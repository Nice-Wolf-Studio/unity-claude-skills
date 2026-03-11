---
name: unity-save-system
description: >
  Unity save/load system architecture. Serialization format selection, save data DTOs,
  versioning and migration, cloud sync, PlayerPrefs scoping, auto-save strategies,
  mobile persistence. DECISION format: WHEN/DECISION/SCAFFOLD/GOTCHA. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
---

# Save/Load Systems -- Decision Patterns

> **Prerequisite skills:** `unity-lifecycle` (OnApplicationPause, OnApplicationQuit, quit sequence), `unity-data-driven` (JSON serialization, versioning), `unity-packages-services` (Cloud Save API), `unity-async-patterns` (BackgroundThreadAsync)

These patterns address the most common save system failure: Claude uses `PlayerPrefs` for everything, produces brittle serialization with no versioning, and ignores mobile-specific persistence requirements.

---

## PATTERN: Serialization Format Selection

WHEN: Choosing how to serialize save data to disk

DECISION:
- **JSON (`JsonUtility`)** -- Human-readable, debuggable, small save files. No dictionary/polymorphism. Best default for most games.
- **JSON (Newtonsoft)** -- Full JSON features (dictionaries, polymorphism, LINQ). Slightly larger dependency. Best when save data is complex.
- **Binary (custom or MessagePack)** -- Performance-critical, large saves, anti-cheat (harder to edit). Not human-readable. Best for competitive games or very large worlds.
- **BinaryFormatter** -- **NEVER USE**. Security vulnerability (arbitrary code execution on deserialization). Deprecated by Unity and Microsoft.

SCAFFOLD (JSON save/load):
```csharp
using System.IO;
using UnityEngine;

public static class SaveFileIO
{
    public static void SaveJson<T>(T data, string fileName)
    {
        string path = GetSavePath(fileName);
        string json = JsonUtility.ToJson(data, prettyPrint: true);

        // Write to temp file first, then rename (atomic write)
        string tempPath = path + ".tmp";
        File.WriteAllText(tempPath, json);
        if (File.Exists(path))
            File.Replace(tempPath, path, path + ".bak");
        else
            File.Move(tempPath, path);
    }

    public static T LoadJson<T>(string fileName) where T : new()
    {
        string path = GetSavePath(fileName);
        if (!File.Exists(path)) return new T();

        string json = File.ReadAllText(path);
        return JsonUtility.FromJson<T>(json);
    }

    public static bool SaveExists(string fileName) =>
        File.Exists(GetSavePath(fileName));

    public static void DeleteSave(string fileName)
    {
        string path = GetSavePath(fileName);
        if (File.Exists(path)) File.Delete(path);
        if (File.Exists(path + ".bak")) File.Delete(path + ".bak");
    }

    static string GetSavePath(string fileName) =>
        Path.Combine(Application.persistentDataPath, fileName);
}
```

GOTCHA: `BinaryFormatter` is a security hole -- deserialization can execute arbitrary code. Unity and Microsoft have deprecated it. If you find it in existing code, replace it immediately. `JsonUtility` cannot serialize dictionaries -- convert to `List<SerializableKeyValue<K,V>>` or use Newtonsoft. The atomic write pattern (write to .tmp, rename) prevents data corruption if the app crashes mid-write.

---

## PATTERN: Save Data Architecture (DTO Pattern)

WHEN: Deciding what to serialize and how to structure it

DECISION:
- **Single monolithic save** -- One `SaveData` class with everything. Load/save is atomic. Best for small games with fast save/load.
- **Per-system save files** -- `PlayerSave.json`, `InventorySave.json`, `WorldSave.json`. Partial load, smaller writes, easier to migrate individual systems.

