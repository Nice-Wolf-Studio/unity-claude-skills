---
name: unity-scripting
description: >
  Unity 6 C# scripting guide. Use when writing MonoBehaviour scripts, handling lifecycle events (Awake, Start, Update, FixedUpdate), using coroutines or async/await (Awaitable), working with ScriptableObjects, events, delegates, or core APIs like Vector3, Quaternion, Time, Debug. Based on Unity 6.3 LTS documentation.
globs:
  - "**/*.cs"
---

# Unity C# Scripting

## Script Fundamentals

C# scripts (`.cs` files) are stored in the `Assets` folder. Scripts gain Unity functionality by inheriting from built-in types:

- **UnityEngine.Object** -- Makes custom types assignable to Inspector fields
- **MonoBehaviour** -- Attaches to GameObjects as components to control behavior in a scene
- **ScriptableObject** -- Standalone data assets not attached to GameObjects

Scripts operate in two contexts:
- **Runtime scripts** -- Execute in the Player build (use `UnityEngine` namespace)
- **Editor scripts** -- Run only in the Editor (use `UnityEditor` namespace, place in `Editor` folders)

## MonoBehaviour Lifecycle

MonoBehaviours always exist as a Component of a GameObject. The lifecycle event functions execute in a strict order. You cannot rely on the order in which the same event function is invoked for different GameObjects unless configured via Script Execution Order settings.
### Execution Order (ASCII Diagram)

```
INITIALIZATION
  |
  v
[Awake] ---------> Called when script instance loads (once per lifetime)
  |
  v
[OnEnable] ------> Called when object/component becomes enabled
  |
  v
(SceneManager.sceneLoaded fires here -- after OnEnable, before Start)
  |
  v
[Start] ---------> Called before first frame Update (once per lifetime)
  |
  |
  |  +===========================================+
  |  |          PHYSICS LOOP (fixed timestep)    |
  |  |                                           |
  +->| [FixedUpdate] --> Internal Physics ------>|
  |  |       |                                   |
  |  | [yield WaitForFixedUpdate resumes]        |
  |  +===========================================+
  |
  v
[Update] --------> Called once per frame
  |
  v
[yield null / yield WaitForSeconds resumes]
  |
  v
(Internal Animation Update)
  |   [OnAnimatorMove]
  |   [OnAnimatorIK]
  |
  v
[LateUpdate] ----> Called after all Update functions complete
  |
  v
RENDERING
  | [OnWillRenderObject]
  | [OnPreCull] [OnBecameVisible/Invisible]
  | [OnPreRender]
  | [OnRenderObject]
  | [OnPostRender]
  | [OnRenderImage]
  |
  v
[OnGUI] ---------> Called for GUI rendering events
  |
  v
[yield WaitForEndOfFrame resumes]
  |
  v
DEACTIVATION / TEARDOWN
  |
  v
[OnDisable] -----> Called when component/object is disabled
  |
  v
[OnDestroy] -----> Called before object destruction
```

### Key Lifecycle Callbacks

| Callback | Timing | Use For |
|----------|--------|---------|
| `Awake()` | Script instance loads | One-time init, cache references |
| `OnEnable()` | Component enabled | Subscribe to events |
| `Start()` | Before first Update | Init that depends on other Awake() calls |
| `FixedUpdate()` | Fixed timestep (default 0.02s) | Physics calculations, Rigidbody forces |
| `Update()` | Every frame | Input, non-physics game logic |
| `LateUpdate()` | After all Update calls | Camera follow, post-Update adjustments |
| `OnDisable()` | Component disabled | Unsubscribe from events |
| `OnDestroy()` | Before destruction | Final cleanup |

### Physics Callbacks
```csharp
// 3D Physics
void OnCollisionEnter(Collision collision) { }
void OnCollisionStay(Collision collision) { }
void OnCollisionExit(Collision collision) { }
void OnTriggerEnter(Collider other) { }
void OnTriggerStay(Collider other) { }
void OnTriggerExit(Collider other) { }

// 2D Physics
void OnCollisionEnter2D(Collision2D collision) { }
void OnTriggerEnter2D(Collider2D other) { }
```

