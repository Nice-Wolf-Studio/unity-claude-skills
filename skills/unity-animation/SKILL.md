---
name: unity-animation
description: >
  Unity 6 animation system guide. Use when working with Animator Controllers, animation state machines, blend trees, animation clips, Avatar system, humanoid rigs, root motion, animation events, Timeline, or Cinemachine. Based on Unity 6.3 LTS documentation.
---

# Unity Animation System

## Animation System Overview

Unity's Mecanim animation system is built on three interconnected components:

1. **Animation Clips** -- Unit pieces of motion (Idle, Walk, Run)
2. **Animator Controller** -- State machine organizing clips into a flowchart of states and transitions
3. **Avatar System** -- Maps humanoid character skeletons to a common internal format for retargeting

The **Animator** component is attached to GameObjects and references both the Animator Controller and Avatar assets needed for playback.

### Animation Types

- **Humanoid** -- Requires Avatar configuration; supports retargeting between different character rigs; 15-20% more CPU-intensive than Generic
- **Generic** -- Animates Transform or MonoBehaviour properties on specific hierarchies; not transferable between different hierarchies
- **Legacy** -- Older Animation component; use for simple single-shot or UI animations

## Animator Controller

An Animator Controller asset arranges Animation Clips and Transitions for a character or animated GameObject.

**Creating:** Right-click in Project window > Create > Animator Controller

### Key Components

- **States** -- Each state plays an associated Animation Clip or Blend Tree
- **Transitions** -- Define how and when the state machine switches between states
- **Parameters** -- Variables (Float, Int, Bool, Trigger) that scripts set to control transitions
- **Layers** -- Separate state machines for different body parts or animation concerns
- **Sub-State Machines** -- Nested state machines for hierarchical organization

### Parameters

Four types are available:

| Type | Description | Script Method |
|------|-------------|---------------|
| Float | Decimal number | `SetFloat()` / `GetFloat()` |
| Int | Whole number | `SetInteger()` / `GetInteger()` |
| Bool | True/false | `SetBool()` / `GetBool()` |
| Trigger | Auto-resetting bool | `SetTrigger()` / `ResetTrigger()` |

```csharp
using UnityEngine;

public class PlayerAnimController : MonoBehaviour
{
    Animator animator;

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        // Note: Uses legacy Input Manager for simplicity. See unity-input for the new Input System.
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        bool fire = Input.GetButtonDown("Fire1");

        animator.SetFloat("Forward", v);
        animator.SetFloat("Strafe", h);
        animator.SetBool("Fire", fire);
    }

    void OnCollisionEnter(Collision col)
    {
        if (col.gameObject.CompareTag("Enemy"))
        {
            animator.SetTrigger("Die");
        }
    }
}
```

### Animator Override Controller

Replaces animation clips in an Animator Controller while keeping structure, parameters, and logic intact. Useful for multiple characters sharing the same state machine but using different clips.

**Critical:** Set transition exit times in **normalized time** (not seconds) when using Override Controllers, or exit times may be ignored if override clips have different durations.

### Layers

- **Override mode** -- Replaces animation from previous layers
- **Additive mode** -- Adds animation on top of previous layers
- **Avatar Mask** -- Restricts a layer to specific body parts (e.g., upper body only)
- **Synced Layers** -- Reuse state machine structure with different clips

## State Machines and Transitions

### States

Each state in the Animator Controller represents a distinct action. Special states include:
- **Entry** -- Default entry point
- **Any State** -- Transitions from any current state
- **Exit** -- Exits the current state machine or sub-state machine

### Transitions

Transitions define how states blend into each other.

| Setting | Description |
|---------|-------------|
| **Has Exit Time** | Transition triggers at a normalized time (e.g., 0.75 = 75% complete) |
| **Transition Duration** | Blend period; in seconds (Fixed Duration) or fraction of source state |
| **Transition Offset** | Where destination state begins playback (0.5 = midpoint) |
| **Conditions** | Parameter-based rules; all must be satisfied simultaneously |
| **Interruption Source** | Which transitions can interrupt: None, Current State, Next State, or combinations |
| **Ordered Interruption** | Whether transition parsing stops at current transition or any valid one |

When both Has Exit Time and Conditions are set, Unity only checks conditions after the exit time.

### State Machine Behaviours

