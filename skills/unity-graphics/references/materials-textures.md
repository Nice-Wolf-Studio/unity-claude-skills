# Materials and Textures Guide

## Materials Overview

Materials and shaders work together to define the appearance of a scene. A material references a shader and provides values for the shader's properties. Shaders are programs that run on the GPU.

Source: [Materials](https://docs.unity3d.com/6000.3/Documentation/Manual/Materials.html), [Material API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Material.html)

## Material Creation and Assignment

1. **Create**: Right-click in Project window > **Create > Material**
2. **Assign shader**: Select shader in Material Inspector dropdown
3. **Configure properties**: Set colors, textures, and values in Inspector
4. **Apply to GameObject**: Drag material onto a GameObject or assign to Renderer component's Materials array

## Material Properties API

### Key Properties

| Property | Type | Description |
|---|---|---|
| `color` | Color | Main color of the material |
| `mainTexture` | Texture | Primary texture |
| `mainTextureScale` | Vector2 | UV scale for main texture |
| `mainTextureOffset` | Vector2 | UV position offset |
| `shader` | Shader | Assigned shader reference |
| `renderQueue` | int | Render order override |
| `enableInstancing` | bool | GPU instancing toggle |
| `enabledKeywords` | LocalKeyword[] | Active shader keywords |
| `isVariant` | bool | Whether this is a Material Variant |

### Setter Methods

```csharp
material.SetColor("_BaseColor", Color.red);
material.SetFloat("_Smoothness", 0.8f);
material.SetInteger("_StencilRef", 1);
material.SetTexture("_BaseMap", myTexture);
material.SetVector("_Tiling", new Vector4(2, 2, 0, 0));
material.SetMatrix("_CustomMatrix", Matrix4x4.identity);
```

### Getter Methods

```csharp
Color col = material.GetColor("_BaseColor");
float smooth = material.GetFloat("_Smoothness");
Texture tex = material.GetTexture("_BaseMap");
Vector4 vec = material.GetVector("_Tiling");
Matrix4x4 mat = material.GetMatrix("_CustomMatrix");
```

### Array Variants

```csharp
material.SetColorArray("_Colors", colorArray);
material.SetFloatArray("_Weights", floatArray);
material.SetMatrixArray("_Matrices", matrixArray);
material.SetVectorArray("_Points", vectorArray);
```

### Property Checking

```csharp
bool has = material.HasProperty("_BaseColor");
bool hasTex = material.HasTexture("_BaseMap");
bool hasCol = material.HasColor("_BaseColor");
bool hasFloat = material.HasFloat("_Smoothness");
bool hasMat = material.HasMatrix("_CustomMatrix");
bool hasVec = material.HasVector("_Tiling");
```

### Keyword Management

```csharp
material.EnableKeyword("_EMISSION");
material.DisableKeyword("_EMISSION");
bool enabled = material.IsKeywordEnabled("_EMISSION");
```

### Shader Pass Control

```csharp
int passIndex = material.FindPass("ForwardLit");
string passName = material.GetPassName(0);
bool passEnabled = material.GetShaderPassEnabled("DepthOnly");
material.SetShaderPassEnabled("DepthOnly", false);
```

### Utility Methods

```csharp
material.CopyPropertiesFromMaterial(otherMaterial);
material.Lerp(materialA, materialB, 0.5f);  // Interpolate
int hash = material.ComputeCRC();
```

## Material Access Patterns

### Instance vs Shared Material

```csharp
Renderer renderer = GetComponent<Renderer>();

// Creates a material INSTANCE (safe, per-object)
renderer.material.color = Color.blue;

// Modifies the shared ASSET (dangerous, affects all objects using it)
// renderer.sharedMaterial.color = Color.blue;  // AVOID at runtime
```

> **Important:** `renderer.material` creates a copy on first access. This is safe but increases memory. For per-object variation without instancing, use `MaterialPropertyBlock` instead.

### MaterialPropertyBlock (Preferred for Per-Object Variation)

MaterialPropertyBlock allows setting per-object shader properties without creating material instances, preserving SRP Batcher compatibility:

```csharp
using UnityEngine;

public class MaterialPropertyBlockExample : MonoBehaviour
{
    private static readonly int BaseColorID = Shader.PropertyToID("_BaseColor");
    private MaterialPropertyBlock _propBlock;
    private Renderer _renderer;

    void Awake()
    {
        _propBlock = new MaterialPropertyBlock();
        _renderer = GetComponent<Renderer>();
    }

    public void SetColor(Color color)
    {
        _renderer.GetPropertyBlock(_propBlock);
        _propBlock.SetColor(BaseColorID, color);
        _renderer.SetPropertyBlock(_propBlock);
    }
}
```

> **Best practice:** Cache `Shader.PropertyToID()` results as static fields. String-based property access is slower.

### Set Shader Before Properties

Set the desired shader before applying property modifications. Texture and property assignments have no effect if the current shader does not support them. Once a shader is established, you can switch between shaders with compatible properties while preserving values.

```csharp
material.shader = Shader.Find("Universal Render Pipeline/Lit");
material.SetColor("_BaseColor", Color.white);
material.SetFloat("_Metallic", 0.5f);
```

## Material Variants

Material Variants inherit from a parent material, allowing overrides of specific properties while keeping others synchronized:

- Create via right-click on a material > **Create > Material Variant**
- Override only the properties that differ
- Changes to the parent automatically propagate to variants (for non-overridden properties)
- Useful for managing large material collections with shared base settings

## Pipeline-Specific Material Upgrade

When switching from Built-in to URP or HDRP, materials may render bright pink (shader incompatibility). Use the pipeline's built-in material upgrader:

- **URP**: Edit > Rendering > Materials > Convert Built-in Materials to URP
- **HDRP**: Edit > Rendering > Materials > Convert Built-in Materials to HDRP

## Common Shader Property Names by Pipeline

### URP Lit

| Property | Type | Description |
|---|---|---|
| `_BaseColor` | Color | Albedo tint |
| `_BaseMap` | Texture | Albedo texture |
| `_Metallic` | Float | Metallic value (0-1) |
| `_Smoothness` | Float | Smoothness (0-1) |
| `_BumpMap` | Texture | Normal map |
| `_BumpScale` | Float | Normal intensity |
| `_EmissionColor` | Color | Emission color |
| `_EmissionMap` | Texture | Emission texture |
| `_OcclusionMap` | Texture | AO map |
| `_OcclusionStrength` | Float | AO strength |

### Built-in Standard

| Property | Type | Description |
|---|---|---|
| `_Color` | Color | Albedo tint |
| `_MainTex` | Texture | Albedo texture |
| `_Metallic` | Float | Metallic value |
| `_Glossiness` | Float | Smoothness |
| `_BumpMap` | Texture | Normal map |

---

## Textures Overview

Textures are bitmap images applied to mesh surfaces to provide fine visual detail -- "as though printed on a rubber sheet stretched and pinned onto the mesh."

Source: [Textures](https://docs.unity3d.com/6000.3/Documentation/Manual/Textures.html)

## Texture Fundamentals

### Color Models

| Model | Description |
|---|---|
| **RGB** | Red, green, blue color channels |
| **RGBA** | RGB plus alpha channel for blending/opacity |

### Dynamic Range

| Type | Formats | Value Range |
|---|---|---|
| **LDR** (Low Dynamic Range) | PNG, JPG | 0.0 -- 1.0 |
| **HDR** (High Dynamic Range) | EXR, HDR | Extended (beyond 1.0) |

### Dimension Requirements

Textures should use **power-of-two** (POT) dimensions for optimal compression and performance:
- 32, 64, 128, 256, 512, 1024, 2048, 4096

Non-power-of-two (NPOT) textures may prevent GPU compression, increase memory usage, and reduce performance on some platforms.

## Texture Import Settings

### Texture Type

| Type | Use Case |
|---|---|
| **Default** | General-purpose diffuse/albedo textures |
| **Normal Map** | Surface normal data; Unity handles platform encoding |
| **Editor GUI and Legacy GUI** | UI textures |
| **Sprite (2D and UI)** | 2D game sprites and UI elements |
| **Cursor** | Hardware cursor textures |
| **Cookie** | Light cookie masks |
| **Lightmap** | Baked lightmap data |
| **Single Channel** | Grayscale data (masks, height maps) |

### Compression Formats

Choose format based on target platform and quality needs:

| Format Family | Platforms | Bits Per Pixel | Notes |
|---|---|---|---|
| **ASTC** | iOS, Android, WebGL 2.0+ | 0.89 -- 8 bpp | Variable block size; best quality/size tradeoff |
| **ETC/ETC2** | Android, WebGL | 4 -- 8 bpp | Standard for Android; ETC2 adds alpha support |
| **BC (DXT)** | Desktop, Console | 4 -- 8 bpp | BC1 (DXT1), BC3 (DXT5), BC5, BC7 |
| **PVRTC** | iOS (legacy) | 2 -- 4 bpp | Requires square POT textures |
| **Uncompressed** | All | 16 -- 128 bpp | Best quality; highest memory |

**Platform recommendations:**
- **Mobile (Android)**: ASTC (preferred) or ETC2
- **Mobile (iOS)**: ASTC (preferred) or PVRTC (legacy)
- **Desktop**: BC7 (best quality) or BC1/BC3 (smaller size)
- **WebGL**: ASTC or ETC2

### Key Import Settings

| Setting | Description |
|---|---|
| **Max Size** | Maximum texture dimension (downscales if larger) |
| **Format** | Compression format override |
| **Compression Quality** | Low / Normal / High |
| **Generate Mip Maps** | Create smaller versions for distance rendering |
| **Filter Mode** | Point (pixel art), Bilinear, Trilinear |
| **Wrap Mode** | Repeat, Clamp, Mirror |
| **sRGB** | Enable for color textures; disable for data (normal, mask) |
| **Read/Write Enabled** | Allow CPU access (doubles memory) |

### Anisotropic Filtering

Improves texture quality when viewed at steep angles (e.g., ground textures):
- Set **Aniso Level** in Texture Import Settings (0 = disabled, 16 = maximum)
- Force globally via **Quality Settings > Anisotropic Textures**
- Setting Aniso Level to 0 disables forced filtering for that texture

## Texture Usage Contexts

| Context | Application |
|---|---|
| **3D Models** | Mesh surface detail via Materials and Shaders |
| **2D Games** | Sprites on flat meshes |
| **GUI** | Interface elements |
| **Particles** | Smoke, flames, effects via Particle Systems |

## Optimization Best Practices

1. **Use power-of-two dimensions**: Enables compression and mipmaps
2. **Choose appropriate compression**: ASTC for mobile; BC for desktop
3. **Lower bits per pixel** reduces memory and improves GPU cache efficiency
4. **Generate mipmaps** for 3D textures viewed at varying distances
5. **Disable mipmaps** for UI/2D textures always viewed at full resolution
6. **Disable Read/Write** unless CPU access is needed (halves runtime memory)
7. **Use texture atlases** to reduce material/draw call count
8. **Set appropriate Max Size** per platform; mobile rarely needs 4096
9. **Use Crunch compression** for smaller disk size (Variable Bit Rate); memory matches underlying format
10. **sRGB off** for non-color data (normal maps, masks, height maps)

## Related Resources

- [Materials Documentation](https://docs.unity3d.com/6000.3/Documentation/Manual/Materials.html)
- [Textures Documentation](https://docs.unity3d.com/6000.3/Documentation/Manual/Textures.html)
- [Material Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Material.html)
