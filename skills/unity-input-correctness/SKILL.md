---
name: unity-input-correctness
description: >
  Unity New Input System correctness patterns. Catches common mistakes with action reading
  (triggered vs IsPressed vs WasPressedThisFrame), action map switching, rebinding persistence,
  InputValue lifetime, PassThrough vs Value, local multiplayer device assignment, and control
  scheme auto-switching. PATTERN format: WHEN/WRONG/RIGHT/GOTCHA. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.inputactions"
---

# Input System (New) -- Correctness Patterns

> **Prerequisite skills:** `unity-input` (Input System API, actions, bindings, PlayerInput component)

These patterns target the most common Input System bugs: wrong reading method for the action type, mixing old/new APIs, losing rebindings, and mishandling multiplayer device assignment.

---

## PATTERN: Reading Input -- triggered vs IsPressed vs WasPressedThisFrame

WHEN: Reading button/action state at runtime

WRONG (Claude default):
```csharp
// Using .triggered for continuous input (only fires once per press)
if (fireAction.triggered)
    rb.AddForce(Vector3.forward * force); // Only fires one frame, not while held

// Using .IsPressed() for one-shot actions (fires every frame while held)
if (jumpAction.IsPressed())
    Jump(); // Jumps every frame the button is held!
```

RIGHT:
```csharp
// One-shot actions (jump, interact, fire single bullet):
if (jumpAction.WasPressedThisFrame())  // True for exactly ONE frame
    Jump();

// Or use .triggered (same as WasPressedThisFrame for Button actions with default interaction)
if (jumpAction.triggered)
    Jump();

// Continuous actions (sprint, aim, hold to charge):
if (sprintAction.IsPressed())  // True every frame while held
    moveSpeed = sprintSpeed;

// Value reading (stick, mouse delta):
Vector2 moveInput = moveAction.ReadValue<Vector2>();  // Continuous value
```

GOTCHA: `.triggered` respects Interactions (Hold, Tap, etc.) -- it fires when the interaction completes. `.WasPressedThisFrame()` fires on raw press regardless of interactions. `.IsPressed()` returns true every frame while actuated above the press threshold. For `Button` type actions without interactions, `.triggered` == `.WasPressedThisFrame()`. For `Value` type actions, `.triggered` fires when the value changes from zero to non-zero.

---

## PATTERN: Action Map Switching

WHEN: Switching between action maps (e.g., Gameplay -> UI -> Vehicle)

WRONG (Claude default):
```csharp
// Forgetting that SwitchCurrentActionMap disables the previous map
playerInput.SwitchCurrentActionMap("UI");
// All "Gameplay" actions are now DISABLED -- callbacks won't fire
// If you cached Gameplay actions, they silently stop working
```

RIGHT:
```csharp
// Option 1: Via PlayerInput (handles enable/disable automatically)
playerInput.SwitchCurrentActionMap("UI");
// Previous map disabled, new map enabled

// Option 2: Manual enable/disable (more control)
gameplayActions.Disable();
uiActions.Enable();

// Option 3: Keep both maps active simultaneously
// (useful for universal actions like Pause)
gameplayActions.Enable();
pauseActions.Enable(); // Both active at once
```

GOTCHA: When using `PlayerInput.SwitchCurrentActionMap`, the previous map is fully disabled. Any cached `InputAction` references from the previous map stop firing callbacks until re-enabled. If you need certain actions (like Pause) to work across all maps, put them in a separate map that stays enabled, or use the manual enable/disable approach.

---

## PATTERN: Processor vs Interaction Confusion

WHEN: Applying deadzones or modifying input values

WRONG (Claude default):
```csharp
// Adding a deadzone as an Interaction (Interactions modify TIMING, not values)
// In .inputactions: Action > Interactions > "Deadzone" -- this doesn't exist as an interaction
```

RIGHT:
```csharp
// Deadzones are PROCESSORS -- they modify the input VALUE
// Set in .inputactions: Binding > Processors > "Stick Deadzone" or "Axis Deadzone"

// Processors modify the value stream: Raw Input -> Processor Chain -> Final Value
// Common processors:
//   StickDeadzone   -- applies radial deadzone to Vector2 (sticks)
//   AxisDeadzone    -- applies linear deadzone to float (triggers)
//   Normalize       -- normalizes Vector2 to 0-1 range
//   Invert          -- negates the value
//   Scale           -- multiplies by a factor
//   Clamp           -- clamps to min/max range

// Runtime processor override (if needed):
moveAction.ApplyBindingOverride(new InputBinding { overrideProcessors = "StickDeadzone(min=0.2,max=0.9)" });
```

GOTCHA: **Processors** transform the value (deadzone, normalize, scale, invert). **Interactions** change the timing of when `started`/`performed`/`canceled` fire (Press, Hold, Tap, SlowTap, MultiTap). Confusing them results in either no deadzone (processor missing) or wrong callback timing (interaction added where not needed).