Scripts inheriting `StateMachineBehaviour` attach to states. Callbacks: `OnStateEnter`, `OnStateUpdate`, `OnStateExit`, `OnStateMove`, `OnStateIK`. All receive `(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)`.

```csharp
public class AttackState : StateMachineBehaviour
{
    public AudioClip attackSound;
    override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        AudioSource.PlayClipAtPoint(attackSound, animator.transform.position);
    }
    override public void OnStateExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // Cleanup when leaving state
    }
}
```

## Blend Trees

Blend Trees smoothly blend between multiple similar animations based on parameter values, unlike transitions which switch between distinct states over time.

**Critical requirement:** Animations must be of similar nature and timing. Foot contact points should align in normalized time (e.g., left foot at 0.0, right foot at 0.5).

### Blend Types

- **1D** -- Single parameter controls blending (e.g., speed for walk/run)
- **2D Simple Directional** -- Two parameters, one motion per direction
- **2D Freeform Directional** -- Two parameters, multiple motions per direction
- **2D Freeform Cartesian** -- Two parameters, motions not representing directions
- **Direct** -- Each motion has its own weight parameter (facial animations)

**Creating:** Right-click in Animator Controller > Create State > From New Blend Tree. Double-click to enter the graph. Add child motions via the Inspector.

```csharp
// Driving a locomotion blend tree from script
void Update()
{
    float speed = new Vector3(rb.velocity.x, 0, rb.velocity.z).magnitude;
    float direction = Vector3.SignedAngle(transform.forward,
        rb.velocity.normalized, Vector3.up);

    animator.SetFloat("Speed", speed, 0.1f, Time.deltaTime);
    animator.SetFloat("Direction", direction, 0.1f, Time.deltaTime);
}
```

## Avatar and Humanoid Rigs

The Avatar system identifies models as humanoid and maps body parts for animation retargeting.

### Key Concepts

- **Avatar** -- Maps bone structure to Unity's internal humanoid format
- **Retargeting** -- Animations transfer between different humanoid rigs sharing the same Avatar mapping
- **Muscle Definitions** -- Intuitive control in muscle space rather than bone space

### Setup

1. Select model in Project window
2. In Rig tab of Import Settings, set Animation Type to **Humanoid**
3. Configure Avatar mapping (Unity auto-maps when possible)
4. Verify and adjust bone assignments in the Avatar Configuration window

## Root Motion

Root motion transfers animation-driven movement to the GameObject's Transform.

### Architecture

- **Body Transform** -- Character's center of mass; stores world-space curves
- **Root Transform** -- Y-plane projection of Body Transform; computed at runtime each frame

### Clip Inspector Settings

| Setting | Purpose |
|---------|---------|
| **Bake Into Pose (Rotation)** | Orientation stays on body; GameObject receives no rotation |
| **Bake Into Pose (Y)** | Vertical motion stays on body; enable for all except jumps |
| **Bake Into Pose (XZ)** | Horizontal motion stays on body; enable for idle clips to prevent drift |
| **Based Upon** | Body Orientation (mocap), Original (keyframed), Feet (prevents floating) |

`Animator.gravityWeight` is driven by Bake Into Pose Position Y: enabled = 1, disabled = 0.

```csharp
// Custom root motion handling
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class RootMotionController : MonoBehaviour
{
    Animator animator;
    CharacterController controller;

    void Start()
    {
        animator = GetComponent<Animator>();
        controller = GetComponent<CharacterController>();
        animator.applyRootMotion = false; // We handle it manually
    }

    void OnAnimatorMove()
    {
        // Apply root motion through CharacterController
        Vector3 deltaPosition = animator.deltaPosition;
        deltaPosition.y -= 9.81f * Time.deltaTime; // Add gravity
        controller.Move(deltaPosition);
        transform.rotation *= animator.deltaRotation;
    }
}
```

## Animation Events

Animation events trigger functions at designated points in the animation timeline.

### Parameter Types

- **Float** -- Numeric values (e.g., volume)
- **Int** -- Integer values
- **String** -- Text data
- **Object** -- GameObject or Prefab references

### Setup

1. In Animation tab, expand Events section
2. Position playback head on desired frame
3. Click Add Event
4. Set Function name matching a method on an attached script

