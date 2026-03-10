---
name: unity-performance
description: >
  Unity 6 performance profiling and optimization guide. Use when profiling,
  optimizing frame rate, reducing memory usage, debugging performance bottlenecks,
  or using the Profiler, Memory Profiler, or Frame Debugger.
  Based on Unity 6.3 LTS documentation.
---

# Unity Performance Profiling & Optimization

> Based on Unity 6.3 LTS (6000.3) official documentation

## Core Tools Overview

Unity provides several built-in and package-based tools for profiling and optimization:

| Tool | Access | Purpose |
|------|--------|---------|
| **Unity Profiler** | Window > Analysis > Profiler | CPU, GPU, memory, rendering metrics per frame |
| **Memory Profiler** | Package: `com.unity.memoryprofiler` | Deep memory snapshots, comparison, leak detection |
| **Frame Debugger** | Window > Analysis > Frame Debugger | Inspect every draw call in a rendered frame |
| **Profile Analyzer** | Package: `com.unity.performance.profile-analyzer` | Statistical analysis across many Profiler frames |

---

## Unity Profiler

The Profiler captures per-frame performance data. It runs in the Editor or connects to a Development Build on a target device.

### CPU Module

The CPU module is the primary tool for finding performance bottlenecks.

**Views:**
- **Timeline view** -- Shows all threads side-by-side with time on the x-axis. Best for seeing thread contention, job system utilization, and where the frame time is spent.
- **Hierarchy view** -- Aggregates samples into a call tree. Shows Total %, Self %, Calls, GC Alloc, and Time columns. Best for finding the most expensive functions.

**Key threads:**
- **Main Thread** -- Game logic, scripts, animation, UI layout
- **Render Thread** -- Submits draw calls to the GPU (SRP command buffer execution)
- **Job Worker threads** -- C# Jobs, Burst-compiled workloads, physics simulation

**Profiler markers:**
- Built-in markers (e.g., `PlayerLoop`, `Update.ScriptRunBehaviourUpdate`, `Physics.Simulate`)
- Custom markers using `Unity.Profiling.ProfilerMarker` (see [references/profiler-guide.md](references/profiler-guide.md))

**Deep Profiling:**
- Instruments every C# method call automatically
- WARNING: Adds 10-100x overhead -- results do not reflect real performance
- Use `ProfilerMarker` for targeted instrumentation instead

**Call stacks for GC allocations:**
- Enable in Profiler toolbar to see where managed allocations originate
- Adds moderate overhead but invaluable for tracking down GC spikes

### GPU Module

- Shows GPU frame time broken down by rendering passes
- Identifies shader complexity and fill-rate issues
- Useful for diagnosing overdraw and expensive fragment shaders
- Note: GPU profiling is not available on all platforms (check platform docs)
- On mobile, use platform-specific GPU profilers (Xcode GPU Debugger, RenderDoc, Arm Mobile Studio)

### Memory Module

Displays per-frame memory summary:

- **Managed memory** -- C# heap (Mono/IL2CPP), GC allocations
- **Native memory** -- Textures, meshes, audio clips, render targets, native containers
- **Total Reserved vs Used** -- How much memory Unity has reserved from the OS vs actively using
- **GC Allocated in Frame** -- Critical metric; non-zero values in gameplay indicate allocation pressure

### Other Modules

| Module | Key Metrics |
|--------|-------------|
| **Rendering** | Batches, SetPass calls, triangles, vertices, shadow casters |
| **Physics** | Active/sleeping rigidbodies, contacts, broadphase pairs |
| **Audio** | Playing sources, DSP load, memory usage |
| **UI** | Canvas rebuilds, layout rebuilds, batches |
| **Video** | Video player decode time |

---

## Profiling Best Practices

1. **Profile on the target device** -- Editor overhead skews results significantly. Always validate on actual hardware.
2. **Use Development Builds** -- Enable `Development Build` and `Autoconnect Profiler` in Build Settings. The Profiler connects automatically when the build launches.
3. **Use ProfilerMarker** -- Instrument critical code paths with custom markers for precise measurement without Deep Profile overhead.
4. **Profile representative scenarios** -- Test worst-case scenes (many enemies, particle effects, complex UI).
5. **Compare before/after** -- Use Profile Analyzer to compare captures statistically.
6. **Set a frame budget** -- Know your target:
   - 60 FPS = 16.6 ms per frame
   - 120 FPS = 8.3 ms per frame
   - 30 FPS = 33.3 ms per frame
7. **Disable VSync when profiling CPU** -- VSync masks CPU headroom.

---

## Memory Optimization

