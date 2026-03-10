---
name: unity-lighting-vfx
description: >
  Unity 6 lighting and visual effects guide. Use when working with lights, baked/realtime/mixed lighting, light probes, reflection probes, Adaptive Probe Volumes (APV), global illumination, Particle System, VFX Graph, or post-processing effects. Based on Unity 6.3 LTS documentation.
---

# Unity Lighting and Visual Effects

## Lighting Modes

Unity provides three light modes controlling how illumination is calculated.

### Realtime Lights
- Calculate lighting **every frame at runtime**
- Allow dynamic changes to intensity, color, position
- Cast shadows up to Shadow Distance
- Contribute only direct lighting by default (no bounced light)
- Higher runtime cost, especially in complex scenes or low-end hardware
- Best for: dynamic objects, flickering effects, moving light sources

### Baked Lights
- Calculations performed **in the Unity Editor** and saved as lighting data to disk
- At runtime, Unity loads pre-computed data instead of calculating dynamically
- Bake both direct and indirect lighting into lightmaps
- Store information in Light Probes for moving objects
- Cannot modify light properties at runtime; do not illuminate dynamic GameObjects
- No specular contributions
- Best for: static scenery, complex indirect lighting, performance-critical scenarios

### Mixed Lights
- Combine **baked indirect lighting** with **real-time direct lighting**
- Behavior depends on the Lighting Mode setting in the Lighting window
- Cast real-time shadows (not baked soft shadows)
- Can change properties at runtime (affects real-time component only)
- Always more expensive than fully baked lighting
- Best for: dynamic shadows with baked background lighting

**Important:** All baked/mixed modes require **Baked Global Illumination** enabled. Without it, Mixed and Baked lights behave as Realtime.

## Light Types

### Directional Light
- Located infinitely far away, emits light in one direction
- Parallel rays, no distance-based intensity falloff
- Simulates sun/moon; every new scene includes one by default
- Links to procedural sky system; rotate to create time-of-day effects

### Point Light
- Located at a point, emits in all directions equally
- Intensity follows inverse square law (diminishes with distance squared)
- Use for lamps, explosions, local illumination

### Spot Light
- Located at a point, emits in a cone shape
- Adjustable cone angle; light diminishes at edges (penumbra)
- Wider angles create larger fade areas
- Use for flashlights, headlights, searchlights

### Area Light
- Defined by a rectangle or disc; emits uniformly across surface
- Follows inverse square law; produces soft, subtle shading
- **Bake-only** -- not available at runtime
- Use for street lights, realistic interior lighting

## Global Illumination

Global illumination (GI) simulates how light bounces between surfaces, producing realistic indirect lighting.

### Baked GI
- Pre-computes indirect lighting into lightmaps using the **Progressive Lightmapper** (CPU or GPU)
- Results stored in lightmap textures and Light Probes
- Configure in the Lighting window under **Bake** settings
- GPU Progressive Lightmapper offers faster bake times with configurable tile sizes

### Environment Lighting
Three ambient light sources configured in the Lighting window Environment tab:
- **Skybox**: Uses skybox material colors for ambient light from different angles
- **Gradient**: Separate sky, horizon, and ground colors with smooth blending
- **Color**: Uniform ambient light across the scene

Intensity Multiplier (0-8, default 1) controls ambient brightness.

### Environment Reflections
- Source: Skybox or custom Cubemap/RenderTexture
- Configurable resolution, compression, intensity multiplier
- Bounces setting controls reflection evaluation iterations between objects

## Light Probes and Adaptive Probe Volumes

### Light Probes
- Capture lighting information in **empty space** throughout a scene
- At runtime, indirect lighting for dynamic GameObjects is approximated using nearest probes
- Provide indirect bounced light for moving objects and LOD system support
- Must be manually placed using Light Probe Groups
- Store baked lighting information; work with both direct and indirect lighting

### Adaptive Probe Volumes (APV)
APV is the modern replacement for manual Light Probe placement in URP:
- **Automated probe placement** -- eliminates manual Light Probe Group positioning
- **Per-pixel lighting** -- superior quality compared to per-object approaches
- **Scene baking** -- bake multiple scenes together using Baking Sets
- **Runtime adjustments** -- Lighting Scenarios and sky occlusion for dynamic changes
- **Large-world support** -- streaming data for expansive open-world environments
- **Data flexibility** -- loading from AssetBundles or Addressables
- Configurable probe density and volume size with visualization tools

## Reflection Probes

Capture a spherical view of surroundings as a cubemap for reflective materials.

