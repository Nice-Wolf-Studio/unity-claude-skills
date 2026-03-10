# GameObject, Component, and Transform API Reference

> Based on Unity 6.3 documentation

## GameObject

### What It Is

The GameObject is the most important concept in the Unity Editor. Every object in a scene is a GameObject: characters, props, scenery, cameras, waypoints, and lights. GameObjects are containers that require Components to gain functionality. Every GameObject automatically includes a Transform component that cannot be removed.

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | The name of the GameObject |
| `tag` | `string` | The tag assigned to this GameObject |
| `layer` | `int` | The layer index (0-31) |
| `activeSelf` | `bool` | The local active state of this GameObject |
| `activeInHierarchy` | `bool` | Whether this GameObject is active considering its parent chain |
| `transform` | `Transform` | The Transform attached to this GameObject |
| `scene` | `Scene` | The Scene this GameObject belongs to |
| `isStatic` | `bool` | Whether this GameObject is marked as static |

### Instance Methods

#### GetComponent / AddComponent / Destroy

```csharp
using UnityEngine;

public class ComponentManagement : MonoBehaviour
{
    void Start()
    {
        // GetComponent -- retrieve an existing component
        Rigidbody rb = GetComponent<Rigidbody>();
        if (rb != null)
        {
            rb.mass = 2f;
        }

        // TryGetComponent -- safer pattern, no null-ref risk in chaining
        if (TryGetComponent<Collider>(out Collider col))
        {
            col.enabled = false;
        }

        // GetComponentInChildren -- searches this object and all descendants
        AudioSource audio = GetComponentInChildren<AudioSource>();

        // GetComponentInParent -- searches this object and all ancestors
        Canvas canvas = GetComponentInParent<Canvas>();

        // GetComponentsInChildren -- returns all matching components
        MeshRenderer[] renderers = GetComponentsInChildren<MeshRenderer>();

        // AddComponent -- attach a new component at runtime
        BoxCollider box = gameObject.AddComponent<BoxCollider>();
        box.size = new Vector3(2, 2, 2);

        // Destroy a component (deferred to end of frame)
        Destroy(box);

        // DestroyImmediate -- use only in Editor scripts, never in gameplay
        // DestroyImmediate(box); // Editor only!
    }
}
```

#### SetActive

```csharp
using UnityEngine;

public class ActivationPatterns : MonoBehaviour
{
    public GameObject targetObject;

    void Example()
    {
        // Deactivate: disables all components, stops Update/rendering
        targetObject.SetActive(false);

        // Check local state (ignores parent)
        bool selfActive = targetObject.activeSelf;

        // Check effective state (considers entire parent chain)
        // A child is inactive in hierarchy if any ancestor is inactive
        bool inHierarchy = targetObject.activeInHierarchy;

        // Reactivate
        targetObject.SetActive(true);
    }
}
```

**Important behavior**: When a parent GameObject is deactivated, all children become inactive in the hierarchy (`activeInHierarchy` returns false) even if their own `activeSelf` is true. When the parent is reactivated, children return to their own active state.

### Static Methods for Finding GameObjects

```csharp
using UnityEngine;

public class FindPatterns : MonoBehaviour
{
    void Start()
    {
        // FindWithTag -- returns the FIRST active GameObject with tag
        GameObject player = GameObject.FindWithTag("Player");

        // FindGameObjectsWithTag -- returns ALL active GameObjects with tag
        GameObject[] respawnPoints = GameObject.FindGameObjectsWithTag("Respawn");

        // Find by name -- searches entire hierarchy (SLOW)
        // Avoid in Update or performance-critical code
        GameObject manager = GameObject.Find("GameManager");

        // Find by name supports path syntax
        GameObject child = GameObject.Find("ParentName/ChildName");

        // FindObjectOfType -- finds first instance of a component type
        Camera mainCam = FindObjectOfType<Camera>();

        // FindObjectsOfType -- finds all instances
        Light[] allLights = FindObjectsOfType<Light>();
    }
}
```

#### CompareTag (Preferred Over String Comparison)

```csharp
using UnityEngine;

public class TagComparison : MonoBehaviour
{
    void OnTriggerEnter(Collider other)
    {
        // GOOD: CompareTag -- no GC allocation
        if (other.CompareTag("Player"))
        {
            Debug.Log("Player entered trigger");
        }

        // BAD: String comparison allocates memory
        // if (other.tag == "Player") { }  // Avoid this
    }
}
```

### Creating and Destroying GameObjects

```csharp
using UnityEngine;

public class GameObjectLifecycle : MonoBehaviour
{
    public GameObject prefab;

    void Example()
    {
        // Create empty GameObject
        GameObject empty = new GameObject("EmptyObject");

        // Create with components
        GameObject withComponents = new GameObject("WithComponents",
            typeof(Rigidbody), typeof(BoxCollider));

        // Instantiate from prefab
        GameObject instance = Instantiate(prefab, Vector3.zero, Quaternion.identity);

        // Instantiate as child
        GameObject child = Instantiate(prefab, transform);

        // Destroy (deferred to end of frame)
        Destroy(instance);

        // Destroy after delay
        Destroy(child, 5f);

        // Persist across scene loads
        DontDestroyOnLoad(gameObject);
    }
}
```

