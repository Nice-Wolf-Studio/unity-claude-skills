---
name: unity-cinemachine
description: >
  Unity 6 Cinemachine camera system guide. Use when working with virtual cameras,
  camera blending, follow cameras, FreeLook, camera shake, or state-driven cameras.
  Covers Cinemachine 3.x API. Based on Unity 6.3 LTS documentation.
---

# Unity Cinemachine (Camera System)

> Based on Unity 6.3 LTS -- Cinemachine 3.1 package
> IMPORTANT: Cinemachine 3.x renamed CinemachineVirtualCamera to CinemachineCamera

## Core Concepts

Cinemachine procedurally controls the Unity camera at runtime. Compose camera behaviors from reusable components instead of writing custom camera scripts.

### Architecture

1. **CinemachineBrain** -- On Main Camera; drives the Unity Camera from the highest-priority active CinemachineCamera
2. **CinemachineCamera** -- Lightweight virtual camera describing desired position, rotation, and lens (replaces CinemachineVirtualCamera from v2)
3. **Priority System** -- Highest-priority enabled CinemachineCamera wins
4. **Pipeline Stages** -- Body (position), Aim (rotation), Noise stages compute the final camera state

### Namespace

```csharp
using Unity.Cinemachine;  // Cinemachine 3.x (NOT "using Cinemachine;")
```

### Minimal Setup

1. Add `CinemachineBrain` to Main Camera
2. Create GameObject with `CinemachineCamera`
3. Set Follow target and optionally LookAt target
4. Add Body/Aim components as needed

```csharp
using UnityEngine;
using Unity.Cinemachine;

public class CameraSetup : MonoBehaviour
{
    [SerializeField] Transform playerTransform;

    void Start()
    {
        var vcam = gameObject.AddComponent<CinemachineCamera>();
        vcam.Follow = playerTransform;
        vcam.LookAt = playerTransform;
        vcam.Priority.Value = 10;
    }
}
```

## Camera Setup Patterns

### Basic Follow Camera

`CinemachineCamera` + `CinemachineFollow`. Set Follow target to player.

```csharp
// CinemachineFollow provides a simple offset-based follow
var follow = gameObject.AddComponent<CinemachineFollow>();
follow.FollowOffset = new Vector3(0f, 5f, -10f);
follow.Damping = new Vector3(1f, 1f, 1f);
```

### Third-Person Camera

`CinemachineThirdPersonFollow` for collision-aware third-person cameras.

| Property | Description |
|----------|-------------|
| `ShoulderOffset` | Offset from follow target in local space |
| `CameraDistance` | Distance from shoulder point |
| `CameraSide` | 0=left, 0.5=center, 1=right |
| `CameraRadius` | Collision detection radius |
| `DampingIntoCollision` | Damping when moving closer due to collision |
| `DampingFromCollision` | Damping when returning after collision |

### Orbital / FreeLook Camera

`CinemachineOrbitalFollow` for orbit-around-target cameras controlled by player input. In Cinemachine 3.x, FreeLook is no longer a separate component -- use `CinemachineCamera` + `CinemachineOrbitalFollow` + `CinemachineInputAxisController`.

```csharp
var orbital = gameObject.AddComponent<CinemachineOrbitalFollow>();
orbital.OrbitStyle = CinemachineOrbitalFollow.OrbitStyles.ThreeRing;
orbital.Radius = 5f;
// Add CinemachineInputAxisController to wire Input System actions
gameObject.AddComponent<CinemachineInputAxisController>();
```

### 2D Camera

`CinemachinePositionComposer` with dead zones and damping for smooth 2D tracking.

```csharp
var composer = gameObject.AddComponent<CinemachinePositionComposer>();
composer.Damping = new Vector3(1f, 0.5f, 0f);
composer.DeadZoneWidth = 0.1f;
composer.DeadZoneHeight = 0.1f;
composer.ScreenPosition = new Vector2(0.5f, 0.5f);
composer.CameraDistance = 10f;  // orthographic distance
```

## Body Components (Position Tracking)

Body components control how the camera position follows the target. Add one Body component per CinemachineCamera.