### MonoBehaviour Properties (Unity 6)
| Property | Purpose |
|----------|---------|
| `destroyCancellationToken` | Token raised when MonoBehaviour is destroyed (for async cancellation) |
| `didAwake` | Whether Awake has been called |
| `didStart` | Whether Start has been called |
| `runInEditMode` | Allow script execution in editor |

> Full lifecycle reference: [references/monobehaviour-lifecycle.md](references/monobehaviour-lifecycle.md)

## Coroutines vs Async/Await

Unity supports two patterns for operations spanning multiple frames.
### Coroutines (IEnumerator)

Methods that suspend with `yield return` and resume based on the yield instruction.

```csharp
IEnumerator Fade()
{
    Color c = renderer.material.color;
    for (float alpha = 1f; alpha >= 0; alpha -= 0.1f)
    {
        c.a = alpha;
        renderer.material.color = c;
        yield return new WaitForSeconds(0.1f);
    }
}

void Update()
{
    if (Input.GetKeyDown("f"))
    {
        StartCoroutine(Fade());
    }
}
```

**Yield Instructions:**
- `yield return null` -- Resume next frame (after Update)
- `yield return new WaitForSeconds(t)` -- Resume after t seconds
- `yield return new WaitForFixedUpdate()` -- Resume after FixedUpdate
- `yield return new WaitForEndOfFrame()` -- Resume after rendering
- `yield return new WaitUntil(() => condition)` -- Resume when condition is true
- `yield return StartCoroutine(other)` -- Wait for nested coroutine

**Important:** Coroutines run on the main thread. Disabling the MonoBehaviour via `enabled = false` does NOT stop coroutines. Deactivating the GameObject or destroying the MonoBehaviour does stop them.

### Awaitable (Unity 6 Async/Await)

`Awaitable` is Unity's custom async type -- usually more efficient than iterator-based coroutines. It is pooled to limit allocations.

```csharp
async Awaitable SampleSchedulingJobsForNextFrame()
{
    await Awaitable.EndOfFrameAsync();
    var jobHandle = ScheduleSomethingWithJobSystem();
    await Awaitable.NextFrameAsync();
    jobHandle.Complete();
}
```

**Awaitable Methods:**
- `Awaitable.NextFrameAsync()` -- Resume next frame
- `Awaitable.FixedUpdateAsync()` -- Resume at next FixedUpdate
- `Awaitable.EndOfFrameAsync()` -- Resume at end of frame
- `Awaitable.WaitForSecondsAsync(float)` -- Resume after delay
- `Awaitable.MainThreadAsync()` -- Force continuation on main thread
- `Awaitable.BackgroundThreadAsync()` -- Force continuation on background thread

**Critical constraint:** Awaitable instances are pooled -- never `await` the same instance more than once. Multiple awaits cause undefined behavior.

| Feature | Coroutine | Awaitable |
|---------|-----------|-----------|
| Return values | No | Yes (`Awaitable<T>`) |
| Thread switching | No | Yes |
| Memory allocation | Per-yield overhead | Pooled, minimal |
| Cancellation | Manual StopCoroutine | CancellationToken support |
| Error handling | No try/catch | Full try/catch/finally |

> Full async reference: [references/coroutines-and-async.md](references/coroutines-and-async.md)

## Events and Communication Patterns

### C# Events and Delegates

```csharp
public class Health : MonoBehaviour
{
    public event System.Action<float> OnDamageTaken;
    public event System.Action OnDeath;

    private float _hp = 100f;

    public void TakeDamage(float amount)
    {
        _hp -= amount;
        OnDamageTaken?.Invoke(amount);
        if (_hp <= 0f)
            OnDeath?.Invoke();
    }
}

public class UIHealthBar : MonoBehaviour
{
    [SerializeField] private Health _health;

    void OnEnable()
    {
        _health.OnDamageTaken += HandleDamage;
    }

    void OnDisable()
    {
        _health.OnDamageTaken -= HandleDamage;
    }

    private void HandleDamage(float amount)
    {
        // Update UI
    }
}
```

### UnityEvents (Inspector-assignable)

```csharp
using UnityEngine.Events;

public class GameManager : MonoBehaviour
{
    public UnityEvent OnGameStart;
    public UnityEvent<int> OnScoreChanged;

    public void StartGame()
    {
        OnGameStart?.Invoke();
    }
}
```

### ScriptableObject Event Channels