### Types
| Type | Description |
|------|-------------|
| **Baked** | Captures static GameObjects only; best performance |
| **Custom** | Allows dynamic object capture with custom textures |
| **Realtime** | Updates during gameplay; configurable refresh mode |

### Key Properties
- **Importance**: Rendering priority when multiple probes overlap
- **Intensity**: Texture brightness in shader calculations
- **Box Projection**: Enables projection mapping for interiors (requires URP config)
- **Box Size/Offset**: World-space bounding box for reflection contribution
- **Blend Distance**: Blending distance for deferred probes

### Realtime Options
- **Refresh Mode**: On Awake, Every Frame, or Via Scripting
- **Time Slicing**: All Faces At Once, Individual Faces, No Time Slicing

## Particle System vs VFX Graph

| Feature | Particle System | VFX Graph |
|---------|----------------|-----------|
| Simulation | CPU-based | GPU-based |
| Particle count | Thousands | Millions |
| Render pipeline | All pipelines | URP/HDRP only |
| Authoring | Inspector modules | Node-based graph editor |
| Physics | Built-in collision | Custom collision blocks |
| Scripting | Full C# API | Event-based C# API |
| Sub-emitters | Native support | GPU Event contexts |
| Best for | Small/medium effects, mobile | Large-scale effects, high-end |

**Decision Guide:**
- Use **Particle System** for mobile targets, simple effects, when you need full CPU-side scripting control, or when targeting the Built-in Render Pipeline
- Use **VFX Graph** for massive particle counts, GPU-driven simulations, complex node-based authoring, or high-end platforms with URP/HDRP

## Particle System Modules

| Module | Purpose |
|--------|---------|
| **Main** | Initial state: lifetime, speed, size, gravity, simulation space |
| **Emission** | Rate and timing of particle spawns |
| **Shape** | Volume/surface for emission and start velocity direction |
| **Velocity over Lifetime** | Modify movement over particle age |
| **Noise** | Turbulence for organic, chaotic motion |
| **Limit Velocity over Lifetime** | Natural deceleration |
| **Force over Lifetime** | Simulated physics forces |
| **Inherit Velocity** | Sub-emitter particles match parent velocity |
| **Lifetime by Emitter Speed** | Adjust lifespan based on emitter velocity |
| **Color over Lifetime / by Speed** | Color changes based on age or velocity |
| **Size over Lifetime / by Speed** | Dimension changes based on time or speed |
| **Rotation over Lifetime / by Speed** | Orientation changes |
| **Collision** | Particle collisions with scene geometry |
| **Triggers** | Designate particles as collision triggers |
| **Sub Emitters** | Particles that emit other particles |
| **Texture Sheet Animation** | Texture grid animation frames |
| **Trails** | Motion trail rendering |
| **Lights** | Real-time lights on particles |
| **External Forces** | Wind zones and force fields |
| **Renderer** | Image/mesh transform, shading, overdraw |
| **Custom Data** | Attach custom data to particles |

## VFX Graph Basics

### Systems
1. **Spawn System**: Single Spawn Context managing emission
2. **Particle System**: Initialize -> Update -> Output succession
3. **Mesh Output System**: Single Mesh Output Context

### Contexts
- **Spawn**: Executes each frame to calculate spawn amounts. States: Running, Idle, Waiting. Configurable loop duration, count, and delays
- **Initialize**: Runs at particle birth, sets initial state. Processes Blocks for newly spawned particles. Configurable bounds and capacity
- **Update**: Per-frame for all living particles. Automatic: position integration, rotation integration, aging, reaping
- **Output**: Renders particles (Quad, Mesh, etc.). No output ports. Customizable rendering blocks

### Graph Elements
- **Blocks**: Stackable nodes within Contexts; each handles one operation; top-to-bottom execution
- **Operators**: Low-level property workflow nodes connecting to Block/Context ports
- **Properties**: Connectable via property workflow
- **Settings**: Non-connectable editable values per Context

### GPU Events
Experimental feature where GPU computes events (vs CPU for normal events). Cannot be customized with Blocks.

## Common Patterns (C#)

### Create and Configure a Light
```csharp
using UnityEngine;

public class LightSetup : MonoBehaviour
{
    void Start()
    {
        GameObject lightObj = new GameObject("Dynamic Light");
        Light light = lightObj.AddComponent<Light>();
        light.type = LightType.Point;
        light.color = Color.yellow;
        light.intensity = 2.0f;
        light.range = 15f;
        light.shadows = LightShadows.Soft;
        light.shadowResolution = UnityEngine.Rendering.LightShadowResolution.Medium;
    }
}
```