SCAFFOLD (ISaveable interface):
```csharp
// Save Data Transfer Object -- plain C# class, NOT MonoBehaviour
[System.Serializable]
public class GameSaveData
{
    public int version = 1;
    public PlayerSaveData player;
    public InventorySaveData inventory;
    public WorldSaveData world;
}

[System.Serializable]
public class PlayerSaveData
{
    public float[] position = new float[3]; // Vector3 as array for JSON compat
    public int health;
    public int level;
    public int xp;

    public void FromPlayer(Transform t, int hp, int lvl, int xp)
    {
        position[0] = t.position.x;
        position[1] = t.position.y;
        position[2] = t.position.z;
        health = hp; level = lvl; this.xp = xp;
    }

    public Vector3 GetPosition() => new(position[0], position[1], position[2]);
}

// Systems implement ISaveable to participate in save/load
public interface ISaveable
{
    void GatherSaveData(GameSaveData data);  // Write state to DTO
    void ApplySaveData(GameSaveData data);   // Read state from DTO
}
```

GOTCHA: Save DTOs must be plain C# classes with `[System.Serializable]`, NOT MonoBehaviours or ScriptableObjects. They contain only serializable types (primitives, arrays, lists, nested `[Serializable]` classes). Unity types like `Vector3` serialize fine with `JsonUtility` but NOT with Newtonsoft without a custom converter -- use `float[]` for portability.

---

## PATTERN: Save File Location

WHEN: Choosing where to write save files

DECISION:
- **`Application.persistentDataPath`** (correct default) -- Writable, survives app updates, platform-appropriate. Use for all save data.
- **`Application.streamingAssetsPath`** -- READ-ONLY in builds. Never write here. For bundled read-only data only.
- **`PlayerPrefs`** -- Key-value only. For settings/preferences. NOT for game state.

SCAFFOLD:
```csharp
// Always use Path.Combine -- never concatenate with "/"
string savePath = Path.Combine(Application.persistentDataPath, "saves", "slot1.json");

// Ensure directory exists before writing
string dir = Path.GetDirectoryName(savePath);
if (!Directory.Exists(dir))
    Directory.CreateDirectory(dir);
```

GOTCHA: `persistentDataPath` locations differ per platform: `AppData/LocalLow/<company>/<product>` (Windows), `~/Library/Application Support/<bundleID>` (macOS), internal storage (Android/iOS). On WebGL, it uses IndexedDB (async, may fail in private browsing). Always use `Path.Combine` -- forward slashes work on macOS/Linux but `Path.Combine` is cross-platform safe.

---

## PATTERN: PlayerPrefs Scoping

WHEN: Using PlayerPrefs for settings and small persistent values

DECISION:
- **Direct PlayerPrefs calls** -- Under 10 settings, minimal project. Simple.
- **Wrapper class** -- 10+ settings, need type safety, change events, defaults. Prevents key collision.

SCAFFOLD (Settings wrapper):
```csharp
public static class GameSettings
{
    // Prefixed keys prevent collision between systems
    private const string Prefix = "settings.";

    public static float MasterVolume
    {
        get => PlayerPrefs.GetFloat(Prefix + "masterVolume", 1f);
        set { PlayerPrefs.SetFloat(Prefix + "masterVolume", value); OnSettingsChanged?.Invoke(); }
    }

    public static bool Fullscreen
    {
        get => PlayerPrefs.GetInt(Prefix + "fullscreen", 1) == 1;
        set { PlayerPrefs.SetInt(Prefix + "fullscreen", value ? 1 : 0); OnSettingsChanged?.Invoke(); }
    }

    public static int QualityLevel
    {
        get => PlayerPrefs.GetInt(Prefix + "quality", QualitySettings.GetQualityLevel());
        set { PlayerPrefs.SetInt(Prefix + "quality", value); OnSettingsChanged?.Invoke(); }
    }

    public static event Action OnSettingsChanged;

    public static void Save() => PlayerPrefs.Save();

    public static void ResetToDefaults()
    {
        PlayerPrefs.DeleteKey(Prefix + "masterVolume");
        PlayerPrefs.DeleteKey(Prefix + "fullscreen");
        PlayerPrefs.DeleteKey(Prefix + "quality");
        OnSettingsChanged?.Invoke();
    }
}
```

