# UI/UX Pattern Scaffolds

Detailed implementations for UI architecture patterns. Supplements the PATTERN blocks in the parent SKILL.md. All patterns use UI Toolkit exclusively.

---

## 1. Complete ScreenManager

Full implementation with transition support, duplicate push guard, and screen registry.

### IScreen Interface

```csharp
using System.Threading;

/// <summary>
/// Contract for all navigable screens in the screen flow system.
/// </summary>
public interface IScreen
{
    /// <summary>Display name for debugging and stack inspection.</summary>
    string ScreenName { get; }

    /// <summary>Transition the screen into view.</summary>
    Awaitable ShowAsync(CancellationToken ct);

    /// <summary>Transition the screen out of view.</summary>
    Awaitable HideAsync(CancellationToken ct);
}
```

### ScreenManager

```csharp
using System.Collections.Generic;
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Stack-based screen navigator with transition support.
/// Attach to a GameObject with a UIDocument for the screen container.
/// </summary>
public class ScreenManager : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    private readonly Stack<IScreen> _screenStack = new();
    private bool _isTransitioning;

    /// <summary>Singleton accessor.</summary>
    public static ScreenManager Instance { get; private set; }

    /// <summary>The currently visible screen, or null if stack is empty.</summary>
    public IScreen CurrentScreen =>
        _screenStack.Count > 0 ? _screenStack.Peek() : null;

    /// <summary>Number of screens on the stack.</summary>
    public int StackDepth => _screenStack.Count;

    /// <summary>Root VisualElement for screen content.</summary>
    public VisualElement Root => uiDocument.rootVisualElement;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() => Instance = null;

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
    }

    /// <summary>
    /// Push a new screen onto the stack. Hides the current screen first.
    /// Optionally applies transitions during the switch.
    /// </summary>
    /// <param name="screen">Screen to push.</param>
    /// <param name="hideTransition">Transition for the outgoing screen (optional).</param>
    /// <param name="showTransition">Transition for the incoming screen (optional).</param>
    public async Awaitable PushAsync(
        IScreen screen,
        IScreenTransition hideTransition = null,
        IScreenTransition showTransition = null)
    {
        if (_isTransitioning) return;

        // Guard: don't push the same screen that's already on top
        if (_screenStack.Count > 0 && _screenStack.Peek() == screen) return;

        _isTransitioning = true;
        var ct = destroyCancellationToken;

        // Hide current screen
        if (_screenStack.TryPeek(out var current))
        {
            if (hideTransition != null)
                await hideTransition.PlayAsync(Root, ct);
            await current.HideAsync(ct);
        }

        // Push and show new screen
        _screenStack.Push(screen);

        await screen.ShowAsync(ct);
        if (showTransition != null)
            await showTransition.PlayAsync(Root, ct);

        _isTransitioning = false;
    }

    /// <summary>
    /// Pop the current screen and reveal the one beneath it.
    /// No-op if only one screen remains (cannot pop the root).
    /// </summary>
    /// <param name="hideTransition">Transition for the outgoing screen (optional).</param>
    /// <param name="showTransition">Transition for the revealed screen (optional).</param>
    public async Awaitable PopAsync(
        IScreenTransition hideTransition = null,
        IScreenTransition showTransition = null)
    {
        if (_isTransitioning || _screenStack.Count <= 1) return;
        _isTransitioning = true;

        var ct = destroyCancellationToken;

        // Hide and remove current screen
        var leaving = _screenStack.Pop();
        if (hideTransition != null)
            await hideTransition.PlayAsync(Root, ct);
        await leaving.HideAsync(ct);

        // Reveal screen beneath
        if (_screenStack.TryPeek(out var revealed))
        {
            await revealed.ShowAsync(ct);
            if (showTransition != null)
                await showTransition.PlayAsync(Root, ct);
        }

        _isTransitioning = false;
    }

    /// <summary>
    /// Pop all screens down to the root, hiding each in sequence.
    /// </summary>
    public async Awaitable PopToRootAsync()
    {
        while (_screenStack.Count > 1)
        {
            await PopAsync();
        }
    }

    /// <summary>
    /// Clear the entire stack and push a new root screen.
    /// Useful for hard navigation resets (e.g., returning to main menu from gameplay).
    /// </summary>
    public async Awaitable ReplaceAllAsync(IScreen newRoot)
    {
        if (_isTransitioning) return;
        _isTransitioning = true;

        var ct = destroyCancellationToken;

        // Hide current
        if (_screenStack.TryPeek(out var current))
            await current.HideAsync(ct);

        // Clear stack
        _screenStack.Clear();

        // Push new root
        _screenStack.Push(newRoot);
        await newRoot.ShowAsync(ct);

        _isTransitioning = false;
    }
}
```