| Component | Use Case |
|-----------|----------|
| `CinemachineFollow` | Simple offset follow with damping |
| `CinemachineThirdPersonFollow` | Collision-aware third-person |
| `CinemachineOrbitalFollow` | Orbit around target (FreeLook style) |
| `CinemachinePositionComposer` | Screen-space framing with dead zones |
| `CinemachineHardLockToTarget` | Snap position exactly to target (no damping) |
| `CinemachineTrackedDolly` | Follow a SplineContainer path |

### CinemachineTrackedDolly

Moves the camera along a `SplineContainer` path. Useful for cutscene rails, racing games, or side-scrollers.

```csharp
var dolly = gameObject.AddComponent<CinemachineTrackedDolly>();
dolly.SplinePath = splineContainer;
dolly.AutoDolly.Enabled = true;      // auto-position along spline
dolly.CameraPosition = 0.5f;        // 0..1 position on spline
dolly.Damping = new Vector3(1f, 1f, 1f);
```

## Aim Components (Rotation)

Aim components control how the camera rotates toward its LookAt target. Add one Aim component per CinemachineCamera.

| Component | Use Case |
|-----------|----------|
| `CinemachineRotationComposer` | Soft-zone aim with dead zones and damping |
| `CinemachineHardLookAt` | Always face target exactly (no damping) |
| `CinemachinePanTilt` | Manual pan/tilt via input axes (first-person) |
| `CinemachineGroupFraming` | Auto-frame a CinemachineTargetGroup |

### CinemachinePanTilt

For first-person or manual-aim cameras:

```csharp
var panTilt = gameObject.AddComponent<CinemachinePanTilt>();
panTilt.TiltAxis.Range = new Vector2(-70f, 70f); // clamp vertical look
```

## Camera Blending

CinemachineBrain handles smooth transitions automatically.

### Blend Styles

| Style | Description |
|-------|-------------|
| `Cut` | Instant switch |
| `EaseInOut` | Smooth acceleration/deceleration (most common) |
| `EaseIn` / `EaseOut` | One-sided easing |
| `HardIn` / `HardOut` | Hard start or end |
| `Linear` | Constant speed |
| `Custom` | User-defined AnimationCurve |

### Switching Cameras

```csharp
// Priority-based: Brain blends to highest priority
closeUpCamera.Priority.Value = 20;
wideCamera.Priority.Value = 10;

// Or enable/disable GameObjects -- Brain blends automatically
closeUpCamera.gameObject.SetActive(true);
wideCamera.gameObject.SetActive(false);
```

Custom per-camera-pair blends use a `CinemachineBlenderSettings` asset assigned to `CinemachineBrain.CustomBlends`.

## State-Driven Cameras

`CinemachineStateDrivenCamera` maps Animator states to child CinemachineCameras. When the Animator transitions, the corresponding camera activates automatically.

### Setup

1. Create a parent GameObject with `CinemachineStateDrivenCamera`
2. Add child GameObjects, each with `CinemachineCamera`
3. Assign the Animator that drives the state transitions
4. Map each Animator state to a child camera in the Inspector

### Use Cases

- **Combat** -- Switch to over-shoulder cam when entering Combat Animator state
- **Vehicles** -- Different cameras for driving vs. reversing
- **Stealth** -- Wider FOV when in Crouch state
- **Dialogue** -- Close-up camera for conversation states

## Camera Shake (Impulse System)

| Component | Role |
|-----------|------|
| `CinemachineImpulseSource` | Generates impulse signal at a position |
| `CinemachineImpulseListener` | Receives impulse on a CinemachineCamera |

### Generating Impulse

```csharp
using UnityEngine;
using Unity.Cinemachine;

public class ExplosionShake : MonoBehaviour
{
    [SerializeField] CinemachineImpulseSource impulseSource;

    public void Explode()
    {
        impulseSource.GenerateImpulse();           // default velocity
        impulseSource.GenerateImpulse(3f);         // scaled intensity
        impulseSource.GenerateImpulse(Vector3.up); // directional
    }
}
```

### Listener Properties

