# Unity 3D Physics API Reference

Full API reference for Unity's 3D physics system (PhysX). Based on Unity 6.3 LTS documentation.

---

## Rigidbody Component

The Rigidbody class controls a GameObject's position through physics simulation. Adding a Rigidbody places the object under the physics engine's control.

> Source: [Rigidbody API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Rigidbody.html)

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `mass` | float | The rigidbody's mass value |
| `linearDamping` | float | Linear damping of the Rigidbody linear velocity |
| `angularDamping` | float | Angular damping of the object |
| `linearVelocity` | Vector3 | Linear velocity vector; rate of change of position |
| `angularVelocity` | Vector3 | Angular velocity in radians per second |
| `useGravity` | bool | Controls whether gravity affects this rigidbody |
| `isKinematic` | bool | Controls whether physics affects the rigidbody |
| `interpolation` | RigidbodyInterpolation | Manages appearance of jitter in movement |
| `collisionDetectionMode` | CollisionDetectionMode | The collision detection mode |
| `position` | Vector3 | The position of the rigidbody |
| `rotation` | Quaternion | The rotation of the rigidbody |
| `constraints` | RigidbodyConstraints | Freeze position/rotation axes |
| `centerOfMass` | Vector3 | Center of mass relative to the transform origin |
| `maxAngularVelocity` | float | Maximum angular velocity in rad/s |
| `sleepThreshold` | float | Energy below which the body sleeps |

### Methods

#### Force Application

```csharp
// AddForce - applies force in world space
rb.AddForce(Vector3 force, ForceMode mode = ForceMode.Force);

// AddRelativeForce - applies force in local space
rb.AddRelativeForce(Vector3 force, ForceMode mode = ForceMode.Force);

// AddTorque - applies rotational force
rb.AddTorque(Vector3 torque, ForceMode mode = ForceMode.Force);

// AddRelativeTorque - applies torque in local space
rb.AddRelativeTorque(Vector3 torque, ForceMode mode = ForceMode.Force);

// AddForceAtPosition - applies force at a world position (creates torque)
rb.AddForceAtPosition(Vector3 force, Vector3 position, ForceMode mode = ForceMode.Force);

// AddExplosionForce - simulates explosion
rb.AddExplosionForce(float explosionForce, Vector3 explosionPosition, float explosionRadius,
    float upwardsModifier = 0f, ForceMode mode = ForceMode.Force);
```

#### ForceMode Enum

| Value | Description |
|-------|-------------|
| `ForceMode.Force` | Continuous force, affected by mass. Use for sustained push. |
| `ForceMode.Acceleration` | Continuous force, ignores mass. Same acceleration regardless of mass. |
| `ForceMode.Impulse` | Instant force, affected by mass. Use for jumps, knockback. |
| `ForceMode.VelocityChange` | Instant velocity change, ignores mass. |

#### Movement (Kinematic Bodies)

```csharp
// MovePosition - moves kinematic body smoothly with interpolation
rb.MovePosition(Vector3 position);

// MoveRotation - rotates kinematic body smoothly
rb.MoveRotation(Quaternion rot);
```

**Important**: Use these in `FixedUpdate` for kinematic Rigidbodies. For dynamic bodies, use AddForce instead.

#### Sleep Control

```csharp
rb.Sleep();   // Force the rigidbody to sleep (stop simulating)
rb.WakeUp();  // Force the rigidbody to wake up
bool sleeping = rb.IsSleeping(); // Check sleep state
```

### Usage Example

```csharp
using UnityEngine;

public class PhysicsMovement : MonoBehaviour
{
    public float thrustForce = 20f;
    public float torqueForce = 5f;

    private Rigidbody rb;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
        rb.mass = 2f;
        rb.linearDamping = 0.5f;
        rb.angularDamping = 1f;
        rb.interpolation = RigidbodyInterpolation.Interpolate;
        rb.collisionDetectionMode = CollisionDetectionMode.Continuous;
    }

    void FixedUpdate()
    {
        // Apply thrust
        if (Input.GetKey(KeyCode.W))
            rb.AddRelativeForce(Vector3.forward * thrustForce);

        // Apply torque for steering
        float turn = Input.GetAxis("Horizontal");
        rb.AddTorque(Vector3.up * turn * torqueForce);
    }
}
```

---

## Physics Static Class

The Physics class provides global physics settings and query methods.

> Source: [Physics API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.html)

### Static Properties

