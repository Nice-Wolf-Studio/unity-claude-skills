---
name: unity-game-architecture
description: >
  Unity game architecture decision patterns. Service Locator vs Singleton vs DI,
  Event Bus vs ScriptableObject channels, MonoBehaviour vs plain C#, component composition,
  manager bootstrap sequences. DECISION format: WHEN/DECISION/SCAFFOLD/GOTCHA.
  Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
---

# Game Systems Architecture -- Decision Patterns

> **Prerequisite skills:** `unity-scripting` (MonoBehaviour, ScriptableObjects, events), `unity-lifecycle` (RuntimeInitializeOnLoadMethod, DontDestroyOnLoad, SubsystemRegistration), `unity-foundations` (components, GameObjects)

These patterns address the most common architectural failure: Claude defaults to fat MonoBehaviours with direct references and singletons everywhere. This works for prototypes but collapses at system scale.

---

## PATTERN: Global Service Access

WHEN: Systems need to find other systems at runtime (AudioManager, InputManager, SaveManager, etc.)

DECISION:
- **Lazy Singleton** -- Tiny project, 1-3 managers, no testing needed. `static Instance` + `DontDestroyOnLoad`. Fast to write, impossible to mock.
- **Service Locator** -- Medium project, want to swap implementations for testing (mock audio, stub save). Central registry with `Register<T>/Get<T>`. Dependencies are implicit but swappable.
- **Constructor/Method DI** -- Large project or library code, maximum testability. Pass dependencies explicitly. Use VContainer or Zenject for MonoBehaviour injection.

SCAFFOLD (Service Locator):
```csharp
public static class Services
{
    private static readonly Dictionary<Type, object> _services = new();

    public static void Register<T>(T service) where T : class
    {
        _services[typeof(T)] = service;
    }

    public static T Get<T>() where T : class
    {
        if (_services.TryGetValue(typeof(T), out var service))
            return (T)service;
        throw new InvalidOperationException($"Service {typeof(T).Name} not registered");
    }

    public static bool TryGet<T>(out T service) where T : class
    {
        if (_services.TryGetValue(typeof(T), out var obj))
        {
            service = (T)obj;
            return true;
        }
        service = null;
        return false;
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() => _services.Clear();
}

// Registration (in a bootstrap MonoBehaviour or RuntimeInitializeOnLoadMethod):
Services.Register<IAudioService>(new AudioService());
Services.Register<ISaveService>(new SaveService());

// Usage (anywhere):
Services.Get<IAudioService>().PlaySFX("explosion");
```

GOTCHA: Service Locator hides dependencies -- you cannot see what a class needs by looking at its constructor. Use it for true infrastructure services only (audio, save, analytics), not for gameplay dependencies. Always back services with interfaces (`IAudioService`, not `AudioManager`) so tests can register mocks. The `SubsystemRegistration` reset is critical for Enter Play Mode Options with domain reload disabled.

---

## PATTERN: MonoBehaviour vs Plain C# Class

WHEN: Deciding whether a new class should inherit from MonoBehaviour

DECISION:
- **MonoBehaviour** -- Needs any of: Inspector serialization via `[SerializeField]`, Unity callbacks (Update, OnTriggerEnter), Transform/GameObject access, coroutines/Awaitable with `destroyCancellationToken`, or being a component on a GameObject.
- **Plain C# class** -- Pure logic: state machines, pathfinding algorithms, data processing, inventory logic, damage calculation, save/load DTOs. Owned and driven by a MonoBehaviour.

