---
name: unity-lifecycle
description: >
  Unity lifecycle and execution order correctness patterns. Catches common mistakes with
  initialization ordering, destruction timing, fake-null, disabled components, editor vs runtime
  init, DontDestroyOnLoad, and async destruction. PATTERN format: WHEN/WRONG/RIGHT/GOTCHA.
  Based on Unity 6.3 LTS documentation.
globs:
  - "**/*.cs"
---

# Unity Lifecycle & Execution Order -- Correctness Patterns

> **Prerequisite skills:** `unity-scripting` (MonoBehaviour lifecycle, coroutines), `unity-foundations` (GameObjects, components)

These patterns target initialization bugs, null reference exceptions from destruction timing, and subtle editor-vs-runtime differences that cause "works in editor, fails in build" issues.

---

## PATTERN: Fake-Null Trap (?.  and ?? on Destroyed Objects)

WHEN: Null-checking Unity objects that may have been destroyed

WRONG (Claude default):
```csharp
// C# null-conditional and null-coalescing bypass Unity's == override
myComponent?.DoSomething();          // May call method on destroyed object!
var fallback = myComponent ?? other; // May return a destroyed "fake-null" object!
```

RIGHT:
```csharp
// Unity overrides == to return true for destroyed objects
// Always use == null or implicit bool conversion
if (myComponent != null)
    myComponent.DoSomething();

// Or use the implicit bool operator (equivalent to != null for UnityEngine.Object)
if (myComponent)
    myComponent.DoSomething();
```

GOTCHA: When Unity destroys an object, the C# reference still exists but Unity marks it as "fake-null". The `==` operator is overridden to handle this, but `?.`, `??`, `is null`, and `is not null` use the C# native null check and see a valid (non-null) reference. This is the #1 source of `MissingReferenceException`. Pattern matching (`obj is MyType t`) also bypasses the override -- use `if (obj != null && obj is MyType t)`.

---

## PATTERN: Destroy is Deferred

WHEN: Destroying objects and accessing them in the same frame

WRONG (Claude default):
```csharp
// Expecting immediate removal
Destroy(enemy);
enemies.Remove(enemy); // enemy still exists this frame
Debug.Log(enemies.Count); // Count is correct, but enemy is "alive" until end of frame

// Iterating and destroying
foreach (var e in enemies)
    if (e.health <= 0)
        Destroy(e.gameObject); // Modifying collection during iteration = crash
```

RIGHT:
```csharp
// Destroy happens at END of current frame (after all Updates complete)
Destroy(enemy);
// enemy is still accessible this frame, but == null returns true

// Safe iteration: collect then destroy
var toDestroy = enemies.Where(e => e.health <= 0).ToList();
foreach (var e in toDestroy)
{
    enemies.Remove(e);
    Destroy(e.gameObject);
}

// If you truly need immediate destruction (EDITOR ONLY):
// DestroyImmediate(obj); // Never use in runtime code
```

GOTCHA: `Destroy` schedules destruction for end of frame. The object's `== null` check returns `true` immediately after `Destroy()`, but `OnDisable` and `OnDestroy` run later. `DestroyImmediate` is synchronous but only safe in editor scripts -- using it at runtime causes hard-to-debug ordering issues. `Destroy(obj, delay)` waits `delay` seconds before scheduling destruction.

---

## PATTERN: Disabled Component Still Gets Awake

WHEN: A component starts with its checkbox unchecked in the Inspector

WRONG (Claude default):
```csharp
// Assuming Awake is skipped for disabled components
// "My Awake runs even though the component is disabled -- bug?"
```