### GC Allocation Patterns to Avoid

Every managed allocation contributes to GC pressure. In hot paths (`Update`, `FixedUpdate`, `LateUpdate`), target zero allocations.

| Pattern | Problem | Fix |
|---------|---------|-----|
| String concatenation (`+`) | Creates new string each time | Use `StringBuilder` or `string.Create` |
| LINQ queries | Iterator allocation, closure boxing | Use manual `for`/`foreach` loops |
| Lambda closures capturing locals | Compiler generates a class allocation | Cache delegates or use static lambdas |
| Boxing (`int` to `object`) | Allocates on managed heap | Use generic APIs, avoid `object` params |
| `foreach` on non-generic `IEnumerable` | Enumerator boxing | Use typed collections or `for` loops |
| `params` arrays | Array allocated each call | Provide overloads or use `Span<T>` |
| `ToString()` on value types | Allocates string | Cache or avoid in hot paths |

### Asset Memory

**Textures (often the largest memory consumer):**
- Use ASTC compression on mobile, BC7/DXT on desktop
- Enable mipmap streaming (`Texture.streamingMipmaps`) to limit VRAM usage
- Reduce max texture size where quality permits
- Use texture atlases to reduce draw calls and memory fragmentation

**Meshes:**
- Enable mesh compression in import settings
- Use LOD Groups to reduce vertex counts at distance
- Strip unused vertex channels (tangents, colors) in import settings

**Audio:**
- `Decompress on Load` -- Fast playback, high memory (short SFX only)
- `Compressed in Memory` -- Lower memory, moderate CPU (medium clips)
- `Streaming` -- Minimal memory, continuous I/O (music, ambient)
- Set `Load Type` per-clip based on length and frequency of use

**Unloading:**
- `Resources.UnloadUnusedAssets()` -- Frees assets with no references (slow, use during loading screens)
- Addressables: `Addressables.Release()` to decrement ref count and unload when zero

### Object Pooling

Reuse frequently created/destroyed objects to avoid GC pressure and instantiation cost.

```csharp
using UnityEngine.Pool;

public class BulletSpawner : MonoBehaviour
{
    [SerializeField] private Bullet bulletPrefab;
    private ObjectPool<Bullet> _pool;

    private void Awake()
    {
        _pool = new ObjectPool<Bullet>(
            createFunc: () => Instantiate(bulletPrefab),
            actionOnGet: b => b.gameObject.SetActive(true),
            actionOnRelease: b => b.gameObject.SetActive(false),
            actionOnDestroy: b => Destroy(b.gameObject),
            defaultCapacity: 20,
            maxSize: 100
        );
    }

    public Bullet GetBullet() => _pool.Get();
    public void ReturnBullet(Bullet b) => _pool.Release(b);
}
```

See also: unity-scripting for additional pooling patterns.

---

## CPU Optimization

### Scripting

- **Cache `GetComponent` results** -- Call in `Awake`/`Start`, store in a field
- **Use `CompareTag("Tag")`** -- Avoids string allocation from `gameObject.tag`
- **Avoid `Find` methods in hot paths** -- `Find`, `FindObjectOfType`, `FindObjectsByType` are expensive; cache references
- **Use C# Jobs + Burst** -- For data-heavy processing (spatial queries, AI, pathfinding). See unity-ecs-dots.
- **Async operations with `Awaitable`** -- Non-blocking scene loading, asset loading, web requests

```csharp
// Cache component references
private Rigidbody _rb;
private void Awake() => _rb = GetComponent<Rigidbody>();

// Use CompareTag instead of string comparison
if (other.CompareTag("Enemy")) { /* ... */ }
```

### Physics

- **Simplify colliders** -- Use primitive colliders (Box, Sphere, Capsule) over MeshColliders
- **Layer-based collision matrix** -- Disable unnecessary collision pairs in Project Settings > Physics
- **FixedUpdate timestep** -- Default 0.02s (50Hz). Increase to 0.03-0.04s for less demanding games.
- **Rigidbody sleeping** -- Ensure objects go to sleep; avoid constant `AddForce` on idle objects.
- **Non-allocating queries** -- Use `Physics.RaycastNonAlloc`, `Physics.OverlapSphereNonAlloc`

### Rendering

- **SRP Batcher** -- Enabled by default in URP/HDRP. Reduces SetPass call overhead for compatible shaders.
- **Static batching** -- Mark non-moving objects as `Batching Static` to merge meshes at build time.
- **GPU Instancing** -- Enable on materials for many identical objects (trees, grass, debris).
- **Dynamic batching** -- Small meshes batched at runtime (limited benefit in SRP; prefer GPU instancing).
- **Occlusion culling** -- Bake occlusion data to skip rendering objects behind walls.
- **LOD Groups** -- Reduce geometric complexity at distance.
- **Shader variants** -- Minimize keyword combinations; strip unused variants in Player Settings.