| Property | Type | Description |
|----------|------|-------------|
| `gravity` | Vector3 | Gravity applied to all rigid bodies (default: 0, -9.81, 0) |
| `defaultContactOffset` | float | Default contact offset of newly created colliders |
| `bounceThreshold` | float | Collision velocity threshold for bouncing (default: 2) |
| `sleepThreshold` | float | Energy threshold for rigidbody sleep states |
| `defaultSolverIterations` | int | Solver accuracy for joints/contacts (default: 6) |
| `defaultMaxAngularSpeed` | float | Max angular speed in radians (default: 50) |
| `queriesHitTriggers` | bool | Whether queries hit trigger colliders |
| `queriesHitBackfaces` | bool | Whether queries hit back-face triangles |
| `invokeCollisionCallbacks` | bool | Whether MonoBehaviour collision messages are sent |
| `simulationMode` | SimulationMode | Controls physics simulation timing |
| `AllLayers` | int | Layer mask selecting all layers |
| `DefaultRaycastLayers` | int | Default raycast layer selection |
| `IgnoreRaycastLayer` | int | Ignore raycast layer constant |

### Raycast Methods

#### Physics.Raycast

```csharp
// Overload 1: Basic check
public static bool Raycast(
    Vector3 origin,
    Vector3 direction,
    float maxDistance = Mathf.Infinity,
    int layerMask = DefaultRaycastLayers,
    QueryTriggerInteraction queryTriggerInteraction = QueryTriggerInteraction.UseGlobal
);

// Overload 2: With hit info
public static bool Raycast(
    Vector3 origin,
    Vector3 direction,
    out RaycastHit hitInfo,
    float maxDistance,
    int layerMask,
    QueryTriggerInteraction queryTriggerInteraction
);

// Overload 3: Ray-based
public static bool Raycast(
    Ray ray,
    float maxDistance = Mathf.Infinity,
    int layerMask = DefaultRaycastLayers,
    QueryTriggerInteraction queryTriggerInteraction = QueryTriggerInteraction.UseGlobal
);

// Overload 4: Ray-based with hit info
public static bool Raycast(
    Ray ray,
    out RaycastHit hitInfo,
    float maxDistance = Mathf.Infinity,
    int layerMask = DefaultRaycastLayers,
    QueryTriggerInteraction queryTriggerInteraction = QueryTriggerInteraction.UseGlobal
);
```

#### RaycastHit Struct

| Property | Type | Description |
|----------|------|-------------|
| `point` | Vector3 | World-space impact position |
| `normal` | Vector3 | Surface normal at impact point |
| `distance` | float | Distance from ray origin to impact |
| `collider` | Collider | The collider that was hit |
| `transform` | Transform | Transform of the hit object |
| `rigidbody` | Rigidbody | Rigidbody of the hit object (null if none) |
| `textureCoord` | Vector2 | UV texture coordinate at impact point |
| `triangleIndex` | int | Index of the mesh triangle hit |

#### Raycast Examples

```csharp
// Simple forward check
Vector3 fwd = transform.TransformDirection(Vector3.forward);
if (Physics.Raycast(transform.position, fwd, 10))
    print("Something ahead!");

// With distance reporting
RaycastHit hit;
if (Physics.Raycast(transform.position, -Vector3.up, out hit, 100.0f))
    print("Distance: " + hit.distance);

// Mouse-to-world raycast
Ray ray = Camera.main.ScreenPointToRay(Mouse.current.position.ReadValue());
if (Physics.Raycast(ray, out hit, 100))
    Debug.DrawLine(ray.origin, hit.point);

// Layer-filtered raycast
int enemyMask = LayerMask.GetMask("Enemies");
if (Physics.Raycast(transform.position, transform.forward, out hit, 50f, enemyMask))
    Debug.Log("Enemy hit: " + hit.collider.name);
```

#### Physics.RaycastAll / RaycastNonAlloc

```csharp
// Returns all hits (allocates array)
RaycastHit[] allHits = Physics.RaycastAll(origin, direction, maxDistance, layerMask);

// Non-allocating version (fills pre-allocated buffer)
RaycastHit[] buffer = new RaycastHit[20];
int hitCount = Physics.RaycastNonAlloc(origin, direction, buffer, maxDistance, layerMask);
for (int i = 0; i < hitCount; i++)
    Debug.Log(buffer[i].collider.name);
```

### Shape Cast Methods

```csharp
// SphereCast - sweep a sphere
public static bool SphereCast(
    Vector3 origin, float radius, Vector3 direction,
    out RaycastHit hitInfo, float maxDistance, int layerMask,
    QueryTriggerInteraction queryTriggerInteraction
);

// BoxCast - sweep a box
public static bool BoxCast(
    Vector3 center, Vector3 halfExtents, Vector3 direction,
    out RaycastHit hitInfo, Quaternion orientation, float maxDistance,
    int layerMask, QueryTriggerInteraction queryTriggerInteraction
);

// CapsuleCast - sweep a capsule
public static bool CapsuleCast(
    Vector3 point1, Vector3 point2, float radius, Vector3 direction,
    out RaycastHit hitInfo, float maxDistance, int layerMask,
    QueryTriggerInteraction queryTriggerInteraction
);

// Linecast - check between two points
public static bool Linecast(
    Vector3 start, Vector3 end,
    out RaycastHit hitInfo, int layerMask,
    QueryTriggerInteraction queryTriggerInteraction
);
```

