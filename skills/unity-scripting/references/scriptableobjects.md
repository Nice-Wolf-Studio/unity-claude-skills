# ScriptableObject Reference

> Source: [Unity 6.3 ScriptableObject Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-ScriptableObject.html)

## What Are ScriptableObjects?

ScriptableObjects are serializable Unity types derived from `UnityEngine.Object`. Unlike MonoBehaviours, they are NOT attached to GameObjects. They exist as independent project assets and are referenced via Inspector fields.

## Key Characteristics

- Stored as `.asset` files in the project
- Shared across multiple objects (single instance in memory)
- Survive scene transitions (they are project assets, not scene objects)
- In Edit mode: Inspector changes save automatically; script changes require `EditorUtility.SetDirty()`
- At runtime: read-only in builds (runtime modifications exist only in memory, not persisted to disk)

## Creating ScriptableObjects

### Define the Class

```csharp
using UnityEngine;

[CreateAssetMenu(fileName = "Data", menuName = "ScriptableObjects/SpawnManagerScriptableObject", order = 1)]
public class SpawnManagerScriptableObject : ScriptableObject
{
    public string prefabName;
    public int numberOfPrefabsToCreate;
    public Vector3[] spawnPoints;
}
```

The `[CreateAssetMenu]` attribute adds an entry to the **Assets > Create** menu in the Unity Editor.

### Create an Instance in Editor

1. Right-click in Project window
2. **Create > ScriptableObjects > SpawnManagerScriptableObject**
3. Configure values in the Inspector

### Create an Instance via Script

```csharp
// Runtime creation (not saved as asset)
var config = ScriptableObject.CreateInstance<SpawnManagerScriptableObject>();
config.prefabName = "Enemy";
config.numberOfPrefabsToCreate = 10;

// Editor-only: save as asset
#if UNITY_EDITOR
UnityEditor.AssetDatabase.CreateAsset(config, "Assets/Data/NewConfig.asset");
UnityEditor.AssetDatabase.SaveAssets();
#endif
```

### Reference from MonoBehaviour

```csharp
public class SpawnManager : MonoBehaviour
{
    [SerializeField] private SpawnManagerScriptableObject _spawnData;

    void Start()
    {
        for (int i = 0; i < _spawnData.numberOfPrefabsToCreate; i++)
        {
            Vector3 pos = _spawnData.spawnPoints[i % _spawnData.spawnPoints.Length];
            Instantiate(Resources.Load(_spawnData.prefabName), pos, Quaternion.identity);
        }
    }
}
```

## Use Case Patterns

### 1. Shared Configuration Data

Store game balance values, enemy stats, weapon data -- referenced by many objects without duplication.

```csharp
[CreateAssetMenu(menuName = "Config/Weapon Stats")]
public class WeaponStats : ScriptableObject
{
    public string weaponName;
    public float damage;
    public float fireRate;
    public float range;
    public int magazineSize;
    public AudioClip fireSound;
    public GameObject muzzleFlashPrefab;
}

public class Weapon : MonoBehaviour
{
    [SerializeField] private WeaponStats _stats;

    private float _nextFireTime;
    private int _currentAmmo;

    void Start()
    {
        _currentAmmo = _stats.magazineSize;
    }

    void Fire()
    {
        if (Time.time < _nextFireTime || _currentAmmo <= 0) return;

        _nextFireTime = Time.time + (1f / _stats.fireRate);
        _currentAmmo--;
        // Use _stats.damage, _stats.range, etc.
    }
}
```

**Memory advantage:** 100 enemies referencing the same `WeaponStats` asset share one copy of the data instead of each holding their own duplicate.

### 2. Enum-Like Collections

Replace enums with ScriptableObject instances for extensibility.

```csharp
[CreateAssetMenu(menuName = "Config/Item Type")]
public class ItemType : ScriptableObject
{
    public string displayName;
    public Sprite icon;
    public Color rarityColor;
    public int maxStackSize;
}
```

Designers can create new item types without modifying code.

### 3. Event Channels (Decoupled Communication)

ScriptableObject-based events allow systems to communicate without direct references.

```csharp
[CreateAssetMenu(menuName = "Events/Void Event Channel")]
public class VoidEventChannel : ScriptableObject
{
    private System.Action _onEventRaised;

    public void RaiseEvent()
    {
        _onEventRaised?.Invoke();
    }

    public void Subscribe(System.Action listener)
    {
        _onEventRaised += listener;
    }

    public void Unsubscribe(System.Action listener)
    {
        _onEventRaised -= listener;
    }
}
```

```csharp
[CreateAssetMenu(menuName = "Events/Int Event Channel")]
public class IntEventChannel : ScriptableObject
{
    private System.Action<int> _onEventRaised;

    public void RaiseEvent(int value)
    {
        _onEventRaised?.Invoke(value);
    }

    public void Subscribe(System.Action<int> listener)
    {
        _onEventRaised += listener;
    }

    public void Unsubscribe(System.Action<int> listener)
    {
        _onEventRaised -= listener;
    }
}
```