SCAFFOLD (Plain C# class owned by MonoBehaviour):
```csharp
// Pure logic class -- testable without Unity
public class HealthSystem
{
    public int Current { get; private set; }
    public int Max { get; }
    public bool IsDead => Current <= 0;
    public event Action OnDied;
    public event Action<int, int> OnChanged; // current, max

    public HealthSystem(int maxHealth)
    {
        Max = maxHealth;
        Current = maxHealth;
    }

    public void TakeDamage(int amount)
    {
        if (IsDead) return;
        Current = Mathf.Max(0, Current - amount);
        OnChanged?.Invoke(Current, Max);
        if (IsDead) OnDied?.Invoke();
    }

    public void Heal(int amount)
    {
        if (IsDead) return;
        Current = Mathf.Min(Max, Current + amount);
        OnChanged?.Invoke(Current, Max);
    }
}

// Thin MonoBehaviour wrapper -- bridges Unity and logic
public class HealthComponent : MonoBehaviour
{
    [SerializeField] private int maxHealth = 100;

    public HealthSystem Health { get; private set; }

    void Awake()
    {
        Health = new HealthSystem(maxHealth);
    }

    // Optional: expose events for Unity-side wiring
    void OnEnable() => Health.OnDied += HandleDeath;
    void OnDisable() => Health.OnDied -= HandleDeath;

    void HandleDeath()
    {
        // Unity-specific: play VFX, disable collider, etc.
        Destroy(gameObject, 2f);
    }
}
```

GOTCHA: Plain C# classes cannot use `[SerializeField]`. Use `[System.Serializable]` for nested display in the Inspector. They have no `destroyCancellationToken` -- pass one from the owning MonoBehaviour if they do async work. Use `Mathf` (not `System.Math`) for Unity-compatible math in plain C# classes that reference UnityEngine.

---

## PATTERN: Component Composition vs Inheritance

WHEN: Multiple GameObjects share some behavior but differ in specifics (enemies with different attacks, interactable objects)

DECISION:
- **Composition with interfaces** (default) -- Separate capabilities into focused components (`Health`, `Mover`, `DamageDealer`). Consumers query via `GetComponent<IDamageable>()`. Maximum flexibility, easy to mix-and-match.
- **Abstract base class** -- Only when there is genuine IS-A relationship with shared STATE and shared IMPLEMENTATION (not just shared interface). Example: `Projectile` base with `BulletProjectile` and `RocketProjectile` that share velocity/lifetime logic.

SCAFFOLD (Interface + Composition):
```csharp
// Capability interface
public interface IDamageable
{
    void TakeDamage(float amount, Vector3 hitPoint, Vector3 hitNormal);
    bool IsAlive { get; }
}

// Focused component implementing the interface
[RequireComponent(typeof(Collider))]
public class DamageReceiver : MonoBehaviour, IDamageable
{
    [SerializeField] private float maxHealth = 100f;
    private float _currentHealth;

    public bool IsAlive => _currentHealth > 0;
    public event Action<float> OnDamaged;

    void Awake() => _currentHealth = maxHealth;

    public void TakeDamage(float amount, Vector3 hitPoint, Vector3 hitNormal)
    {
        if (!IsAlive) return;
        _currentHealth -= amount;
        OnDamaged?.Invoke(amount);
    }
}

// Consumer queries the interface, not the concrete type
void OnTriggerEnter(Collider other)
{
    if (other.TryGetComponent(out IDamageable target) && target.IsAlive)
    {
        target.TakeDamage(damage, transform.position, transform.forward);
    }
}
```

GOTCHA: `GetComponent<IInterface>()` works in Unity -- interfaces are queryable. `RequireComponent` enforces component dependencies at add-time. Prefer `TryGetComponent` over null-checking `GetComponent` (avoids allocation of a null wrapper in older Unity versions). Deep MonoBehaviour inheritance hierarchies (3+ levels) are the #1 Unity architecture anti-pattern.

---

## PATTERN: Event Architecture Selection

WHEN: Two or more systems need to communicate without direct references

DECISION:
- **C# events/Actions** -- Communication within a single class or tightly-coupled components on the same GameObject. Simplest, strongly typed, zero overhead.
- **ScriptableObject Event Channels** -- Cross-scene communication, designer-configurable, drag-and-drop wiring in Inspector. Best for gameplay events (player died, level complete). See `unity-scripting/references/scriptableobjects.md` for full implementation.
- **Static Event Bus** -- Project-wide typed events, code-only (no assets to manage). Fast to prototype, good for system-level events (scene loaded, settings changed). Harder to debug than SO channels.

SCAFFOLD (Static Typed Event Bus):
```csharp
// Event definitions
public struct PlayerDiedEvent { public Vector3 Position; public string CauseOfDeath; }
public struct ScoreChangedEvent { public int NewScore; public int Delta; }

// Bus implementation
public static class EventBus
{
    private static readonly Dictionary<Type, Delegate> _handlers = new();

    public static void Subscribe<T>(Action<T> handler) where T : struct
    {
        var type = typeof(T);
        if (_handlers.TryGetValue(type, out var existing))
            _handlers[type] = Delegate.Combine(existing, handler);
        else
            _handlers[type] = handler;
    }

    public static void Unsubscribe<T>(Action<T> handler) where T : struct
    {
        var type = typeof(T);
        if (_handlers.TryGetValue(type, out var existing))
        {
            var result = Delegate.Remove(existing, handler);
            if (result == null) _handlers.Remove(type);
            else _handlers[type] = result;
        }
    }

    public static void Publish<T>(T evt) where T : struct
    {
        if (_handlers.TryGetValue(typeof(T), out var handler))
            ((Action<T>)handler)?.Invoke(evt);
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() => _handlers.Clear();
}

// Usage
EventBus.Subscribe<PlayerDiedEvent>(OnPlayerDied);
EventBus.Publish(new PlayerDiedEvent { Position = pos, CauseOfDeath = "lava" });
```

GOTCHA: Always unsubscribe in `OnDisable` (not `OnDestroy`) to match the `OnEnable` subscription. Static Event Bus survives scene loads -- if a handler's object is destroyed without unsubscribing, you get `MissingReferenceException`. Use `struct` events to avoid allocation. SO Event Channels are preferred when designers need to wire events visually.

---

## PATTERN: Manager Bootstrap Sequence

WHEN: Multiple manager systems depend on each other at startup

DECISION:
- **Boot Scene** -- A dedicated "Boot" scene loads first, creates all managers, then loads the gameplay scene additively. Visual, async-friendly, supports loading screens. Best for production projects.
- **RuntimeInitializeOnLoadMethod** -- Code-only bootstrap, no scene dependency. Creates managers via `BeforeSceneLoad`. Best for plugins, packages, or projects where any scene can be the entry point.

SCAFFOLD (Boot Scene):
```csharp
public class Bootstrapper : MonoBehaviour
{
    [SerializeField] private string firstGameplayScene = "MainMenu";

    async Awaitable Start()
    {
        // Create persistent managers
        DontDestroyOnLoad(gameObject);

        // Initialize services in dependency order
        var audio = gameObject.AddComponent<AudioService>();
        var save = gameObject.AddComponent<SaveService>();

        Services.Register<IAudioService>(audio);
        Services.Register<ISaveService>(save);

        // Load saved settings before gameplay
        await save.LoadSettingsAsync(destroyCancellationToken);

        // Load the first gameplay scene (replaces Boot scene)
        await SceneManager.LoadSceneAsync(firstGameplayScene);
    }
}
```

SCAFFOLD (RuntimeInitializeOnLoadMethod):
```csharp
public static class GameBootstrap
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Bootstrap()
    {
        // Create a persistent GameObject for managers
        var go = new GameObject("[Services]");
        Object.DontDestroyOnLoad(go);

        var audio = go.AddComponent<AudioService>();
        Services.Register<IAudioService>(audio);

        // NOTE: Cannot use async/await here -- this is a static method
        // For async init, have a manager use async Awaitable Start()
    }
}
```

GOTCHA: `RuntimeInitializeOnLoadMethod` cannot use `await` (it's a static synchronous method). If your bootstrap needs async operations (loading configs, authenticating), use `BeforeSceneLoad` to create a bootstrap MonoBehaviour, then do async work in its `Start()`. Boot Scene approach requires adding the Boot scene to Build Settings as scene 0. Cross-ref: `unity-lifecycle` covers `RuntimeInitializeOnLoadMethod` timing in detail.

---

## Architecture Anti-Patterns

| Anti-Pattern | Problem | Alternative |
|---|---|---|
| God MonoBehaviour (1000+ lines) | Untestable, hard to modify, merge conflicts | Split into focused components + plain C# logic classes |
| Singleton for everything | Tight coupling, untestable, hidden dependencies | Service Locator for infra, DI for gameplay |
| `FindObjectOfType` in Update | O(n) search every frame, slow | Cache reference in Start/Awake, or use events/SO |
| Manager-of-Managers | Centralized bottleneck, circular dependencies | Each system registers with Service Locator independently |
| Direct cross-references between systems | Breaks if either system is removed/replaced | Event channels or Service Locator with interfaces |
| Static state without domain-reload reset | Stale data between play sessions in Editor | `[RuntimeInitializeOnLoadMethod(SubsystemRegistration)]` |

## Related Skills

- **unity-scripting/references/scriptableobjects.md** -- SO Event Channels, Runtime Sets, Variable References (full implementations)
- **unity-lifecycle** -- RuntimeInitializeOnLoadMethod timing, SubsystemRegistration, DontDestroyOnLoad
- **unity-state-machines** -- FSM/BT as plain C# classes following the MonoBehaviour wrapper pattern
- **unity-testing** -- How Service Locator enables mocking in Edit Mode tests

## Additional Resources

- [Unity Architecture: Game Programming Patterns](https://unity.com/how-to/develop-modular-flexible-codebase-game-programming-patterns-e-book)
- [ScriptableObject Architecture (Ryan Hipple GDC Talk)](https://www.youtube.com/watch?v=raQ3iHhE_Kk)
- [VContainer](https://vcontainer.hadashikick.jp/)
- [Zenject/Extenject](https://github.com/Mathijs-Bakker/Extenject)
