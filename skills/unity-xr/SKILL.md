---
name: unity-xr
description: >
  Unity 6 XR development guide. Use when building VR, AR, or MR experiences. Covers XR Interaction Toolkit, XR Plug-in Management, OpenXR, hand tracking, controllers, haptics, AR Foundation (plane detection, anchors, image tracking), and platform-specific setup (Meta Quest, Apple Vision Pro). Based on Unity 6.3 LTS documentation.
---

# Unity 6 XR Development Guide

> Source: Unity 6.3 LTS Documentation (6000.3)

## XR Architecture Overview

Unity defines XR as encompassing three application types:

- **Virtual Reality (VR)** -- The application simulates a self-contained environment around the user
- **Mixed Reality (MR)** -- Combines virtual environments with real-world settings for interaction
- **Augmented Reality (AR)** -- The application layers content over a view of the real world

The XR stack in Unity 6 consists of:

1. **XR Plug-in Management** -- Discovers and loads platform XR SDKs
2. **OpenXR Plugin** -- Open, royalty-free standard by Khronos for cross-platform XR
3. **XR Interaction Toolkit (XRI)** -- High-level component-based interaction system
4. **AR Foundation** -- Cross-platform AR framework with provider plug-in architecture
5. **Input System** -- Action-based input required by OpenXR and XRI

## XR Plug-in Management

Configure via **Edit > Project Settings > XR Plug-in Management**.

- Enable **OpenXR** and desired Feature Groups per platform
- Select **Interaction Profiles** (controller mappings) in the OpenXR > Features tab
- Run **Project Validation** for build-time compatibility checks
- Verify the active runtime matches target hardware

### Supported Runtimes and Platforms

| Runtime | Target | Graphics |
|---------|--------|----------|
| Windows Mixed Reality | Win64 | DX11 |
| Oculus PC + Link | Win64 | DX11 |
| Meta Quest | Android arm64 | Vulkan |
| Magic Leap 2 | Android x64 | Vulkan |
| SteamVR | Win64 | DX11 |

### OpenXR Interaction Profiles

- Eye Gaze Interaction
- HTC Vive Controller
- Khronos Simple Controller
- Microsoft Motion Controller
- Oculus Touch Controller
- Valve Index Controller

### OpenXR Scripting API

```csharp
// Iterate all OpenXR features
var features = OpenXRSettings.Instance.GetFeatures();
foreach (var feature in features)
{
    Debug.Log($"Feature: {feature.name}, Enabled: {feature.enabled}");
}

// Get a specific feature by type
var feature = OpenXRSettings.Instance.GetFeature<MockRuntime>();
if (feature != null)
{
    Debug.Log($"MockRuntime Enabled: {feature.enabled}");
}

// Iterate feature groups (Editor only)
var featureSets = OpenXRFeatureSetManager.FeatureSetsForBuildTarget(
    BuildTargetGroup.Standalone
);
foreach (var featureSet in featureSets)
{
    Debug.Log($"Feature Set ID: {featureSet.featureSetId}");
}
```

## XR Interaction Toolkit

**Package:** `com.unity.xr.interaction.toolkit` (v3.3.1 for Unity 6000.3)

A high-level, component-based interaction system for VR and AR. Three foundational elements:

1. **Interactors** -- Handle user input and initiate interactions
2. **Interactables** -- Define objects users can interact with
3. **Interaction Manager** -- Coordinates between interactors and interactables

### Interaction States

| State | Description |
|-------|-------------|
| **Hover** | Interactable is a valid target; indicates intention |
| **Select** | User input (button/trigger) triggers active interaction (grab) |
| **Focus** | Persists after selection until another interactable is selected |
| **Activate** | Secondary contextual action mapped to additional controls |

### Update Loop

1. Request valid target lists from Interactors
2. Validate existing hover/focus/selection states
3. Exit invalid states (`OnSelectExiting`, `OnHoverExiting`, `OnFocusExiting`)
4. Enter new states (`OnSelectEntering`, `OnHoverEntering`, `OnFocusEntering`)

