# uGUI / Canvas System (Legacy)

> Source: Unity 6.3 LTS Documentation (com.unity.ugui@2.0)

uGUI is Unity's older GameObject-based UI system. While UI Toolkit is recommended for new projects, uGUI remains fully supported and is commonly found in existing projects. It uses Canvas, RectTransform, EventSystem, and a set of visual/interaction components.

---

## Canvas

The Canvas is the root container for all uGUI elements. All UI elements must be children of a Canvas GameObject.

### Render Modes

| Mode | Description | Use Case |
|---|---|---|
| **Screen Space - Overlay** | Renders on top of everything. Automatically adjusts to screen size/resolution changes. | Standard HUD, menus, tooltips |
| **Screen Space - Camera** | Rendered in front of a specific camera. Camera settings (perspective, FOV) affect appearance. | UI with depth/perspective effects |
| **World Space** | Canvas behaves like a regular 3D object. Size controlled via RectTransform. Elements layer based on 3D position. | In-world displays, VR interfaces, diegetic UI |

### Setup

A Canvas requires these components:
- `Canvas` -- Defines render mode and sorting order
- `CanvasScaler` -- Controls scaling behavior across screen sizes
- `GraphicRaycaster` -- Enables pointer input detection

```csharp
using UnityEngine;
using UnityEngine.UI;

public class CanvasSetup : MonoBehaviour
{
    void Start()
    {
        // Create Canvas programmatically
        GameObject canvasObj = new GameObject("MainCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 0;

        CanvasScaler scaler = canvasObj.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920, 1080);
        scaler.matchWidthOrHeight = 0.5f;

        canvasObj.AddComponent<GraphicRaycaster>();
    }
}
```

### CanvasScaler Modes

| Scale Mode | Description |
|---|---|
| `ConstantPixelSize` | UI stays same pixel size regardless of screen |
| `ScaleWithScreenSize` | UI scales to match a reference resolution |
| `ConstantPhysicalSize` | UI stays same physical size regardless of DPI |

### Draw Order

Elements render in Hierarchy order: first child drawn first (behind), last child drawn last (on top).

```csharp
// Reorder elements
transform.SetAsFirstSibling();   // Move to back
transform.SetAsLastSibling();    // Move to front
transform.SetSiblingIndex(2);    // Set specific order
```

### Multiple Canvases

Split static and dynamic content into separate Canvases. When any child of a Canvas changes, the entire Canvas is rebuilt. Separating frequently-changing elements (health bars, timers) from static elements (backgrounds, frames) improves performance.

```csharp
// Nested Canvas inherits parent render mode by default
// Set overrideSorting to control layer order independently
Canvas nestedCanvas = nestedObj.GetComponent<Canvas>();
nestedCanvas.overrideSorting = true;
nestedCanvas.sortingOrder = 10;
```

---

## RectTransform

All uGUI elements use `RectTransform` instead of `Transform`. RectTransform adds anchoring, pivot, and explicit width/height.

### Anchors