---

## PATTERN: InputValue Lifetime in SendMessages/BroadcastMessages

WHEN: Using `PlayerInput` in SendMessages or BroadcastMessages behavior mode

WRONG (Claude default):
```csharp
private InputValue _cachedInput; // Storing the reference

void OnMove(InputValue value)
{
    _cachedInput = value; // WRONG: InputValue is pooled and recycled
}

void Update()
{
    Vector2 dir = _cachedInput.Get<Vector2>(); // May return stale or corrupt data
}
```

RIGHT:
```csharp
private Vector2 _moveInput;

void OnMove(InputValue value)
{
    // Copy the value immediately -- InputValue is only valid during the callback
    _moveInput = value.Get<Vector2>();
}

void Update()
{
    transform.Translate(_moveInput * speed * Time.deltaTime);
}
```

GOTCHA: `InputValue` is a wrapper that is reused between callbacks. Its internal data is only valid during the callback invocation. Always copy with `.Get<T>()` in the callback and store the result. This applies to SendMessages and BroadcastMessages modes. UnityEvents and C# Events modes don't use `InputValue` -- they pass `InputAction.CallbackContext` which has the same lifetime constraint.

---

## PATTERN: PassThrough vs Value for Multi-Source Input

WHEN: Handling input from multiple simultaneous sources (multi-touch, multiple gamepads)

WRONG (Claude default):
```csharp
// Using "Value" action type for multi-touch
// Value type performs disambiguation -- picks the input with highest magnitude
// You only see ONE touch, even if multiple fingers are on screen
```

RIGHT:
```csharp
// Use "PassThrough" action type for all-source input
// PassThrough does NOT disambiguate -- every input source triggers the action

// In .inputactions file: Set Action Type = "Pass Through"
// This is essential for:
//   - Multi-touch (each finger fires separately)
//   - Multiple gamepads sending the same action
//   - Combining keyboard + mouse simultaneously

// Read which device triggered it:
void OnAction(InputAction.CallbackContext ctx)
{
    var device = ctx.control.device;
    var value = ctx.ReadValue<float>();
}
```

GOTCHA: **Button**: fires on press/release, returns float 0 or 1. **Value**: fires when value changes, picks highest-magnitude source (disambiguation). **PassThrough**: fires on every change from every source, no disambiguation. For most gameplay input, `Value` is correct. Use `PassThrough` only when you need per-device or per-finger tracking.

---

## PATTERN: Action Enable/Disable Scope

WHEN: Enabling/disabling individual actions vs entire action maps

WRONG (Claude default):
```csharp
// Enabling an action without enabling its map
fireAction.Enable(); // Works, BUT...
// If the map was disabled, this implicitly enables JUST this action
// Other actions in the same map remain disabled
```

RIGHT:
```csharp
// Preferred: Enable/disable at the MAP level
playerActions.Enable();  // Enables all actions in the map
playerActions.Disable(); // Disables all actions

// Individual action enable/disable (advanced use only):
fireAction.Enable();  // Enables this action even if map is disabled
fireAction.Disable(); // Disables only this action

// Check state:
bool mapEnabled = playerActions.enabled;
bool actionEnabled = fireAction.enabled;
```

GOTCHA: An action can be enabled while its containing map is "disabled" -- the action still works. But this creates confusing state: `map.enabled` returns false while `action.enabled` returns true. Best practice: always enable/disable at the map level. Only use per-action enable/disable for special cases like temporarily disabling fire while reloading.

---

## PATTERN: Device-Specific Button Prompts

WHEN: Displaying control hints to the player (e.g., "Press X to interact")

WRONG (Claude default):
```csharp
// Hardcoded button names
promptText.text = "Press A to Jump";
// Wrong on keyboard (should be "Space"), PS5 (should be "Cross"), etc.
```

RIGHT:
```csharp
// Get the display name for the current binding
InputAction jumpAction = inputActions.FindAction("Jump");

// Get display string for the active control scheme
string displayName = jumpAction.GetBindingDisplayString(
    InputBinding.DisplayStringOptions.DontOmitDevice);
promptText.text = $"Press {displayName} to Jump";

// For a specific control scheme:
int bindingIndex = jumpAction.GetBindingIndex(
    InputBinding.MaskByGroup("Gamepad"));
if (bindingIndex >= 0)
{
    string gamepadPrompt = jumpAction.GetBindingDisplayString(bindingIndex);
    // Returns "Button South" or device-specific name
}
```

GOTCHA: `GetBindingDisplayString()` returns human-readable names. Without parameters, it returns the string for the first binding. Use binding masks or indices to target specific control schemes. For full icon support, you need a custom `InputBindingComposite` or asset that maps control paths to sprite/icon references -- Unity does not provide built-in icon mapping.

