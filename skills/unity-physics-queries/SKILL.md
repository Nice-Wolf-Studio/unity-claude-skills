---
name: unity-physics-queries
description: >
  Unity physics query correctness patterns. Catches common mistakes with Raycast, SphereCast,
  OverlapSphere, NonAlloc allocation, LayerMask construction, trigger interaction, hit ordering,
  and query type selection. PATTERN format: WHEN/WRONG/RIGHT/GOTCHA. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
---

# Physics Query Patterns -- Correctness Patterns

> **Prerequisite skills:** `unity-physics` (Rigidbody, colliders, raycasting API), `unity-foundations` (layers, GameObjects)

These patterns target the most common physics query bugs: using the wrong query type, misunderstanding allocation, and ignoring subtle defaults that cause silent failures.

---

## PATTERN: Query Type Selection

WHEN: Choosing which physics query to use

WRONG (Claude default):
```csharp
// Always defaulting to Raycast for everything
Physics.Raycast(origin, direction, out hit, maxDistance);
```

RIGHT -- use the decision tree:
```
Need to detect...
  |
  +-- "Is anything there?" (binary yes/no)
  |     --> CheckSphere, CheckBox, CheckCapsule (returns bool, cheapest)
  |
  +-- "What's the nearest thing along a line?"
  |     --> Raycast (single closest hit along an infinitely thin line)
  |
  +-- "What's the nearest thing along a volume?"
  |     --> SphereCast, BoxCast, CapsuleCast (sweep a shape, single closest hit)
  |
  +-- "Everything along a line?"
  |     --> RaycastAll / RaycastNonAlloc (all hits, not just closest)
  |
  +-- "Everything inside an area?"
        --> OverlapSphere, OverlapBox, OverlapCapsule (all colliders in region)
```

GOTCHA: `Raycast` only returns the **closest** hit. If you need to pierce through multiple objects, use `RaycastAll` or `RaycastNonAlloc`. If you need to detect everything in an area (like an explosion radius), `OverlapSphere` is correct -- NOT `SphereCast`.

---

## PATTERN: Cast Origin Inside Collider

WHEN: A SphereCast/BoxCast/CapsuleCast starts overlapping an existing collider

WRONG (Claude default):
```csharp
// Expecting to detect the ground when the sphere starts inside it
if (Physics.SphereCast(feetPosition, radius, Vector3.down, out hit, 0.1f))
{
    grounded = true; // May MISS if sphere starts inside the ground collider
}
```

RIGHT:
```csharp
// Casts do NOT detect colliders that the shape starts inside of
// Use Overlap for "what am I currently touching?"
grounded = Physics.CheckSphere(feetPosition, radius, groundMask);

// Or use OverlapSphere to get the actual colliders:
Collider[] touching = Physics.OverlapSphere(feetPosition, radius, groundMask);
```

GOTCHA: This applies to ALL cast queries (SphereCast, BoxCast, CapsuleCast, Raycast). If the origin is inside a collider, that collider is ignored. This is the #1 source of "my ground check doesn't work" bugs. Raycasts that start inside a MeshCollider also miss it. Use `Overlap*` or `Check*` for current-overlap detection.

---

## PATTERN: Hit Ordering Not Guaranteed

WHEN: Using `RaycastAll` or `RaycastNonAlloc` and expecting sorted results

WRONG (Claude default):
```csharp
RaycastHit[] hits = Physics.RaycastAll(origin, direction, maxDist);
// Assuming hits[0] is the closest
ProcessHit(hits[0]);
```

RIGHT:
```csharp
RaycastHit[] hits = Physics.RaycastAll(origin, direction, maxDist);
// Results are NOT sorted by distance -- sort manually
System.Array.Sort(hits, (a, b) => a.distance.CompareTo(b.distance));
if (hits.Length > 0)
    ProcessHit(hits[0]); // Now this is the closest
```

GOTCHA: Regular `Physics.Raycast` (single hit) always returns the closest. Only `RaycastAll` and `RaycastNonAlloc` return unsorted results. The same applies to `SphereCastAll`/`SphereCastNonAlloc`, etc. For `NonAlloc`, sort only up to the returned count, not the full buffer.

---

## PATTERN: NonAlloc Buffer Size and Return Count

WHEN: Using `RaycastNonAlloc`, `OverlapSphereNonAlloc`, or similar zero-allocation queries

WRONG (Claude default):
```csharp
// Buffer of 1 -- silently drops extra results
RaycastHit[] buffer = new RaycastHit[1];
int count = Physics.RaycastNonAlloc(ray, buffer, maxDist);
```