```csharp
[CreateAssetMenu(menuName = "Events/Void Event Channel")]
public class VoidEventChannel : ScriptableObject
{
    private System.Action _onEventRaised;

    public void RaiseEvent()
    {
        _onEventRaised?.Invoke();
    }

    public void Subscribe(System.Action listener) => _onEventRaised += listener;
    public void Unsubscribe(System.Action listener) => _onEventRaised -= listener;
}
```

## ScriptableObjects

ScriptableObjects are serializable Unity types derived from `UnityEngine.Object`. They exist as independent project assets, not attached to GameObjects. Use them for shared data, configuration, and event channels.

```csharp
[CreateAssetMenu(fileName = "Data", menuName = "ScriptableObjects/SpawnManagerScriptableObject", order = 1)]
public class SpawnManagerScriptableObject : ScriptableObject
{
    public string prefabName;
    public int numberOfPrefabsToCreate;
    public Vector3[] spawnPoints;
}
```

**Key behaviors:**
- In Edit mode, Inspector modifications save automatically; script changes require `EditorUtility.SetDirty()`
- At runtime, players can read ScriptableObject data but not persist modifications to disk
- Memory efficient: multiple objects reference the same asset instance instead of duplicating data

> Full ScriptableObject reference: [references/scriptableobjects.md](references/scriptableobjects.md)

## Serialization Quick Reference

Unity serializes fields that meet ALL conditions:
1. `public` OR has `[SerializeField]` attribute
2. Not `static`, `const`, or `readonly`
3. Is a serializable type

**Serializable types:** primitives, enums (32-bit or smaller), Unity built-in types (Vector2, Vector3, Rect, Color, AnimationCurve, etc.), `[Serializable]` custom classes/structs, `UnityEngine.Object` references, `List<T>` and arrays of any above type.

**Key attributes:**

```csharp
[SerializeField] private float _speed = 5f;        // Serialize private field
[field: SerializeField] public float Speed { get; private set; } // Auto-property
[NonSerialized] public float tempValue;             // Exclude from serialization
[HideInInspector] public float hiddenValue;         // Serialize but hide from Inspector
[SerializeReference] private IMyInterface _impl;    // Polymorphic serialization
```

**Not supported:** Multidimensional arrays, jagged arrays, dictionaries, nested containers. Use `ISerializationCallbackReceiver` for custom serialization of unsupported types.

## Core API Quick Reference

### Vector3

```csharp
// Static direction shortcuts
Vector3.zero;      // (0, 0, 0)
Vector3.one;       // (1, 1, 1)
Vector3.up;        // (0, 1, 0)
Vector3.forward;   // (0, 0, 1)
Vector3.right;     // (1, 0, 0)

// Common operations
float dist = Vector3.Distance(a, b);
float dot = Vector3.Dot(a.normalized, b.normalized);
Vector3 cross = Vector3.Cross(a, b);
Vector3 smoothed = Vector3.Lerp(from, to, t);
Vector3 moved = Vector3.MoveTowards(current, target, maxDelta);
Vector3 projected = Vector3.ProjectOnPlane(velocity, groundNormal);
```

**Properties:** `magnitude`, `sqrMagnitude` (use for comparisons -- avoids sqrt), `normalized`.

### Quaternion

```csharp
// Creation
Quaternion.identity;                             // No rotation
Quaternion.Euler(0f, 90f, 0f);                  // From Euler angles (degrees)
Quaternion.LookRotation(direction, Vector3.up);  // Face a direction
Quaternion.AngleAxis(45f, Vector3.up);           // Rotate around axis
Quaternion.FromToRotation(Vector3.up, normal);   // Rotation between directions

// Interpolation
Quaternion.Slerp(from, to, t);                  // Spherical interpolation
Quaternion.Lerp(from, to, t);                   // Linear interpolation

// Operations
float angle = Quaternion.Angle(a, b);           // Angle in degrees (0-180)
Vector3 rotatedPoint = rotation * point;         // Rotate a vector
Quaternion combined = rotA * rotB;               // Combine rotations
```

**Never modify x, y, z, w directly.** Use `Euler()`, `AngleAxis()`, or `LookRotation()`.

### Time

