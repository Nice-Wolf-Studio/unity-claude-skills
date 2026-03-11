# Architecture Patterns Reference

Detailed implementations for game architecture scaffolds. Supplements the DECISION blocks in the parent SKILL.md.

## Complete Service Locator with Interface Backing

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Lightweight service locator for infrastructure services.
/// Register with interfaces, not concrete types.
/// </summary>
public static class Services
{
    private static readonly Dictionary<Type, object> _services = new();

    /// <summary>Register a service. Overwrites any existing registration for this type.</summary>
    public static void Register<T>(T service) where T : class
    {
        _services[typeof(T)] = service ?? throw new ArgumentNullException(nameof(service));
    }

    /// <summary>Get a registered service. Throws if not found.</summary>
    public static T Get<T>() where T : class
    {
        if (_services.TryGetValue(typeof(T), out var service))
            return (T)service;
        throw new InvalidOperationException(
            $"Service {typeof(T).Name} not registered. Call Services.Register<{typeof(T).Name}>() first.");
    }

    /// <summary>Try to get a service without throwing.</summary>
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

    /// <summary>Check if a service is registered.</summary>
    public static bool Has<T>() where T : class => _services.ContainsKey(typeof(T));

    /// <summary>Remove a service registration.</summary>
    public static void Unregister<T>() where T : class => _services.Remove(typeof(T));

    /// <summary>Clear all registrations. Called on domain reload.</summary>
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() => _services.Clear();
}
```

### Test Mock Pattern

```csharp
// In Edit Mode tests:
[SetUp]
public void Setup()
{
    // Register a mock audio service
    Services.Register<IAudioService>(new MockAudioService());
}

[TearDown]
public void Teardown()
{
    Services.Unregister<IAudioService>();
}

[Test]
public void PlayerDeath_PlaysSFX()
{
    var mockAudio = (MockAudioService)Services.Get<IAudioService>();
    var health = new HealthSystem(100);

    health.TakeDamage(100);

    Assert.IsTrue(mockAudio.PlayedSFXs.Contains("death"));
}

// Mock implementation
public class MockAudioService : IAudioService
{
    public List<string> PlayedSFXs { get; } = new();
    public void PlaySFX(string name) => PlayedSFXs.Add(name);
    public void PlayMusic(string name) { }
    public void StopMusic() { }
}
```

---

## Complete Typed Event Bus

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Static typed event bus for system-level communication.
/// Use struct events to avoid allocation.
/// </summary>
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

    /// <summary>Clear all handlers. For testing and domain reload.</summary>
    public static void Clear() => _handlers.Clear();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() => _handlers.Clear();
}

// --- Event definitions (in a shared Events.cs file) ---

public struct PlayerDiedEvent
{
    public Vector3 Position;
    public string CauseOfDeath;
}

public struct ScoreChangedEvent
{
    public int NewScore;
    public int Delta;
}

public struct LevelCompletedEvent
{
    public int LevelIndex;
    public float CompletionTime;
}

// --- Usage example ---

public class ScoreUI : MonoBehaviour
{
    void OnEnable() => EventBus.Subscribe<ScoreChangedEvent>(OnScoreChanged);
    void OnDisable() => EventBus.Unsubscribe<ScoreChangedEvent>(OnScoreChanged);

    void OnScoreChanged(ScoreChangedEvent evt)
    {
        scoreText.text = evt.NewScore.ToString();
    }
}
```

---

## MonoBehaviour Wrapper Pattern

For encapsulating plain C# logic classes within the Unity component system.

```csharp
// --- Plain C# class (testable, no Unity dependency beyond Mathf) ---

public class DamageCalculator
{
    private readonly float _baseDamage;
    private readonly float _critMultiplier;

    public DamageCalculator(float baseDamage, float critMultiplier)
    {
        _baseDamage = baseDamage;
        _critMultiplier = critMultiplier;
    }

    public float Calculate(float distance, bool isCrit, float armor)
    {
        float damage = _baseDamage;

        // Falloff by distance
        float falloff = Mathf.Clamp01(1f - (distance / 50f));
        damage *= falloff;

        // Crit
        if (isCrit) damage *= _critMultiplier;

        // Armor reduction
        damage *= 1f - (armor / (armor + 100f));

        return Mathf.Max(0f, damage);
    }
}

// --- MonoBehaviour wrapper (bridges Inspector <-> Logic) ---

public class WeaponComponent : MonoBehaviour
{
    [Header("Config")]
    [SerializeField] private float baseDamage = 25f;
    [SerializeField] private float critMultiplier = 2f;

    private DamageCalculator _calculator;

    void Awake()
    {
        _calculator = new DamageCalculator(baseDamage, critMultiplier);
    }

    public float GetDamage(float distance, bool isCrit, float targetArmor)
    {
        return _calculator.Calculate(distance, isCrit, targetArmor);
    }
}
```

---

## DI Framework Comparison

| Feature | No DI (Manual) | Service Locator | VContainer | Zenject/Extenject |
|---------|---------------|-----------------|------------|-------------------|
| Setup complexity | None | Minimal | Moderate | Moderate-High |
| Dependencies visible | At call site | Hidden (implicit) | In installer | In installer |
| Testability | Pass in constructor | Register mocks | Bind mocks | Bind mocks |
| MonoBehaviour injection | Manual (Awake) | `Services.Get<T>()` | `[Inject]` attribute | `[Inject]` attribute |
| Scene independence | Yes | Yes | Per-scope | Per-scope |
| Performance overhead | None | Dictionary lookup | Reflection at startup | Reflection at startup |
| Learning curve | None | Low | Medium | Medium-High |
| Best for | Small projects | Medium projects | Large projects | Large projects |

### When to use each

- **No DI / Manual**: Prototype, game jam, solo developer, < 5 systems
- **Service Locator**: 5-15 systems, need mock testing, don't want framework dependency
- **VContainer**: 15+ systems, multiple developers, want compile-time safety, Unity-native
- **Zenject**: Legacy projects already using it, complex scope hierarchies needed

---

## Event Architecture Selection Guide

```
Need systems to communicate?
|
+-- Same GameObject, same class?
|     --> C# event/Action (public event Action<T> OnSomething)
|
+-- Same GameObject, different components?
|     --> GetComponent + direct call, or C# event on shared component
|
+-- Different GameObjects, same scene?
|     +-- Designer needs to wire it?
|     |     --> SO Event Channel (drag-and-drop in Inspector)
|     +-- Code-only is fine?
|           --> Static Event Bus or C# event on shared reference
|
+-- Cross-scene communication?
|     --> SO Event Channel (survives scene loads)
|     --> or Static Event Bus (code-only, domain-reload safe)
|
+-- One-to-one notification?
      --> Direct C# event (Action/delegate) on the source
```

### SO Event Channels vs Static Event Bus

| Feature | SO Event Channel | Static Event Bus |
|---------|-----------------|-----------------|
| Wiring | Inspector drag-and-drop | Code-only |
| Designer access | Yes | No |
| Debugging | Select asset, see listeners | Need custom tooling |
| Scene independence | Yes (asset-based) | Yes (static) |
| Type safety | Per-channel class | Generic `<T>` |
| Allocation | One SO asset per channel | Zero (struct events) |
| Best for | Gameplay events | System/infrastructure events |

See `unity-scripting/references/scriptableobjects.md` for complete SO Event Channel implementation.
