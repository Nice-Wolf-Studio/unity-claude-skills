# Spatial Math Deep Dive

Reference for advanced 3D math topics in Unity. Supplements the PATTERN blocks in the parent SKILL.md.

## Unity's Coordinate System

```
        +Y (up)
         |
         |
         |_______ +X (right)
        /
       /
      +Z (forward)

LEFT-HANDED coordinate system
- Positive rotation = CLOCKWISE when looking along the positive axis
- Triangle winding: CLOCKWISE = front-facing
```

**Comparison with other engines/tools:**

| System | Handedness | Up | Forward |
|--------|-----------|-----|---------|
| Unity | Left | +Y | +Z |
| Unreal | Left | +Z | +X |
| Blender | Right | +Z | -Y |
| OpenGL | Right | +Y | -Z |
| DirectX | Left | +Y | +Z |

When importing from Blender/OpenGL: Z and Y axes swap, and winding order may flip.

---

## Plane API Correctness

### Constructor Overloads

```csharp
// 1. Normal + distance from origin (CAREFUL: distance is negative of the dot product)
new Plane(Vector3.up, 0f);          // Plane at y=0 (XZ plane)
new Plane(Vector3.up, 5f);          // Plane at y=-5 (NOT y=5!)

// 2. Normal + point on plane (RECOMMENDED -- unambiguous)
new Plane(Vector3.up, new Vector3(0, 5, 0));  // Plane at y=5

// 3. Three points (computes normal from winding order)
new Plane(pointA, pointB, pointC);  // Normal follows left-hand rule
```

### Distance Sign Convention

`Plane.distance` stores the negative dot product of the normal and a point on the plane:
- `new Plane(Vector3.up, new Vector3(0, 5, 0))` produces `distance = -5`
- `plane.GetDistanceToPoint(point)` returns a **signed** distance: positive = same side as normal, negative = opposite side

### Common Operations

```csharp
Plane plane = new Plane(Vector3.up, Vector3.zero); // XZ plane at origin

// Which side is a point on?
bool abovePlane = plane.GetSide(point);             // true = same side as normal
float signedDist = plane.GetDistanceToPoint(point); // + above, - below

// Project a point onto the plane
Vector3 projected = point - plane.normal * plane.GetDistanceToPoint(point);

// Closest point on plane
Vector3 closest = plane.ClosestPointOnPlane(point);

// Flip the plane (reverse normal)
plane = plane.flipped;
```

---

## Bounds Intersection Math

### Bounds vs Collider.bounds vs Mesh.bounds

| Property | Space | Shape | Updates With Rotation |
|----------|-------|-------|----------------------|
| `Renderer.bounds` | World | AABB | Yes (expands) |
| `Collider.bounds` | World | AABB | Yes (expands) |
| `Mesh.bounds` | Local | AABB | No (static) |

### Intersection Tests

```csharp
Bounds a = rendererA.bounds;
Bounds b = rendererB.bounds;

// AABB overlap test (fast but imprecise for rotated objects)
bool overlaps = a.Intersects(b);

// Point containment
bool contains = a.Contains(point);

// Closest point on bounds surface
Vector3 closest = a.ClosestPoint(point);

// Ray intersection
float enter;
bool hit = a.IntersectRay(ray, out enter);
Vector3 hitPoint = ray.GetPoint(enter);

// Expand/shrink bounds
a.Expand(1f);            // Expand by 1 unit in all directions
a.Encapsulate(point);    // Grow to include point
a.Encapsulate(otherBounds); // Grow to include other bounds
```

### Manual OBB (Oriented Bounding Box) Check

```csharp
// Transform the test point into the object's local space
// Then check against the local-space mesh bounds
public static bool OBBContains(Transform objTransform, Mesh mesh, Vector3 worldPoint)
{
    Vector3 localPoint = objTransform.InverseTransformPoint(worldPoint);
    return mesh.bounds.Contains(localPoint);
}

// OBB vs OBB intersection (no built-in method -- use Physics.ComputePenetration
// or the Separating Axis Theorem for custom implementation)
```

---

## Camera Projection Patterns

### Screen, Viewport, and World Space

```
Screen Space:    (0,0) bottom-left pixel,  (Screen.width, Screen.height) top-right
Viewport Space:  (0,0) bottom-left,        (1,1) top-right (normalized)
World Space:     Scene coordinates
Clip Space:      (-1,-1) to (1,1) after projection (GPU space)
```

### Conversion Matrix

