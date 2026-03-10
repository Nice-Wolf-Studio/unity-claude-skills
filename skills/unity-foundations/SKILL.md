---
name: unity-foundations
description: >
  Unity 6 core concepts and architecture guide. Use when working with GameObjects, Components, Transforms, Scenes, Prefabs, ScriptableObjects, or Unity project structure. Covers the entity-component architecture, object hierarchy, tags, layers, and project conventions. Based on Unity 6.3 LTS documentation.
---

# Unity Foundations

## Core Concepts

### GameObjects

GameObjects are the fundamental building blocks in Unity. Every object in a scene -- characters, props, scenery, cameras, lights -- is a GameObject. GameObjects are containers: they cannot function alone and require **Components** to gain functionality. Every GameObject automatically includes a **Transform** component that cannot be removed.

### Components

Components are the functional pieces of every GameObject. Unity uses a **composition-over-inheritance** architecture: you build behavior by attaching multiple components to a GameObject rather than inheriting from deep class hierarchies. Each GameObject must have exactly one Transform component. Additional components (Rigidbody, Collider, MeshRenderer, custom MonoBehaviours) define what the object does.

Constraints from the docs:
- Components must reside in the same project as their target GameObject
- Components cannot be sourced from separate projects, unattached scripts, or uninstalled packages

### Transforms

The Transform component stores **position**, **rotation**, and **scale** -- each relative to the parent (local coordinates) or to the world origin (world coordinates). Key points from the docs:

- Child Transforms display values relative to their parent
- Root GameObjects (no parent) show world coordinates
- The physics engine assumes 1 unit = 1 meter
- Set parent location to `(0,0,0)` before adding children so local coords match global coords
- Avoid adjusting Transform Scale at runtime; model assets at real-life scale instead. Non-uniform scaling causes issues with Colliders, Lights, and Audio Sources

### Scenes

Scenes are assets that contain all or part of a game or application. A default new scene includes a Camera and a directional Light. Projects can use a single scene or multiple scenes (e.g., one per level). Scene Templates serve as blueprints for creating new scenes.

### Prefabs

Prefabs are reusable asset templates that store a complete GameObject configuration (all components, property values, and child GameObjects). Key features:
- **Nested Prefabs**: Include prefab instances within other prefabs
- **Prefab Variants**: Create predefined variations that maintain a base prefab relationship
- **Overrides**: Modify components/data on specific instances without affecting the template
- **Unpacking**: Convert prefab instances back to standalone GameObjects

### ScriptableObjects

ScriptableObject is a serializable Unity type derived from `UnityEngine.Object` that serves as a data container independent of GameObjects. Unlike MonoBehaviours, ScriptableObjects exist as project-level `.asset` files. Primary use cases:
- Shared data containers (reduces memory by referencing one asset instead of duplicating data across prefabs)
- Editor tool foundations (EditorTool, EditorWindow derive from ScriptableObject)
- Runtime configuration storage

**Critical**: Unity does not automatically save changes to a ScriptableObject made via script in Edit mode. You must call `EditorUtility.SetDirty()` after modifications.

### Tags

Tags are reference identifiers assigned to GameObjects for scripting purposes. Each GameObject can have only one tag, but multiple GameObjects can share the same tag. Built-in tags: `Untagged`, `Respawn`, `Finish`, `EditorOnly`, `MainCamera`, `Player`, `GameController`.

- `MainCamera`: The Editor caches these; `Camera.main` returns the first valid result
- `EditorOnly`: GameObjects tagged this way are destroyed during builds
- Tag names cannot be renamed once created

### Layers

Layers separate GameObjects for selective processing including camera rendering, lighting, physics collisions, and custom code logic. Unity supports up to 32 layers. LayerMasks define which layers an API call interacts with.

---

## Common Patterns

### Creating and Accessing Components

```csharp
using UnityEngine;

public class ComponentAccess : MonoBehaviour
{
    void Start()
    {
        // Get a component on this GameObject
        Rigidbody rb = GetComponent<Rigidbody>();

        // Get a component on a child GameObject
        Collider childCollider = GetComponentInChildren<Collider>();

        // Get all components of a type on this and children
        MeshRenderer[] renderers = GetComponentsInChildren<MeshRenderer>();

        // Add a component at runtime
        BoxCollider box = gameObject.AddComponent<BoxCollider>();

        // Remove a component (destroys it)
        Destroy(box);
    }
}
```

### Finding GameObjects

```csharp
using UnityEngine;

public class FindingObjects : MonoBehaviour
{
    void Start()
    {
        // Find by tag (returns first match)
        GameObject player = GameObject.FindWithTag("Player");

        // Find all with tag
        GameObject[] enemies = GameObject.FindGameObjectsWithTag("Enemy");

        // Find by name (slow -- avoid in Update)
        GameObject manager = GameObject.Find("GameManager");

        // Compare tags efficiently (no GC allocation)
        if (gameObject.CompareTag("Player"))
        {
            Debug.Log("This is the player");
        }
    }
}
```

