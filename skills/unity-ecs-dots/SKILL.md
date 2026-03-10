---
name: unity-ecs-dots
description: >
  Unity 6 ECS/DOTS development guide. Use when working with Entity Component System,
  data-oriented design, Jobs system, or Burst Compiler.
  Covers Entities, IComponentData, ISystem, EntityManager, baking, Jobs, and Burst.
  Based on Unity 6.3 LTS documentation.
---

# Unity ECS / DOTS (Data-Oriented Technology Stack)

> Based on Unity 6.3 LTS (6000.3) -- Entities 1.3, Burst 1.8, Jobs package

## Core Concepts

ECS (Entity Component System) is Unity's data-oriented framework. It replaces the GameObject/MonoBehaviour model with a cache-friendly, high-performance architecture.

### ECS vs MonoBehaviour

| Aspect | MonoBehaviour | ECS |
|--------|--------------|-----|
| Identity | GameObject (heavy, managed) | Entity (lightweight int ID) |
| Data | Class fields on components | Unmanaged structs (IComponentData) |
| Logic | Methods on MonoBehaviour | Systems (ISystem / SystemBase) |
| Memory layout | Scattered across heap | Contiguous chunks by archetype |
| Threading | Main thread only | Jobs + Burst for parallel work |

### Entities

Entities are lightweight identifiers (an index + version integer). They have no behavior and no data -- they are handles used to associate components.

### Components (IComponentData)

Components are unmanaged structs with no methods. They hold only data.

```csharp
using Unity.Entities;

public struct Speed : IComponentData
{
    public float Value;
}

public struct Health : IComponentData
{
    public float Current;
    public float Max;
}
```

### Archetypes and Chunks

An **archetype** is a unique combination of component types. All entities with the same set of components share an archetype. Entities are stored in **chunks** (16 KB blocks) grouped by archetype, enabling cache-efficient iteration.

### World and EntityManager

A `World` contains an `EntityManager` and a set of systems. The default world is created automatically. `EntityManager` is the primary API for creating/destroying entities and adding/removing components.

## Baking and SubScene Workflow

Baking converts authoring GameObjects into runtime entities. This is a one-way conversion that happens at build time or when a SubScene is loaded in the Editor.

### Baker<T>

```csharp
using Unity.Entities;

// Authoring component (MonoBehaviour on GameObject)
public class SpeedAuthoring : MonoBehaviour
{
    public float speed;
}

// Baker converts authoring data to ECS components
public class SpeedBaker : Baker<SpeedAuthoring>
{
    public override void Bake(SpeedAuthoring authoring)
    {
        var entity = GetEntity(TransformUsageFlags.Dynamic);
        AddComponent(entity, new Speed { Value = authoring.speed });
    }
}
```

### SubScene

- SubScenes contain GameObjects that are baked into entities at build time
- At runtime, entity data streams in efficiently (no GameObject overhead)
- In the Editor, SubScenes can be opened for editing (shows GameObjects) or closed (shows baked entities)
- Always place ECS-managed objects inside a SubScene

### TransformUsageFlags

| Flag | Use |
|------|-----|
| `Dynamic` | Entity moves at runtime (gets LocalTransform, LocalToWorld) |
| `Renderable` | Entity is rendered but not moved by code |
| `WorldSpace` | Entity uses world-space transform only |
| `None` | No transform components added |

## Systems

Systems contain all logic. They iterate over entities that match a component query.

### ISystem (Recommended)

ISystem is the modern, unmanaged system type. It is Burst-compatible and should be preferred over SystemBase.

```csharp
using Unity.Burst;
using Unity.Entities;
using Unity.Mathematics;
using Unity.Transforms;

[BurstCompile]
public partial struct MovementSystem : ISystem
{
    [BurstCompile]
    public void OnCreate(ref SystemState state)
    {
        state.RequireForUpdate<Speed>();
    }

    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        float deltaTime = SystemAPI.Time.DeltaTime;

        foreach (var (transform, speed) in
            SystemAPI.Query<RefRW<LocalTransform>, RefRO<Speed>>())
        {
            transform.ValueRW.Position +=
                new float3(0, 0, speed.ValueRO.Value * deltaTime);
        }
    }

    [BurstCompile]
    public void OnDestroy(ref SystemState state) { }
}
```

