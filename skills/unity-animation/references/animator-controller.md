# Animator Controller Reference

> Based on Unity 6.3 LTS documentation

## Overview

An Animator Controller is an asset that arranges and maintains a set of Animation Clips and associated Animation Transitions for a character or animated GameObject. It functions as a state machine -- a graph of nodes and connecting lines resembling a flowchart.

**Source:** [Animator Controller](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AnimatorController.html)

## Creating an Animator Controller

Right-click in the Project window > **Create > Animator Controller**

Unity auto-creates a controller when you:
- Begin animating a GameObject via the Animation Window
- Attach animation clips directly to a GameObject

## State Machine Structure

### States

Each state represents an animation action. When the state machine enters a state, it plays the associated Animation Clip or Blend Tree.

**Default states:**
- **Entry** -- The initial entry point; connects to the default state (shown in orange)
- **Any State** -- Represents all states; transitions from Any State apply from any current state
- **Exit** -- Exits the current state machine (returns to parent or stops)

**Creating states:**
- Right-click in Animator window > Create State > Empty / From New Blend Tree
- Drag an Animation Clip into the Animator window to auto-create a state

### Sub-State Machines

Nested state machines for hierarchical organization. Group related states to reduce visual clutter in complex controllers.

- Right-click > Create Sub-State Machine
- Double-click to enter the sub-state machine graph
- Sub-state machines appear as hexagonal nodes in the parent

## Parameters

Parameters are variables defined in the controller that scripts can read and write to influence state machine behavior.

### Parameter Types

| Type | Description | UI Control | Script Methods |
|------|-------------|------------|----------------|
| **Float** | Decimal number | Slider/field | `SetFloat()` / `GetFloat()` |
| **Int** | Whole number | Number field | `SetInteger()` / `GetInteger()` |
| **Bool** | True/false | Checkbox | `SetBool()` / `GetBool()` |
| **Trigger** | Auto-resetting boolean | Circle button | `SetTrigger()` / `ResetTrigger()` |

**Triggers** are consumed by transitions and automatically reset. They are ideal for one-shot actions (jump, attack, die).

### Scripting Parameters

```csharp
using UnityEngine;

public class SimplePlayer : MonoBehaviour
{
    Animator animator;

    // Cache hash IDs for performance -- avoid string lookups every frame
    static readonly int ForwardHash = Animator.StringToHash("Forward");
    static readonly int StrafeHash = Animator.StringToHash("Strafe");
    static readonly int FireHash = Animator.StringToHash("Fire");
    static readonly int DieHash = Animator.StringToHash("Die");

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        bool fire = Input.GetButtonDown("Fire1");

        // Use damping for smooth blend tree transitions
        animator.SetFloat(ForwardHash, v, 0.1f, Time.deltaTime);
        animator.SetFloat(StrafeHash, h, 0.1f, Time.deltaTime);
        animator.SetBool(FireHash, fire);
    }

    void OnCollisionEnter(Collision col)
    {
        if (col.gameObject.CompareTag("Enemy"))
        {
            animator.SetTrigger(DieHash);
        }
    }
}
```

### Bidirectional Parameter Flow

Animation curves within clips can write to parameters, allowing animations to communicate data back to scripts (e.g., a curve controlling sound pitch variation throughout a walk cycle).

## Layers

Layers allow managing complex state machines across different body parts or animation concerns.

### Layer Settings

| Setting | Description |
|---------|-------------|
| **Weight** | Influence of this layer (0 to 1) |
| **Blending Mode** | Override or Additive |
| **Avatar Mask** | Restricts animation to specific body parts |
| **Sync** | Mirrors another layer's state machine structure |
| **Timing** | When synced, balances animation duration by weight |

### Blending Modes

- **Override** -- Replaces animation from previous layers entirely for affected body parts
- **Additive** -- Adds animation on top of previous layers (e.g., breathing layer added to locomotion)

### Avatar Masks

Restrict a layer to specific body parts. For example:
- Lower-body layer: walking, jumping (mask includes legs, root)
- Upper-body layer: throwing, shooting (mask includes arms, head, spine)

An "M" symbol appears on layers with masks applied.

### Synced Layers

Reuse the state machine structure from another layer while swapping animation clips:
- Enable **Sync** checkbox and select the source layer
- State machine changes apply only to the source layer
- Animation clip selections remain unique to each synced layer
- An "S" symbol marks synced layers

### Scripting Layers

```csharp
// Set upper body layer weight
int upperBodyLayer = animator.GetLayerIndex("UpperBody");
animator.SetLayerWeight(upperBodyLayer, 1.0f);

// Get layer info
string layerName = animator.GetLayerName(0);
int layerCount = animator.layerCount;
```

## Transitions

Transitions define how the state machine switches or blends between states.

### Transition Settings

| Setting | Description |
|---------|-------------|
| **Has Exit Time** | Transition triggers at a normalized time (e.g., 0.75 = 75%) |
| **Exit Time** | The normalized time at which the transition can begin |
| **Fixed Duration** | When enabled, duration is in seconds; otherwise fraction of source |
| **Transition Duration** | Blend period between states |
| **Transition Offset** | Where destination state begins (0.5 = midpoint) |
| **Interruption Source** | Which transitions can interrupt this one |
| **Ordered Interruption** | Whether parsing stops at current transition |