| From | To | Method |
|------|----|--------|
| Screen | World ray | `Camera.ScreenPointToRay(screenPos)` |
| Screen | World point | `Camera.ScreenToWorldPoint(new Vector3(x, y, zDepth))` |
| Screen | Viewport | `Camera.ScreenToViewportPoint(screenPos)` |
| Viewport | World point | `Camera.ViewportToWorldPoint(new Vector3(x, y, zDepth))` |
| Viewport | Screen | `Camera.ViewportToScreenPoint(viewportPos)` |
| World | Screen | `Camera.WorldToScreenPoint(worldPos)` |
| World | Viewport | `Camera.WorldToViewportPoint(worldPos)` |

### Mouse-to-Ground Pattern (3D)

```csharp
// Most reliable: Raycast against a physics plane
Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
Plane groundPlane = new Plane(Vector3.up, Vector3.zero);
if (groundPlane.Raycast(ray, out float enter))
{
    Vector3 groundPoint = ray.GetPoint(enter);
}

// Alternative: Raycast against colliders
if (Physics.Raycast(ray, out RaycastHit hit, 100f, groundLayerMask))
{
    Vector3 groundPoint = hit.point;
}
```

### Mouse-to-World Pattern (2D / Orthographic)

```csharp
// Orthographic: z depth determines the Z position in world
Vector3 screenPos = Input.mousePosition;
screenPos.z = 0f; // Z world position for the spawned object
Vector3 worldPos = Camera.main.ScreenToWorldPoint(screenPos);
// worldPos.z will be 0 (same as camera.transform.position.z + 0)

// For 2D: camera is typically at z=-10, so:
screenPos.z = 10f; // Distance from camera to z=0 plane
Vector3 worldPos2D = Camera.main.ScreenToWorldPoint(screenPos);
```

### Screen Bounds for Object Clamping

```csharp
// Get world-space bounds at a specific distance from camera
float dist = 10f;
Vector3 bottomLeft = Camera.main.ViewportToWorldPoint(new Vector3(0, 0, dist));
Vector3 topRight = Camera.main.ViewportToWorldPoint(new Vector3(1, 1, dist));

// Clamp an object within screen bounds
Vector3 pos = transform.position;
pos.x = Mathf.Clamp(pos.x, bottomLeft.x, topRight.x);
pos.y = Mathf.Clamp(pos.y, bottomLeft.y, topRight.y);
transform.position = pos;
```

---

## Floating-Point Precision at Large Distances

### The Problem

32-bit floats (`float`) have ~7 digits of precision. At large world positions, small movements lose precision:

| World Position | Smallest Representable Step | Visible Effect |
|---------------|---------------------------|----------------|
| 1,000 units | ~0.0001 | None |
| 10,000 units | ~0.001 | Minor jitter |
| 100,000 units | ~0.01 | Visible jitter |
| 1,000,000 units | ~0.1 | Severe jitter, physics breakdown |

### Mitigation Strategies

```csharp
// 1. Floating Origin: Periodically recenter the world around the player
void RecenterWorld()
{
    Vector3 offset = player.transform.position;
    offset.y = 0; // Keep Y stable

    // Move everything back toward origin
    foreach (Transform t in allRootObjects)
        t.position -= offset;

    // Shift tracking data (GPS coords, etc.) by the same offset
    worldOffset += offset;
}

// 2. Double-precision for world coordinates, float for local rendering
// Store true position as double, render relative to camera
double3 truePosition; // Use Unity.Mathematics double3
float3 renderPosition = (float3)(truePosition - cameraWorldPosition);
```

### When to Worry

- Open world games larger than ~10km: consider floating origin
- Space games: always use floating origin or relative rendering
- Indoor/arena games under 1km: standard float is fine
- Physics breaks noticeably before rendering does (~50,000 units)

---

## Dot Product Use Cases

```csharp
// 1. Is target in front or behind?
float dot = Vector3.Dot(transform.forward, (target.position - transform.position).normalized);
// dot > 0 = in front, dot < 0 = behind, dot == 0 = perpendicular

// 2. Field-of-view check (cheaper than angle calculation)
float dot = Vector3.Dot(transform.forward, dirToTarget.normalized);
bool inFOV = dot > Mathf.Cos(halfFOVRadians); // cos(45deg) = 0.707 for 90-degree FOV

// 3. Projection of A onto B
Vector3 projection = Vector3.Project(a, b); // Built-in; equivalent to Dot(a,b)/Dot(b,b) * b

// 4. Rejection (component of A perpendicular to B)
Vector3 rejection = a - Vector3.Project(a, b);

// 5. Surface angle for slope detection
float slopeAngle = Vector3.Angle(hitNormal, Vector3.up);
bool tooSteep = slopeAngle > maxSlopeAngle;
```
