# Unity 6 Lighting Guide

Comprehensive reference for lighting setup, baking, probes, Adaptive Probe Volumes, and environment lighting in Unity 6.3 LTS.

## Light Component Properties

The Light component is the primary way to add illumination to a scene. All properties are accessible via the `UnityEngine.Light` class.

### Core Properties

| Property | Description | Applicable Types |
|----------|-------------|-----------------|
| **Type** | Directional, Point, Spot, or Area (Rectangle/Disc) | All |
| **Range** | Emission distance from light center | Point, Spot |
| **Spot Angle** | Cone angle in degrees | Spot |
| **Color** | Emitted light color | All |
| **Mode** | Realtime, Mixed, or Baked | All |
| **Intensity** | Brightness level (default 0.5 Directional; 1.0 others) | All |
| **Indirect Multiplier** | Bounced light intensity. Below 1 dims; above 1 brightens. 0 = direct-only | All |
| **Cookie** | Texture mask for patterned shadow/illumination effects | All |
| **Draw Halo** | Spherical glow using Range diameter | Point, Spot |
| **Flare** | Asset rendered at light position | All |
| **Render Mode** | Auto, Important (per-pixel), Not Important (vertex/object) | All |
| **Culling Mask** | Layer-based object inclusion/exclusion | All |

### Shadow Configuration

| Property | Description | Range |
|----------|-------------|-------|
| **Shadow Type** | Hard Shadows or Soft Shadows | -- |
| **Baked Shadow Angle** | Artificial edge softening (Directional, Baked/Mixed) | -- |
| **Baked Shadow Radius** | Artificial edge softening (Point/Spot, Baked/Mixed) | -- |
| **Strength** | Shadow darkness | 0-1, default 1 |
| **Resolution** | Shadow map fidelity vs GPU cost | -- |
| **Bias** | Distance offset preventing self-shadowing artifacts | 0-2, default 0.05 |
| **Normal Bias** | Surface shrinkage along normals | 0-3, default 0.4 |
| **Near Plane** | Near clip plane for shadow rendering | 0.1-10, default 0.2 |

### Scripting API (UnityEngine.Light)

**Light Emission Properties:**
- `color` -- Emitted light color
- `intensity` -- Brightness multiplier
- `lightUnit` -- Display unit for intensity
- `colorTemperature` -- CCT value in Kelvin for realistic lighting
- `bounceIntensity` -- GI bounce strength

**Shape and Range:**
- `type` -- LightType enum (Directional, Point, Spot, Area)
- `range` -- Maximum travel distance (Point/Spot)
- `spotAngle` -- Outer cone angle in degrees
- `innerSpotAngle` -- Inner cone angle
- `areaSize` -- Dimensions of area lights
- `enableSpotReflector` -- Simulates reflector behavior

**Shadow Controls:**
- `shadows` -- LightShadows enum (None, Hard, Soft)
- `shadowResolution` -- Shadow map quality
- `shadowBias` -- Constant offset to reduce artifacts
- `shadowNormalBias` -- Normal-based bias adjustment
- `shadowStrength` -- Shadow darkness intensity
- `shadowRadius` -- Softness for Point/Spot
- `shadowAngle` -- Softness for Directional

**Culling and Visibility:**
- `cullingMask` -- Layer mask for selective lighting
- `renderingLayerMask` -- Rendering layer filtering
- `forceVisible` -- Renders light outside view frustum
- `boundingSphereOverride` -- Custom culling sphere
- `useBoundingSphereOverride` -- Enables bounding sphere override

**Advanced:**
- `cookie` -- Projected texture
- `cookieSize2D` -- Directional cookie dimensions
- `bakingOutput` -- Last bake contribution details
- `lightmapBakeType` -- Baking configuration

**Methods:**
- `AddCommandBuffer(event, buffer)` -- Execute GPU commands at specified render events
- `AddCommandBufferAsync(event, buffer)` -- Async GPU command execution
- `GetCommandBuffers(event)` -- Retrieve attached command buffers
- `RemoveCommandBuffer(event, buffer)` -- Remove specific GPU command buffer
- `RemoveCommandBuffers(event)` -- Remove all buffers for an event
- `RemoveAllCommandBuffers()` -- Clean up all GPU commands
- `Reset()` -- Restore default light parameters
- `SetLightDirty()` -- Notify baking backends of changes (Editor only)

## Light Types In Detail

### Directional Light
Located infinitely far away; emits parallel rays in one direction. No distance-based intensity falloff. Every new Unity scene includes one by default, linked to the procedural sky system. Rotating the directional light creates time-of-day effects (sunrise, sunset, night).

