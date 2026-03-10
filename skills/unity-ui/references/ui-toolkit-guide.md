# UI Toolkit Complete Guide

> Source: Unity 6.3 LTS Documentation

UI Toolkit is Unity's recommended UI framework for new projects. It uses a retained-mode rendering model inspired by web technologies: UXML for structure, USS for styling, and C# for behavior.

---

## Visual Elements

All UI Toolkit elements inherit from `VisualElement`. The visual tree is a hierarchy of elements rooted at `rootVisualElement`.

### Common Built-in Elements

| Element | C# Type | Purpose |
|---|---|---|
| `<ui:VisualElement>` | `VisualElement` | Generic container |
| `<ui:Label>` | `Label` | Display text |
| `<ui:Button>` | `Button` | Clickable button |
| `<ui:Toggle>` | `Toggle` | Checkbox / boolean switch |
| `<ui:TextField>` | `TextField` | Single-line text input |
| `<ui:IntegerField>` | `IntegerField` | Integer input |
| `<ui:FloatField>` | `FloatField` | Float input |
| `<ui:Slider>` | `Slider` | Horizontal slider (float) |
| `<ui:SliderInt>` | `SliderInt` | Horizontal slider (int) |
| `<ui:MinMaxSlider>` | `MinMaxSlider` | Range slider |
| `<ui:DropdownField>` | `DropdownField` | Dropdown selection |
| `<ui:RadioButton>` | `RadioButton` | Single radio option |
| `<ui:RadioButtonGroup>` | `RadioButtonGroup` | Mutually exclusive options |
| `<ui:Foldout>` | `Foldout` | Collapsible section |
| `<ui:ScrollView>` | `ScrollView` | Scrollable container |
| `<ui:ListView>` | `ListView` | Virtualized list |
| `<ui:TreeView>` | `TreeView` | Hierarchical tree |
| `<ui:GroupBox>` | `GroupBox` | Labeled group container |
| `<ui:ProgressBar>` | `ProgressBar` | Progress indicator |
| `<ui:Image>` | `Image` | Display texture/sprite |

### Creating Elements in C#

```csharp
using UnityEngine;
using UnityEngine.UIElements;

public class UISetup : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    void OnEnable()
    {
        var root = uiDocument.rootVisualElement;

        // Labels
        var title = new Label("Game Title");
        title.AddToClassList("title");
        root.Add(title);

        // Buttons
        var button = new Button(() => Debug.Log("Clicked!"));
        button.text = "Start Game";
        button.name = "start-btn";
        root.Add(button);

        // Toggle
        var toggle = new Toggle("Enable Sound") { value = true };
        root.Add(toggle);

        // Slider
        var slider = new Slider("Brightness", 0f, 1f) { value = 0.5f };
        root.Add(slider);

        // TextField
        var textField = new TextField("Player Name");
        textField.maxLength = 20;
        root.Add(textField);

        // DropdownField
        var dropdown = new DropdownField(
            "Difficulty",
            new System.Collections.Generic.List<string> { "Easy", "Normal", "Hard" },
            0
        );
        root.Add(dropdown);

        // ScrollView
        var scrollView = new ScrollView(ScrollViewMode.Vertical);
        for (int i = 0; i < 50; i++)
            scrollView.Add(new Label($"Item {i}"));
        root.Add(scrollView);

        // ListView (virtualized)
        var items = new System.Collections.Generic.List<string>();
        for (int i = 0; i < 1000; i++) items.Add($"Entry {i}");

        var listView = new ListView(items, 30, () => new Label(), (element, index) =>
        {
            (element as Label).text = items[index];
        });
        listView.style.height = 300;
        root.Add(listView);
    }
}
```

### Loading UXML at Runtime

```csharp
// Load from Resources
var tree = Resources.Load<VisualTreeAsset>("UI/MainMenu");
var instance = tree.Instantiate();
root.Add(instance);

// Load from SerializeField
[SerializeField] private VisualTreeAsset menuTemplate;

void OnEnable()
{
    var instance = menuTemplate.Instantiate();
    uiDocument.rootVisualElement.Add(instance);
}
```

---

## Querying Elements (UQuery)

UQuery provides CSS-selector-like queries to find elements in the visual tree.

```csharp
var root = uiDocument.rootVisualElement;

// Query by name (returns first match)
Button playBtn = root.Q<Button>("play-button");

// Query by class
VisualElement highlighted = root.Q<VisualElement>(className: "highlighted");

// Query by type (first Label anywhere in tree)
Label firstLabel = root.Q<Label>();

// Query multiple elements
var allButtons = root.Query<Button>().ToList();

// Query by class, multiple results
var menuItems = root.Query<VisualElement>(className: "menu-item").ToList();

// Chained query: buttons inside a specific container
var containerBtns = root.Q<VisualElement>("button-container")
                        .Query<Button>().ToList();

// ForEach on query results
root.Query<Button>(className: "menu-btn").ForEach(btn =>
{
    btn.RegisterCallback<ClickEvent>(OnMenuButtonClicked);
});

// Query child elements of compound controls
var dragContainer = slider.Q("unity-drag-container");
```

