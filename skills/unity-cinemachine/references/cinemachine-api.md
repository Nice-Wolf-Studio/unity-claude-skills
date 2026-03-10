# Cinemachine 3.x API Reference

Detailed API reference for Unity Cinemachine 3.1 (Unity 6.3 LTS). All classes in `Unity.Cinemachine` namespace.

---

## CinemachineCamera

Core virtual camera component. Replaces `CinemachineVirtualCamera` from v2.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `Follow` | Transform | Position tracking target |
| `LookAt` | Transform | Aim tracking target |
| `Priority` | PrioritySettings | Camera priority (highest wins) |
| `Lens` | LensSettings | FOV, near/far clip, ortho size, dutch |
| `OutputChannel` | OutputChannels | Which Brain channel to output to |
| `BlendHint` | BlendHints | Hints for blending to/from this camera |
| `State` | CameraState | Read-only computed state this frame |

### Methods

```csharp
CameraState state = cinemachineCamera.State;
Vector3 pos = state.RawPosition;
Quaternion rot = state.RawOrientation;

// Snap to position (skip damping)
cinemachineCamera.ForceCameraPosition(newPosition, newRotation);

// Lens modification
cinemachineCamera.Lens.FieldOfView = 60f;
cinemachineCamera.Lens.NearClipPlane = 0.1f;
cinemachineCamera.Lens.FarClipPlane = 1000f;
cinemachineCamera.Lens.OrthographicSize = 5f;
cinemachineCamera.Lens.Dutch = 0f;
```

---

## CinemachineBrain

Drives the Unity Camera from the highest-priority active CinemachineCamera.

| Property | Type | Description |
|----------|------|-------------|
| `DefaultBlend` | CinemachineBlendDefinition | Default blend style/duration |
| `CustomBlends` | CinemachineBlenderSettings | Per-camera-pair overrides |
| `UpdateMethod` | UpdateMethods | FixedUpdate, LateUpdate, SmartUpdate |
| `ChannelMask` | OutputChannels | Which camera channels to listen to |
| `IsBlending` | bool | Whether a blend is in progress |
| `ActiveVirtualCamera` | ICinemachineCamera | Currently active camera |

```csharp
CinemachineBrain brain = Camera.main.GetComponent<CinemachineBrain>();
CinemachineBlend blend = brain.ActiveBlend;
if (blend != null)
    Debug.Log($"Blend: {blend.TimeInBlend / blend.Duration:P0}");
```

---

## Body Component Properties

### CinemachineFollow

| Property | Type | Description |
|----------|------|-------------|
| `FollowOffset` | Vector3 | Offset in target-local space |
| `Damping` | Vector3 | Per-axis position damping |

### CinemachineThirdPersonFollow

| Property | Type | Description |
|----------|------|-------------|
| `ShoulderOffset` | Vector3 | Shoulder position offset |
| `VerticalArmLength` | float | Vertical arm length |
| `CameraDistance` | float | Distance from shoulder |
| `CameraSide` | float | 0=left, 0.5=center, 1=right |
| `CameraRadius` | float | Obstacle avoidance radius |
| `CameraCollisionFilter` | LayerMask | Collision layers |
| `AvoidObstacles` | bool | Enable obstacle avoidance |
| `DampingIntoCollision` | float | Damping moving closer |
| `DampingFromCollision` | float | Damping moving back |

### CinemachineOrbitalFollow

| Property | Type | Description |
|----------|------|-------------|
| `OrbitStyle` | OrbitStyles | Sphere or ThreeRing |
| `Radius` | float | Orbit radius (Sphere mode) |
| `Orbits` | OrbitDef | Three-ring orbit definitions |
| `HorizontalAxis` | InputAxis | Horizontal orbit input |
| `VerticalAxis` | InputAxis | Vertical orbit input |

### CinemachinePositionComposer

| Property | Type | Description |
|----------|------|-------------|
| `Damping` | Vector3 | Position damping |
| `ScreenPosition` | Vector2 | Target screen position |
| `DeadZoneWidth/Height` | float | No-move zone (0-1) |
| `SoftZoneWidth/Height` | float | Soft tracking zone |
| `CameraDistance` | float | Distance from target |
| `LookaheadTime` | float | Lookahead seconds |

### CinemachineTrackedDolly

| Property | Type | Description |
|----------|------|-------------|
| `SplinePath` | SplineContainer | Spline to follow |
| `CameraPosition` | float | Position on spline (0-1) |
| `Damping` | Vector3 | Position damping |
| `AutoDolly` | AutoDollySetting | Auto-position settings |

---

## Aim Component Properties

### CinemachineRotationComposer

| Property | Type | Description |
|----------|------|-------------|
| `Damping` | Vector2 | H/V aim damping |
| `ScreenPosition` | Vector2 | Target screen position |
| `DeadZoneWidth/Height` | float | Dead zone |
| `SoftZoneWidth/Height` | float | Soft zone |
| `LookaheadTime` | float | Prediction lookahead |

