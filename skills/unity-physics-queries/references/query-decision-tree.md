# Physics Query Decision Tree & Reference

Detailed reference for choosing and optimizing physics queries. Supplements the PATTERN blocks in the parent SKILL.md.

## Complete Decision Tree

```
What do you need to know?
|
+-- "Is anything at this point/region?" (existence check)
|   |
|   +-- Point: CheckSphere(point, tiny_radius)
|   +-- Sphere: CheckSphere(center, radius, mask)
|   +-- Box: CheckBox(center, halfExtents, orientation, mask)
|   +-- Capsule: CheckCapsule(point1, point2, radius, mask)
|   |
|   Returns: bool (cheapest query, no hit data)
|
+-- "What is the nearest thing in a direction?" (single hit)
|   |
|   +-- Thin line: Raycast(origin, dir, out hit, maxDist, mask)
|   +-- Thick line: SphereCast(origin, radius, dir, out hit, maxDist, mask)
|   +-- Box sweep: BoxCast(center, halfExtents, dir, out hit, orient, maxDist, mask)
|   +-- Capsule sweep: CapsuleCast(p1, p2, radius, dir, out hit, maxDist, mask)
|   |
|   Returns: bool + RaycastHit (closest hit only)
|
+-- "What are ALL things in a direction?" (multiple hits)
|   |
|   +-- Thin line: RaycastAll / RaycastNonAlloc
|   +-- Thick line: SphereCastAll / SphereCastNonAlloc
|   +-- Box sweep: BoxCastAll / BoxCastNonAlloc
|   +-- Capsule sweep: CapsuleCastAll / CapsuleCastNonAlloc
|   |
|   Returns: RaycastHit[] (UNSORTED -- must sort by distance)
|
+-- "What is currently overlapping a region?" (area query)
    |
    +-- Sphere: OverlapSphere / OverlapSphereNonAlloc
    +-- Box: OverlapBox / OverlapBoxNonAlloc
    +-- Capsule: OverlapCapsule / OverlapCapsuleNonAlloc
    |
    Returns: Collider[] (all colliders touching the region)
```

---

## Cast vs Overlap Comparison

| Feature | Cast Queries | Overlap Queries |
|---------|-------------|-----------------|
| **Purpose** | "What will I hit if I move?" | "What is already here?" |
| **Returns** | `RaycastHit` (point, normal, distance) | `Collider[]` (just the colliders) |
| **Detects overlapping** | NO -- misses colliders at origin | YES -- that's the point |
| **Has direction** | YES -- sweeps along a direction | NO -- tests a static region |
| **Use case** | Bullet trace, movement prediction | Explosion radius, trigger zone |
| **Has NonAlloc** | Yes | Yes |

---

## NonAlloc Strategy

### Buffer Sizing Guide

| Use Case | Recommended Buffer Size | Rationale |
|----------|------------------------|-----------|
| Ground check | 4 | Rarely more than a few ground surfaces |
| Bullet pierce | 8 | Walls + enemies in a line |
| Explosion radius | 32 | Many objects in blast zone |
| Area scan / broad phase | 64 | Lots of potential targets |
| Editor/debug queries | 128 | Cast a wide net |

### Allocation Pattern

```csharp
public class PhysicsQueryCache : MonoBehaviour
{
    // Allocate ONCE as class fields -- reuse every frame
    private readonly RaycastHit[] _rayHits = new RaycastHit[16];
    private readonly Collider[] _overlapResults = new Collider[32];

    // Ground check example
    public bool IsGrounded(Vector3 feetPos, float radius, LayerMask groundMask)
    {
        int count = Physics.OverlapSphereNonAlloc(
            feetPos, radius, _overlapResults, groundMask,
            QueryTriggerInteraction.Ignore);
        return count > 0;
    }

    // Area damage example
    public void ApplyAreaDamage(Vector3 center, float radius, float damage, LayerMask mask)
    {
        int count = Physics.OverlapSphereNonAlloc(
            center, radius, _overlapResults, mask,
            QueryTriggerInteraction.Ignore);

        for (int i = 0; i < count; i++)
        {
            if (_overlapResults[i].TryGetComponent(out IDamageable target))
            {
                float dist = Vector3.Distance(center, _overlapResults[i].transform.position);
                float falloff = 1f - (dist / radius);
                target.TakeDamage(damage * falloff);
            }
        }
    }

    // Pierce-through raycast with sorted results
    public int RaycastSorted(Ray ray, float maxDist, LayerMask mask)
    {
        int count = Physics.RaycastNonAlloc(ray, _rayHits, maxDist, mask,
            QueryTriggerInteraction.Ignore);

        // Sort only the valid portion of the buffer
        if (count > 1)
            System.Array.Sort(_rayHits, 0, count,
                Comparer<RaycastHit>.Create((a, b) => a.distance.CompareTo(b.distance)));

        return count;
    }
}
```

