---
name: unity-data-driven
description: >
  Unity data-driven design architecture. ScriptableObject config hierarchies, JSON data pipelines,
  designer handoff workflows, data versioning and migration, Inspector attributes for self-documenting
  configs. DECISION format: WHEN/DECISION/SCAFFOLD/GOTCHA. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.asset"
---

# Data-Driven Design -- Decision Patterns

> **Prerequisite skills:** `unity-scripting/references/scriptableobjects.md` (SO creation, event channels, runtime sets, variable references), `unity-editor-tools` (custom inspectors, EditorWindow)

These patterns address the most common data management failure: Claude hardcodes tunable values in MonoBehaviours or uses magic numbers, making iteration and balancing painful. All game data should be designer-editable without code changes.

---

## PATTERN: Config Data Storage Selection

WHEN: Choosing where to store game configuration (enemy stats, level layouts, loot tables)

DECISION:
- **ScriptableObject assets** (default) -- Designer-editable in Inspector, type-safe, refactorable, version-controlled as YAML. Best for most game configs.
- **JSON/CSV files** -- External tools generate data (spreadsheets, web tools), need modding support, or bulk editing is required. Loaded at runtime.
- **Embedded constants** -- Truly fixed values (physics constants, math, protocol versions). `static readonly` or `const`.

SCAFFOLD (ScriptableObject config):
```csharp
[CreateAssetMenu(fileName = "New Enemy Config", menuName = "Game/Enemy Config")]
public class EnemyConfig : ScriptableObject
{
    [Header("Stats")]
    [Min(1)] public int maxHealth = 100;
    [Range(0f, 20f)] public float moveSpeed = 5f;
    [Range(0f, 50f)] public float attackDamage = 10f;

    [Header("AI")]
    [Range(1f, 50f)] public float detectionRange = 15f;
    [Range(0.5f, 5f)] public float attackCooldown = 1.5f;

    [Header("Rewards")]
    [Min(0)] public int xpReward = 25;
    [Tooltip("Loot dropped on death. Leave empty for no loot.")]
    public LootTable lootTable;
}

// Usage in MonoBehaviour:
public class Enemy : MonoBehaviour
{
    [SerializeField] private EnemyConfig config; // Assign in Inspector

    void Awake()
    {
        // Read from config -- never hardcode values
        _health = new HealthSystem(config.maxHealth);
        _moveSpeed = config.moveSpeed;
    }
}
```

GOTCHA: ScriptableObject assets modified at runtime in the Editor persist those changes to disk (the .asset file is saved). In builds, runtime modifications are lost when the application exits. Never rely on runtime SO modification for save data -- use a separate save system. See `unity-save-system` for persistence.

---

## PATTERN: ScriptableObject Inheritance vs Composition

WHEN: Multiple config types share base fields (all enemies have HP/speed, subtypes add flying/ranged/boss fields)

DECISION:
- **SO inheritance** -- `EnemyConfig : ScriptableObject`, `FlyingEnemyConfig : EnemyConfig`. Each subtype adds its own fields. Designer sees only relevant fields per asset. Works well for 2-3 levels of hierarchy.
- **Nested `[Serializable]` structs (composition)** -- `EnemyConfig` contains `[SerializeField] MovementConfig movement; [SerializeField] AttackConfig attack;`. Mix-and-match capabilities. Often cleaner than inheritance for wide variation.

SCAFFOLD (Composition):
```csharp
[System.Serializable]
public struct MovementConfig
{
    [Range(0f, 20f)] public float speed;
    public bool canFly;
    [Tooltip("Only used if canFly is true")]
    [Range(0f, 50f)] public float flyHeight;
}

[System.Serializable]
public struct AttackConfig
{
    public AttackType type;
    [Range(0f, 100f)] public float damage;
    [Range(0.1f, 10f)] public float cooldown;
    [Range(0f, 30f)] public float range;
}

[CreateAssetMenu(fileName = "New Enemy", menuName = "Game/Enemy Config")]
public class EnemyConfig : ScriptableObject
{
    [Header("Identity")]
    public string displayName;
    [TextArea(2, 4)] public string description;

    [Header("Movement")]
    public MovementConfig movement;

    [Header("Combat")]
    public AttackConfig attack;

    [Header("Stats")]
    [Min(1)] public int maxHealth = 100;
    [Min(0)] public int xpReward = 25;
}
```

