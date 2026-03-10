# Animation Clips Reference

> Based on Unity 6.3 LTS documentation

## Overview

Animation Clips are the core unit of Unity's animation system -- each clip represents a single piece of motion such as Idle, Walk, or Run. Clips can be imported from external sources or created natively in Unity.

**Source:** [Animation Clips](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationClips.html)

## Import Sources

- **Motion capture studios** -- Humanoid animation data
- **3D applications** -- 3ds Max, Maya, Blender
- **Asset Store** -- Pre-built animation sets
- **Single files** -- Multiple clips can be extracted from a single motion file

## Creating Clips in Unity

The Animation Window enables animating:

| Property Type | Examples |
|--------------|----------|
| **Transform** | Position, rotation, scale of GameObjects |
| **Component** | Material colors, light intensity, sound volume |
| **Script variables** | Floats, integers, enums, vectors, booleans |
| **Function timing** | Scheduling function calls at specific keyframes |

### Animation Window Workflow

1. Select a GameObject
2. Open Window > Animation > Animation
3. Click Create to make a new clip (creates both clip and controller if needed)
4. Add properties via Add Property button
5. Set keyframes at desired times
6. Preview with the playback controls

## Import Settings

### Rig Tab

Controls how the model's skeleton is interpreted:

| Animation Type | Use Case |
|---------------|----------|
| **None** | No animation support |
| **Legacy** | Older Animation component system |
| **Generic** | Non-humanoid rigs (animals, props, mechanical) |
| **Humanoid** | Bipedal characters with Avatar mapping |

### Animation Tab

Configure imported animation clips:

| Setting | Description |
|---------|-------------|
| **Import Animation** | Enable/disable animation import |
| **Anim. Compression** | Off, Keyframe Reduction, Optimal |
| **Rotation Error** | Compression tolerance for rotation curves |
| **Position Error** | Compression tolerance for position curves |
| **Scale Error** | Compression tolerance for scale curves |

### Clip Range

When a source file contains multiple animations, define clip ranges:
- **Start/End** frame numbers
- **Loop Time** -- whether the clip loops
- **Loop Pose** -- smooth loop point blending
- **Cycle Offset** -- offset the loop start point

## Animation Curves

Curves define how properties change over time within a clip.

### Curve Types

- **Transform curves** -- Position, rotation, scale keyframes
- **Property curves** -- Any animatable component property
- **Animation curves (custom)** -- Float parameters accessible from scripts

### Curve Editor

- Add keyframes by right-clicking on the timeline
- Adjust tangent modes: Auto, Free, Linear, Constant
- Copy/paste keyframes between properties

### Accessing Curves from Script

Animation clips can define custom float curves that map to Animator parameters:

```csharp
// If an animation clip has a curve named "AttackPower",
// it writes to the Animator parameter of the same name each frame.
void Update()
{
    // Read the curve-driven parameter
    float attackPower = animator.GetFloat("AttackPower");
    // Use it for gameplay logic
    damageMultiplier = attackPower;
}
```

## Animation Events

Events trigger functions at designated points in the animation timeline.

**Source:** [Animation Events on Imported Clips](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationEventsOnImportedClips.html)

### Setup on Imported Clips

1. Select the model asset in the Project window
2. Open the Animation tab in the Inspector
3. Expand the **Events** section
4. Position the playback head on the desired frame
5. Click **Add Event**
6. Set the **Function** property to match a method on an attached script

### Event Parameter Types

| Type | Use Case |
|------|----------|
| **Float** | Volume levels, speed multipliers |
| **Int** | Index values, state IDs |
| **String** | Sound names, effect identifiers |
| **Object** | Prefab references for spawning |

### Event Handler Script

The target GameObject must have an attached script containing a function with the same name as specified in the event:

```csharp
using UnityEngine;

public class AnimationEventHandler : MonoBehaviour
{
    public AudioClip[] footstepSounds;
    public AudioClip attackWhoosh;

    AudioSource audioSource;

    void Start()
    {
        audioSource = GetComponent<AudioSource>();
    }

    // Called by animation event -- no parameters
    public void PlayAttackSound()
    {
        audioSource.PlayOneShot(attackWhoosh);
    }

    // Called by animation event with Float parameter
    public void PlayFootstep(float volume)
    {
        if (footstepSounds.Length > 0)
        {
            int index = Random.Range(0, footstepSounds.Length);
            audioSource.PlayOneShot(footstepSounds[index], volume);
        }
    }

    // Called by animation event with Int parameter
    public void SetWeaponTrail(int active)
    {
        // Enable/disable weapon trail effect
        GetComponentInChildren<TrailRenderer>().emitting = active == 1;
    }

    // Called by animation event with String parameter
    public void SpawnNamedEffect(string effectName)
    {
        // Look up and spawn effect by name
        GameObject prefab = Resources.Load<GameObject>("Effects/" + effectName);
        if (prefab != null)
        {
            Instantiate(prefab, transform.position, transform.rotation);
        }
    }

    // Called by animation event with Object parameter
    public void SpawnEffect(Object effectPrefab)
    {
        if (effectPrefab != null)
        {
            Instantiate((GameObject)effectPrefab, transform.position, Quaternion.identity);
        }
    }
}
```