---

## RaycastHit Data Reference

| Field | Type | Description | Notes |
|-------|------|-------------|-------|
| `point` | `Vector3` | World-space hit position | On the surface of the hit collider |
| `normal` | `Vector3` | Surface normal at hit point | Useful for reflections, alignment |
| `distance` | `float` | Distance from ray origin to hit | For SphereCast: center travel distance |
| `collider` | `Collider` | The collider that was hit | Never null if hit was valid |
| `rigidbody` | `Rigidbody` | Rigidbody of hit object | Null if no Rigidbody attached |
| `transform` | `Transform` | Transform of hit object | Same as `collider.transform` |
| `textureCoord` | `Vector2` | UV at hit point | Only for MeshColliders; requires mesh readable |
| `textureCoord2` | `Vector2` | Second UV channel | Only for MeshColliders |
| `triangleIndex` | `int` | Triangle index in mesh | Only for MeshColliders; -1 for others |
| `barycentricCoordinate` | `Vector3` | Barycentric coord on triangle | Only for MeshColliders |
| `articulationBody` | `ArticulationBody` | Articulation body if present | For robotics/complex joint chains |

---

## LayerMask Construction Cheat Sheet

```csharp
// By name (returns bitmask directly)
int mask = LayerMask.GetMask("Ground");
int multiMask = LayerMask.GetMask("Ground", "Water", "Interactable");

// By index (requires bitshift)
int layer = LayerMask.NameToLayer("Ground"); // Returns index (e.g., 8)
int mask = 1 << layer;                        // Convert to bitmask

// Combine masks
int combined = LayerMask.GetMask("Ground") | LayerMask.GetMask("Water");

// Exclude specific layers (everything BUT these)
int excludeUI = ~LayerMask.GetMask("UI");

// Include everything
int all = ~0; // or Physics.AllLayers

// SerializeField for Inspector assignment (RECOMMENDED)
[SerializeField] private LayerMask groundMask; // Set in Inspector -- safest approach
```

### Common Mistake: Layer Index vs Layer Mask

```csharp
// gameObject.layer is an INDEX (e.g., 8)
// LayerMask.GetMask returns a MASK (e.g., 256)

// WRONG: passing layer index where mask expected
Physics.Raycast(ray, out hit, 100f, gameObject.layer); // Layer 8 = bitmask for layer 3!

// RIGHT: convert index to mask
Physics.Raycast(ray, out hit, 100f, 1 << gameObject.layer);
```

---

## Physics Query Performance Tiers

From cheapest to most expensive:

1. **Check\*** (bool only) -- `CheckSphere`, `CheckBox`, `CheckCapsule`
2. **Single Cast** (one hit) -- `Raycast`, `SphereCast`, `BoxCast`
3. **Overlap** (area, multiple colliders) -- `OverlapSphere`, `OverlapBox`
4. **All/NonAlloc** (multiple hits along line) -- `RaycastNonAlloc`, `SphereCastAll`
5. **Allocating variants** (GC pressure) -- `RaycastAll`, `OverlapSphere` (non-NonAlloc)

**Rules of thumb:**
- Always prefer `NonAlloc` over allocating variants in Update loops
- Use `Check*` when you only need a yes/no answer
- Limit `maxDistance` to the smallest reasonable value
- Use `LayerMask` to exclude irrelevant layers early
- Profile with the Physics Debugger (Window > Analysis > Physics Debugger)
