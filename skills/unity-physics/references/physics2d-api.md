# Unity 2D Physics API Reference

Full API reference for Unity's 2D physics system (Box2D). Based on Unity 6.3 LTS documentation.

---

## Rigidbody2D Component

Provides physics movement and dynamics, with the ability to attach Collider2D components.

> Source: [Rigidbody2D API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Rigidbody2D.html)

### Body Types

| Type | Enum Value | Description |
|------|------------|-------------|
| **Dynamic** | `RigidbodyType2D.Dynamic` | Fully simulated, responds to forces and gravity |
| **Kinematic** | `RigidbodyType2D.Kinematic` | User-controlled movement, collision detection enabled, not affected by forces |
| **Static** | `RigidbodyType2D.Static` | Immobile reference objects, no simulation cost |

```csharp
Rigidbody2D rb = GetComponent<Rigidbody2D>();
rb.bodyType = RigidbodyType2D.Dynamic;
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `mass` | float | Object mass for physics calculations |
| `linearDamping` | float | Velocity resistance factor |
| `angularDamping` | float | Rotational resistance factor |
| `gravityScale` | float | Gravity influence multiplier (0 = no gravity) |
| `linearVelocity` | Vector2 | Rate of position change per world-unit |
| `angularVelocity` | float | Rotation speed in degrees per second |
| `position` | Vector2 | Rigidbody position in world space |
| `rotation` | float | Angular orientation in degrees |
| `bodyType` | RigidbodyType2D | Physical behavior classification |
| `constraints` | RigidbodyConstraints2D | Freeze position/rotation axes |
| `collisionDetectionMode` | CollisionDetectionMode2D | Collision checking methodology |
| `interpolation` | RigidbodyInterpolation2D | Physics update smoothing |
| `freezeRotation` | bool | Lock rotation from physics |
| `sleepMode` | RigidbodySleepMode2D | Initial rest state |
| `centerOfMass` | Vector2 | Local mass center point |
| `simulated` | bool | Whether the body participates in simulation |

### Force Application Methods

```csharp
Rigidbody2D rb = GetComponent<Rigidbody2D>();

// Apply directional force
rb.AddForce(Vector2 force, ForceMode2D mode = ForceMode2D.Force);

// Apply rotational force
rb.AddTorque(float torque, ForceMode2D mode = ForceMode2D.Force);

// Apply force at a specific world position (creates torque)
rb.AddForceAtPosition(Vector2 force, Vector2 position, ForceMode2D mode = ForceMode2D.Force);
```

### ForceMode2D Enum

| Value | Description |
|-------|-------------|
| `ForceMode2D.Force` | Continuous force, affected by mass (default) |
| `ForceMode2D.Impulse` | Instant force, affected by mass |

### Movement Methods

```csharp
// Direct position adjustment (use in FixedUpdate)
rb.MovePosition(Vector2 position);

// Direct rotation adjustment (use in FixedUpdate)
rb.MoveRotation(float angle);

// Combined transform update
rb.MovePositionAndRotation(Vector2 position, float angle);
```

### Query Methods

```csharp
// Sweep collision detection along a direction
RaycastHit2D[] results = new RaycastHit2D[10];
int count = rb.Cast(Vector2 direction, results, float distance);

// Static collision overlap check
Collider2D[] overlapResults = new Collider2D[10];
int overlapCount = rb.Overlap(overlapResults);

// Point-in-collider test
bool contains = rb.OverlapPoint(Vector2 point);

// Retrieve active collision contacts
ContactPoint2D[] contacts = new ContactPoint2D[10];
int contactCount = rb.GetContacts(contacts);

// Check if touching another collider
bool touching = rb.IsTouching(Collider2D collider);
```

### Usage Example

```csharp
using UnityEngine;

public class Player2DMovement : MonoBehaviour
{
    public float moveSpeed = 5f;
    public float jumpForce = 10f;

    private Rigidbody2D rb;
    private bool jumpRequested;

