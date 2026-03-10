# Unity Profiler Guide

> Detailed reference for Unity 6.3 LTS profiling APIs and workflows

## ProfilerMarker API

`Unity.Profiling.ProfilerMarker` is the recommended way to instrument custom code sections. It has zero overhead when the Profiler is not recording and is compatible with Burst-compiled code.

### Basic Usage

```csharp
using Unity.Profiling;

public class EnemyAI : MonoBehaviour
{
    // Declare as static readonly for best performance
    private static readonly ProfilerMarker s_UpdateAI = new("EnemyAI.UpdateAI");
    private static readonly ProfilerMarker s_Pathfinding = new("EnemyAI.Pathfinding");

    private void Update()
    {
        s_UpdateAI.Begin();
        UpdateAI();
        s_UpdateAI.End();
    }

    private void UpdateAI()
    {
        s_Pathfinding.Begin();
        // ... pathfinding logic ...
        s_Pathfinding.End();
    }
}
```

### Using Auto() for Scoped Markers

The `Auto()` method returns a disposable struct that calls `End()` automatically, ensuring markers are always closed even if exceptions occur.

```csharp
using Unity.Profiling;

private static readonly ProfilerMarker s_ProcessEnemies = new("GameManager.ProcessEnemies");

private void ProcessEnemies()
{
    using (s_ProcessEnemies.Auto())
    {
        foreach (var enemy in _activeEnemies)
        {
            enemy.Think();
        }
    }
}
```

### ProfilerMarker with Metadata

You can attach integer or string metadata to markers for richer Profiler data.

```csharp
using Unity.Profiling;

private static readonly ProfilerMarker<int> s_SpawnMarker =
    new("Spawner.Spawn", "Count");

public void SpawnWave(int count)
{
    s_SpawnMarker.Begin(count);
    for (int i = 0; i < count; i++)
    {
        SpawnEnemy();
    }
    s_SpawnMarker.End();
}
```

### ProfilerMarker in Burst Jobs

`ProfilerMarker` is Burst-compatible. Declare markers as `static readonly` and use them inside `IJob` or `IJobParallelFor` implementations with `Auto()`.

---

## ProfilerRecorder

`ProfilerRecorder` reads profiler counter values at runtime, enabling you to build custom performance overlays or log metrics.

```csharp
using Unity.Profiling;
using UnityEngine;

public class PerformanceOverlay : MonoBehaviour
{
    private ProfilerRecorder _mainThreadRecorder;
    private ProfilerRecorder _gcMemoryRecorder;
    private ProfilerRecorder _drawCallRecorder;

    private void OnEnable()
    {
        // Subscribe to built-in profiler counters
        _mainThreadRecorder = ProfilerRecorder.StartNew(
            ProfilerCategory.Internal, "Main Thread", 15); // 15 frame capacity
        _gcMemoryRecorder = ProfilerRecorder.StartNew(
            ProfilerCategory.Memory, "GC Reserved Memory");
        _drawCallRecorder = ProfilerRecorder.StartNew(
            ProfilerCategory.Render, "Draw Calls Count");
    }

    private void OnDisable()
    {
        _mainThreadRecorder.Dispose();
        _gcMemoryRecorder.Dispose();
        _drawCallRecorder.Dispose();
    }

    private void OnGUI()
    {
        // Display runtime metrics (use UI Toolkit in production)
        double frameTimeMs = _mainThreadRecorder.LastValue * 1e-6; // ns to ms
        long gcMemoryMB = _gcMemoryRecorder.LastValue / (1024 * 1024);
        long drawCalls = _drawCallRecorder.LastValue;

        GUILayout.Label($"Frame: {frameTimeMs:F1} ms");
        GUILayout.Label($"GC Memory: {gcMemoryMB} MB");
        GUILayout.Label($"Draw Calls: {drawCalls}");
    }
}
```

### Common Profiler Counter Names

| Category | Counter Name | Value |
|----------|-------------|-------|
| `ProfilerCategory.Internal` | `Main Thread` | Frame time in nanoseconds |
| `ProfilerCategory.Render` | `Draw Calls Count` | Number of draw calls |
| `ProfilerCategory.Render` | `SetPass Calls Count` | Number of SetPass calls |
| `ProfilerCategory.Render` | `Triangles Count` | Rendered triangles |
| `ProfilerCategory.Render` | `Vertices Count` | Rendered vertices |
| `ProfilerCategory.Memory` | `Total Used Memory` | Bytes of used memory |
| `ProfilerCategory.Memory` | `Total Reserved Memory` | Bytes of reserved memory |
| `ProfilerCategory.Memory` | `GC Reserved Memory` | Bytes reserved for managed heap |
| `ProfilerCategory.Memory` | `GC Used Memory` | Bytes used on managed heap |
| `ProfilerCategory.Memory` | `GC Allocation In Frame Count` | Number of GC allocations in frame |

