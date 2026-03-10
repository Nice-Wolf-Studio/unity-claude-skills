# URP (Universal Render Pipeline) Guide

## Overview

The Universal Render Pipeline (URP) is a prebuilt Scriptable Render Pipeline made by Unity for creating optimized graphics across a range of platforms, from mobile to high-end consoles and PCs.

Source: [URP Documentation](https://docs.unity3d.com/6000.3/Documentation/Manual/universal-render-pipeline.html)

## Setup

1. **New project**: Select a URP template when creating a new project
2. **Existing project**: Install the URP package via Package Manager (`com.unity.render-pipelines.universal`)
3. **Configuration**: Create a URP Asset (Universal Render Pipeline Asset) and assign it in **Edit > Project Settings > Graphics**

## Rendering Paths

URP supports multiple rendering paths:

| Path | Description | Use Case |
|---|---|---|
| **Forward** | Single pass per light; simpler | Mobile, lower-end hardware |
| **Forward+** | Improved forward rendering with better light handling | Mid-range hardware, many lights |
| **Deferred** | G-buffer based; handles many lights efficiently | Desktop/console, many dynamic lights |

## Anti-Aliasing

URP provides four anti-aliasing methods:

| Method | Description | Performance Impact |
|---|---|---|
| **FXAA** | Fast Approximate Anti-Aliasing; per-pixel edge detection | Very low |
| **SMAA** | Subpixel Morphological Anti-Aliasing; pattern-based | Low |
| **TAA** | Temporal Anti-Aliasing; uses motion vectors across frames | Medium |
| **MSAA** | Multi-Sample Anti-Aliasing; hardware-based supersampling | High |

## SRP Batcher

The SRP Batcher is enabled by default in URP. It reduces CPU time for draw calls by minimizing render-state changes between draw calls. Material data persists in GPU memory, and a dedicated code path manages per-object GPU constant buffers.

**Best practices:**
- Use as few shader variants as possible
- Multiple materials sharing the same shader variant batch efficiently
- SRP Batcher replaces the need for dynamic batching in most cases

Source: [SRP Batcher](https://docs.unity3d.com/6000.3/Documentation/Manual/SRPBatcher.html)

## Renderer Features

Renderer Features allow injecting custom rendering logic into the URP rendering pipeline. They extend `ScriptableRendererFeature` and use `ScriptableRenderPass` for the actual rendering work.

### Creating a Custom Renderer Feature

```csharp
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class MyRendererFeature : ScriptableRendererFeature
{
    class MyRenderPass : ScriptableRenderPass
    {
        public override void Execute(
            ScriptableRenderContext context,
            ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("MyRenderPass");
            // Custom rendering commands here
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    MyRenderPass m_RenderPass;

    public override void Create()
    {
        m_RenderPass = new MyRenderPass();
        // Configure injection point
        m_RenderPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    public override void AddRenderPasses(
        ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }
}
```

### Injection Points (RenderPassEvent)

| Event | When |
|---|---|
| `BeforeRendering` | Before any rendering |
| `BeforeRenderingShadows` | Before shadow maps |
| `AfterRenderingShadows` | After shadow maps |
| `BeforeRenderingOpaques` | Before opaque geometry |
| `AfterRenderingOpaques` | After opaque geometry |
| `BeforeRenderingSkybox` | Before skybox |
| `AfterRenderingSkybox` | After skybox |
| `BeforeRenderingTransparents` | Before transparent geometry |
| `AfterRenderingTransparents` | After transparent geometry |
| `AfterRendering` | After all rendering |
| `BeforeRenderingPostProcessing` | Before post-processing |
| `AfterRenderingPostProcessing` | After post-processing |

### Adding a Renderer Feature

1. Select your URP Renderer Asset (e.g., `ForwardRenderer`)
2. In the Inspector, click **Add Renderer Feature**
3. Select your custom feature from the list

## 2D Renderer

URP includes a dedicated 2D Renderer for 2D games:

- Optimized sprite rendering pipeline
- 2D lighting system (Sprite Lit, Sprite Unlit shaders)
- 2D shadow support
- Designed for tilemaps and sprite-based workflows

**Setup:**
1. Create a URP Asset with 2D Renderer
2. Assign the 2D Renderer to the URP Asset's Renderer List
3. Use 2D-specific shaders: `Sprite-Lit-Default`, `Sprite-Unlit-Default`

## Post-Processing in URP

URP includes built-in post-processing through the Volume system:

1. Create a **Volume** component (Global or Local)
2. Assign or create a **Volume Profile**
3. Add effect overrides to the profile (Bloom, Color Grading, Vignette, etc.)
4. Enable post-processing on the Camera component

```csharp
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PostProcessController : MonoBehaviour
{
    [SerializeField] private Volume volume;

    void Start()
    {
        if (volume.profile.TryGet<Bloom>(out var bloom))
        {
            bloom.intensity.Override(1.5f);
            bloom.threshold.Override(0.9f);
        }
    }
}
```

## URP Shader Properties

Common URP Lit shader properties for scripting:

| Property Name | Type | Description |
|---|---|---|
| `_BaseColor` | Color | Albedo tint color |
| `_BaseMap` | Texture | Albedo texture |
| `_Metallic` | Float | Metallic value (0-1) |
| `_Smoothness` | Float | Smoothness value (0-1) |
| `_BumpMap` | Texture | Normal map |
| `_BumpScale` | Float | Normal map scale |
| `_EmissionColor` | Color | Emission color |
| `_EmissionMap` | Texture | Emission texture |
| `_OcclusionMap` | Texture | Ambient occlusion map |
| `_OcclusionStrength` | Float | AO strength (0-1) |

## Quality Configuration

Configure per-quality-level URP Assets for scalable rendering:

- Assign different URP Assets to Quality Levels in **Edit > Project Settings > Quality**
- Each asset can have different shadow resolution, MSAA, HDR, and rendering settings
- Use `QualitySettings.SetQualityLevel()` to switch at runtime

## Related Resources

- [URP Documentation](https://docs.unity3d.com/6000.3/Documentation/Manual/universal-render-pipeline.html)
- [SRP Batcher](https://docs.unity3d.com/6000.3/Documentation/Manual/SRPBatcher.html)
- [Post-Processing Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/PostProcessingOverview.html)