| Property | Description |
|----------|-------------|
| `Gain` | Impulse multiplier (0=ignore, 1=full) |
| `Use2DDistance` | Use 2D distance for falloff |
| `ChannelMask` | Which impulse channels to receive |

## Noise (Procedural Shake)

`CinemachineBasicMultiChannelPerlin` adds continuous procedural noise (handheld feel, idle breathing).

| Profile | Use Case |
|---------|----------|
| `6D Shake` | Full positional + rotational |
| `Handheld_normal_mild` | Subtle handheld |
| `Handheld_normal_strong` | Pronounced handheld |

## CinemachineTargetGroup

Frame multiple targets with a single camera.

```csharp
var group = gameObject.AddComponent<CinemachineTargetGroup>();
group.Targets = new CinemachineTargetGroup.Target[]
{
    new() { Object = player.transform, Weight = 1f, Radius = 1f },
    new() { Object = enemy.transform, Weight = 0.5f, Radius = 1f }
};
// Add CinemachineGroupFraming to the camera for auto-framing
```

## Input Handling

Cinemachine 3.x uses `InputAxis` for camera control input. It integrates with Unity's Input System package.

### CinemachineInputAxisController

Add this component alongside `CinemachineOrbitalFollow` or `CinemachinePanTilt`. It auto-discovers axes on sibling components and connects Input System actions.

### Custom Input Provider

```csharp
using UnityEngine;
using Unity.Cinemachine;
using System.Collections.Generic;

public class CustomCameraInput : MonoBehaviour, IInputAxisOwner
{
    [SerializeField] InputAxis horizontalAxis;
    [SerializeField] InputAxis verticalAxis;

    public void GetInputAxes(List<IInputAxisOwner.AxisDescriptor> axes)
    {
        axes.Add(new IInputAxisOwner.AxisDescriptor
        {
            DrivenAxis = () => ref horizontalAxis,
            Name = "Horizontal"
        });
        axes.Add(new IInputAxisOwner.AxisDescriptor
        {
            DrivenAxis = () => ref verticalAxis,
            Name = "Vertical"
        });
    }
}
```

## Common Patterns

### Third-Person with Collision Avoidance

```csharp
var vcam = gameObject.AddComponent<CinemachineCamera>();
vcam.Follow = player; vcam.LookAt = player;

var tpFollow = gameObject.AddComponent<CinemachineThirdPersonFollow>();
tpFollow.ShoulderOffset = new Vector3(0.5f, 0f, 0f);
tpFollow.CameraDistance = 4f;
tpFollow.CameraSide = 1f;
tpFollow.CameraRadius = 0.2f;

var rotComposer = gameObject.AddComponent<CinemachineRotationComposer>();
rotComposer.Damping = new Vector2(0.5f, 0.5f);
```

### Switching Cameras on Trigger Zones

```csharp
using UnityEngine;
using Unity.Cinemachine;

public class CameraTriggerZone : MonoBehaviour
{
    [SerializeField] CinemachineCamera zoneCamera;
    [SerializeField] int activePriority = 20;
    [SerializeField] int inactivePriority = 0;

    void Start() => zoneCamera.Priority.Value = inactivePriority;

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
            zoneCamera.Priority.Value = activePriority;
    }

    void OnTriggerExit(Collider other)
    {
        if (other.CompareTag("Player"))
            zoneCamera.Priority.Value = inactivePriority;
    }
}
```

### Cutscene Camera Sequence

```csharp
using UnityEngine;
using Unity.Cinemachine;
using System.Collections;

public class CutsceneSequence : MonoBehaviour
{
    [SerializeField] CinemachineCamera[] cameras;
    [SerializeField] float[] durations;

    public IEnumerator PlayCutscene()
    {
        for (int i = 0; i < cameras.Length; i++)
        {
            foreach (var cam in cameras) cam.Priority.Value = 0;
            cameras[i].Priority.Value = 100;
            yield return new WaitForSeconds(durations[i]);
        }
    }
}
```

### Split-Screen Setup

