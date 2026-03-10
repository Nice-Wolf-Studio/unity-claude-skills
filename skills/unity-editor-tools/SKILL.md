---
name: unity-editor-tools
description: >
  Unity 6 editor scripting and custom tools guide. Use when creating custom inspectors, EditorWindows, PropertyDrawers, Gizmos, Handles, menu items, or editor extensions. Covers SerializedObject/SerializedProperty pattern, AssetDatabase, and editor-only code with #if UNITY_EDITOR. Based on Unity 6.3 LTS documentation.
---

# Unity Editor Tools

## Editor Scripting Overview

Editor scripts extend the Unity Editor with custom inspectors, windows, tools, and workflows. All editor code must either live in an `Editor/` folder or be wrapped in `#if UNITY_EDITOR` / `#endif` -- this ensures editor code is stripped from runtime builds.

Unity 6.3 supports two GUI frameworks for editor extensions:

| Framework | Status | Entry Point |
|-----------|--------|-------------|
| **UI Toolkit** | Recommended | `CreateInspectorGUI()` / `CreateGUI()` returning `VisualElement` |
| **IMGUI** | Legacy, fully functional | `OnInspectorGUI()` / `OnGUI()` |

Key base classes: `Editor`, `EditorWindow`, `PropertyDrawer`, `DecoratorDrawer`, `ScriptableWizard`.

---

## Custom Inspector (Editor)

Derive from `Editor`, apply `[CustomEditor(typeof(TargetType))]`. See `references/custom-inspectors.md` for full guide.

### UI Toolkit (Recommended)

```csharp
[CustomEditor(typeof(MyPlayer))]
public class MyPlayerEditor : Editor
{
    public override VisualElement CreateInspectorGUI()
    {
        VisualElement root = new VisualElement();
        var visualTree = Resources.Load("MyPlayerEditor") as VisualTreeAsset;
        visualTree.CloneTree(root);
        return root;
    }
}
```

When `CreateInspectorGUI()` is overridden, `OnInspectorGUI()` is ignored.

### IMGUI with SerializedObject Pattern

```csharp
[CustomEditor(typeof(LookAtPoint))]
[CanEditMultipleObjects]
public class LookAtPointEditor : Editor
{
    SerializedProperty lookAtPoint;

    void OnEnable() { lookAtPoint = serializedObject.FindProperty("lookAtPoint"); }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();
        EditorGUILayout.PropertyField(lookAtPoint);
        serializedObject.ApplyModifiedProperties();
    }
}
```

### Key Members

| Member | Description |
|--------|-------------|
| `target` / `targets` | Inspected object(s) |
| `serializedObject` | SerializedObject for the target(s) |
| `DrawDefaultInspector()` | Renders built-in default inspector |
| `OnSceneGUI()` | Draw interactive Handles in Scene View |

### Scene View Integration

```csharp
public void OnSceneGUI()
{
    var t = (LookAtPoint)target;
    EditorGUI.BeginChangeCheck();
    Vector3 pos = Handles.PositionHandle(t.lookAtPoint, Quaternion.identity);
    if (EditorGUI.EndChangeCheck())
    {
        Undo.RecordObject(target, "Move look-at point");
        t.lookAtPoint = pos;
    }
}
```

---

## PropertyDrawer and PropertyAttribute

Customize how serialized fields appear in the Inspector. See `references/property-drawers.md` for full guide.

**1. Define attribute (runtime code, outside Editor folder):**

```csharp
public class MyRangeAttribute : PropertyAttribute
{
    public readonly float min, max;
    public MyRangeAttribute(float min, float max) { this.min = min; this.max = max; }
}
```

**2. Implement drawer (Editor folder):**

```csharp
[CustomPropertyDrawer(typeof(MyRangeAttribute))]
public class MyRangeDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        MyRangeAttribute range = (MyRangeAttribute)attribute;
        if (property.propertyType == SerializedPropertyType.Float)
            EditorGUI.Slider(position, property, range.min, range.max, label);
        else if (property.propertyType == SerializedPropertyType.Integer)
            EditorGUI.IntSlider(position, property, (int)range.min, (int)range.max, label);
    }
}
```

**Critical rules:** Must be in `Editor/` folder. Use `EditorGUI` (not `EditorGUILayout`). Use `EditorGUI.BeginProperty()`/`EndProperty()` for prefab overrides. Cannot mix UI Toolkit and IMGUI in one drawer.

---

## EditorWindow

Custom dockable editor windows. See `references/editor-windows.md` for full guide.

**Lifecycle:** OnEnable -> CreateGUI -> Update -> OnGUI -> OnDisable

```csharp
public class MyToolWindow : EditorWindow
{
    [MenuItem("Tools/My Tool Window")]
    public static void ShowWindow()
    {
        var window = GetWindow<MyToolWindow>();
        window.titleContent = new GUIContent("My Tool");
        window.minSize = new Vector2(300, 200);
    }

    public void CreateGUI()
    {
        rootVisualElement.Add(new Label("Hello from UI Toolkit!"));
        rootVisualElement.Add(new Button(() => Debug.Log("Clicked!")) { text = "Click Me" });
    }
}
```