---

## USS Styling Reference

USS (Unity Style Sheets) use CSS-like syntax. Files have the `.uss` extension.

### Selector Types

```css
/* Type selector -- matches all elements of this type */
Button { }

/* Class selector -- matches elements with this class */
.primary { }

/* Name selector -- matches element with this name */
#main-menu { }

/* Universal selector -- matches everything */
* { }

/* Descendant selector -- Button anywhere inside .panel */
.panel Button { }

/* Child selector -- direct children only */
.panel > Button { }

/* Multiple selectors -- must match all */
Button.primary { }

/* Selector list -- shared styles */
.btn-play, .btn-settings, .btn-quit {
    height: 40px;
}

/* Pseudo-classes */
Button:hover { }
Button:active { }
Button:focus { }
Button:disabled { }
Toggle:checked { }
```

### Selector Precedence

Specificity follows CSS-like rules. More specific selectors override less specific ones. Inline styles (set via C# `element.style`) override USS.

### BEM Naming Convention (Recommended)

BEM (Block Element Modifier) reduces the need for complex selectors:

```css
/* Block */
.inventory { }

/* Element (part of block) */
.inventory__slot { }
.inventory__item-icon { }
.inventory__item-count { }

/* Modifier (variant) */
.inventory__slot--empty { }
.inventory__slot--selected { }
.inventory__item-count--low { }
```

```csharp
// Apply BEM classes in C#
slotElement.AddToClassList("inventory__slot");
if (isEmpty) slotElement.AddToClassList("inventory__slot--empty");
```

### Layout Properties (Flexbox)

USS uses the Yoga flexbox engine. Default `flex-direction` is `column`.

```css
.container {
    /* Direction and wrapping */
    flex-direction: row;            /* row | row-reverse | column | column-reverse */
    flex-wrap: wrap;                /* nowrap | wrap | wrap-reverse */

    /* Main-axis alignment */
    justify-content: space-between; /* flex-start | flex-end | center | space-between | space-around */

    /* Cross-axis alignment */
    align-items: center;            /* auto | flex-start | flex-end | center | stretch */
    align-content: flex-start;      /* flex-start | flex-end | center | stretch */
}

.item {
    /* Item flex properties */
    flex-grow: 1;                   /* Growth factor */
    flex-shrink: 0;                 /* Shrinkage factor */
    flex-basis: auto;               /* Base size */
    flex: 1 0 auto;                 /* Shorthand: grow shrink basis */
    align-self: flex-end;           /* Override parent align-items */
}
```

### Sizing, Margins, Padding

```css
.panel {
    /* Sizing */
    width: 300px;
    height: 200px;
    min-width: 100px;
    max-width: 500px;
    aspect-ratio: 16 / 9;

    /* Margins (outside) */
    margin: 10px;                   /* all sides */
    margin: 10px 20px;             /* vertical horizontal */
    margin: 10px 20px 10px 20px;   /* top right bottom left */

    /* Padding (inside) */
    padding: 16px;

    /* Positioning */
    position: relative;             /* relative (default) | absolute */
    left: 10px;
    top: 10px;
}
```

### Visual Properties

```css
.card {
    /* Background */
    background-color: rgba(0, 0, 0, 0.8);
    background-image: url("project://database/Assets/Textures/bg.png");
    -unity-background-scale-mode: scale-to-fit;  /* stretch-to-fill | scale-and-crop | scale-to-fit */
    -unity-background-image-tint-color: #FFFFFF80;

    /* Borders */
    border-width: 2px;
    border-color: #FFD700;
    border-radius: 8px;

    /* 9-slice for sprites */
    -unity-slice-left: 10;
    -unity-slice-right: 10;
    -unity-slice-top: 10;
    -unity-slice-bottom: 10;

    /* Visibility */
    opacity: 0.9;
    display: flex;                  /* flex | none */
    visibility: visible;            /* visible | hidden */
    overflow: hidden;               /* visible | hidden */
}
```

### Text Properties

```css
.heading {
    color: #FFFFFF;
    font-size: 24px;
    -unity-font-style: bold;           /* normal | italic | bold | bold-and-italic */
    -unity-text-align: middle-center;  /* upper/middle/lower - left/center/right */
    white-space: normal;               /* normal | nowrap | pre | pre-wrap */
    text-overflow: ellipsis;           /* clip | ellipsis */
    letter-spacing: 2px;
    word-spacing: 4px;

    /* Text outline */
    -unity-text-outline-width: 1px;
    -unity-text-outline-color: #000000;

    /* Text shadow */
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);

    /* Auto-size text */
    -unity-text-auto-size: best-fit 10 48;

    /* Font asset */
    -unity-font-definition: url("project://database/Assets/Fonts/MyFont.asset");
}
```

### USS Variables (Custom Properties)

```css
:root {
    --color-primary: #4CAF50;
    --color-secondary: #2196F3;
    --color-danger: #F44336;
    --spacing-sm: 4px;
    --spacing-md: 8px;
    --spacing-lg: 16px;
    --border-radius: 4px;
    --font-size-body: 14px;
    --font-size-heading: 24px;
}

.btn-primary {
    background-color: var(--color-primary);
    border-radius: var(--border-radius);
    padding: var(--spacing-md) var(--spacing-lg);
    font-size: var(--font-size-body);
}
```

### Applying Styles Programmatically

```csharp
// Add USS class
element.AddToClassList("active");

// Remove USS class
element.RemoveFromClassList("active");

// Toggle class
element.ToggleInClassList("selected");

// Check class
bool hasClass = element.ClassListContains("active");

// Inline style (overrides USS -- avoid when possible)
element.style.backgroundColor = new Color(1, 0, 0, 0.5f);
element.style.width = 200;
element.style.height = new Length(50, LengthUnit.Percent);
element.style.display = DisplayStyle.None;

// Load and apply stylesheet from C#
var styleSheet = Resources.Load<StyleSheet>("UI/Styles/MainTheme");
root.styleSheets.Add(styleSheet);
```

---

## Event System

### Event Propagation

Events flow through three phases:
1. **Trickle-down**: Root to target
2. **Target**: On the target element itself
3. **Bubble-up**: Target back to root

```csharp
// Bubble-up (default) -- handle after children
element.RegisterCallback<PointerDownEvent>(evt =>
{
    Debug.Log($"Pointer down at {evt.position}");
});

// Trickle-down -- handle before children
parent.RegisterCallback<PointerDownEvent>(evt =>
{
    Debug.Log("Parent intercepting before children");
}, TrickleDown.TrickleDown);

// Stop propagation (prevent further handlers)
element.RegisterCallback<ClickEvent>(evt =>
{
    evt.StopPropagation();
});
```

### Common Event Types

| Event | Trigger |
|---|---|
| `ClickEvent` | Element clicked (down + up on same element) |
| `PointerDownEvent` | Pointer pressed |
| `PointerUpEvent` | Pointer released |
| `PointerMoveEvent` | Pointer moved |
| `PointerEnterEvent` | Pointer enters element |
| `PointerLeaveEvent` | Pointer leaves element |
| `KeyDownEvent` | Key pressed |
| `KeyUpEvent` | Key released |
| `FocusInEvent` | Element gains focus |
| `FocusOutEvent` | Element loses focus |
| `ChangeEvent<T>` | Value changed on control |
| `GeometryChangedEvent` | Element size/position changed |
| `AttachToPanelEvent` | Element added to panel |
| `DetachFromPanelEvent` | Element removed from panel |

### Value Change Handling

```csharp
// RegisterValueChangedCallback is shorthand for RegisterCallback<ChangeEvent<T>>
slider.RegisterValueChangedCallback(evt =>
{
    float oldVal = evt.previousValue;
    float newVal = evt.newValue;
    Debug.Log($"Slider changed from {oldVal} to {newVal}");
});

// Unregister
slider.UnregisterValueChangedCallback(myCallback);

// Set value without triggering event
slider.SetValueWithoutNotify(0.5f);
```

### Custom Data with Callbacks

```csharp
element.RegisterCallback<ClickEvent, int>(HandleClick, 42);

void HandleClick(ClickEvent evt, int data)
{
    Debug.Log($"Clicked with data: {data}");
}
```

---

## Responsive Design

### Percentage-Based Layout

```css
.responsive-container {
    width: 100%;
    height: 100%;
    flex-direction: row;
    flex-wrap: wrap;
}

.responsive-panel {
    min-width: 200px;
    flex-grow: 1;
    flex-basis: 30%;
}
```

### Adapting to Screen Size in C#

```csharp
void OnEnable()
{
    var root = uiDocument.rootVisualElement;
    root.RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
}

void OnGeometryChanged(GeometryChangedEvent evt)
{
    var root = uiDocument.rootVisualElement;
    float width = root.resolvedStyle.width;

    if (width < 600)
    {
        root.RemoveFromClassList("layout-wide");
        root.AddToClassList("layout-narrow");
    }
    else
    {
        root.RemoveFromClassList("layout-narrow");
        root.AddToClassList("layout-wide");
    }
}
```

```css
.layout-wide {
    flex-direction: row;
}

.layout-narrow {
    flex-direction: column;
}
```

---

## Manipulators

Manipulators are state machines that separate interaction logic from UI elements.

### Built-in Manipulators

| Class | Purpose |
|---|---|
| `Manipulator` | Base class |
| `PointerManipulator` | Pointer input with activation filters |
| `MouseManipulator` | Mouse-specific input handling |
| `Clickable` | Click detection (press + release) |
| `ContextualMenuManipulator` | Right-click context menus |
| `KeyboardNavigationManipulator` | Keyboard navigation |

### Creating a Custom Manipulator

```csharp
using UnityEngine;
using UnityEngine.UIElements;

public class ResizeManipulator : PointerManipulator
{
    private Vector2 startSize;
    private Vector3 startPointer;
    private bool isResizing;

    public ResizeManipulator()
    {
        activators.Add(new ManipulatorActivationFilter { button = MouseButton.LeftMouse });
    }

    protected override void RegisterCallbacksOnTarget()
    {
        target.RegisterCallback<PointerDownEvent>(OnPointerDown);
        target.RegisterCallback<PointerMoveEvent>(OnPointerMove);
        target.RegisterCallback<PointerUpEvent>(OnPointerUp);
    }

    protected override void UnregisterCallbacksFromTarget()
    {
        target.UnregisterCallback<PointerDownEvent>(OnPointerDown);
        target.UnregisterCallback<PointerMoveEvent>(OnPointerMove);
        target.UnregisterCallback<PointerUpEvent>(OnPointerUp);
    }

    private void OnPointerDown(PointerDownEvent evt)
    {
        if (!CanStartManipulation(evt)) return;
        startPointer = evt.position;
        startSize = new Vector2(target.resolvedStyle.width, target.resolvedStyle.height);
        isResizing = true;
        target.CapturePointer(evt.pointerId);
        evt.StopPropagation();
    }

    private void OnPointerMove(PointerMoveEvent evt)
    {
        if (!isResizing) return;
        var delta = evt.position - startPointer;
        target.style.width = Mathf.Max(50, startSize.x + delta.x);
        target.style.height = Mathf.Max(50, startSize.y + delta.y);
    }

    private void OnPointerUp(PointerUpEvent evt)
    {
        if (!isResizing) return;
        isResizing = false;
        target.ReleasePointer(evt.pointerId);
        evt.StopPropagation();
    }
}

// Attach to element:
myPanel.AddManipulator(new ResizeManipulator());
```

### Context Menu Example

```csharp
element.AddManipulator(new ContextualMenuManipulator(evt =>
{
    evt.menu.AppendAction("Copy", action => CopyItem());
    evt.menu.AppendAction("Paste", action => PasteItem());
    evt.menu.AppendAction("Delete", action => DeleteItem(),
        DropdownMenuAction.Status.Normal);
}));
```

---

## Element State Management

```csharp
// Enable/disable
element.SetEnabled(false);  // Adds :disabled pseudo-class

// Show/hide
element.style.display = DisplayStyle.None;   // Hidden, removed from layout
element.style.display = DisplayStyle.Flex;   // Visible
element.style.visibility = Visibility.Hidden; // Hidden but occupies space

// Tooltip
element.tooltip = "Click to start the game";

// Focus
element.focusable = true;
element.Focus();
```

---

## Performance Best Practices

1. **Use USS files over inline styles** -- USS rules are shared; inline styles allocate per-element.
2. **Prefer class selectors** -- Faster than complex descendant selectors.
3. **Use BEM naming** -- Eliminates deep selector chains.
4. **Minimize `:hover` on parent elements** -- Mouse movement invalidates targeted subtrees.
5. **Use `ListView` for long lists** -- Virtualized rendering, only visible items exist.
6. **Avoid rebuilding the tree** -- Update existing elements rather than removing and recreating.
7. **Pool custom elements** -- Reuse `VisualElement` instances when showing/hiding dynamic content.
8. **Use `GeometryChangedEvent`** -- Instead of polling for layout changes.

---

## Additional Resources

- [UI Toolkit Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/UIToolkits.html)
- [Simple UI Toolkit Workflow](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-simple-ui-toolkit-workflow.html)
- [USS Styling](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-USS.html)
- [USS Supported Properties](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-USS-SupportedProperties.html)
- [USS Best Practices](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-USS-WritingStyleSheets.html)
- [UXML Format](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-UXML.html)
- [USS Selectors](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-USS-Selectors.html)
- [Event Handling](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-Events-Handling.html)
- [Manipulators](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-manipulators.html)
- [Controls Reference](https://docs.unity3d.com/6000.3/Documentation/Manual/UIE-Controls.html)
