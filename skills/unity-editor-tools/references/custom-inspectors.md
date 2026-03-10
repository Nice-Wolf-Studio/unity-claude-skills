# Custom Inspectors in Unity 6.3

## Overview

Custom inspectors replace or extend the default Inspector panel for MonoBehaviours and ScriptableObjects. Unity 6.3 supports two approaches: **UI Toolkit** (recommended) and **IMGUI** (legacy but fully functional).

All custom inspector code must reside in an `Editor/` folder or be wrapped in `#if UNITY_EDITOR`.

**Source:** [Custom Editors Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/editor-CustomEditors.html) | [Editor API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Editor.html)

---

## Core Setup

Every custom inspector requires:

1. A class deriving from `Editor`
2. The `[CustomEditor(typeof(TargetType))]` attribute
3. An override of `CreateInspectorGUI()` (UI Toolkit) or `OnInspectorGUI()` (IMGUI)

```csharp
using UnityEditor;
using UnityEngine;

// The target MonoBehaviour
public class LookAtPoint : MonoBehaviour
{
    public Vector3 lookAtPoint = Vector3.zero;
}
```

---

## UI Toolkit Approach (Recommended)

Override `CreateInspectorGUI()` to return a `VisualElement` tree. When this method is overridden, any `OnInspectorGUI()` implementation is ignored.

### Basic UI Toolkit Inspector

```csharp
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEditor.UIElements;

[CustomEditor(typeof(LookAtPoint))]
public class LookAtPointEditor : Editor
{
    public override VisualElement CreateInspectorGUI()
    {
        VisualElement root = new VisualElement();

        // PropertyField automatically binds to SerializedProperty
        var lookAtField = new PropertyField(serializedObject.FindProperty("lookAtPoint"));
        root.Add(lookAtField);

        // Add a custom button
        var resetButton = new Button(() =>
        {
            serializedObject.FindProperty("lookAtPoint").vector3Value = Vector3.zero;
            serializedObject.ApplyModifiedProperties();
        })
        { text = "Reset Point" };
        root.Add(resetButton);

        return root;
    }
}
```

### Loading from UXML Template

```csharp
[CustomEditor(typeof(MyPlayer))]
public class MyPlayerEditor : Editor
{
    public override VisualElement CreateInspectorGUI()
    {
        VisualElement root = new VisualElement();

        // Load UXML from Resources folder
        var visualTree = Resources.Load("MyPlayerEditor") as VisualTreeAsset;
        visualTree.CloneTree(root);

        return root;
    }
}
```

---

## IMGUI Approach

Override `OnInspectorGUI()` using the SerializedObject three-step pattern.

### Basic IMGUI Inspector

```csharp
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(LookAtPoint))]
[CanEditMultipleObjects]
public class LookAtPointEditor : Editor
{
    SerializedProperty lookAtPoint;

    void OnEnable()
    {
        // Cache property references for performance
        lookAtPoint = serializedObject.FindProperty("lookAtPoint");
    }

    public override void OnInspectorGUI()
    {
        // Step 1: Update serialized representation
        serializedObject.Update();

        // Step 2: Draw property fields
        EditorGUILayout.PropertyField(lookAtPoint);

        // Step 3: Apply changes (auto-registers undo)
        serializedObject.ApplyModifiedProperties();
    }
}
```

### Extended Inspector with Default + Custom

```csharp
[CustomEditor(typeof(MyComponent))]
public class MyComponentEditor : Editor
{
    public override void OnInspectorGUI()
    {
        // Draw all default fields first
        DrawDefaultInspector();

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Custom Controls", EditorStyles.boldLabel);

        if (GUILayout.Button("Do Something"))
        {
            ((MyComponent)target).DoSomething();
        }
    }
}
```

### Full-Featured IMGUI Inspector

```csharp
[CustomEditor(typeof(MyPlayer))]
[CanEditMultipleObjects]
public class MyPlayerEditor : Editor
{
    SerializedProperty damageProp;
    SerializedProperty armorProp;
    SerializedProperty weaponProp;

    void OnEnable()
    {
        damageProp = serializedObject.FindProperty("damage");
        armorProp = serializedObject.FindProperty("armor");
        weaponProp = serializedObject.FindProperty("weapon");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.LabelField("Combat Stats", EditorStyles.boldLabel);
        EditorGUILayout.IntSlider(damageProp, 0, 100, new GUIContent("Damage"));

        // Conditional display based on property value
        if (!damageProp.hasMultipleDifferentValues && damageProp.intValue > 80)
        {
            EditorGUILayout.HelpBox("High damage value!", MessageType.Warning);
        }

        EditorGUILayout.PropertyField(armorProp);
        EditorGUILayout.PropertyField(weaponProp);

        serializedObject.ApplyModifiedProperties();
    }
}
```