| Static Method | Description |
|---------------|-------------|
| `GetWindow<T>()` | Get existing or create new |
| `CreateWindow<T>()` | Always create new instance |
| `HasOpenInstances<T>()` | Check if open |

| Display Mode | Behavior |
|-------------|----------|
| `Show()` | Standard dockable |
| `ShowUtility()` | Floating, not dockable |
| `ShowModal()` | Modal dialog |
| `ShowAsDropDown()` | Dropdown popup |

---

## MenuItem

The `[MenuItem]` attribute converts static methods into menu commands.

```csharp
[MenuItem("Menu/Path/Item Name", isValidateFunction, priority)]
```

| Prefix | Placement |
|--------|-----------|
| `"Tools/..."` | Custom tools menu |
| `"Assets/..."` | Assets menu + Project context menu |
| `"GameObject/..."` | GameObject menu + Hierarchy context menu |
| `"CONTEXT/ComponentType/..."` | Component context menu |

**Shortcut modifiers:** `%` = Cmd/Ctrl, `#` = Shift, `&` = Alt, `^` = Ctrl (all), `_` = no modifier.

```csharp
// Validation function controls when menu item is enabled
[MenuItem("Tools/Reset Position", true)]
static bool ValidateResetPosition() => Selection.activeTransform != null;

[MenuItem("Tools/Reset Position", false)]
static void ResetPosition()
{
    Undo.RecordObject(Selection.activeTransform, "Reset Position");
    Selection.activeTransform.position = Vector3.zero;
}
```

**GameObject creation** (use priority 10):

```csharp
[MenuItem("GameObject/Custom/My Object", false, 10)]
static void CreateMyObject(MenuCommand menuCommand)
{
    var go = new GameObject("My Object");
    GameObjectUtility.SetParentAndAlign(go, menuCommand.context as GameObject);
    Undo.RegisterCreatedObjectUndo(go, "Create My Object");
    Selection.activeObject = go;
}
```

---

## Gizmos and Handles

### Gizmos -- Visual Debugging in Scene/Game View

All drawing inside `OnDrawGizmos()` (always) or `OnDrawGizmosSelected()` (when selected):

```csharp
void OnDrawGizmos()
{
    Gizmos.color = Color.yellow;
    Gizmos.DrawWireSphere(transform.position, radius);
}

void OnDrawGizmosSelected()
{
    Gizmos.color = Color.red;
    Gizmos.DrawSphere(transform.position, radius);
}
```

**Methods:** `DrawLine`, `DrawRay`, `DrawSphere`, `DrawWireSphere`, `DrawCube`, `DrawWireCube`, `DrawMesh`, `DrawWireMesh`, `DrawFrustum`, `DrawIcon`. **Properties:** `color`, `matrix`.

### Handles -- Interactive 3D Controls (Editor Only)

Used inside `OnSceneGUI()` on custom Editors:

```csharp
[CustomEditor(typeof(CircleLayout))]
public class CircleLayoutEditor : Editor
{
    public void OnSceneGUI()
    {
        var t = (CircleLayout)target;
        Handles.color = new Color(1f, 0.8f, 0.4f, 1f);
        Handles.DrawWireDisc(t.transform.position, t.transform.up, t.radius);
        Handles.Label(t.transform.position, $"Radius: {t.radius:F1}");

        EditorGUI.BeginChangeCheck();
        float newRadius = Handles.RadiusHandle(Quaternion.identity, t.transform.position, t.radius);
        if (EditorGUI.EndChangeCheck())
        {
            Undo.RecordObject(t, "Change Radius");
            t.radius = newRadius;
        }
    }
}
```

**Methods:** `PositionHandle`, `RotationHandle`, `ScaleHandle`, `FreeMoveHandle`, `RadiusHandle`, `DrawLine`, `DrawWireDisc`, `Label`, `BeginGUI`/`EndGUI`. **Properties:** `color`, `matrix`.

---

## SerializedObject Pattern

The standard way to edit properties in editor scripts. Provides automatic Undo, multi-object editing, and prefab override tracking.

**Three-step pattern:**

```csharp
serializedObject.Update();                                          // 1. Sync from target
EditorGUILayout.PropertyField(serializedObject.FindProperty("myField")); // 2. Draw/modify
serializedObject.ApplyModifiedProperties();                         // 3. Apply with undo
```

| Member | Description |
|--------|-------------|
| `Update()` | Refresh from target |
| `ApplyModifiedProperties()` | Commit changes with undo |
| `FindProperty(string)` | Get SerializedProperty by name |
| `GetIterator()` | Iterate all properties |
| `targetObject` / `targetObjects` | Inspected object(s) |
| `hasModifiedProperties` | True when unapplied changes exist |

For multi-object editing: add `[CanEditMultipleObjects]` and always use `SerializedProperty` instead of `target`.

---

## AssetDatabase

Programmatic asset access in editor scripts.