**Publisher (knows nothing about subscribers):**

```csharp
public class PlayerHealth : MonoBehaviour
{
    [SerializeField] private IntEventChannel _onHealthChanged;
    [SerializeField] private VoidEventChannel _onPlayerDeath;

    private int _currentHealth = 100;

    public void TakeDamage(int amount)
    {
        _currentHealth -= amount;
        _onHealthChanged.RaiseEvent(_currentHealth);

        if (_currentHealth <= 0)
            _onPlayerDeath.RaiseEvent();
    }
}
```

**Subscriber (knows nothing about publishers):**

```csharp
public class HealthUI : MonoBehaviour
{
    [SerializeField] private IntEventChannel _onHealthChanged;

    void OnEnable() => _onHealthChanged.Subscribe(UpdateHealthBar);
    void OnDisable() => _onHealthChanged.Unsubscribe(UpdateHealthBar);

    private void UpdateHealthBar(int health)
    {
        // Update UI elements
    }
}
```

### 4. Runtime Data Sets

Track runtime collections without singletons.

```csharp
[CreateAssetMenu(menuName = "Data/Runtime Set")]
public class RuntimeSet<T> : ScriptableObject
{
    [System.NonSerialized] private List<T> _items = new List<T>();

    public IReadOnlyList<T> Items => _items;

    public void Add(T item)
    {
        if (!_items.Contains(item))
            _items.Add(item);
    }

    public void Remove(T item) => _items.Remove(item);
}
```

### 5. Variable References (Shared State)

```csharp
[CreateAssetMenu(menuName = "Variables/Float Variable")]
public class FloatVariable : ScriptableObject
{
    public float value;

    public void SetValue(float newValue) => value = newValue;
    public void ApplyChange(float delta) => value += delta;
}
```

```csharp
public class PlayerScore : MonoBehaviour
{
    [SerializeField] private FloatVariable _score;

    public void AddPoints(float points)
    {
        _score.ApplyChange(points);
    }
}

public class ScoreDisplay : MonoBehaviour
{
    [SerializeField] private FloatVariable _score;
    [SerializeField] private TMPro.TextMeshProUGUI _text;

    void Update()
    {
        _text.text = $"Score: {_score.value:F0}";
    }
}
```

Both components reference the same `FloatVariable` asset -- no direct coupling.

## ScriptableObject Lifecycle

ScriptableObjects have a limited set of lifecycle callbacks compared to MonoBehaviour:

| Callback | When |
|----------|------|
| `Awake()` | When the instance is created (CreateInstance or loaded from asset) |
| `OnEnable()` | When the object is loaded/enabled |
| `OnDisable()` | When the object is about to be unloaded |
| `OnDestroy()` | When the object is being destroyed |
| `OnValidate()` | Editor-only: when loaded or Inspector values change |

```csharp
public class GameConfig : ScriptableObject
{
    [SerializeField] private float _maxSpeed = 10f;

    void OnEnable()
    {
        // Called when asset is loaded
        // Good place for runtime initialization
    }

    void OnValidate()
    {
        // Editor-only: enforce constraints
        _maxSpeed = Mathf.Max(0f, _maxSpeed);
    }
}
```

## Data Persistence

| Context | Behavior |
|---------|----------|
| **Editor, Inspector changes** | Saved automatically on project save |
| **Editor, script changes** | Must call `EditorUtility.SetDirty(obj)` then save |
| **Runtime (Play mode)** | Changes persist until Play mode ends, then revert |
| **Runtime (Built player)** | Read-only; modifications exist only in memory |

For persistent runtime data, combine ScriptableObjects with a save system (JSON, binary, PlayerPrefs).

## Architecture Recommendations

### Do

- Use ScriptableObjects for shared read-only configuration
- Use event channels for decoupled communication across scenes
- Use `[CreateAssetMenu]` so designers can create assets without code
- Reset runtime state in `OnEnable()` if the ScriptableObject carries mutable runtime data

### Do Not

- Store large amounts of transient runtime state (use MonoBehaviours or plain C# classes)
- Expect runtime modifications to persist in builds
- Forget that all references point to the same instance (mutations are shared)
- Create ScriptableObject instances with `new` -- always use `ScriptableObject.CreateInstance<T>()`

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `new MyScriptableObject()` | Bypasses Unity lifecycle | Use `ScriptableObject.CreateInstance<T>()` |
| Mutable runtime data without reset | Data persists between Play sessions in editor | Reset in `OnEnable()` or use `[NonSerialized]` |
| Massive ScriptableObjects | Entire asset loads into memory | Split into smaller focused assets |
| Direct field access without encapsulation | Hard to add validation or events later | Use properties or methods |
| Circular references between ScriptableObjects | Serialization issues, hard to reason about | Use event channels for indirect communication |