    void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        rb.gravityScale = 1f;
        rb.linearDamping = 0.3f;
        rb.freezeRotation = true;
    }

    void Update()
    {
        if (Input.GetButtonDown("Jump"))
            jumpRequested = true;
    }

    void FixedUpdate()
    {
        float h = Input.GetAxis("Horizontal");
        rb.linearVelocity = new Vector2(h * moveSpeed, rb.linearVelocity.y);

        if (jumpRequested)
        {
            rb.AddForce(Vector2.up * jumpForce, ForceMode2D.Impulse);
            jumpRequested = false;
        }
    }
}
```

---

## Physics2D Static Class

Provides global 2D physics settings and query methods.

> Source: [Physics2D API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics2D.html)

### Static Properties

| Property | Type | Description |
|----------|------|-------------|
| `gravity` | Vector2 | Acceleration due to gravity (default: 0, -9.81) |
| `AllLayers` | int | Layer mask constant including all layers |
| `DefaultRaycastLayers` | int | Default layers participating in raycasts |
| `IgnoreRaycastLayer` | int | Layer constant that ignores raycasts |
| `simulationMode` | SimulationMode2D | Controls when Unity runs 2D physics |
| `simulationLayers` | int | Layers to simulate |
| `queriesHitTriggers` | bool | Do raycasts detect trigger colliders? |
| `queriesStartInColliders` | bool | Do rays starting inside colliders detect them? |
| `defaultContactOffset` | float | Default contact offset for new colliders |

### Raycast Methods

```csharp
// Cast a ray against 2D colliders
RaycastHit2D hit = Physics2D.Raycast(
    Vector2 origin,
    Vector2 direction,
    float distance = Mathf.Infinity,
    int layerMask = DefaultRaycastLayers
);

// Return all hits along the ray
RaycastHit2D[] hits = Physics2D.RaycastAll(
    Vector2 origin, Vector2 direction, float distance, int layerMask
);

// Non-allocating version
RaycastHit2D[] buffer = new RaycastHit2D[20];
int count = Physics2D.RaycastNonAlloc(origin, direction, buffer, distance, layerMask);

// Linecast between two points
RaycastHit2D hit = Physics2D.Linecast(Vector2 start, Vector2 end, int layerMask);
RaycastHit2D[] hits = Physics2D.LinecastAll(start, end, layerMask);
```

### RaycastHit2D Properties

| Property | Type | Description |
|----------|------|-------------|
| `point` | Vector2 | World-space impact position |
| `normal` | Vector2 | Surface normal at impact |
| `distance` | float | Distance from origin |
| `collider` | Collider2D | Collider that was hit |
| `rigidbody` | Rigidbody2D | Rigidbody of the hit object |
| `transform` | Transform | Transform of the hit object |
| `fraction` | float | Fraction of distance where hit occurred |

### Raycast Example

```csharp
using UnityEngine;

public class GroundCheck2D : MonoBehaviour
{
    public LayerMask groundLayer;

    public bool IsGrounded()
    {
        RaycastHit2D hit = Physics2D.Raycast(
            transform.position,
            Vector2.down,
            1.1f,
            groundLayer
        );
        return hit.collider != null;
    }
}
```

### Shape Cast Methods

```csharp
// BoxCast - sweep a box
RaycastHit2D hit = Physics2D.BoxCast(
    Vector2 origin, Vector2 size, float angle,
    Vector2 direction, float distance, int layerMask
);
RaycastHit2D[] hits = Physics2D.BoxCastAll(origin, size, angle, direction, distance, layerMask);

// CircleCast - sweep a circle
RaycastHit2D hit = Physics2D.CircleCast(
    Vector2 origin, float radius,
    Vector2 direction, float distance, int layerMask
);
RaycastHit2D[] hits = Physics2D.CircleCastAll(origin, radius, direction, distance, layerMask);

// CapsuleCast - sweep a capsule
RaycastHit2D hit = Physics2D.CapsuleCast(
    Vector2 origin, Vector2 size, CapsuleDirection2D capsuleDirection, float angle,
    Vector2 direction, float distance, int layerMask
);
RaycastHit2D[] hits = Physics2D.CapsuleCastAll(origin, size, capsuleDirection, angle, direction, distance, layerMask);

