# Input System API Reference

> Based on Unity Input System package v1.14+ for Unity 6.3 LTS.
> Source: [Unity Input System Documentation](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/index.html)

## Namespace

```csharp
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Interactions; // For interaction types
using UnityEngine.InputSystem.EnhancedTouch; // For enhanced touch API
```

---

## InputSystem (Static Class)

The central hub for the Input System.

| Member | Type | Description |
|--------|------|-------------|
| `InputSystem.actions` | `InputActionAsset` | Project-wide actions asset |
| `InputSystem.devices` | `ReadOnlyArray<InputDevice>` | All registered devices |
| `InputSystem.onDeviceChange` | `event Action<InputDevice, InputDeviceChange>` | Device added/removed/etc. |
| `InputSystem.PauseHaptics()` | Method | Pause all haptic output globally |
| `InputSystem.ResumeHaptics()` | Method | Resume paused haptics |
| `InputSystem.ResetHaptics()` | Method | Reset all haptics to initial state |
| `InputSystem.RegisterInteraction<T>()` | Method | Register a custom interaction |

### Device Change Types

```csharp
InputSystem.onDeviceChange += (device, change) =>
{
    // InputDeviceChange values:
    // Added, Removed, Disconnected, Reconnected,
    // Enabled, Disabled, ConfigurationChanged, SoftReset, HardReset
};
```

---

## InputAction

Represents a single input action that can have multiple bindings.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Action name |
| `type` | `InputActionType` | Value, Button, or PassThrough |
| `enabled` | `bool` | Whether the action is currently enabled |
| `phase` | `InputActionPhase` | Current phase (Disabled, Waiting, Started, Performed, Canceled) |
| `bindings` | `ReadOnlyArray<InputBinding>` | All bindings on this action |
| `activeControl` | `InputControl` | The control currently driving the action |

### Action Types

| Type | Behavior |
|------|----------|
| `InputActionType.Value` | Continuous value; triggers on every change. Best for axes, sticks, movement. |
| `InputActionType.Button` | Discrete press; triggers on press point threshold. Best for jump, fire. |
| `InputActionType.PassThrough` | Raw pass-through; no conflict resolution. Best for multi-touch, debug. |

### Reading Values

```csharp
// Generic read
Vector2 move = moveAction.ReadValue<Vector2>();
float trigger = triggerAction.ReadValue<float>();

// Button state queries
bool held = action.IsPressed();
bool justPressed = action.WasPressedThisFrame();
bool justReleased = action.WasReleasedThisFrame();
```

### Callbacks

```csharp
action.started += ctx => { /* Input began */ };
action.performed += ctx => { /* Action completed */ };
action.canceled += ctx => { /* Interrupted or released */ };
```

### CallbackContext

| Member | Description |
|--------|-------------|
| `ctx.ReadValue<T>()` | Read the value that triggered the callback |
| `ctx.performed` | True if this is the performed phase |
| `ctx.started` | True if this is the started phase |
| `ctx.canceled` | True if this is the canceled phase |
| `ctx.interaction` | The interaction driving this callback |
| `ctx.control` | The control that triggered the action |
| `ctx.time` | Timestamp of the input event |
| `ctx.duration` | Time since the action started |

### Enable / Disable

```csharp
action.Enable();   // Must call before action responds to input
action.Disable();  // Must call before modifying bindings

// Enable/disable entire maps
actionMap.Enable();
actionMap.Disable();
```

### Creating Actions in Code

```csharp
// Simple action
var jumpAction = new InputAction("Jump", InputActionType.Button, "<Keyboard>/space");

// Action with composite binding
var moveAction = new InputAction("Move", InputActionType.Value);
moveAction.AddCompositeBinding("2DVector")
    .With("Up", "<Keyboard>/w")
    .With("Down", "<Keyboard>/s")
    .With("Left", "<Keyboard>/a")
    .With("Right", "<Keyboard>/d");

// Action with interaction
var fireAction = new InputAction("Fire");
fireAction.AddBinding("<Gamepad>/buttonSouth")
    .WithInteractions("tap,slowTap");
```

