# EditorWindow in Unity 6.3

## Overview

`EditorWindow` is the base class for creating custom dockable editor windows in Unity. Windows can float freely, dock as tabs alongside built-in panels, or display as utility/modal dialogs.

**Source:** [EditorWindow Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/editor-EditorWindows.html) | [EditorWindow API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/EditorWindow.html)

---

## Lifecycle Order

1. **OnEnable** -- called when the window script loads or after domain reload
2. **CreateGUI** -- build UI Toolkit interface (skipped during editor update cycles)
3. **Update** -- called once per frame (use for background logic)
4. **OnGUI** -- called multiple times per frame for IMGUI rendering and event handling
5. **OnDisable** -- called when window is closed or script reloads

---

## Creating an EditorWindow

### UI Toolkit (Recommended)

```csharp
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

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
        // Build UI using UI Toolkit
        var label = new Label("My Custom Tool");
        label.style.fontSize = 16;
        label.style.unityFontStyleAndWeight = FontStyle.Bold;
        rootVisualElement.Add(label);

        var textField = new TextField("Name");
        rootVisualElement.Add(textField);

        var toggle = new Toggle("Enabled");
        rootVisualElement.Add(toggle);

        var slider = new Slider("Amount", 0f, 100f);
        rootVisualElement.Add(slider);

        var button = new Button(() => Debug.Log("Button clicked!"))
        {
            text = "Execute"
        };
        rootVisualElement.Add(button);
    }
}
```

### IMGUI Approach

```csharp
using UnityEditor;
using UnityEngine;

public class MyIMGUIWindow : EditorWindow
{
    string myString = "Hello";
    bool groupEnabled;
    bool myBool = true;
    float myFloat = 1.23f;

    [MenuItem("Tools/My IMGUI Window")]
    public static void ShowWindow()
    {
        GetWindow<MyIMGUIWindow>("My IMGUI Window");
    }

    void OnGUI()
    {
        GUILayout.Label("Base Settings", EditorStyles.boldLabel);
        myString = EditorGUILayout.TextField("Text Field", myString);

        groupEnabled = EditorGUILayout.BeginToggleGroup("Optional Settings", groupEnabled);
        myBool = EditorGUILayout.Toggle("Toggle", myBool);
        myFloat = EditorGUILayout.Slider("Slider", myFloat, -3, 3);
        EditorGUILayout.EndToggleGroup();
    }
}
```

---

## Opening Windows

### Static Methods

| Method | Behavior |
|--------|----------|
| `GetWindow<T>()` | Returns existing window of type T, or creates one if none exists |
| `GetWindow<T>(string title)` | Same, with custom title |
| `CreateWindow<T>()` | Always creates a new instance (multiple windows of same type) |
| `HasOpenInstances<T>()` | Check if a window type is currently open |
| `FocusWindowIfItsOpen<T>()` | Bring an open window to front |

### GetWindow Overloads

```csharp
// Basic -- reuses existing or creates new
var window = GetWindow<MyToolWindow>();

// With title
var window = GetWindow<MyToolWindow>("My Tool");

// With utility flag (floating, not dockable)
var window = GetWindow<MyToolWindow>(true, "My Tool");

// Dock next to specific window type
var window = GetWindow<MyToolWindow>(typeof(SceneView));
```

---

## Display Modes

| Method | Behavior | Dockable |
|--------|----------|----------|
| `Show()` | Standard editor window | Yes |
| `ShowUtility()` | Floating utility window | No |
| `ShowModal()` | Modal dialog (blocks other windows) | No |
| `ShowAsDropDown()` | Dropdown-style popup at specific position | No |
| `Close()` | Close the window | -- |

```csharp
// Show as utility window
[MenuItem("Tools/Quick Settings")]
static void ShowQuickSettings()
{
    var window = CreateInstance<QuickSettingsWindow>();
    window.titleContent = new GUIContent("Quick Settings");
    window.ShowUtility();
}

// Show as dropdown
[MenuItem("Tools/Color Picker")]
static void ShowColorPicker()
{
    var window = CreateInstance<ColorPickerWindow>();
    window.ShowAsDropDown(
        new Rect(Screen.width / 2f, Screen.height / 2f, 0, 0),
        new Vector2(250, 150)
    );
}
```

---

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `rootVisualElement` | VisualElement | Root of UI Toolkit hierarchy |
| `titleContent` | GUIContent | Window title and optional icon |
| `position` | Rect | Window position and size in screen space |
| `docked` | bool | Whether the window is currently docked |
| `hasFocus` | bool | Whether the window has keyboard focus |
| `minSize` | Vector2 | Minimum window dimensions |
| `maxSize` | Vector2 | Maximum window dimensions |
| `hasUnsavedChanges` | bool | Enables save-on-close prompt |
| `saveChangesMessage` | string | Custom prompt message |

