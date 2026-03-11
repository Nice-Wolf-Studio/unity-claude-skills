# Rebinding & Multiplayer Reference

Detailed reference for Input System rebinding persistence and local multiplayer setup. Supplements the PATTERN blocks in the parent SKILL.md.

## Complete Rebinding Save/Load Lifecycle

### Architecture Overview

```
GAME STARTUP
  |
  v
Load InputActionAsset (from .inputactions file or auto-generated C# class)
  |
  v
Load saved overrides from PlayerPrefs/file -> LoadBindingOverridesFromJson()
  |
  v
Enable action maps
  |
  v
(gameplay...)
  |
  v
REBINDING FLOW (user opens settings)
  |
  v
Disable action being rebound
  |
  v
PerformInteractiveRebinding() -> listen for new input
  |
  v
Apply override -> Save to PlayerPrefs/file
  |
  v
Re-enable action
```

### Full Implementation

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class RebindManager : MonoBehaviour
{
    [SerializeField] private InputActionAsset inputActions;

    private const string RebindSaveKey = "inputBindingOverrides";

    // === LOADING (call in Awake, before any action maps are enabled) ===

    void Awake()
    {
        LoadRebinds();
    }

    public void LoadRebinds()
    {
        string json = PlayerPrefs.GetString(RebindSaveKey, string.Empty);
        if (!string.IsNullOrEmpty(json))
        {
            inputActions.LoadBindingOverridesFromJson(json);
        }
    }

    // === SAVING ===

    public void SaveRebinds()
    {
        string json = inputActions.SaveBindingOverridesAsJson();
        PlayerPrefs.SetString(RebindSaveKey, json);
        PlayerPrefs.Save();
    }

    // === REBINDING A SINGLE ACTION ===

    private InputActionRebindingExtensions.RebindingOperation _rebindOp;

    /// <summary>
    /// Start interactive rebinding for a specific action and binding index.
    /// </summary>
    /// <param name="action">The action to rebind</param>
    /// <param name="bindingIndex">Which binding to rebind (0 for first)</param>
    /// <param name="onComplete">Callback when rebinding finishes</param>
    public void StartRebinding(InputAction action, int bindingIndex, System.Action onComplete = null)
    {
        // Must disable the action during rebinding
        action.Disable();

        _rebindOp = action.PerformInteractiveRebinding(bindingIndex)
            .WithControlsExcluding("Mouse")           // Exclude mouse movement
            .WithControlsExcluding("<Keyboard>/escape") // Reserve Escape for cancel
            .WithCancelingThrough("<Keyboard>/escape")  // Cancel with Escape
            .WithTimeout(5f)                            // 5 second timeout
            .OnMatchWaitForAnother(0.1f)               // Brief wait for modifiers
            .OnComplete(operation =>
            {
                // Rebinding succeeded
                action.Enable();
                SaveRebinds();
                operation.Dispose(); // CRITICAL: always dispose
                _rebindOp = null;
                onComplete?.Invoke();
            })
            .OnCancel(operation =>
            {
                // User cancelled or timeout
                action.Enable();
                operation.Dispose(); // CRITICAL: always dispose
                _rebindOp = null;
                onComplete?.Invoke();
            })
            .Start();
    }

    /// <summary>
    /// Cancel an in-progress rebinding operation.
    /// </summary>
    public void CancelRebinding()
    {
        _rebindOp?.Cancel();
    }

    // === RESETTING BINDINGS ===

    /// <summary>
    /// Reset a single action's bindings to defaults.
    /// </summary>
    public void ResetBinding(InputAction action, int bindingIndex)
    {
        action.RemoveBindingOverride(bindingIndex);
        SaveRebinds();
    }

    /// <summary>
    /// Reset ALL bindings to defaults.
    /// </summary>
    public void ResetAllBindings()
    {
        foreach (var map in inputActions.actionMaps)
        {
            map.RemoveAllBindingOverrides();
        }
        SaveRebinds();
    }

    void OnDestroy()
    {
        // Cleanup any in-progress rebinding
        _rebindOp?.Dispose();
    }
}
```

### Rebinding UI Pattern

```csharp
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UIElements;

public class RebindUIElement
{
    private Button _rebindButton;
    private Label _bindingLabel;
    private InputAction _action;
    private int _bindingIndex;
    private RebindManager _rebindManager;

    public void Initialize(InputAction action, int bindingIndex, RebindManager manager,
        Button button, Label label)
    {
        _action = action;
        _bindingIndex = bindingIndex;
        _rebindManager = manager;
        _rebindButton = button;
        _bindingLabel = label;

        _rebindButton.clicked += OnRebindClicked;
        UpdateDisplay();
    }

    void OnRebindClicked()
    {
        _bindingLabel.text = "Press a key...";
        _rebindButton.SetEnabled(false);

        _rebindManager.StartRebinding(_action, _bindingIndex, () =>
        {
            UpdateDisplay();
            _rebindButton.SetEnabled(true);
        });
    }

    void UpdateDisplay()
    {
        _bindingLabel.text = _action.GetBindingDisplayString(_bindingIndex);
    }
}
```

---

## Local Multiplayer Setup Guide

### Architecture

```
PlayerInputManager (singleton, scene object)
  |
  +-- Join Settings
  |     - Join Behavior: JoinPlayersWhenButtonIsPressed / JoinPlayersWhenJoinActionTriggered
  |     - Player Prefab: prefab with PlayerInput component
  |     - Max Players: -1 (unlimited) or specific count
  |
  +-- Events
        - onPlayerJoined(PlayerInput)
        - onPlayerLeft(PlayerInput)
```

### Step-by-Step Setup

```csharp
// 1. Create InputActionAsset with control schemes:
//    - "KeyboardMouse" requiring <Keyboard> + <Mouse>
//    - "Gamepad" requiring <Gamepad>