Interactors are always notified before Interactables for both processing and state changes.

### Interactor Types

| Component | Purpose |
|-----------|---------|
| XR Direct Interactor | Close-range (touch/grab) interaction |
| XR Ray Interactor | Ray-based distance interaction |
| XR Poke Interactor | Poking/touching interaction |
| Near-Far Interactor | Hybrid proximity/distance |
| XR Gaze Interactor | Eye-gaze based interaction |
| XR Socket Interactor | Snap-point interaction |
| Climb Teleport Interactor | Climbing locomotion |

### Interactable Types

| Component | Purpose |
|-----------|---------|
| XR Grab Interactable | Object grabbing and manipulation |
| XR Simple Interactable | Basic interaction events |
| Climb Interactable | Climbable surfaces |
| Teleportation Anchor | Fixed teleport destination |
| Teleportation Area | Area-based teleport target |
| Teleportation Multi-Anchor Volume | Volume with multiple anchors |

### XR Grab Interactable Movement Types

- **Instantaneous** -- Sets Transform position/rotation every frame; lowest latency but can pass through colliders
- **Kinematic** -- Updates kinematic Rigidbody during FixedUpdate; syncs physics with visuals
- **Velocity Tracking** -- Sets Rigidbody velocity/angular velocity; prevents collision penetration but may lag

### Interaction Strength

Interactors and Interactables report a normalized `[0.0, 1.0]` analog selection strength, processed after state changes.

### Interaction Groups

A Group contains multiple member Interactors sorted by priority and only allows one Interactor in the Group to interact at a time. Supports nested Groups.

See `skills/unity-xr/references/xr-toolkit.md` for full API details.

## Locomotion System

### Locomotion Providers

| Provider | Description |
|----------|-------------|
| Teleportation Provider | Point-and-teleport movement |
| Snap Turn Provider | Rotates user by fixed angles |
| Continuous Turn Provider | Smooth rotation over time |
| Continuous Move Provider | Smooth movement over time |
| Grab Move Provider | Moves user counter to controller movement |
| Two-Handed Grab Move Provider | Dual-controller movement, rotation, scaling |
| Climb Provider | Movement while selecting Climb Interactables |
| Gravity Provider | Gravitational effects with grounded state detection |

### Architecture

- **Locomotion Mediator** -- Manages transformation requests; states: Idle, Preparing, Moving, Ended
- **XR Body Transformer** -- Queues transformations applied each Update based on priority
- **XR Movable Body** -- Wraps XR Origin with body-relative transformation

Transformations are applied sequentially based on ascending priority; same-priority transformations apply in queue order.

## AR Foundation

**Package:** `com.unity.xr.arfoundation` (v6.3.3 for Unity 6000.3)

AR Foundation uses a two-package architecture:

- **Base Package** -- Provides AR feature interfaces (non-functional alone)
- **Provider Plug-ins** -- Platform-specific implementations

### Supported Platforms

| Platform | Provider Plug-in |
|----------|-----------------|
| Android | Google ARCore XR Plug-in |
| iOS | Apple ARKit XR Plug-in |
| visionOS | Apple visionOS XR Plug-in |
| HoloLens 2 | OpenXR Plug-in |
| Meta Quest | Unity OpenXR: Meta |
| Android XR | Unity OpenXR: Android XR |

### Feature Subsystems

| Feature | Manager Component |
|---------|-------------------|
| Session Management | ARSession |
| Device Tracking | ARTrackedPoseDriver |
| Camera | ARCameraManager |
| Plane Detection | ARPlaneManager |
| Image Tracking | ARTrackedImageManager |
| Face Tracking | ARFaceManager |
| Body Tracking | ARHumanBodyManager |
| Object Tracking | ARTrackedObjectManager |
| Point Clouds | ARPointCloudManager |
| Ray Casting | ARRaycastManager |
| Anchors | ARAnchorManager |
| Meshing | ARMeshManager |
| Environment Probes | AREnvironmentProbeManager |
| Occlusion | AROcclusionManager |
| Bounding Box Detection | ARBoundingBoxManager |
| Participants | ARParticipantManager |