### Conditions

Each condition requires:
1. An animation parameter
2. A conditional predicate (Greater, Less, Equals, NotEqual)
3. A threshold value

Multiple conditions on one transition act as AND -- all must be satisfied. When Has Exit Time is also enabled, conditions are only checked after the exit time.

### Interruption Source Options

| Option | Behavior |
|--------|----------|
| None | Cannot be interrupted |
| Current State | Only transitions from current state can interrupt |
| Next State | Only transitions from destination state can interrupt |
| Current State then Next State | Check current first, then next |
| Next State then Current State | Check next first, then current |

### Direct State Playback (Script-Driven)

```csharp
// Play state immediately (resets state)
animator.Play("Attack");

// Play with specific start time (normalized)
animator.Play("Attack", 0, 0.5f);

// Crossfade with normalized duration
animator.CrossFade("Run", 0.1f);

// Crossfade with fixed time duration in seconds
animator.CrossFadeInFixedTime("Run", 0.25f);

// Check state
AnimatorStateInfo info = animator.GetCurrentAnimatorStateInfo(0);
if (info.IsName("Idle") && !animator.IsInTransition(0))
{
    animator.CrossFadeInFixedTime("Walk", 0.2f);
}
```

## State Machine Behaviours

Scripts inheriting `StateMachineBehaviour` attach to states for lifecycle event handling.

### Callback Methods

| Callback | When Called |
|----------|------------|
| `OnStateEnter` | First update frame when state is evaluated |
| `OnStateUpdate` | Each update frame (except first and last) |
| `OnStateExit` | Last update frame when leaving state |
| `OnStateMove` | During Animator Root Motion pass |
| `OnStateIK` | During Animator IK pass |
| `OnStateMachineEnter` | First frame entering a sub-state machine |
| `OnStateMachineExit` | Last frame exiting a sub-state machine |

### Implementation

```csharp
using UnityEngine;

public class PatrolState : StateMachineBehaviour
{
    public float detectionRange = 10f;
    private Transform player;

    override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        player = GameObject.FindWithTag("Player")?.transform;
    }

    override public void OnStateUpdate(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        if (player == null) return;

        float distance = Vector3.Distance(animator.transform.position, player.position);
        if (distance < detectionRange)
        {
            animator.SetTrigger("Chase");
        }
    }

    override public void OnStateExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // Cleanup patrol state
    }
}
```

### Adding to States

1. Select a state in the Animator window
2. Click **Add Behaviour** in the Inspector
3. Create new or select existing StateMachineBehaviour script

### Performance Note

StateMachineBehaviour callbacks introduce synchronization points that break parallel Animator evaluation. Minimize usage to preserve performance; prefer script-side logic when possible.

## Animator Override Controller

Replaces animation clips in a base Animator Controller while keeping structure, parameters, and logic intact.

### Setup

1. **Assets > Create > Animation > Animator Override Controller**
2. Assign a base Animator Controller in the Inspector
3. Map original clips to character-specific override clips
4. Assign the Override Controller to a character's Animator component

### Use Case

Multiple character types (goblin, ogre, elf) sharing identical state machine logic but using different animation clips.

### Critical Requirement

**Always use normalized time for transition exit times**, not seconds. If override clips have different durations than originals, fixed-time exit times may be skipped.

### Runtime Swap

```csharp
using UnityEngine;

public class CharacterSkinSwap : MonoBehaviour
{
    public AnimatorOverrideController[] characterOverrides;
    Animator animator;

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    public void SwapCharacter(int index)
    {
        animator.runtimeAnimatorController = characterOverrides[index];
        // Rebind if bindings have changed
        animator.Rebind();
    }
}
```

## Performance Optimization

### Rebind Operations (Expensive)

Triggered by: scene loading, controller changes, override controller modifications, PlayableGraph changes, manual `Rebind()`, or GameObject activation.

**Minimize by:**
- Using single controllers where possible
- Prebuilt override controllers (not runtime assembly)
- Maintaining small PlayableGraphs
- Disabling Animator component instead of deactivating the entire GameObject

### Parallel Execution

- Default Animator updates use parallel execution across CPU cores
- Manual `Update()` calls bypass parallel execution
- Single-thread write limitation per Transform hierarchy -- avoid grouping multiple Animators under a shared root GameObject

### Culling

`cullingMode` controls behavior when renderers are not visible:
- Updates root position only (default)
- Full transform and property updates
- Always update regardless of visibility

### State Machine Overhead

State machines continuously evaluate transitions even at idle. For single-shot animations, consider the legacy Animation component or Playables API instead.

## Editor Navigation

| Shortcut | Action |
|----------|--------|
| Scroll wheel | Zoom in/out |
| F | Focus on selected states |
| A | Fit all states in view |
| Play Mode | Auto-pan to active states |

## Related Documentation

- [Animation Parameters](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationParameters.html)
- [Animation Layers](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationLayers.html)
- [Animator Override Controller](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimatorOverrideController.html)
- [State Machine Behaviours](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/StateMachineBehaviour.html)
- [Animator Scripting Reference](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Animator.html)