### CinemachinePanTilt

| Property | Type | Description |
|----------|------|-------------|
| `PanAxis` | InputAxis | Horizontal rotation |
| `TiltAxis` | InputAxis | Vertical rotation |
| `ReferenceFrame` | ReferenceFrames | Parent, World, or FollowTarget |

### CinemachineGroupFraming

| Property | Type | Description |
|----------|------|-------------|
| `FramingMode` | FramingModes | Horizontal, Vertical, or Both |
| `FramingSize` | float | Screen fill fraction |
| `Damping` | float | Adjustment damping |
| `AdjustmentMode` | SizeAdjustmentModes | DollyOnly, ZoomOnly, DollyThenZoom |

---

## CinemachineImpulseSource

### GenerateImpulse Overloads

```csharp
impulseSource.GenerateImpulse();                            // default shake
impulseSource.GenerateImpulse(3f);                          // 3x intensity
impulseSource.GenerateImpulse(Vector3.up * 2f);             // directional
impulseSource.GenerateImpulse(collision.relativeVelocity);  // physics-based
```

### ImpulseDefinition Configuration

```csharp
var def = impulseSource.ImpulseDefinition;
def.ImpulseChannel = 1;
def.ImpulseShape = ImpulseShapes.Bump;
def.ImpulseDuration = 0.3f;
def.DissipationRate = 0.25f;
def.DissipationDistance = 100f;
```

---

## CinemachineTargetGroup

### Managing Targets at Runtime

```csharp
var group = GetComponent<CinemachineTargetGroup>();

// Add target
var targets = new List<CinemachineTargetGroup.Target>(group.Targets);
targets.Add(new CinemachineTargetGroup.Target
{
    Object = newEnemy.transform, Weight = 1f, Radius = 1f
});
group.Targets = targets.ToArray();

// Remove target
targets.RemoveAll(t => t.Object == deadEnemy.transform);
group.Targets = targets.ToArray();
```

---

## CinemachineBlenderSettings

Custom blend rules between camera pairs.

```csharp
var settings = ScriptableObject.CreateInstance<CinemachineBlenderSettings>();
settings.CustomBlends = new CinemachineBlenderSettings.CustomBlend[]
{
    new()
    {
        From = "WideCamera", To = "CloseUpCamera",
        Blend = new CinemachineBlendDefinition(
            CinemachineBlendDefinition.Styles.EaseInOut, 1.5f)
    },
    new()
    {
        From = "*", To = "CutsceneCam",  // wildcard
        Blend = new CinemachineBlendDefinition(
            CinemachineBlendDefinition.Styles.Cut, 0f)
    }
};
brain.CustomBlends = settings;
```

---

## InputAxis and Input Handling

| Property | Type | Description |
|----------|------|-------------|
| `Value` | float | Current axis value |
| `Center` | float | Rest/recentering value |
| `Range` | Vector2 | Min/max range |
| `Wrap` | bool | Wrap around at limits |
| `Recentering` | Recentering | Auto-recentering settings |

`CinemachineInputAxisController` bridges Input System actions to camera axes. Add it alongside `CinemachineOrbitalFollow` or `CinemachinePanTilt`; it auto-discovers axes.

---

## Custom Extensions

Inherit `CinemachineExtension` to create custom pipeline stages.

```csharp
using UnityEngine;
using Unity.Cinemachine;

public class CinemachineCustomZoom : CinemachineExtension
{
    [SerializeField] float minFOV = 20f;
    [SerializeField] float maxFOV = 80f;
    [SerializeField] float zoomSpeed = 10f;
    float currentZoom;

    protected override void PostPipelineStageCallback(
        CinemachineVirtualCameraBase vcam,
        CinemachineCore.Stage stage,
        ref CameraState state, float deltaTime)
    {
        if (stage == CinemachineCore.Stage.Aim)
        {
            currentZoom = Mathf.Clamp(
                currentZoom - Input.mouseScrollDelta.y * zoomSpeed * deltaTime,
                minFOV, maxFOV);
            state.Lens.FieldOfView = currentZoom;
        }
    }
}
```

### Pipeline Stages

| Stage | When | Use Case |
|-------|------|----------|
| `Body` | After position calc | Modify position |
| `Aim` | After rotation calc | Modify rotation/lens |
| `Noise` | After noise applied | Post-noise adjustments |
| `Finalize` | Final stage | Last-chance modifications |

---

## Timeline Integration

Cinemachine integrates with Timeline via `CinemachineTrack` and `CinemachineShot` clips.

```csharp
// 1. Add CinemachineTrack to Timeline
// 2. Bind CinemachineBrain to the track
// 3. Add CinemachineShot clips referencing CinemachineCameras
// 4. Overlapping clips create automatic blends
var director = GetComponent<PlayableDirector>();
director.Play();
```