### Example Screens

```csharp
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Main menu screen. Loads its visual tree from a UXML template.
/// </summary>
public class MainMenuScreen : MonoBehaviour, IScreen
{
    [SerializeField] private VisualTreeAsset menuTemplate;

    private VisualElement _root;

    public string ScreenName => "MainMenu";

    public async Awaitable ShowAsync(CancellationToken ct)
    {
        var container = ScreenManager.Instance.Root;
        _root = menuTemplate.Instantiate();
        _root.style.flexGrow = 1;
        container.Add(_root);

        // Wire buttons
        _root.Q<Button>("btn-play").clicked += OnPlayClicked;
        _root.Q<Button>("btn-settings").clicked += OnSettingsClicked;

        await Awaitable.NextFrameAsync(ct);
    }

    public async Awaitable HideAsync(CancellationToken ct)
    {
        _root?.RemoveFromHierarchy();
        _root = null;
        await Awaitable.NextFrameAsync(ct);
    }

    private async void OnPlayClicked()
    {
        // Navigate to gameplay -- handled by game-specific logic
        Debug.Log("Play clicked");
    }

    private async void OnSettingsClicked()
    {
        var settings = FindAnyObjectByType<SettingsScreen>();
        if (settings != null)
            await ScreenManager.Instance.PushAsync(settings);
    }
}
```

```csharp
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Settings screen with a back button that pops the screen stack.
/// </summary>
public class SettingsScreen : MonoBehaviour, IScreen
{
    [SerializeField] private VisualTreeAsset settingsTemplate;

    private VisualElement _root;

    public string ScreenName => "Settings";

    public async Awaitable ShowAsync(CancellationToken ct)
    {
        var container = ScreenManager.Instance.Root;
        _root = settingsTemplate.Instantiate();
        _root.style.flexGrow = 1;
        container.Add(_root);

        _root.Q<Button>("btn-back").clicked += OnBackClicked;

        await Awaitable.NextFrameAsync(ct);
    }

    public async Awaitable HideAsync(CancellationToken ct)
    {
        _root?.RemoveFromHierarchy();
        _root = null;
        await Awaitable.NextFrameAsync(ct);
    }

    private async void OnBackClicked()
    {
        await ScreenManager.Instance.PopAsync();
    }
}
```

---

## 2. Complete View/ViewModel

Full MVVM-style implementation with property change helper and generic binding utility.

### PropertyChangedBase

```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;

/// <summary>
/// Base class for ViewModels with INotifyPropertyChanged boilerplate.
/// </summary>
public abstract class PropertyChangedBase : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;

    /// <summary>Set a field and raise PropertyChanged if the value changed.</summary>
    protected bool SetField<T>(ref T field, T value,
        [CallerMemberName] string propertyName = null)
    {
        if (System.Collections.Generic.EqualityComparer<T>.Default.Equals(field, value))
            return false;

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }
}
```

### InventoryViewModel