**Key points:**
- Must be a `partial struct`
- Use `[BurstCompile]` on the struct and each method
- `OnCreate`, `OnUpdate`, `OnDestroy` receive `ref SystemState`
- `state.RequireForUpdate<T>()` -- system only runs when T exists
- `SystemAPI.Query<T>()` -- type-safe foreach iteration

### SystemBase (Managed, Legacy)

SystemBase is a managed class-based system. It supports managed code but cannot be Burst-compiled at the system level. Use ISystem for all new code. SystemBase uses `Entities.ForEach()` lambda syntax instead of `SystemAPI.Query`.

### SystemGroup and Update Ordering

Systems are organized into groups that update in a defined order:

```
InitializationSystemGroup
  -> BeginInitializationEntityCommandBufferSystem
SimulationSystemGroup (default group)
  -> BeginSimulationEntityCommandBufferSystem
  -> [Your systems go here by default]
  -> EndSimulationEntityCommandBufferSystem
PresentationSystemGroup
  -> BeginPresentationEntityCommandBufferSystem
```

Control ordering with attributes:

```csharp
[UpdateInGroup(typeof(SimulationSystemGroup))]
[UpdateBefore(typeof(OtherSystem))]
[UpdateAfter(typeof(AnotherSystem))]
public partial struct MySystem : ISystem { }
```

### SystemAPI

`SystemAPI` provides static methods for safe, Burst-compatible access:

| Method | Purpose |
|--------|---------|
| `SystemAPI.Query<T1, T2>()` | Iterate matching entities |
| `SystemAPI.Time` | Access TimeData (DeltaTime, ElapsedTime) |
| `SystemAPI.GetSingleton<T>()` | Get singleton component value |
| `SystemAPI.SetSingleton<T>(value)` | Set singleton component value |
| `SystemAPI.GetComponent<T>(entity)` | Read component from entity |
| `SystemAPI.SetComponent<T>(entity, value)` | Write component on entity |
| `SystemAPI.HasComponent<T>(entity)` | Check if entity has component |
| `SystemAPI.GetComponentLookup<T>()` | Get random-access lookup |
| `SystemAPI.GetBuffer<T>(entity)` | Get DynamicBuffer |
| `SystemAPI.GetAspect<T>(entity)` | Get aspect for entity |

## Components Deep Dive

### IComponentData (Unmanaged Struct)

The fundamental component type. Must be an unmanaged struct (no reference types, no managed arrays).

### ISharedComponentData

Shared across entities -- entities with the same shared component value are grouped into the same chunk. Changing a shared component value is a structural change.

```csharp
public struct TeamId : ISharedComponentData
{
    public int Value;
}
```

### IBufferElementData (DynamicBuffer)

Variable-length arrays attached to entities.

```csharp
[InternalBufferCapacity(8)]
public struct DamageEvent : IBufferElementData
{
    public float Value;
    public Entity Source;
}

// Usage in a system
foreach (var (buffer, entity) in SystemAPI.Query<DynamicBuffer<DamageEvent>>()
    .WithEntityAccess())
{
    for (int i = 0; i < buffer.Length; i++)
        totalDamage += buffer[i].Value;
    buffer.Clear();
}
```

### ICleanupComponentData

Persists after entity destruction. Used for cleanup logic (e.g., releasing native resources). The entity is not fully destroyed until all cleanup components are removed.

### IEnableableComponent

Components that can be toggled on/off without structural changes (no chunk moves).

```csharp
public struct Stunned : IComponentData, IEnableableComponent { }

// Toggle in system
SystemAPI.SetComponentEnabled<Stunned>(entity, true);
bool isStunned = SystemAPI.IsComponentEnabled<Stunned>(entity);
```

### Tag Components

Zero-size structs used purely for filtering queries. No fields -- zero memory cost per entity.

```csharp
public struct IsPlayer : IComponentData { }
```

## Common Patterns

### Creating and Destroying Entities

```csharp
// Direct creation (structural change -- main thread only)
Entity e = entityManager.CreateEntity(typeof(Speed), typeof(Health));

// Preferred: use EntityCommandBuffer for deferred structural changes
var ecb = new EntityCommandBuffer(Allocator.TempJob);
Entity e2 = ecb.CreateEntity();
ecb.AddComponent(e2, new Speed { Value = 5f });
ecb.Playback(entityManager);
ecb.Dispose();
```

