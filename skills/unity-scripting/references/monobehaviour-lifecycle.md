# MonoBehaviour Lifecycle Reference

> Source: [Unity 6.3 MonoBehaviour API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/MonoBehaviour.html) and [Execution Order](https://docs.unity3d.com/6000.3/Documentation/Manual/execution-order.html)

## Overview

MonoBehaviour is the base class that many Unity scripts derive from. MonoBehaviours always exist as a Component of a GameObject and can be added via `GameObject.AddComponent<T>()`.

When destroyed, the C# object remains in memory until garbage collected. It behaves as `null` in Unity's equality checks but does NOT support null-conditional (`?.`) or null-coalescing (`??`) operators.

## Complete Execution Order

### Phase 1: Initialization

```
Scene Load / Object Instantiation
         |
         v
   [Awake]            Called once when script instance loads.
         |              Called even if the MonoBehaviour is disabled.
         |              Called in arbitrary order across GameObjects.
         |              Use for: self-initialization, caching GetComponent references.
         v
   [OnEnable]          Called each time the component/object is enabled.
         |              Use for: subscribing to events, resetting state.
         v
   (SceneManager.sceneLoaded fires -- after OnEnable, before Start)
         |
         v
   [Start]             Called once, before the first Update, only if enabled.
                        Use for: initialization that depends on other objects' Awake().
```

### Phase 2: Game Loop (repeats every frame)

```
  +===============================================+
  |  FIXED UPDATE LOOP (may run 0..N times)       |
  |                                               |
  |  [FixedUpdate]                                |
  |       |                                       |
  |  Internal Physics Simulation                  |
  |       |                                       |
  |  [OnTriggerEnter/Stay/Exit]                   |
  |  [OnCollisionEnter/Stay/Exit]                 |
  |       |                                       |
  |  [yield WaitForFixedUpdate resumes]           |
  +===============================================+
         |
         v
  [Update]                Called once per frame.
         |                Use for: input polling, non-physics game logic.
         v
  [yield return null resumes]
  [yield WaitForSeconds resumes]
         |
         v
  Internal Animation Update
  [OnAnimatorMove]        Override root motion handling.
  [OnAnimatorIK]          Set up IK targets (after animation eval).
         |
         v
  StateMachineBehaviour callbacks:
  [OnStateMachineEnter/Exit]
  [OnStateEnter/Update/Exit]
  [OnStateMove]
  [OnStateIK]
         |
         v
  [LateUpdate]            Called after all Update functions.
                          Use for: camera follow, post-movement adjustments.
```

### Phase 3: Rendering

Rendering callbacks execute only on MonoBehaviours attached to the same object as an enabled Camera component (built-in render pipeline).

```
  [OnPreCull]              Before camera culls the scene.
  [OnBecameVisible]        When renderer becomes visible by any camera.
  [OnBecameInvisible]      When renderer is no longer visible by any camera.
  [OnWillRenderObject]     Once per camera if object is visible.
  [OnPreRender]            Before camera starts rendering.
  [OnRenderObject]         After regular rendering; draw custom geometry.
  [OnPostRender]           After camera finishes rendering.
  [OnRenderImage]          After rendering; apply post-processing.
```

### Phase 4: GUI

```
  [OnGUI]                  Called for GUI events (may fire multiple times per frame).
```

### Phase 5: End of Frame

```
  [yield WaitForEndOfFrame resumes]
```

### Phase 6: Deactivation and Teardown

```
  [OnDisable]              Called when component or GameObject is disabled.
                          Use for: unsubscribing from events.
         |
         v
  [OnDestroy]             Called before the object is destroyed.
                          Use for: final cleanup.
         |
         v
  [OnApplicationQuit]     Called on all objects before application exits.
```

## Complete Callback Reference

### Initialization

| Callback | Signature | Notes |
|----------|-----------|-------|
| `Awake` | `void Awake()` | Called once when script loads, even if disabled |
| `OnEnable` | `void OnEnable()` | Called each time component is enabled |
| `Start` | `void Start()` | Called once before first Update, only if enabled |
| `Reset` | `void Reset()` | Editor-only: called when component is first added or Reset is used |

### Update

| Callback | Signature | Notes |
|----------|-----------|-------|
| `FixedUpdate` | `void FixedUpdate()` | Fixed timestep (default 0.02s) |
| `Update` | `void Update()` | Once per frame |
| `LateUpdate` | `void LateUpdate()` | After all Update calls |

### Physics (3D)

| Callback | Signature |
|----------|-----------|
| `OnCollisionEnter` | `void OnCollisionEnter(Collision collision)` |
| `OnCollisionStay` | `void OnCollisionStay(Collision collision)` |
| `OnCollisionExit` | `void OnCollisionExit(Collision collision)` |
| `OnTriggerEnter` | `void OnTriggerEnter(Collider other)` |
| `OnTriggerStay` | `void OnTriggerStay(Collider other)` |
| `OnTriggerExit` | `void OnTriggerExit(Collider other)` |
| `OnControllerColliderHit` | `void OnControllerColliderHit(ControllerColliderHit hit)` |
| `OnJointBreak` | `void OnJointBreak(float breakForce)` |

### Physics (2D)

| Callback | Signature |
|----------|-----------|
| `OnCollisionEnter2D` | `void OnCollisionEnter2D(Collision2D collision)` |
| `OnCollisionStay2D` | `void OnCollisionStay2D(Collision2D collision)` |
| `OnCollisionExit2D` | `void OnCollisionExit2D(Collision2D collision)` |
| `OnTriggerEnter2D` | `void OnTriggerEnter2D(Collider2D other)` |
| `OnTriggerStay2D` | `void OnTriggerStay2D(Collider2D other)` |
| `OnTriggerExit2D` | `void OnTriggerExit2D(Collider2D other)` |
| `OnJointBreak2D` | `void OnJointBreak2D(Joint2D brokenJoint)` |

### Input / Mouse

| Callback | Notes |
|----------|-------|
| `OnMouseDown` | Mouse button pressed over collider |
| `OnMouseDrag` | Mouse dragging over collider |
| `OnMouseUp` | Mouse button released |
| `OnMouseUpAsButton` | Released over same collider as pressed |
| `OnMouseEnter` | Mouse enters collider area |
| `OnMouseExit` | Mouse exits collider area |
| `OnMouseOver` | Mouse is over collider |

### Rendering

| Callback | Notes |
|----------|-------|
| `OnPreCull` | Before camera culls |
| `OnPreRender` | Before camera renders |
| `OnPostRender` | After camera renders |
| `OnRenderObject` | After scene rendering; custom geometry |
| `OnRenderImage` | Post-processing on render image |
| `OnWillRenderObject` | Once per camera if visible |
| `OnBecameVisible` | Renderer visible by any camera |
| `OnBecameInvisible` | Renderer no longer visible |

### Animation

| Callback | Notes |
|----------|-------|
| `OnAnimatorIK(int layerIndex)` | Set IK targets |
| `OnAnimatorMove` | Override root motion |

### Particles

| Callback | Notes |
|----------|-------|
| `OnParticleCollision` | Particle hits collider |
| `OnParticleTrigger` | Particle meets trigger conditions |
| `OnParticleSystemStopped` | Particle system finishes |
| `OnParticleUpdateJobScheduled` | Particle update job is scheduled |

### Application

| Callback | Notes |
|----------|-------|
| `OnApplicationFocus(bool hasFocus)` | App gains/loses focus |
| `OnApplicationPause(bool pauseStatus)` | App pauses/unpauses |
| `OnApplicationQuit` | Before application exits |

### Audio

| Callback | Notes |
|----------|-------|
| `OnAudioFilterRead(float[] data, int channels)` | DSP audio processing |

### Deactivation

| Callback | Notes |
|----------|-------|
| `OnDisable` | Component or GameObject disabled |
| `OnDestroy` | Before object destruction |

### Editor-Only

| Callback | Notes |
|----------|-------|
| `OnValidate` | Script loaded or Inspector value changes |
| `OnDrawGizmos` | Draw gizmos every frame in Scene view |
| `OnDrawGizmosSelected` | Draw gizmos only when selected |

### Hierarchy

| Callback | Notes |
|----------|-------|
| `OnTransformChildrenChanged` | Child list changes |
| `OnTransformParentChanged` | Parent changes |

## Public Methods

### Invoke

```csharp
// Call method after delay (string-based -- prefer coroutines or Awaitable)
Invoke("MethodName", 2.0f);
InvokeRepeating("MethodName", 0.5f, 1.0f); // delay, then repeat interval
CancelInvoke("MethodName");
bool pending = IsInvoking("MethodName");
```

### Coroutines

```csharp
Coroutine handle = StartCoroutine(MyCoroutine());
StopCoroutine(handle);       // Stop specific coroutine
StopAllCoroutines();         // Stop all coroutines on this MonoBehaviour
```

### Utility

```csharp
print("Message");            // Shorthand for Debug.Log
```

## MonoBehaviour Properties (Unity 6)

```csharp
// CancellationToken raised when MonoBehaviour is destroyed
CancellationToken token = destroyCancellationToken;

// Check initialization state
if (didAwake) { /* Awake has been called */ }
if (didStart) { /* Start has been called */ }

// Allow execution in Edit mode
runInEditMode = true;

// Disable GUI layout phase for performance
useGUILayout = false;
```

## Script Template

```csharp
using UnityEngine;

public class MyComponent : MonoBehaviour
{
    [SerializeField] private float _speed = 5f;

    private Rigidbody _rb;
    private Transform _cachedTransform;

    void Awake()
    {
        _rb = GetComponent<Rigidbody>();
        _cachedTransform = transform;
    }

    void OnEnable()
    {
        // Subscribe to events
    }

    void OnDisable()
    {
        // Unsubscribe from events
    }

    void Start()
    {
        // Init that depends on other objects
    }

    void FixedUpdate()
    {
        // Physics calculations
    }

    void Update()
    {
        // Per-frame logic
    }

    void LateUpdate()
    {
        // Post-update adjustments
    }
}
```

## Important Notes

- You cannot rely on the order in which the same event function is invoked for different GameObjects unless configured via **Edit > Project Settings > Script Execution Order**.
- Empty event functions (`Update()`, `FixedUpdate()`, etc.) still have overhead -- remove them if unused.
- `Awake()` is called even on disabled MonoBehaviours; `Start()` is not.
- Coroutines stop when the GameObject is deactivated but NOT when `enabled = false` on the MonoBehaviour.