// 2. Player Prefab requirements:
//    - PlayerInput component (set Default Map, Default Scheme = auto)
//    - Your player controller script
//    - Camera (for split-screen) or reference to shared camera

// 3. Scene setup:
//    - Empty GameObject with PlayerInputManager component
//    - Set Player Prefab
//    - Set Join Behavior

// 4. Game Manager to handle join/leave:
public class MultiplayerManager : MonoBehaviour
{
    [SerializeField] private Camera[] playerCameras;

    void OnEnable()
    {
        var manager = PlayerInputManager.instance;
        manager.onPlayerJoined += OnPlayerJoined;
        manager.onPlayerLeft += OnPlayerLeft;
    }

    void OnDisable()
    {
        if (PlayerInputManager.instance != null)
        {
            PlayerInputManager.instance.onPlayerJoined -= OnPlayerJoined;
            PlayerInputManager.instance.onPlayerLeft -= OnPlayerLeft;
        }
    }

    void OnPlayerJoined(PlayerInput playerInput)
    {
        int index = playerInput.playerIndex; // 0, 1, 2, ...
        Debug.Log($"Player {index} joined with {playerInput.currentControlScheme}");

        // Assign split-screen camera
        SetupSplitScreen(playerInput, index);

        // Assign team color, spawn point, etc.
        var controller = playerInput.GetComponent<PlayerController>();
        controller.Initialize(index);
    }

    void OnPlayerLeft(PlayerInput playerInput)
    {
        Debug.Log($"Player {playerInput.playerIndex} left");
        RecalculateSplitScreen();
    }

    void SetupSplitScreen(PlayerInput playerInput, int playerIndex)
    {
        var cam = playerInput.camera;
        if (cam == null) return;

        int totalPlayers = PlayerInputManager.instance.playerCount;

        // Dynamically adjust viewport rects
        switch (totalPlayers)
        {
            case 1:
                cam.rect = new Rect(0, 0, 1, 1); // Full screen
                break;
            case 2:
                cam.rect = playerIndex == 0
                    ? new Rect(0, 0.5f, 1, 0.5f)    // Top half
                    : new Rect(0, 0, 1, 0.5f);       // Bottom half
                break;
            case 3:
            case 4:
                float x = (playerIndex % 2) * 0.5f;
                float y = (playerIndex < 2) ? 0.5f : 0f;
                cam.rect = new Rect(x, y, 0.5f, 0.5f); // Quadrants
                break;
        }
    }

    void RecalculateSplitScreen()
    {
        var players = PlayerInput.all;
        for (int i = 0; i < players.Count; i++)
        {
            SetupSplitScreen(players[i], i);
        }
    }
}
```

### Device Assignment Rules

| Scenario | Behavior |
|----------|----------|
| 2 gamepads, press button on gamepad 1 | Player 1 assigned gamepad 1 |
| Press button on gamepad 2 | Player 2 assigned gamepad 2 |
| Only keyboard + mouse available | First player gets keyboard + mouse |
| Player with gamepad disconnects | `onPlayerLeft` fires; device unassigned |
| Gamepad reconnects | Must rejoin (not automatic) |
| Same device for two players | Not allowed -- each device assigned once |

### Accessing Per-Player Input

```csharp
// In player scripts, always read through PlayerInput -- never static device references
public class PlayerController : MonoBehaviour
{
    private PlayerInput _playerInput;

    void Awake()
    {
        _playerInput = GetComponent<PlayerInput>();
    }

    // Option A: Polling (in Update)
    void Update()
    {
        var moveAction = _playerInput.actions["Move"];
        Vector2 move = moveAction.ReadValue<Vector2>();
    }

    // Option B: SendMessages callback
    void OnMove(InputValue value)
    {
        Vector2 move = value.Get<Vector2>();
    }

    // Option C: C# events
    void OnEnable()
    {
        _playerInput.onActionTriggered += OnActionTriggered;
    }

    void OnActionTriggered(InputAction.CallbackContext ctx)
    {
        if (ctx.action.name == "Move" && ctx.performed)
        {
            Vector2 move = ctx.ReadValue<Vector2>();
        }
    }
}
```

---

## Processor Configuration

### Built-in Processors

| Processor | Input Type | Parameters | Purpose |
|-----------|-----------|------------|---------|
| `StickDeadzone` | `Vector2` | `min`, `max` | Radial deadzone for analog sticks |
| `AxisDeadzone` | `float` | `min`, `max` | Linear deadzone for triggers/axes |
| `NormalizeVector2` | `Vector2` | -- | Normalize to unit length |
| `NormalizeVector3` | `Vector3` | -- | Normalize to unit length |
| `Scale` | `float` | `factor` | Multiply value by factor |
| `ScaleVector2` | `Vector2` | `x`, `y` | Scale per axis |
| `ScaleVector3` | `Vector3` | `x`, `y`, `z` | Scale per axis |
| `Invert` | `float` | -- | Negate value |
| `InvertVector2` | `Vector2` | `invertX`, `invertY` | Negate per axis |
| `InvertVector3` | `Vector3` | `invertX`, `invertY`, `invertZ` | Negate per axis |
| `Clamp` | `float` | `min`, `max` | Clamp to range |

### Runtime Processor Override

```csharp
// Apply processor to a specific binding at runtime
var action = inputActions.FindAction("Move");
int bindingIndex = action.GetBindingIndex(InputBinding.MaskByGroup("Gamepad"));

action.ApplyBindingOverride(bindingIndex, new InputBinding
{
    overrideProcessors = "StickDeadzone(min=0.15,max=0.95)"
});

// Remove processor override (revert to asset default)
action.RemoveBindingOverride(bindingIndex);
```
