---
name: unity-ui-patterns
description: >
  Unity UI/UX pattern design-to-code translation. Screen flow architecture,
  View/ViewModel separation, HUD architecture, feedback & juice systems,
  dynamic list/grid views, transition & animation contracts. UI Toolkit only.
  DESIGN INTENT format: INTENT/WRONG/RIGHT/SCAFFOLD/DESIGN HOOK. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.uxml"
  - "**/*.uss"
---

# UI/UX Patterns -- Design Translation Patterns

> **Prerequisite skills:** `unity-ui` (UI Toolkit API, USS/UXML, data binding), `unity-async-patterns` (async transitions, cancellation), `unity-game-architecture` (events, Service Locator)

Claude builds UI as monolithic scripts mixing data fetching, display, and animation. Works for one screen, unmaintainable when a designer adds transitions, dynamic lists, or multiple screens. These patterns separate structure from behavior, make screens composable, and keep juice designer-configurable.

---

## PATTERN: Screen Flow Architecture

DESIGN INTENT: Game has multiple screens (MainMenu, Settings, Inventory, HUD, PauseMenu) with navigation flows and back-button support.

WRONG:
```csharp
// One MonoBehaviour per screen with direct references -- breaks on every new screen
public class MainMenu : MonoBehaviour
{
    [SerializeField] private GameObject settingsPanel;
    [SerializeField] private GameObject inventoryPanel;

    public void OnSettingsClicked()
    {
        gameObject.SetActive(false);
        settingsPanel.SetActive(true); // Direct coupling
    }

    public void OnBackFromSettings()
    {
        settingsPanel.SetActive(false);
        gameObject.SetActive(true); // Every screen knows every other screen
    }
}
```

RIGHT: `ScreenManager` with stack-based navigation (push/pop). Each screen implements `IScreen` with `ShowAsync`/`HideAsync`. Screens loaded from UXML templates via `UIDocument`. Navigation decoupled from screen logic -- screens never reference each other.

SCAFFOLD:
```csharp
using System;
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Contract for all navigable screens.
/// </summary>
public interface IScreen
{
    /// <summary>Display name used for debugging and stack inspection.</summary>
    string ScreenName { get; }

    /// <summary>Transition the screen into view.</summary>
    Awaitable ShowAsync(CancellationToken ct);

    /// <summary>Transition the screen out of view.</summary>
    Awaitable HideAsync(CancellationToken ct);
}

/// <summary>
/// Stack-based screen navigator. Push screens to go forward, pop to go back.
/// </summary>
public class ScreenManager : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    private readonly System.Collections.Generic.Stack<IScreen> _screenStack = new();
    private bool _isTransitioning;

    public static ScreenManager Instance { get; private set; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() => Instance = null;

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
    }

    /// <summary>Push a new screen onto the stack, hiding the current one.</summary>
    public async Awaitable PushAsync(IScreen screen)
    {
        if (_isTransitioning) return;
        _isTransitioning = true;

        var ct = destroyCancellationToken;

        if (_screenStack.TryPeek(out var current))
        {
            await current.HideAsync(ct);
        }

        _screenStack.Push(screen);
        await screen.ShowAsync(ct);

        _isTransitioning = false;
    }

    /// <summary>Pop the current screen and reveal the one beneath it.</summary>
    public async Awaitable PopAsync()
    {
        if (_isTransitioning || _screenStack.Count <= 1) return;
        _isTransitioning = true;

        var ct = destroyCancellationToken;
        var leaving = _screenStack.Pop();
        await leaving.HideAsync(ct);

        if (_screenStack.TryPeek(out var revealed))
        {
            await revealed.ShowAsync(ct);
        }

        _isTransitioning = false;
    }
}
```

DESIGN HOOK: New screens = implement `IScreen` + UXML template; navigation via `ScreenManager.PushAsync(screen)` / `PopAsync()`. Screens know nothing about each other.