### AR Gesture Interaction (XRI)

- **TouchscreenGestureInputController** -- Maps screen touches to gesture events
- **ARTransformer** -- Handles place, select, translate, rotate, and scale gestures
- Screen Space input components feed into XRRayInteractor

## Hand Tracking

Hand-tracking devices expose the `HandTracking` characteristic and `CommonUsages.HandData` feature:

```csharp
Hand handData;
if (device.TryGetFeatureValue(CommonUsages.handData, out handData))
{
    // Get wrist bone
    Bone rootBone;
    if (handData.TryGetRootBone(out rootBone))
    {
        Vector3 wristPosition;
        rootBone.TryGetPosition(out wristPosition);
    }

    // Get finger bones (up to 21 bones per hand)
    List<Bone> fingerBones = new List<Bone>();
    if (handData.TryGetFingerBones(HandFinger.Index, fingerBones))
    {
        foreach (Bone bone in fingerBones)
        {
            Vector3 bonePosition;
            bone.TryGetPosition(out bonePosition);
        }
    }
}
```

Each Bone contains: position, orientation, parent/child references.

## Controllers and Haptics

### Input Device Access

```csharp
using UnityEngine.XR;

// Get devices by role
var devices = new List<InputDevice>();
InputDevices.GetDevicesWithRole(InputDeviceRole.RightHanded, devices);

if (devices.Count > 0)
{
    var device = devices[0];

    // Read trigger button
    bool triggerPressed;
    if (device.TryGetFeatureValue(CommonUsages.triggerButton,
        out triggerPressed) && triggerPressed)
    {
        // Handle trigger press
    }

    // Read joystick axis
    Vector2 axis;
    if (device.TryGetFeatureValue(CommonUsages.primary2DAxis, out axis))
    {
        // Use axis.x, axis.y
    }
}
```

### Common Input Usages

| Usage | Type | Description |
|-------|------|-------------|
| `primary2DAxis` | Vector2 | Thumbstick/touchpad |
| `trigger` | float | Trigger axis (0-1) |
| `grip` | float | Grip axis (0-1) |
| `triggerButton` | bool | Trigger pressed |
| `gripButton` | bool | Grip pressed |
| `primaryButton` | bool | A/X button |
| `secondaryButton` | bool | B/Y button |
| `menuButton` | bool | Menu button |
| `userPresence` | bool | User wearing headset |

### Haptics

```csharp
HapticCapabilities capabilities;
if (device.TryGetHapticCapabilities(out capabilities))
{
    if (capabilities.supportsImpulse)
    {
        uint channel = 0;
        float amplitude = 0.5f;  // 0-1
        float duration = 1.0f;   // seconds
        device.SendHapticImpulse(channel, amplitude, duration);
    }
}
```

### Eye Tracking

```csharp
Eyes eyeData;
if (device.TryGetFeatureValue(CommonUsages.eyesData, out eyeData))
{
    // Access left/right eye positions, gaze direction, blink amounts
}
```

### Device Lifecycle

```csharp
// Subscribe to connection events
InputDevices.deviceConnected += OnDeviceConnected;
InputDevices.deviceDisconnected += OnDeviceDisconnected;

// Always validate before use
if (device.isValid)
{
    // Safe to read features
}
```

### Tracking Origin

```csharp
var subsystems = new List<XRInputSubsystem>();
SubsystemManager.GetInstances<XRInputSubsystem>(subsystems);
if (subsystems.Count > 0)
{
    subsystems[0].TrySetTrackingOriginMode(TrackingOriginModeFlags.Floor);

    // Get play area boundary
    List<Vector3> boundaryPoints = new List<Vector3>();
    if (subsystems[0].TryGetBoundaryPoints(boundaryPoints))
    {
        // Points are floor-level, clockwise-ordered
    }
}
```

## Common Patterns

### Basic XR Rig Setup

