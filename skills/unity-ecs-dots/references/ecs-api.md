# ECS API Reference

> Source: [Unity Entities 1.3 API](https://docs.unity3d.com/Packages/com.unity.entities@1.3/api/index.html)

## EntityManager

`EntityManager` is the primary API for creating, destroying, and modifying entities. All methods execute immediately and are main-thread only. Structural changes invalidate any active queries or enumerators.

### Creating Entities

```csharp
using Unity.Entities;
using Unity.Collections;

// Create empty entity
Entity entity = entityManager.CreateEntity();

// Create with specific components
Entity entity = entityManager.CreateEntity(typeof(Speed), typeof(Health));

// Create from archetype (most efficient for batch creation)
EntityArchetype archetype = entityManager.CreateArchetype(
    typeof(LocalTransform), typeof(Speed), typeof(Health));
Entity entity = entityManager.CreateEntity(archetype);

// Batch create
NativeArray<Entity> entities = entityManager.CreateEntity(
    archetype, 1000, Allocator.Temp);
```

### Adding and Removing Components

```csharp
entityManager.AddComponent<Speed>(entity);
entityManager.AddComponentData(entity, new Speed { Value = 10f });

// Add multiple components at once
var types = new ComponentTypeSet(typeof(Speed), typeof(Health));
entityManager.AddComponent(entity, types);

entityManager.RemoveComponent<Speed>(entity);
bool hasSpeed = entityManager.HasComponent<Speed>(entity);
```

### Getting and Setting Component Data

```csharp
Speed speed = entityManager.GetComponentData<Speed>(entity);
entityManager.SetComponentData(entity, new Speed { Value = 20f });

// Shared components
TeamId team = entityManager.GetSharedComponentManaged<TeamId>(entity);
entityManager.SetSharedComponentManaged(entity, new TeamId { Value = 2 });
// Note: setting shared component is a structural change
```

### Destroying Entities

```csharp
entityManager.DestroyEntity(entity);
entityManager.DestroyEntity(entityQuery);     // All matching
entityManager.DestroyEntity(entityArray);     // Batch
```

### Enabling / Disabling Components

```csharp
// For components implementing IEnableableComponent
entityManager.SetComponentEnabled<Stunned>(entity, false);
bool enabled = entityManager.IsComponentEnabled<Stunned>(entity);
```

## EntityCommandBuffer (ECB)

ECB records structural changes to be played back later. Essential for deferring changes during iteration or from jobs.

### Basic Usage

```csharp
var ecb = new EntityCommandBuffer(Allocator.TempJob);

Entity e = ecb.CreateEntity();
ecb.AddComponent(e, new Speed { Value = 5f });
ecb.AddComponent<Health>(e);

ecb.Playback(entityManager);
ecb.Dispose();               // Always dispose
```

### Full API

| Method | Description |
|--------|-------------|
| `CreateEntity()` | Records entity creation; returns a temporary Entity |
| `Instantiate(Entity prefab)` | Records instantiation of a prefab entity |
| `DestroyEntity(Entity)` | Records entity destruction |
| `AddComponent<T>(Entity)` | Records adding a component |
| `AddComponent<T>(Entity, T value)` | Records adding a component with value |
| `RemoveComponent<T>(Entity)` | Records removing a component |
| `SetComponent<T>(Entity, T value)` | Records setting a component value |
| `AppendToBuffer<T>(Entity, T element)` | Appends element to DynamicBuffer |
| `SetBuffer<T>(Entity)` | Returns a DynamicBuffer for recording buffer operations |
| `Playback(EntityManager)` | Executes all recorded commands |
| `Dispose()` | Frees native memory |

### ParallelWriter

For use in parallel jobs. Every method requires a `sortKey` parameter for deterministic ordering.

```csharp
[BurstCompile]
public partial struct SpawnJob : IJobEntity
{
    public EntityCommandBuffer.ParallelWriter ECB;
    public Entity Prefab;

    void Execute([ChunkIndexInQuery] int sortKey, in Spawner spawner)
    {
        if (spawner.ShouldSpawn)
        {
            Entity e = ECB.Instantiate(sortKey, Prefab);
            ECB.AddComponent(sortKey, e, new Speed { Value = spawner.Speed });
        }
    }
}

// Create ParallelWriter from ECB
var ecb = new EntityCommandBuffer(Allocator.TempJob);
var parallelWriter = ecb.AsParallelWriter();
```

### System-Managed ECB

Use `EndSimulationEntityCommandBufferSystem` for automatic playback:

```csharp
var ecbSingleton = SystemAPI.GetSingleton<
    EndSimulationEntityCommandBufferSystem.Singleton>();
var ecb = ecbSingleton.CreateCommandBuffer(state.WorldUnmanaged);
// Commands play back automatically -- no Playback or Dispose needed
```

## EntityQuery

EntityQuery filters entities by component types for bulk operations and system filtering.

### Builder Pattern

```csharp
_query = new EntityQueryBuilder(Allocator.Temp)
    .WithAll<Speed, Health>()           // Must have both
    .WithAny<FireDamage, IceDamage>()   // Must have at least one
    .WithNone<Dead>()                   // Must not have
    .WithOptions(EntityQueryOptions.IncludeDisabledEntities)
    .Build(ref state);
```

### Query Methods

| Method | Description |
|--------|-------------|
| `WithAll<T1, T2>()` | Entity must have all specified components |
| `WithAny<T1, T2>()` | Entity must have at least one |
| `WithNone<T1, T2>()` | Entity must not have any |
| `WithDisabled<T>()` | Match entities where T is disabled |
| `WithPresent<T>()` | Match regardless of enabled state |

### Bulk Operations

```csharp
int count = query.CalculateEntityCount();
NativeArray<Entity> entities = query.ToEntityArray(Allocator.Temp);
NativeArray<Speed> speeds = query.ToComponentDataArray<Speed>(Allocator.Temp);
bool empty = query.IsEmpty;
```

## SystemAPI

Static methods available inside `ISystem` and `SystemBase` for type-safe, source-generated access.

### Query Iteration

```csharp
// Basic foreach
foreach (var (transform, speed) in
    SystemAPI.Query<RefRW<LocalTransform>, RefRO<Speed>>())
{
    transform.ValueRW.Position.y += speed.ValueRO.Value * deltaTime;
}

// With entity access
foreach (var (health, entity) in
    SystemAPI.Query<RefRO<Health>>().WithEntityAccess())
{
    if (health.ValueRO.Current <= 0)
        ecb.DestroyEntity(entity);
}

// With filtering
foreach (var speed in
    SystemAPI.Query<RefRW<Speed>>()
        .WithAll<IsPlayer>()
        .WithNone<Dead>())
{
    speed.ValueRW.Value *= 1.1f;
}
```

### Component Access and Singletons

```csharp
// Random access by entity
Speed s = SystemAPI.GetComponent<Speed>(entity);
SystemAPI.SetComponent(entity, new Speed { Value = 5f });
bool has = SystemAPI.HasComponent<Speed>(entity);

// Component lookup (for random access in jobs)
ComponentLookup<Health> lookup = SystemAPI.GetComponentLookup<Health>(true);

// Singletons (exactly one entity must have this component)
GameConfig config = SystemAPI.GetSingleton<GameConfig>();
SystemAPI.SetSingleton(new GameConfig { Gravity = -9.81f });
Entity configEntity = SystemAPI.GetSingletonEntity<GameConfig>();
bool exists = SystemAPI.HasSingleton<GameConfig>();
```

## DynamicBuffer<T>

Variable-length, per-entity arrays for components implementing `IBufferElementData`.

```csharp
[InternalBufferCapacity(8)] // Elements stored inline before heap fallback
public struct WaypointElement : IBufferElementData
{
    public float3 Position;
}
```

### Operations

```csharp
entityManager.AddBuffer<WaypointElement>(entity);
DynamicBuffer<WaypointElement> buffer = SystemAPI.GetBuffer<WaypointElement>(entity);

buffer.Add(new WaypointElement { Position = new float3(1, 0, 0) });
buffer.RemoveAt(0);
buffer.Insert(0, new WaypointElement { Position = float3.zero });
int count = buffer.Length;
buffer.Clear();
buffer.TrimExcess();

NativeArray<WaypointElement> array = buffer.AsNativeArray(); // No copy
DynamicBuffer<float3> positions = buffer.Reinterpret<float3>(); // Zero-copy cast
```

## Aspects (IAspect)

Aspects bundle related components into a reusable access wrapper with optional methods.

```csharp
public readonly partial struct CharacterAspect : IAspect
{
    public readonly RefRW<LocalTransform> Transform;
    public readonly RefRO<Speed> Speed;
    public readonly RefRW<Health> Health;
    [Optional] public readonly RefRO<Shield> Shield;
    public readonly Entity Entity;

    public void Move(float3 direction, float deltaTime)
    {
        Transform.ValueRW.Position +=
            direction * Speed.ValueRO.Value * deltaTime;
    }
}

// Use in query, jobs, or direct access
foreach (var c in SystemAPI.Query<CharacterAspect>())
    c.Move(new float3(0, 0, 1), deltaTime);

CharacterAspect aspect = SystemAPI.GetAspect<CharacterAspect>(entity);
```

## Entity Prefabs and Instantiation

Prefab entities are baked via `GetEntity(authoring.prefab, TransformUsageFlags.Dynamic)` in a Baker. At runtime, instantiate with `ecb.Instantiate(prefabEntity)`. Prefab entities have a `Prefab` tag and are excluded from queries by default -- use `EntityQueryOptions.IncludePrefab` to include them.