GOTCHA: Screen stack must handle edge cases: pushing same screen twice, popping last screen, pushing during transition. The scaffold guards against transition overlap with `_isTransitioning`. To prevent duplicate pushes, check `_screenStack.Peek() != screen` before pushing.

---

## PATTERN: View/ViewModel Separation

DESIGN INTENT: UI displays data from multiple systems (health, inventory, quests) and updates reactively.

WRONG:
```csharp
// UI script queries game systems directly every frame
public class InventoryUI : MonoBehaviour
{
    [SerializeField] private UIDocument doc;

    void Update()
    {
        // Polling every frame, tightly coupled to game internals
        var root = doc.rootVisualElement;
        var items = GameManager.Instance.Player.Inventory.Items;
        for (int i = 0; i < items.Count; i++)
        {
            root.Q<Label>($"item-{i}").text = items[i].Name;
            root.Q<Label>($"count-{i}").text = items[i].Count.ToString();
        }
    }
}
```

RIGHT: ViewModel (plain C# class) adapts game data to display data, exposes C# events on change. View binds VisualElements to ViewModel properties. ViewModel has no dependency on VisualElement. Game systems update the ViewModel; View reacts.

SCAFFOLD:
```csharp
using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;

/// <summary>
/// ViewModel adapting inventory data for display.
/// No dependency on UnityEngine.UIElements.
/// </summary>
public class InventoryViewModel : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;

    private string _selectedItemName = "";
    private int _selectedItemCount;
    private int _totalItems;

    /// <summary>Name of the currently selected item.</summary>
    public string SelectedItemName
    {
        get => _selectedItemName;
        set { _selectedItemName = value; OnPropertyChanged(); }
    }

    /// <summary>Stack count of the selected item.</summary>
    public int SelectedItemCount
    {
        get => _selectedItemCount;
        set { _selectedItemCount = value; OnPropertyChanged(); }
    }

    /// <summary>Total number of distinct items in inventory.</summary>
    public int TotalItems
    {
        get => _totalItems;
        set { _totalItems = value; OnPropertyChanged(); }
    }

    private void OnPropertyChanged([CallerMemberName] string name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
```

```csharp
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// View that binds VisualElements to InventoryViewModel properties.
/// </summary>
public class InventoryView : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    private InventoryViewModel _viewModel;
    private Label _itemNameLabel;
    private Label _itemCountLabel;
    private Label _totalLabel;

    /// <summary>Bind the view to a ViewModel instance.</summary>
    public void Bind(InventoryViewModel viewModel)
    {
        if (_viewModel != null)
            _viewModel.PropertyChanged -= OnPropertyChanged;

        _viewModel = viewModel;
        _viewModel.PropertyChanged += OnPropertyChanged;

        var root = uiDocument.rootVisualElement;
        _itemNameLabel = root.Q<Label>("item-name");
        _itemCountLabel = root.Q<Label>("item-count");
        _totalLabel = root.Q<Label>("total-items");

        RefreshAll();
    }

    private void OnPropertyChanged(object sender,
        System.ComponentModel.PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(InventoryViewModel.SelectedItemName):
                _itemNameLabel.text = _viewModel.SelectedItemName;
                break;
            case nameof(InventoryViewModel.SelectedItemCount):
                _itemCountLabel.text = _viewModel.SelectedItemCount.ToString();
                break;
            case nameof(InventoryViewModel.TotalItems):
                _totalLabel.text = _viewModel.TotalItems.ToString();
                break;
        }
    }

    private void RefreshAll()
    {
        _itemNameLabel.text = _viewModel.SelectedItemName;
        _itemCountLabel.text = _viewModel.SelectedItemCount.ToString();
        _totalLabel.text = _viewModel.TotalItems.ToString();
    }

    void OnDestroy()
    {
        if (_viewModel != null)
            _viewModel.PropertyChanged -= OnPropertyChanged;
    }
}
```

DESIGN HOOK: New data sources = new ViewModel adapting game system; View binds with zero knowledge of game internals. ViewModels are testable without Unity.

GOTCHA: Don't use Unity's built-in data binding for gameplay UI -- it is designed for Editor tools and has overhead/limitations that make it unsuitable for runtime game UI. Use explicit C# event subscriptions for control and debuggability.

---

## PATTERN: HUD Architecture

DESIGN INTENT: HUD elements (health bar, ammo counter, minimap markers, crosshair) always visible during gameplay, update at different rates.

WRONG:
```csharp
// All HUD logic in one script, polling every frame
public class HUD : MonoBehaviour
{
    [SerializeField] private UIDocument doc;

    void Update()
    {
        var root = doc.rootVisualElement;
        root.Q<ProgressBar>("health-bar").value = Player.Instance.Health;
        root.Q<Label>("ammo-count").text = Player.Instance.Ammo.ToString();
        root.Q<Label>("score").text = ScoreManager.Instance.Score.ToString();
        // Everything updates every frame whether it changed or not
    }
}
```

RIGHT: Each HUD widget implements `IHudWidget` with `Initialize`/`Dispose` lifecycle. Widgets subscribe to game events (SO channels from `unity-game-architecture`), self-update only on change. `HudController` manages widget registration and lifecycle.

SCAFFOLD:
```csharp
using System;
using UnityEngine.UIElements;

/// <summary>
/// Contract for HUD widgets. Each widget owns a section of the HUD.
/// </summary>
public interface IHudWidget : IDisposable
{
    /// <summary>Bind to VisualElements and subscribe to game events.</summary>
    void Initialize(VisualElement hudRoot);
}
```

```csharp
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Manages HUD widget lifecycle. Attach to the HUD UIDocument GameObject.
/// </summary>
public class HudController : MonoBehaviour
{
    [SerializeField] private UIDocument hudDocument;

    private readonly List<IHudWidget> _widgets = new();

    /// <summary>Register and initialize a widget.</summary>
    public void RegisterWidget(IHudWidget widget)
    {
        widget.Initialize(hudDocument.rootVisualElement);
        _widgets.Add(widget);
    }

    void OnDestroy()
    {
        foreach (var widget in _widgets)
            widget.Dispose();
        _widgets.Clear();
    }
}
```

```csharp
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Health bar widget. Updates only when health changes via event subscription.
/// </summary>
public class HealthBarWidget : IHudWidget
{
    // ScriptableObject event channel (see unity-game-architecture)
    private readonly FloatEventChannel _healthChanged;
    private ProgressBar _healthBar;

    public HealthBarWidget(FloatEventChannel healthChanged)
    {
        _healthChanged = healthChanged;
    }

    public void Initialize(VisualElement hudRoot)
    {
        _healthBar = hudRoot.Q<ProgressBar>("health-bar");
        _healthChanged.OnEventRaised += UpdateHealth;
    }

    private void UpdateHealth(float normalizedHealth)
    {
        _healthBar.value = normalizedHealth * 100f;
    }

    public void Dispose()
    {
        _healthChanged.OnEventRaised -= UpdateHealth;
    }
}
```

DESIGN HOOK: New widgets = implement `IHudWidget`; add element to HUD UXML; register with `HudController`. Widgets are self-contained, testable, and only update when their data changes.

GOTCHA: HUD root must use a separate `UIDocument` from gameplay screens -- `sortingOrder` on the `UIDocument` component controls layering. HUD should have a higher `sortingOrder` than screen UI so it renders on top. Multiple `UIDocument` components can coexist in a scene.

---

## PATTERN: Feedback & Juice Systems

DESIGN INTENT: UI reacts to game events with visual feedback (damage numbers, screen shake, color flash, scale punch).

WRONG:
```csharp
// Hardcoded feedback inline in combat logic
public class CombatManager : MonoBehaviour
{
    [SerializeField] private UIDocument hudDoc;

    public void ApplyDamage(float amount)
    {
        // Combat script directly drives UI -- tight coupling
        var healthBar = hudDoc.rootVisualElement.Q("health-bar");
        healthBar.style.backgroundColor = Color.red;
        // No way to revert, no timing, no designer control
    }
}
```

RIGHT: `UIFeedbackPlayer` component with `UIFeedback` SO assets. Game code fires events, feedback system subscribes, applies visual effects. Feedback sequence: USS class add, transition plays via USS `transition-*` properties, USS class remove after duration.

SCAFFOLD:
```csharp
using UnityEngine;

/// <summary>
/// Designer-configurable UI feedback effect.
/// </summary>
[CreateAssetMenu(menuName = "UI/Feedback Effect")]
public class UIFeedback : ScriptableObject
{
    [Tooltip("USS class to add that triggers the visual effect")]
    public string ussClassName = "feedback--damage";

    [Tooltip("Duration in seconds before removing the USS class")]
    public float duration = 0.3f;

    [Tooltip("Optional: target element name. Null = apply to root.")]
    public string targetElementName;
}
```

```csharp
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Plays UIFeedback effects on a UIDocument's visual tree.
/// </summary>
public class UIFeedbackPlayer : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    /// <summary>Play a feedback effect, adding then removing a USS class.</summary>
    public async Awaitable PlayAsync(UIFeedback feedback)
    {
        var ct = destroyCancellationToken;
        var root = uiDocument.rootVisualElement;

        var target = string.IsNullOrEmpty(feedback.targetElementName)
            ? root
            : root.Q(feedback.targetElementName);

        if (target == null) return;

        // Add USS class -- USS transition-* properties handle the animation
        target.AddToClassList(feedback.ussClassName);

        await Awaitable.WaitForSecondsAsync(feedback.duration, ct);

        // Remove USS class -- transition plays in reverse
        target.RemoveFromClassList(feedback.ussClassName);
    }
}
```

Example USS for damage flash:
```css
/* Base state */
.health-bar {
    transition-property: background-color, scale;
    transition-duration: 0.15s;
    transition-timing-function: ease-out;
    background-color: rgb(50, 180, 50);
    scale: 1 1;
}

/* Feedback state -- applied by UIFeedbackPlayer */
.health-bar.feedback--damage {
    background-color: rgb(220, 40, 40);
    scale: 1.1 1.1;
}
```

DESIGN HOOK: Designers create `UIFeedback` SOs; assign USS classes for visual effects. New juice = new SO + USS rule. No code changes required.

GOTCHA: USS transitions use `transition-duration` and `transition-timing-function` -- you must set the transition properties on the **base state** (not the triggered class), or the transition won't play. The triggered class only changes the target property values.

---

## PATTERN: Dynamic List/Grid Views

DESIGN INTENT: Inventory, shop, leaderboard -- scrollable lists of variable-length data with efficient rendering.

WRONG:
```csharp
// Instantiate one VisualElement per data item
public void PopulateInventory(List<ItemData> items)
{
    var container = doc.rootVisualElement.Q("item-container");
    container.Clear();
    foreach (var item in items)
    {
        // 1000 items = 1000 elements in the visual tree -- laggy scroll
        var element = new VisualElement();
        element.Add(new Label(item.Name));
        element.Add(new Label(item.Count.ToString()));
        container.Add(element);
    }
}
```

RIGHT: UI Toolkit `ListView` with `makeItem`/`bindItem` callbacks for element recycling. Data source is `List<T>` or `IList`. Item template from UXML. Only visible items exist in the visual tree.

SCAFFOLD:
```csharp
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Sets up a ListView with element recycling for efficient scrolling.
/// </summary>
public class InventoryListView : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;
    [SerializeField] private VisualTreeAsset itemTemplate;

    private ListView _listView;
    private List<ItemData> _items = new();

    void OnEnable()
    {
        _listView = uiDocument.rootVisualElement.Q<ListView>("inventory-list");

        _listView.makeItem = () => itemTemplate.Instantiate();

        _listView.bindItem = (element, index) =>
        {
            var item = _items[index];
            element.Q<Label>("item-name").text = item.Name;
            element.Q<Label>("item-count").text = item.Count.ToString();
        };

        _listView.unbindItem = (element, index) =>
        {
            // Clean up any subscriptions or dynamic content
            element.Q<Label>("item-name").text = "";
            element.Q<Label>("item-count").text = "";
        };

        _listView.itemsSource = _items;
        _listView.fixedItemHeight = 60f;
        _listView.selectionType = SelectionType.Single;

        _listView.selectionChanged += OnSelectionChanged;
    }

    /// <summary>Update the data source and refresh the list.</summary>
    public void SetItems(List<ItemData> items)
    {
        _items = items;
        _listView.itemsSource = _items;
        _listView.RefreshItems();
    }

    private void OnSelectionChanged(IEnumerable<object> selection)
    {
        foreach (var obj in selection)
        {
            if (obj is ItemData item)
                Debug.Log($"Selected: {item.Name}");
        }
    }

    void OnDisable()
    {
        _listView.selectionChanged -= OnSelectionChanged;
    }
}
```

DESIGN HOOK: Item visual = UXML template; data binding in `bindItem` callback; new list types reuse pattern with different data/template. Designers control item layout via UXML + USS.

GOTCHA: Call `ListView.RefreshItems()` (not `Rebuild()`) after data changes -- `Rebuild` recreates all elements from scratch, `RefreshItems` rebinds existing recycled elements. Use `Rebuild()` only when the item template itself changes.

---

## PATTERN: Transition & Animation Contracts

DESIGN INTENT: Screen transitions (fade, slide, scale) are consistent and designer-configurable.

WRONG:
```csharp
// Manual alpha lerps per screen, no standard contract
public async Awaitable ShowMainMenu(VisualElement root)
{
    root.style.opacity = 0;
    root.style.display = DisplayStyle.Flex;
    float t = 0;
    while (t < 0.3f)
    {
        t += Time.deltaTime;
        root.style.opacity = t / 0.3f;
        await Awaitable.NextFrameAsync();
    }
    // Every screen duplicates this. Duration/easing hardcoded. No designer control.
}
```

RIGHT: `IScreenTransition` interface with `PlayAsync(VisualElement target, CancellationToken ct)`. Implementations use USS transitions (`opacity`, `translate`, `scale`). Transitions are SO assets with duration/easing config. `ScreenManager` accepts transition per navigation call.

SCAFFOLD:
```csharp
using System.Threading;
using UnityEngine.UIElements;

/// <summary>
/// Contract for screen transitions.
/// </summary>
public interface IScreenTransition
{
    /// <summary>Play the transition on the target element.</summary>
    Awaitable PlayAsync(VisualElement target, CancellationToken ct);
}
```

```csharp
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Fade transition using USS opacity. Designer-configurable duration.
/// </summary>
[CreateAssetMenu(menuName = "UI/Transitions/Fade")]
public class FadeTransition : ScriptableObject, IScreenTransition
{
    [Tooltip("Fade duration in seconds")]
    [SerializeField] private float duration = 0.3f;

    [Tooltip("True = fade in (0 to 1), False = fade out (1 to 0)")]
    [SerializeField] private bool fadeIn = true;

    public async Awaitable PlayAsync(VisualElement target, CancellationToken ct)
    {
        float startOpacity = fadeIn ? 0f : 1f;
        float endOpacity = fadeIn ? 1f : 0f;

        // Set initial state without transition
        target.style.transitionDuration = new List<TimeValue> { new(0, TimeUnit.Second) };
        target.style.opacity = startOpacity;

        // Wait one frame for the initial state to apply
        await Awaitable.NextFrameAsync(ct);

        // Set transition duration then animate
        target.style.transitionProperty = new List<StylePropertyName> { new("opacity") };
        target.style.transitionDuration = new List<TimeValue> { new(duration, TimeUnit.Second) };
        target.style.transitionTimingFunction =
            new List<EasingFunction> { new(EasingMode.EaseInOut) };
        target.style.opacity = endOpacity;

        await Awaitable.WaitForSecondsAsync(duration, ct);
    }
}
```

```csharp
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Slide transition using USS translate. Configurable direction and duration.
/// </summary>
[CreateAssetMenu(menuName = "UI/Transitions/Slide")]
public class SlideTransition : ScriptableObject, IScreenTransition
{
    [SerializeField] private float duration = 0.4f;
    [SerializeField] private bool slideIn = true;
    [SerializeField] private Vector2 offset = new(100f, 0f); // percentage

    public async Awaitable PlayAsync(VisualElement target, CancellationToken ct)
    {
        var start = slideIn
            ? new Translate(Length.Percent(offset.x), Length.Percent(offset.y))
            : new Translate(Length.Percent(0), Length.Percent(0));
        var end = slideIn
            ? new Translate(Length.Percent(0), Length.Percent(0))
            : new Translate(Length.Percent(offset.x), Length.Percent(offset.y));

        // Set initial state
        target.style.transitionDuration = new List<TimeValue> { new(0, TimeUnit.Second) };
        target.style.translate = new StyleTranslate(start);

        await Awaitable.NextFrameAsync(ct);

        // Animate
        target.style.transitionProperty = new List<StylePropertyName> { new("translate") };
        target.style.transitionDuration = new List<TimeValue> { new(duration, TimeUnit.Second) };
        target.style.transitionTimingFunction =
            new List<EasingFunction> { new(EasingMode.EaseOut) };
        target.style.translate = new StyleTranslate(end);

        await Awaitable.WaitForSecondsAsync(duration, ct);
    }
}
```

DESIGN HOOK: New transitions = implement `IScreenTransition` as a ScriptableObject; designers pick transition SO per screen change. `ScreenManager.PushAsync(screen, transition)` applies it.

GOTCHA: USS `transition-property` must include ALL animated properties -- if you animate `opacity` and `translate`, both must be listed. Use `transition-property: all` as a fallback, but be aware it will animate every property change (including layout changes you don't intend to animate).

---

## Anti-Patterns Summary

| Anti-Pattern | Problem | Pattern Fix |
|---|---|---|
| Monolithic screen scripts | Every screen knows every other screen; adding one screen changes five files | Screen Flow Architecture -- stack-based navigation |
| Direct system polling in Update | Wasted cycles, tight coupling between UI and game logic | View/ViewModel -- event-driven updates |
| Single HUD MonoBehaviour | One change breaks all HUD elements; everything polls every frame | HUD Architecture -- independent widgets with event subscriptions |
| Hardcoded feedback in game logic | Combat scripts drive UI directly; no designer control | Feedback & Juice -- SO-driven USS class effects |
| Manual element instantiation | 1000 items = 1000 VisualElements; laggy scroll | Dynamic ListView -- recycling with makeItem/bindItem |
| Per-screen animation code | Every screen duplicates transition logic; no consistency | Transition Contracts -- SO-based IScreenTransition |

---

## Related Skills

- `unity-ui` -- UI Toolkit fundamentals, USS/UXML authoring, VisualElement hierarchy
- `unity-async-patterns` -- Awaitable, CancellationToken, async lifecycle management
- `unity-game-architecture` -- Event channels, Service Locator, ScriptableObject patterns
- `unity-scene-assets` -- Scene loading for screen-per-scene architectures

## Additional Resources

- `skills/unity-ui-patterns/references/ui-pattern-scaffolds.md` -- Complete implementations for all patterns
- Unity Manual: UI Toolkit runtime usage
- Unity Manual: ListView and virtualization
- Unity Manual: USS transitions and animations
