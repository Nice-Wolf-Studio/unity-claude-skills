---
name: unity-physics
description: >
  Unity 6 physics development guide. Use when working with Rigidbody, colliders, raycasting, triggers, collisions, joints, or physics simulation. Covers PhysX 5 (3D) and Box2D (2D) physics, FixedUpdate timing, layer masks, and contact data. Based on Unity 6.3 LTS documentation.
---

# Unity Physics

## Physics System Overview

Unity provides different physics engine integrations for different project needs:

- **3D Physics (PhysX)**: Nvidia PhysX engine integration for 3D object-oriented projects
- **2D Physics (Box2D)**: Optimized 2D physics system with dedicated components
- Both systems simulate gravity, collisions, forces, and constraints

### Physics Timing

Physics runs on a fixed timestep via `FixedUpdate`, separate from the rendering frame rate:

```csharp
void FixedUpdate()
{
    // All physics code belongs here, not in Update()
    rb.AddForce(Vector3.forward * speed);
}
```

Key timing rules:
- `FixedUpdate` runs at a fixed interval (default 0.02s / 50Hz)
- Multiple `FixedUpdate` calls can occur per frame, or none
- `Time.fixedDeltaTime` controls the interval
- Use `Update` for input, `FixedUpdate` for physics forces

### Simulation Modes

`Physics.simulationMode` controls when the physics engine steps:
- **FixedUpdate** (default): Automatic simulation each fixed timestep
- **Update**: Simulate once per frame
- **Script**: Manual control via `Physics.Simulate()`

---

## Rigidbody Configuration

A Rigidbody component places a GameObject under physics engine control. A rigid body does not deform or change shape under physics forces.

### Key Properties

| Property | Description | Default |
|----------|-------------|---------|
| `mass` | Mass in kg; affects force interactions | 1 |
| `linearDamping` | Resistance to linear velocity | 0 |
| `angularDamping` | Resistance to angular velocity | 0.05 |
| `useGravity` | Whether gravity affects this body | true |
| `isKinematic` | If true, not driven by physics forces | false |
| `interpolation` | Smooths visual jitter between physics steps | None |
| `collisionDetectionMode` | Algorithm for detecting collisions | Discrete |

### Movement Methods

```csharp
Rigidbody rb = GetComponent<Rigidbody>();

// Apply continuous force (call in FixedUpdate)
rb.AddForce(Vector3.forward * 10f);
rb.AddForce(Vector3.up * 5f, ForceMode.Impulse);

// Apply torque
rb.AddTorque(Vector3.up * 2f);

// Apply force at a world position (creates both force and torque)
rb.AddForceAtPosition(Vector3.forward * 10f, hitPoint);

// Kinematic movement (use for isKinematic=true bodies)
rb.MovePosition(rb.position + direction * speed * Time.fixedDeltaTime);
rb.MoveRotation(targetRotation);
```

### ForceMode Options

| Mode | Description |
|------|-------------|
| `ForceMode.Force` | Continuous force, uses mass (default) |
| `ForceMode.Acceleration` | Continuous force, ignores mass |
| `ForceMode.Impulse` | Instant force, uses mass |
| `ForceMode.VelocityChange` | Instant force, ignores mass |

### Sleep State

When a Rigidbody's energy falls below the sleep threshold, the physics engine stops calculating it. Control manually with `rb.Sleep()` and `rb.WakeUp()`.

### Scale Warning

Unity assumes 1 world unit = 1 metre. Incorrect scale causes unrealistic physics behavior. Keep GameObjects at realistic proportions.

---

## Colliders and Triggers

Colliders are invisible shapes that define a GameObject's physical boundaries. They do not need to match the visual mesh.

### Collider Categories

| Category | Description |
|----------|-------------|
| **Static Collider** | Collider only, no Rigidbody. For immovable geometry (walls, floors). |
| **Dynamic Rigidbody Collider** | Collider + Rigidbody (isKinematic=false). Fully simulated. |
| **Kinematic Rigidbody Collider** | Collider + Rigidbody (isKinematic=true). Moved via script. |

### Collider Shapes

- **Primitive**: BoxCollider, SphereCollider, CapsuleCollider -- efficient, auto-scale
- **Compound**: Multiple primitives on child GameObjects for complex shapes
- **MeshCollider**: Matches exact mesh geometry; expensive, use sparingly
- **WheelCollider**: Raycast-based, built-in vehicle physics
- **TerrainCollider**: Matches terrain heightmap

### Trigger Colliders

Triggers detect overlapping colliders without physical collision response:

```csharp
// Set via Inspector: Collider > Is Trigger = true
// Or via script:
GetComponent<BoxCollider>().isTrigger = true;
```

Requirements for trigger events:
- At least one GameObject must have a Rigidbody
- The collider must have `isTrigger` enabled
- Each overlapping pair needs its own Rigidbody for individual detection

### Physics Materials

Colliders support PhysicsMaterial with adjustable friction and bounciness properties for surface interactions.

---

## Raycasting

Raycasting projects invisible rays to detect colliders in the scene.

### Physics.Raycast

```csharp
// Basic: check if anything is ahead
Vector3 fwd = transform.TransformDirection(Vector3.forward);
if (Physics.Raycast(transform.position, fwd, 10))
    Debug.Log("Something ahead!");

// With hit info
RaycastHit hit;
if (Physics.Raycast(transform.position, -Vector3.up, out hit, 100.0f))
    Debug.Log("Distance to ground: " + hit.distance);

// With layer mask
int layerMask = 1 << LayerMask.NameToLayer("Enemies");
if (Physics.Raycast(origin, direction, out hit, maxDist, layerMask))
    Debug.Log("Hit enemy: " + hit.collider.gameObject.name);

// Mouse-to-world raycast
Ray ray = Camera.main.ScreenPointToRay(Mouse.current.position.ReadValue());
if (Physics.Raycast(ray, out hit, 100))
    Debug.DrawLine(ray.origin, hit.point);
```

### RaycastHit Properties

| Property | Type | Description |
|----------|------|-------------|
| `point` | Vector3 | World-space hit position |
| `normal` | Vector3 | Surface normal at hit point |
| `distance` | float | Distance from ray origin |
| `collider` | Collider | Collider that was hit |
| `transform` | Transform | Transform of the hit object |

### Other Cast Methods

| Method | Description |
|--------|-------------|
| `Physics.RaycastAll()` | Returns all intersections along the ray |
| `Physics.RaycastNonAlloc()` | Fills a pre-allocated buffer (no GC alloc) |
| `Physics.SphereCast()` | Sweeps a sphere along a direction |
| `Physics.BoxCast()` | Sweeps a box along a direction |
| `Physics.CapsuleCast()` | Sweeps a capsule along a direction |
| `Physics.Linecast()` | Checks for colliders between two points |

### Overlap Queries (no direction, area check)

| Method | Description |
|--------|-------------|
| `Physics.OverlapSphere()` | Find all colliders within a sphere |
| `Physics.OverlapBox()` | Find all colliders within a box |
| `Physics.OverlapCapsule()` | Find all colliders within a capsule |
| `Physics.CheckSphere()` | Returns true if any collider overlaps the sphere |
| `Physics.CheckBox()` | Returns true if any collider overlaps the box |
| `Physics.CheckCapsule()` | Returns true if any collider overlaps the capsule |

### QueryTriggerInteraction

Controls whether casts/overlaps detect trigger colliders:
- `QueryTriggerInteraction.UseGlobal` -- uses `Physics.queriesHitTriggers`
- `QueryTriggerInteraction.Collide` -- always detect triggers
- `QueryTriggerInteraction.Ignore` -- never detect triggers

---

## Collision Detection

### Collision Detection Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Discrete** | Checks collisions at end of each physics step. High efficiency. | Default for most objects |
| **Continuous** | Checks collisions over the entire step. Prevents tunneling. | Fast objects hitting static geometry |
| **Continuous Dynamic** | Continuous detection against both static and dynamic colliders | Fast objects hitting other fast objects |
| **Continuous Speculative** | Predictive CCD using speculative contacts | Kinematic bodies, general CCD |

### Collision Callbacks

```csharp
void OnCollisionEnter(Collision other) {  // First frame of contact
    if (other.gameObject.CompareTag("Player"))
        Debug.Log("Player hit this object");
}
void OnCollisionStay(Collision other) { }  // Every physics frame while touching
void OnCollisionExit(Collision other) { }  // Contact ended
```

### Trigger Callbacks

```csharp
void OnTriggerEnter(Collider other) {  // Entered trigger volume
    if (other.CompareTag("Player"))
        Debug.Log("Player entered trigger zone");
}
void OnTriggerStay(Collider other) {   // Each frame inside trigger
    other.attachedRigidbody?.AddForce(Vector3.up * 12f, ForceMode.Acceleration);
}
void OnTriggerExit(Collider other) { } // Left trigger volume
```

### Collision Matrix