---

## Multi-Object Editing

Add `[CanEditMultipleObjects]` and always use `SerializedProperty` (never `target` directly) to support selecting and editing multiple objects simultaneously.

```csharp
[CustomEditor(typeof(Enemy))]
[CanEditMultipleObjects]
public class EnemyEditor : Editor
{
    SerializedProperty healthProp;

    void OnEnable()
    {
        healthProp = serializedObject.FindProperty("health");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        // This automatically handles mixed values across selections
        EditorGUILayout.PropertyField(healthProp);

        // Check for mixed values
        if (healthProp.hasMultipleDifferentValues)
        {
            EditorGUILayout.HelpBox("Objects have different health values.", MessageType.Info);
        }

        serializedObject.ApplyModifiedProperties();
    }
}
```

---

## Scene View Integration (OnSceneGUI)

`OnSceneGUI()` enables drawing interactive handles directly in the Scene view from a custom Editor.

### Position Handle in Scene View

```csharp
[CustomEditor(typeof(LookAtPoint))]
public class LookAtPointEditor : Editor
{
    SerializedProperty lookAtPoint;

    void OnEnable()
    {
        lookAtPoint = serializedObject.FindProperty("lookAtPoint");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();
        EditorGUILayout.PropertyField(lookAtPoint);
        serializedObject.ApplyModifiedProperties();
    }

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
}
```

### Drawing 2D GUI in Scene View

```csharp
public void OnSceneGUI()
{
    var t = (MyComponent)target;

    // 3D handle drawing
    Handles.color = Color.cyan;
    Handles.DrawWireDisc(t.transform.position, Vector3.up, t.radius);

    // 2D GUI overlay -- must wrap in BeginGUI/EndGUI
    Handles.BeginGUI();
    GUILayout.BeginArea(new Rect(10, 10, 200, 100));
    GUILayout.Label("Scene Tool", EditorStyles.boldLabel);
    if (GUILayout.Button("Reset"))
    {
        Undo.RecordObject(t, "Reset");
        t.radius = 1f;
    }
    GUILayout.EndArea();
    Handles.EndGUI();
}
```

---

## Editor Class Properties and Methods Reference

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `target` | Object | The single inspected object |
| `targets` | Object[] | All inspected objects (multi-select) |
| `serializedObject` | SerializedObject | Serialized representation of target(s) |
| `hasUnsavedChanges` | bool | Whether editor has unsaved modifications |
| `saveChangesMessage` | string | Message shown when prompting to save |

### Methods

| Method | Description |
|--------|-------------|
| `CreateInspectorGUI()` | UI Toolkit inspector (returns VisualElement) |
| `OnInspectorGUI()` | IMGUI inspector rendering |
| `OnSceneGUI()` | Scene view handles and drawing |
| `DrawDefaultInspector()` | Render the built-in default inspector |
| `Repaint()` | Request inspector redraw |
| `DrawHeader()` | Render the editor header |
| `OnPreviewGUI()` | Custom asset preview |
| `RequiresConstantRepaint()` | Return true if continuous repaint needed |
| `SaveChanges()` | Handle save prompt |
| `DiscardChanges()` | Handle discard prompt |

### Static Methods

| Method | Description |
|--------|-------------|
| `CreateEditor(target)` | Instantiate an editor for a specific object |
| `CreateCachedEditor()` | Efficiently manage editor instances |
| `DrawFoldoutInspector()` | Render inspector with collapsible headers |

---

## ExecuteInEditMode

Apply `[ExecuteInEditMode]` (or `[ExecuteAlways]` for both edit and play mode) to a MonoBehaviour to have it run during edit mode, useful for previewing behavior without entering Play mode:

```csharp
[ExecuteInEditMode]
public class LookAtPoint : MonoBehaviour
{
    public Vector3 lookAtPoint = Vector3.zero;

    void Update()
    {
        transform.LookAt(lookAtPoint);
    }
}
```

---

## Common Mistakes

| Mistake | Why It Fails | Fix |
|---------|-------------|-----|
| Using `target` with `[CanEditMultipleObjects]` | Only edits first object | Use `SerializedProperty` |
| Forgetting `serializedObject.Update()` | Reads stale data | Always call before reading properties |
| Forgetting `ApplyModifiedProperties()` | Changes are silently lost | Always call after modifications |
| Modifying `target` without `Undo.RecordObject()` | No undo support | Use SerializedObject pattern or Undo API |
| Heavy work in `OnInspectorGUI()` | Called many times per frame | Cache in `OnEnable()` |
| Not caching `SerializedProperty` in `OnEnable()` | `FindProperty()` every frame is wasteful | Cache in `OnEnable()` |
