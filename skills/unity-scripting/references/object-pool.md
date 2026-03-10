# ObjectPool<T> API Reference

> Unity 6.3 LTS (6000.3) — `UnityEngine.Pool` namespace
> [ObjectPool<T>](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Pool.ObjectPool_1.html)

## Overview

`ObjectPool<T>` is Unity's built-in generic object pooling solution (Unity 2021+). It eliminates repeated `Instantiate`/`Destroy` calls that cause GC allocations and frame spikes. Uses a stack-based collection internally.

**Not thread-safe** — use only on the main thread.

---

## Constructor

```csharp
public ObjectPool<T>(
    Func<T> createFunc,                   // Required: how to create new instances
    Action<T> actionOnGet = null,         // Called when retrieved from pool
    Action<T> actionOnRelease = null,     // Called when returned to pool
    Action<T> actionOnDestroy = null,     // Called when destroyed (over maxSize)
    bool collectionCheck = true,          // Detect double-release errors
    int defaultCapacity = 10,             // Initial capacity
    int maxSize = 10000                   // Max pooled objects
);
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `CountActive` | `int` | Objects currently in use (out of pool) |
| `CountInactive` | `int` | Objects available in pool |
| `CountAll` | `int` | Total (active + inactive) |

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Get()` | `T` | Get an object (creates if pool empty) |
| `Get(out PooledObject<T>)` | `PooledObject<T>` | Get with auto-release via `using` |
| `Release(T element)` | `void` | Return object to pool |
| `Clear()` | `void` | Clear pool, invoke `actionOnDestroy` on all |
| `Dispose()` | `void` | Same as `Clear()` |

---

## Common Patterns

### Projectile Pool

```csharp
using UnityEngine;
using UnityEngine.Pool;

public class BulletSpawner : MonoBehaviour
{
    [SerializeField] GameObject bulletPrefab;
    ObjectPool<GameObject> pool;

    void Awake()
    {
        pool = new ObjectPool<GameObject>(
            createFunc: () => Instantiate(bulletPrefab),
            actionOnGet: obj => obj.SetActive(true),
            actionOnRelease: obj => obj.SetActive(false),
            actionOnDestroy: obj => Destroy(obj),
            defaultCapacity: 20,
            maxSize: 100
        );
    }

    public GameObject SpawnBullet(Vector3 position, Quaternion rotation)
    {
        GameObject bullet = pool.Get();
        bullet.transform.SetPositionAndRotation(position, rotation);
        return bullet;
    }

    public void ReturnBullet(GameObject bullet) => pool.Release(bullet);
}
```

### Auto-Release with `using`

```csharp
using UnityEngine.Pool;

// PooledObject<T> auto-releases when disposed
using (pool.Get(out var bullet))
{
    // bullet is auto-returned to pool when scope exits
    bullet.transform.position = spawnPoint;
}
```

### Particle Effect Pool

```csharp
ObjectPool<ParticleSystem> vfxPool;

void Awake()
{
    vfxPool = new ObjectPool<ParticleSystem>(
        createFunc: () => {
            var go = Instantiate(explosionPrefab);
            var ps = go.GetComponent<ParticleSystem>();
            var main = ps.main;
            main.stopAction = ParticleSystemStopAction.Callback;
            return ps;
        },
        actionOnGet: ps => {
            ps.gameObject.SetActive(true);
            ps.Play();
        },
        actionOnRelease: ps => ps.gameObject.SetActive(false),
        actionOnDestroy: ps => Destroy(ps.gameObject)
    );
}

// On the ParticleSystem callback (OnParticleSystemStopped)
void OnParticleSystemStopped() => vfxPool.Release(GetComponent<ParticleSystem>());
```

---

## Other Pool Types in UnityEngine.Pool

| Class | Use Case |
|-------|----------|
| `LinkedPool<T>` | Same API as ObjectPool but uses linked list (lower memory fragmentation) |
| `CollectionPool<TCollection, TItem>` | Pool collections to avoid GC (e.g., `List<T>`) |
| `ListPool<T>` | Shortcut: `ListPool<int>.Get()` returns a pooled `List<int>` |
| `DictionaryPool<TKey, TValue>` | Pool `Dictionary` instances |
| `HashSetPool<T>` | Pool `HashSet` instances |
| `GenericPool<T>` | Static pool for `new()` constrained types |

### Using ListPool to Avoid Allocations

```csharp
using UnityEngine.Pool;

void ProcessNearbyEnemies()
{
    // Get a pooled list instead of new List<Collider>()
    var hits = ListPool<Collider>.Get();
    try
    {
        Physics.OverlapSphereNonAlloc(transform.position, 10f, tempArray);
        foreach (var col in tempArray)
            if (col != null) hits.Add(col);

        // Process hits...
    }
    finally
    {
        ListPool<Collider>.Release(hits); // Return to pool
    }
}
```

---

## Anti-Patterns

| What | Why It's Wrong | Fix |
|------|---------------|-----|
| Creating pool in `Update()` | New pool every frame | Create once in `Awake()` |
| Releasing same object twice | Exception if `collectionCheck` is on; corruption if off | Track active state or use `PooledObject<T>` |
| Not resetting state in `actionOnGet` | Stale data from previous use | Reset position, velocity, health, etc. in `actionOnGet` |
| Pool without maxSize | Unbounded growth after spike | Set reasonable `maxSize` |
| Destroying pooled objects | Pool loses track of them | Always `Release()` back to pool |
| Using ObjectPool for MonoBehaviours directly | Pool expects `T`, not `GameObject` | Pool the `GameObject`, get components from it |