RIGHT:
```csharp
// Awake ALWAYS runs if the GAMEOBJECT is active (regardless of component enabled state)
// Start is SKIPPED if the component is disabled at Start time
// Start runs later when the component is first enabled

void Awake()
{
    // This runs even if this component is disabled
    // Use for self-initialization (cache references, set defaults)
    _rb = GetComponent<Rigidbody>();
}

void Start()
{
    // This is DEFERRED until the component is first enabled
    // Use for cross-references that depend on other objects being initialized
    _target = FindObjectOfType<Player>();
}

void OnEnable()
{
    // Runs every time the component is enabled (including the first time)
    // Runs AFTER Awake but BEFORE Start on first enable
    SubscribeToEvents();
}
```

GOTCHA: The key distinction: Awake depends on **GameObject** active state. Start and OnEnable depend on **component** enabled state. If the **GameObject** starts inactive (`SetActive(false)`), neither Awake nor Start runs until the GameObject is activated. Once the GameObject activates: Awake fires immediately, OnEnable fires if component is enabled, Start fires on the next frame if component is enabled.

---

## PATTERN: OnEnable/OnDisable for Event Subscription

WHEN: Subscribing to events, delegates, or Unity callbacks

WRONG (Claude default):
```csharp
void Start()
{
    EventManager.OnPlayerDied += HandlePlayerDied;
}

void OnDestroy()
{
    EventManager.OnPlayerDied -= HandlePlayerDied;
}
// BUG: If object is disabled/re-enabled, events accumulate
// BUG: If scene reloads, Start doesn't re-run for DontDestroyOnLoad objects
```

RIGHT:
```csharp
void OnEnable()
{
    EventManager.OnPlayerDied += HandlePlayerDied;
    SceneManager.sceneLoaded += OnSceneLoaded;
}

void OnDisable()
{
    EventManager.OnPlayerDied -= HandlePlayerDied;
    SceneManager.sceneLoaded -= OnSceneLoaded;
}
// Correctly handles: disable/enable cycles, scene reloads, destruction
```

GOTCHA: `OnEnable`/`OnDisable` are the symmetric pair. They fire on: component enable/disable, GameObject activate/deactivate, scene load/unload, AND before `OnDestroy`. Using `Start`/`OnDestroy` fails when objects are pooled (disabled/enabled without destruction) or when `DontDestroyOnLoad` objects persist across scene reloads.

---

## PATTERN: OnValidate is Editor-Only

WHEN: Using `OnValidate` to initialize or validate component state

WRONG (Claude default):
```csharp
// Relying on OnValidate for runtime initialization
void OnValidate()
{
    _maxHealth = Mathf.Max(1, _maxHealth);
    _currentHealth = _maxHealth; // This never runs in builds!
}
```

RIGHT:
```csharp
// OnValidate: Editor-only, for Inspector feedback and clamping serialized fields
#if UNITY_EDITOR
void OnValidate()
{
    _maxHealth = Mathf.Max(1, _maxHealth);
}
#endif

// Runtime initialization belongs in Awake or Reset
void Awake()
{
    _currentHealth = _maxHealth;
}

// Reset: Editor-only, called when component is first added or Reset from context menu
void Reset()
{
    _maxHealth = 100;
}
```

GOTCHA: `OnValidate` is stripped from builds entirely. It runs in the Editor when: a serialized field changes in Inspector, a prefab is modified, or the script recompiles. It does NOT run at play mode start. Calling `GetComponent` in `OnValidate` is risky -- the component may not be fully initialized. Wrap side-effect-free validation in `#if UNITY_EDITOR`.

---

## PATTERN: [ExecuteAlways] Update Timing

WHEN: Using `[ExecuteAlways]` or `[ExecuteInEditMode]` for edit-mode behavior

WRONG (Claude default):
```csharp
[ExecuteAlways]
public class LookAtTarget : MonoBehaviour
{
    [SerializeField] Transform target;

    void Update()
    {
        // Expecting this to run every frame in edit mode
        transform.LookAt(target);
    }
}
```

