---
name: unity-3d-math
description: >
  Unity 3D math correctness patterns. Catches common mistakes with coordinate spaces, Quaternion,
  Vector3, Plane, Bounds, Transform hierarchies, raycasting projection, and floating-point precision.
  PATTERN format: WHEN/WRONG/RIGHT/GOTCHA. Based on Unity 6.3 LTS documentation.
globs:
  - "**/*.cs"
---

# 3D Math & Spatial Reasoning -- Correctness Patterns

> **Prerequisite skills:** `unity-scripting` (Vector3/Quaternion API), `unity-foundations` (Transform, GameObjects), `unity-physics` (raycasting basics)

These patterns target the most dangerous Claude failure mode: **plausible-looking math that compiles but produces wrong results**. Each pattern documents Claude's default mistake and the correct Unity approach.

---

## PATTERN: Coordinate Space -- TransformPoint vs TransformDirection

WHEN: Converting between local and world space

WRONG (Claude default):
```csharp
// Using TransformDirection for a position offset
Vector3 worldPos = transform.TransformDirection(localOffset);
```

RIGHT:
```csharp
// Positions: TransformPoint (applies position + rotation + scale)
Vector3 worldPos = transform.TransformPoint(localOffset);

// Directions: TransformDirection (applies rotation only, ignores scale)
Vector3 worldDir = transform.TransformDirection(localDir);

// Vectors: TransformVector (applies rotation + scale, no position)
Vector3 worldVec = transform.TransformVector(localVec);
```

GOTCHA: `TransformDirection` ignores scale -- if the parent has non-uniform scale and you need the direction scaled, use `TransformVector`. For the inverse operations, use `InverseTransformPoint`, `InverseTransformDirection`, `InverseTransformVector`.

---

## PATTERN: Quaternion Multiplication Order

WHEN: Combining rotations (e.g., applying a local rotation on top of a world rotation)

WRONG (Claude default):
```csharp
// "First rotate by A, then rotate by B"
transform.rotation = rotA * rotB; // Actually applies B first, then A
```

RIGHT:
```csharp
// Quaternion multiplication applies RIGHT operand first
// "Apply B in A's space" = A * B
// Parent-then-child: parent * child
transform.rotation = worldRotation * localRotation;

// Example: rotate 45 degrees around Y, then tilt 30 degrees around local X
Quaternion yaw = Quaternion.AngleAxis(45f, Vector3.up);
Quaternion pitch = Quaternion.AngleAxis(30f, Vector3.right);
transform.rotation = yaw * pitch; // yaw is applied in world, pitch in yaw's local space
```

GOTCHA: This is the opposite of matrix multiplication reading order. If you think "first A then B", write `A * B` -- the right operand is applied in the left operand's local space.

---

## PATTERN: Euler Angle Interpolation (Gimbal Lock)

WHEN: Smoothly rotating between two orientations

WRONG (Claude default):
```csharp
// Interpolating euler angles directly
Vector3 currentEuler = Vector3.Lerp(startEuler, endEuler, t);
transform.eulerAngles = currentEuler;
```

RIGHT:
```csharp
// Always interpolate quaternions, never euler angles
transform.rotation = Quaternion.Slerp(startRot, endRot, t);

// For small angles where performance matters, Lerp is acceptable
transform.rotation = Quaternion.Lerp(startRot, endRot, t); // Slightly faster, less accurate for large arcs
```

GOTCHA: Euler angles suffer from gimbal lock at 90-degree pitch and have discontinuities (e.g., 359 to 1 degree jumps through 358 degrees instead of 2). `Quaternion.Slerp` always takes the shortest path. Use `Quaternion.Lerp` only when the angular difference is small (< 45 degrees).

---

## PATTERN: Quaternion.LookRotation Zero Vector

WHEN: Rotating an object to face a target direction

WRONG (Claude default):
```csharp
Vector3 dir = target.position - transform.position;
transform.rotation = Quaternion.LookRotation(dir);
```