// Cast a 3D ray against 2D colliders (useful for camera-to-world)
RaycastHit2D hit = Physics2D.GetRayIntersection(Ray ray, float distance, int layerMask);
RaycastHit2D[] hits = Physics2D.GetRayIntersectionAll(ray, distance, layerMask);
```

### Overlap Queries

```csharp
// Circle overlap
Collider2D hit = Physics2D.OverlapCircle(Vector2 point, float radius, int layerMask);
Collider2D[] hits = Physics2D.OverlapCircleAll(point, radius, layerMask);

// Box overlap
Collider2D hit = Physics2D.OverlapBox(Vector2 point, Vector2 size, float angle, int layerMask);
Collider2D[] hits = Physics2D.OverlapBoxAll(point, size, angle, layerMask);

// Capsule overlap
Collider2D hit = Physics2D.OverlapCapsule(
    Vector2 point, Vector2 size, CapsuleDirection2D direction, float angle, int layerMask
);
Collider2D[] hits = Physics2D.OverlapCapsuleAll(point, size, direction, angle, layerMask);

// Rectangular area overlap
Collider2D hit = Physics2D.OverlapArea(Vector2 pointA, Vector2 pointB, int layerMask);
Collider2D[] hits = Physics2D.OverlapAreaAll(pointA, pointB, layerMask);

// Point overlap
Collider2D hit = Physics2D.OverlapPoint(Vector2 point, int layerMask);
Collider2D[] hits = Physics2D.OverlapPointAll(point, layerMask);

// Collider-to-collider overlap
Collider2D[] results = new Collider2D[10];
int count = Physics2D.OverlapCollider(Collider2D collider, results);
```

### Collision Control

```csharp
// Ignore collision between two specific colliders
Physics2D.IgnoreCollision(Collider2D collider1, Collider2D collider2, bool ignore = true);
bool ignored = Physics2D.GetIgnoreCollision(collider1, collider2);

// Ignore collisions between layers
Physics2D.IgnoreLayerCollision(int layer1, int layer2, bool ignore = true);
bool ignored = Physics2D.GetIgnoreLayerCollision(layer1, layer2);

// Set/get layer collision masks
Physics2D.SetLayerCollisionMask(int layer, int layerMask);
int mask = Physics2D.GetLayerCollisionMask(int layer);
```

### Contact and Distance

```csharp
// Check if two colliders are touching
bool touching = Physics2D.IsTouching(Collider2D collider1, Collider2D collider2);
bool touchingLayers = Physics2D.IsTouchingLayers(Collider2D collider, int layerMask);

// Calculate minimum distance between colliders
ColliderDistance2D dist = Physics2D.Distance(Collider2D colliderA, Collider2D colliderB);

// Closest point on collider perimeter
Vector2 closest = Physics2D.ClosestPoint(Vector2 position, Collider2D collider);

// Retrieve contacts
ContactPoint2D[] contacts = new ContactPoint2D[10];
int count = Physics2D.GetContacts(Collider2D collider, contacts);
```

### Simulation Control

```csharp
// Manually step physics
Physics2D.Simulate(float step);

// Synchronize transforms with physics
Physics2D.SyncTransforms();
```

---

## 2D Collider Types

| Component | Description |
|-----------|-------------|
| `BoxCollider2D` | Rectangular collision shape |
| `CircleCollider2D` | Circular collision shape |
| `CapsuleCollider2D` | Capsule collision shape |
| `PolygonCollider2D` | Arbitrary polygon shape (auto-generated from sprite) |
| `EdgeCollider2D` | Open-ended line segment collider |
| `CompositeCollider2D` | Merges child colliders into optimized shapes |
| `TilemapCollider2D` | Collider for Tilemap components |

### Collider2D Common Properties

| Property | Type | Description |
|----------|------|-------------|
| `isTrigger` | bool | Is this a trigger collider? |
| `offset` | Vector2 | Local offset from Rigidbody2D |
| `sharedMaterial` | PhysicsMaterial2D | Friction and bounce settings |
| `density` | float | Mass density (when auto-mass enabled) |
| `attachedRigidbody` | Rigidbody2D | The Rigidbody2D this collider is attached to |

---

## 2D Collision Callbacks

Same pattern as 3D but with 2D-specific parameter types:

```csharp
// Physical collision events
void OnCollisionEnter2D(Collision2D other)
{
    Debug.Log("Hit: " + other.gameObject.name);
    Debug.Log("Contact point: " + other.GetContact(0).point);
    Debug.Log("Relative velocity: " + other.relativeVelocity);
}