RIGHT:
```csharp
[ExecuteAlways]
public class LookAtTarget : MonoBehaviour
{
    [SerializeField] Transform target;

    void Update()
    {
        // In Edit mode: Update only runs when the Scene view repaints
        // (camera moves, something changes, inspector edited)
        // NOT every frame like Play mode

        if (!target) return; // Safety: references may not exist in edit mode

        #if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            // Edit-mode-specific logic
            transform.LookAt(target);
            return;
        }
        #endif

        // Play-mode logic (runs every frame as normal)
        transform.LookAt(target);
    }
}
```

GOTCHA: In Edit mode, `Update` only runs when the Scene view redraws (not per frame). `Time.deltaTime` is unreliable in Edit mode. `Application.isPlaying` distinguishes editor from play. `[ExecuteAlways]` (Unity 2018.3+) is preferred over `[ExecuteInEditMode]` -- the older attribute has issues with prefab editing in isolation. Components with `[ExecuteAlways]` must handle null references gracefully since the scene may be partially loaded in edit mode.

---

## PATTERN: [RuntimeInitializeOnLoadMethod] Timing

WHEN: Using static initialization that must run before or after scene load

WRONG (Claude default):
```csharp
// Assuming it runs before all Awake calls
[RuntimeInitializeOnLoadMethod]
static void Initialize()
{
    // Default timing is AfterSceneLoad -- Awake has ALREADY run!
    Debug.Log("This runs AFTER Awake, not before");
}
```

RIGHT:
```csharp
// Explicit timing control
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
static void ResetStaticState()
{
    // Earliest: runs before domain reload completes
    // Use for clearing static fields (critical for Enter Play Mode options)
    _instances.Clear();
}

[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
static void InitBeforeScene()
{
    // Runs before any Awake in the first scene
    // Use for system bootstrap (creating manager objects)
}

[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
static void InitAfterScene()
{
    // Runs after all Awake/OnEnable/Start in the first scene
    // Default if no parameter specified
}
```

GOTCHA: The full order is: `SubsystemRegistration` -> `AfterAssembliesLoaded` -> `BeforeSplashScreen` -> `BeforeSceneLoad` -> (scene loads, Awake/OnEnable fire) -> `AfterSceneLoad`. `SubsystemRegistration` is critical for clearing static state when using "Enter Play Mode Options" with domain reload disabled.

---

## PATTERN: Script Execution Order

WHEN: One script's initialization depends on another's

WRONG (Claude default):
```csharp
// Assuming scripts execute in a predictable order
public class GameManager : MonoBehaviour
{
    void Awake() { Instance = this; }
}

public class Player : MonoBehaviour
{
    void Awake()
    {
        GameManager.Instance.Register(this); // May be null if Player.Awake runs first!
    }
}
```

RIGHT:
```csharp
// Option 1: [DefaultExecutionOrder] attribute
[DefaultExecutionOrder(-100)] // Negative = runs earlier
public class GameManager : MonoBehaviour
{
    public static GameManager Instance;
    void Awake() { Instance = this; }
}

[DefaultExecutionOrder(0)] // Default
public class Player : MonoBehaviour
{
    void Start() // Use Start for cross-references, not Awake
    {
        GameManager.Instance.Register(this);
    }
}

// Option 2: Awake for self-init, Start for cross-references
// This is the intended pattern -- Awake before Start is guaranteed
```

GOTCHA: Without explicit ordering, the execution order of the same callback across different scripts is **non-deterministic** (may vary between builds, platforms, and domain reloads). The Awake-before-Start guarantee exists across ALL scripts, making the Awake=self-init / Start=cross-ref pattern reliable. `[DefaultExecutionOrder]` is per-class; Project Settings > Script Execution Order is per-class in the Editor.

---

## PATTERN: OnApplicationQuit vs OnDestroy

WHEN: Saving data or cleaning up when the application exits

WRONG (Claude default):
```csharp
void OnDestroy()
{
    SavePlayerData(); // May fail: other objects might already be destroyed
    // Order of OnDestroy across objects is NOT guaranteed
}
```