---

## InputActionMap

A named collection of actions.

```csharp
// Find action within a map
var action = actionMap.FindAction("Move");

// Enable/disable all actions in the map
actionMap.Enable();
actionMap.Disable();

// Create from JSON
var maps = InputActionMap.FromJson(jsonString);
```

---

## InputActionAsset

A persistent asset containing multiple action maps and control schemes.

```csharp
// Find action across all maps
var action = asset.FindAction("Player/Move");

// Find action map
var playerMap = asset.FindActionMap("Player");

// Iterate maps
foreach (var map in asset.actionMaps) { /* ... */ }
```

### Auto-Generated C# Class

When "Generate C# Class" is enabled on the asset:

```csharp
public class PlayerActions : MonoBehaviour, IGameplayActions
{
    MyControls controls;

    void OnEnable()
    {
        controls = new MyControls();
        controls.gameplay.SetCallbacks(this);
        controls.gameplay.Enable();
    }

    void OnDisable()
    {
        controls.gameplay.Disable();
        controls.Dispose();
    }

    // Interface callback
    public void OnMove(InputAction.CallbackContext context)
    {
        Vector2 move = context.ReadValue<Vector2>();
    }

    public void OnFire(InputAction.CallbackContext context)
    {
        if (context.performed) { /* fire */ }
    }
}
```

---

## Binding Syntax (Control Paths)

Bindings use a path syntax to identify controls on devices.

### Path Format

```
<DeviceType>/controlPath
```

### Common Paths

| Path | Description |
|------|-------------|
| `<Keyboard>/space` | Spacebar |
| `<Keyboard>/w` | W key |
| `<Keyboard>/leftShift` | Left Shift |
| `<Keyboard>/escape` | Escape key |
| `<Mouse>/leftButton` | Left mouse button |
| `<Mouse>/rightButton` | Right mouse button |
| `<Mouse>/position` | Mouse position (Vector2) |
| `<Mouse>/delta` | Mouse movement delta (Vector2) |
| `<Mouse>/scroll` | Mouse scroll wheel (Vector2) |
| `<Gamepad>/leftStick` | Left analog stick (Vector2) |
| `<Gamepad>/rightStick` | Right analog stick (Vector2) |
| `<Gamepad>/buttonSouth` | A (Xbox) / Cross (PS) |
| `<Gamepad>/buttonNorth` | Y (Xbox) / Triangle (PS) |
| `<Gamepad>/buttonEast` | B (Xbox) / Circle (PS) |
| `<Gamepad>/buttonWest` | X (Xbox) / Square (PS) |
| `<Gamepad>/leftShoulder` | LB / L1 |
| `<Gamepad>/rightShoulder` | RB / R1 |
| `<Gamepad>/leftTrigger` | LT / L2 (float axis) |
| `<Gamepad>/rightTrigger` | RT / R2 (float axis) |
| `<Gamepad>/dpad` | D-pad (DpadControl) |
| `<Gamepad>/dpad/up` | D-pad up |
| `<Gamepad>/startButton` | Start / Options |
| `<Gamepad>/selectButton` | Select / Share |
| `<Gamepad>/leftStickPress` | L3 / Left stick click |
| `<Gamepad>/rightStickPress` | R3 / Right stick click |
| `<Touchscreen>/primaryTouch/position` | Primary touch position |
| `<Touchscreen>/primaryTouch/press` | Primary touch active |
| `<Touchscreen>/touch*/press` | Any touch (wildcard) |
| `<Touchscreen>/touch3/press` | Specific touch by index |

### Composite Bindings