SCAFFOLD (Inheritance):
```csharp
public abstract class EnemyConfig : ScriptableObject
{
    [Min(1)] public int maxHealth = 100;
    [Range(0f, 20f)] public float moveSpeed = 5f;
}

[CreateAssetMenu(fileName = "New Melee Enemy", menuName = "Game/Enemies/Melee")]
public class MeleeEnemyConfig : EnemyConfig
{
    [Range(0f, 50f)] public float meleeDamage = 15f;
    [Range(0.5f, 3f)] public float attackRadius = 1.5f;
}

[CreateAssetMenu(fileName = "New Ranged Enemy", menuName = "Game/Enemies/Ranged")]
public class RangedEnemyConfig : EnemyConfig
{
    [Range(0f, 50f)] public float projectileDamage = 10f;
    [Range(5f, 30f)] public float fireRange = 15f;
    public GameObject projectilePrefab;
}
```

GOTCHA: SO inheritance shows ALL base fields in the Inspector (no hiding). Use `[HideInInspector]` or a custom editor if base fields clutter the Inspector. Composition with `[Serializable]` structs is often cleaner because each struct can be reused across unrelated config types. `[CreateAssetMenu]` only works on concrete (non-abstract) ScriptableObject subclasses.

---

## PATTERN: JSON Data Pipeline

WHEN: Loading game data from external sources (spreadsheets, web APIs, modding)

DECISION:
- **Build-time pipeline** -- Convert JSON/CSV to ScriptableObject assets in an Editor script. Data is baked at build time. Designer edits spreadsheet, runs import, data becomes SO assets.
- **Runtime loading** -- Load JSON from StreamingAssets or a remote URL at runtime. Supports modding, hot-reload, and server-driven config.

SCAFFOLD (Runtime JSON loading):
```csharp
// Data class (plain C#, not ScriptableObject)
[System.Serializable]
public class WaveData
{
    public int waveNumber;
    public string[] enemyTypes;
    public int[] enemyCounts;
    public float spawnInterval;
}

[System.Serializable]
public class WaveDataList
{
    public WaveData[] waves; // JsonUtility requires a wrapper for arrays
}

// Loading
public class WaveLoader : MonoBehaviour
{
    async Awaitable<WaveData[]> LoadWaves()
    {
        string path = Path.Combine(Application.streamingAssetsPath, "waves.json");

        #if UNITY_ANDROID && !UNITY_EDITOR
        // Android: StreamingAssets is inside APK, must use UnityWebRequest
        using var request = UnityWebRequest.Get(path);
        await request.SendWebRequest();
        string json = request.downloadHandler.text;
        #else
        string json = await File.ReadAllTextAsync(path);
        #endif

        var wrapper = JsonUtility.FromJson<WaveDataList>(json);
        return wrapper.waves;
    }
}
```

GOTCHA: `JsonUtility` cannot serialize: dictionaries, top-level arrays (need a wrapper class), polymorphic types, null values (uses default instead), or properties (only fields). For any of these, use Newtonsoft JSON (`com.unity.nuget.newtonsoft-json` package). `Application.streamingAssetsPath` is read-only on all platforms and requires `UnityWebRequest` on Android. See `references/data-pipeline-patterns.md` for the Editor import script.

---

## PATTERN: Designer Handoff Workflow

WHEN: Designers need to create and edit game data without touching code

DECISION:
- **SO + CreateAssetMenu** -- Designers right-click in Project window to create config assets, edit in Inspector. Best for small-medium data sets (< 100 items).
- **SO + Custom EditorWindow** -- Bulk editing, validation, search/filter. Worth the investment for large data sets (100+ items, loot tables, dialogue).
- **External spreadsheet + import** -- Google Sheets/Excel -> CSV -> Editor import script. Best when designers prefer spreadsheets or data comes from external tools.

SCAFFOLD (Self-documenting Inspector):
```csharp
[CreateAssetMenu(fileName = "New Weapon", menuName = "Game/Weapons/Weapon Config")]
public class WeaponConfig : ScriptableObject
{
    [Header("Identity")]
    [Tooltip("Display name shown in UI and inventory")]
    public string displayName;

    [TextArea(2, 5)]
    [Tooltip("Flavor text shown in the item tooltip")]
    public string description;

    public Sprite icon;

    [Header("Combat Stats")]
    [Tooltip("Base damage before modifiers. Actual damage = base * level multiplier")]
    [Range(1f, 200f)] public float baseDamage = 10f;

    [Tooltip("Seconds between attacks")]
    [Range(0.1f, 5f)] public float attackSpeed = 1f;

    [Tooltip("Maximum range in world units")]
    [Range(0.5f, 30f)] public float range = 2f;

    [Header("VFX/SFX")]
    [Tooltip("Played on hit. Leave null for no effect")]
    public GameObject hitEffect;

    [Tooltip("Played on attack")]
    public AudioClip attackSound;

    [Space(10)]
    [Header("Advanced")]
    [Tooltip("Damage falloff over distance. X = normalized distance (0-1), Y = damage multiplier")]
    public AnimationCurve damageFalloff = AnimationCurve.Linear(0, 1, 1, 0.5f);
}
```