### EntityCommandBuffer (ECB)

Structural changes (create/destroy entity, add/remove component) cannot happen during iteration. Use ECB to defer them. See [references/ecs-api.md](references/ecs-api.md) for full ECB API.

### System-Managed ECB (Preferred)

```csharp
[BurstCompile]
public partial struct SpawnSystem : ISystem
{
    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        var ecbSingleton = SystemAPI.GetSingleton<
            EndSimulationEntityCommandBufferSystem.Singleton>();
        var ecb = ecbSingleton.CreateCommandBuffer(state.WorldUnmanaged);
        // ecb is played back automatically -- no Playback/Dispose needed
        foreach (var spawner in SystemAPI.Query<RefRW<Spawner>>())
        {
            if (spawner.ValueRO.Timer <= 0)
            {
                ecb.Instantiate(spawner.ValueRO.Prefab);
                spawner.ValueRW.Timer = spawner.ValueRO.Interval;
            }
        }
    }
}
```

### Singleton Components

Use when exactly one entity has a given component. Access via `SystemAPI.GetSingleton<T>()` / `SystemAPI.SetSingleton<T>(value)` / `SystemAPI.GetSingletonRW<T>()`. Useful for global config, game state, and similar one-of-a-kind data.

### Aspects (IAspect)

Aspects group related components into a single access wrapper with optional methods.

```csharp
public readonly partial struct CharacterAspect : IAspect
{
    public readonly RefRW<LocalTransform> Transform;
    public readonly RefRO<Speed> Speed;
    public readonly RefRW<Health> Health;

    public void Move(float3 direction, float deltaTime)
    {
        Transform.ValueRW.Position +=
            direction * Speed.ValueRO.Value * deltaTime;
    }
}

// Use in system
foreach (var character in SystemAPI.Query<CharacterAspect>())
{
    character.Move(new float3(1, 0, 0), deltaTime);
}
```

## Jobs System

### IJobEntity (Recommended)

Automatically generates an EntityQuery from the Execute parameter types.

```csharp
[BurstCompile]
public partial struct MoveJob : IJobEntity
{
    public float DeltaTime;

    void Execute(ref LocalTransform transform, in Speed speed)
    {
        transform.Position += new float3(0, 0, speed.Value * DeltaTime);
    }
}

// Schedule from system
[BurstCompile]
public partial struct MoveSystem : ISystem
{
    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        new MoveJob
        {
            DeltaTime = SystemAPI.Time.DeltaTime
        }.ScheduleParallel();
    }
}
```

### IJobChunk (Low-Level)

Manual chunk iteration for maximum control. See [references/jobs-burst.md](references/jobs-burst.md) for full examples.

### Job Scheduling

| Method | Behavior |
|--------|----------|
| `Run()` | Execute on main thread (no job scheduling) |
| `Schedule()` | Single-threaded job on worker thread |
| `ScheduleParallel()` | Multi-threaded across chunks |

### ECB in Parallel Jobs

```csharp
[BurstCompile]
public partial struct DestroyDeadJob : IJobEntity
{
    public EntityCommandBuffer.ParallelWriter ECB;

    void Execute([ChunkIndexInQuery] int sortKey, in Health health, Entity entity)
    {
        if (health.Current <= 0)
            ECB.DestroyEntity(sortKey, entity);
    }
}
```

## Burst Compiler

The Burst compiler translates IL/.NET bytecode into highly optimized native code using LLVM.

### Usage

Add `[BurstCompile]` to `ISystem` structs (and each method) and `IJobEntity` structs. Burst compiles them to optimized native code via LLVM.

### Restrictions

- **No managed types** (no `class`, `string`, `List<T>`, managed arrays)
- **No allocations** (no `new` for reference types)
- **No try/catch/finally**
- **No virtual methods or interfaces** (except job interfaces)
- **No static mutable fields** (use `SharedStatic<T>` instead)
- Must use `NativeContainer` types for collections

### Unity.Mathematics

Burst-optimized math library replacing `UnityEngine.Mathf` and `Vector3`:

```csharp
using Unity.Mathematics;

float3 position = new float3(1, 2, 3);
quaternion rot = quaternion.Euler(0, math.PI, 0);
float dist = math.distance(a, b);
float3 dir = math.normalize(b - a);
float val = math.lerp(0f, 1f, 0.5f);
```