```csharp
using UnityEngine;

public class FootstepHandler : MonoBehaviour
{
    public AudioClip[] footstepSounds;
    public GameObject dustPrefab;

    // Called by animation event -- function name must match event
    public void PlayFootstep(int footIndex)
    {
        if (footstepSounds.Length > 0)
        {
            int clipIndex = Random.Range(0, footstepSounds.Length);
            AudioSource.PlayClipAtPoint(footstepSounds[clipIndex], transform.position);
        }
    }

    // Called by animation event passing an Object parameter
    public void SpawnEffect(Object effectPrefab)
    {
        Instantiate((GameObject)effectPrefab, transform.position, Quaternion.identity);
    }
}
```

## Timeline

Timeline creates cinematic content, gameplay sequences, audio sequences, and particle effects. Package: `com.unity.timeline` (v1.8.11, Unity 6.3 compatible).

### Core Components

- **Timeline Asset** -- Defines tracks, clips, and their arrangement
- **Timeline Instance** -- Runtime instance bound to specific scene objects
- **Playable Director** -- Component that plays Timeline assets and binds tracks to scene objects

### Track Types

| Track | Purpose |
|-------|---------|
| Animation | Controls Animator on bound GameObject |
| Audio | Plays AudioClips on bound AudioSource |
| Activation | Enables/disables bound GameObject |
| Signal | Fires events at specific times via SignalReceiver |
| Control | Triggers sub-Timelines, particle systems, or other Playable Directors |
| Playable | Custom track using Playables API |

### Features

- Animation recording directly in Timeline
- Humanoid animation support
- Animation Override tracks
- Sub-Timelines for modular composition

## Scripting Animation

### Inverse Kinematics (IK)

Requires: Humanoid Avatar, IK Pass enabled on layer.

```csharp
using UnityEngine;

public class IKController : MonoBehaviour
{
    Animator animator;
    public bool ikActive = true;
    public Transform rightHandTarget;
    public Transform lookTarget;

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void OnAnimatorIK()
    {
        if (animator == null || !ikActive) return;

        // Look at target
        animator.SetLookAtWeight(1f);
        animator.SetLookAtPosition(lookTarget.position);

        // Right hand IK
        animator.SetIKPositionWeight(AvatarIKGoal.RightHand, 1f);
        animator.SetIKRotationWeight(AvatarIKGoal.RightHand, 1f);
        animator.SetIKPosition(AvatarIKGoal.RightHand, rightHandTarget.position);
        animator.SetIKRotation(AvatarIKGoal.RightHand, rightHandTarget.rotation);
    }
}
```

### Direct State Playback

```csharp
// Play state immediately
animator.Play("Attack");

// Play with normalized time offset (start at 50%)
animator.Play("Attack", 0, 0.5f);

// Crossfade into state over 0.25 seconds
animator.CrossFadeInFixedTime("Run", 0.25f);

// Crossfade using normalized time
animator.CrossFade("Run", 0.1f);
```

### Querying State Information

```csharp
AnimatorStateInfo stateInfo = animator.GetCurrentAnimatorStateInfo(0);

if (stateInfo.IsName("Attack"))
{
    Debug.Log("Currently attacking");
}

if (stateInfo.normalizedTime >= 1.0f && !animator.IsInTransition(0))
{
    Debug.Log("Animation finished");
}

// Use hash for performance
int runHash = Animator.StringToHash("Run");
if (animator.HasState(0, runHash))
{
    animator.Play(runHash);
}
```

### Target Matching

```csharp
// Match character's hand to a ledge position during climb animation
animator.MatchTarget(ledgePosition, Quaternion.identity, AvatarTarget.RightHand,
    new MatchTargetWeightMask(Vector3.one, 0f), 0.1f, 0.4f);
```

## Common Patterns

### Character Locomotion Controller

```csharp
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class LocomotionController : MonoBehaviour
{
    Animator animator;
    static readonly int SpeedHash = Animator.StringToHash("Speed");
    static readonly int GroundedHash = Animator.StringToHash("Grounded");
    static readonly int JumpHash = Animator.StringToHash("Jump");

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        float speed = Input.GetAxis("Vertical");
        animator.SetFloat(SpeedHash, Mathf.Abs(speed), 0.1f, Time.deltaTime);
        animator.SetBool(GroundedHash, IsGrounded());

        if (Input.GetButtonDown("Jump") && IsGrounded())
        {
            animator.SetTrigger(JumpHash);
        }
    }

    bool IsGrounded()
    {
        return Physics.Raycast(transform.position + Vector3.up * 0.1f, Vector3.down, 0.2f);
    }
}
```

