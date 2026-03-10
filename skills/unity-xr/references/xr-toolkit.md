# XR Interaction Toolkit Reference

> Source: Unity XR Interaction Toolkit 3.3.1 Documentation
> https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.3/manual/index.html

## Package Dependencies

**Required:**
- Input System
- Mathematics
- Unity UI
- XR Core Utilities
- Built-in: Audio, IMGUI, Physics, XR modules

**Optional:**
- AR Foundation (for AR gesture interactions)
- Animation module

## Architecture

### Core Interaction Flow

```
Interactor --> Interaction Manager --> Interactable
   |                  |                    |
   |-- generates valid target list         |
   |                  |-- validates states  |
   |                  |-- exits invalid     |
   |                  |-- enters new states |
   |<-- notified first                     |
                                    notified second
```

### Interaction States

1. **Hover** -- Interactable is a valid target; no user input required
2. **Select** -- User triggers input (button/trigger); active grab/hold
3. **Focus** -- Persists after selection until another interactable is selected or explicit deselection
4. **Activate** -- Secondary contextual action on additional controls

### Lifecycle Callbacks (in order)

- `PreprocessInteractor`
- `ProcessInteractor`
- `ProcessInteractable`
- `ProcessInteractionStrength`
- State transitions: `OnSelectEntering` > `OnSelectEntered` > `OnSelectExiting` > `OnSelectExited`

## Interactor Types

### XR Direct Interactor

Close-range interaction via overlapping colliders. Best for grabbing objects within arm's reach.

### XR Ray Interactor

Distance interaction using a raycast. Supports line visuals (straight, projectile, bezier curves). Used with XR Interactor Line Visual for rendering.

### XR Poke Interactor

Touch/poke interaction for pressing buttons and UI elements. Best paired with XR Poke Filter.

**Known limitation:** Does not work with UI Toolkit elements.

### Near-Far Interactor

Hybrid interactor that combines direct and ray interaction based on proximity. Automatically switches modes.

### XR Gaze Interactor

Eye-gaze based interaction. Properties:
- `Allow Gaze Interaction` -- Enables gaze events on interactables
- `Allow Gaze Select` -- Permits selection via sustained gaze
- `Override Gaze Time To Select` -- Custom hover duration for selection
- `Override Time To Auto Deselect` -- Auto-deselect after duration
- `Allow Gaze Assistance` -- Snap volume for ray interactor snapping

### XR Socket Interactor

Snap-point interaction. Objects snap to a defined attachment point. Use `Attach Ease In Time >= 0.15` to avoid visual skipping.

### Climb Teleport Interactor

Enables climbing locomotion when selecting Climb Interactable objects.

### Interaction Attach Controller

Manages attachment point behavior between interactors and interactables.

## Interactable Types

### XR Grab Interactable

Full-featured grabbable object with physics integration.

**Movement Types:**

| Type | Update | Physics | Latency | Collisions |
|------|--------|---------|---------|------------|
| Instantaneous | Every frame (Transform) | None | Lowest | Can pass through |
| Kinematic | FixedUpdate (Rigidbody) | Synced | Moderate | Some penetration |
| Velocity Tracking | Velocity-based (Rigidbody) | Full | Potential lag | Prevented |

**Attachment System:**
- `Attach Transform` -- Defines grab point (uses object position if unset)
- `Use Dynamic Attach` -- Calculates attachment from interactor pose at grab time
- `Match Position/Rotation` -- Syncs grab point to interactor attachment
- `Secondary Attach Transform` -- Two-handed interaction support
- `Far Attach Mode` -- Controls whether objects stay distant or snap to hand

**Throw Configuration:**
- `Throw On Detach` -- Enables velocity inheritance on release
- `Throw Smoothing Duration` -- Averaging window (up to 20 frames)
- `Throw Smoothing Curve` -- Weights recent frames more heavily
- `Throw Velocity Scale` -- Linear velocity multiplier
- `Throw Angular Velocity Scale` -- Angular velocity multiplier
- `Force Gravity On Detach` -- Restores gravity after release

**Tracking Smoothing:**
- `Smooth Position/Rotation/Scale Amount` -- Interpolation intensity (larger = tighter)
- `Tighten Position/Rotation/Scale` -- Bias: 0 = no bias, 1 = no smoothing
- `Velocity Damping` -- Decay rate for existing velocity
- `Velocity Scale` -- Multiplier for tracked velocity

**Predicted Visuals Transform:**
Separates Rigidbody/colliders from visual representation for smooth rendering. Recommended hierarchy:

```
Grab Interactable (Rigidbody, XRGrabInteractable)
  ├── Visuals (MeshFilter, MeshRenderer)
  ├── Collider (BoxCollider)
  └── Visual Feedback
```

Constraints:
- Must be direct child of XR Grab Interactable
- Cannot contain colliders
- Cannot have intermediate parents with Transform offsets

**Distance Calculation Modes:**
- `Transform Position` -- Fastest, lowest accuracy
- `Collider Position` -- Moderate performance/accuracy
- `Collider Volume` -- Highest accuracy, highest cost