### Instantiating Prefabs

From the Unity docs example:

```csharp
using UnityEngine;

public class InstantiationExample : MonoBehaviour
{
    // Reference to the prefab. Drag a prefab into this field in the Inspector.
    public GameObject myPrefab;

    void Start()
    {
        // Instantiate at position (0, 0, 0) and zero rotation.
        Instantiate(myPrefab, new Vector3(0, 0, 0), Quaternion.identity);
    }
}
```

### Instantiating with Parent Transform

```csharp
using UnityEngine;

public class SpawnWithParent : MonoBehaviour
{
    public GameObject prefab;
    public Transform parentTransform;

    void SpawnChild()
    {
        // Instantiate as child of a parent transform
        GameObject instance = Instantiate(prefab, parentTransform);

        // Instantiate at specific world position under a parent
        GameObject positioned = Instantiate(
            prefab,
            new Vector3(5, 0, 0),
            Quaternion.identity,
            parentTransform
        );
    }
}
```

### ScriptableObject Data Container

From the Unity docs:

```csharp
using UnityEngine;

[CreateAssetMenu(fileName = "Data", menuName = "ScriptableObjects/SpawnData", order = 1)]
public class SpawnDataScriptableObject : ScriptableObject
{
    public GameObject prefab;
    public int count;
    public Vector3[] positions;
}
```

```csharp
using UnityEngine;

public class SpawnManager : MonoBehaviour
{
    public SpawnDataScriptableObject spawnData;

    void Start()
    {
        for (int i = 0; i < spawnData.count; i++)
        {
            Instantiate(spawnData.prefab, spawnData.positions[i], Quaternion.identity);
        }
    }
}
```

### Scene Management

```csharp
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneLoader : MonoBehaviour
{
    void Start()
    {
        // Subscribe to scene loaded event
        SceneManager.sceneLoaded += OnSceneLoaded;
    }

    void OnSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        Debug.Log("Loaded: " + scene.name);
    }

    public void LoadLevel(string sceneName)
    {
        // Load scene by name (replaces current)
        SceneManager.LoadScene(sceneName);
    }

    public void LoadAdditive(string sceneName)
    {
        // Load scene additively (keeps current scenes)
        SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
    }

    public void UnloadLevel(string sceneName)
    {
        SceneManager.UnloadSceneAsync(sceneName);
    }

    public void GetSceneInfo()
    {
        Scene active = SceneManager.GetActiveScene();
        Debug.Log("Active scene: " + active.name);
        Debug.Log("Loaded scene count: " + SceneManager.loadedSceneCount);
    }
}
```

### Tag-Based Spawning

From the Unity docs example:

```csharp
using UnityEngine;

public class RespawnSystem : MonoBehaviour
{
    public GameObject respawnPrefab;
    private GameObject respawn;

    void Update()
    {
        if (respawn == null)
            respawn = GameObject.FindWithTag("Respawn");

        if (respawn != null)
        {
            Instantiate(respawnPrefab, respawn.transform.position,
                respawn.transform.rotation);
        }
    }
}
```

### Activating and Deactivating GameObjects

```csharp
using UnityEngine;

public class ToggleVisibility : MonoBehaviour
{
    public GameObject target;

    public void Toggle()
    {
        // SetActive controls whether the GameObject is active
        target.SetActive(!target.activeSelf);

        // activeSelf: this object's own active state
        // activeInHierarchy: effective state (considers parent chain)
        Debug.Log("Self: " + target.activeSelf);
        Debug.Log("InHierarchy: " + target.activeInHierarchy);
    }
}
```

### Layer Masks for Raycasting

```csharp
using UnityEngine;

public class LayerRaycast : MonoBehaviour
{
    void Update()
    {
        // Create a layer mask for layer named "Ground"
        int groundLayer = LayerMask.NameToLayer("Ground");
        int layerMask = 1 << groundLayer;

        // Raycast only against the Ground layer
        if (Physics.Raycast(transform.position, Vector3.down, out RaycastHit hit, 100f, layerMask))
        {
            Debug.Log("Hit ground at: " + hit.point);
        }

        // Use GetMask for multiple layers
        int combinedMask = LayerMask.GetMask("Ground", "Water");
        Physics.Raycast(transform.position, Vector3.forward, 50f, combinedMask);
    }
}
```

---

## Anti-Patterns

### 1. Using GameObject.Find in Update

```csharp
// BAD: Find is expensive -- runs every frame with string lookup
void Update()
{
    GameObject player = GameObject.Find("Player"); // Avoid!
}

// GOOD: Cache the reference
private GameObject player;
void Start()
{
    player = GameObject.FindWithTag("Player");
}
```

### 2. Non-Uniform Transform Scale