| Pair | Collision Events | Trigger Events |
|------|-----------------|----------------|
| Static + Dynamic | Yes | -- |
| Static + Kinematic | No | -- |
| Static + Static | No | -- |
| Dynamic + Dynamic | Yes | -- |
| Dynamic + Kinematic | Yes | -- |
| Kinematic + Kinematic | No | -- |
| Trigger + Dynamic/Kinematic | -- | Yes |
| Static Trigger + Dynamic/Kinematic | -- | Yes |

At least one dynamic (non-kinematic) Rigidbody is required for collision events. The physics engine only applies forces to GameObjects with Rigidbody or ArticulationBody components.

---

## Joints

Joints connect Rigidbody components together or to fixed points in space.

| Joint Type | Description | Use Case |
|------------|-------------|----------|
| **FixedJoint** | Locks two bodies together (implemented as a spring) | Attaching objects, breakable connections |
| **HingeJoint** | Rotation around a single axis | Doors, pendulums, chains |
| **SpringJoint** | Elastic connection maintaining distance | Bungees, tethers |
| **CharacterJoint** | Ball-and-socket with constrained angles | Ragdolls (hips, shoulders) |
| **ConfigurableJoint** | Fully customizable constraints | Any specialized connection |

### Joint Properties

- **Connected Body**: The other Rigidbody (null = fixed to world)
- **Anchor / Connected Anchor**: Local-space attachment points
- **Break Force / Break Torque**: Threshold to destroy the joint
- **Enable Preprocessing**: Stabilizes the joint simulation

For industrial/robotics applications requiring precise articulation, use **ArticulationBody** instead of regular joints.

---

## 2D Physics Differences

Unity's 2D physics uses a separate engine optimized for 2D workflows.

| Aspect | 3D | 2D |
|--------|----|----|
| Engine | PhysX | Box2D |
| Rigidbody | `Rigidbody` | `Rigidbody2D` |
| Collider | `Collider` | `Collider2D` |
| Physics class | `Physics` | `Physics2D` |
| Vectors | `Vector3` | `Vector2` |
| Rotation | Quaternion (3-axis) | float (Z-axis only) |
| Gravity | `Vector3` | `Vector2` |
| ForceMode | `ForceMode` | `ForceMode2D` |

### Rigidbody2D Body Types

| Type | Description |
|------|-------------|
| **Dynamic** | Fully simulated, responds to forces and gravity |
| **Kinematic** | Moved via script, detects collisions but not affected by forces |
| **Static** | Immovable, for level geometry |

### 2D Collider Types

BoxCollider2D, CircleCollider2D, CapsuleCollider2D, PolygonCollider2D, EdgeCollider2D, CompositeCollider2D, TilemapCollider2D

### 2D-Specific Features

- **Effectors 2D**: Area, Buoyancy, Platform, Point, Surface effectors for force interactions
- **Constant Force 2D**: Applies persistent force/torque
- **Physics Material 2D**: Friction and bounce properties
- **LowLevelPhysics2D API**: Independent low-level physics pathway

See reference file `references/physics2d-api.md` for full 2D API details.

---

## Common Patterns

### Player Movement with Rigidbody

```csharp
public class PlayerMovement : MonoBehaviour
{
    public float moveSpeed = 5f;
    public float jumpForce = 7f;

    private Rigidbody rb;
    private bool jumpRequested;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    void Update()
    {
        // Capture input in Update (legacy Input Manager; see unity-input for new Input System)
        if (Input.GetButtonDown("Jump"))
            jumpRequested = true;
    }

    void FixedUpdate()
    {
        // Apply physics in FixedUpdate (legacy Input; see unity-input)
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        Vector3 move = new Vector3(h, 0f, v) * moveSpeed;
        rb.linearVelocity = new Vector3(move.x, rb.linearVelocity.y, move.z);

        if (jumpRequested)
        {
            rb.AddForce(Vector3.up * jumpForce, ForceMode.Impulse);
            jumpRequested = false;
        }
    }
}
```

### Ground Check with SphereCast

```csharp
// Cache collider reference in Awake() -- avoid GetComponent in hot paths
private CapsuleCollider capsule;
void Awake() => capsule = GetComponent<CapsuleCollider>();

public bool IsGrounded()
{
    float radius = 0.3f;
    return Physics.SphereCast(transform.position, radius, Vector3.down,
        out _, (capsule.height / 2f) - radius + 0.1f,
        LayerMask.GetMask("Ground"));
}
```

### Hover Pad with Trigger

```csharp
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

### Non-Allocating Raycast (Zero GC)

```csharp
private readonly RaycastHit[] hits = new RaycastHit[10];