---

## Frame Debugger

The Frame Debugger (Window > Analysis > Frame Debugger) lets you step through every draw call in a frame.

**Workflow:**
1. Open Frame Debugger and click **Enable**
2. The Game view freezes on the current frame
3. Step through draw calls in the left panel
4. Inspect: shader, pass, keywords, render target, mesh, material properties
5. Identify redundant draws, batching breaks, overdraw

**Common uses:**
- Verify SRP Batcher / batching effectiveness
- Find why batches are breaking (different materials, shader keywords, render state changes)
- Inspect shadow passes and their cost
- Debug transparent object sorting issues
- Verify render target switches (each switch has overhead)
- Check fullscreen post-processing pass count

---

## IL2CPP and Managed Code Performance

Unity 6 uses IL2CPP by default for most platforms. Key performance considerations:

- **IL2CPP ahead-of-time compilation** converts C# to C++, enabling better optimization than Mono JIT
- **Code stripping** removes unused code, reducing build size and improving startup
- **Generic sharing** -- IL2CPP shares code for reference-type generics but generates separate code for value-type generics. Excessive value-type generic instantiations increase binary size.
- **Virtual method calls** -- IL2CPP uses vtable dispatch; `sealed` classes/methods enable devirtualization and inlining
- **Struct layout** -- Use `[StructLayout(LayoutKind.Sequential)]` for data passed to native code. Keep structs small (under 16 bytes) for efficient passing.

```csharp
// sealed enables devirtualization -- IL2CPP can inline the call
public sealed class FastEnemy : EnemyBase
{
    public override void Think()
    {
        // This can be inlined by IL2CPP when called through a typed reference
    }
}
```

---

## Quality Settings and Adaptive Performance

### Runtime Quality Switching

```csharp
// Switch quality level at runtime (e.g., from settings menu)
QualitySettings.SetQualityLevel(qualityIndex, applyExpensiveChanges: true);

// Adjust individual settings
QualitySettings.shadows = ShadowQuality.Disable;
QualitySettings.vSyncCount = 0;
Application.targetFrameRate = 60;
```

### Adaptive Performance (Mobile)

The Adaptive Performance package (`com.unity.adaptiveperformance`) dynamically adjusts quality based on device thermal state and performance metrics:

- Automatically reduces resolution, LOD bias, shadow quality when device overheats
- Provides `IAdaptivePerformance` interface for custom scaling logic
- Supports Samsung (GameSDK) and universal providers

---

## Common Performance Patterns

### Async Scene Loading

```csharp
using UnityEngine.SceneManagement;

public async Awaitable LoadSceneAsync(string sceneName)
{
    AsyncOperation op = SceneManager.LoadSceneAsync(sceneName);
    op.allowSceneActivation = false;

    while (op.progress < 0.9f)
    {
        // Update loading bar: op.progress / 0.9f
        await Awaitable.NextFrameAsync();
    }
    op.allowSceneActivation = true;
}
```

### Spreading Work Across Frames

```csharp
// Process a large list over multiple frames
private IEnumerator ProcessChunked<T>(List<T> items, int chunkSize, System.Action<T> process)
{
    for (int i = 0; i < items.Count; i++)
    {
        process(items[i]);
        if ((i + 1) % chunkSize == 0)
            yield return null; // Resume next frame
    }
}
```

### Frame Budget Awareness

```csharp
using System.Diagnostics;

private readonly Stopwatch _sw = new();
private const float BUDGET_MS = 4f; // Portion of frame budget

private void Update()
{
    _sw.Restart();
    while (_workQueue.Count > 0 && _sw.Elapsed.TotalMilliseconds < BUDGET_MS)
    {
        ProcessNextItem(_workQueue.Dequeue());
    }
}
```

### Level Streaming with Additive Scenes

```csharp
using UnityEngine.SceneManagement;

// Load adjacent area additively without blocking
public async Awaitable StreamArea(string sceneName)
{
    AsyncOperation op = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
    while (!op.isDone)
        await Awaitable.NextFrameAsync();
}

// Unload area when player moves away
public async Awaitable UnloadArea(string sceneName)
{
    AsyncOperation op = SceneManager.UnloadSceneAsync(sceneName);
    while (!op.isDone)
        await Awaitable.NextFrameAsync();
    // Reclaim memory from unloaded assets
    Resources.UnloadUnusedAssets();
}
```

