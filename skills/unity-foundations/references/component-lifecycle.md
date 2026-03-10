# Component Lifecycle and Execution Order

> Based on Unity 6.3 documentation: [Execution Order](https://docs.unity3d.com/6000.3/Documentation/Manual/execution-order.html)

## Overview

Unity MonoBehaviour scripts follow a deterministic execution order within a single object. However, as noted in the docs: "You can't rely on the order in which the same event function is invoked for different GameObjects" -- unless explicitly configured via Script Execution Order settings in Project Settings.

## Complete Lifecycle Phases

### Phase 1: Initialization

| Callback | When It Runs |
|----------|--------------|
| `Awake()` | Called when the script instance is being loaded. Always before Start. Called even if the script component is disabled (but the GameObject must be active). |
| `OnEnable()` | Called when the object becomes enabled and active. Called every time the object is re-enabled. |
| `SceneManager.sceneLoaded` | Fires after OnEnable but before Start. |
| `Start()` | Called before the first frame update, only once per script lifetime. Called only if the script is enabled. |

### Phase 2: Physics (Fixed Timestep)

| Callback | When It Runs |
|----------|--------------|
| `FixedUpdate()` | Called at fixed timestep intervals (default 0.02s). Used for physics calculations. May be called multiple times per frame or not at all. |
| `OnTriggerXXX()` | `OnTriggerEnter`, `OnTriggerStay`, `OnTriggerExit` -- called during physics step. |
| `OnCollisionXXX()` | `OnCollisionEnter`, `OnCollisionStay`, `OnCollisionExit` -- called during physics step. |

### Phase 3: Input and Game Logic (Per Frame)

| Callback | When It Runs |
|----------|--------------|
| `Update()` | Called once per frame. Primary location for game logic, input handling, non-physics movement. |
| `LateUpdate()` | Called after all Update calls complete. Used for camera follow, post-processing of positions. |

### Phase 4: Animation

| Callback | When It Runs |
|----------|--------------|
| `OnAnimatorMove()` | Called after animation updates to allow script-driven root motion. |
| `OnAnimatorIK()` | Called during IK pass for setting IK targets. |

### Phase 5: Rendering

| Callback | When It Runs |
|----------|--------------|
| `OnPreCull()` | Before the camera culls the scene. |
| `OnBecameVisible()` | When the renderer becomes visible to any camera. |
| `OnBecameInvisible()` | When the renderer is no longer visible to any camera. |
| `OnWillRenderObject()` | Once per camera if the object is visible. |
| `OnPreRender()` | Before the camera starts rendering. |
| `OnRenderObject()` | After regular rendering; for custom geometry drawing. |
| `OnPostRender()` | After the camera finishes rendering. |
| `OnRenderImage()` | After rendering for post-processing effects. |
| `OnGUI()` | For legacy GUI event handling. May be called multiple times per frame. |
| `OnDrawGizmos()` | For drawing gizmos in the Scene view. |

### Phase 6: Teardown

| Callback | When It Runs |
|----------|--------------|
| `OnDisable()` | When the object becomes disabled or inactive. Called on object destruction before OnDestroy. |
| `OnDestroy()` | When the object is destroyed, after the last frame in which it existed. |
| `OnApplicationQuit()` | When the application is about to quit. |

---

## Lifecycle Code Example

```csharp
using UnityEngine;

public class LifecycleDemo : MonoBehaviour
{
    private Rigidbody rb;

    // INITIALIZATION -- called once when loaded
    void Awake()
    {
        // Best place to set up internal references
        // Called even if the component is disabled
        rb = GetComponent<Rigidbody>();
    }

    void OnEnable()
    {
        // Subscribe to events here
        // Called every time the object is (re-)enabled
        GameEvents.OnPlayerDeath += HandlePlayerDeath;
    }

    void Start()
    {
        // Called once, after Awake, before the first Update
        // Safe to reference other objects that initialized in Awake
        rb.mass = 5f;
    }

    // PHYSICS -- fixed timestep
    void FixedUpdate()
    {
        // Physics calculations go here
        // Consistent timestep regardless of frame rate
        rb.AddForce(Vector3.forward * 10f);
    }

    // GAME LOGIC -- once per frame
    void Update()
    {
        // Input handling, non-physics movement, game state
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        transform.Translate(new Vector3(h, 0, v) * Time.deltaTime);
    }

    void LateUpdate()
    {
        // Camera follow, position adjustments after all Updates
        // Guarantees all objects have finished their Update
    }

    // TEARDOWN
    void OnDisable()
    {
        // Unsubscribe from events to prevent memory leaks
        GameEvents.OnPlayerDeath -= HandlePlayerDeath;
    }

    void OnDestroy()
    {
        // Final cleanup (file handles, native resources)
        Debug.Log(gameObject.name + " destroyed");
    }

    void OnApplicationQuit()
    {
        // Save game state, close connections
    }

    private void HandlePlayerDeath()
    {
        Debug.Log("Player died");
    }
}
```

---

## Common Lifecycle Patterns

### Awake vs Start

```csharp
public class ManagerA : MonoBehaviour
{
    public static ManagerA Instance;

    void Awake()
    {
        // Awake: set up self-references and singletons
        // Other objects can safely reference this in their Start()
        Instance = this;
    }
}

public class UserOfA : MonoBehaviour
{
    void Start()
    {
        // Start: safe to reference other objects
        // All Awake() calls have completed by now
        ManagerA.Instance.DoSomething();
    }
}
```

### FixedUpdate vs Update

```csharp
public class MovementExample : MonoBehaviour
{
    private Rigidbody rb;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    void FixedUpdate()
    {
        // Physics-based movement: use FixedUpdate
        // Time.fixedDeltaTime is the interval
        rb.MovePosition(rb.position + Vector3.forward * Time.fixedDeltaTime);
    }

    void Update()
    {
        // Non-physics movement: use Update with Time.deltaTime
        // Handles variable frame rates
        transform.Rotate(Vector3.up, 90f * Time.deltaTime);
    }
}
```

### Enable/Disable Event Subscription

```csharp
public class EventSubscriber : MonoBehaviour
{
    void OnEnable()
    {
        // Always subscribe in OnEnable
        SomeEvent.OnTriggered += HandleEvent;
    }

    void OnDisable()
    {
        // Always unsubscribe in OnDisable (mirrors OnEnable)
        // Prevents memory leaks and ghost callbacks
        SomeEvent.OnTriggered -= HandleEvent;
    }

    private void HandleEvent() { }
}
```

---

## Execution Order Configuration

When you need deterministic order between different script types, configure it via:
**Edit > Project Settings > Script Execution Order**

Lower numbers execute first. Default is 0. Example:
- `GameManager`: -100 (initializes first)
- `PlayerController`: 0 (default)
- `CameraFollow`: 100 (runs after player moves)

---

## Key Gotchas

1. **Awake is called even on disabled components** -- but the GameObject must be active. Start is only called on enabled components.

2. **Order between objects is not guaranteed** -- Two MonoBehaviours with `Update()` on different GameObjects may run in any order unless Script Execution Order is configured.

3. **OnDestroy may not be called** -- If the object was never active, OnDestroy is not invoked. Also not called if the application is force-quit.

4. **Coroutines stop on disable** -- When `OnDisable()` fires, all running coroutines on that object are stopped. They do not automatically resume on `OnEnable()`.

5. **FixedUpdate frequency** -- It may run 0, 1, or multiple times per frame depending on the fixed timestep vs actual frame time.

---

## Source Documentation

- [Execution Order](https://docs.unity3d.com/6000.3/Documentation/Manual/execution-order.html)
- [Components](https://docs.unity3d.com/6000.3/Documentation/Manual/Components.html)