### Create a Realtime Reflection Probe
```csharp
using UnityEngine;
using UnityEngine.Rendering;

public class ProbeSetup : MonoBehaviour
{
    void Start()
    {
        GameObject probeObj = new GameObject("Realtime Reflection Probe");
        ReflectionProbe probe = probeObj.AddComponent<ReflectionProbe>();
        probe.size = new Vector3(10, 10, 10);
        probe.mode = ReflectionProbeMode.Realtime;
        probe.refreshMode = ReflectionProbeRefreshMode.EveryFrame;
        probe.resolution = 256;
        probe.hdr = true;
    }
}
```

### Control Particle System at Runtime
```csharp
using UnityEngine;

public class ParticleController : MonoBehaviour
{
    ParticleSystem ps;

    void Start()
    {
        ps = GetComponent<ParticleSystem>();

        // Modify emission rate -- cache module in local variable first
        var emission = ps.emission;
        emission.rateOverTimeMultiplier = 50f;

        // Modify main module
        var main = ps.main;
        main.startLifetime = 3f;
        main.startSpeed = 5f;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
    }

    void OnTriggerEnter(Collider other)
    {
        // Burst emit particles
        ps.Emit(100);
    }

    void OnDisable()
    {
        ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
    }
}
```

### VFX Graph Runtime Control
```csharp
using UnityEngine;
using UnityEngine.VFX;

public class VFXController : MonoBehaviour
{
    VisualEffect vfx;
    VFXEventAttribute eventAttr;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();
        eventAttr = vfx.CreateVFXEventAttribute();

        // Set exposed properties
        vfx.SetFloat("SpawnRate", 100f);
        vfx.SetVector3("Direction", Vector3.up);
        vfx.playRate = 1.5f;
    }

    void OnTriggerEnter(Collider other)
    {
        // Send custom event with attributes
        eventAttr.SetVector3("position", other.transform.position);
        vfx.SendEvent("OnHit", eventAttr);
    }

    public void StopEffect()
    {
        vfx.Stop();
    }
}
```

### Refresh Reflection Probe on Demand
```csharp
using UnityEngine;

public class ProbeRefresher : MonoBehaviour
{
    ReflectionProbe probe;

    void Start()
    {
        probe = GetComponent<ReflectionProbe>();
        probe.refreshMode = UnityEngine.Rendering.ReflectionProbeRefreshMode.ViaScripting;
    }

    public void RefreshReflections()
    {
        probe.RenderProbe();
    }

    public bool IsReady()
    {
        return probe.IsFinishedRendering(probe.RenderProbe());
    }
}
```

## Anti-Patterns

### Lighting Anti-Patterns
1. **Too many Realtime lights**: Each realtime light adds per-frame cost. Use Baked or Mixed for static lights
2. **Forgetting to enable Baked Global Illumination**: Mixed/Baked lights silently fall back to Realtime without it
3. **Overlapping Reflection Probes without Importance values**: Causes flickering; always set Importance to establish priority
4. **Using Area Lights expecting runtime behavior**: Area lights are bake-only; they produce no light at runtime
5. **Ignoring Indirect Multiplier**: Leaving at default can cause over-bright or too-dark bounced light; tune per light
6. **Not setting Shadow Bias correctly**: Too low causes self-shadowing artifacts (shadow acne); too high causes peter-panning (shadows detach from objects)
7. **Manual Light Probe placement in large scenes**: Use Adaptive Probe Volumes (APV) in URP instead for automated, per-pixel quality

### Particle System Anti-Patterns
1. **Not caching module references**: Each property access on a module struct immediately writes to native code; cache the module variable
2. **Using World simulation space for attached effects**: Particles drift away from moving parents; use Local space for attached FX
3. **Excessive particle counts on CPU**: Particle System is CPU-bound; for >10K particles, consider VFX Graph
4. **Forgetting to Stop/Clear**: Leaked particle systems consume CPU even when invisible

### VFX Graph Anti-Patterns
1. **Using VFX Graph for simple effects on mobile**: GPU overhead and URP/HDRP requirement make it overkill for simple mobile effects
2. **Not setting Capacity in Initialize**: Default capacity may allocate too much or too little GPU memory
3. **Ignoring Bounds**: Incorrect bounds cause effects to be culled when visible; always configure bounds in Initialize context
4. **Sending events every frame without throttling**: SendEvent has CPU-GPU sync cost; batch or throttle event dispatch