---

## Persistence Between Sessions

EditorWindow state automatically persists between editor sessions for serialized fields. Windows remember their position and docking state as part of the editor layout.

```csharp
public class PersistentWindow : EditorWindow
{
    // These survive domain reloads and editor restarts
    [SerializeField] private string savedText = "";
    [SerializeField] private int savedIndex = 0;

    // This does NOT persist (not serializable)
    private Dictionary<string, object> runtimeCache;

    void OnEnable()
    {
        // Rebuild non-serialized state
        runtimeCache = new Dictionary<string, object>();
    }
}
```

---

## Window with SerializedObject Binding

For windows that edit ScriptableObject or other asset data:

```csharp
public class DataEditorWindow : EditorWindow
{
    [SerializeField] private MyDataAsset currentAsset;
    private SerializedObject serializedAsset;

    [MenuItem("Tools/Data Editor")]
    public static void ShowWindow()
    {
        GetWindow<DataEditorWindow>("Data Editor");
    }

    void OnGUI()
    {
        currentAsset = (MyDataAsset)EditorGUILayout.ObjectField(
            "Data Asset", currentAsset, typeof(MyDataAsset), false);

        if (currentAsset == null) return;

        if (serializedAsset == null || serializedAsset.targetObject != currentAsset)
            serializedAsset = new SerializedObject(currentAsset);

        serializedAsset.Update();

        var iterator = serializedAsset.GetIterator();
        iterator.NextVisible(true); // skip "m_Script"
        while (iterator.NextVisible(false))
        {
            EditorGUILayout.PropertyField(iterator, true);
        }

        serializedAsset.ApplyModifiedProperties();
    }
}
```

---

## Toolbar Integration

Add buttons to the main editor toolbar using `[InitializeOnLoad]`:

```csharp
using UnityEditor;
using UnityEditor.Overlays;
using UnityEditor.Toolbars;
using UnityEngine.UIElements;

[Overlay(typeof(SceneView), "My Custom Toolbar")]
public class MyToolbarOverlay : ToolbarOverlay
{
    MyToolbarOverlay() : base(MyToolbarButton.id) { }
}

[EditorToolbarElement(id, typeof(SceneView))]
public class MyToolbarButton : EditorToolbarButton
{
    public const string id = "MyToolbar/MyButton";

    public MyToolbarButton()
    {
        text = "My Tool";
        clicked += OnClick;
    }

    void OnClick()
    {
        MyToolWindow.ShowWindow();
    }
}
```

---

## IMGUI Controls Reference

Two sets of GUI classes work in EditorWindows:

| Class | Purpose |
|-------|---------|
| `GUI` / `GUILayout` | Standard controls (work in runtime and editor) |
| `EditorGUI` / `EditorGUILayout` | Editor-specific controls (extended functionality) |

Both can be mixed freely within `OnGUI()`.

### Common EditorGUILayout Controls

```csharp
void OnGUI()
{
    // Text
    myString = EditorGUILayout.TextField("Label", myString);

    // Numbers
    myInt = EditorGUILayout.IntField("Count", myInt);
    myFloat = EditorGUILayout.FloatField("Speed", myFloat);
    myFloat = EditorGUILayout.Slider("Amount", myFloat, 0f, 1f);

    // Vectors
    myVec3 = EditorGUILayout.Vector3Field("Position", myVec3);

    // Objects
    myObj = (GameObject)EditorGUILayout.ObjectField("Target", myObj, typeof(GameObject), true);

    // Enum
    myEnum = (MyEnum)EditorGUILayout.EnumPopup("Mode", myEnum);

    // Color
    myColor = EditorGUILayout.ColorField("Tint", myColor);

    // Toggle group
    showAdvanced = EditorGUILayout.Foldout(showAdvanced, "Advanced");
    if (showAdvanced)
    {
        EditorGUI.indentLevel++;
        // ... advanced fields ...
        EditorGUI.indentLevel--;
    }

    // Buttons
    if (GUILayout.Button("Execute"))
    {
        DoWork();
    }
}
```

---

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Not setting `titleContent` | Window shows blank tab | Set in `ShowWindow()` or `OnEnable()` |
| Using non-serialized fields for state | State lost on domain reload | Mark important state with `[SerializeField]` |
| Heavy work in `OnGUI()` | Called many times per frame, causes lag | Do work in `OnEnable()` or `Update()`, cache results |
| Not calling `Repaint()` when data changes externally | Window shows stale data | Call `Repaint()` or use data binding |
| Creating window in `OnEnable()` or field initializer | Recursive creation, stack overflow | Only create in static `MenuItem` method |
