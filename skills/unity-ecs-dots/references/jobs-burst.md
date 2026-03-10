# Jobs and Burst Compiler Reference

> Source: [Unity Jobs](https://docs.unity3d.com/6000.3/Documentation/Manual/job-system.html) | [Unity Burst 1.8](https://docs.unity3d.com/Packages/com.unity.burst@1.8/manual/index.html)

## IJobEntity

The recommended job type for ECS. The query is automatically generated from the `Execute` method parameters.

### Parameter Modifiers

| Modifier | Meaning |
|----------|---------|
| `ref T` | Read-write access to component |
| `in T` | Read-only access to component |
| `Entity` | The entity being processed |
| `[ChunkIndexInQuery] int` | Chunk index for ECB sort key |
| `[EntityIndexInQuery] int` | Global index of entity in query |
| `DynamicBuffer<T>` | Access to a dynamic buffer |
| `MyAspect` | Access to a custom aspect |

### Filtering with Attributes

```csharp
[BurstCompile]
[WithAll(typeof(IsPlayer))]
[WithNone(typeof(Dead))]
[WithAny(typeof(OnFire), typeof(Frozen))]
public partial struct PlayerMoveJob : IJobEntity
{
    public float DeltaTime;

    void Execute(ref LocalTransform transform, in Speed speed)
    {
        transform.Position.z += speed.Value * DeltaTime;
    }
}
```

### Scheduling

```csharp
var job = new MoveJob { DeltaTime = SystemAPI.Time.DeltaTime };

job.Run();                                    // Main thread
state.Dependency = job.Schedule(state.Dependency);          // Single worker
state.Dependency = job.ScheduleParallel(state.Dependency);  // Parallel across chunks

// Schedule with specific query
var query = SystemAPI.QueryBuilder().WithAll<Speed>().Build();
state.Dependency = job.ScheduleParallel(query, state.Dependency);
```

### ECB in IJobEntity

```csharp
[BurstCompile]
public partial struct DestroyDeadJob : IJobEntity
{
    public EntityCommandBuffer.ParallelWriter ECB;

    void Execute([ChunkIndexInQuery] int sortKey, Entity entity, in Health health)
    {
        if (health.Current <= 0f)
            ECB.DestroyEntity(sortKey, entity);
    }
}

// In system:
var ecbSingleton = SystemAPI.GetSingleton<
    EndSimulationEntityCommandBufferSystem.Singleton>();
var ecb = ecbSingleton.CreateCommandBuffer(state.WorldUnmanaged);
state.Dependency = new DestroyDeadJob
{
    ECB = ecb.AsParallelWriter()
}.ScheduleParallel(state.Dependency);
```

## IJobChunk

Low-level chunk iteration for cases where IJobEntity is insufficient.

```csharp
[BurstCompile]
public struct ApplyDamageChunkJob : IJobChunk
{
    public ComponentTypeHandle<Health> HealthHandle;
    [ReadOnly] public ComponentTypeHandle<DamageOverTime> DotHandle;
    public float DeltaTime;

    public void Execute(in ArchetypeChunk chunk, int unfilteredChunkIndex,
        bool useEnabledMask, in v128 chunkEnabledMask)
    {
        var healths = chunk.GetNativeArray(ref HealthHandle);
        var dots = chunk.GetNativeArray(ref DotHandle);
        var enumerator = new ChunkEntityEnumerator(
            useEnabledMask, chunkEnabledMask, chunk.Count);

        while (enumerator.NextEntityIndex(out int i))
        {
            var h = healths[i];
            h.Current -= dots[i].DamagePerSecond * DeltaTime;
            healths[i] = h;
        }
    }
}

// Schedule: update handles each frame, then schedule against query
_healthHandle = SystemAPI.GetComponentTypeHandle<Health>();
_dotHandle = SystemAPI.GetComponentTypeHandle<DamageOverTime>(isReadOnly: true);
state.Dependency = new ApplyDamageChunkJob
{
    HealthHandle = _healthHandle,
    DotHandle = _dotHandle,
    DeltaTime = SystemAPI.Time.DeltaTime
}.ScheduleParallel(_query, state.Dependency);
```

## Burst Compiler Configuration

```csharp
[BurstCompile(
    FloatPrecision.Standard,
    FloatMode.Default,
    CompileSynchronously = false,
    OptimizeFor = OptimizeFor.Performance
)]
public partial struct MyJob : IJobEntity { }
```

### Restrictions

| Not Allowed | Alternative |
|-------------|-------------|
| `string` | `FixedString64Bytes`, `FixedString128Bytes` |
| `class` instances | Unmanaged structs only |
| `List<T>`, `Dictionary<K,V>` | `NativeList<T>`, `NativeHashMap<K,V>` |
| `new` (reference types) | NativeContainer or stack allocation |
| `try / catch / finally` | Check conditions explicitly |
| Virtual/interface dispatch | Direct method calls or function pointers |
| Static mutable fields | `SharedStatic<T>` |
| `Debug.Log` | `#if !UNITY_BURST_COMPILED` |
| Boxing (value to object) | Avoid casting to `object` |

### SharedStatic<T>

```csharp
using Unity.Burst;

public struct GameSettings
{
    public float Gravity;
    public float MaxSpeed;
}

public static class SharedGameSettings
{
    public static readonly SharedStatic<GameSettings> Value =
        SharedStatic<GameSettings>.GetOrCreate<SharedGameSettings>();
}

// Write from managed code
SharedGameSettings.Value.Data = new GameSettings { Gravity = -9.81f };

// Read from Burst code
float gravity = SharedGameSettings.Value.Data.Gravity;
```

## NativeContainer Types

### Allocator Types

| Allocator | Lifetime | Use Case |
|-----------|----------|----------|
| `Allocator.Temp` | 1 frame (auto-disposed) | Within a single method |
| `Allocator.TempJob` | 4 frames | Job data, short-lived |
| `Allocator.Persistent` | Until manually disposed | Long-lived data |

### NativeArray, NativeList, NativeHashMap

```csharp
using Unity.Collections;

// NativeArray -- fixed size
var array = new NativeArray<float>(100, Allocator.TempJob);
array[0] = 42f;
array.Dispose();

// NativeList -- dynamic size
var list = new NativeList<int>(64, Allocator.TempJob);
list.Add(1);
list.RemoveAt(0);
NativeArray<int> asArray = list.AsArray();  // No copy
list.Dispose();

// NativeHashMap -- key-value store
var map = new NativeHashMap<int, float>(64, Allocator.TempJob);
map.Add(1, 3.14f);
map.TryGetValue(1, out float val);
map.Remove(1);
map.Dispose();

// Parallel writing
NativeHashMap<int, float>.ParallelWriter writer = map.AsParallelWriter();
```

## Job Dependencies

```csharp
// state.Dependency tracks input dependencies automatically
JobHandle handle1 = new JobA().Schedule(state.Dependency);
JobHandle handle2 = new JobB().Schedule(state.Dependency);
JobHandle combined = JobHandle.CombineDependencies(handle1, handle2);
state.Dependency = new JobC().Schedule(combined);
// ECS auto-completes state.Dependency before next system runs
```

**Important:** Always assign job handles back to `state.Dependency`. Failing to do so causes race conditions.

## Unity.Mathematics

### Common Types and Functions

```csharp
using Unity.Mathematics;

float3 pos = new float3(1, 2, 3);
quaternion rot = quaternion.Euler(0, math.PI, 0);
float3 rotated = math.rotate(rot, direction);

// Arithmetic
float d = math.distance(a, b);
float d2 = math.distancesq(a, b);    // Faster (no sqrt)
float3 n = math.normalize(v);
float dot = math.dot(a, b);
float3 cross = math.cross(a, b);
float c = math.clamp(val, min, max);
float s = math.saturate(val);         // Clamp to [0,1]

// Deterministic random
var rng = new Random(seed);            // seed must be non-zero
float3 pt = rng.NextFloat3();
int ri = rng.NextInt(0, 100);
```

## Performance Tips

**Do:**
- Add `[BurstCompile]` to all `ISystem` structs and methods
- Use `ScheduleParallel()` when entities are independent
- Use `Allocator.Temp` for frame-local data
- Use `math.distancesq()` for comparisons
- Use `[ReadOnly]` on job fields that are only read
- Call `state.RequireForUpdate<T>()` to skip idle systems
- Batch structural changes with ECB

**Don't:**
- Call `.Complete()` unless you need results immediately
- Use managed types in Burst code
- Forget to assign handles to `state.Dependency`
- Allocate NativeContainers without disposing
- Use `EntityManager` structural changes in jobs
- Mix `UnityEngine.Mathf` / `Vector3` with Burst code
- Access `SystemAPI` from jobs (pass data as fields)