---

## Legacy Profiler.BeginSample / EndSample

The older `UnityEngine.Profiling.Profiler` API still works but has limitations:
- Not compatible with Burst
- Slightly higher overhead than `ProfilerMarker`
- Automatically stripped from non-Development builds

```csharp
using UnityEngine.Profiling;

private void Update()
{
    Profiler.BeginSample("MyComponent.Update");
    // ... work ...
    Profiler.EndSample();
}
```

Prefer `ProfilerMarker` for new code. Use `BeginSample`/`EndSample` only when maintaining legacy codebases.

---

## Development Build Profiling Setup

### Build Configuration

1. Open **File > Build Settings**
2. Check **Development Build**
3. Check **Autoconnect Profiler** (connects the Profiler window automatically when the build starts)
4. Optionally check **Deep Profiling Support** (adds overhead; usually avoid)
5. Build and run on the target device

### Remote Profiling

If Autoconnect does not work (firewall, different subnet):

1. Build with **Development Build** enabled (Autoconnect optional)
2. Open Profiler window in the Editor
3. Click the **Target Selection** dropdown (top-left of Profiler)
4. Select the device IP or use `<Enter IP>` to connect manually
5. Ensure port 34999 (default) is open on the device

### IL2CPP Considerations

- IL2CPP builds strip managed method names by default in Release
- Enable **Script Debugging** in Build Settings to preserve names (adds overhead)
- Alternatively, use `ProfilerMarker` which works regardless of stripping

---

## Profile Analyzer Package

The Profile Analyzer (`com.unity.performance.profile-analyzer`) provides statistical analysis across many captured frames, going beyond the per-frame view of the standard Profiler.

### Installation

```
Window > Package Manager > Unity Registry > Profile Analyzer > Install
```

### Workflow

1. Open **Window > Analysis > Profile Analyzer**
2. Capture frames in the Profiler (at least 300 for meaningful statistics)
3. In Profile Analyzer, click **Pull Data** to import from the Profiler
4. View median, min, max, standard deviation for any marker
5. **Compare mode**: Pull two datasets (before/after optimization) to see statistical differences

### Key Features

- **Single view** -- Statistics for one capture session
- **Compare view** -- Side-by-side comparison of two sessions
- **Marker filtering** -- Search and filter by marker name
- **Frame range selection** -- Analyze a subset of captured frames
- **Export** -- Save analysis data as CSV for external tools

---

## Frame Debugger Step-by-Step

1. Open **Window > Analysis > Frame Debugger**
2. Enter Play Mode (or connect to a Development Build)
3. Click **Enable** in the Frame Debugger window
4. The Game view freezes; the left panel lists all draw events

### Navigating Draw Calls

- Click any draw event to highlight the geometry it renders in the Game view
- The right panel shows:
  - **Shader and pass** being used
  - **Shader keywords** active for this draw
  - **Render target** and its format
  - **Mesh** and submesh index
  - **Material properties** (textures, colors, floats)

### Diagnosing Batching Issues

When draw calls are not batching as expected, the Frame Debugger shows the reason:
- "Objects have different materials" -- Consolidate materials or use atlases
- "Objects have different shader keywords" -- Reduce keyword variants
- "Objects are not static" -- Mark as Batching Static for static batching
- "SRP Batcher: incompatible" -- Ensure shader uses CBUFFER macros

### Checking Overdraw

Switch the Game view to **Overdraw** visualization mode (Scene view shading dropdown) to see where multiple layers of transparent or opaque geometry overlap, wasting fill rate.

---

## Custom Profiler Modules (Advanced)

You can create custom Profiler modules that appear in the Profiler window alongside built-in modules.

```csharp
using Unity.Profiling;
using Unity.Profiling.Editor;

[System.Serializable]
[ProfilerModuleMetadata("Game Stats")]
public class GameStatsProfilerModule : ProfilerModule
{
    private static readonly ProfilerCounterDescriptor[] k_Counters =
    {
        new("Active Enemies", ProfilerCategory.Scripts),
        new("Projectiles", ProfilerCategory.Scripts),
    };

    public GameStatsProfilerModule()
        : base(k_Counters) { }
}
```

Report values from game code:

```csharp
using Unity.Profiling;

public class GameStats : MonoBehaviour
{
    public static readonly ProfilerCounter<int> EnemyCount =
        new(ProfilerCategory.Scripts, "Active Enemies", ProfilerMarkerDataUnit.Count);
    public static readonly ProfilerCounter<int> ProjectileCount =
        new(ProfilerCategory.Scripts, "Projectiles", ProfilerMarkerDataUnit.Count);

    private void Update()
    {
        EnemyCount.Sample(EnemyManager.ActiveCount);
        ProjectileCount.Sample(ProjectileManager.ActiveCount);
    }
}
```

These custom counters then appear in the Profiler under the "Game Stats" module.