RIGHT:
```csharp
Vector3 dir = target.position - transform.position;
if (dir.sqrMagnitude > 0.0001f) // Guard against zero/near-zero vector
{
    transform.rotation = Quaternion.LookRotation(dir, Vector3.up);
}
```

GOTCHA: `LookRotation(Vector3.zero)` produces `NaN` quaternion that silently corrupts the transform. The `forward` parameter does not need to be normalized (Unity normalizes internally), but it MUST be non-zero. Also fails if `forward` is exactly parallel to `up` -- the second parameter defaults to `Vector3.up`, which breaks if the target is directly above/below.

---

## PATTERN: Never Modify Quaternion Components Directly

WHEN: Trying to zero out or modify a specific rotation axis

WRONG (Claude default):
```csharp
// "Remove the X rotation"
Quaternion rot = transform.rotation;
rot.x = 0f;
transform.rotation = rot;
```

RIGHT:
```csharp
// Extract euler, modify, rebuild
Vector3 euler = transform.eulerAngles;
euler.x = 0f;
transform.rotation = Quaternion.Euler(euler);

// Or use Quaternion factory methods
// Keep only Y rotation:
transform.rotation = Quaternion.Euler(0f, transform.eulerAngles.y, 0f);
```

GOTCHA: Quaternion x/y/z/w are NOT euler angles. They are components of a 4D unit quaternion. Setting `.x = 0` produces a non-unit quaternion with undefined behavior. Always use factory methods: `Quaternion.Euler()`, `Quaternion.AngleAxis()`, `Quaternion.LookRotation()`.

---

## PATTERN: Float Comparison

WHEN: Comparing positions, distances, or any floating-point values

WRONG (Claude default):
```csharp
if (transform.position == targetPosition) { /* arrived */ }
if (distance == 0f) { /* overlapping */ }
```

RIGHT:
```csharp
// For positions: use sqrMagnitude with epsilon
if ((transform.position - targetPosition).sqrMagnitude < 0.0001f) { /* arrived */ }

// For single floats: use Mathf.Approximately
if (Mathf.Approximately(distance, 0f)) { /* close enough */ }

// For custom tolerance:
const float epsilon = 0.01f;
if (Mathf.Abs(a - b) < epsilon) { /* within tolerance */ }
```

GOTCHA: `Vector3 == Vector3` in Unity does use an approximate comparison internally (epsilon ~1e-5), but it is often too tight for gameplay logic. Use explicit thresholds matching your game's precision needs. Never use `==` with calculated floats that accumulated error.

---

## PATTERN: Vector3.Angle is Always Positive

WHEN: Determining turn direction (left vs right, clockwise vs counter-clockwise)

WRONG (Claude default):
```csharp
float angle = Vector3.Angle(transform.forward, dirToTarget);
// angle is always 0-180, cannot tell left from right
```

RIGHT:
```csharp
// SignedAngle returns -180 to +180 relative to the specified axis
float signedAngle = Vector3.SignedAngle(transform.forward, dirToTarget, Vector3.up);
// Positive = target is to the right, Negative = target is to the left (when axis is up)
```

GOTCHA: The sign depends on the `axis` parameter. With `Vector3.up` as axis: positive = clockwise when viewed from above. Choose the axis that matches your rotation plane. For 2D games using XY plane, use `Vector3.forward` as the axis.

---

## PATTERN: Cross Product Order and Handedness

WHEN: Computing normals, perpendicular vectors, or winding order

WRONG (Claude default):
```csharp
// Assuming right-hand rule
Vector3 normal = Vector3.Cross(edge1, edge2);
```

RIGHT:
```csharp
// Unity uses a LEFT-handed coordinate system (Y-up, Z-forward)
// Cross product follows LEFT-hand rule:
// Cross(right, forward) = UP (not down)
Vector3 normal = Vector3.Cross(edge1, edge2);
// If normal points wrong way, swap operand order:
Vector3 flippedNormal = Vector3.Cross(edge2, edge1);
```