RIGHT:
```csharp
void OnApplicationQuit()
{
    // Fires BEFORE OnDisable/OnDestroy on all objects
    // All objects still exist and are accessible
    SavePlayerData();
}

void OnDisable()
{
    UnsubscribeFromEvents(); // Still safe during quit sequence
}

void OnDestroy()
{
    // Cleanup own resources only (don't access other objects)
    // No guarantee other objects still exist
    _nativeArray.Dispose();
}
```

GOTCHA: Quit sequence: `OnApplicationQuit` (all objects) -> `OnDisable` (per object) -> `OnDestroy` (per object). In the Editor, stopping play mode triggers the same sequence. On mobile, `OnApplicationQuit` may not fire (app backgrounding) -- use `OnApplicationPause(true)` for mobile save triggers. `OnApplicationQuit` can be cancelled by setting `Application.wantsToQuit = false`.

---

## PATTERN: Async Methods + Object Destruction

WHEN: Using `async` methods in MonoBehaviours

WRONG (Claude default):
```csharp
async void Start()
{
    await Awaitable.WaitForSecondsAsync(5f);
    // Object may be destroyed by now!
    transform.position = Vector3.zero; // MissingReferenceException
}
```

RIGHT:
```csharp
async Awaitable Start()
{
    try
    {
        await Awaitable.WaitForSecondsAsync(5f, destroyCancellationToken);
        transform.position = Vector3.zero; // Safe: would have thrown if destroyed
    }
    catch (OperationCanceledException)
    {
        // Object was destroyed during the wait -- expected, not an error
    }
}

// For methods called from elsewhere:
public async Awaitable DoAsyncWork()
{
    var token = destroyCancellationToken;
    await Awaitable.NextFrameAsync(token);

    // After each await, the token ensures we don't continue on a destroyed object
    token.ThrowIfCancellationRequested();
    _data.Process();
}
```

GOTCHA: `destroyCancellationToken` is raised when `OnDestroy` begins. Always pass it to `Awaitable` methods. `async void` methods cannot propagate exceptions -- the app crashes. Use `async Awaitable` (or `async Awaitable<T>`) instead, which integrates with Unity's frame loop. See `unity-async-patterns` skill for deeper async correctness.

---

## Lifecycle Timing Quick Reference

| Callback | Fires When | Frequency | Scope |
|----------|-----------|-----------|-------|
| `Awake` | Script instance loads (if GO active) | Once | Self-init |
| `OnEnable` | Component/GO enabled | Every enable | Subscribe events |
| `Start` | Before first Update (if enabled) | Once | Cross-references |
| `FixedUpdate` | Fixed timestep | 0-N per frame | Physics |
| `Update` | Every frame | Once per frame | Game logic |
| `LateUpdate` | After all Updates | Once per frame | Camera, follow |
| `OnDisable` | Component/GO disabled | Every disable | Unsubscribe events |
| `OnDestroy` | Object destroyed | Once | Cleanup own resources |
| `OnApplicationQuit` | App exiting | Once | Save data |
| `OnValidate` | Inspector change (EDITOR ONLY) | Many | Clamp fields |
| `Reset` | Component added/reset (EDITOR ONLY) | Manual | Default values |

## Related Skills

- **unity-scripting** -- MonoBehaviour lifecycle diagram, coroutine lifecycle, Awaitable API
- **unity-foundations** -- GameObject activation, component enable/disable API
- **unity-async-patterns** -- Deep async/await correctness patterns

## Additional Resources

- [Execution Order](https://docs.unity3d.com/6000.3/Documentation/Manual/ExecutionOrder.html)
- [MonoBehaviour API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/MonoBehaviour.html)
- [RuntimeInitializeOnLoadMethodAttribute](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/RuntimeInitializeOnLoadMethodAttribute.html)
- [DefaultExecutionOrder](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/DefaultExecutionOrder.html)
- [Application.wantsToQuit](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Application-wantsToQuit.html)
