# HDRP (High Definition Render Pipeline) Guide

## Overview

The High Definition Render Pipeline (HDRP) is a prebuilt Scriptable Render Pipeline built by Unity targeting AAA-quality games, automotive demonstrations, architectural visualizations, and projects requiring advanced graphics fidelity. HDRP uses compute shader technology and requires compatible GPU hardware (DirectX 11/12, Metal, Vulkan).

Source: [HDRP Documentation](https://docs.unity3d.com/6000.3/Documentation/Manual/high-definition-render-pipeline.html), [HDRP Features](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/HDRP-Features.html)

## Setup

1. **New project**: Select an HDRP template
2. **Existing project**: Install via Package Manager (`com.unity.render-pipelines.high-definition`)
3. **Configuration**: Use the **Render Pipeline Wizard** to verify and fix settings
4. **Hardware**: Requires compute shader-capable GPU

## Rendering Architecture

HDRP uses a hybrid tile and cluster renderer for forward and deferred rendering of opaque and transparent GameObjects.

| Path | Description |
|---|---|
| **Forward** | Per-pixel lighting in a single pass |
| **Deferred** | G-buffer based; handles many lights efficiently |

## Material Types and Shaders

HDRP provides specialized shaders for different surface types:

| Shader | Use Case | Key Features |
|---|---|---|
| **Lit** | Default realistic surfaces | Subsurface scattering, iridescence, translucency |
| **Layered Lit** | Tiled material blending | Combines multiple tileable materials efficiently |
| **Unlit** | VFX, non-lit surfaces | Shadow matte support |
| **StackLit** | Higher quality than Lit | Simultaneous anisotropy + iridescence + coat |
| **Hair** | Hair rendering | Marschner or Kajiya Kay lighting models |
| **Fabric** | Cloth rendering | Cotton wool or silk lighting models |
| **Eye** | Eye rendering | Caustic calculation, cinematic options |
| **AxF** | Measured materials | X-Rite measured material format |
| **Terrain** | Terrain surfaces | 8 layers per draw call |

### Material Properties

HDRP materials support: opaque/transparent surfaces, premultiplied alpha, refraction, distortion, anisotropy, iridescence, metallic, subsurface scattering, tessellation, displacement, emission, and custom motion vectors.

## Lighting System

### Light Types

| Light Type | Real-time | Baked | Cookies | Color Temperature |
|---|---|---|---|---|
| Directional | Yes | Yes | Yes | Yes |
| Spot | Yes | Yes | Yes | Yes |
| Point | Yes | Yes | Yes | Yes |
| Rectangle (Area) | Yes | Yes | Yes | Yes |
| Tube (Area) | Yes | Yes | Yes | Yes |
| Disk (Area) | No | Yes | Yes | Yes |

### Advanced Lighting Features

- **Physical Light Units (PLU)**: Realistic intensity values matching real-world measurements
- **IES Profiles**: Import real-world light distribution patterns
- **Rendering Layers**: Selective per-light illumination control
- **Light Anchor**: Manipulate lights relative to Main Camera
- **Light Explorer**: Manage all scene lights from a single window

## Shadow Systems

| Feature | Description |
|---|---|
| **Shadow Cascades** | Split quality control for directional lights |
| **Contact Shadows** | Raymarching in depth buffer for fine detail shadows |
| **Micro Shadows** | Estimated from normal/AO maps |
| **Cacheable Shadow Maps** | Cache cascade, punctual, and area light shadows |
| **Dynamic Resolution** | Variable shadow resolution for punctual/area lights |
| **On-Demand Rendering** | `RequestShadowMapRendering()` for manual control |

## Ray Tracing

HDRP supports hardware ray tracing (DXR) for multiple effects:

| Feature | Notes |
|---|---|
| **Ray-Traced Ambient Occlusion** | Off-screen capable |
| **Ray-Traced Contact Shadows** | Enhanced fine-detail shadows |
| **Ray-Traced Global Illumination** | Ray Tracing or Mixed modes |
| **Ray-Traced Reflections** | Screen-space and off-screen |
| **Ray-Traced Shadows** | Directional, Point, Area lights |
| **Recursive Ray Tracing** | Multi-bounce refraction/reflection |
| **Ray-Traced Subsurface Scattering** | Skin and translucent surfaces |

**Terrain compatibility**: Ray tracing supports terrain geometry but excludes detail meshes/trees in standard mode.

## Volumetric Effects

### Fog
- Exponential fog with volumetric rendering
- Local volumetric fog using 3D texture masks or Shader Graph
- Affects both opaque and transparent surfaces

### Clouds
- **Cloud Layer**: Scattering and shadow projection
- **Volumetric Clouds**: Shadow mapping and atmospheric interaction

## Sky Systems

| System | Description |
|---|---|
| **Gradient Sky** | Three-zone color gradient |
| **HDRI Sky** | Cubemap-based environment |
| **Physically Based Sky** | Atmospheric simulation with celestial bodies |
| **Backplate** | Shape projection (Rectangle, Disc, Ellipse, Infinite) |

## Reflection and Refraction

| Feature | Description |
|---|---|
| **Reflection Probes** | Cubemap reflections with roughness |
| **Planar Reflection Probes** | Mirror/wet floor effects with smoothness filtering |
| **Screen-Space Reflection** | Depth/color buffer ray tracing |
| **Screen-Space Refraction** | Transparent materials (windows, water) |
| **Screen-Space Distortion** | Refraction-like heat haze effects |

## Global Illumination

- **Adaptive Probe Volumes**: Auto-placed light probes with per-pixel selection, reduced light leaking
- **Screen-Space Global Illumination**: Ray marching for indirect diffuse lighting
- **Lightmaps/Light Probes**: Traditional baking options

## Water System

HDRP includes a comprehensive water system:
- Multiple water presets
- Simulation-based caustics
- Underwater rendering
- Deformation and foam
- Water excluder volumes
- CPU simulation mirroring for gameplay
- Shader Graph customization

## Post-Processing and Camera

### Anti-Aliasing

| Method | Resource Impact | Notes |
|---|---|---|
| MSAA | Highest | Hardware multisampling |
| TAA | Medium | Motion-dependent temporal smoothing |
| SMAA | Low | Pattern-based edge blending |
| FXAA | Lowest | Per-pixel edge detection |

### Dynamic Resolution

Supported upscaling methods:
- Catmull-Rom interpolation
- AMD FSR 1.0
- NVIDIA DLSS
- TAA Upscaling

### Exposure

Histogram-based exposure with:
- Percentile selection
- Metering modes (texture-based and procedural)
- Pre-exposure for precision with Physical Light Units

### Camera Features
- Physically-based camera mimicking real-world properties
- Camera-relative rendering for distant scene objects
- HDR Display Output with tonemapping and ACES pipeline

## Path Tracing

- Path-traced depth of field with multi-layer transparency
- Frame accumulation via Recording API
- Subsurface scattering using random walk approach
- Anisotropic fog absorption
- Decal support
- Denoising: Optix or Intel Open Image Denoise
- Supported materials: Lit, Layered Lit, Unlit, StackLit, Fabric, AxF

## Volume System

HDRP uses Volumes for localized environmental settings and post-processing:
- Multiple volumes per scene with blending
- Effects vary by camera position (fog density, sky, exposure)
- Volume API enables runtime property modification

```csharp
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

public class HDRPVolumeControl : MonoBehaviour
{
    [SerializeField] private Volume volume;

    void SetFogDensity(float density)
    {
        if (volume.profile.TryGet<Fog>(out var fog))
        {
            fog.meanFreePath.Override(density);
        }
    }
}
```

## Custom Passes

HDRP supports Custom Pass for injecting shader/script rendering at specific points:
- Alternative viewpoint rendering
- Custom effect injection via Volume framework
- HDR Display Output control

## Programming APIs

| API | Purpose |
|---|---|
| Material Scripting API | Runtime material modification with validation |
| `HDAdditionalLightData` | Light control including PLU features |
| Shadow Update Control | `RequestShadowMapRendering()` for on-demand shadows |
| Render Graph | GPU memory optimization and pass culling |
| Volume System API | Code-based volume/component manipulation |
| Custom Pass API | Render from alternative viewpoints |

## Virtual Reality

HDRP optimizes single-pass VR rendering with full platform compatibility.

## Related Resources

- [HDRP Documentation](https://docs.unity3d.com/6000.3/Documentation/Manual/high-definition-render-pipeline.html)
- [HDRP Features](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/HDRP-Features.html)
- [Post-Processing Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/PostProcessingOverview.html)
