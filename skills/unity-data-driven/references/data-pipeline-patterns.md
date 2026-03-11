# Data Pipeline Patterns Reference

Detailed implementations for data import, serialization, and cross-platform loading. Supplements the DECISION blocks in the parent SKILL.md.

## JsonUtility vs Newtonsoft JSON

| Feature | `JsonUtility` (built-in) | `Newtonsoft.Json` (package) |
|---------|------------------------|---------------------------|
| **Package** | Built into Unity | `com.unity.nuget.newtonsoft-json` |
| **Performance** | Fast (native C++) | Slower (managed C#) |
| **Dictionaries** | Not supported | Supported |
| **Top-level arrays** | Not supported (need wrapper) | Supported |
| **Polymorphism** | Not supported | `TypeNameHandling` |
| **Null values** | Uses type default | Preserves null |
| **Properties** | Not supported (fields only) | Supported |
| **Custom converters** | Not supported | `JsonConverter` |
| **Formatting** | `prettyPrint` param | `Formatting.Indented` |
| **LINQ-to-JSON** | Not supported | `JObject`, `JArray` |
| **Unity types** | `Vector3`, `Color`, etc. | Need custom converter |
| **Allocation** | Lower | Higher |
| **Best for** | Simple data, performance | Complex data, flexibility |

### JsonUtility Examples

```csharp
// Serialize
string json = JsonUtility.ToJson(data, prettyPrint: true);

// Deserialize
MyData data = JsonUtility.FromJson<MyData>(json);

// Overwrite existing object (avoids allocation)
JsonUtility.FromJsonOverwrite(json, existingObject);

// Top-level array workaround
[System.Serializable]
public class EnemyList
{
    public EnemyData[] enemies; // Wrap array in a class
}
string json = "{\"enemies\":[{...},{...}]}";
var list = JsonUtility.FromJson<EnemyList>(json);
```

### Newtonsoft JSON Examples

```csharp
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

// Serialize with formatting
string json = JsonConvert.SerializeObject(data, Formatting.Indented);

// Deserialize
MyData data = JsonConvert.DeserializeObject<MyData>(json);

// Dictionaries (not supported by JsonUtility)
var dict = JsonConvert.DeserializeObject<Dictionary<string, int>>(json);

// LINQ-to-JSON for migration/inspection
JObject jObj = JObject.Parse(json);
int version = (int)jObj["version"];
string name = (string)jObj["player"]["name"];

// Custom converter for Unity types
public class Vector3Converter : JsonConverter<Vector3>
{
    public override Vector3 ReadJson(JsonReader reader, Type type, Vector3 existing,
        bool hasExisting, JsonSerializer serializer)
    {
        JObject obj = JObject.Load(reader);
        return new Vector3((float)obj["x"], (float)obj["y"], (float)obj["z"]);
    }

    public override void WriteJson(JsonWriter writer, Vector3 value, JsonSerializer serializer)
    {
        writer.WriteStartObject();
        writer.WritePropertyName("x"); writer.WriteValue(value.x);
        writer.WritePropertyName("y"); writer.WriteValue(value.y);
        writer.WritePropertyName("z"); writer.WriteValue(value.z);
        writer.WriteEndObject();
    }
}

// Register converter
var settings = new JsonSerializerSettings();
settings.Converters.Add(new Vector3Converter());
string json = JsonConvert.SerializeObject(data, settings);
```

---

## CSV-to-ScriptableObject Editor Import Script

```csharp
#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.IO;

public class EnemyDataImporter : EditorWindow
{
    private TextAsset csvFile;
    private string outputFolder = "Assets/Data/Enemies";

    [MenuItem("Tools/Import Enemy Data from CSV")]
    static void ShowWindow()
    {
        GetWindow<EnemyDataImporter>("Enemy Importer");
    }

    void OnGUI()
    {
        csvFile = (TextAsset)EditorGUILayout.ObjectField("CSV File", csvFile, typeof(TextAsset), false);
        outputFolder = EditorGUILayout.TextField("Output Folder", outputFolder);

        if (GUILayout.Button("Import") && csvFile != null)
        {
            ImportCSV();
        }
    }

    void ImportCSV()
    {
        if (!Directory.Exists(outputFolder))
            Directory.CreateDirectory(outputFolder);

        string[] lines = csvFile.text.Split('\n');
        string[] headers = lines[0].Trim().Split(',');

        int created = 0;
        for (int i = 1; i < lines.Length; i++)
        {
            string line = lines[i].Trim();
            if (string.IsNullOrEmpty(line)) continue;

            string[] values = line.Split(',');
            if (values.Length < headers.Length) continue;

            // Create or load existing SO
            string assetName = values[0].Trim();
            string assetPath = $"{outputFolder}/{assetName}.asset";

            var config = AssetDatabase.LoadAssetAtPath<EnemyConfig>(assetPath);
            if (config == null)
            {
                config = ScriptableObject.CreateInstance<EnemyConfig>();
                AssetDatabase.CreateAsset(config, assetPath);
            }

            // Map CSV columns to SO fields
            config.maxHealth = int.Parse(values[1]);
            config.moveSpeed = float.Parse(values[2]);
            config.attackDamage = float.Parse(values[3]);
            config.detectionRange = float.Parse(values[4]);
            config.xpReward = int.Parse(values[5]);

            EditorUtility.SetDirty(config);
            created++;
        }

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log($"Imported {created} enemy configs from CSV");
    }
}
#endif
```

### Expected CSV Format

```csv
Name,MaxHealth,MoveSpeed,AttackDamage,DetectionRange,XPReward
Skeleton,50,3.5,8,12,15
Goblin,30,5.0,5,10,10
Dragon,500,2.0,50,30,200
```

---

## StreamingAssets Cross-Platform Loading

```csharp
using UnityEngine;
using UnityEngine.Networking;
using System.IO;
using System.Threading.Tasks;

public static class StreamingAssetsLoader
{
    /// <summary>
    /// Load a text file from StreamingAssets, handling platform differences.
    /// </summary>
    public static async Awaitable<string> LoadTextAsync(string fileName)
    {
        string path = Path.Combine(Application.streamingAssetsPath, fileName);

        #if UNITY_ANDROID && !UNITY_EDITOR
        // Android: files are inside the APK (compressed)
        // Must use UnityWebRequest to access them
        using var request = UnityWebRequest.Get(path);
        var op = request.SendWebRequest();
        while (!op.isDone) await Awaitable.NextFrameAsync();

        if (request.result != UnityWebRequest.Result.Success)
            throw new FileNotFoundException($"Failed to load {fileName}: {request.error}");

        return request.downloadHandler.text;

        #elif UNITY_WEBGL && !UNITY_EDITOR
        // WebGL: also requires UnityWebRequest
        using var request = UnityWebRequest.Get(path);
        var op = request.SendWebRequest();
        while (!op.isDone) await Awaitable.NextFrameAsync();

        if (request.result != UnityWebRequest.Result.Success)
            throw new FileNotFoundException($"Failed to load {fileName}: {request.error}");

        return request.downloadHandler.text;

        #else
        // Standalone, iOS, Editor: direct file access works
        if (!File.Exists(path))
            throw new FileNotFoundException($"File not found: {path}");

        return await File.ReadAllTextAsync(path);
        #endif
    }
}
```

### Platform Path Reference

| Platform | `streamingAssetsPath` | Writable? | Access Method |
|----------|----------------------|-----------|---------------|
| Windows | `<exe>/Data/StreamingAssets` | No | `File.Read` |
| macOS | `<app>/Contents/Resources/Data/StreamingAssets` | No | `File.Read` |
| Linux | `<exe>/Data/StreamingAssets` | No | `File.Read` |
| Android | `jar:file://<apk>!/assets` | No | `UnityWebRequest` |
| iOS | `<app>/Data/Raw` | No | `File.Read` |
| WebGL | `<url>/StreamingAssets` | No | `UnityWebRequest` |

### Where to Write Data

| Need | Path | API |
|------|------|-----|
| Save files | `Application.persistentDataPath` | `File.Write` |
| Temp files | `Application.temporaryCachePath` | `File.Write` |
| Read-only data | `Application.streamingAssetsPath` | See above |
| Built-in resources | `Application.dataPath` | Read-only in builds |

---

## SO Inheritance vs Composition Side-by-Side

### Inheritance Approach

```
EnemyConfig (abstract)
  ├── maxHealth, moveSpeed
  │
  ├── MeleeEnemyConfig
  │     └── meleeDamage, attackRadius
  │
  ├── RangedEnemyConfig
  │     └── projectileDamage, fireRange, projectilePrefab
  │
  └── BossEnemyConfig
        └── phase2Config, enrageThreshold
```

**Pros:** Type-safe, each subtype is its own asset type, clear IS-A relationship.
**Cons:** Cannot combine (melee + ranged hybrid), base fields always visible, deep hierarchies get messy.

### Composition Approach

```
EnemyConfig
  ├── displayName, maxHealth, xpReward
  ├── MovementConfig (struct)
  │     └── speed, canFly, flyHeight
  ├── MeleeConfig (struct, optional)
  │     └── damage, radius
  ├── RangedConfig (struct, optional)
  │     └── damage, range, projectile
  └── BossConfig (struct, optional)
        └── phases[], enrageThreshold
```

**Pros:** Mix-and-match (melee + ranged), single asset type, flat hierarchy.
**Cons:** All fields visible (unused ones clutter Inspector), need custom editor for conditional display.

### Recommendation

Use **composition** as the default. Switch to **inheritance** only when subtypes are truly distinct with no overlap (e.g., `WeaponConfig` vs `ArmorConfig` vs `ConsumableConfig` -- these are different item categories, not variations).