GOTCHA: Designers cannot read code comments -- use `[Tooltip("...")]` on every field. Use `[Range(min, max)]` to prevent invalid data entry. Use `[Header("Section")]` to group related fields. Use `[Space(10)]` for visual separation. `AnimationCurve` fields are powerful for designer-tunable falloffs, easing, and response curves. Mark optional references with tooltips like "Leave null for no effect".

---

## PATTERN: Data Versioning and Migration

WHEN: Shipped data format changes between updates (added/renamed/removed fields)

DECISION:
- **SO resilient serialization (additive changes)** -- Adding new fields gives them default values. Removing fields silently drops data. Safe for non-breaking changes. Unity handles this automatically.
- **Explicit version field + migrator** -- For breaking changes (renamed fields, restructured data). Store `int version` in the data, run migration on load.

SCAFFOLD (FormerlySerializedAs for renames):
```csharp
using UnityEngine.Serialization;

public class EnemyConfig : ScriptableObject
{
    // Renamed from "hp" to "maxHealth" -- existing assets preserved
    [FormerlySerializedAs("hp")]
    [Min(1)] public int maxHealth = 100;

    // Renamed from "speed" to "moveSpeed"
    [FormerlySerializedAs("speed")]
    [Range(0f, 20f)] public float moveSpeed = 5f;

    // New field -- existing assets get the default value (25)
    [Min(0)] public int xpReward = 25;

    // Removed field: just delete it. Existing assets silently drop the old data.
}
```

SCAFFOLD (Versioned runtime data with migration):
```csharp
[System.Serializable]
public class PlayerData
{
    public int version = 2; // Current schema version
    public string playerName;
    public int level;
    public float[] position; // v2: changed from Vector3 to float[] for JSON compat

    // Migration from v1 to v2
    public static PlayerData MigrateFromV1(string json)
    {
        // v1 had "pos_x", "pos_y", "pos_z" as separate fields
        var jObj = Newtonsoft.Json.Linq.JObject.Parse(json);
        if ((int)jObj["version"] == 1)
        {
            float x = (float)jObj["pos_x"];
            float y = (float)jObj["pos_y"];
            float z = (float)jObj["pos_z"];
            jObj.Remove("pos_x"); jObj.Remove("pos_y"); jObj.Remove("pos_z");
            jObj["position"] = new Newtonsoft.Json.Linq.JArray(x, y, z);
            jObj["version"] = 2;
        }
        return jObj.ToObject<PlayerData>();
    }
}
```

GOTCHA: `[FormerlySerializedAs]` only works for Unity serialization (Inspector, .asset files, prefabs). It does NOT work for JSON or custom serialization. For JSON migration, you must parse the raw JSON before deserializing to the new type. SO data versioning and save data versioning are different problems -- see `unity-save-system` for save file migration.

---

## Inspector Attribute Quick Reference

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `[Header("Section")]` | Section label | Group related fields |
| `[Tooltip("Help text")]` | Hover help text | Explain non-obvious fields |
| `[Range(min, max)]` | Slider for numeric fields | `[Range(0, 100)]` |
| `[Min(value)]` | Minimum value clamp | `[Min(0)]` for non-negative |
| `[TextArea(min, max)]` | Multi-line text field | `[TextArea(2, 5)]` |
| `[Space(pixels)]` | Vertical spacing | `[Space(10)]` |
| `[HideInInspector]` | Hide from Inspector | Internal fields |
| `[FormerlySerializedAs]` | Preserve data on rename | Migration safety |
| `[ColorUsage(alpha, hdr)]` | Color picker config | `[ColorUsage(true, true)]` |
| `[GradientUsage(hdr)]` | Gradient HDR support | VFX color ramps |
| `[Delayed]` | Apply on Enter/focus loss | Prevent per-keystroke updates |
| `[SerializeReference]` | Polymorphic serialization | Interface fields |

## Related Skills

- **unity-scripting/references/scriptableobjects.md** -- SO creation, event channels, runtime sets, variable references
- **unity-editor-tools** -- Custom EditorWindow for bulk editing, PropertyDrawer for custom display
- **unity-save-system** -- Runtime data persistence (versus config data)
- **unity-game-architecture** -- ScriptableObject architecture decisions

## Additional Resources

- [ScriptableObject API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/ScriptableObject.html)
- [JsonUtility](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/JsonUtility.html)
- [FormerlySerializedAs](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Serialization.FormerlySerializedAsAttribute.html)
- [SerializeReference](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/SerializeReference.html)
