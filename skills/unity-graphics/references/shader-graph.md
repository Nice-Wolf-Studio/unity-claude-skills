# Shader Graph Guide

## Overview

Shader Graph enables building shaders visually by creating and connecting nodes in a graph framework instead of writing code. Changes are reflected with instant feedback. Shader Graph 17.0.4 is included automatically with URP or HDRP.

Source: [Shader Graph](https://docs.unity3d.com/6000.3/Documentation/Manual/shader-graph.html), [Shader Graph 17.0](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/index.html)

## Render Pipeline Compatibility

| Pipeline | Supported |
|---|---|
| URP | Yes |
| HDRP | Yes |
| Built-in Render Pipeline | Yes |
| Custom SRP | No |

## Creating a Shader Graph

1. In the Project window, right-click and select **Create > Shader Graph**
2. Choose a target: URP, HDRP, or Built-in
3. Select a graph type (Lit, Unlit, etc.)
4. Double-click the asset to open the Shader Graph editor
5. Create nodes, connect them to the Master Stack outputs
6. Save to compile the shader

### Applying to a Material

1. Create a new Material
2. In the Material Inspector, set the Shader to your Shader Graph asset
3. Configure exposed properties in the Inspector
4. Assign the Material to a Renderer component on a GameObject

## Node Categories

Shader Graph organizes nodes into functional categories:

| Category | Purpose | Examples |
|---|---|---|
| **Artistic** | Color manipulation, blending | Blend, Contrast, Saturation, White Balance |
| **Channel** | Component manipulation | Split, Combine, Swizzle, Flip |
| **Input** | Data sources | Texture, Color, Time, Position, UV, Screen |
| **Math** | Mathematical operations | Add, Multiply, Lerp, Clamp, Step, Smoothstep |
| **Procedural** | Generated patterns | Noise (Gradient, Simple, Voronoi), Checkerboard, Shape |
| **UV** | UV coordinate manipulation | Tiling and Offset, Rotate, Polar Coordinates, Triplanar |
| **Utility** | Helpers | Preview, Custom Function, Sub Graph, Keyword |
| **Master Stack** | Final output configuration | Vertex and Fragment stages |

## Master Stack

The Master Stack defines the final shader output. It has two stages:

- **Vertex Stage**: Modify vertex position, normal, and tangent
- **Fragment Stage**: Define surface appearance (albedo, normal, metallic, smoothness, emission, alpha)

### Common Master Stack Targets

**URP Lit:**
- Base Color, Normal, Metallic, Smoothness, Emission, Ambient Occlusion, Alpha

**URP Unlit:**
- Base Color, Alpha

**HDRP Lit:**
- Base Color, Normal, Metallic, Smoothness, Emission, Ambient Occlusion, Specular Color, Coat Mask, Alpha

**HDRP Unlit:**
- Color, Emission, Alpha

## Common Graph Patterns

### Dissolve Effect
1. Sample a Noise texture (Gradient Noise or Simple Noise node)
2. Compare noise output against a `_DissolveAmount` float property using a Step node
3. Connect result to Alpha output
4. Optionally add emission at dissolve edge using Smoothstep

### Scrolling UV
1. Use a Time node
2. Multiply by a `_ScrollSpeed` Vector2 property
3. Add to UV coordinates via Tiling and Offset node
4. Use modified UVs for texture sampling

### Fresnel / Rim Lighting
1. Use a Fresnel Effect node (takes Normal and View Direction)
2. Multiply by a `_RimColor` Color property
3. Add to Emission output

### Triplanar Mapping
1. Use a Triplanar node for world-space texture projection
2. Useful for terrain or objects without proper UVs
3. Configure Blend sharpness for edge transitions

### World-Space Mask
1. Use Position node (World space)
2. Split to isolate Y component
3. Use Smoothstep or Remap to create a height-based mask
4. Blend between two textures/colors using the mask

## Custom Function Node

The Custom Function node injects custom HLSL code into Shader Graphs for fine-grained optimization.

### String Mode

The graph auto-generates the function wrapper. Use `$precision` token for half/float:

```hlsl
// String mode body (typed directly into node)
Out = A * B + 0.5;
```

### File Mode

Reference an external `.hlsl` file. Requirements:
- Include `#ifndef` / `#define` guards with unique identifiers
- Add precision suffixes to function names (`_float` or `_half`)
- Match function arguments to node input/output names

```hlsl
//UNITY_SHADER_NO_UPGRADE
#ifndef MYHLSLINCLUDE_INCLUDED
#define MYHLSLINCLUDE_INCLUDED

void MyFunction_float(float3 A, float B, out float3 Out)
{
    Out = A + B;
}
#endif //MYHLSLINCLUDE_INCLUDED
```

### Uniform Variables in Custom Functions

Define shared data outside the function scope. Set via `Shader.SetGlobalMatrix()` (global only, not per-material):

```hlsl
float4x4 _MyMatrix;
void MyFunction_float(float3 A, float B, out float3 Out)
{
    A = mul(float4(A, 0.0), _MyMatrix).rgb;
    Out = A + B;
}
```

### Multiple Functions

Call helper functions from within the main function:

```hlsl
float3 MyOtherFunction_float(float3 In)
{
    return In * In;
}

void MyFunction_float(float3 A, float B, out float3 Out)
{
    A = MyOtherFunction_float(A);
    Out = A + B;
}
```

### Pipeline-Specific Code in Custom Functions

Use conditional compilation to safely reference pipeline libraries:

```hlsl
#ifdef SHADERGRAPH_PREVIEW
    half3 color = half3(0,0,0);
#else
    #if defined(UNIVERSAL_PIPELINE_CORE_INCLUDED)
        half4 shadowCoord = TransformWorldToShadowCoord(WorldPosition);
        Light mainLight = GetMainLight(shadowCoord);
        half3 color = mainLight.color;
    #else
        half3 color = half3(0, 0, 0);
    #endif
#endif
```

**Pipeline detection defines:**

| Define | Pipeline |
|---|---|
| `BUILTIN_PIPELINE_CORE_INCLUDED` | Built-in Render Pipeline |
| `UNIVERSAL_PIPELINE_CORE_INCLUDED` | URP |
| `UNITY_HEADER_HD_INCLUDED` | HDRP |
| `SHADERGRAPH_PREVIEW` | Shader Graph preview window |

### Texture Wire Support (v10.3+)

Use dedicated structs for texture handling in Custom Function nodes:

| Struct | Purpose |
|---|---|
| `UnityTexture2D` | Standard 2D texture |
| `UnityTexture2DArray` | Texture array |
| `UnityTexture3D` | 3D/volume texture |
| `UnityTextureCube` | Cubemap texture |
| `UnitySamplerState` | Sampler configuration |

Access texture metadata: `myInputTex.samplerstate`, `myInputTex.texelSize`

## Sub Graphs

Sub Graphs are reusable shader graph assets:

1. Create via **Create > Shader Graph > Sub Graph**
2. Define inputs and outputs on the Sub Graph
3. Build the node network inside
4. Use in other graphs via the Sub Graph node
5. Convert Custom Function nodes to Sub Graphs via right-click menu

## Keywords

Shader Graph supports Keywords for creating shader variants:

- **Boolean**: On/Off toggle
- **Enum**: Multiple named options
- **Built-in**: Platform or pipeline keywords

Keywords generate shader variants. Minimize keyword usage to reduce variant count and build times.

## Best Practices

- **Minimize shader variants**: Each keyword combination creates a variant; strip unused ones
- **Use Sub Graphs** for commonly reused node patterns
- **Prefer Custom Function File mode** over String mode for complex HLSL (better version control)
- **Test across target platforms**: Visual results may differ between rendering backends
- **Use Preview nodes** to debug intermediate values in the graph
- **Expose only necessary properties**: Unexposed properties are compiled as constants (faster)

## Related Resources

- [Shader Graph Documentation](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/index.html)
- [Custom Function Node](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/Custom-Function-Node.html)
- [Shader Introduction](https://docs.unity3d.com/6000.3/Documentation/Manual/shader-introduction.html)