**Grab Transformers:**
- `IXRGrabTransformer` interface implementations
- `XRGeneralTransformer` -- Default; provides axis constraints, two-handed rotation and scaling
- Configure `Starting Single Grab Transformers` and `Starting Multiple Grab Transformers`

### XR Simple Interactable

Basic interactable for receiving interaction events without grab behavior. Use for buttons, triggers, and custom interactions.

### Climb Interactable

Defines a climbable surface. Pairs with the Climb Provider locomotion system.

### Teleportation Anchor

Fixed point teleport destination. Returns exact position and rotation.

### Teleportation Area

Area-based teleport target. Player can teleport anywhere within the defined area.

### Teleportation Multi-Anchor Volume

Volume containing multiple anchor points for teleportation.

## Locomotion System

### Provider Architecture

```
Locomotion Mediator
  ├── manages state: Idle -> Preparing -> Moving -> Ended
  ├── XR Body Transformer (queues transformations by priority)
  └── Providers register transformation requests
```

### Locomotion Providers

**Teleportation Provider:**
Works with Teleportation Anchor, Area, and Multi-Anchor Volume interactables.

**Snap Turn Provider:**
Rotates user by fixed angle increments (e.g., 30, 45, 90 degrees).

**Continuous Turn Provider:**
Smooth rotation mapped to thumbstick/touchpad input.

**Continuous Move Provider:**
Smooth translation mapped to thumbstick/touchpad. Supports head-relative and hand-relative movement directions.

**Grab Move Provider:**
Moves user counter to controller movement (pulling the world).

**Two-Handed Grab Move Provider:**
Dual-controller input for movement, rotation, and scaling.

**Climb Provider:**
Movement while selecting Climb Interactable surfaces.

**Gravity Provider:**
Applies gravitational effects with grounded state detection.

### Body Transformation Types

| Class | Purpose |
|-------|---------|
| `DelegateXRBodyTransformation` | Custom delegate-based transform |
| `XRBodyGroundPositioning` | Ground alignment |
| `XRBodyScale` | Body scaling |
| `XRBodyYawRotation` | Y-axis rotation |
| `XRCameraForwardXZAlignment` | Forward direction alignment |
| `XROriginMovement` | Origin translation |
| `XROriginUpAlignment` | Up vector alignment |

## Visual and Feedback Components

### Line Visuals

- **Curve Visual Controller** -- Controls curve rendering
- **XR Interactor Line Visual** -- Renders interaction ray
- **XR Interactor Reticle Visual** -- Endpoint indicator

### Haptic Feedback

- **Haptic Impulse Player** -- Direct haptic playback
- **Simple Haptic Feedback** -- Event-driven haptic response

### Audio Feedback

- **Simple Audio Feedback** -- Event-driven audio response

### Visual Feedback

- **XR Tint Interactable Visual** -- Color tinting on interaction states

## UI Components

### XR UI Input Module

Replaces standard Event System input for XR. Required for canvas interaction in VR/AR.

### Tracked Device Graphic Raycaster

Raycaster for Canvas UI elements. Add to Canvas alongside XR UI Input Module.

### Canvas Optimizer

Performance optimization for Canvas rendering in XR.

### Hand Menu

XR-specific hand-attached menu component.

### Lazy Follow

Smooth following behavior for floating UI elements.

## Input System

### Input Readers

Abstract input sources for Interactors and locomotion providers. Enable different input actions per component.

### Input Action Manager

Manages enabling/disabling Input Action assets.

### Input Modality Manager

Detects and switches between input modalities (controllers vs. hands).

### Tracked Pose Driver

Reads tracked device position/rotation from Input System. Apply to camera and controller GameObjects.

## Utility Components

### XR Interaction Manager

Single instance that coordinates all interactors and interactables. Registers components during `OnEnable`, unregisters during `OnDisable`.

### XR Interaction Group

Contains multiple Interactors sorted by priority. Only one Interactor in the Group can interact at a time. Supports nesting.

### XR Transform Stabilizer

Smooths tracked device jitter for more stable interactions.

### XR Interactable Snap Volume

Defines a volume that assists ray interactions in snapping to interactables.

### XR Device Simulator / XR Interaction Simulator

Editor tools for testing XR interactions without physical hardware.

## Filtering

### XR Poke Filter

Filters poke interactions based on approach direction and depth.

### XR Target Filter

Filters which interactables are valid targets for an interactor.

### Interactable Filters

Implement `IXRHoverFilter`, `IXRSelectFilter`, or `IXRInteractionStrengthFilter` for custom filtering logic.

## Known Limitations

1. Socket interactor visual skips -- Set Attach Ease In Time >= 0.15
2. Mouse/world-space UI incompatible with enabled XR Plug-in Providers
3. Poke Interactor does not work with UI Toolkit elements
4. Acceleration/AngularAcceleration always return zero on OpenXR input devices
5. Invalid stage space during OpenXR startup -- Use "Floor" Device Tracking Option as workaround

## Additional Resources

- [XRI Architecture](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.3/manual/architecture.html)
- [XRI Components](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.3/manual/components.html)
- [XRI Locomotion](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.3/manual/locomotion.html)
- [XR Grab Interactable](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.3/manual/xr-grab-interactable.html)
