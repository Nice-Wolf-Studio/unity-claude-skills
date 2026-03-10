# Memory Optimization Guide

> Detailed reference for Unity 6.3 LTS memory management and optimization

## Finding GC Allocations

### Profiler Call Stacks

1. Open the Profiler (Window > Analysis > Profiler)
2. Select the **CPU Module**
3. Enable **Call Stacks** in the toolbar (click the dropdown arrow next to the record button)
4. Select **GC.Alloc** as the call stack type
5. Play the scene and look for `GC.Alloc` entries in the Hierarchy view
6. Click an allocation to see the full call stack in the details panel

### Common Allocation Sources in the Hierarchy

Look for these columns in the CPU module Hierarchy view:
- **GC Alloc** -- Total bytes allocated by this sample and its children
- Sort by this column descending to find the worst offenders
- Filter by your scripts (uncheck Unity internals) to focus on actionable items

---

## Zero-Allocation Patterns

### String Operations

```csharp
// BAD: Allocates a new string every frame
_label.text = "Score: " + _score + " HP: " + _hp;

// GOOD: Use StringBuilder, only update when values change
private readonly StringBuilder _sb = new(64);
private int _lastScore, _lastHp;

private void UpdateScoreDisplay()
{
    if (_score == _lastScore && _hp == _lastHp) return;
    _lastScore = _score;
    _lastHp = _hp;
    _sb.Clear();
    _sb.Append("Score: ").Append(_score).Append(" HP: ").Append(_hp);
    _label.text = _sb.ToString();
}
```

### Collection Reuse

```csharp
// BAD: Allocates a new list every call
var result = new List<Enemy>();

// GOOD: Pass a reusable buffer, clear before use
private readonly List<Enemy> _buffer = new(32);
private void GetNearby(Vector3 pos, float range, List<Enemy> results)
{
    results.Clear();
    foreach (var e in _allEnemies)
        if (Vector3.Distance(e.Position, pos) < range)
            results.Add(e);
}

// ALSO GOOD: Use Unity's ListPool for short-lived collections
var list = ListPool<Enemy>.Get();
// ... use list ...
ListPool<Enemy>.Release(list);
```

### Non-Allocating Physics Queries

```csharp
// BAD: Allocates array each call
Collider[] hits = Physics.OverlapSphere(pos, radius);

// GOOD: Pre-allocated buffer with NonAlloc
private readonly Collider[] _hitBuffer = new Collider[32];

private void CheckArea(Vector3 pos, float radius)
{
    int count = Physics.OverlapSphereNonAlloc(pos, radius, _hitBuffer);
    for (int i = 0; i < count; i++)
        ProcessHit(_hitBuffer[i]);
}
```

Also use `Physics.RaycastNonAlloc`, `Physics.SphereCastNonAlloc`, etc.

### Delegate and Closure Allocation

```csharp
// BAD: Lambda captures 'threshold', compiler generates closure class
_enemies.RemoveAll(e => e.Health < threshold);

// GOOD: Manual loop avoids closure allocation
for (int i = _enemies.Count - 1; i >= 0; i--)
    if (_enemies[i].Health < threshold)
        _enemies.RemoveAt(i);
```

---

## NativeArray vs Managed Arrays

| Feature | `T[]` (managed) | `NativeArray<T>` |
|---------|-----------------|-------------------|
| GC tracked | Yes | No |
| Burst compatible | No (in most cases) | Yes |
| Job system compatible | Copy only (via NativeArray) | Direct |
| Memory location | Managed heap | Native (unmanaged) heap |
| Dispose required | No | Yes (`Dispose()` or `Allocator.Temp`) |
| Bounds checking | Always | Development builds only |

```csharp
using Unity.Collections;

var temp = new NativeArray<float>(1024, Allocator.Temp);       // 1 frame, auto-freed
var job  = new NativeArray<float>(1024, Allocator.TempJob);    // 4 frames, must Dispose
var perm = new NativeArray<float>(1024, Allocator.Persistent); // Until Dispose
job.Dispose();
perm.Dispose();
```

---

## Texture Memory Budgets by Platform

Textures are typically the largest memory consumer. Use these guidelines:

| Platform | Recommended Total Texture Budget | Compression Format |
|----------|----------------------------------|-------------------|
| Mobile (low-end) | 150-256 MB | ASTC 6x6 or 8x8 |
| Mobile (high-end) | 256-512 MB | ASTC 4x4 or 6x6 |
| Desktop / Console | 512 MB - 2 GB | BC7 (quality) or BC1/BC3 (smaller) |
| WebGL | 128-256 MB | DXT1/DXT5 or ASTC |