RIGHT:
```csharp
// Pre-allocate a reasonably sized buffer as a class field
private readonly RaycastHit[] _hitBuffer = new RaycastHit[16];

void DetectHits()
{
    int count = Physics.RaycastNonAlloc(ray, _hitBuffer, maxDist, layerMask);

    // ONLY iterate up to count, not buffer.Length
    for (int i = 0; i < count; i++)
    {
        ProcessHit(_hitBuffer[i]);
    }

    // If count == buffer.Length, you may have missed results
    if (count == _hitBuffer.Length)
        Debug.LogWarning("Hit buffer full -- may have missed results");
}
```

GOTCHA: `NonAlloc` fills the provided buffer and returns how many results were written. If there are more results than buffer capacity, extras are **silently dropped** with no error. Size your buffer to the maximum expected results for your use case. Common sizes: ground check = 4, explosion radius = 32, broad scan = 64.

---

## PATTERN: LayerMask Bitshift vs GetMask

WHEN: Constructing a layer mask for physics queries

WRONG (Claude default):
```csharp
// DOUBLE-SHIFTING: GetMask already returns a bitmask, not a layer index
int mask = 1 << LayerMask.GetMask("Ground"); // WRONG -- shifts a bitmask by a bitmask amount
```

RIGHT:
```csharp
// GetMask returns the final bitmask -- use directly
int groundMask = LayerMask.GetMask("Ground");
int multiMask = LayerMask.GetMask("Ground", "Water", "Default");

// NameToLayer returns the layer INDEX -- this one needs the shift
int groundLayer = LayerMask.NameToLayer("Ground"); // Returns e.g. 8
int groundMask2 = 1 << groundLayer;                // Correct: 1 << 8 = 256

// Combining with bitwise OR
int combinedMask = (1 << LayerMask.NameToLayer("Ground")) | (1 << LayerMask.NameToLayer("Water"));

// Inverting a mask (everything EXCEPT these layers)
int everythingButGround = ~LayerMask.GetMask("Ground");
```

GOTCHA: `LayerMask.GetMask("Ground")` = bitmask (e.g., 256). `LayerMask.NameToLayer("Ground")` = index (e.g., 8). `gameObject.layer` = index. Passing a layer **index** where a **mask** is expected (or vice versa) silently filters wrong layers with no error.

---

## PATTERN: QueryTriggerInteraction Default

WHEN: Raycasts or other queries are unexpectedly hitting trigger colliders

WRONG (Claude default):
```csharp
// Assuming triggers are ignored by queries
if (Physics.Raycast(origin, direction, out hit, maxDist, layerMask))
{
    // hit.collider might be a trigger!
}
```

RIGHT:
```csharp
// Explicitly control trigger interaction
if (Physics.Raycast(origin, direction, out hit, maxDist, layerMask, QueryTriggerInteraction.Ignore))
{
    // Guaranteed to only hit non-trigger colliders
}

// Or check at the hit level
if (Physics.Raycast(origin, direction, out hit, maxDist, layerMask))
{
    if (!hit.collider.isTrigger)
    {
        // Process only non-trigger hits
    }
}
```

GOTCHA: The default is `QueryTriggerInteraction.UseGlobal`, which reads from `Physics.queriesHitTriggers`. That global default is **true** -- meaning queries DO hit triggers by default. This catches many developers off guard. Set it explicitly when trigger hits would cause bugs (ground checks, line-of-sight, bullet traces).

---

## PATTERN: SphereCast Radius vs Distance

WHEN: Using SphereCast and confusing the parameters

WRONG (Claude default):
```csharp
// Confusing parameters: treating radius as detection range
Physics.SphereCast(origin, detectionRange, direction, out hit);
// This creates a sphere with radius=detectionRange that travels infinitely far
```

RIGHT:
```csharp
// radius = SIZE of the sphere being swept
// maxDistance = how FAR the sphere travels
float sphereRadius = 0.5f;
float castDistance = 10f;
if (Physics.SphereCast(origin, sphereRadius, direction, out hit, castDistance, layerMask))
{
    // hit.distance = distance the sphere CENTER traveled, not the surface
    // hit.point = point on the surface of the OTHER collider (not the sphere)
}
```

GOTCHA: `hit.distance` is the distance the sphere's center traveled before contact, NOT the total distance from origin to the hit surface. The actual contact surface is at `hit.point`. A SphereCast with `radius=0` behaves like a Raycast. If the sphere is very large and the cast distance is short, you may miss nearby objects due to the "origin inside collider" issue.

---

## PATTERN: CapsuleCast Point Parameters