1. Add **XR Origin** to scene (provides camera offset and body tracking)
2. Add **XR Interaction Manager** (single instance coordinates all interactions)
3. Add **Tracked Pose Driver** to camera and controllers
4. Add **Interactors** to controller GameObjects
5. Add **Interactables** to interactive objects

### Grab Object Pattern

```csharp
// On the grabbable object:
// 1. Add Rigidbody
// 2. Add Collider
// 3. Add XR Grab Interactable component
// Configure Movement Type based on needs:
//   - Instantaneous: lowest latency, no physics
//   - Kinematic: physics-synced, moderate latency
//   - Velocity Tracking: full physics, potential lag
```

### Recommended Grab Hierarchy

```
Grab Interactable (Rigidbody, XRGrabInteractable)
  ├── Visuals (MeshFilter, MeshRenderer)
  ├── Collider (BoxCollider, MeshCollider)
  └── Visual Feedback (Affordance providers)
```

### XR Interaction Simulator

Use the XR Interaction Simulator component to test interactions in the Editor without physical hardware.

## Anti-Patterns

- **Single Interaction Manager missing** -- All Interactors and Interactables require a shared Interaction Manager. Forgetting it causes silent failures.
- **Using legacy Input Manager with OpenXR** -- OpenXR requires the new Input System package. Legacy `Input.GetAxis()` will not work.
- **Skipping device validation** -- Always check `InputDevice.isValid` before reading features; devices can disconnect at any time.
- **Ignoring Attach Ease In Time on sockets** -- Socket interactor visual skips occur; set Attach Ease In Time to at least 0.15 to mitigate.
- **Mouse/World-space UI with XR providers** -- Enabling XR Plug-in Providers breaks standard mouse and world-space UI. Use XR UI Input Module instead.
- **Not checking compute shader support** -- On platforms without compute shaders, GPU-based features may fail silently. Check `SystemInfo.supportsComputeShaders`.
- **Teleportation without vignette** -- Instant teleportation without a Tunneling Vignette Controller causes motion sickness.
- **Poke Interactor with UI Toolkit** -- Known limitation; use Canvas-based UI with Tracked Device Graphic Raycaster instead.

## Key API Quick Reference

| Class | Namespace | Purpose |
|-------|-----------|---------|
| `XROrigin` | Unity.XR.CoreUtils | Camera rig and tracking space |
| `XRInteractionManager` | UnityEngine.XR.Interaction.Toolkit | Coordinates interactions |
| `XRBaseInteractor` | UnityEngine.XR.Interaction.Toolkit | Base interactor class |
| `XRBaseInteractable` | UnityEngine.XR.Interaction.Toolkit | Base interactable class |
| `XRGrabInteractable` | UnityEngine.XR.Interaction.Toolkit | Grabbable object |
| `InputDevice` | UnityEngine.XR | Physical XR device |
| `InputDevices` | UnityEngine.XR | Device discovery |
| `CommonUsages` | UnityEngine.XR | Standard input feature names |
| `OpenXRSettings` | UnityEngine.XR.OpenXR | OpenXR configuration |
| `ARSession` | UnityEngine.XR.ARFoundation | AR session management |
| `ARPlaneManager` | UnityEngine.XR.ARFoundation | Plane detection |
| `ARAnchorManager` | UnityEngine.XR.ARFoundation | Spatial anchors |

## Related Skills

- `unity-input` -- Input System package, action maps, bindings
- `unity-graphics` -- Rendering pipelines, shader considerations for XR

## Additional Resources

- [XR Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/XR.html)
- [XR Interaction Toolkit](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.3/manual/index.html)
- [XR Input](https://docs.unity3d.com/6000.3/Documentation/Manual/xr_input.html)
- [OpenXR Plugin](https://docs.unity3d.com/Packages/com.unity.xr.openxr@1.16/manual/index.html)
- [AR Foundation](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@6.3/manual/index.html)
- [XR Interaction Toolkit Package](https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.xr.interaction.toolkit.html)
- [AR Foundation Package](https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.xr.arfoundation.html)