| Composite | Output | Parts |
|-----------|--------|-------|
| `1DAxis` | `float` | `negative`, `positive` |
| `2DVector` / `Dpad` | `Vector2` | `up`, `down`, `left`, `right` |
| `ButtonWithOneModifier` | `float` | `modifier`, `button` |
| `ButtonWithTwoModifiers` | `float` | `modifier1`, `modifier2`, `button` |

```csharp
// WASD composite
action.AddCompositeBinding("2DVector")
    .With("Up", "<Keyboard>/w")
    .With("Down", "<Keyboard>/s")
    .With("Left", "<Keyboard>/a")
    .With("Right", "<Keyboard>/d");

// 1D axis (zoom in/out)
action.AddCompositeBinding("1DAxis")
    .With("Negative", "<Keyboard>/q")
    .With("Positive", "<Keyboard>/e");

// Modifier (Ctrl+S)
action.AddCompositeBinding("ButtonWithOneModifier")
    .With("Modifier", "<Keyboard>/leftCtrl")
    .With("Button", "<Keyboard>/s");
```

---

## Control Schemes

Control Schemes define device requirements for a set of bindings.

| Concept | Description |
|---------|-------------|
| Control Scheme | Named group (e.g., "Keyboard&Mouse", "Gamepad") |
| Device Requirement | Specifies required devices for the scheme |
| Binding Groups | Tag bindings to belong to specific schemes |

Control Schemes are configured in the Input Actions editor and allow automatic scheme switching based on detected devices.

---

## PlayerInput Component API

| Member | Description |
|--------|-------------|
| `playerInput.actions` | The action asset (private copy) |
| `playerInput.currentActionMap` | Currently active action map |
| `playerInput.currentControlScheme` | Active control scheme name |
| `playerInput.SwitchCurrentActionMap(string)` | Switch to named action map |
| `playerInput.ActivateInput()` | Enable input with default map |
| `playerInput.DeactivateInput()` | Disable all input |
| `playerInput.onActionTriggered` | C# event for any action trigger |
| `playerInput.onDeviceLost` | C# event when paired device disconnects |
| `playerInput.onDeviceRegained` | C# event when device reconnects |

### Behavior Modes

**Send Messages:** Calls `OnActionName()` on the same GameObject.

```csharp
public void OnMove(InputValue value)
{
    Vector2 v = value.Get<Vector2>();
}
public void OnJump() { /* triggered */ }
```

**Invoke Unity Events:** Wire actions to methods in the Inspector.

```csharp
public void OnFire(InputAction.CallbackContext context)
{
    if (context.performed) { /* fire */ }
}
```

**Invoke C# Events:** Subscribe programmatically.

```csharp
playerInput.onActionTriggered += ctx =>
{
    if (ctx.action.name == "Jump" && ctx.performed)
        Jump();
};
```

---

## Device Classes

### Gamepad

```csharp
Gamepad gp = Gamepad.current; // null if none connected

// Sticks (Vector2, deadzoned)
Vector2 left = gp.leftStick.ReadValue();
Vector2 right = gp.rightStick.ReadValue();

// Buttons
bool a = gp.buttonSouth.isPressed;
bool pressed = gp.buttonSouth.wasPressedThisFrame;
bool released = gp.buttonSouth.wasReleasedThisFrame;

// Triggers (float 0-1)
float lt = gp.leftTrigger.ReadValue();

// D-pad
bool up = gp.dpad.up.isPressed;

// Access by enum
gp[GamepadButton.North].isPressed;

// Haptics
gp.SetMotorSpeeds(0.25f, 0.75f);
gp.PauseHaptics();
gp.ResumeHaptics();
gp.ResetHaptics();
```

**Supported gamepads:**
- DualShock 3 (HID, macOS only)
- DualShock 4 (HID: macOS, Windows, UWP, Linux; iOS via Bluetooth)
- DualSense (HID: macOS, Windows)
- Xbox controllers (XInput: Windows/UWP; Bluetooth: macOS, iOS)
- Switch Pro (Bluetooth: desktop)