WHEN: Setting up CapsuleCast endpoints

WRONG (Claude default):
```csharp
// Using center + full height
Physics.CapsuleCast(center, center + Vector3.up * height, radius, direction, out hit);
```

RIGHT:
```csharp
// point1 and point2 are the centers of the two HEMISPHERES (not the full endpoints)
// For a character with height 2.0 and radius 0.5:
float height = 2.0f;
float radius = 0.5f;
Vector3 point1 = center + Vector3.up * (height * 0.5f - radius); // Top hemisphere center
Vector3 point2 = center - Vector3.up * (height * 0.5f - radius); // Bottom hemisphere center
Physics.CapsuleCast(point1, point2, radius, direction, out hit, maxDistance, layerMask);
```

GOTCHA: The total capsule height = `|point2 - point1| + 2 * radius`. If point1 == point2, it degenerates into a SphereCast. The CapsuleCollider component defines this differently (center + height + radius), so translating from a CapsuleCollider requires: `point1 = center + up * (height/2 - radius)`, `point2 = center - up * (height/2 - radius)`.

---

## PATTERN: Backface Detection

WHEN: Raycasting against MeshColliders from behind

WRONG (Claude default):
```csharp
// Assuming raycasts hit both sides of a mesh triangle
if (Physics.Raycast(insidePoint, direction, out hit))
{
    // May not hit if ray goes through backface of MeshCollider
}
```

RIGHT:
```csharp
// Enable backface hits globally (affects all queries)
Physics.queriesHitBackfaces = true;

// Or design around it:
// Convex MeshColliders are always hit from both sides
// Primitive colliders (Box, Sphere, Capsule) are always hit from both sides
// Only non-convex MeshColliders have single-sided detection by default
```

GOTCHA: By default, `Physics.queriesHitBackfaces = false`. This only affects **non-convex MeshColliders**. Box, Sphere, Capsule, and convex MeshColliders detect hits from any direction. If you need to raycast from inside a non-convex mesh (e.g., room interior), either enable backface queries or use a convex collider for the interior.

---

## PATTERN: Scene-Specific Queries

WHEN: Using additive scenes with separate physics simulations

WRONG (Claude default):
```csharp
// Global queries search ALL physics scenes
Collider[] results = Physics.OverlapSphere(center, radius);
```

RIGHT:
```csharp
// Get the physics scene for a specific Unity scene
PhysicsScene physScene = gameObject.scene.GetPhysicsScene();

// Query only within that physics scene
RaycastHit hit;
if (physScene.Raycast(origin, direction, out hit, maxDist, layerMask))
{
    // Only hits colliders in this physics scene
}

// OverlapSphere with scene scope
Collider[] buffer = new Collider[32];
int count = physScene.OverlapSphere(center, radius, buffer, layerMask);
```

GOTCHA: By default, all scenes share the same `Physics.defaultPhysicsScene`. Scene-specific physics only matters when you explicitly create scenes with `LocalPhysicsMode.Physics3D`. Most projects never need this -- but it's critical for multiplayer prediction, parallel simulations, or editor preview scenes.

---

## Anti-Patterns Quick Reference

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `Physics.Raycast` in `Update` without layer mask | Hits everything including UI colliders | Always pass a `LayerMask` parameter |
| Allocating `new RaycastHit[]` every frame | GC pressure | Use `NonAlloc` with a cached buffer |
| `OverlapSphere` with radius 0 | Returns nothing | Radius must be > 0; use `CheckSphere` for point checks |
| Comparing `hit.distance` across different query types | SphereCast distance != Raycast distance | SphereCast distance is center travel, not surface distance |
| Using `maxDistance = Mathf.Infinity` | Queries entire scene, expensive | Use a reasonable max distance for your use case |
| Forgetting `QueryTriggerInteraction.Ignore` on ground checks | Trigger volumes falsely report "grounded" | Pass `QueryTriggerInteraction.Ignore` explicitly |

## Related Skills

- **unity-physics** -- Rigidbody, colliders, collision/trigger events, physics settings API
- **unity-3d-math** -- Raycasting projection, Plane math, coordinate spaces
- **unity-performance** -- Profiling physics queries, optimization patterns

## Additional Resources

- [Physics.Raycast](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.Raycast.html)
- [Physics.SphereCast](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.SphereCast.html)
- [Physics.OverlapSphere](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.OverlapSphere.html)
- [Physics.RaycastNonAlloc](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.RaycastNonAlloc.html)
- [QueryTriggerInteraction](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/QueryTriggerInteraction.html)
- [PhysicsScene](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/PhysicsScene.html)