---

## PATTERN: Local Multiplayer Device Assignment

WHEN: Supporting multiple players on the same machine with separate controllers

WRONG (Claude default):
```csharp
// Both players reading from the same static device reference
Vector2 p1Move = Gamepad.current.leftStick.ReadValue();
Vector2 p2Move = Gamepad.current.leftStick.ReadValue(); // Same gamepad!
```

RIGHT:
```csharp
// Use PlayerInputManager for automatic device assignment
// 1. Add PlayerInputManager component to a manager object
// 2. Set Join Behavior (e.g., JoinPlayersWhenButtonIsPressed)
// 3. Set Player Prefab (must have PlayerInput component)
// PlayerInputManager automatically assigns unique devices to each player

// In the player script:
public class PlayerController : MonoBehaviour
{
    private PlayerInput _playerInput;
    private InputAction _moveAction;

    void Awake()
    {
        _playerInput = GetComponent<PlayerInput>();
        _moveAction = _playerInput.actions["Move"];
    }

    void Update()
    {
        // Each PlayerInput instance reads from its ASSIGNED device only
        Vector2 move = _moveAction.ReadValue<Vector2>();
        transform.Translate(move * speed * Time.deltaTime);
    }
}

// Listen for join/leave events:
void OnEnable()
{
    PlayerInputManager.instance.onPlayerJoined += OnPlayerJoined;
    PlayerInputManager.instance.onPlayerLeft += OnPlayerLeft;
}
```

GOTCHA: `Gamepad.current` returns the most recently used gamepad -- NOT a specific player's gamepad. For multiplayer, always read input through the `PlayerInput` component which manages device assignment. `PlayerInputManager.instance.maxPlayerCount` limits players. Split-screen is handled via `PlayerInput.camera` assignment -- each player gets a camera with a different viewport rect.

---

## PATTERN: Control Scheme Auto-Switching

WHEN: Players switch between keyboard and gamepad mid-game

WRONG (Claude default):
```csharp
// Assuming the control scheme is fixed after startup
// UI shows keyboard prompts even after player picks up a gamepad
```

RIGHT:
```csharp
public class ControlSchemeHandler : MonoBehaviour
{
    private PlayerInput _playerInput;

    void OnEnable()
    {
        _playerInput = GetComponent<PlayerInput>();
        _playerInput.controlsChangedEvent.AddListener(OnControlsChanged);
        // Initialize with current scheme
        UpdatePrompts(_playerInput.currentControlScheme);
    }

    void OnDisable()
    {
        _playerInput.controlsChangedEvent.RemoveListener(OnControlsChanged);
    }

    void OnControlsChanged(PlayerInput input)
    {
        UpdatePrompts(input.currentControlScheme);
    }

    void UpdatePrompts(string schemeName)
    {
        bool isGamepad = schemeName == "Gamepad";
        // Update UI prompts, button icons, etc.
        promptIcon.sprite = isGamepad ? gamepadSprite : keyboardSprite;
    }
}
```

GOTCHA: `PlayerInput` auto-switches control schemes when it detects input from a different device type. `controlsChangedEvent` fires on every switch. `currentControlScheme` returns the name string matching your `.inputactions` control scheme names. The switch happens on the next input event, not immediately on device connection. Test with both devices plugged in simultaneously.

---

## Anti-Patterns Quick Reference

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `Input.GetKey` mixed with new Input System | Old and new API conflict; may require both backends active | Fully migrate to new Input System; remove `using UnityEngine.Input` |
| Not calling `action.Enable()` | Action does nothing; no errors | Enable action map or individual action before reading |
| Reading `.ReadValue<T>()` with wrong type `T` | Returns default value silently | Match `T` to action's Control Type (Vector2 for Stick, float for Button) |
| Forgetting to dispose `PerformInteractiveRebinding` | Memory leak | Always call `.Dispose()` after `.Start()` completes or is cancelled |
| Using legacy `OnGUI` for input | Mixes IMGUI with Input System | Use UI Toolkit or Input System callbacks |
| Not saving rebind overrides | Players lose custom bindings on restart | Save with `SaveBindingOverridesAsJson`, load in Awake |

## Related Skills

- **unity-input** -- Input System API reference, action types, binding syntax, device access
- **unity-ui** -- UI Toolkit input handling, navigation events
- **unity-multiplayer** -- Netcode input authority, client prediction

## Additional Resources

- [Input System Manual](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/index.html)
- [InputAction API](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/api/UnityEngine.InputSystem.InputAction.html)
- [PlayerInput API](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/api/UnityEngine.InputSystem.PlayerInput.html)
- [PlayerInputManager](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/api/UnityEngine.InputSystem.PlayerInputManager.html)
- [Interactive Rebinding](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/ActionBindings.html#interactive-rebinding)