Best practices:
- Use one primary directional light as the "sun"
- Pair with Environment Lighting skybox for consistent ambient
- Rotation controls both shadow direction and sky color (when using procedural skybox)

### Point Light
Emits from a single point in all directions equally. Intensity follows the inverse square law. Configurable via `range` property.

Best practices:
- Set range to match the visual extent of the light source
- Use for lamps, torches, explosions, campfires
- Consider baking for static point lights to save runtime cost

### Spot Light
Emits in a cone shape with adjustable angle. Light diminishes at cone edges (penumbra effect). Wider angles create larger fade areas.

Best practices:
- Use `spotAngle` for outer cone, `innerSpotAngle` for inner cone (hotspot)
- Combine with cookies for flashlight patterns
- Use for headlights, searchlights, stage lighting

### Area Light
Defined by a rectangle or disc. Emits uniformly across surface area. Follows inverse square law. **Bake-only** -- produces no light at runtime.

Best practices:
- Use for realistic soft lighting in architectural visualization
- Increase size for softer shadows
- Always pair with lightmapping; cannot be used with Realtime mode

## Lighting Modes Deep Dive

### Realtime Mode
- Lighting calculated every frame at runtime
- Supports dynamic changes to all light properties
- Cast shadows up to Shadow Distance setting
- Direct lighting only by default (shadows are completely black without indirect)
- Cost scales with scene complexity and number of shadow-casting lights

### Baked Mode
- Pre-computed in Unity Editor; saved as lighting data to disk
- Bakes direct and indirect lighting into lightmaps
- Stores probe data in Light Probes for dynamic objects
- Minimal runtime overhead
- Cannot modify at runtime; does not illuminate dynamic GameObjects
- No specular contributions

### Mixed Mode
- Baked indirect lighting + real-time direct lighting
- Behavior depends on Lighting Mode setting:
  - **Baked Indirect**: Real-time direct + baked indirect. Best balance of quality and performance
  - **Subtractive**: Bakes everything; applies real-time shadow on top. Cheapest mixed mode
  - **Shadowmask**: Baked indirect + distance shadowmask. Best shadow quality for static objects
- Always more expensive than fully baked
- Real-time shadows (not baked soft shadows)

**Dependency:** Baked Global Illumination must be enabled. Without it, Mixed and Baked lights silently fall back to Realtime with Inspector warnings.

## Lighting Window Settings

Access via **Window > Rendering > Lighting**.

### Environment Tab

**Ambient Light Source:**
| Source | Description |
|--------|-------------|
| Skybox | Uses skybox material colors for ambient from different angles |
| Gradient | Separate sky, horizon, ground colors with smooth blending |
| Color | Uniform ambient light across the scene |

- **Intensity Multiplier**: 0-8 range, default 1

**Environment Reflections:**
- Source: Skybox or custom Cubemap/RenderTexture
- Resolution: Adjustable for skybox reflections
- Compression: Auto, Uncompressed, or Compressed
- Intensity Multiplier: Controls reflection visibility strength
- Bounces: Reflection evaluation iterations between objects

### Bake Settings

**Bake on Scene Load options:**
- Never (default for Unity 6 projects)
- If Missing Lighting Data (default for earlier versions)

**Generate Lighting dropdown:**
- Full bake (lightmaps, Light Probes, APV, Reflection Probes)
- Bake Probe Volumes only
- Bake Reflection Probes only
- Clear Baked Data

**GPU Progressive Lightmapper:**
- GPU Baking Device selection
- GPU Baking Profile: Automatic, High/Highest Performance, Low/Lowest Memory Usage

**Related APIs:** `LightingSettings` and `Lightmapping` classes for script-based control of bake settings.

## Light Probes

### Concept
Light Probes capture lighting information in **empty space** throughout a scene. They store "baked" lighting data measured during the baking process. At runtime, indirect lighting for dynamic GameObjects is approximated using values from the nearest probes.

### How They Work
1. Place Light Probe Groups in the scene with probes at strategic positions
2. During baking, light is measured at each probe position
3. At runtime, dynamic objects sample nearby probes via tetrahedral interpolation
4. The blended result provides approximate indirect lighting

### Use Cases
- **Dynamic object lighting**: Primary purpose -- delivering high-quality indirect lighting to moving GameObjects
- **LOD system support**: Provides lighting for static scenery using Level of Detail system

### Placement Best Practices
- Place probes where lighting changes significantly (light/shadow transitions)
- Denser placement near important gameplay areas
- Avoid placing probes inside geometry (produces incorrect results)
- Create a grid formation with extra density at light boundaries
- Ensure probes exist on both sides of shadow boundaries
- Place probes at different heights for multi-level environments

