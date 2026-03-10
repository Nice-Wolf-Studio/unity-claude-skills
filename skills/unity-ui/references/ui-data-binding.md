# UI Toolkit Data Binding

> Source: Unity 6.3 LTS Documentation

Data binding connects UI elements to data sources, enabling automatic synchronization between the UI and the underlying data model. Unity 6 provides two binding systems: **SerializedObject binding** (for Editor/Inspector UI) and **Runtime binding** (for plain C# objects).

---

## SerializedObject Binding

SerializedObject binding connects visual elements to serialized properties. It works with:
- User-defined `MonoBehaviour` classes
- User-defined `ScriptableObject` classes
- Native Unity component types (Transform, Rigidbody, etc.)
- Native Unity asset types
- Primitive C# types: `int`, `bool`, `float`, etc.
- Native Unity types: `Vector3`, `Color`, `Object`, etc.

### Constraint

Only the `value` property of elements implementing `INotifyValueChanged<T>` can be bound. For example, you can bind `TextField.value` to a string, but you cannot bind `TextField.name` to a string.

### Setting Binding Paths

A binding path maps to the serialized property name. For a field `int m_Count`, the binding path is `"m_Count"`.

**Three ways to set binding paths:**

1. **UI Builder** -- Set in the Inspector panel
2. **UXML** -- Use the `binding-path` attribute:
```xml
<ui:IntegerField label="Health" binding-path="m_Health" />
<ui:FloatField label="Speed" binding-path="m_Speed" />
<ui:Toggle label="Is Active" binding-path="m_IsActive" />
<ui:TextField label="Name" binding-path="m_Name" />
<ui:ColorField label="Color" binding-path="m_Color" />
<ui:ObjectField label="Target" binding-path="m_Target" />
```
3. **C#** -- Set the `bindingPath` property:
```csharp
var healthField = new IntegerField("Health");
healthField.bindingPath = "m_Health";
```

### Binding in Custom Inspectors

```csharp
using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.UIElements;

[CustomEditor(typeof(PlayerStats))]
public class PlayerStatsEditor : Editor
{
    public override VisualElement CreateInspectorGUI()
    {
        var root = new VisualElement();

        // Fields with binding paths -- auto-bound after this method returns
        root.Add(new IntegerField("Health") { bindingPath = "m_Health" });
        root.Add(new FloatField("Speed") { bindingPath = "m_Speed" });
        root.Add(new Toggle("Is Active") { bindingPath = "m_IsActive" });
        root.Add(new TextField("Player Name") { bindingPath = "m_PlayerName" });
        root.Add(new ColorField("Team Color") { bindingPath = "m_TeamColor" });

        // DO NOT call Bind() here -- auto-binding occurs after CreateInspectorGUI returns
        return root;
    }
}
```

The `MonoBehaviour` backing this inspector:

```csharp
using UnityEngine;

public class PlayerStats : MonoBehaviour
{
    [SerializeField] private int m_Health = 100;
    [SerializeField] private float m_Speed = 5f;
    [SerializeField] private bool m_IsActive = true;
    [SerializeField] private string m_PlayerName = "Player";
    [SerializeField] private Color m_TeamColor = Color.blue;
}
```

### Manual Binding

For UI created outside of `CreateInspectorGUI` (e.g., EditorWindow), call `Bind()` explicitly:

```csharp
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

public class StatsWindow : EditorWindow
{
    [SerializeField] private VisualTreeAsset windowLayout;

    [MenuItem("Window/Stats")]
    public static void ShowWindow() => GetWindow<StatsWindow>("Stats");

    public void CreateGUI()
    {
        var root = rootVisualElement;
        windowLayout.CloneTree(root);

        // Manual binding required in EditorWindow
        var selectedObject = Selection.activeGameObject;
        if (selectedObject != null)
        {
            var stats = selectedObject.GetComponent<PlayerStats>();
            if (stats != null)
            {
                root.Bind(new SerializedObject(stats));
            }
        }
    }
}
```

### Bind() vs BindProperty()

| Method | Use Case |
|---|---|
| `Bind(SerializedObject)` | Binds entire element hierarchy. Matches child binding paths to properties. |
| `BindProperty(SerializedProperty)` | Binds a single element directly to a specific property. Useful for dynamic property traversal. |
| `Unbind()` | Stops value tracking on element and all children. |

```csharp
// Bind entire hierarchy
root.Bind(new SerializedObject(targetComponent));

// Bind single element to specific property
SerializedObject so = new SerializedObject(targetComponent);
SerializedProperty healthProp = so.FindProperty("m_Health");
healthField.BindProperty(healthProp);

// Unbind
root.Unbind();
```

### Nested Property Binding

`BindableElement`, `TemplateContainer`, and `GroupBox` support nested binding paths. Child binding paths are combined with ancestor paths:

```xml
<ui:BindableElement binding-path="m_Stats">
    <ui:IntegerField label="Health" binding-path="m_Health" />
    <ui:FloatField label="Speed" binding-path="m_Speed" />
</ui:BindableElement>
```

This binds to `m_Stats.m_Health` and `m_Stats.m_Speed`.

### Tracking Changes

```csharp
// Track a specific property
SerializedProperty prop = serializedObject.FindProperty("m_Health");
element.TrackPropertyValue(prop, changedProp =>
{
    Debug.Log($"Health changed to: {changedProp.intValue}");
});

// Track any change on the entire SerializedObject
element.TrackSerializedObjectValue(serializedObject, changedObj =>
{
    Debug.Log("Something changed on the object");
});
```

### Auto-Property Backing Fields

C# auto-properties with `[field: SerializeField]` generate compiler-named backing fields:

```csharp
[field: SerializeField]
public int SomeProp { get; set; }
// Backing field name: <SomeProp>k__BackingField
```

In UXML, escape the angle brackets:
```xml
<ui:IntegerField binding-path="&lt;SomeProp&gt;k__BackingField" />
```

In C#:
```csharp
field.bindingPath = "<SomeProp>k__BackingField";
```

### Automatic Binding Timing

Automatic binding occurs:
- During `InspectorElement` constructor
- After `CreateInspectorGUI()` returns
- After `CreatePropertyGUI()` returns
- When `Bind()` or `BindProperty()` is called on a parent element

For non-Inspector UI (EditorWindow, runtime), always call `Bind()` or `BindProperty()` manually.

---

## Custom Bindable Elements

To make a custom element support binding, it must:
1. Inherit from `BindableElement` or implement `IBindable`
2. Implement `INotifyValueChanged<T>`
3. Provide `SetValueWithoutNotify()` and a `value` property

```csharp
using UnityEngine.UIElements;

public class PercentageBar : BindableElement, INotifyValueChanged<float>
{
    public new class UxmlFactory : UxmlFactory<PercentageBar, UxmlTraits> { }

    private float m_Value;
    private VisualElement fillBar;
    private Label valueLabel;

    public float value
    {
        get => m_Value;
        set
        {
            if (Mathf.Approximately(m_Value, value)) return;
            using (var evt = ChangeEvent<float>.GetPooled(m_Value, value))
            {
                evt.target = this;
                SetValueWithoutNotify(value);
                SendEvent(evt);
            }
        }
    }

    public void SetValueWithoutNotify(float newValue)
    {
        m_Value = Mathf.Clamp01(newValue);
        fillBar.style.width = Length.Percent(m_Value * 100f);
        valueLabel.text = $"{m_Value:P0}";
    }

    public PercentageBar()
    {
        AddToClassList("percentage-bar");

        fillBar = new VisualElement();
        fillBar.AddToClassList("percentage-bar__fill");
        Add(fillBar);

        valueLabel = new Label("0%");
        valueLabel.AddToClassList("percentage-bar__label");
        Add(valueLabel);
    }
}
```

Usage in UXML:
```xml
<PercentageBar binding-path="m_HealthPercent" />
```

### Limitation

Custom data types that are not supported by `SerializedPropertyType` cannot bind directly. However, nested properties of custom types can be bound individually.

---

## Runtime Binding

Runtime data binding connects properties of any plain C# object to UI control properties. It works in both runtime and Editor contexts.

### When to Use

| Scenario | Binding System |
|---|---|
| Editor Inspector / custom editors | SerializedObject binding |
| Editor UI with serialized data needing undo/redo | SerializedObject binding |
| Runtime game UI | Runtime binding |
| Binding to non-serialized C# objects | Runtime binding |

### Key Concepts

- **Data Sources**: Any C# type can serve as a data source. Assign to elements for child elements to inherit.
- **Binding Modes**: Control synchronization direction (source-to-UI, UI-to-source, two-way).
- **Update Triggers**: Define when binding updates occur (on value change, on frame, etc.).
- **Type Converters**: Transform data between source and UI types when they don't match directly.

### Basic Runtime Binding Example

```csharp
using UnityEngine;
using UnityEngine.UIElements;

// Data source class
public class GameState
{
    public int Score { get; set; }
    public float Health { get; set; }
    public string PlayerName { get; set; }
}

public class GameHUD : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;
    private GameState gameState = new GameState();

    void OnEnable()
    {
        var root = uiDocument.rootVisualElement;

        // Without runtime binding, update manually
        var scoreLabel = root.Q<Label>("score-label");
        var healthBar = root.Q<ProgressBar>("health-bar");

        // Manual update pattern (alternative to runtime binding)
        InvokeRepeating(nameof(UpdateUI), 0f, 0.1f);
    }

    void UpdateUI()
    {
        var root = uiDocument.rootVisualElement;
        root.Q<Label>("score-label").text = $"Score: {gameState.Score}";
        root.Q<ProgressBar>("health-bar").value = gameState.Health;
    }

    // Game logic updates the data
    public void AddScore(int points)
    {
        gameState.Score += points;
    }

    public void TakeDamage(float damage)
    {
        gameState.Health = Mathf.Max(0, gameState.Health - damage);
    }
}
```

### Runtime Binding with INotifyPropertyChanged

For automatic updates, implement `INotifyPropertyChanged` on your data source:

```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;

public class ObservableGameState : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;

    private int score;
    private float health = 100f;
    private string playerName = "Player";

    public int Score
    {
        get => score;
        set { score = value; OnPropertyChanged(); }
    }

    public float Health
    {
        get => health;
        set { health = Mathf.Clamp(value, 0f, 100f); OnPropertyChanged(); }
    }

    public string PlayerName
    {
        get => playerName;
        set { playerName = value; OnPropertyChanged(); }
    }

    protected void OnPropertyChanged([CallerMemberName] string propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
```

### Debugging Bindings

Configure logging levels to troubleshoot binding issues during development. Check the Unity Console for binding error messages when paths don't match or types are incompatible.

Common issues:
- Binding path doesn't match the property/field name
- Type mismatch between UI control and data property
- Forgetting to call `Bind()` on non-Inspector UI
- Calling `Bind()` inside `CreateInspectorGUI()` (causes double-binding)

---

## Practical Patterns

### Inventory Slot with Binding

```csharp
using UnityEngine;
using UnityEngine.UIElements;

[System.Serializable]
public class InventorySlot
{
    [SerializeField] private string m_ItemName;
    [SerializeField] private int m_Quantity;
    [SerializeField] private Sprite m_Icon;
}

// UXML for one slot:
// <ui:BindableElement class="inventory-slot">
//     <ui:Label binding-path="m_ItemName" />
//     <ui:IntegerField binding-path="m_Quantity" />
// </ui:BindableElement>
```

### Settings Panel with Two-Way Binding

```csharp
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

[CreateAssetMenu(menuName = "Settings/Game Settings")]
public class GameSettings : ScriptableObject
{
    [SerializeField] private float m_MasterVolume = 1f;
    [SerializeField] private float m_MusicVolume = 0.8f;
    [SerializeField] private float m_SFXVolume = 0.8f;
    [SerializeField] private bool m_Fullscreen = true;
    [SerializeField] private int m_QualityLevel = 2;
}

// In an EditorWindow or custom inspector:
// var settingsObj = new SerializedObject(gameSettings);
// root.Bind(settingsObj);
```

UXML for the settings panel:
```xml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:Slider label="Master Volume" low-value="0" high-value="1"
               binding-path="m_MasterVolume" />
    <ui:Slider label="Music Volume" low-value="0" high-value="1"
               binding-path="m_MusicVolume" />
    <ui:Slider label="SFX Volume" low-value="0" high-value="1"
               binding-path="m_SFXVolume" />
    <ui:Toggle label="Fullscreen" binding-path="m_Fullscreen" />
    <ui:SliderInt label="Quality Level" low-value="0" high-value="5"
                  binding-path="m_QualityLevel" />
</ui:UXML>
```

---

## Additional Resources

- [SerializedObject Data Binding](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-Binding.html)
- [Runtime Data Binding](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-runtime-binding.html)
- [UI Toolkit Controls](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-Controls.html)