### Overlap Queries

```csharp
// Find all colliders within a sphere
Collider[] results = Physics.OverlapSphere(Vector3 position, float radius, int layerMask);

// Non-allocating version
Collider[] buffer = new Collider[20];
int count = Physics.OverlapSphereNonAlloc(position, radius, buffer, layerMask);

// Find all colliders within a box
Collider[] results = Physics.OverlapBox(
    Vector3 center, Vector3 halfExtents, Quaternion orientation, int layerMask
);
int count = Physics.OverlapBoxNonAlloc(center, halfExtents, buffer, orientation, layerMask);

// Find all colliders within a capsule
Collider[] results = Physics.OverlapCapsule(
    Vector3 point0, Vector3 point1, float radius, int layerMask
);
```

### Boolean Check Queries

```csharp
// Returns true if any collider overlaps the shape (no allocation, fastest)
bool hit = Physics.CheckSphere(Vector3 position, float radius, int layerMask);
bool hit = Physics.CheckBox(Vector3 center, Vector3 halfExtents, Quaternion orientation, int layerMask);
bool hit = Physics.CheckCapsule(Vector3 start, Vector3 end, float radius, int layerMask);
```

### Utility Methods

```csharp
// Closest point on a collider to a position
Vector3 closest = Physics.ClosestPoint(
    Vector3 point, Collider collider, Vector3 colliderPosition, Quaternion colliderRotation
);

// Calculate penetration between two colliders
bool overlapping = Physics.ComputePenetration(
    Collider colliderA, Vector3 positionA, Quaternion rotationA,
    Collider colliderB, Vector3 positionB, Quaternion rotationB,
    out Vector3 direction, out float distance
);

// Sync transform changes to physics engine
Physics.SyncTransforms();

// Manual simulation step
Physics.Simulate(float step);

// Ignore collision between two specific colliders
Physics.IgnoreCollision(Collider collider1, Collider collider2, bool ignore = true);

// Ignore all collisions between two layers
Physics.IgnoreLayerCollision(int layer1, int layer2, bool ignore = true);
```

---

## Collision Callbacks

Collision callbacks are MonoBehaviour methods invoked by the physics engine.

