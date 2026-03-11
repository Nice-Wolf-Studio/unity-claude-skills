# Save/Load Implementation Reference

Complete implementations for save management, ISaveable pattern, and migration. Supplements the DECISION blocks in the parent SKILL.md.

## Complete SaveManager

```csharp
using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

/// <summary>
/// Central save manager. Coordinates ISaveable systems, handles slots,
/// and manages the save/load lifecycle.
/// </summary>
public class SaveManager : MonoBehaviour
{
    [SerializeField] private int maxSlots = 3;

    private readonly List<ISaveable> _saveables = new();

    public static SaveManager Instance { get; private set; }

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() => Instance = null;

    // --- Registration ---

    public void Register(ISaveable saveable) => _saveables.Add(saveable);
    public void Unregister(ISaveable saveable) => _saveables.Remove(saveable);

    // --- Save ---

    public void Save(int slot = 0)
    {
        if (slot < 0 || slot >= maxSlots)
            throw new ArgumentOutOfRangeException(nameof(slot));

        var data = GatherData();
        data.timestamp = DateTime.UtcNow.ToString("o");

        string json = JsonUtility.ToJson(data, prettyPrint: true);
        string path = GetSlotPath(slot);

        // Atomic write: temp file -> rename
        string tempPath = path + ".tmp";
        File.WriteAllText(tempPath, json);

        if (File.Exists(path))
            File.Replace(tempPath, path, path + ".bak");
        else
            File.Move(tempPath, path);

        Debug.Log($"Game saved to slot {slot}");
    }

    // --- Load ---

    public bool Load(int slot = 0)
    {
        string path = GetSlotPath(slot);
        if (!File.Exists(path))
        {
            Debug.LogWarning($"No save found in slot {slot}");
            return false;
        }

        try
        {
            string json = File.ReadAllText(path);
            var data = SaveMigrator.LoadAndMigrate(json);
            ApplyData(data);
            Debug.Log($"Game loaded from slot {slot}");
            return true;
        }
        catch (Exception e)
        {
            Debug.LogError($"Failed to load slot {slot}: {e.Message}");

            // Try backup
            string backupPath = path + ".bak";
            if (File.Exists(backupPath))
            {
                Debug.Log("Attempting to load from backup...");
                try
                {
                    string backupJson = File.ReadAllText(backupPath);
                    var backupData = SaveMigrator.LoadAndMigrate(backupJson);
                    ApplyData(backupData);
                    return true;
                }
                catch (Exception backupEx)
                {
                    Debug.LogError($"Backup also failed: {backupEx.Message}");
                }
            }
            return false;
        }
    }

    // --- Delete ---

    public void DeleteSlot(int slot)
    {
        string path = GetSlotPath(slot);
        if (File.Exists(path)) File.Delete(path);
        if (File.Exists(path + ".bak")) File.Delete(path + ".bak");
    }

    // --- Query ---

    public bool SlotExists(int slot) => File.Exists(GetSlotPath(slot));

    public SaveSlotInfo GetSlotInfo(int slot)
    {
        string path = GetSlotPath(slot);
        if (!File.Exists(path)) return null;

        string json = File.ReadAllText(path);
        var header = JsonUtility.FromJson<SaveHeader>(json);
        return new SaveSlotInfo
        {
            Slot = slot,
            Timestamp = header.timestamp,
            Version = header.version
        };
    }

    // --- Internal ---

    GameSaveData GatherData()
    {
        var data = new GameSaveData();
        foreach (var saveable in _saveables)
            saveable.GatherSaveData(data);
        return data;
    }

    void ApplyData(GameSaveData data)
    {
        foreach (var saveable in _saveables)
            saveable.ApplySaveData(data);
    }

    string GetSlotPath(int slot) =>
        Path.Combine(Application.persistentDataPath, $"save_slot_{slot}.json");
}

// --- Supporting types ---

public interface ISaveable
{
    void GatherSaveData(GameSaveData data);
    void ApplySaveData(GameSaveData data);
}

[System.Serializable]
public class SaveHeader
{
    public int version;
    public string timestamp;
}

public class SaveSlotInfo
{
    public int Slot;
    public string Timestamp;
    public int Version;
}
```