```csharp
Time.deltaTime       // Seconds since last frame (use in Update)
Time.fixedDeltaTime  // Fixed timestep interval (use in FixedUpdate)
Time.time            // Time since game start
Time.timeScale       // 0 = paused, 1 = normal, 2 = double speed
Time.unscaledDeltaTime // Ignores timeScale (for UI animations during pause)
```

### Debug

```csharp
Debug.Log("Message");
Debug.LogWarning("Warning");
Debug.LogError("Error");
Debug.DrawRay(origin, direction, Color.red, duration);
Debug.DrawLine(start, end, Color.green, duration);
```

## Common Patterns

### Cached Component References

```csharp
public class PlayerMovement : MonoBehaviour
{
    private Rigidbody _rb;
    private Transform _transform;

    void Awake()
    {
        _rb = GetComponent<Rigidbody>();
        _transform = transform; // Cache the transform property
    }

    void FixedUpdate()
    {
        // Use cached references -- never call GetComponent in Update/FixedUpdate
        _rb.AddForce(Vector3.up * 10f);
    }
}
```

### Singleton Pattern

```csharp
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }
}
```

### Async with Cancellation (Unity 6)

```csharp
public class AsyncExample : MonoBehaviour
{
    async void Start()
    {
        try
        {
            await LoadAndProcessAsync(destroyCancellationToken);
        }
        catch (OperationCanceledException) { }
    }

    async Awaitable LoadAndProcessAsync(CancellationToken token)
    {
        await Awaitable.BackgroundThreadAsync();
        // Heavy computation here (off main thread)
        var result = ComputeExpensiveData();

        await Awaitable.MainThreadAsync();
        // Back on main thread -- safe to use Unity API
        ApplyResult(result);
    }
}
```

### Conditional Wait (Awaitable replacement for WaitUntil)

```csharp
public static async Awaitable AwaitableUntil(Func<bool> condition, CancellationToken token)
{
    while (!condition())
    {
        token.ThrowIfCancellationRequested();
        await Awaitable.NextFrameAsync();
    }
}
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `GetComponent<T>()` in `Update()` | Allocates and searches every frame | Cache in `Awake()` |
| `GameObject.Find()` in `Update()` | Expensive string search every frame | Cache reference or use serialized field |
| Repeated `new Vector3()` in hot paths | Unnecessary constructor overhead each frame | Use `Vector3.zero`, `Vector3.one`, or cache reusable values |
| Modifying `Quaternion.x/y/z/w` directly | Produces invalid rotations | Use `Euler()`, `AngleAxis()`, `LookRotation()` |
| Physics logic in `Update()` | Inconsistent at variable framerates | Use `FixedUpdate()` for Rigidbody forces |
| `Time.deltaTime` in `FixedUpdate()` | Works (Unity returns `fixedDeltaTime` implicitly) but is unclear to readers | Use `Time.fixedDeltaTime` explicitly for clarity |
| Forgetting to unsubscribe events in `OnDisable` | Memory leaks, null reference errors | Always unsubscribe in `OnDisable()` |
| `await`-ing same `Awaitable` twice | Undefined behavior (pooled instances) | Await once, or wrap with `.AsTask()` |
| Empty `Update()` / `FixedUpdate()` methods | Unity still calls them (overhead) | Remove empty event functions |
| String-based `Invoke("MethodName", t)` | No compile-time safety, breaks on rename | Use coroutines or Awaitable instead |

## Related Skills

- **unity-foundations** -- GameObjects, Components, Transforms, Scenes, Prefabs
- **unity-physics** -- Rigidbody, Colliders, Raycasting, Physics materials
- **unity-input** -- Input System, InputActions, PlayerInput component

## Additional Resources

- [Scripting](https://docs.unity3d.com/6000.3/Documentation/Manual/scripting.html) | [Execution Order](https://docs.unity3d.com/6000.3/Documentation/Manual/execution-order.html) | [Coroutines](https://docs.unity3d.com/6000.3/Documentation/Manual/Coroutines.html) | [Async/Await](https://docs.unity3d.com/6000.3/Documentation/Manual/async-await-support.html)
- [ScriptableObjects](https://docs.unity3d.com/6000.3/Documentation/Manual/class-ScriptableObject.html) | [MonoBehaviour](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/MonoBehaviour.html) | [Vector3](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Vector3.html)
- For object pooling (`ObjectPool<T>`), see [references/object-pool.md](references/object-pool.md)