### Runtime Override Controller Swap

```csharp
using UnityEngine;

public class WeaponAnimSwap : MonoBehaviour
{
    public AnimatorOverrideController swordOverride;
    public AnimatorOverrideController bowOverride;
    Animator animator;

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    public void EquipSword()
    {
        animator.runtimeAnimatorController = swordOverride;
    }

    public void EquipBow()
    {
        animator.runtimeAnimatorController = bowOverride;
    }
}
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| String parameters every frame | GC allocation, slow lookup | Cache hashes with `Animator.StringToHash()` |
| Humanoid rig for non-humanoid objects | 15-20% unnecessary CPU overhead | Use Generic animation type for props, animals, effects |
| Multiple Animators under shared root | Single-thread write limitation per hierarchy blocks parallelism | Give each Animator its own root GameObject |
| StateMachineBehaviour overuse | Creates synchronization points, breaks parallel evaluation | Minimize SMB callbacks; prefer script-side logic |
| RectTransform animation via Animator | Deterministic write issues | Use legacy Animation component for UI animation |
| Complex state machines for single-shot anims | Continuous transition evaluation even at idle | Use Animation component or Playables API instead |
| Calling `Animator.Update()` manually | Bypasses parallel execution | Use PlayableGraph for manual control with parallelism |
| Not setting transition exit time to normalized | Override Controller clips may skip transitions | Always use normalized time for exit times |
| Forgetting `Rebind()` after controller swap | Stale bindings cause incorrect playback | Call `Rebind()` when changing controllers at runtime |
| Bake Into Pose disabled on idle clips (XZ) | Drift accumulation on idle animations | Enable Bake Into Pose XZ for stationary clips |

## Key API Quick Reference

### Animator -- Essential Properties

`applyRootMotion`, `speed`, `updateMode` (Normal/AnimatePhysics/UnscaledTime), `cullingMode`, `deltaPosition`, `deltaRotation`, `velocity`, `isHuman`, `layerCount`, `bodyPosition`, `gravityWeight`

### Animator -- Essential Methods

- **Playback:** `Play(state, layer, time)`, `CrossFade(state, duration)`, `CrossFadeInFixedTime(state, duration)`
- **Parameters:** `SetFloat/Int/Bool/Trigger(name, value)`, `GetFloat/Int/Bool(name)`, `ResetTrigger(name)`
- **State Query:** `GetCurrentAnimatorStateInfo(layer)`, `GetNextAnimatorStateInfo(layer)`, `IsInTransition(layer)`
- **IK:** `SetIKPosition/Rotation(goal, value)`, `SetIKPositionWeight/RotationWeight(goal, weight)`, `SetLookAtPosition(pos)`
- **Utility:** `MatchTarget(...)`, `GetBoneTransform(bone)`, `Rebind()`, `StringToHash(name)`, `SetLayerWeight(layer, weight)`

## Related Skills

- **unity-foundations** -- Core Unity concepts, GameObjects, Components, project structure
- **unity-scripting** -- MonoBehaviour lifecycle, C# patterns, event systems
- **unity-graphics** -- Rendering, materials, shaders (relevant for animated material properties)

## Additional Resources

- [Animation Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationOverview.html) | [Animator Controller](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AnimatorController.html) | [Animation Clips](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationClips.html)
- [State Machines](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationStateMachines.html) | [Parameters](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationParameters.html) | [Layers](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationLayers.html)
- [Blend Trees](https://docs.unity3d.com/6000.3/Documentation/Manual/class-BlendTree.html) | [Avatar Setup](https://docs.unity3d.com/6000.3/Documentation/Manual/AvatarCreationandSetup.html) | [Root Motion](https://docs.unity3d.com/6000.3/Documentation/Manual/RootMotion.html)
- [Animation Events](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationEventsOnImportedClips.html) | [IK](https://docs.unity3d.com/6000.3/Documentation/Manual/InverseKinematics.html) | [Override Controller](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimatorOverrideController.html)
- [Animator API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Animator.html) | [StateMachineBehaviour API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/StateMachineBehaviour.html) | [Timeline](https://docs.unity3d.com/Packages/com.unity.timeline@1.8/manual/index.html)