Anchors define how a child positions/sizes relative to its parent using fractional coordinates:
- `anchorMin` -- Lower-left anchor point (0,0 = parent's lower-left)
- `anchorMax` -- Upper-right anchor point (1,1 = parent's upper-right)
- Values range from 0.0 to 1.0

**When anchors are together (anchorMin == anchorMax):** Element has fixed size, positioned relative to anchor point.
- Fields: Pos X, Pos Y, Width, Height

**When anchors are separated:** Element stretches with parent.
- Fields: Left, Right, Top, Bottom (padding from anchor edges)

### Common Anchor Presets

| Preset | anchorMin | anchorMax | Effect |
|---|---|---|---|
| Center | (0.5, 0.5) | (0.5, 0.5) | Fixed size at center |
| Top-Left | (0, 1) | (0, 1) | Fixed size at top-left |
| Bottom-Right | (1, 0) | (1, 0) | Fixed size at bottom-right |
| Stretch Horizontal | (0, 0.5) | (1, 0.5) | Stretches width with parent |
| Stretch Full | (0, 0) | (1, 1) | Fills entire parent |
| Left Side | (0, 0) | (0, 1) | Stretches height on left edge |

### Pivot

The pivot is the local center point for rotation, scaling, and position. Values are fractions (0 to 1):
- (0.5, 0.5) = center
- (0, 0) = bottom-left corner
- (1, 1) = upper-right corner

### RectTransform in C#

```csharp
using UnityEngine;

public class UIPositioning : MonoBehaviour
{
    [SerializeField] private RectTransform panel;

    void Start()
    {
        // Set anchors to center
        panel.anchorMin = new Vector2(0.5f, 0.5f);
        panel.anchorMax = new Vector2(0.5f, 0.5f);
        panel.pivot = new Vector2(0.5f, 0.5f);

        // Set position and size
        panel.anchoredPosition = new Vector2(0, 0);
        panel.sizeDelta = new Vector2(400, 300);

        // Stretch to fill parent with margins
        panel.anchorMin = Vector2.zero;
        panel.anchorMax = Vector2.one;
        panel.offsetMin = new Vector2(20, 20);   // left, bottom padding
        panel.offsetMax = new Vector2(-20, -20);  // right, top padding (negative)
    }

    // Move UI element to world position
    public void PositionAtWorldPoint(RectTransform element, Camera cam, Canvas canvas, Vector3 worldPos)
    {
        Vector2 screenPos = cam.WorldToScreenPoint(worldPos);
        RectTransformUtility.ScreenPointToLocalPointInRectangle(
            canvas.transform as RectTransform, screenPos, cam, out Vector2 localPoint);
        element.anchoredPosition = localPoint;
    }
}
```

---

## Layout Groups

Auto Layout components automatically arrange child elements.

### Horizontal Layout Group

Arranges children in a horizontal row.

```csharp
using UnityEngine;
using UnityEngine.UI;

public class LayoutSetup : MonoBehaviour
{
    void Start()
    {
        var hlg = gameObject.AddComponent<HorizontalLayoutGroup>();
        hlg.spacing = 10f;
        hlg.padding = new RectOffset(10, 10, 5, 5); // left, right, top, bottom
        hlg.childAlignment = TextAnchor.MiddleCenter;
        hlg.childControlWidth = true;
        hlg.childControlHeight = true;
        hlg.childForceExpandWidth = false;
        hlg.childForceExpandHeight = false;
    }
}
```

### Vertical Layout Group

Same as Horizontal but arranges children vertically.

### Grid Layout Group

Arranges children in a grid.

```csharp
var grid = gameObject.AddComponent<GridLayoutGroup>();
grid.cellSize = new Vector2(100, 100);
grid.spacing = new Vector2(10, 10);
grid.startCorner = GridLayoutGroup.Corner.UpperLeft;
grid.startAxis = GridLayoutGroup.Axis.Horizontal;
grid.constraint = GridLayoutGroup.Constraint.FixedColumnCount;
grid.constraintCount = 4;
grid.padding = new RectOffset(10, 10, 10, 10);
```

### Content Size Fitter

Automatically sizes an element based on its content.

```csharp
var fitter = gameObject.AddComponent<ContentSizeFitter>();
fitter.horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
fitter.verticalFit = ContentSizeFitter.FitMode.PreferredSize;
```

Fit modes: `Unconstrained`, `MinSize`, `PreferredSize`

### Aspect Ratio Fitter

Maintains a specific width-to-height ratio.

```csharp
var arFitter = gameObject.AddComponent<AspectRatioFitter>();
arFitter.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
arFitter.aspectRatio = 16f / 9f;
```

Aspect modes: `None`, `WidthControlsHeight`, `HeightControlsWidth`, `FitInParent`, `EnvelopeParent`

### Layout Element

Overrides automatic sizing for individual elements.

```csharp
var layoutElem = gameObject.AddComponent<LayoutElement>();
layoutElem.minWidth = 100;
layoutElem.minHeight = 50;
layoutElem.preferredWidth = 200;
layoutElem.preferredHeight = 100;
layoutElem.flexibleWidth = 1;  // Grows to fill extra space
layoutElem.flexibleHeight = 0;
```

**Sizing allocation order:**
1. Minimum sizes allocated first
2. Preferred sizes if space available
3. Flexible sizes for remaining space

---

## EventSystem

The EventSystem manages input-based event delivery to GameObjects. One EventSystem must exist in the scene for any uGUI input to work.

### Components

| Component | Purpose |
|---|---|
| `EventSystem` | Central dispatcher, manages selection state |
| `StandaloneInputModule` | Handles keyboard/mouse/controller input |
| `GraphicRaycaster` | Detects pointer events on Canvas UI elements |
| `PhysicsRaycaster` | Detects pointer events on 3D colliders |
| `Physics2DRaycaster` | Detects pointer events on 2D colliders |

### Event Interfaces

Implement these on MonoBehaviours attached to UI or world-space objects:

```csharp
using UnityEngine;
using UnityEngine.EventSystems;

public class InteractableObject : MonoBehaviour,
    IPointerClickHandler,
    IPointerEnterHandler,
    IPointerExitHandler,
    IDragHandler,
    IBeginDragHandler,
    IEndDragHandler,
    IDropHandler
{
    public void OnPointerClick(PointerEventData eventData)
    {
        Debug.Log($"Clicked: {gameObject.name}");
    }

    public void OnPointerEnter(PointerEventData eventData)
    {
        // Highlight
    }

    public void OnPointerExit(PointerEventData eventData)
    {
        // Remove highlight
    }

    public void OnBeginDrag(PointerEventData eventData)
    {
        Debug.Log("Drag started");
    }

    public void OnDrag(PointerEventData eventData)
    {
        transform.position = eventData.position;
    }

    public void OnEndDrag(PointerEventData eventData)
    {
        Debug.Log("Drag ended");
    }

    public void OnDrop(PointerEventData eventData)
    {
        // Handle dropped item
        var dragged = eventData.pointerDrag;
        Debug.Log($"{dragged.name} dropped on {gameObject.name}");
    }
}
```

### Common Event Interfaces

| Interface | Triggered When |
|---|---|
| `IPointerClickHandler` | Pointer clicked |
| `IPointerDownHandler` | Pointer pressed |
| `IPointerUpHandler` | Pointer released |
| `IPointerEnterHandler` | Pointer enters element |
| `IPointerExitHandler` | Pointer exits element |
| `IDragHandler` | During drag |
| `IBeginDragHandler` | Drag starts |
| `IEndDragHandler` | Drag ends |
| `IDropHandler` | Object dropped on element |
| `IScrollHandler` | Scroll wheel input |
| `ISelectHandler` | Element selected |
| `IDeselectHandler` | Element deselected |
| `ISubmitHandler` | Submit action (Enter key) |
| `ICancelHandler` | Cancel action (Escape key) |

---

## Interaction Components

### Button

```csharp
using UnityEngine;
using UnityEngine.UI;

public class ButtonExample : MonoBehaviour
{
    [SerializeField] private Button myButton;
    [SerializeField] private Image buttonImage;

    void OnEnable()
    {
        myButton.onClick.AddListener(OnButtonClicked);
    }

    void OnDisable()
    {
        myButton.onClick.RemoveListener(OnButtonClicked);
    }

    void OnButtonClicked()
    {
        Debug.Log("Button clicked!");
    }

    // Programmatic state
    void DisableButton()
    {
        myButton.interactable = false;
    }
}
```

### Toggle and ToggleGroup

```csharp
[SerializeField] private Toggle soundToggle;
[SerializeField] private ToggleGroup difficultyGroup;

void OnEnable()
{
    soundToggle.onValueChanged.AddListener(OnSoundToggled);
}

void OnSoundToggled(bool isOn)
{
    AudioListener.volume = isOn ? 1f : 0f;
}

// Get active toggle from group
Toggle activeToggle = difficultyGroup.GetFirstActiveToggle();
```

### Slider

```csharp
[SerializeField] private Slider healthSlider;

void OnEnable()
{
    healthSlider.minValue = 0;
    healthSlider.maxValue = 100;
    healthSlider.wholeNumbers = true;
    healthSlider.onValueChanged.AddListener(OnHealthChanged);
}

void OnHealthChanged(float value)
{
    Debug.Log($"Health: {value}");
}

// Set without triggering callback
void SetHealth(float health)
{
    healthSlider.SetValueWithoutNotify(health);
}
```

### Dropdown

```csharp
using UnityEngine.UI;
using System.Collections.Generic;

[SerializeField] private Dropdown resolutionDropdown;

void Start()
{
    var options = new List<Dropdown.OptionData>
    {
        new Dropdown.OptionData("1920x1080"),
        new Dropdown.OptionData("1280x720"),
        new Dropdown.OptionData("800x600")
    };
    resolutionDropdown.options = options;
    resolutionDropdown.onValueChanged.AddListener(OnResolutionChanged);
}

void OnResolutionChanged(int index)
{
    Debug.Log($"Selected resolution index: {index}");
}
```

### InputField

```csharp
[SerializeField] private InputField nameInput;

void OnEnable()
{
    nameInput.characterLimit = 20;
    nameInput.contentType = InputField.ContentType.Alphanumeric;
    nameInput.onEndEdit.AddListener(OnNameSubmitted);
    nameInput.onValueChanged.AddListener(OnNameTyping);
}

void OnNameSubmitted(string text) => Debug.Log($"Submitted: {text}");
void OnNameTyping(string text) => Debug.Log($"Typing: {text}");
```

### ScrollRect (Scroll View)

```csharp
using UnityEngine.UI;

[SerializeField] private ScrollRect scrollRect;

void Start()
{
    scrollRect.horizontal = false;
    scrollRect.vertical = true;
    scrollRect.movementType = ScrollRect.MovementType.Elastic;
    scrollRect.elasticity = 0.1f;
    scrollRect.inertia = true;
    scrollRect.decelerationRate = 0.135f;
    scrollRect.scrollSensitivity = 10f;

    scrollRect.onValueChanged.AddListener(OnScrollChanged);
}

void OnScrollChanged(Vector2 normalizedPos)
{
    // normalizedPos.y: 1 = top, 0 = bottom
    Debug.Log($"Scroll position: {normalizedPos}");
}

// Scroll to top
void ScrollToTop() => scrollRect.normalizedPosition = new Vector2(0, 1);
```

---

## Visual Components

### Image

```csharp
using UnityEngine;
using UnityEngine.UI;

[SerializeField] private Image iconImage;
[SerializeField] private Sprite newSprite;

void UpdateImage()
{
    iconImage.sprite = newSprite;
    iconImage.color = Color.white;
    iconImage.type = Image.Type.Sliced;    // Simple, Sliced, Tiled, Filled
    iconImage.fillAmount = 0.75f;          // For Filled type
    iconImage.preserveAspect = true;
    iconImage.raycastTarget = false;       // Disable if not interactive
}
```

### Text (Legacy -- use TextMeshPro instead)

```csharp
using UnityEngine.UI;

[SerializeField] private Text scoreText;

void UpdateScore(int score)
{
    scoreText.text = $"Score: {score}";
    scoreText.fontSize = 24;
    scoreText.alignment = TextAnchor.MiddleCenter;
    scoreText.color = Color.white;
}
```

---

## Performance Tips

1. **Separate dynamic and static Canvases** -- Any change to a child triggers a Canvas rebuild.
2. **Disable `raycastTarget`** on non-interactive elements (Labels, decorative Images).
3. **Use object pooling** for dynamic lists instead of Instantiate/Destroy.
4. **Avoid layout groups on frequently-updated UI** -- Layout recalculation is expensive.
5. **Use `Canvas.willRenderCanvases`** callback for batch updates.
6. **Minimize overdraw** -- Reduce overlapping transparent UI elements.
7. **Use Sprite Atlases** for UI sprites to reduce draw calls.

---

## Additional Resources

- [Canvas](https://docs.unity3d.com/Packages/com.unity.ugui@2.0/manual/UICanvas.html)
- [Basic Layout](https://docs.unity3d.com/Packages/com.unity.ugui@2.0/manual/UIBasicLayout.html)
- [Auto Layout](https://docs.unity3d.com/Packages/com.unity.ugui@2.0/manual/UIAutoLayout.html)
- [Interaction Components](https://docs.unity3d.com/Packages/com.unity.ugui@2.0/manual/UIInteractionComponents.html)
- [Event System](https://docs.unity3d.com/Packages/com.unity.ugui@2.0/manual/EventSystem.html)