---

## ISaveable Implementation Examples

### Player System

```csharp
public class PlayerSaveSystem : MonoBehaviour, ISaveable
{
    [SerializeField] private Transform playerTransform;

    private HealthSystem _health;
    private int _level;
    private int _xp;

    void OnEnable() => SaveManager.Instance?.Register(this);
    void OnDisable() => SaveManager.Instance?.Unregister(this);

    public void GatherSaveData(GameSaveData data)
    {
        data.player = new PlayerSaveData();
        data.player.FromPlayer(playerTransform, _health.Current, _level, _xp);
    }

    public void ApplySaveData(GameSaveData data)
    {
        if (data.player == null) return;
        playerTransform.position = data.player.GetPosition();
        _health.SetHealth(data.player.health);
        _level = data.player.level;
        _xp = data.player.xp;
    }
}
```

### Inventory System

```csharp
public class InventorySaveSystem : MonoBehaviour, ISaveable
{
    private Inventory _inventory;

    void OnEnable() => SaveManager.Instance?.Register(this);
    void OnDisable() => SaveManager.Instance?.Unregister(this);

    public void GatherSaveData(GameSaveData data)
    {
        data.inventory = new InventorySaveData
        {
            items = _inventory.Items.Select(item => new ItemSaveData
            {
                itemId = item.Config.name,  // SO asset name as ID
                quantity = item.Quantity,
                slotIndex = item.SlotIndex
            }).ToArray()
        };
    }

    public void ApplySaveData(GameSaveData data)
    {
        if (data.inventory?.items == null) return;
        _inventory.Clear();
        foreach (var itemData in data.inventory.items)
        {
            var config = Resources.Load<ItemConfig>($"Items/{itemData.itemId}");
            if (config != null)
                _inventory.AddItem(config, itemData.quantity, itemData.slotIndex);
        }
    }
}
```

---

## Save Data DTO Structure

```csharp
[System.Serializable]
public class GameSaveData
{
    public int version = 3;
    public string timestamp;
    public PlayerSaveData player = new();
    public InventorySaveData inventory = new();
    public WorldSaveData world = new();
    public QuestSaveData quests = new();
}

[System.Serializable]
public class PlayerSaveData
{
    public float[] position = new float[3];
    public int health;
    public int level;
    public int xp;

    public void FromPlayer(Transform t, int hp, int lvl, int experience)
    {
        position[0] = t.position.x;
        position[1] = t.position.y;
        position[2] = t.position.z;
        health = hp; level = lvl; xp = experience;
    }

    public Vector3 GetPosition() => new(position[0], position[1], position[2]);
}

[System.Serializable]
public class InventorySaveData
{
    public ItemSaveData[] items = Array.Empty<ItemSaveData>();
}

[System.Serializable]
public class ItemSaveData
{
    public string itemId;
    public int quantity;
    public int slotIndex;
}

[System.Serializable]
public class WorldSaveData
{
    public string currentScene;
    public string[] unlockedAreas = Array.Empty<string>();
    public string[] destroyedObjects = Array.Empty<string>();
}

[System.Serializable]
public class QuestSaveData
{
    public QuestEntry[] activeQuests = Array.Empty<QuestEntry>();
    public string[] completedQuestIds = Array.Empty<string>();
}

[System.Serializable]
public class QuestEntry
{
    public string questId;
    public int currentStep;
    public int[] objectiveProgress;
}
```

---

## Async Save Pattern

```csharp
public async Awaitable SaveAsync(int slot, CancellationToken token = default)
{
    var data = GatherData();
    data.timestamp = DateTime.UtcNow.ToString("o");
    string json = JsonUtility.ToJson(data, prettyPrint: true);
    string path = GetSlotPath(slot);

    // Write on background thread to avoid frame hitch
    await Awaitable.BackgroundThreadAsync();
    token.ThrowIfCancellationRequested();

    string tempPath = path + ".tmp";
    await File.WriteAllTextAsync(tempPath, json, token);

    if (File.Exists(path))
        File.Replace(tempPath, path, path + ".bak");
    else
        File.Move(tempPath, path);

    await Awaitable.MainThreadAsync();
    Debug.Log($"Async save to slot {slot} complete");
}
```

