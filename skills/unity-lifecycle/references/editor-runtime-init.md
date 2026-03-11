# Editor vs Runtime Initialization Reference

Detailed reference for initialization timing, editor-specific callbacks, and the quit sequence. Supplements the PATTERN blocks in the parent SKILL.md.

## RuntimeInitializeOnLoadMethod Complete Timing

```
DOMAIN RELOAD (if enabled)
  |
  v
[SubsystemRegistration] -----> Clear static fields, reset state
  |                             Critical for "Enter Play Mode Options"
  v
[AfterAssembliesLoaded] -----> After all assemblies loaded
  |                             Register custom systems
  v
[BeforeSplashScreen] ---------> Before splash screen shows
  |                             Initialize analytics, crash reporting
  v
[BeforeSceneLoad] ------------> Before first scene loads
  |                             Bootstrap managers, create DontDestroyOnLoad objects
  |
  v
=== FIRST SCENE LOADS ===
  | Awake (all active GOs)
  | OnEnable (all enabled components)
  | Start (all enabled components)
  v
[AfterSceneLoad] ------------> After first scene fully loaded (DEFAULT)
                                Post-initialization, start gameplay
```

### Usage Examples

```csharp
// Critical: Clear static state for Enter Play Mode Options (domain reload disabled)
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
static void ClearStaticState()
{
    // Without this, statics from previous play session persist
    _instance = null;
    _registeredHandlers.Clear();
    _isInitialized = false;
}

// Bootstrap: Create persistent manager before any scene
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
static void CreateManager()
{
    var go = new GameObject("GameManager");
    go.AddComponent<GameManager>();
    Object.DontDestroyOnLoad(go);
}

// Post-init: Start gameplay after everything is ready
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
static void StartGame()
{
    GameManager.Instance.BeginGameplay();
}
```

### Enter Play Mode Options

When **domain reload** is disabled (Project Settings > Editor > Enter Play Mode Settings):
- Static fields are NOT reset between play sessions
- `[RuntimeInitializeOnLoadMethod(SubsystemRegistration)]` is the ONLY place to reset them
- Without reset, statics keep values from the previous play session

```csharp
// Pattern for domain-reload-safe singletons
public class AudioManager : MonoBehaviour
{
    private static AudioManager _instance;
    public static AudioManager Instance => _instance;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() => _instance = null;

    void Awake()
    {
        if (_instance != null)
        {
            Destroy(gameObject);
            return;
        }
        _instance = this;
        DontDestroyOnLoad(gameObject);
    }
}
```

---

## ExecuteAlways vs ExecuteInEditMode

| Feature | `[ExecuteAlways]` | `[ExecuteInEditMode]` |
|---------|-------------------|----------------------|
| **Unity version** | 2018.3+ (recommended) | Legacy |
| **Prefab isolation** | Works correctly | Issues with prefab mode |
| **Edit mode Update** | Runs on scene repaint | Runs on scene repaint |
| **Play mode** | Normal execution | Normal execution |
| **Build stripping** | Both stripped from builds (callbacks just run normally) |

### Edit Mode Behavior Differences

```csharp
[ExecuteAlways]
public class EditModeAware : MonoBehaviour
{
    void Update()
    {
        // EDIT MODE:
        // - Update runs only when Scene view repaints (camera moves, selection changes,
        //   Inspector edit, manual Repaint call)
        // - Time.deltaTime is unreliable (time since last repaint, not frame time)
        // - Time.realtimeSinceStartup is reliable
        // - Input is not available
        // - Coroutines DO run but yield timing is unreliable

        // PLAY MODE:
        // - Normal per-frame execution
        // - All APIs work normally

        #if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            // Force continuous repaints if needed (use sparingly -- drains battery)
            UnityEditor.EditorApplication.QueuePlayerLoopUpdate();
            return;
        }
        #endif
    }

    void OnEnable()
    {
        // Runs in BOTH edit and play mode
        // In edit mode: runs when component is enabled in Inspector,
        //   scene opens, or script recompiles

        #if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            // Edit-mode-only subscription
            UnityEditor.SceneView.duringSceneGui += OnSceneGUI;
        }
        #endif
    }

    void OnDisable()
    {
        #if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            UnityEditor.SceneView.duringSceneGui -= OnSceneGUI;
        }
        #endif
    }

    #if UNITY_EDITOR
    void OnSceneGUI(UnityEditor.SceneView sceneView)
    {
        // Custom scene view rendering
    }
    #endif
}
```