> Source: [Collider Interactions](https://docs.unity3d.com/6000.3/Documentation/Manual/collider-interactions.html)

### OnCollision Events (Physical Collisions)

Triggered when two non-trigger colliders make contact. At least one must have a dynamic (non-kinematic) Rigidbody.

```csharp
// Called the first frame two colliders touch
void OnCollisionEnter(Collision other)
{
    // Collision contains contact info
    foreach (ContactPoint contact in other.contacts)
    {
        Debug.DrawRay(contact.point, contact.normal, Color.red, 2f);
    }

    Debug.Log("Relative velocity: " + other.relativeVelocity);
    Debug.Log("Hit object: " + other.gameObject.name);
}

// Called every physics frame while colliders remain in contact
void OnCollisionStay(Collision other)
{
    // Use for continuous effects (grinding, sliding)
}

// Called when colliders separate
void OnCollisionExit(Collision other)
{
    // Use for cleanup
}
```

### Collision Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `contacts` | ContactPoint[] | All contact points |
| `contactCount` | int | Number of contact points |
| `relativeVelocity` | Vector3 | Relative linear velocity of the two colliders |
| `gameObject` | GameObject | The other GameObject |
| `collider` | Collider | The other collider |
| `rigidbody` | Rigidbody | The other Rigidbody (may be null) |
| `transform` | Transform | The other transform |
| `impulse` | Vector3 | Total impulse applied to resolve the collision |

### OnTrigger Events (Trigger Volumes)

Triggered when a collider with `isTrigger=true` overlaps another collider. At least one object must have a Rigidbody.

```csharp
// Called when a collider first enters the trigger
void OnTriggerEnter(Collider other)
{
    if (other.CompareTag("Player"))
        Debug.Log("Player entered trigger zone");
}

// Called every frame a collider remains inside the trigger
void OnTriggerStay(Collider other)
{
    if (other.attachedRigidbody != null)
        other.attachedRigidbody.AddForce(Vector3.up * 12f, ForceMode.Acceleration);
}

// Called when a collider exits the trigger
void OnTriggerExit(Collider other)
{
    Debug.Log(other.name + " left trigger zone");
}
```

### Collision Matrix

Which collider type pairs generate events:

| | Static Collider | Dynamic Rigidbody | Kinematic Rigidbody |
|---|---|---|---|
| **Static Collider** | No events | Collision events | No events |
| **Dynamic Rigidbody** | Collision events | Collision events | Collision events |
| **Kinematic Rigidbody** | No events | Collision events | No events |

For trigger events: a trigger (dynamic or kinematic) generates trigger events with any dynamic or kinematic collider. A static trigger generates events with dynamic or kinematic colliders.

### Practical Example: Door with Tag Check

```csharp
using UnityEngine;

public class DoorObject : MonoBehaviour
{
    private void OnCollisionEnter(Collision other)
    {
        if (other.gameObject.CompareTag("Player"))
            Debug.Log("The player character has touched the door.");

        if (other.gameObject.CompareTag("Enemy"))
            Debug.Log("An enemy character has touched the door!");
    }
}
```

### Practical Example: Hover Pad with Trigger

```csharp
using UnityEngine;

public class HoverPad : MonoBehaviour
{
    public float hoverForce = 12f;

    void OnTriggerStay(Collider other)
    {
        if (other.attachedRigidbody != null)
            other.attachedRigidbody.AddForce(Vector3.up * hoverForce, ForceMode.Acceleration);
    }
}
```

---

## Collision Detection Modes

> Source: [Collision Detection](https://docs.unity3d.com/6000.3/Documentation/Manual/collision-detection.html)

| Mode | Description | Performance | Use Case |
|------|-------------|-------------|----------|
| `Discrete` | Checks at end of each physics step | Highest efficiency | Default, slow/medium objects |
| `Continuous` | Checks over entire step against static colliders | Medium | Fast objects hitting walls/floors |
| `ContinuousDynamic` | Checks over entire step against all colliders | Lower efficiency | Fast objects hitting other fast objects |
| `ContinuousSpeculative` | Predictive CCD using speculative contacts | Efficient CCD | Kinematic bodies, general anti-tunneling |

```csharp
// Set collision detection mode
rb.collisionDetectionMode = CollisionDetectionMode.Continuous;

// For a bullet or fast projectile
rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
```

---

## Joints

> Source: [Joints](https://docs.unity3d.com/6000.3/Documentation/Manual/Joints.html)

### Joint Types

| Component | Description |
|-----------|-------------|
| `FixedJoint` | Locks two bodies together; implemented as a stiff spring |
| `HingeJoint` | Rotation around one axis; doors, pendulums, chains |
| `SpringJoint` | Elastic connection maintaining distance between anchor points |
| `CharacterJoint` | Ball-and-socket with angle limits; ragdoll hips/shoulders |
| `ConfigurableJoint` | Fully customizable; can emulate any other joint type |

### Common Joint Properties

| Property | Description |
|----------|-------------|
| `connectedBody` | The other Rigidbody (null = world anchor) |
| `anchor` | Joint anchor point in local space |
| `connectedAnchor` | Anchor on the connected body |
| `breakForce` | Force threshold to break the joint (Infinity = unbreakable) |
| `breakTorque` | Torque threshold to break the joint |
| `enablePreprocessing` | Enables joint stabilization |

### Joint Example

```csharp
using UnityEngine;

public class BreakableConnection : MonoBehaviour
{
    public Rigidbody connectedObject;
    public float breakThreshold = 500f;

    void Start()
    {
        FixedJoint joint = gameObject.AddComponent<FixedJoint>();
        joint.connectedBody = connectedObject;
        joint.breakForce = breakThreshold;
        joint.breakTorque = breakThreshold;
    }

    void OnJointBreak(float breakForce)
    {
        Debug.Log("Joint broke with force: " + breakForce);
    }
}
```

---

## Layer Masks

Layer masks are bitmasks used to filter physics queries and collisions.

```csharp
// Get mask for a named layer
int groundMask = LayerMask.GetMask("Ground");
int combinedMask = LayerMask.GetMask("Ground", "Obstacles", "Enemies");

// Get layer index
int groundLayer = LayerMask.NameToLayer("Ground");

// Bitwise construction
int layer8Mask = 1 << 8;                    // Only layer 8
int allExceptLayer8 = ~(1 << 8);            // Everything except layer 8

// Use in raycast
Physics.Raycast(origin, direction, out hit, 100f, groundMask);

// Ignore collisions between layers
Physics.IgnoreLayerCollision(
    LayerMask.NameToLayer("Player"),
    LayerMask.NameToLayer("PlayerProjectiles"),
    true
);
```
