---
name: unity-input
description: >
  Unity 6 Input System guide. Use when handling player input, controls, gamepad, keyboard, mouse, touch, or XR controllers. Covers the new Input System package (recommended), Input Actions, Action Maps, Control Schemes, PlayerInput component, and input debugging. Based on Unity 6.3 LTS documentation.
---

# Unity Input System

## Input System Overview: New vs Legacy

Unity provides two input systems:

| Feature | New Input System (Recommended) | Legacy Input Manager |
|---------|-------------------------------|---------------------|
| Package | `com.unity.inputsystem` (v1.19.0 for Unity 6.3) | Built-in (`UnityEngine.Input`) |
| Architecture | Action-based, event-driven | Polling-based |
| Device Support | Gamepad, keyboard, mouse, touch, XR, custom | Keyboard, mouse, joystick |
| Multiplayer | Built-in local multiplayer via PlayerInput | Manual implementation |
| Rebinding | Runtime rebinding support | Not supported |
| Cross-platform | Control Schemes per device type | Manual per-platform code |

The new Input System is a package installed via Package Manager. It replaces the legacy `Input.GetKey`/`Input.GetAxis` API with an action-based model that separates input purpose from device controls.

**Namespace:** `UnityEngine.InputSystem`

## Quick Start Setup

### 1. Install the Package
Install via **Window > Package Manager > Unity Registry > Input System**.

### 2. Create Default Project-Wide Actions
Go to **Edit > Project Settings > Input System Package > Input Actions** and click **"Create and assign a default project-wide Action Asset"**.

This creates default Action Maps:
- **Player**: Move, Look, Jump, Attack
- **UI**: Navigate, Submit, Cancel

Each action includes bindings for keyboard, gamepad, XR controllers, and touchscreen.

### 3. Read Input in a Script

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : MonoBehaviour
{
    InputAction moveAction;
    InputAction jumpAction;

    void Start()
    {
        moveAction = InputSystem.actions.FindAction("Move");
        jumpAction = InputSystem.actions.FindAction("Jump");
    }

    void Update()
    {
        Vector2 moveValue = moveAction.ReadValue<Vector2>();
        transform.Translate(new Vector3(moveValue.x, 0, moveValue.y) * Time.deltaTime * 5f);

        if (jumpAction.IsPressed())
        {
            // Jump logic
        }
    }
}
```

When multiple actions share names across maps, specify both: `"Player/Move"`.

## Input Actions and Action Maps

### Core Concepts

- **InputAction**: A named action that returns control values or triggers callbacks
- **InputActionMap**: A named collection of related actions (e.g., "Player", "UI", "Vehicle")
- **InputBinding**: Relationship between an action and a device control
- **InputSystem.actions**: Reference to project-wide actions

### Creating Actions

**Method 1 — Input Actions Editor (Recommended):**
Configure via Project Settings > Input System Package.

**Method 2 — MonoBehaviour fields:** Declare `InputAction` fields directly in scripts (configurable in Inspector).

**Method 3 — Code:**

```csharp
var moveAction = new InputAction("Move", InputActionType.Value);
moveAction.AddCompositeBinding("Dpad")
    .With("Up", "<Keyboard>/w").With("Down", "<Keyboard>/s")
    .With("Left", "<Keyboard>/a").With("Right", "<Keyboard>/d");
moveAction.Enable();
```

**Method 4 — JSON:** `var map = InputActionMap.FromJson(jsonString);`

### Action Lifecycle
Actions begin **disabled**. You must call `.Enable()` before they respond to input. You cannot modify bindings while enabled; call `.Disable()` first.

### Input Action Assets (.inputactions)

These are JSON files storing actions, bindings, and control schemes. Create via **Assets > Create > Input Actions**.

**Auto-generated C# class:** Enable "Generate C# Class" in the asset's importer to get type-safe access:

```csharp
public class MyPlayerScript : MonoBehaviour, IGameplayActions
{
    MyPlayerControls controls;

    public void OnEnable()
    {
        controls = new MyPlayerControls();
        controls.gameplay.SetCallbacks(this);
        controls.gameplay.Enable();
    }