```csharp
using System.Collections.Generic;

/// <summary>
/// ViewModel adapting raw inventory data for display.
/// No dependency on UnityEngine.UIElements.
/// </summary>
public class InventoryViewModel : PropertyChangedBase
{
    private string _selectedItemName = "";
    private string _selectedItemDescription = "";
    private int _selectedItemCount;
    private int _totalItems;
    private int _selectedIndex = -1;
    private List<ItemDisplayData> _itemList = new();

    /// <summary>Name of the currently selected item.</summary>
    public string SelectedItemName
    {
        get => _selectedItemName;
        set => SetField(ref _selectedItemName, value);
    }

    /// <summary>Description of the currently selected item.</summary>
    public string SelectedItemDescription
    {
        get => _selectedItemDescription;
        set => SetField(ref _selectedItemDescription, value);
    }

    /// <summary>Stack count of the selected item.</summary>
    public int SelectedItemCount
    {
        get => _selectedItemCount;
        set => SetField(ref _selectedItemCount, value);
    }

    /// <summary>Total number of distinct items.</summary>
    public int TotalItems
    {
        get => _totalItems;
        set => SetField(ref _totalItems, value);
    }

    /// <summary>Index of the selected item in the list.</summary>
    public int SelectedIndex
    {
        get => _selectedIndex;
        set => SetField(ref _selectedIndex, value);
    }

    /// <summary>Display-ready list of items.</summary>
    public List<ItemDisplayData> ItemList
    {
        get => _itemList;
        set => SetField(ref _itemList, value);
    }

    /// <summary>
    /// Refresh from game data source. Call when inventory contents change.
    /// </summary>
    public void RefreshFromSource(List<ItemData> rawItems)
    {
        var display = new List<ItemDisplayData>(rawItems.Count);
        foreach (var item in rawItems)
        {
            display.Add(new ItemDisplayData
            {
                Name = item.Name,
                Description = item.Description,
                Count = item.Count,
                IconPath = item.IconPath
            });
        }

        ItemList = display;
        TotalItems = display.Count;

        if (SelectedIndex >= 0 && SelectedIndex < display.Count)
            SelectItem(SelectedIndex);
    }

    /// <summary>Select an item by index.</summary>
    public void SelectItem(int index)
    {
        if (index < 0 || index >= _itemList.Count) return;

        SelectedIndex = index;
        var item = _itemList[index];
        SelectedItemName = item.Name;
        SelectedItemDescription = item.Description;
        SelectedItemCount = item.Count;
    }
}

/// <summary>Display-ready item data (no game logic).</summary>
public struct ItemDisplayData
{
    public string Name;
    public string Description;
    public int Count;
    public string IconPath;
}
```

### InventoryView

```csharp
using System.ComponentModel;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// View that binds VisualElements to InventoryViewModel.
/// Handles element queries and property-to-element mapping.
/// </summary>
public class InventoryView : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    private InventoryViewModel _viewModel;
    private Label _itemNameLabel;
    private Label _itemDescLabel;
    private Label _itemCountLabel;
    private Label _totalLabel;
    private VisualElement _detailPanel;

    /// <summary>Bind this view to a ViewModel instance.</summary>
    public void Bind(InventoryViewModel viewModel)
    {
        Unbind();

        _viewModel = viewModel;
        _viewModel.PropertyChanged += OnViewModelPropertyChanged;

        var root = uiDocument.rootVisualElement;
        _itemNameLabel = root.Q<Label>("item-name");
        _itemDescLabel = root.Q<Label>("item-description");
        _itemCountLabel = root.Q<Label>("item-count");
        _totalLabel = root.Q<Label>("total-items");
        _detailPanel = root.Q("detail-panel");

        RefreshAll();
    }

    /// <summary>Unbind from the current ViewModel.</summary>
    public void Unbind()
    {
        if (_viewModel != null)
        {
            _viewModel.PropertyChanged -= OnViewModelPropertyChanged;
            _viewModel = null;
        }
    }

    private void OnViewModelPropertyChanged(object sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(InventoryViewModel.SelectedItemName):
                _itemNameLabel.text = _viewModel.SelectedItemName;
                break;
            case nameof(InventoryViewModel.SelectedItemDescription):
                _itemDescLabel.text = _viewModel.SelectedItemDescription;
                break;
            case nameof(InventoryViewModel.SelectedItemCount):
                _itemCountLabel.text = _viewModel.SelectedItemCount.ToString();
                break;
            case nameof(InventoryViewModel.TotalItems):
                _totalLabel.text = _viewModel.TotalItems.ToString();
                break;
            case nameof(InventoryViewModel.SelectedIndex):
                _detailPanel.style.display = _viewModel.SelectedIndex >= 0
                    ? DisplayStyle.Flex
                    : DisplayStyle.None;
                break;
        }
    }

    private void RefreshAll()
    {
        _itemNameLabel.text = _viewModel.SelectedItemName;
        _itemDescLabel.text = _viewModel.SelectedItemDescription;
        _itemCountLabel.text = _viewModel.SelectedItemCount.ToString();
        _totalLabel.text = _viewModel.TotalItems.ToString();
        _detailPanel.style.display = _viewModel.SelectedIndex >= 0
            ? DisplayStyle.Flex
            : DisplayStyle.None;
    }

    void OnDestroy() => Unbind();
}
```