GOTCHA: PlayerPrefs keys are global strings -- no namespacing. Use prefixed keys (`"audio.masterVolume"`, `"video.fullscreen"`) to prevent collisions. PlayerPrefs has no bool type -- use `int` (0/1). On Windows, PlayerPrefs stores to the Windows Registry -- avoid large values. `PlayerPrefs.Save()` is automatic on `OnApplicationQuit` but call it manually after important changes on mobile (app may be killed without quit).

---

## PATTERN: Save Versioning and Migration

WHEN: Save format changes between game updates (fields added, renamed, restructured)

DECISION:
- **Version field + sequential migrators** -- For breaking changes. Store `int version` in save. On load, run migration chain: v1 -> v2 -> v3 -> current.
- **Tolerant reader** -- For additive-only changes. New fields get defaults, removed fields are ignored. Works with `JsonUtility` automatically.

SCAFFOLD (Migration chain):
```csharp
public static class SaveMigrator
{
    private static readonly int CurrentVersion = 3;

    public static GameSaveData LoadAndMigrate(string json)
    {
        // Parse version from raw JSON first
        var versionCheck = JsonUtility.FromJson<VersionOnly>(json);
        int version = versionCheck.version;

        if (version == CurrentVersion)
            return JsonUtility.FromJson<GameSaveData>(json);

        // Sequential migration using Newtonsoft for raw JSON manipulation
        var jObj = Newtonsoft.Json.Linq.JObject.Parse(json);

        if (version < 2) MigrateV1ToV2(jObj);
        if (version < 3) MigrateV2ToV3(jObj);

        jObj["version"] = CurrentVersion;
        return Newtonsoft.Json.JsonConvert.DeserializeObject<GameSaveData>(jObj.ToString());
    }

    static void MigrateV1ToV2(Newtonsoft.Json.Linq.JObject data)
    {
        // v2 moved "playerX/Y/Z" into "player.position" array
        var player = (Newtonsoft.Json.Linq.JObject)data["player"];
        if (player != null && player["playerX"] != null)
        {
            float x = (float)player["playerX"];
            float y = (float)player["playerY"];
            float z = (float)player["playerZ"];
            player["position"] = new Newtonsoft.Json.Linq.JArray(x, y, z);
            player.Remove("playerX"); player.Remove("playerY"); player.Remove("playerZ");
        }
    }

    static void MigrateV2ToV3(Newtonsoft.Json.Linq.JObject data)
    {
        // v3 added inventory system (default to empty)
        if (data["inventory"] == null)
            data["inventory"] = Newtonsoft.Json.Linq.JObject.FromObject(new InventorySaveData());
    }

    [System.Serializable]
    private class VersionOnly { public int version; }
}
```

