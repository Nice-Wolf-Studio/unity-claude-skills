# Unity 6 VFX Graph Reference

Comprehensive reference for VFX Graph nodes, contexts, GPU events, and C# integration in Unity 6.3 LTS.

## Overview

The Visual Effect Graph is a node-based visual logic system for authoring visual effects. It simulates particle behavior on the GPU, enabling millions of particles compared to the CPU-based Particle System's thousands. Effects are stored in Visual Effect Assets and controlled at runtime via the VisualEffect component.

### Key Characteristics
- **GPU-based simulation** for massive particle counts
- **Node-based graph editor** for visual authoring
- **Requires URP or HDRP** (not available in Built-in Render Pipeline)
- **Previews changes immediately** with adjustable simulation rates
- Supports sub-graphs for reusable node combinations
- Supports nesting VFX Graphs within other graphs
- Effects managed through event systems triggerable via C# or Timeline

## Architecture

### Two Logic Flows
1. **Vertical (Processing)**: Links Contexts in sequence defining particle lifetime stages
2. **Horizontal (Property)**: Connects Operators for mathematical operations feeding into Contexts/Blocks

### Graph Elements

**Blocks**: Stackable nodes within Contexts. Each handles one operation. Execution order is top-to-bottom within a Context. Can be reordered by dragging.

**Operators**: Low-level nodes composing the property workflow. Connect to Block and Context ports for data input. Examples: Math operations, noise generators, samplers.

**Properties**: Exposed parameters connectable via the property workflow. Can be set from C# at runtime.

**Settings**: Non-connectable editable values on Contexts and Blocks. Configured in the Inspector.

**Groups**: Organizational containers for multiple nodes.

**Sticky Notes**: Draggable comment elements for documentation within the graph.

## Systems

VFX Graph organizes effects into three system types:

### 1. Spawn System
- Contains a single **Spawn Context**
- Manages particle emission rate and timing
- Runs on the CPU

### 2. Particle System
- Contains **Initialize -> Update -> Output** Context chain
- Processes particle lifecycle on the GPU
- One Initialize feeds into one or more Update/Output contexts

### 3. Mesh Output System
- Contains a single **Mesh Output Context**
- Renders static meshes with VFX Graph properties

## Contexts

### Spawn Context
Manages particle emission with three operational states:
- **Running (Looping)**: Computes Blocks and spawns new particles
- **Idle**: Inactive, not spawning
- **Waiting**: Delayed before next loop

**Configuration:**
| Setting | Description |
|---------|-------------|
| Loop Duration | Infinite, Constant, or Random |
| Loop Count | Number of emission loops |
| Delay Before Loop | Wait time before loop starts |
| Delay After Loop | Wait time after loop ends |

**Flow Ports:**
- **Start**: Receives implicit OnPlay event
- **Stop**: Receives implicit OnStop event

Compatible Blocks can be added for custom spawn logic (constant rate, burst, etc.).

### Initialize Context
Generates new particles from SpawnEvent data.

**Sources:** Events, Spawn Contexts, or GPU Event Contexts. SpawnEvent and GPUSpawnEvent sources are mutually exclusive.

**Key Settings:**
| Setting | Description |
|---------|-------------|
| Bounds | System bounding box for culling |
| Capacity | Maximum particle allocation count |

**Purpose:** Entry point for new particles. Processes Blocks for all newly spawned particles (set initial position, velocity, color, size, lifetime, etc.).

**Outputs to:** Particle Update or Particle Output contexts.

### Update Context
Updates all living particles each frame.

**Automatic Computations (toggleable):**
| Computation | Description |
|-------------|-------------|
| Update Position | Euler velocity integration for position |
| Update Rotation | Angular integration for rotation |
| Age Particles | Increments particle age each frame |
| Reap Particles | Removes particles when age exceeds lifetime |

**Purpose:** Per-frame simulation for forces, collisions, noise, attraction, custom behavior.