### Limitations
- Per-object lighting (not per-pixel) -- can look flat on large objects
- Manual placement is tedious for large scenes
- Requires rebaking when static lighting changes
- Consider APV as a modern replacement in URP

## Adaptive Probe Volumes (APV)

### Overview
APV is the modern replacement for manual Light Probe placement in URP. Key advantages:
- **Automated probe placement** -- eliminates manual Light Probe Group positioning
- **Per-pixel lighting** -- superior quality compared to per-object Light Probes
- **Scalable** -- supports large open-world environments via streaming

### Key Features
- **Baking Sets**: Bake multiple scenes together for consistent lighting across scene boundaries
- **Lighting Scenarios**: Runtime adjustments for different lighting conditions (day/night)
- **Sky Occlusion**: Dynamic sky lighting changes
- **Streaming**: Load/unload probe data for large worlds
- **Data Flexibility**: Load from AssetBundles or Addressables

### Configuration
- **Probe Density**: Adjustable resolution for different areas
- **Volume Size**: Define the region covered by probe volumes
- **Probe Adjustment Volume**: Fine-tune probe behavior in specific regions
- **Options Override**: Per-scene configuration overrides
- **Visualization Tools**: Debug and inspect probe placement

### When to Use APV vs Light Probes
| Criteria | Light Probes | APV |
|----------|-------------|-----|
| Render pipeline | All | URP only |
| Placement | Manual | Automatic |
| Quality | Per-object | Per-pixel |
| Large worlds | Difficult to manage | Streaming support |
| Setup complexity | Simple concept | More configuration |

## Reflection Probes

### Concept
A Reflection Probe captures a spherical view of surroundings in all directions, stored as a cubemap. Reflective materials within the probe's zone use the cubemap for reflections.

### Types

**Baked:**
- Captures static GameObjects only (Reflection Probe Static flag)
- Best performance; baked during lightmap generation
- Cannot reflect dynamic objects

**Custom:**
- Allows dynamic object capture with custom textures
- Assign custom cubemaps for controlled reflections

**Realtime:**
- Updates during gameplay
- Refresh Mode: On Awake, Every Frame, or Via Scripting
- Time Slicing: All Faces At Once, Individual Faces, No Time Slicing
- Most expensive; use sparingly

### Key Properties

| Property | Description |
|----------|-------------|
| Importance | Rendering priority when multiple probes overlap |
| Intensity | Texture brightness modifier in shaders |
| Box Projection | Enables parallax-correct reflections for interiors |
| Box Size | World-space bounding box dimensions |
| Box Offset | Probe-relative center position |
| Blend Distance | Fade distance between probes (deferred rendering) |
| Resolution | Cubemap resolution in pixels |
| HDR | Enable HDR capture (OpenEXR vs PNG) |
| Shadow Distance | Max distance for shadows in probe capture |
| Culling Mask | Layer-based inclusion/exclusion |
| Near/Far Clip | Clipping plane distances |

### Scripting API (UnityEngine.ReflectionProbe)

**Properties:**
- `texture` -- Read-only texture passed to shaders
- `bakedTexture` -- Reference to baked cubemap
- `customBakedTexture` -- Assign custom reflection texture
- `realtimeTexture` -- RenderTexture for real-time reflections
- `mode` -- ReflectionProbeMode (Baked, Custom, Realtime)
- `size` / `center` -- Bounding box configuration
- `intensity` / `importance` -- Brightness and priority
- `boxProjection` -- Enable box projection
- `refreshMode` -- Refresh strategy enum
- `timeSlicingMode` -- Time-sliced rendering mode
- `hdr` -- HDR rendering toggle
- `resolution` -- Cubemap resolution
- `cullingMask` -- Layer mask
- `renderDynamicObjects` -- Include non-static GameObjects
- `nearClipPlane` / `farClipPlane` -- Clipping distances
- `blendDistance` -- Probe blending distance

**Methods:**
- `RenderProbe()` -- Force cubemap refresh; returns render ID
- `IsFinishedRendering(renderId)` -- Check time-sliced render completion
- `Reset()` -- Revert to defaults
- `BlendCubemap(src, dst, blend, target)` -- Utility for blending cubemaps
- `UpdateCachedState()` -- Update culling system data

**Events:**
- `reflectionProbeChanged` -- Fired when probes are added/removed
- `defaultReflectionSet` -- Fired when default cubemap changes
- `defaultReflectionTexture` -- Access default reflection texture