---

## 3. Complete HUD System

Full HUD architecture with widget lifecycle, registration, and example widgets.

### IHudWidget and HudController

```csharp
using System;
using UnityEngine.UIElements;

/// <summary>
/// Contract for self-contained HUD widgets.
/// Each widget owns a section of the HUD visual tree.
/// </summary>
public interface IHudWidget : IDisposable
{
    /// <summary>Unique name for this widget.</summary>
    string WidgetName { get; }

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
/// Uses a separate UIDocument from screen UI for proper layering.
/// </summary>
public class HudController : MonoBehaviour
{
    [SerializeField] private UIDocument hudDocument;

    private readonly List<IHudWidget> _widgets = new();
    private readonly HashSet<string> _registeredNames = new();

    /// <summary>Register and initialize a widget. No-op if already registered.</summary>
    public void RegisterWidget(IHudWidget widget)
    {
        if (!_registeredNames.Add(widget.WidgetName)) return;

        widget.Initialize(hudDocument.rootVisualElement);
        _widgets.Add(widget);
    }

    /// <summary>Unregister and dispose a widget by name.</summary>
    public void UnregisterWidget(string widgetName)
    {
        for (int i = _widgets.Count - 1; i >= 0; i--)
        {
            if (_widgets[i].WidgetName == widgetName)
            {
                _widgets[i].Dispose();
                _widgets.RemoveAt(i);
                _registeredNames.Remove(widgetName);
                return;
            }
        }
    }

    /// <summary>Show the entire HUD.</summary>
    public void Show() =>
        hudDocument.rootVisualElement.style.display = DisplayStyle.Flex;

    /// <summary>Hide the entire HUD (e.g., during cutscenes).</summary>
    public void Hide() =>
        hudDocument.rootVisualElement.style.display = DisplayStyle.None;

    void OnDestroy()
    {
        foreach (var widget in _widgets)
            widget.Dispose();
        _widgets.Clear();
        _registeredNames.Clear();
    }
}
```

### Example Widgets

```csharp
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Health bar widget. Subscribes to health change events, updates only on change.
/// </summary>
public class HealthBarWidget : IHudWidget
{
    private readonly FloatEventChannel _healthChanged;
    private readonly FloatEventChannel _maxHealthChanged;

    private ProgressBar _healthBar;
    private Label _healthText;
    private float _maxHealth = 100f;

    public string WidgetName => "HealthBar";

    public HealthBarWidget(FloatEventChannel healthChanged,
        FloatEventChannel maxHealthChanged)
    {
        _healthChanged = healthChanged;
        _maxHealthChanged = maxHealthChanged;
    }

    public void Initialize(VisualElement hudRoot)
    {
        _healthBar = hudRoot.Q<ProgressBar>("health-bar");
        _healthText = hudRoot.Q<Label>("health-text");

        _healthChanged.OnEventRaised += OnHealthChanged;
        _maxHealthChanged.OnEventRaised += OnMaxHealthChanged;
    }

    private void OnHealthChanged(float currentHealth)
    {
        float normalized = currentHealth / _maxHealth;
        _healthBar.value = normalized * 100f;
        _healthText.text = $"{Mathf.CeilToInt(currentHealth)} / {Mathf.CeilToInt(_maxHealth)}";

        // Visual feedback via USS classes
        _healthBar.EnableInClassList("health--low", normalized < 0.25f);
        _healthBar.EnableInClassList("health--critical", normalized < 0.1f);
    }

    private void OnMaxHealthChanged(float maxHealth)
    {
        _maxHealth = maxHealth;
    }

    public void Dispose()
    {
        _healthChanged.OnEventRaised -= OnHealthChanged;
        _maxHealthChanged.OnEventRaised -= OnMaxHealthChanged;
    }
}
```