**Outputs to:** Another Update Context or Output Context.

### Output Context
Renders particles using different modes and shapes.

**Input from:** Initialize or Update Context.

**Types of Output:**
- Quad Output (billboards)
- Mesh Output (3D meshes per particle)
- Line Output
- Strip Output (connected particle strips)
- Lit Quad/Mesh Output (with lighting)
- Decal Output

**No output ports** -- terminal node in the processing chain.

Customizable through compatible Blocks for rendering properties (color, alpha, size, orientation).

## GPU Events

GPU Events are an experimental feature where the GPU computes events (vs CPU for normal events).

Key characteristics:
- Cannot be customized with Blocks
- Used for inter-system communication on the GPU
- Example: particle death in one system spawns particles in another
- Connected from Update Context GPU Event ports to Initialize Context

**Limitations:**
- Experimental/preview feature
- No Block customization
- GPU-only execution (no CPU-side callbacks)

## Property Types

VFX Graph supports these exposed property types accessible from C#:

| Type | C# Method |
|------|-----------|
| Int | `SetInt()` / `GetInt()` / `HasInt()` |
| UInt | `SetUInt()` / `GetUInt()` / `HasUInt()` |
| Bool | `SetBool()` / `GetBool()` / `HasBool()` |
| Float | `SetFloat()` / `GetFloat()` / `HasFloat()` |
| Vector2 | `SetVector2()` / `GetVector2()` / `HasVector2()` |
| Vector3 | `SetVector3()` / `GetVector3()` / `HasVector3()` |
| Vector4 | `SetVector4()` / `GetVector4()` / `HasVector4()` |
| Gradient | `SetGradient()` / `GetGradient()` / `HasGradient()` |
| AnimationCurve | `SetAnimationCurve()` / `GetAnimationCurve()` / `HasAnimationCurve()` |
| Mesh | `SetMesh()` / `GetMesh()` / `HasMesh()` |
| Texture | `SetTexture()` / `GetTexture()` / `HasTexture()` |
| Matrix4x4 | `SetMatrix4x4()` / `GetMatrix4x4()` / `HasMatrix4x4()` |

Use `ResetOverride(property)` to restore original graph values.

## C# API (UnityEngine.VFX.VisualEffect)

### Core Properties
```csharp
visualEffectAsset   // Assign/change effect graph at runtime
initialEventName    // Customize startup event (string)
initialEventID      // Startup event (int ID)
playRate            // Simulation speed multiplier
resetSeedOnPlay     // Randomize seed each play
startSeed           // Manual seed value
aliveParticleCount  // Active particle count (async update)
culled              // Was culled by camera last frame
pause               // Pause/resume without serialization
```

### Playback Control
```csharp
Play()                      // Start effect
Play(eventAttribute)        // Start with event attributes
Stop()                      // Stop effect
Stop(eventAttribute)        // Stop with event data
Reinit()                    // Reset time to 0, resend default event
AdvanceOneFrame()           // Step one frame (requires pause=true)
```

### Event System
```csharp
SendEvent(eventNameOrId)                    // Trigger named event
SendEvent(eventNameOrId, eventAttribute)    // Trigger with payload
CreateVFXEventAttribute()                   // Create compatible attribute object
```

### Property Access
```csharp
// Check existence
HasFloat("PropertyName")
HasVector3("PropertyName")

// Get values
GetFloat("PropertyName")
GetVector3("PropertyName")

// Set values (creates override)
SetFloat("PropertyName", value)
SetVector3("PropertyName", value)

// Reset to graph default
ResetOverride("PropertyName")
```

## Common Scripting Patterns