### Mipmap Streaming

Enable per-texture in Import Settings > Advanced > Streaming Mipmaps. Set budget via `QualitySettings.streamingMipmapsBudget` to limit total mip memory per platform.

---

## Audio Memory Strategies

| Clip Type | Load Type | Compression | Memory Impact |
|-----------|-----------|-------------|---------------|
| Short SFX (< 1s) | Decompress on Load | Vorbis | ~10x compressed size in RAM |
| Medium SFX (1-5s) | Compressed in Memory | Vorbis | ~1x compressed size in RAM |
| Music / Ambient | Streaming | Vorbis / AAC | ~200 KB buffer per clip |

Key settings:
- **Force Mono** for sounds without spatial relevance (UI, ambient) -- halves memory
- **Sample Rate Override** -- Reduce to 22050 Hz for speech or low-quality sounds
- **Preload Audio Data** -- Disable for rarely used clips to defer loading

---

## Mesh Optimization

### Vertex Count Guidelines

| Platform | Per-object guideline | Total scene guideline |
|----------|---------------------|-----------------------|
| Mobile | < 10K vertices | < 200K total |
| Desktop | < 100K vertices | < 2M total |

### Reducing Mesh Memory

- **Mesh Compression** -- Set in import settings (Low/Medium/High). Trades quality for size.
- **Read/Write Enabled** -- Disable unless you modify meshes at runtime. Halves memory (no CPU copy).
- **Strip unused vertex channels** -- In import settings, disable Tangents, Vertex Colors if not needed.
- **LOD Groups** -- Use 3-4 LOD levels. LOD0: full detail, LOD1: 50%, LOD2: 25%, Cull: invisible.

---

## Addressables Memory Management

The Addressables system (`com.unity.addressables`) manages asset lifetime via reference counting.

### Key Principles

1. Every `LoadAssetAsync` must have a matching `Release`
2. Every `InstantiateAsync` must have a matching `ReleaseInstance`
3. Assets are unloaded from memory only when the ref count reaches zero and the bundle is released

```csharp
using UnityEngine.AddressableAssets;

// Load -- must Release when done
var handle = Addressables.LoadAssetAsync<GameObject>("EnemyPrefab");
await handle.Task;
// ... use handle.Result ...
Addressables.Release(handle);

// InstantiateAsync -- must ReleaseInstance when done
var instHandle = Addressables.InstantiateAsync("EnemyPrefab");
await instHandle.Task;
// ... use instance ...
Addressables.ReleaseInstance(instHandle);
```

### Detecting Addressable Leaks

Enable the **Addressables Event Viewer** (Window > Asset Management > Addressables > Event Viewer) during play mode to visualize ref counts and detect unreleased handles.

---

## Memory Profiler Package

The Memory Profiler (`com.unity.memoryprofiler`) provides deep memory snapshots beyond what the built-in Profiler Memory module offers.

### Installation

```
Window > Package Manager > Unity Registry > Memory Profiler > Install
```

### Capturing Snapshots

1. Open **Window > Analysis > Memory Profiler**
2. Connect to a Development Build or use Play Mode
3. Click **Capture New Snapshot**
4. Wait for the snapshot to complete (may take several seconds on large projects)

### Analyzing and Comparing Snapshots

The Memory Profiler provides **Summary**, **Unity Objects**, **All Of Memory**, and **Tree Map** views.

**Leak detection workflow:**
1. Capture snapshot A at a known-good state (e.g., main menu)
2. Play through gameplay, then return to main menu
3. Capture snapshot B
4. Compare A vs B -- objects in B but not A are potential leaks

### Common Memory Leak Indicators

| Indicator | Likely Cause |
|-----------|-------------|
| Managed heap grows, never shrinks | References keeping dead objects alive |
| Duplicate textures/meshes | Assets loaded multiple times from different paths |
| GameObjects accumulating | `Instantiate` without `Destroy` or pool return |
| Event delegates holding refs | `+=` without `-=` keeps listeners alive |
| Static refs to scene objects | Static fields prevent GC after scene unload |

Always capture snapshots on the target device. Force GC before snapshot (`System.GC.Collect()` then `Resources.UnloadUnusedAssets()`) for cleaner results.