---

## PlayerPrefs Wrapper (Complete)

```csharp
using System;
using UnityEngine;

/// <summary>
/// Type-safe PlayerPrefs wrapper with change events and default values.
/// Use for application settings only, not game save data.
/// </summary>
public static class GameSettings
{
    private const string P = "settings."; // Key prefix

    // --- Audio ---
    public static float MasterVolume
    {
        get => PlayerPrefs.GetFloat(P + "audio.master", 1f);
        set => SetFloat(P + "audio.master", value);
    }

    public static float MusicVolume
    {
        get => PlayerPrefs.GetFloat(P + "audio.music", 0.8f);
        set => SetFloat(P + "audio.music", value);
    }

    public static float SFXVolume
    {
        get => PlayerPrefs.GetFloat(P + "audio.sfx", 1f);
        set => SetFloat(P + "audio.sfx", value);
    }

    // --- Video ---
    public static bool Fullscreen
    {
        get => PlayerPrefs.GetInt(P + "video.fullscreen", 1) == 1;
        set => SetBool(P + "video.fullscreen", value);
    }

    public static int QualityLevel
    {
        get => PlayerPrefs.GetInt(P + "video.quality", QualitySettings.GetQualityLevel());
        set => SetInt(P + "video.quality", value);
    }

    // --- Accessibility ---
    public static float UIScale
    {
        get => PlayerPrefs.GetFloat(P + "a11y.uiScale", 1f);
        set => SetFloat(P + "a11y.uiScale", value);
    }

    public static bool Subtitles
    {
        get => PlayerPrefs.GetInt(P + "a11y.subtitles", 1) == 1;
        set => SetBool(P + "a11y.subtitles", value);
    }

    // --- Events ---
    public static event Action OnChanged;

    // --- Helpers ---
    static void SetFloat(string key, float val) { PlayerPrefs.SetFloat(key, val); OnChanged?.Invoke(); }
    static void SetInt(string key, int val) { PlayerPrefs.SetInt(key, val); OnChanged?.Invoke(); }
    static void SetBool(string key, bool val) { PlayerPrefs.SetInt(key, val ? 1 : 0); OnChanged?.Invoke(); }

    public static void Save() => PlayerPrefs.Save();

    public static void ResetAll()
    {
        // Only delete our prefixed keys -- don't nuke everything
        PlayerPrefs.DeleteKey(P + "audio.master");
        PlayerPrefs.DeleteKey(P + "audio.music");
        PlayerPrefs.DeleteKey(P + "audio.sfx");
        PlayerPrefs.DeleteKey(P + "video.fullscreen");
        PlayerPrefs.DeleteKey(P + "video.quality");
        PlayerPrefs.DeleteKey(P + "a11y.uiScale");
        PlayerPrefs.DeleteKey(P + "a11y.subtitles");
        OnChanged?.Invoke();
    }
}
```

---

## BinaryFormatter Replacement Guide

If you have existing code using `BinaryFormatter`:

```csharp
// BEFORE (DANGEROUS -- remove immediately)
// BinaryFormatter bf = new BinaryFormatter();
// bf.Serialize(stream, data);  // Arbitrary code execution vulnerability
// var loaded = (SaveData)bf.Deserialize(stream);

// AFTER (JSON -- safe)
string json = JsonUtility.ToJson(data);
File.WriteAllText(path, json);
var loaded = JsonUtility.FromJson<SaveData>(json);

// AFTER (Newtonsoft -- safe, more features)
string json = Newtonsoft.Json.JsonConvert.SerializeObject(data);
File.WriteAllText(path, json);
var loaded = Newtonsoft.Json.JsonConvert.DeserializeObject<SaveData>(json);
```

**Migration from BinaryFormatter saves:**
1. Load existing save with `BinaryFormatter` (one last time)
2. Convert to JSON format
3. Save in new JSON format
4. Delete old binary save
5. Remove all `BinaryFormatter` references from code

This requires keeping `BinaryFormatter` code temporarily for migration, then removing it completely.
