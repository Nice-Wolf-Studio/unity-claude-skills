# CharacterController API Reference

> Unity 6.3 LTS (6000.3)
> [CharacterController](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/CharacterController.html)

## Overview

`CharacterController` is a capsule-based movement component that handles collision detection **without** using a Rigidbody. It does not respond to forces, gravity, or physics simulation — you control movement entirely through code.

### When to Use CharacterController vs Rigidbody

| Feature | CharacterController | Rigidbody |
|---------|-------------------|-----------|
| Gravity | Manual (apply yourself) | Automatic |
| Forces/Impulses | Not supported | Supported |
| Slope handling | Built-in (slopeLimit) | Manual or PhysicMaterial |
| Step climbing | Built-in (stepOffset) | Not built-in |
| Collision response | Slides along surfaces | Bounces/pushes |
| Best for | Player characters, NPCs | Physics-driven objects |
| FixedUpdate required | No (use Update) | Yes |

**Rule of thumb:** Use `CharacterController` for player/NPC movement where you want precise, predictable control. Use `Rigidbody` for physics-driven gameplay (vehicles, ragdolls, thrown objects).

---

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `center` | `Vector3` | Center of the capsule relative to transform position |
| `height` | `float` | Height of the capsule |
| `radius` | `float` | Radius of the capsule |
| `slopeLimit` | `float` | Max walkable slope in degrees (default 45) |
| `stepOffset` | `float` | Max step height in meters (default 0.3) |
| `skinWidth` | `float` | Collision skin width — should be >10% of radius |
| `minMoveDistance` | `float` | Minimum distance threshold for movement |
| `detectCollisions` | `bool` | Whether other rigidbodies/controllers collide with this |
| `enableOverlapRecovery` | `bool` | Auto-depenetrate from static objects |
| `isGrounded` | `bool` | Was the controller touching ground during last `Move()` call |
| `velocity` | `Vector3` | Current velocity of the character (read-only) |
| `collisionFlags` | `CollisionFlags` | What part collided during last `Move()` (None, Sides, Above, Below) |

---

## Methods

### Move(Vector3 motion)

```csharp
CollisionFlags Move(Vector3 motion)
```

Moves the character by `motion`, constrained by collisions. Does **not** apply gravity automatically. Returns `CollisionFlags` indicating what was hit.

### SimpleMove(Vector3 speed)

```csharp
bool SimpleMove(Vector3 speed)
```

Moves at `speed` (m/s, not per-frame delta). Automatically applies gravity. Cannot jump (vertical component ignored). Returns `true` if grounded.

---

## Common Patterns

### First-Person Controller

```csharp
using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class FPSController : MonoBehaviour
{
    [SerializeField] float moveSpeed = 6f;
    [SerializeField] float jumpHeight = 1.2f;
    [SerializeField] float gravity = -20f;

    CharacterController controller;
    Vector3 velocity;

    void Awake() => controller = GetComponent<CharacterController>();

    void Update()
    {
        // Ground check via isGrounded (updated after Move)
        if (controller.isGrounded && velocity.y < 0f)
            velocity.y = -2f; // small downward to keep grounded

        // Horizontal movement (legacy Input; see unity-input for new Input System)
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        Vector3 move = transform.right * h + transform.forward * v;
        controller.Move(move * moveSpeed * Time.deltaTime);

        // Jump
        if (Input.GetButtonDown("Jump") && controller.isGrounded)
            velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);

        // Apply gravity
        velocity.y += gravity * Time.deltaTime;
        controller.Move(velocity * Time.deltaTime);
    }
}
```

### Handling Collisions

```csharp
void OnControllerColliderHit(ControllerColliderHit hit)
{
    // Push rigidbodies the character walks into
    Rigidbody rb = hit.collider.attachedRigidbody;
    if (rb != null && !rb.isKinematic)
    {
        Vector3 pushDir = new Vector3(hit.moveDirection.x, 0, hit.moveDirection.z);
        rb.AddForce(pushDir * 2f, ForceMode.Impulse);
    }
}
```

### Slope and Step Configuration

```csharp
// Recommended settings for typical humanoid character
controller.slopeLimit = 45f;   // Can walk up to 45-degree slopes
controller.stepOffset = 0.4f;  // Can step over 0.4m obstacles
controller.skinWidth = 0.08f;  // Should be > 10% of radius
controller.center = new Vector3(0, 1f, 0); // Capsule center at waist height
```

---

## Anti-Patterns

| What | Why It's Wrong | Fix |
|------|---------------|-----|
| Using `Move()` without applying gravity | Character floats in air | Add `velocity.y += gravity * Time.deltaTime` each frame |
| Checking `isGrounded` before calling `Move()` | `isGrounded` reflects the *last* `Move()` call | Call `Move()` first or use a ground raycast |
| Adding Rigidbody alongside CharacterController | Conflicting movement systems | Use one or the other, not both |
| Setting `skinWidth` too small | Jittering, getting stuck in geometry | Keep skinWidth > 10% of radius |
| Using `SimpleMove()` for jumping | SimpleMove ignores vertical input | Use `Move()` with manual gravity for jump support |

---

## CollisionFlags

```csharp
CollisionFlags flags = controller.Move(motion);
if ((flags & CollisionFlags.Below) != 0) { /* hit ground */ }
if ((flags & CollisionFlags.Above) != 0) { /* hit ceiling */ }
if ((flags & CollisionFlags.Sides) != 0) { /* hit wall */ }
```