| UnityEngine | Unity.Mathematics |
|-------------|-------------------|
| `Vector3` | `float3` |
| `Vector2` | `float2` |
| `Quaternion` | `quaternion` |
| `Mathf.Lerp` | `math.lerp` |
| `Mathf.Sin` | `math.sin` |
| `Matrix4x4` | `float4x4` |

## Anti-Patterns

| What | Why It's Wrong | Fix |
|------|---------------|-----|
| Using `SystemBase` when `ISystem` works | Cannot Burst-compile system, heap allocations | Use `ISystem` (partial struct) with `[BurstCompile]` |
| Structural changes during iteration | Invalidates iterators, causes exceptions | Use `EntityCommandBuffer` for deferred changes |
| Structural changes in parallel jobs without ECB | Race conditions, crashes | Use `EntityCommandBuffer.ParallelWriter` with sort key |
| Managed types in Burst-compiled code | Burst cannot compile managed types | Use unmanaged structs, `FixedString`, `NativeContainer` |
| Missing `[BurstCompile]` on ISystem | System runs as managed code, loses performance | Add `[BurstCompile]` to struct and all methods |
| Allocating `NativeArray` every frame without disposing | Memory leak | Allocate with `Allocator.Temp` or dispose in `OnDestroy` |
| Using `UnityEngine.Mathf` in Burst code | Not Burst-optimized | Use `Unity.Mathematics.math` |
| Forgetting `state.RequireForUpdate<T>()` | System runs even when no matching entities exist | Call in `OnCreate` to skip updates when unnecessary |
| Modifying `SharedComponentData` frequently | Each change is a structural change (chunk move) | Use regular `IComponentData` for frequently changing data |
| Using `GetComponent` in inner loops | Random access breaks cache coherency | Use `SystemAPI.Query` for linear iteration |

## Key API Quick Reference

| Class / Struct | Key Members | Notes |
|---------------|-------------|-------|
| `EntityManager` | `CreateEntity`, `DestroyEntity`, `AddComponent<T>`, `RemoveComponent<T>`, `GetComponentData<T>`, `SetComponentData<T>` | Main-thread only; structural changes |
| `EntityCommandBuffer` | `CreateEntity`, `DestroyEntity`, `AddComponent`, `RemoveComponent`, `Instantiate`, `Playback` | Deferred structural changes |
| `ECB.ParallelWriter` | Same as ECB but with `sortKey` parameter | Thread-safe for parallel jobs |
| `SystemAPI` | `Query<T>`, `Time`, `GetSingleton<T>`, `GetComponent<T>`, `GetComponentLookup<T>` | Static access from systems |
| `EntityQuery` | `ToEntityArray`, `ToComponentDataArray<T>`, `CalculateEntityCount` | Bulk operations |
| `IComponentData` | (marker interface) | Unmanaged struct components |
| `IBufferElementData` | (marker interface) | Dynamic buffer elements |
| `DynamicBuffer<T>` | `Add`, `RemoveAt`, `Length`, `Clear`, `AsNativeArray` | Variable-length per-entity arrays |
| `IJobEntity` | `Execute(ref T1, in T2, ...)` | Auto-generated query from params |
| `IJobChunk` | `Execute(in ArchetypeChunk, ...)` | Manual chunk iteration |
| `World` | `DefaultGameObjectInjectionWorld`, `EntityManager` | Container for systems + entities |
| `RefRW<T>` / `RefRO<T>` | `ValueRW` / `ValueRO` | Read-write / read-only component refs |

## Related Skills

- **unity-scripting** -- MonoBehaviour scripting, coroutines, async/await
- **unity-physics** -- Physics engine, Rigidbody, colliders (for Unity Physics ECS package)
- **unity-foundations** -- GameObjects, Transforms, Scenes, Prefabs

## Additional Resources

- See [references/ecs-api.md](references/ecs-api.md) for detailed Entity/Component API
- See [references/jobs-burst.md](references/jobs-burst.md) for Jobs and Burst deep dive
- [Unity Entities Manual](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/index.html)
- [Unity Burst Manual](https://docs.unity3d.com/Packages/com.unity.burst@1.8/manual/index.html)
- [Unity Jobs Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/job-system.html)
- [Unity Entities API Reference](https://docs.unity3d.com/Packages/com.unity.entities@1.3/api/index.html)