    public void OnDisable()
    {
        controls.gameplay.Disable();
    }

    public void OnMove(InputAction.CallbackContext context)
    {
        Vector2 move = context.ReadValue<Vector2>();
        // Handle movement
    }
}
```

## PlayerInput Component

The `PlayerInput` component maps Input Actions to script methods and handles local multiplayer with device filtering and screen-splitting.

### Setup
1. Add `PlayerInput` component to your player GameObject
2. Assign your Action Asset to the **Actions** field
3. Select a **Default Action Map**
4. Choose a **Behavior** notification type

### Behavior Options

| Behavior | Mechanism | Best For |
|----------|-----------|----------|
| **Send Messages** | `GameObject.SendMessage()` | Simple prototyping |
| **Broadcast Messages** | `BroadcastMessage()` down hierarchy | Component hierarchies |
| **Invoke Unity Events** | Inspector-configured event routing | Designer-friendly wiring |
| **Invoke C# Events** | `onActionTriggered`, `onDeviceLost`, `onDeviceRegained` | Programmer control |

### Send Messages Pattern

```csharp
public class PlayerActions : MonoBehaviour
{
    public void OnJump()
    {
        // Called when Jump action triggers (no parameters)
    }

    public void OnMove(InputValue value)
    {
        Vector2 v = value.Get<Vector2>();
        // InputValue is only valid during this callback
    }
}
```

### Unity Events Pattern

```csharp
public void OnFire(InputAction.CallbackContext context)
{
    if (context.performed)
    {
        // Fire logic
    }
}
```

### Managing PlayerInput

```csharp
PlayerInput playerInput = GetComponent<PlayerInput>();
playerInput.DeactivateInput();                      // Disable all input
playerInput.ActivateInput();                         // Re-enable with default map
playerInput.SwitchCurrentActionMap("Vehicle");       // Switch action map
```

## Reading Input in Code

### Polling (in Update)

```csharp
// 2D movement axis
Vector2 move = moveAction.ReadValue<Vector2>();

// Button state
if (jumpAction.IsPressed()) { /* held down */ }
if (jumpAction.WasPressedThisFrame()) { /* just pressed */ }
if (jumpAction.WasReleasedThisFrame()) { /* just released */ }
```

### Callbacks (Event-Driven)

```csharp
void OnEnable()
{
    fireAction.started += OnFireStarted;
    fireAction.performed += OnFirePerformed;
    fireAction.canceled += OnFireCanceled;
    fireAction.Enable();
}

void OnDisable()
{
    fireAction.started -= OnFireStarted;
    fireAction.performed -= OnFirePerformed;
    fireAction.canceled -= OnFireCanceled;
    fireAction.Disable();
}

void OnFireStarted(InputAction.CallbackContext ctx) { /* Input began */ }
void OnFirePerformed(InputAction.CallbackContext ctx) { /* Completed */ }
void OnFireCanceled(InputAction.CallbackContext ctx) { /* Interrupted */ }
```

## Gamepad / Keyboard / Mouse / Touch

### Gamepad

```csharp
using UnityEngine.InputSystem;

// Current gamepad (null if none connected)
var gp = Gamepad.current;
if (gp == null) return;

Vector2 leftStick = gp.leftStick.ReadValue();
bool southPressed = gp.buttonSouth.isPressed;

// Access by enum
gp[GamepadButton.LeftShoulder].isPressed;
gp[GamepadButton.Y].isPressed;          // Xbox style
gp[GamepadButton.Triangle].isPressed;   // PlayStation style

// Rumble / Haptics
gp.SetMotorSpeeds(0.25f, 0.75f); // low-frequency, high-frequency
gp.ResetHaptics();

// Global haptics control
InputSystem.PauseHaptics();
InputSystem.ResumeHaptics();
InputSystem.ResetHaptics();
```

Supported gamepads: DualShock 3/4, DualSense, Xbox (XInput/Bluetooth), Switch Pro. Generic HID gamepads appear as generic joysticks, not `Gamepad` devices.

### Keyboard and Mouse

```csharp
var kb = Keyboard.current;
if (kb.spaceKey.wasPressedThisFrame) { /* space pressed */ }