---

## Transform

### What It Is

The Transform component stores position, rotation, and scale of a GameObject. Every GameObject has exactly one Transform. Transforms form parent-child hierarchies: a child's values are relative to its parent (local space).

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `position` | `Vector3` | World-space position |
| `localPosition` | `Vector3` | Position relative to parent |
| `rotation` | `Quaternion` | World-space rotation |
| `localRotation` | `Quaternion` | Rotation relative to parent |
| `eulerAngles` | `Vector3` | World rotation in degrees |
| `localEulerAngles` | `Vector3` | Local rotation in degrees |
| `localScale` | `Vector3` | Scale relative to parent |
| `lossyScale` | `Vector3` | Read-only approximate world scale |
| `parent` | `Transform` | The parent transform (null if root) |
| `root` | `Transform` | The topmost transform in the hierarchy |
| `childCount` | `int` | Number of direct children |
| `forward` | `Vector3` | World-space forward direction (blue axis) |
| `right` | `Vector3` | World-space right direction (red axis) |
| `up` | `Vector3` | World-space up direction (green axis) |

### Movement and Rotation

```csharp
using UnityEngine;

public class TransformMovement : MonoBehaviour
{
    public float speed = 5f;
    public float rotSpeed = 90f;

    void Update()
    {
        // Translate in local space (relative to object's own axes)
        transform.Translate(Vector3.forward * speed * Time.deltaTime);

        // Translate in world space
        transform.Translate(Vector3.up * speed * Time.deltaTime, Space.World);

        // Set world position directly
        transform.position = new Vector3(10, 0, 5);

        // Rotate around local Y axis
        transform.Rotate(Vector3.up, rotSpeed * Time.deltaTime);

        // Rotate around world axis
        transform.Rotate(Vector3.up, rotSpeed * Time.deltaTime, Space.World);

        // Look at a target
        Transform target = GameObject.FindWithTag("Player")?.transform;
        if (target != null)
        {
            transform.LookAt(target);
        }

        // Rotate around a point
        transform.RotateAround(Vector3.zero, Vector3.up, 20f * Time.deltaTime);
    }
}
```

### Parent-Child Hierarchy

```csharp
using UnityEngine;

public class HierarchyManagement : MonoBehaviour
{
    public Transform parentTarget;

    void Example()
    {
        // Set parent (preserves world position by default)
        transform.SetParent(parentTarget);

        // Set parent without preserving world position
        // (keeps local position/rotation/scale unchanged)
        transform.SetParent(parentTarget, worldPositionStays: false);

        // Unparent
        transform.SetParent(null);

        // Detach all children
        transform.DetachChildren();

        // Iterate children
        for (int i = 0; i < transform.childCount; i++)
        {
            Transform child = transform.GetChild(i);
            Debug.Log(child.name);
        }

        // Find child by name
        Transform found = transform.Find("ChildName");

        // Set sibling order (affects rendering/UI order)
        transform.SetAsFirstSibling();
        transform.SetAsLastSibling();
        transform.SetSiblingIndex(2);
    }
}
```

### Coordinate Space Conversion

```csharp
using UnityEngine;

public class CoordinateConversion : MonoBehaviour
{
    void Example()
    {
        // Convert local point to world space
        Vector3 worldPoint = transform.TransformPoint(new Vector3(0, 1, 0));

        // Convert world point to local space
        Vector3 localPoint = transform.InverseTransformPoint(worldPoint);

        // Convert local direction to world space
        Vector3 worldDir = transform.TransformDirection(Vector3.forward);

        // Convert world direction to local space
        Vector3 localDir = transform.InverseTransformDirection(worldDir);

        // Convert local vector (affected by scale) to world space
        Vector3 worldVec = transform.TransformVector(Vector3.one);
    }
}
```

### Scale Warnings (From the Docs)

Three factors influence a GameObject's scale:
1. Mesh size in 3D modeling software
2. Mesh Scale Factor in Import Settings
3. Transform Scale values

From the docs: "Don't adjust the Scale of your GameObject in the Transform component." Instead, create models at real-life scale. Non-uniform scaling (e.g., 2, 4, 2) causes:
- Some components to behave incorrectly (Colliders, Lights, Audio Sources)
- Rotated children to appear skewed
- Performance degradation on instantiation

The physics engine assumes 1 unit = 1 meter. Improperly scaled objects may appear to fall in slow motion.

---

## Source Documentation

- [GameObjects](https://docs.unity3d.com/6000.3/Documentation/Manual/GameObjects.html)
- [Components](https://docs.unity3d.com/6000.3/Documentation/Manual/Components.html)
- [Transform](https://docs.unity3d.com/6000.3/Documentation/Manual/class-Transform.html)