### Basic VFX Control
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXBasicControl : MonoBehaviour
{
    VisualEffect vfx;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();

        // Set exposed properties
        vfx.SetFloat("SpawnRate", 200f);
        vfx.SetVector3("Velocity", new Vector3(0, 5, 0));
        vfx.SetFloat("ParticleSize", 0.1f);

        vfx.Play();
    }

    public void SetIntensity(float intensity)
    {
        vfx.SetFloat("SpawnRate", intensity * 200f);
        vfx.SetFloat("ParticleSize", intensity * 0.1f);
    }

    public void StopEffect()
    {
        vfx.Stop();
    }
}
```

### Event-Driven VFX
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXEventDriven : MonoBehaviour
{
    VisualEffect vfx;
    VFXEventAttribute eventAttr;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
        eventAttr = vfx.CreateVFXEventAttribute();
    }

    public void TriggerHitEffect(Vector3 position, Vector3 normal, Color color)
    {
        eventAttr.SetVector3("position", position);
        eventAttr.SetVector3("direction", normal);
        eventAttr.SetFloat("intensity", 1.0f);
        vfx.SendEvent("OnHit", eventAttr);
    }

    void OnTriggerEnter(Collider other)
    {
        eventAttr.SetVector3("position", other.ClosestPoint(transform.position));
        vfx.SendEvent("OnImpact", eventAttr);
    }
}
```

### Runtime Asset Switching
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXAssetSwapper : MonoBehaviour
{
    VisualEffect vfx;
    [SerializeField] VisualEffectAsset fireEffect;
    [SerializeField] VisualEffectAsset iceEffect;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
    }

    public void SetFireMode()
    {
        vfx.Stop();
        vfx.visualEffectAsset = fireEffect;
        vfx.SetFloat("SpawnRate", 100f);
        vfx.Play();
    }

    public void SetIceMode()
    {
        vfx.Stop();
        vfx.visualEffectAsset = iceEffect;
        vfx.SetFloat("SpawnRate", 50f);
        vfx.Play();
    }
}
```

### Controlled Simulation Stepping
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXStepSimulation : MonoBehaviour
{
    VisualEffect vfx;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
        vfx.pause = true;
    }

    public void StepFrame()
    {
        vfx.AdvanceOneFrame();
    }

    public void SetPlayRate(float rate)
    {
        vfx.pause = false;
        vfx.playRate = rate;  // 0.5 = half speed, 2.0 = double speed
    }
}
```

### Seed Control for Deterministic Effects
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXSeedControl : MonoBehaviour
{
    VisualEffect vfx;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
        vfx.resetSeedOnPlay = false;
        vfx.startSeed = 42;  // Deterministic seed
        vfx.Reinit();
    }

    public void Randomize()
    {
        vfx.resetSeedOnPlay = true;
        vfx.Reinit();
    }
}
```

### Checking Particle Count and Culling
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXMonitor : MonoBehaviour
{
    VisualEffect vfx;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
    }

    void Update()
    {
        // aliveParticleCount updates asynchronously (may be 1 frame behind)
        int count = vfx.aliveParticleCount;

        // Check if effect was culled by camera last frame
        if (vfx.culled)
        {
            // Effect not visible -- consider reducing quality or pausing
        }

        // Auto-cleanup when effect finishes
        if (count == 0 && !vfx.HasAnySystemAwake())
        {
            Destroy(gameObject);
        }
    }
}
```