var mouse = Mouse.current;
Vector2 mousePos = mouse.position.ReadValue();
float scroll = mouse.scroll.ReadValue().y;
bool leftClick = mouse.leftButton.isPressed;
```

### Touch

Two API levels:

**Low-level — Touchscreen device:**

```csharp
var ts = Touchscreen.current;
if (ts.primaryTouch.press.isPressed)
{
    Vector2 pos = ts.primaryTouch.position.ReadValue();
}
```

**High-level — EnhancedTouch API:**

```csharp
using UnityEngine.InputSystem.EnhancedTouch;

void OnEnable() => EnhancedTouchSupport.Enable();
void OnDisable() => EnhancedTouchSupport.Disable();

void Update()
{
    foreach (var touch in Touch.activeTouches)
    {
        Debug.Log($"{touch.touchId}: {touch.screenPosition}, {touch.phase}");
    }
}
```

Touch phases: `Began`, `Moved`, `Stationary`, `Ended`, `Cancelled`.

**Multi-touch with Actions:** Bind `<Touchscreen>/touch*/press` and set action type to **PassThrough** to receive callbacks per touch.

**Touch simulation:** Enable via `TouchSimulation.Enable()` to simulate touch from mouse/pen during development.

### Device Discovery

```csharp
// Monitor device connections
InputSystem.onDeviceChange += (device, change) =>
{
    if (change == InputDeviceChange.Added)
        Debug.Log($"Device connected: {device.displayName}");
};
```

## Interactions and Processors

Interactions define input patterns that drive action phases.

### Interaction Phases

| Phase | Meaning |
|-------|---------|
| **Waiting** | Awaiting input |
| **Started** | Input received, not yet complete |
| **Performed** | Interaction complete — primary response trigger |
| **Canceled** | Interaction interrupted |

### Built-in Interactions

| Interaction | Description | Key Parameters |
|-------------|-------------|----------------|
| **Default** | Auto-applied; behavior varies by action type | — |
| **Press** | Explicit button press behavior | `pressPoint`, `behavior` (PressOnly/ReleaseOnly/PressAndRelease) |
| **Hold** | Sustained press for minimum duration | `duration`, `pressPoint` |
| **Tap** | Quick press-and-release | `duration`, `pressPoint` |
| **SlowTap** | Hold then release | `duration`, `pressPoint` |
| **MultiTap** | Repeated tap sequences | `tapTime`, `tapDelay`, `tapCount`, `pressPoint` |

### Adding Interactions via Code

```csharp
var action = new InputAction("fire");
action.AddBinding("<Gamepad>/buttonSouth")
    .WithInteractions("tap(duration=0.8)");
```

### Tap vs Hold Example (Fire vs Charge)

```csharp
var fireAction = new InputAction("fire");
fireAction.AddBinding("<Gamepad>/buttonSouth").WithInteractions("tap,slowTap");
fireAction.started += ctx => { if (ctx.interaction is SlowTapInteraction) ShowChargingUI(); };
fireAction.performed += ctx => {
    if (ctx.interaction is SlowTapInteraction) ChargedFire(); else Fire();
};
fireAction.canceled += _ => HideChargingUI();
fireAction.Enable();
```

### Custom Interaction

Implement `IInputInteraction`, then register: `InputSystem.RegisterInteraction<T>()`. See `references/input-system-api.md` for full example.

## Common Patterns

### Action Map Switching (e.g., Gameplay vs UI)

```csharp
public class GameStateManager : MonoBehaviour
{
    PlayerInput playerInput;

    void Start() => playerInput = GetComponent<PlayerInput>();

    public void EnterMenu() => playerInput.SwitchCurrentActionMap("UI");
    public void ExitMenu() => playerInput.SwitchCurrentActionMap("Player");
}
```

### Runtime Rebinding

```csharp
var rebindOp = action.PerformInteractiveRebinding()
    .WithControlsExcluding("Mouse")
    .OnMatchWaitForAnother(0.1f)
    .OnComplete(op =>
    {
        Debug.Log($"Rebound to: {op.action.bindings[0].effectivePath}");
        op.Dispose();
    })
    .Start();