## Key API Quick Reference

### Light (UnityEngine.Light)
| Member | Type | Description |
|--------|------|-------------|
| `type` | Property | LightType (Directional, Point, Spot, Area) |
| `color` | Property | Emitted light color |
| `intensity` | Property | Brightness multiplier |
| `range` | Property | Max distance (Point/Spot) |
| `spotAngle` / `innerSpotAngle` | Property | Outer/inner cone angles |
| `shadows` | Property | LightShadows (None, Hard, Soft) |
| `shadowResolution` | Property | Shadow map quality |
| `shadowBias` / `shadowNormalBias` | Property | Shadow artifact reduction |
| `bounceIntensity` | Property | GI bounce strength |
| `cookie` | Property | Projected texture mask |
| `cullingMask` | Property | Layer-based filtering |
| `colorTemperature` | Property | CCT in Kelvin |
| `lightmapBakeType` | Property | Baking configuration |
| `bakingOutput` | Property | Last bake contribution details |
| `AddCommandBuffer()` | Method | Execute GPU commands at specified points |

### ParticleSystem (UnityEngine.ParticleSystem)
| Member | Type | Description |
|--------|------|-------------|
| `main` / `emission` / `shape` | Property | Module access structs |
| `particleCount` | Property | Current active particles |
| `isPlaying` / `isPaused` / `isStopped` | Property | Playback state |
| `Play()` / `Pause()` / `Stop()` | Method | Playback control |
| `Emit(count)` | Method | Immediate particle spawn |
| `Simulate(time)` | Method | Fast-forward simulation |
| `GetParticles()` / `SetParticles()` | Method | Direct particle data access |
| `Clear()` | Method | Remove all particles |
| `TriggerSubEmitter()` | Method | Activate sub-emitters |

### VisualEffect (UnityEngine.VFX.VisualEffect)
| Member | Type | Description |
|--------|------|-------------|
| `visualEffectAsset` | Property | Assign/change effect graph |
| `playRate` | Property | Simulation speed |
| `aliveParticleCount` | Property | Active particle count |
| `Play()` / `Stop()` / `Reinit()` | Method | Playback control |
| `SendEvent(name, attr)` | Method | Trigger graph events |
| `CreateVFXEventAttribute()` | Method | Create event payload |
| `SetFloat()` / `SetVector3()` / etc. | Method | Set exposed properties |
| `GetFloat()` / `GetVector3()` / etc. | Method | Read exposed properties |
| `HasFloat()` / `HasVector3()` / etc. | Method | Check property existence |
| `ResetOverride(property)` | Method | Restore original values |

### ReflectionProbe (UnityEngine.ReflectionProbe)
| Member | Type | Description |
|--------|------|-------------|
| `mode` | Property | Baked/Custom/Realtime |
| `size` / `center` | Property | Bounding box config |
| `intensity` / `importance` | Property | Brightness and priority |
| `boxProjection` | Property | Enable box projection |
| `refreshMode` / `timeSlicingMode` | Property | Realtime update config |
| `RenderProbe()` | Method | Force cubemap refresh |
| `IsFinishedRendering()` | Method | Check time-sliced completion |
| `BlendCubemap()` | Method | Blend two cubemaps |

## Related Skills
- `unity-graphics` -- Render pipelines (URP/HDRP/Built-in), shaders, materials, cameras
- `unity-2d` -- 2D lighting (URP 2D Renderer), sprite rendering
- `unity-platforms` -- Platform-specific lighting quality tiers, mobile optimization

## Additional Resources
- [Lighting Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/LightingOverview.html)
- [Light Types](https://docs.unity3d.com/6000.3/Documentation/Manual/LightTypes.html)
- [Light Modes](https://docs.unity3d.com/6000.3/Documentation/Manual/LightModes-introduction.html)
- [Light Probes](https://docs.unity3d.com/6000.3/Documentation/Manual/LightProbes.html)
- [Reflection Probes](https://docs.unity3d.com/6000.3/Documentation/Manual/ReflectionProbes.html)
- [Adaptive Probe Volumes (URP)](https://docs.unity3d.com/6000.3/Documentation/Manual/urp/probevolumes.html)
- [Particle System Modules](https://docs.unity3d.com/6000.3/Documentation/Manual/configuring-particles.html)
- [VFX Graph Package](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@17.0/manual/index.html)
- [Light Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Light.html)
- [ParticleSystem Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/ParticleSystem.html)
- [ReflectionProbe Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/ReflectionProbe.html)