```csharp
using UnityEngine.UIElements;

/// <summary>
/// Ammo counter widget. Subscribes to ammo change events.
/// </summary>
public class AmmoCounterWidget : IHudWidget
{
    private readonly IntEventChannel _ammoChanged;
    private readonly IntEventChannel _maxAmmoChanged;

    private Label _ammoLabel;
    private int _maxAmmo = 30;

    public string WidgetName => "AmmoCounter";

    public AmmoCounterWidget(IntEventChannel ammoChanged,
        IntEventChannel maxAmmoChanged)
    {
        _ammoChanged = ammoChanged;
        _maxAmmoChanged = maxAmmoChanged;
    }

    public void Initialize(VisualElement hudRoot)
    {
        _ammoLabel = hudRoot.Q<Label>("ammo-count");
        _ammoChanged.OnEventRaised += OnAmmoChanged;
        _maxAmmoChanged.OnEventRaised += OnMaxAmmoChanged;
    }

    private void OnAmmoChanged(int current)
    {
        _ammoLabel.text = $"{current} / {_maxAmmo}";
        _ammoLabel.EnableInClassList("ammo--low", current <= 5);
        _ammoLabel.EnableInClassList("ammo--empty", current == 0);
    }

    private void OnMaxAmmoChanged(int max) => _maxAmmo = max;

    public void Dispose()
    {
        _ammoChanged.OnEventRaised -= OnAmmoChanged;
        _maxAmmoChanged.OnEventRaised -= OnMaxAmmoChanged;
    }
}
```

### Example HUD USS

```css
/* Health bar base */
.health-bar .unity-progress-bar__background {
    background-color: rgb(40, 40, 40);
    border-radius: 4px;
}

.health-bar .unity-progress-bar__progress {
    background-color: rgb(50, 180, 50);
    transition-property: background-color, width;
    transition-duration: 0.3s;
    transition-timing-function: ease-out;
}

/* Low health state */
.health-bar.health--low .unity-progress-bar__progress {
    background-color: rgb(220, 180, 30);
}

/* Critical health state */
.health-bar.health--critical .unity-progress-bar__progress {
    background-color: rgb(220, 40, 40);
}

/* Ammo counter */
.ammo-count {
    font-size: 24px;
    color: rgb(220, 220, 220);
    transition-property: color;
    transition-duration: 0.2s;
}

.ammo-count.ammo--low {
    color: rgb(220, 180, 30);
}

.ammo-count.ammo--empty {
    color: rgb(220, 40, 40);
}
```

---

## 4. Complete UIFeedbackPlayer

Full feedback system with play queue, concurrent effect support, and SO configuration.

### UIFeedback ScriptableObject

```csharp
using UnityEngine;

/// <summary>
/// Designer-configurable UI feedback effect.
/// Create via Assets > Create > UI > Feedback Effect.
/// </summary>
[CreateAssetMenu(menuName = "UI/Feedback Effect")]
public class UIFeedback : ScriptableObject
{
    [Tooltip("USS class to add that triggers the visual effect.")]
    public string ussClassName = "feedback--damage";

    [Tooltip("Duration in seconds before removing the USS class.")]
    public float duration = 0.3f;

    [Tooltip("Optional: target element name. Empty = apply to root.")]
    public string targetElementName = "";

    [Tooltip("If true, this effect can stack with itself (add multiple times).")]
    public bool allowStacking;
}
```

### UIFeedbackPlayer