Generic HID gamepads surface as `Joystick`, not `Gamepad`.

### Keyboard

```csharp
Keyboard kb = Keyboard.current;

bool space = kb.spaceKey.wasPressedThisFrame;
bool shift = kb.leftShiftKey.isPressed;
bool anyKey = kb.anyKey.isPressed;

// By Key enum
kb[Key.W].isPressed;
```

### Mouse

```csharp
Mouse mouse = Mouse.current;

Vector2 pos = mouse.position.ReadValue();
Vector2 delta = mouse.delta.ReadValue();
float scrollY = mouse.scroll.ReadValue().y;
bool leftClick = mouse.leftButton.isPressed;
bool rightClick = mouse.rightButton.isPressed;
bool middleClick = mouse.middleButton.isPressed;
```

### Touchscreen

```csharp
Touchscreen ts = Touchscreen.current;

// Primary touch
if (ts.primaryTouch.press.isPressed)
{
    Vector2 pos = ts.primaryTouch.position.ReadValue();
    Vector2 delta = ts.primaryTouch.delta.ReadValue();
    TouchPhase phase = ts.primaryTouch.phase.ReadValue();
}

// All touches
foreach (var touch in ts.touches)
{
    if (touch.press.isPressed)
    {
        int id = touch.touchId.ReadValue();
        Vector2 pos = touch.position.ReadValue();
    }
}
```

### EnhancedTouch API

Must be explicitly enabled. Provides a higher-level API similar to legacy `Input.touches`.

```csharp
using UnityEngine.InputSystem.EnhancedTouch;

void OnEnable() => EnhancedTouchSupport.Enable();
void OnDisable() => EnhancedTouchSupport.Disable();

void Update()
{
    // By touch
    foreach (var touch in Touch.activeTouches)
    {
        Debug.Log($"ID:{touch.touchId} Pos:{touch.screenPosition} Phase:{touch.phase}");
    }

    // By finger
    foreach (var finger in Touch.activeFingers)
    {
        var touch = finger.currentTouch;
        Debug.Log($"Finger {finger.index}: {touch.screenPosition}");
    }
}
```

**Touch Simulation:** Simulate touch from mouse/pen during development.

```csharp
TouchSimulation.Enable();  // In code
// Or: Input Debugger > Options > Simulate Touch Input From Mouse or Pen
```

---

## Interactions

### Built-in Interactions

#### Default (implicit)
Applied when no explicit interaction is set. Behavior depends on action type:
- **Value**: Callbacks on every value change
- **Button**: Callbacks on press threshold crossing
- **PassThrough**: Callbacks on every value change, no conflict resolution

#### Press
Explicit button-press behavior.

| Parameter | Type | Description |
|-----------|------|-------------|
| `pressPoint` | float | Actuation threshold (default from InputSettings) |
| `behavior` | PressBehavior | `PressOnly`, `ReleaseOnly`, `PressAndRelease` |

#### Hold
Sustained actuation for minimum duration.

| Parameter | Type | Description |
|-----------|------|-------------|
| `duration` | float | Required hold time |
| `pressPoint` | float | Actuation threshold |

```csharp
// Hold to charge
action.started += _ => ShowChargeUI();
action.performed += _ => FinishCharging();
action.canceled += _ => HideChargeUI();
```

#### Tap
Quick press and release within time window.

| Parameter | Type | Description |
|-----------|------|-------------|
| `duration` | float | Maximum time for tap |
| `pressPoint` | float | Actuation threshold |

#### SlowTap
Hold for minimum duration, then release to trigger.

| Parameter | Type | Description |
|-----------|------|-------------|
| `duration` | float | Minimum hold time |
| `pressPoint` | float | Actuation threshold |

#### MultiTap
Repeated tap sequences (e.g., double-tap).

| Parameter | Type | Description |
|-----------|------|-------------|
| `tapTime` | float | Max duration per tap |
| `tapDelay` | float | Max gap between taps (default: 2x tapTime) |
| `tapCount` | int | Number of taps required (default: 2) |
| `pressPoint` | float | Actuation threshold |