void OnCollisionStay2D(Collision2D other)
{
    // Continuous contact
}

void OnCollisionExit2D(Collision2D other)
{
    // Contact ended
}

// Trigger events
void OnTriggerEnter2D(Collider2D other)
{
    if (other.CompareTag("Coin"))
    {
        Destroy(other.gameObject);
        score++;
    }
}

void OnTriggerStay2D(Collider2D other)
{
    // Overlapping each frame
}

void OnTriggerExit2D(Collider2D other)
{
    // Left trigger volume
}
```

---

## 2D Joint Types

| Component | Description |
|-----------|-------------|
| `DistanceJoint2D` | Maintains distance between two points |
| `FixedJoint2D` | Locks two bodies together |
| `FrictionJoint2D` | Reduces relative motion between bodies |
| `HingeJoint2D` | Rotation around a single point |
| `RelativeJoint2D` | Maintains relative position/angle |
| `SliderJoint2D` | Constrains movement to a line |
| `SpringJoint2D` | Spring-like elastic connection |
| `TargetJoint2D` | Moves body toward a target position |
| `WheelJoint2D` | Simulates a wheel with suspension |

---

## 2D Effectors

Effectors apply forces when colliders interact:

| Component | Description |
|-----------|-------------|
| `AreaEffector2D` | Applies directional force within an area |
| `BuoyancyEffector2D` | Simulates fluid buoyancy |
| `PlatformEffector2D` | One-way platform behavior |
| `PointEffector2D` | Attracts/repels from a point |
| `SurfaceEffector2D` | Applies tangential force along a surface (conveyor belts) |

---

## Key Differences from 3D Physics

| Feature | 3D (Physics) | 2D (Physics2D) |
|---------|-------------|-----------------|
| Engine | PhysX | Box2D |
| Rigidbody | `Rigidbody` | `Rigidbody2D` |
| Vectors | `Vector3` | `Vector2` |
| Rotation | `Quaternion` (3 axes) | `float` (Z-axis only) |
| Gravity | `Vector3` | `Vector2` |
| Force modes | 4 (Force, Acceleration, Impulse, VelocityChange) | 2 (Force, Impulse) |
| Raycast return | `bool` + `out RaycastHit` | `RaycastHit2D` (struct) |
| Callbacks | `OnCollisionEnter(Collision)` | `OnCollisionEnter2D(Collision2D)` |
| Triggers | `OnTriggerEnter(Collider)` | `OnTriggerEnter2D(Collider2D)` |
| Body types | Dynamic / Kinematic (via isKinematic) | Dynamic / Kinematic / Static (via bodyType) |
| Damping | `linearDamping`, `angularDamping` | `linearDamping`, `angularDamping` |
| Gravity control | `useGravity` (bool) | `gravityScale` (float multiplier) |
| Sleeping | `sleepThreshold` | `sleepMode` |
| Joints | Fixed, Hinge, Spring, Character, Configurable | Distance, Fixed, Friction, Hinge, Relative, Slider, Spring, Target, Wheel |
| Extra features | -- | Effectors (Area, Buoyancy, Platform, Point, Surface) |

### Important: Do Not Mix 2D and 3D

3D physics components (`Rigidbody`, `BoxCollider`, `Physics.Raycast`) and 2D physics components (`Rigidbody2D`, `BoxCollider2D`, `Physics2D.Raycast`) operate in completely separate systems. They do not interact with each other. Use one system consistently per GameObject.

---

## Additional Resources

- [2D Physics Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/2d-physics/2d-physics.html)
- [Rigidbody2D API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Rigidbody2D.html)
- [Physics2D API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics2D.html)