GOTCHA: Unity is left-handed (Y-up, X-right, Z-forward). OpenGL/Blender are right-handed. If you're porting math from a right-handed reference, you need to flip the cross product order OR negate one axis. Triangle winding is clockwise = front-facing in Unity.

---

## PATTERN: sqrMagnitude for Distance Comparisons

WHEN: Comparing distances in performance-sensitive code (Update loops, many objects)

WRONG (Claude default):
```csharp
// Vector3.Distance computes a square root every call
if (Vector3.Distance(a, b) < detectionRange)
{
    // detected
}
```

RIGHT:
```csharp
// Compare squared distances -- avoids sqrt
float sqrRange = detectionRange * detectionRange;
if ((a - b).sqrMagnitude < sqrRange)
{
    // detected
}
```

GOTCHA: Cache `sqrRange` outside the loop -- do not recompute `range * range` per iteration. This optimization matters when checking N objects per frame (O(N) sqrt calls). For single checks, `Vector3.Distance` is perfectly fine -- do not micro-optimize one-off calls.

---

## PATTERN: Camera.ScreenToWorldPoint Z Depth

WHEN: Converting a screen position (mouse, touch) to a world position

WRONG (Claude default):
```csharp
// z=0 gives a point ON the camera's near plane, not in the scene
Vector3 worldPos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
```

RIGHT:
```csharp
// Set z to the desired distance from the camera
Vector3 screenPos = Input.mousePosition;
screenPos.z = desiredDistance; // Distance from camera along its forward axis
Vector3 worldPos = Camera.main.ScreenToWorldPoint(screenPos);
```

GOTCHA: The z component of the input vector is the distance from the camera in world units along the camera's forward direction. For perspective cameras, z=0 returns a point at the camera's position. For orthographic cameras, z doesn't affect x/y but still sets depth. To place objects on a ground plane, use `Physics.Raycast` with `Camera.ScreenPointToRay` instead.

---

## PATTERN: Camera.ViewportToWorldPoint

WHEN: Placing objects at viewport edges (HUD bounds, screen limits)

WRONG (Claude default):
```csharp
// Missing z depth -- returns a point at the camera
Vector3 topRight = Camera.main.ViewportToWorldPoint(new Vector3(1f, 1f, 0f));
```

RIGHT:
```csharp
// z = distance from camera where you want the world point
float distFromCamera = 10f;
Vector3 topRight = Camera.main.ViewportToWorldPoint(new Vector3(1f, 1f, distFromCamera));
Vector3 bottomLeft = Camera.main.ViewportToWorldPoint(new Vector3(0f, 0f, distFromCamera));
```

GOTCHA: Viewport coordinates are normalized: (0,0) = bottom-left, (1,1) = top-right. The z value is NOT a Z world coordinate -- it is the distance from the camera. This matters for perspective cameras where the frustum widens with distance.

---

## PATTERN: Plane.Raycast Semantics

WHEN: Finding where a ray intersects a mathematical plane

WRONG (Claude default):
```csharp
Plane groundPlane = new Plane(Vector3.up, 0f);
float enter;
groundPlane.Raycast(ray, out enter);
Vector3 hitPoint = ray.GetPoint(enter); // Using enter without checking return value
```

RIGHT:
```csharp
Plane groundPlane = new Plane(Vector3.up, 0f); // Normal=up, distance=0 (XZ plane at origin)
float enter;
if (groundPlane.Raycast(ray, out enter))
{
    Vector3 hitPoint = ray.GetPoint(enter);
}
// If returns false, the ray points away from the plane (enter is negative)
```

GOTCHA: `Plane.Raycast` returns `true` only when the ray intersects the plane's front side (the side the normal points toward). If the ray origin is behind the plane or pointing away, it returns `false` and `enter` is negative. The `Plane` constructor `new Plane(normal, distance)` -- the `distance` is the signed distance from origin along the normal. `new Plane(Vector3.up, 5f)` creates a plane at y = -5, NOT y = 5. Use `new Plane(Vector3.up, new Vector3(0, 5, 0))` for a plane at y = 5.

---

## PATTERN: Bounds is Always Axis-Aligned (AABB)