### Applying Interactions

```csharp
// Via code
action.AddBinding("<Gamepad>/buttonSouth")
    .WithInteractions("hold(duration=0.4)");

action.AddBinding("<Keyboard>/space")
    .WithInteractions("multiTap(tapCount=3,tapTime=0.3)");

// Multiple interactions (evaluated in order)
action.AddBinding("<Gamepad>/buttonSouth")
    .WithInteractions("tap,slowTap(duration=1.0)");
```

### Timeout Completion

```csharp
// Check how far through a timed interaction
float pct = playerInput.actions["warp"].GetTimeoutCompletionPercentage();
```

### Custom Interactions

Implement `IInputInteraction` and register with the system:

```csharp
public class HoldAndReleaseInteraction : IInputInteraction
{
    public float duration = 0.5f;

    public void Process(ref InputInteractionContext context)
    {
        if (context.timerHasExpired)
        {
            context.Canceled();
            return;
        }

        switch (context.phase)
        {
            case InputActionPhase.Waiting:
                if (context.ControlIsActuated())
                {
                    context.Started();
                    context.SetTimeout(duration);
                }
                break;

            case InputActionPhase.Started:
                if (!context.ControlIsActuated())
                    context.Performed(); // Released after hold
                break;
        }
    }

    public void Reset() { }
}

// Registration (call once, e.g., in [RuntimeInitializeOnLoadMethod])
InputSystem.RegisterInteraction<HoldAndReleaseInteraction>();

// Usage
var action = new InputAction(interactions: "HoldAndRelease(duration=0.8)");
```

---

## Runtime Rebinding

```csharp
InputAction action = /* your action */;

// Start interactive rebinding
var rebindOp = action.PerformInteractiveRebinding()
    .WithControlsExcluding("<Mouse>")       // Exclude mouse
    .WithControlsExcluding("<Keyboard>/escape") // Exclude escape
    .WithCancelingThrough("<Keyboard>/escape")  // Cancel with escape
    .OnMatchWaitForAnother(0.1f)            // Debounce
    .OnComplete(operation =>
    {
        string newPath = operation.action.bindings[0].effectivePath;
        Debug.Log($"Rebound to: {newPath}");
        operation.Dispose(); // Always dispose
    })
    .OnCancel(operation =>
    {
        Debug.Log("Rebinding cancelled");
        operation.Dispose();
    })
    .Start();

// Save bindings as JSON
string overrides = action.SaveBindingOverridesAsJson();

// Load bindings from JSON
action.LoadBindingOverridesFromJson(overrides);
```

---

## Input Debugging

### Input Debugger Window
Open via **Window > Analysis > Input Debugger**. Shows:
- All registered devices and their controls
- Active actions and their states
- Event trace

### Touch Simulation
Enable in Input Debugger: **Options > Simulate Touch Input From Mouse or Pen**.

### Common Debug Patterns

```csharp
// Log all device connections
InputSystem.onDeviceChange += (device, change) =>
    Debug.Log($"Device {change}: {device.displayName} ({device.GetType().Name})");

// List all devices
foreach (var device in InputSystem.devices)
    Debug.Log($"{device.displayName}: {device.GetType().Name}");

// Check action state
Debug.Log($"Move phase: {moveAction.phase}, value: {moveAction.ReadValue<Vector2>()}");
```

---

## Source Documentation

- [Input System Overview](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/index.html)
- [Quick Start Guide](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/QuickStartGuide.html)
- [Actions](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Actions.html)
- [Action Assets](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/ActionAssets.html)
- [PlayerInput Component](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/PlayerInput.html)
- [Gamepad](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Gamepad.html)
- [Touch](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Touch.html)
- [Interactions](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Interactions.html)
- [Unity 6.3 Package Page](https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.inputsystem.html)