```csharp
// Create
var data = ScriptableObject.CreateInstance<MyData>();
AssetDatabase.CreateAsset(data, "Assets/Data/MyData.asset");
AssetDatabase.SaveAssets();

// Load
var loaded = AssetDatabase.LoadAssetAtPath<MyData>("Assets/Data/MyData.asset");

// Find by type
string[] guids = AssetDatabase.FindAssets("t:MyData");
foreach (string guid in guids)
{
    string path = AssetDatabase.GUIDToAssetPath(guid);
    var asset = AssetDatabase.LoadAssetAtPath<MyData>(path);
}

// Other operations
AssetDatabase.GetAssetPath(myObject);
AssetDatabase.DeleteAsset("Assets/Data/OldData.asset");
AssetDatabase.Refresh();
```

**Key methods:** `CreateAsset`, `LoadAssetAtPath<T>`, `FindAssets`, `GetAssetPath`, `AssetPathToGUID`/`GUIDToAssetPath`, `SaveAssets`, `Refresh`, `DeleteAsset`, `CopyAsset`, `MoveAsset`, `RenameAsset`, `ImportAsset`.

---

## Common Patterns

```csharp
// Editor-only guard
#if UNITY_EDITOR
using UnityEditor;
// editor code
#endif

// Change detection
EditorGUI.BeginChangeCheck();
// ... controls ...
if (EditorGUI.EndChangeCheck()) { Undo.RecordObject(target, "Change"); }

// ScriptableObject creation menu
[CreateAssetMenu(fileName = "NewConfig", menuName = "Game/Config Data", order = 1)]
public class ConfigData : ScriptableObject { public float moveSpeed = 5f; }

// Default inspector + extras
[CustomEditor(typeof(MyComponent))]
public class MyComponentEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        if (GUILayout.Button("Do Something")) { ((MyComponent)target).DoSomething(); }
    }
}
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Editing `target` without Undo | No undo, no dirty flag | Use SerializedObject or `Undo.RecordObject()` |
| `target` with `[CanEditMultipleObjects]` | Only modifies first object | Use `SerializedProperty` |
| Editor code outside `Editor/` without `#if UNITY_EDITOR` | Build failures | Use `Editor/` folder or preprocessor guard |
| `EditorGUILayout` in PropertyDrawer | Not supported | Use `EditorGUI` with Rect |
| Missing `serializedObject.Update()` | Stale data | Always call before reading |
| Missing `ApplyModifiedProperties()` | Changes lost | Always call after modifications |
| Mixing UI Toolkit + IMGUI in one PropertyDrawer | Not supported | Choose one framework |
| Missing `Undo.RegisterCreatedObjectUndo()` | Cannot undo creation | Always register new objects |
| Missing `GameObjectUtility.SetParentAndAlign()` | Wrong hierarchy parenting | Use in GameObject menu items |
| Heavy work in `OnInspectorGUI()`/`OnGUI()` | Lag (called many times/frame) | Cache in `OnEnable()` |

---

## Key API Quick Reference

```
Editor:        [CustomEditor(typeof(T))], [CanEditMultipleObjects]
               CreateInspectorGUI(), OnInspectorGUI(), OnSceneGUI()
               DrawDefaultInspector(), target, targets, serializedObject

EditorWindow:  GetWindow<T>(), CreateWindow<T>(), CreateGUI(), OnGUI()
               rootVisualElement, titleContent, Show/ShowUtility/ShowModal

PropertyDrawer: [CustomPropertyDrawer(typeof(T))]
               CreatePropertyGUI(), OnGUI(rect,prop,label), GetPropertyHeight()
               attribute, fieldInfo, preferredLabel

SerializedObject: Update(), ApplyModifiedProperties(), FindProperty()
MenuItem:      [MenuItem("Path", validate, priority)], % # & ^ _ shortcuts
Gizmos:        DrawLine/Sphere/WireSphere/Cube/WireCube/Ray/Mesh/Icon, color, matrix
Handles:       PositionHandle/RotationHandle/ScaleHandle/FreeMoveHandle/RadiusHandle
               DrawLine/DrawWireDisc/Label, BeginGUI/EndGUI, color, matrix
AssetDatabase: CreateAsset, LoadAssetAtPath<T>, FindAssets, SaveAssets, Refresh
```

---

## Related Skills

- **unity-foundations** -- Project structure, assembly definitions, Editor folders
- **unity-scripting** -- MonoBehaviour lifecycle, SerializeField, ScriptableObject
- **unity-ui** -- UI Toolkit fundamentals, VisualElement, UXML, USS

---

## Additional Resources

- [Custom Editor Windows (Manual)](https://docs.unity3d.com/6000.3/Documentation/Manual/editor-EditorWindows.html)
- [Custom Editors (Manual)](https://docs.unity3d.com/6000.3/Documentation/Manual/editor-CustomEditors.html)
- [Property Drawers (Manual)](https://docs.unity3d.com/6000.3/Documentation/Manual/editor-PropertyDrawers.html)
- [Editor API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Editor.html)
- [EditorWindow API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/EditorWindow.html)
- [PropertyDrawer API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/PropertyDrawer.html)
- [AssetDatabase API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AssetDatabase.html)
- [SerializedObject API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/SerializedObject.html)
- [MenuItem API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/MenuItem.html)
- [Gizmos API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Gizmos.html)
- [Handles API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Handles.html)