WHEN: Checking spatial overlap or containment of rotated objects

WRONG (Claude default):
```csharp
// Assuming bounds rotates with the object
if (renderer.bounds.Contains(point))
{
    // This is an AABB check, not an OBB check
}
```

RIGHT:
```csharp
// renderer.bounds is an AXIS-ALIGNED bounding box in WORLD space
// It expands to encompass the rotated mesh, making it larger than the actual object
Bounds aabb = renderer.bounds;

// For oriented checks, use the collider or manual OBB:
// Option 1: Use a collider (accurate to shape)
Collider col = GetComponent<Collider>();
Vector3 closest = col.ClosestPoint(point);
bool inside = (closest - point).sqrMagnitude < 0.0001f;

// Option 2: Transform point to local space for local-space AABB check
Vector3 localPoint = transform.InverseTransformPoint(point);
Bounds localBounds = meshFilter.sharedMesh.bounds; // Local-space bounds
bool containsLocal = localBounds.Contains(localPoint);
```

GOTCHA: `Renderer.bounds` returns world-space AABB. Rotating an object makes its AABB grow (a rotated cube's AABB is larger than the cube). `Mesh.bounds` is local-space. For `Bounds.Intersects(other)`, both must be in the same space. `Collider.bounds` is also AABB -- for precise shape checks use `Physics.ComputePenetration` or `Collider.ClosestPoint`.

---

## PATTERN: Transform Hierarchy Scale Inheritance

WHEN: Working with parent/child transforms that have non-uniform scale

WRONG (Claude default):
```csharp
// Assuming scale is independent
transform.localScale = Vector3.one; // Visually one-to-one? Not if parent is scaled
```

RIGHT:
```csharp
// lossyScale gives the approximate world-space scale (read-only)
Vector3 worldScale = transform.lossyScale;

// To set a specific world-space scale on a child:
Vector3 parentScale = transform.parent.lossyScale;
transform.localScale = new Vector3(
    desiredWorldScale.x / parentScale.x,
    desiredWorldScale.y / parentScale.y,
    desiredWorldScale.z / parentScale.z
);
```

GOTCHA: `lossyScale` is only approximate when the hierarchy contains rotation + non-uniform scale (skew). Unity does not support skew in transforms, so `lossyScale` may not perfectly represent the visual scale. Avoid non-uniform scale on parents of rotated children. `SetParent(parent, true)` preserves world position/rotation/scale; `SetParent(parent, false)` keeps local values -- choose intentionally.

---

## Common Patterns Quick Reference

| Need | Method | Space |
|------|--------|-------|
| Position local-to-world | `TransformPoint` | local -> world |
| Position world-to-local | `InverseTransformPoint` | world -> local |
| Direction local-to-world | `TransformDirection` | rotation only |
| Direction world-to-local | `InverseTransformDirection` | rotation only |
| Vector local-to-world | `TransformVector` | rotation + scale |
| Angle between vectors | `Vector3.Angle` | unsigned 0-180 |
| Signed angle | `Vector3.SignedAngle` | -180 to +180 |
| Dot product > 0 | vectors face same hemisphere | |
| Dot product == 0 | vectors are perpendicular | |
| Dot product < 0 | vectors face opposite directions | |
| Mouse to world ray | `Camera.ScreenPointToRay` | screen -> world |
| Mouse to world point | `ScreenToWorldPoint` + z depth | screen -> world |
| Viewport edge to world | `ViewportToWorldPoint` + z depth | viewport -> world |

## Related Skills

- **unity-scripting** -- Vector3, Quaternion, Time API reference
- **unity-foundations** -- Transform API, parent/child hierarchies
- **unity-physics** -- Raycasting, collider spatial queries
- **unity-physics-queries** -- Physics query correctness patterns

## Additional Resources

- [Vector3 API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Vector3.html)
- [Quaternion API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Quaternion.html)
- [Transform API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Transform.html)
- [Camera API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Camera.html)
- [Plane API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Plane.html)
- [Bounds API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Bounds.html)