void DetectEnemies()
{
    int count = Physics.RaycastNonAlloc(transform.position, transform.forward,
        hits, 50f, LayerMask.GetMask("Enemies"));
    for (int i = 0; i < count; i++)
        Debug.Log("Hit: " + hits[i].collider.name);
}
```

---

## Anti-Patterns

### Do NOT use Update for physics forces

```csharp
// BAD: Forces applied at variable frame rate cause inconsistent behavior
void Update()
{
    rb.AddForce(Vector3.forward * 10f); // WRONG
}

// GOOD: Use FixedUpdate for physics
void FixedUpdate()
{
    rb.AddForce(Vector3.forward * 10f); // CORRECT
}
```

### Do NOT move Rigidbody with Transform

```csharp
// BAD: Bypasses physics, breaks collision detection
transform.position += Vector3.forward * speed * Time.deltaTime; // WRONG

// GOOD: Use Rigidbody methods
rb.MovePosition(rb.position + Vector3.forward * speed * Time.fixedDeltaTime); // CORRECT
// Or apply forces:
rb.AddForce(Vector3.forward * speed);
```

### Do NOT use MeshCollider when primitives suffice

MeshCollider on a simple box-shaped object is wasteful. Use BoxCollider instead -- much cheaper and equally accurate for simple shapes. Reserve MeshCollider for complex concave geometry.

### Do NOT allocate in physics callbacks

```csharp
// BAD: GC allocation every collision
void OnCollisionEnter(Collision other) {
    var enemies = GameObject.FindGameObjectsWithTag("Enemy"); // WRONG
}
// GOOD: Cache in Start(), reuse in callbacks
```

### Do NOT ignore layer masks in raycasts

```csharp
Physics.Raycast(origin, direction, out hit);                        // BAD: hits everything
Physics.Raycast(origin, direction, out hit, 100f,
    LayerMask.GetMask("Ground", "Obstacles"));                      // GOOD: filtered
```

---

## Key API Quick Reference

| Category | Key Members |
|----------|-------------|
| **Physics (static)** | `Raycast`, `RaycastAll`, `RaycastNonAlloc`, `SphereCast`, `BoxCast`, `CapsuleCast`, `Linecast`, `OverlapSphere`, `OverlapBox`, `CheckSphere`, `CheckBox`, `ClosestPoint`, `ComputePenetration`, `Simulate`, `SyncTransforms` |
| **Physics properties** | `gravity`, `defaultContactOffset`, `bounceThreshold`, `sleepThreshold`, `defaultSolverIterations`, `queriesHitTriggers`, `queriesHitBackfaces`, `simulationMode` |
| **Rigidbody** | `mass`, `linearDamping`, `angularDamping`, `useGravity`, `isKinematic`, `linearVelocity`, `angularVelocity`, `interpolation`, `collisionDetectionMode`, `AddForce()`, `AddTorque()`, `MovePosition()`, `MoveRotation()`, `Sleep()`, `WakeUp()` |
| **Callbacks** | `OnCollisionEnter(Collision)`, `OnCollisionStay`, `OnCollisionExit`, `OnTriggerEnter(Collider)`, `OnTriggerStay`, `OnTriggerExit` |

See `references/physics3d-api.md` for full method signatures, parameters, and overloads.
See `references/physics2d-api.md` for the complete 2D physics API.

---

## CharacterController

For non-physics-driven character movement (FPS controllers, NPCs), use `CharacterController` instead of Rigidbody. It handles slopes, steps, and collision sliding without physics simulation. See [references/character-controller.md](references/character-controller.md) for full API, patterns, and CharacterController vs Rigidbody comparison.

## Related Skills

- **unity-foundations** -- GameObject hierarchy, components, transforms, layers
- **unity-scripting** -- MonoBehaviour lifecycle (Update vs FixedUpdate), coroutines
- **unity-2d** -- 2D game development patterns, sprite rendering

---

## Additional Resources

- [Physics Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/PhysicsSection.html) | [Rigidbody](https://docs.unity3d.com/6000.3/Documentation/Manual/RigidbodiesOverview.html) | [Colliders](https://docs.unity3d.com/6000.3/Documentation/Manual/CollidersOverview.html) | [Collisions](https://docs.unity3d.com/6000.3/Documentation/Manual/collision-section.html) | [Joints](https://docs.unity3d.com/6000.3/Documentation/Manual/Joints.html)
- [Physics API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.html) | [Physics.Raycast](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics.Raycast.html) | [Rigidbody API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Rigidbody.html)
- [2D Physics](https://docs.unity3d.com/6000.3/Documentation/Manual/2d-physics/2d-physics.html) | [Collision Detection Modes](https://docs.unity3d.com/6000.3/Documentation/Manual/collision-detection.html)