---

## OnValidate Safe Patterns

### What's Safe in OnValidate

```csharp
#if UNITY_EDITOR
void OnValidate()
{
    // SAFE: Clamping serialized fields
    _health = Mathf.Clamp(_health, 0, _maxHealth);
    _speed = Mathf.Max(0f, _speed);

    // SAFE: Setting dependent serialized fields
    if (_radius < 0.1f) _radius = 0.1f;

    // SAFE: Validating references (but don't fix them automatically)
    if (_targetPrefab != null && _targetPrefab.GetComponent<Rigidbody>() == null)
        Debug.LogWarning("Target prefab is missing Rigidbody", this);
}
#endif
```

### What's Dangerous in OnValidate

```csharp
#if UNITY_EDITOR
void OnValidate()
{
    // DANGEROUS: GetComponent may return null during deserialization
    // var rb = GetComponent<Rigidbody>(); // May fail

    // DANGEROUS: Accessing other objects
    // FindObjectOfType<GameManager>(); // Scene may not be loaded

    // DANGEROUS: Creating/destroying objects
    // Instantiate(prefab); // Causes editor errors

    // DANGEROUS: Modifying non-serialized state
    // _runtimeCache = new Dictionary<...>(); // Lost on next recompile

    // SAFE WORKAROUND: Defer to next editor frame
    UnityEditor.EditorApplication.delayCall += () =>
    {
        if (this == null) return; // Object may have been destroyed
        // Now safe to call GetComponent, modify scene objects, etc.
        var rb = GetComponent<Rigidbody>();
        if (rb != null) rb.mass = _mass;
    };
}
#endif
```

---

## Application Quit Sequence

```
APPLICATION QUIT INITIATED (user closes, Application.Quit(), or stop play mode)
  |
  v
[Application.wantsToQuit] -----> Can CANCEL quit by returning false
  |                               (e.g., "Are you sure?" dialog)
  v
[Application.quitting] --------> Event fires (point of no return)
  |
  v
[OnApplicationQuit] -----------> All MonoBehaviours, in no particular order
  |                               All objects still alive and accessible
  v
=== PER-OBJECT TEARDOWN (order not guaranteed between objects) ===
  |
  [OnDisable] -----> Component disabled
  |
  [OnDestroy] -----> Component destroyed
  |
  v
=== PROCESS EXIT ===
```

### Mobile Considerations

```csharp
// Mobile: OnApplicationQuit may NOT fire (app can be killed by OS)
// Use OnApplicationPause for reliable save points

void OnApplicationPause(bool pauseStatus)
{
    if (pauseStatus)
    {
        // App going to background -- save immediately
        // This is the LAST reliable callback on mobile
        SaveGameState();
    }
}

void OnApplicationFocus(bool hasFocus)
{
    if (!hasFocus)
    {
        // App lost focus (may still be visible on split-screen)
        // Less critical than pause, but good for auto-save
    }
}

void OnApplicationQuit()
{
    // Desktop: reliable
    // Mobile: may never fire
    // WebGL: may not fire (tab close)
    SaveGameState();
}
```

---

## Destruction Order Guarantees

| Guarantee | Details |
|-----------|---------|
| `OnDisable` before `OnDestroy` | Per-object, always |
| `OnApplicationQuit` before all `OnDisable`/`OnDestroy` | Always |
| Parent destroyed before children | **NOT guaranteed** -- children may destroy first |
| Same-frame destruction order | **NOT guaranteed** between objects |
| `Destroy` deferred to end of frame | Always (except `DestroyImmediate`) |
| `== null` immediately after `Destroy()` | Returns `true` |
| `OnDestroy` runs after `Destroy()` | End of frame, not immediate |
| Destroyed objects accessible same frame | Yes, but `== null` is true |

### Safe Destruction Pattern

```csharp
// Mark for destruction and remove from any tracking lists immediately
public void Kill()
{
    if (_isDead) return; // Prevent double-kill
    _isDead = true;

    // Remove from lists NOW (before end of frame)
    EnemyManager.Instance.Unregister(this);

    // Schedule actual destruction
    Destroy(gameObject);
}

// In OnDestroy, only clean up own resources
void OnDestroy()
{
    _nativeArray.Dispose();
    // Do NOT access other managers or objects here
}
```