### Timeline Integration Pattern
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXTimelineController : MonoBehaviour
{
    VisualEffect vfx;
    [SerializeField] string activationEvent = "OnActivate";
    [SerializeField] string deactivationEvent = "OnDeactivate";

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
    }

    // Called from Timeline Signal Receiver or Animation Event
    public void ActivateEffect()
    {
        vfx.SendEvent(activationEvent);
    }

    public void DeactivateEffect()
    {
        vfx.SendEvent(deactivationEvent);
    }

    public void SetProperty(string name, float value)
    {
        if (vfx.HasFloat(name))
        {
            vfx.SetFloat(name, value);
        }
    }
}
```

## VFX Graph Context Block Examples

### Common Spawn Blocks
- **Constant Spawn Rate**: Emit N particles per second
- **Periodic Burst**: Emit bursts at intervals
- **Variable Spawn Rate**: Rate controlled by property/operator
- **Single Burst**: One-time particle burst

### Common Initialize Blocks
- **Set Position**: Random (sphere, box, circle, line, mesh surface)
- **Set Velocity**: Random direction, from center, tangent
- **Set Lifetime**: Random between min/max
- **Set Size**: Random or constant
- **Set Color**: Random gradient, constant, from map
- **Set Angle**: Random initial rotation
- **Add Position (Attribute from Map)**: Sample position from texture

### Common Update Blocks
- **Add Force**: Gravity, wind, attraction
- **Turbulence/Noise**: Curl noise, Perlin noise forces
- **Conform to Sphere/SDF**: Surface attraction
- **Collision**: Plane, sphere, depth buffer collision
- **Set Alpha over Lifetime**: Fade in/out curves
- **Set Size over Lifetime**: Growth/shrink curves
- **Kill (Age)**: Remove old particles (handled by Reap if enabled)

### Common Output Blocks
- **Set Color over Lifetime**: Color gradient
- **Set Size over Lifetime**: Size animation
- **Orient**: Face camera, along velocity, fixed axis
- **Flipbook Player**: Animated texture sheets
- **Soft Particle**: Depth-based edge softening

## Particle System vs VFX Graph Decision Matrix

| Scenario | Recommendation | Reason |
|----------|---------------|--------|
| Mobile game effects | Particle System | CPU-based, works on all pipelines |
| Thousands of rain/snow particles | VFX Graph | GPU handles millions efficiently |
| Simple UI particles | Particle System | Lighter setup, Canvas compatible |
| Volumetric smoke/fog | VFX Graph | Complex simulation, high count |
| Fire with sparks sub-emitters | Either | PS has native sub-emitters; VFX has GPU events |
| Physics-driven debris | Particle System | Better CPU physics integration |
| Stylized magic effects | VFX Graph | Node-based authoring, flexible |
| Built-in Render Pipeline project | Particle System | VFX Graph requires URP/HDRP |
| Need C# per-particle control | Particle System | Direct GetParticles/SetParticles API |
| Cinematic large-scale battle | VFX Graph | Millions of particles, GPU simulation |

## Anti-Patterns

1. **Using VFX Graph for simple mobile effects**: GPU overhead and URP/HDRP requirement make it overkill. Use Particle System instead.

2. **Not setting Capacity in Initialize Context**: Default capacity may allocate excessive GPU memory. Always configure based on expected max particle count.

3. **Ignoring Bounds in Initialize Context**: Incorrect bounds cause effects to be culled when they should be visible. Manually configure bounds to encompass the full effect volume.

4. **Sending events every frame without throttling**: `SendEvent()` has CPU-GPU synchronization cost. Batch or throttle event dispatch. Use exposed properties for continuous changes instead.

5. **Not checking HasProperty before setting**: Setting a non-existent property silently fails. Always verify with `HasFloat()` etc., especially when swapping assets.

6. **Forgetting to call Reinit() after asset swap**: Old particle state persists. Call `Reinit()` after changing `visualEffectAsset` to start fresh.

7. **Over-relying on aliveParticleCount**: This value updates asynchronously and may be one frame behind. Do not use for frame-accurate logic.

8. **Not using GPU Events for cascading effects**: Creating separate systems with C# event bridging adds unnecessary CPU overhead. Use GPU Event contexts for particle-to-particle spawning.

## References
- [VFX Graph Package Documentation](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@17.0/manual/index.html)
- [VFX Graph Contexts](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@17.0/manual/Contexts.html)
- [VisualEffect Component API](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@17.0/manual/ComponentAPI.html)
- [VFX Graph Logic](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@17.0/manual/GraphLogicAndPhilosophy.html)