From the docs: "Don't adjust the Scale of your GameObject in the Transform component." Non-uniform scaling (e.g., 2, 4, 2) causes:
- Colliders, Lights, Audio Sources to behave incorrectly
- Rotated children to appear skewed
- Performance degradation when instantiating scaled objects

Model assets at real-life scale instead.

### 3. Duplicating Data Across Prefabs Instead of Using ScriptableObjects

```csharp
// BAD: Every prefab instance duplicates this data
public class EnemyStats : MonoBehaviour
{
    public int health = 100;
    public float speed = 5f;
    public string enemyName = "Goblin";
}

// GOOD: Use a ScriptableObject -- one asset, many references
[CreateAssetMenu(menuName = "ScriptableObjects/EnemyConfig")]
public class EnemyConfig : ScriptableObject
{
    public int health = 100;
    public float speed = 5f;
    public string enemyName = "Goblin";
}

public class Enemy : MonoBehaviour
{
    public EnemyConfig config; // All instances share the same asset
}
```

### 4. Forgetting EditorUtility.SetDirty for ScriptableObject Changes

```csharp
// BAD: Changes in Edit mode won't persist
settings.value += 10;

// GOOD: Mark asset dirty so Unity saves it
settings.value += 10;
EditorUtility.SetDirty(settings);
```

### 5. String-Based Tag Comparison

```csharp
// BAD: Allocates a new string for comparison (GC pressure)
if (gameObject.tag == "Player") { }

// GOOD: CompareTag avoids allocation
if (gameObject.CompareTag("Player")) { }
```

### 6. Ignoring Parent-Child Transform Relationships

Set a parent's location to `(0,0,0)` before adding children. Otherwise child local coordinates will not match global coordinates, causing confusion when positioning objects.

---

## Key API Quick Reference

| API | Description | Notes |
|-----|-------------|-------|
| `GetComponent<T>()` | Get component on same GameObject | Returns null if not found |
| `GetComponentInChildren<T>()` | Get component on self or children | Searches depth-first |
| `GetComponentsInChildren<T>()` | Get all matching components in hierarchy | Returns array |
| `AddComponent<T>()` | Attach new component at runtime | Returns the new component |
| `Destroy(obj)` | Destroy a GameObject or Component | Deferred to end of frame |
| `Instantiate(prefab, pos, rot)` | Clone a prefab at position/rotation | Returns the clone |
| `GameObject.FindWithTag(tag)` | Find first active GO with tag | Returns null if none |
| `GameObject.FindGameObjectsWithTag(tag)` | Find all active GOs with tag | Returns array |
| `GameObject.Find(name)` | Find by name (expensive) | Avoid in Update loops |
| `gameObject.SetActive(bool)` | Activate/deactivate | Disables all components |
| `gameObject.CompareTag(tag)` | Tag comparison without GC alloc | Preferred over `== tag` |
| `SceneManager.LoadScene(name)` | Load scene (replaces current) | Must be in Build Settings |
| `SceneManager.LoadSceneAsync(name, mode)` | Async scene loading | Additive or Single mode |
| `SceneManager.UnloadSceneAsync(name)` | Unload a loaded scene | Returns AsyncOperation |
| `SceneManager.GetActiveScene()` | Get current active scene | Returns Scene struct |
| `LayerMask.NameToLayer(name)` | Get layer index from name | Returns int |
| `LayerMask.GetMask(names)` | Get combined mask from layer names | Params string array |
| `Camera.main` | Get MainCamera-tagged camera | Cached by Unity |

---

## Related Skills

- **unity-scripting** -- C# scripting patterns, MonoBehaviour lifecycle, coroutines, events
- **unity-physics** -- Rigidbody, Colliders, physics layers, raycasting, triggers
- **unity-editor-tools** -- Custom inspectors, editor windows, gizmos, build pipeline

---

## Additional Resources

- [GameObjects](https://docs.unity3d.com/6000.3/Documentation/Manual/GameObjects.html)
- [Components](https://docs.unity3d.com/6000.3/Documentation/Manual/Components.html)
- [Transform](https://docs.unity3d.com/6000.3/Documentation/Manual/class-Transform.html)
- [Prefabs](https://docs.unity3d.com/6000.3/Documentation/Manual/Prefabs.html)
- [Scenes](https://docs.unity3d.com/6000.3/Documentation/Manual/CreatingScenes.html)
- [ScriptableObject](https://docs.unity3d.com/6000.3/Documentation/Manual/class-ScriptableObject.html)
- [Tags](https://docs.unity3d.com/6000.3/Documentation/Manual/Tags.html)
- [Layers](https://docs.unity3d.com/6000.3/Documentation/Manual/Layers.html)
- [Execution Order](https://docs.unity3d.com/6000.3/Documentation/Manual/execution-order.html)
- [SceneManager API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/SceneManagement.SceneManager.html)