```

### Multiple Bindings for Same Action (WASD + Arrows)

```csharp
var moveAction = new InputAction("Move", InputActionType.Value);
moveAction.AddCompositeBinding("2DVector")
    .With("Up", "<Keyboard>/w").With("Down", "<Keyboard>/s")
    .With("Left", "<Keyboard>/a").With("Right", "<Keyboard>/d");
moveAction.AddCompositeBinding("2DVector")
    .With("Up", "<Keyboard>/upArrow").With("Down", "<Keyboard>/downArrow")
    .With("Left", "<Keyboard>/leftArrow").With("Right", "<Keyboard>/rightArrow");
```

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|-------------|---------|-----------------|
| Using `Input.GetKey()` (legacy) | Not compatible with new Input System; no rebinding, no multi-device | Use `InputAction` with bindings |
| Reading actions without `.Enable()` | Actions start disabled and return no values | Always call `action.Enable()` in `OnEnable()` |
| Forgetting `.Disable()` on cleanup | Memory leaks and ghost callbacks | Call `action.Disable()` in `OnDisable()` |
| Modifying bindings while action is enabled | Throws exception | Call `.Disable()` before modifying, then `.Enable()` |
| Hardcoding device paths in gameplay code | Breaks cross-platform support | Use Actions + Control Schemes instead |
| Using `InputValue` outside its callback | Value is only valid during the callback frame | Copy the value to a field immediately |
| Accessing `Gamepad.current` without null check | Crashes if no gamepad connected | Always check `if (Gamepad.current == null) return;` |
| Not unsubscribing from action callbacks | Causes errors on scene reload | Unsubscribe in `OnDisable()` |
| Using `SendMessages` behavior in production | Performance overhead from reflection | Use `Invoke Unity Events` or `Invoke C# Events` |
| Polling `EnhancedTouch` without enabling it | Returns empty collections | Call `EnhancedTouchSupport.Enable()` first |

## Key API Quick Reference

| API | Purpose |
|-----|---------|
| `InputSystem.actions` | Project-wide actions |
| `InputSystem.actions.FindAction("name")` | Find action by name |
| `action.ReadValue<T>()` | Read current value |
| `action.IsPressed()` | Button held check |
| `action.WasPressedThisFrame()` | Button just pressed |
| `action.WasReleasedThisFrame()` | Button just released |
| `action.Enable()` / `action.Disable()` | Activate/deactivate |
| `action.started` / `performed` / `canceled` | Callback events |
| `action.AddBinding("path")` | Add binding in code |
| `action.AddCompositeBinding("type")` | Add composite (Dpad, 2DVector) |
| `.WithInteractions("tap(duration=0.5)")` | Add interaction to binding |
| `Gamepad.current` | Current gamepad reference |
| `Keyboard.current` / `Mouse.current` | Current keyboard/mouse |
| `Touchscreen.current` | Current touchscreen |
| `EnhancedTouchSupport.Enable()` | Enable enhanced touch API |
| `Touch.activeTouches` | All active touches (enhanced) |
| `InputSystem.onDeviceChange` | Device connection events |
| `PlayerInput.SwitchCurrentActionMap()` | Change active action map |
| `action.PerformInteractiveRebinding()` | Start runtime rebinding |

## Related Skills

- **unity-scripting** — MonoBehaviour lifecycle, C# patterns
- **unity-ui** — UI Toolkit input integration, `InputSystemUIInputModule`
- **unity-xr** — XR controller input, tracked devices

## Additional Resources

- [Input System Manual](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/index.html)
- [Quick Start Guide](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/QuickStartGuide.html)
- [Actions Reference](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Actions.html)
- [Action Assets](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/ActionAssets.html)
- [PlayerInput Component](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/PlayerInput.html)
- [Gamepad Support](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Gamepad.html)
- [Touch Support](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Touch.html)
- [Interactions](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.14/manual/Interactions.html)
- [Unity 6.3 Package Page](https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.inputsystem.html)