```csharp
using System.Collections.Generic;
using System.Threading;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Plays UIFeedback effects on a UIDocument's visual tree.
/// Supports concurrent non-stacking effects and sequential stacking effects.
/// </summary>
public class UIFeedbackPlayer : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    private readonly HashSet<string> _activeEffects = new();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() { }

    /// <summary>
    /// Play a feedback effect. Adds a USS class, waits, then removes it.
    /// USS transition-* properties on the base state handle the animation.
    /// </summary>
    public async Awaitable PlayAsync(UIFeedback feedback)
    {
        if (feedback == null) return;

        var ct = destroyCancellationToken;
        var root = uiDocument.rootVisualElement;

        var target = string.IsNullOrEmpty(feedback.targetElementName)
            ? root
            : root.Q(feedback.targetElementName);

        if (target == null)
        {
            Debug.LogWarning($"UIFeedbackPlayer: target '{feedback.targetElementName}' not found.");
            return;
        }

        // Guard against duplicate non-stacking effects
        if (!feedback.allowStacking && !_activeEffects.Add(feedback.ussClassName))
            return;

        // Add USS class -- this triggers USS transitions defined on the base state
        target.AddToClassList(feedback.ussClassName);

        // Wait for the effect duration
        await Awaitable.WaitForSecondsAsync(feedback.duration, ct);

        // Remove USS class -- triggers reverse transition
        target.RemoveFromClassList(feedback.ussClassName);

        if (!feedback.allowStacking)
            _activeEffects.Remove(feedback.ussClassName);
    }

    /// <summary>
    /// Play a feedback effect without awaiting (fire-and-forget).
    /// </summary>
    public void PlayFireAndForget(UIFeedback feedback)
    {
        _ = PlayAsync(feedback);
    }

    /// <summary>
    /// Play multiple feedback effects concurrently.
    /// </summary>
    public async Awaitable PlayAllAsync(params UIFeedback[] feedbacks)
    {
        var tasks = new List<Awaitable>(feedbacks.Length);
        foreach (var feedback in feedbacks)
        {
            tasks.Add(PlayAsync(feedback));
        }

        foreach (var task in tasks)
        {
            await task;
        }
    }
}
```

### Example USS for Feedback Effects

```css
/* Base state -- transition properties MUST be defined here, not on the trigger class */
.hud-container {
    transition-property: all;
    transition-duration: 0.15s;
    transition-timing-function: ease-out;
}

/* Damage flash -- turns background red briefly */
.hud-container.feedback--damage {
    background-color: rgba(220, 40, 40, 0.3);
}

/* Heal pulse -- green tint */
.hud-container.feedback--heal {
    background-color: rgba(50, 220, 50, 0.2);
}

/* Scale punch for pickups */
.pickup-icon {
    transition-property: scale;
    transition-duration: 0.2s;
    transition-timing-function: ease-out;
    scale: 1 1;
}

.pickup-icon.feedback--pickup {
    scale: 1.3 1.3;
}

/* Screen shake via translate */
.screen-root {
    transition-property: translate;
    transition-duration: 0.05s;
    transition-timing-function: linear;
    translate: 0 0;
}

.screen-root.feedback--shake {
    translate: 3px -2px;
}
```

---

## 5. Complete ListView Setup

Generic ListView configuration with UXML template, selection handling, and data refresh.

### Generic ListView Helper

```csharp
using System;
using System.Collections.Generic;
using UnityEngine.UIElements;

/// <summary>
/// Helper for configuring a UI Toolkit ListView with proper element recycling.
/// </summary>
public static class ListViewHelper
{
    /// <summary>
    /// Configure a ListView with typed makeItem/bindItem callbacks.
    /// </summary>
    /// <typeparam name="T">Data item type.</typeparam>
    /// <param name="listView">The ListView to configure.</param>
    /// <param name="itemTemplate">UXML template for each item.</param>
    /// <param name="items">Data source list.</param>
    /// <param name="bindItem">Callback to populate an element from data.</param>
    /// <param name="onSelectionChanged">Optional selection callback.</param>
    /// <param name="itemHeight">Fixed item height for virtualization.</param>
    public static void Setup<T>(
        ListView listView,
        VisualTreeAsset itemTemplate,
        IList<T> items,
        Action<VisualElement, T, int> bindItem,
        Action<T> onSelectionChanged = null,
        float itemHeight = 60f)
    {
        listView.makeItem = () => itemTemplate.Instantiate();

        listView.bindItem = (element, index) =>
        {
            if (index >= 0 && index < items.Count)
                bindItem(element, items[index], index);
        };

        listView.unbindItem = (element, index) =>
        {
            // Reset element state to prevent stale data on recycled elements
        };

        listView.itemsSource = items as System.Collections.IList;
        listView.fixedItemHeight = itemHeight;
        listView.selectionType = SelectionType.Single;

        if (onSelectionChanged != null)
        {
            listView.selectionChanged += selection =>
            {
                foreach (var obj in selection)
                {
                    if (obj is T item)
                        onSelectionChanged(item);
                }
            };
        }
    }

    /// <summary>
    /// Refresh the ListView after data changes. Uses RefreshItems (not Rebuild)
    /// to rebind existing recycled elements instead of recreating them.
    /// </summary>
    public static void Refresh<T>(ListView listView, IList<T> items)
    {
        listView.itemsSource = items as System.Collections.IList;
        listView.RefreshItems();
    }
}
```