### Custom ProfilerMarker Instrumentation

```csharp
using Unity.Profiling;

public class AISystem : MonoBehaviour
{
    private static readonly ProfilerMarker s_AIUpdate = new("AISystem.Update");
    private static readonly ProfilerMarker s_Pathfind = new("AISystem.Pathfind");

    private void Update()
    {
        using (s_AIUpdate.Auto())
        {
            foreach (var agent in _agents)
            {
                using (s_Pathfind.Auto())
                {
                    agent.RecalculatePath();
                }
            }
        }
    }
}
```

---

## Common Bottlenecks & Fixes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Low FPS, high CPU main thread | Too much logic in Update | Profile with Profiler; optimize, jobify, or spread across frames |
| GC spikes (frame hitches) | Allocations in hot paths | Pool objects, cache, avoid LINQ/string concat in Update |
| High draw calls / SetPass calls | No batching or too many materials | Enable SRP Batcher, use GPU instancing, atlas textures |
| Memory keeps growing | Asset leaks, unreleased Addressables | Call `Resources.UnloadUnusedAssets()`, check Addressable ref counts |
| Physics lag | Too many active colliders or contacts | Simplify colliders, use collision matrix layers, increase timestep |
| Shader compilation stutter | Shader variants compiled on demand | Use shader warmup (`ShaderVariantCollection.WarmUp()`), reduce variants |
| Long loading times | Synchronous asset loading | Use `Addressables.LoadAssetAsync` or `Resources.LoadAsync` |
| Render thread bound | Too many draw calls or GPU commands | Reduce batches, simplify shaders, lower resolution |

---

## Anti-Patterns

| What | Why It Hurts | Fix |
|------|-------------|-----|
| `Debug.Log` in production | String formatting + managed alloc + I/O | Use `[Conditional("UNITY_EDITOR")]` or strip via scripting defines |
| `Camera.main` in Update | Calls `FindGameObjectWithTag` internally each time | Cache in `Awake` or `Start` |
| `Instantiate`/`Destroy` every frame | GC allocation + native overhead per call | Use `ObjectPool<T>` |
| `GetComponent<T>()` in Update | Lookup cost each frame | Cache in `Awake`/`Start` |
| `OnGUI` for game UI | IMGUI redraws every frame, heavy GC | Use UI Toolkit or uGUI (Canvas) |
| Deep Profile for perf tests | 10-100x overhead invalidates results | Use `ProfilerMarker` for targeted instrumentation |
| Allocating in `FixedUpdate` | Runs at physics rate (50Hz default), amplifies GC | Pre-allocate, pool, use `NativeArray` |
| `SendMessage` / `BroadcastMessage` | Reflection-based, allocates | Use direct method calls, events, or `UnityEvent` |

---

## Key API Quick Reference

| API | Namespace | Purpose |
|-----|-----------|---------|
| `ProfilerMarker` | `Unity.Profiling` | Zero-overhead custom profiler instrumentation |
| `ProfilerRecorder` | `Unity.Profiling` | Read profiler counter values at runtime |
| `Profiler.BeginSample` / `EndSample` | `UnityEngine.Profiling` | Legacy custom profiler samples (stripped in non-dev builds) |
| `ObjectPool<T>` | `UnityEngine.Pool` | Generic object pooling |
| `ListPool<T>` / `HashSetPool<T>` | `UnityEngine.Pool` | Temporary collection pooling |
| `NativeArray<T>` | `Unity.Collections` | Unmanaged, GC-free array for Jobs/Burst |
| `NativeList<T>` | `Unity.Collections` | Unmanaged, resizable list |
| `Stopwatch` | `System.Diagnostics` | High-resolution timing |
| `ShaderVariantCollection` | `UnityEngine.Rendering` | Shader warmup to prevent compilation stutter |
| `QualitySettings` | `UnityEngine` | Runtime quality level switching |

---

## Related Skills

- For scripting patterns and component lifecycle, see **unity-scripting**
- For rendering pipeline and shader optimization, see **unity-graphics**
- For mobile/console platform optimization, see **unity-platforms**
- For ECS, Jobs, and Burst (data-oriented performance), see **unity-ecs-dots**
- For physics configuration and optimization, see **unity-physics**
- For UI performance (Canvas rebuilds, batching), see **unity-ui**

## Additional Resources

- See [references/profiler-guide.md](references/profiler-guide.md) for detailed Profiler API usage and workflows
- See [references/memory-optimization.md](references/memory-optimization.md) for in-depth memory management strategies