```csharp
// Each player: separate Camera + CinemachineBrain + CinemachineCamera
// Camera 1: Viewport Rect (0, 0, 0.5, 1) -- left half
// Camera 2: Viewport Rect (0.5, 0, 0.5, 1) -- right half
brain1.ChannelMask = OutputChannels.Channel01;
brain2.ChannelMask = OutputChannels.Channel02;
player1Cam.OutputChannel = OutputChannels.Channel01;
player2Cam.OutputChannel = OutputChannels.Channel02;
```

### Camera Shake on Explosion

```csharp
[SerializeField] CinemachineImpulseSource impulseSource;
[SerializeField] float shakeForce = 5f;

public void Detonate()
{
    impulseSource.GenerateImpulse(shakeForce);
}
```

## Anti-Patterns

| Anti-Pattern | Do This Instead |
|-------------|-----------------|
| Using `CinemachineVirtualCamera` (v2) | `CinemachineCamera` |
| `using Cinemachine;` namespace | `using Unity.Cinemachine;` |
| Modifying `Camera.main.transform` directly | Modify the CinemachineCamera; Brain drives the Camera |
| All cameras at same priority | Give distinct priorities |
| No CinemachineBrain on Main Camera | Always add CinemachineBrain |
| Manual `Lerp` for camera transitions | Use priority switching; Brain handles blending |
| `CinemachineTransposer` (v2) | `CinemachineFollow` |
| `CinemachineComposer` (v2) | `CinemachineRotationComposer` |
| `CinemachineFramingTransposer` (v2) | `CinemachinePositionComposer` |

## Key API Quick Reference

| Class | Purpose |
|-------|---------|
| `CinemachineCamera` | Virtual camera (was CinemachineVirtualCamera) |
| `CinemachineBrain` | Drives Unity Camera from active virtual camera |
| `CinemachineFollow` | Offset body (was CinemachineTransposer) |
| `CinemachineThirdPersonFollow` | Collision-aware third-person body |
| `CinemachineOrbitalFollow` | Orbit body for FreeLook |
| `CinemachinePositionComposer` | Screen-space framing (was FramingTransposer) |
| `CinemachineTrackedDolly` | Follow a Spline path |
| `CinemachineRotationComposer` | Soft-zone aim (was CinemachineComposer) |
| `CinemachineHardLookAt` | Snap aim to target |
| `CinemachinePanTilt` | Manual pan/tilt aim |
| `CinemachineGroupFraming` | Auto-frame target group |
| `CinemachineImpulseSource` | Generate camera shake |
| `CinemachineImpulseListener` | Receive shake on camera |
| `CinemachineBasicMultiChannelPerlin` | Continuous procedural noise |
| `CinemachineStateDrivenCamera` | Map Animator states to cameras |
| `CinemachineTargetGroup` | Group multiple targets |
| `CinemachineBlenderSettings` | Custom blend definitions |
| `CinemachineInputAxisController` | Connect Input System to axes |
| `ICinemachineCamera` | Interface for virtual cameras |

## v2 to v3 Migration Reference

| Cinemachine 2.x | Cinemachine 3.x |
|-----------------|-----------------|
| `CinemachineVirtualCamera` | `CinemachineCamera` |
| `CinemachineFreeLook` | `CinemachineCamera` + `CinemachineOrbitalFollow` |
| `CinemachineTransposer` | `CinemachineFollow` |
| `CinemachineComposer` | `CinemachineRotationComposer` |
| `CinemachineFramingTransposer` | `CinemachinePositionComposer` |
| `CinemachinePOV` | `CinemachinePanTilt` |
| `CinemachineGroupComposer` | `CinemachineGroupFraming` |
| `using Cinemachine` | `using Unity.Cinemachine` |
| `m_Follow` / `m_LookAt` | `Follow` / `LookAt` |
| `m_Priority` | `Priority.Value` |

## Related Skills

- For animation state machines, see `unity-animation`
- For rendering/cameras, see `unity-graphics`
- For Timeline, see `unity-animation` references/timeline.md
- For input system integration, see `unity-input`

## Additional Resources

- See [references/cinemachine-api.md](references/cinemachine-api.md)