### Usage Example

```csharp
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

/// <summary>
/// Inventory list using the ListViewHelper for setup and refresh.
/// </summary>
public class InventoryListSetup : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;
    [SerializeField] private VisualTreeAsset itemTemplate;

    private List<ItemData> _items = new();
    private ListView _listView;

    void OnEnable()
    {
        _listView = uiDocument.rootVisualElement.Q<ListView>("inventory-list");

        ListViewHelper.Setup<ItemData>(
            _listView,
            itemTemplate,
            _items,
            bindItem: (element, item, index) =>
            {
                element.Q<Label>("item-name").text = item.Name;
                element.Q<Label>("item-count").text = $"x{item.Count}";

                // Alternate row styling
                element.EnableInClassList("row--alt", index % 2 == 1);
            },
            onSelectionChanged: item =>
            {
                Debug.Log($"Selected: {item.Name}");
            },
            itemHeight: 50f
        );
    }

    /// <summary>Update the list with new data.</summary>
    public void UpdateItems(List<ItemData> newItems)
    {
        _items = newItems;
        ListViewHelper.Refresh(_listView, _items);
    }
}
```

### Item UXML Template

```xml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:VisualElement class="item-row">
        <ui:VisualElement class="item-icon" name="item-icon" />
        <ui:VisualElement class="item-info">
            <ui:Label name="item-name" class="item-name" />
            <ui:Label name="item-count" class="item-count" />
        </ui:VisualElement>
    </ui:VisualElement>
</ui:UXML>
```

### Item USS

```css
.item-row {
    flex-direction: row;
    align-items: center;
    padding: 4px 8px;
    border-bottom-width: 1px;
    border-bottom-color: rgba(255, 255, 255, 0.1);
}

.item-row:hover {
    background-color: rgba(255, 255, 255, 0.05);
}

.row--alt {
    background-color: rgba(0, 0, 0, 0.1);
}

.item-icon {
    width: 40px;
    height: 40px;
    margin-right: 8px;
    border-radius: 4px;
    background-color: rgb(60, 60, 60);
}

.item-info {
    flex-grow: 1;
}

.item-name {
    font-size: 16px;
    color: rgb(220, 220, 220);
}

.item-count {
    font-size: 12px;
    color: rgb(150, 150, 150);
}
```

---

## 6. Screen Navigation Diagram

```
Screen Stack Operations
========================

Initial state:           Push MainMenu:
  +---------+              +---------+
  |  empty  |              |MainMenu | <-- top (visible)
  +---------+              +---------+

Push Settings:           Push Inventory:
  +---------+              +---------+
  |Settings | <-- top      |Inventory| <-- top (visible)
  +---------+              +---------+
  |MainMenu |              |Settings |
  +---------+              +---------+
                           |MainMenu |
                           +---------+

Pop (removes Inventory): Pop (removes Settings):
  +---------+              +---------+
  |Settings | <-- top      |MainMenu | <-- top (visible)
  +---------+              +---------+
  |MainMenu |
  +---------+

PopToRoot:               ReplaceAll(GameOver):
  +---------+              +---------+
  |MainMenu | <-- top      |GameOver | <-- top (visible)
  +---------+              +---------+

Transition Flow (Push with transitions):
  1. hideTransition.PlayAsync(root)   -- animate out current
  2. currentScreen.HideAsync()        -- cleanup current
  3. newScreen.ShowAsync()            -- setup new
  4. showTransition.PlayAsync(root)   -- animate in new

Navigation Rules:
  - Cannot pop the last screen (root is permanent)
  - Cannot push during an active transition
  - Cannot push the same screen that is already on top
  - ReplaceAll clears entire stack for hard resets
```