GOTCHA: Migration must work on raw JSON (before deserializing to the new C# type) because the old type definition may no longer exist in code. Use Newtonsoft `JObject` for structural changes. Each migration step is a function from version N to N+1 -- compose them sequentially. Test migrations with saved JSON from each version (store test fixtures).

---

## PATTERN: Cloud Save Integration

WHEN: Save data should sync across devices or persist beyond local storage

DECISION:
- **Unity Cloud Save (UGS)** -- Managed service, key-value or file storage, 200KB free per player. See `unity-packages-services` for API. Best for most indie/mid-size games.
- **Custom backend** -- Full control, unlimited storage, custom conflict resolution. You build and maintain it.

SCAFFOLD (Local-first with cloud sync):
```csharp
public class SaveManager : MonoBehaviour
{
    public async Awaitable Save(GameSaveData data)
    {
        // Always save locally first (fast, reliable)
        SaveFileIO.SaveJson(data, "savegame.json");

        // Then sync to cloud in background (best-effort)
        try
        {
            var cloudData = new Dictionary<string, object>
            {
                { "savegame", JsonUtility.ToJson(data) }
            };
            await Unity.Services.CloudSave.CloudSaveService.Instance
                .Data.Player.SaveAsync(cloudData);
        }
        catch (Exception e)
        {
            Debug.LogWarning($"Cloud save failed (local save preserved): {e.Message}");
        }
    }
}
```

GOTCHA: Cloud saves must handle offline play. Always save locally first, sync to cloud in the background. Handle `CloudSaveException` gracefully -- network failures should never prevent local play or crash the game. For conflict resolution, "last-write-wins" is simplest; use timestamps if you need merge logic.

---

## PATTERN: Auto-Save Strategy

WHEN: Deciding when to trigger saves

DECISION:
- **Checkpoint-based** -- Save at specific game events (level complete, rest point, manual save). Explicit, designer-controlled. Traditional approach.
- **Periodic auto-save** -- Save every N seconds or on scene transition. Safety net against crashes. Can be combined with checkpoints.
- **Event-driven** -- Save whenever significant state changes (item acquired, quest completed). Granular but more I/O.

SCAFFOLD (Auto-save + mobile safety):
```csharp
public class AutoSaveManager : MonoBehaviour
{
    [SerializeField] private float autoSaveInterval = 60f; // seconds
    private float _timeSinceLastSave;

    void Update()
    {
        _timeSinceLastSave += Time.unscaledDeltaTime;
        if (_timeSinceLastSave >= autoSaveInterval)
        {
            _timeSinceLastSave = 0f;
            _ = PerformAutoSave(); // Fire-and-forget with error handling
        }
    }

    // Mobile: save on app background (OnApplicationQuit may not fire)
    void OnApplicationPause(bool paused)
    {
        if (paused)
            _ = PerformAutoSave();
    }

    void OnApplicationQuit()
    {
        // Synchronous save on quit (async may not complete)
        var data = GatherSaveData();
        SaveFileIO.SaveJson(data, "autosave.json");
    }

    async Awaitable PerformAutoSave()
    {
        try
        {
            await Awaitable.BackgroundThreadAsync();
            var data = GatherSaveData();
            SaveFileIO.SaveJson(data, "autosave.json");
            await Awaitable.MainThreadAsync();
        }
        catch (Exception e)
        {
            Debug.LogError($"Auto-save failed: {e.Message}");
        }
    }

    GameSaveData GatherSaveData()
    {
        var data = new GameSaveData();
        // Gather from all ISaveable systems
        return data;
    }
}
```

GOTCHA: Saving is I/O-bound. On mobile, use `OnApplicationPause(true)` -- `OnApplicationQuit` may not fire when the OS kills the app. In `OnApplicationQuit`, use synchronous I/O (async may not complete before the process exits). Never save in `Update` synchronously -- use `BackgroundThreadAsync` or a timer. Cross-ref: `unity-lifecycle` covers the quit sequence.

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `BinaryFormatter` | Security vulnerability, deprecated | Use JsonUtility or Newtonsoft |
| Game state in PlayerPrefs | No structure, no versioning, key collision | Use JSON files + `persistentDataPath` |
| Saving MonoBehaviour directly | Not serializable, couples save to scene | Use plain C# DTOs with `[Serializable]` |
| No version field in save data | Cannot migrate when format changes | Always include `int version` |
| Synchronous save in Update | Frame hitches, especially on mobile | Use `BackgroundThreadAsync` or timer |
| No backup/atomic write | Crash during write corrupts save | Write to .tmp, rename atomically |

## Related Skills

- **unity-lifecycle** -- OnApplicationPause, OnApplicationQuit, quit sequence timing
- **unity-packages-services** -- Unity Cloud Save API (do not duplicate)
- **unity-async-patterns** -- BackgroundThreadAsync for async I/O
- **unity-data-driven** -- JsonUtility vs Newtonsoft, versioning patterns for config data

## Additional Resources

- [Application.persistentDataPath](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Application-persistentDataPath.html)
- [JsonUtility](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/JsonUtility.html)
- [PlayerPrefs](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/PlayerPrefs.html)
- [Unity Cloud Save](https://docs.unity.com/ugs/manual/cloud-save/manual)