### Best Practices
- Set **Importance** values to prevent flickering when probes overlap
- Use **Box Projection** for indoor environments (parallax-correct reflections)
- Use **Time Slicing** for Realtime probes to spread GPU cost across frames
- Place probes at eye level in rooms; one per distinct reflection zone
- Use **Via Scripting** refresh mode when reflections only need occasional updates
- Baked probes are regenerated with **Generate Lighting**; a default probe always exists

### Creating a Reflection Probe via Script
```csharp
using UnityEngine;
using UnityEngine.Rendering;

public class CreateReflectionProbe : MonoBehaviour
{
    void Start()
    {
        GameObject probeObj = new GameObject("Realtime Reflection Probe");
        probeObj.transform.position = new Vector3(0, 1.5f, 0);

        ReflectionProbe probe = probeObj.AddComponent<ReflectionProbe>();
        probe.size = new Vector3(10, 10, 10);
        probe.mode = ReflectionProbeMode.Realtime;
        probe.refreshMode = ReflectionProbeRefreshMode.EveryFrame;
        probe.timeSlicingMode = ReflectionProbeTimeSlicingMode.IndividualFaces;
        probe.resolution = 256;
        probe.hdr = true;
        probe.boxProjection = true;
        probe.importance = 1;
    }
}
```

### On-Demand Probe Refresh
```csharp
using UnityEngine;
using UnityEngine.Rendering;

public class OnDemandProbe : MonoBehaviour
{
    ReflectionProbe probe;
    int renderID = -1;

    void Start()
    {
        probe = GetComponent<ReflectionProbe>();
        probe.mode = ReflectionProbeMode.Realtime;
        probe.refreshMode = ReflectionProbeRefreshMode.ViaScripting;
    }

    public void RefreshNow()
    {
        renderID = probe.RenderProbe();
    }

    void Update()
    {
        if (renderID >= 0 && probe.IsFinishedRendering(renderID))
        {
            Debug.Log("Reflection probe render complete");
            renderID = -1;
        }
    }
}
```

## Dynamic Light Control Script Example

```csharp
using UnityEngine;

public class DynamicLightController : MonoBehaviour
{
    Light sceneLight;
    [SerializeField] float flickerSpeed = 10f;
    [SerializeField] float flickerAmount = 0.3f;
    float baseIntensity;

    void Start()
    {
        sceneLight = GetComponent<Light>();
        baseIntensity = sceneLight.intensity;
    }

    void Update()
    {
        // Flicker effect using Perlin noise
        float noise = Mathf.PerlinNoise(Time.time * flickerSpeed, 0f);
        sceneLight.intensity = baseIntensity + (noise - 0.5f) * flickerAmount;
    }

    public void SetColor(Color newColor)
    {
        sceneLight.color = newColor;
    }

    public void SetShadowsEnabled(bool enabled)
    {
        sceneLight.shadows = enabled ? LightShadows.Soft : LightShadows.None;
    }
}
```

## Day-Night Cycle Example

```csharp
using UnityEngine;

public class DayNightCycle : MonoBehaviour
{
    [SerializeField] Light directionalLight;
    [SerializeField] float dayDurationSeconds = 120f;
    [SerializeField] Gradient lightColorGradient;
    [SerializeField] AnimationCurve intensityCurve;

    float timeOfDay = 0.25f; // Start at sunrise

    void Update()
    {
        timeOfDay += Time.deltaTime / dayDurationSeconds;
        if (timeOfDay > 1f) timeOfDay -= 1f;

        // Rotate sun
        float sunAngle = timeOfDay * 360f - 90f;
        directionalLight.transform.rotation = Quaternion.Euler(sunAngle, 170f, 0f);

        // Adjust color and intensity over the day
        directionalLight.color = lightColorGradient.Evaluate(timeOfDay);
        directionalLight.intensity = intensityCurve.Evaluate(timeOfDay);
    }
}
```

## References
- [Lighting Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/LightingOverview.html)
- [Light Types](https://docs.unity3d.com/6000.3/Documentation/Manual/LightTypes.html)
- [Light Modes](https://docs.unity3d.com/6000.3/Documentation/Manual/LightModes-introduction.html)
- [Light Probes](https://docs.unity3d.com/6000.3/Documentation/Manual/LightProbes.html)
- [Reflection Probes](https://docs.unity3d.com/6000.3/Documentation/Manual/ReflectionProbes.html)
- [Adaptive Probe Volumes (URP)](https://docs.unity3d.com/6000.3/Documentation/Manual/urp/probevolumes.html)
- [Lighting Window](https://docs.unity3d.com/6000.3/Documentation/Manual/lighting-window.html)
- [Light Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Light.html)
- [ReflectionProbe Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/ReflectionProbe.html)