### Events on Unity-Created Clips

For clips created in the Animation Window:
1. Open the Animation Window
2. Select the clip
3. Right-click the timeline at the desired frame
4. Select Add Animation Event
5. Configure the event in the Inspector

## Root Motion Settings

Root motion settings on imported clips control how animation-driven movement transfers to the GameObject.

### Root Transform Rotation

| Setting | Description |
|---------|-------------|
| **Bake Into Pose** | Orientation stays on body; GameObject gets no rotation |
| **Based Upon** | Body Orientation (mocap) or Original (keyframed) |
| **Offset** | Manual rotation adjustment |

### Root Transform Position (Y)

| Setting | Description |
|---------|-------------|
| **Bake Into Pose** | Y motion stays on body; enable for all except jump clips |
| **Based Upon** | Original, Mass Center (Body), or Feet (prevents floating) |
| **Offset** | Manual height adjustment |

`Animator.gravityWeight` is driven by this setting: enabled = 1, disabled = 0.

### Root Transform Position (XZ)

| Setting | Description |
|---------|-------------|
| **Bake Into Pose** | XZ motion stays on body; enable for idle clips to prevent drift |
| **Based Upon** | Original or Mass Center |
| **Offset** | Manual position adjustment |

### Loop Settings

| Setting | Description |
|---------|-------------|
| **Loop Time** | Clip plays continuously |
| **Loop Pose** | Blends start/end poses for seamless looping |
| **Cycle Offset** | Offsets the loop start point (normalized 0-1) |

A green light indicator means the loop is clean; yellow/red indicates a mismatch between start and end poses.

## Blend Trees and Clips

Clips used in Blend Trees must be of similar nature and timing. Foot contact points should align in normalized time:
- Left foot contact: 0.0
- Right foot contact: 0.5

This allows clips of different lengths to blend properly because Blend Trees operate on normalized time.

## Compression

### Compression Options

| Mode | Description |
|------|-------------|
| **Off** | No compression; highest quality, largest size |
| **Keyframe Reduction** | Removes redundant keyframes based on error tolerance |
| **Optimal** | Unity chooses best compression per curve |

### Error Tolerances

Lower values = higher quality, larger file size:
- **Rotation Error** -- Degrees of acceptable rotation deviation
- **Position Error** -- Percentage of acceptable position deviation
- **Scale Error** -- Percentage of acceptable scale deviation

## Clip Information (Read-Only)

The Inspector displays for imported clips:
- **Length** -- Duration in seconds
- **Frame count** -- Total frames
- **Frame rate** -- Frames per second (typically 24, 30, or 60)
- **Samples** -- Keyframe sample count

## Common Patterns

### Multiple Clips from One File

When a 3D artist provides a single FBX with multiple animations:

1. Select the FBX in the Project window
2. Open the Animation tab
3. Use the clip list to define ranges with start/end frames
4. Name each clip appropriately (Idle, Walk, Run, etc.)
5. Configure loop and root motion settings per clip

### Humanoid Retargeting

Once clips are imported with Humanoid rig type and Avatar configured:
- The same clip can play on any character with a valid Humanoid Avatar
- No additional setup needed -- the Avatar system handles bone remapping
- Animation quality depends on how closely character proportions match the source

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| No compression on mobile | Excessive memory usage | Use Keyframe Reduction or Optimal |
| Mismatched timing in Blend Trees | Foot sliding, jerky blends | Align contact points in normalized time |
| Loop Pose disabled on looping clips | Visible pop at loop boundary | Enable Loop Pose for smooth looping |
| Bake Into Pose (XZ) off for idle | Character slowly drifts during idle | Enable Bake Into Pose XZ for stationary clips |
| Events on wrong GameObject | Events never fire | Ensure script is on the same GameObject as the Animator |
| Excessive keyframes in hand-authored clips | Bloated file size, harder to edit | Use fewer keyframes; let interpolation do the work |

## Related Documentation

- [Animation Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationOverview.html)
- [Animation Events](https://docs.unity3d.com/6000.3/Documentation/Manual/AnimationEventsOnImportedClips.html)
- [Root Motion](https://docs.unity3d.com/6000.3/Documentation/Manual/RootMotion.html)
- [Blend Trees](https://docs.unity3d.com/6000.3/Documentation/Manual/class-BlendTree.html)
