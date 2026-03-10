# Sprites and Sprite Atlas Reference

## Sprite Import and Configuration

Sprites are "a type of 2D asset you can use in your Unity project" functioning as 2D graphic objects with specialized import and management.

### Import Settings

When importing a texture as a sprite, set **Texture Type** to **Sprite (2D and UI)** in the Inspector. Key import settings:

| Setting | Description |
|---------|-------------|
| **Sprite Mode** | Single (one sprite), Multiple (spritesheet), or Polygon |
| **Pixels Per Unit** | Number of pixels that correspond to one Unity unit (default: 100) |
| **Mesh Type** | Tight (follows sprite outline) or Full Rect (simple quad) |
| **Pivot** | Anchor point for the sprite (Center, Top Left, Bottom, Custom, etc.) |
| **Generate Physics Shape** | Auto-generate physics collision shape from sprite outline |
| **Wrap Mode** | Clamp, Repeat, Mirror, etc. |
| **Filter Mode** | Point (pixel-perfect), Bilinear, or Trilinear |

For **pixel art**, always use:
- Filter Mode: **Point (no filter)**
- Compression: **None**
- Pixels Per Unit matching your pixel density

### Sprite Slicing

Use the **Sprite Editor** window (Window > 2D > Sprite Editor) to slice spritesheets:

- **Automatic**: Unity detects individual sprites based on transparency
- **Grid By Cell Size**: Slice by fixed pixel dimensions (e.g., 16x16, 32x32)
- **Grid By Cell Count**: Slice into a specified number of rows and columns
- **Manual**: Click and drag to define individual sprite regions

After slicing, each sub-sprite gets a unique name (e.g., `spritesheet_0`, `spritesheet_1`).

### 9-Slicing

9-slicing enables sprites to scale without distorting corners and edges. Set up via the Sprite Editor by defining the border values (Left, Right, Top, Bottom in pixels). Then use SpriteRenderer with **Sliced** or **Tiled** draw mode.

```csharp
// Configure a 9-sliced sprite at runtime
SpriteRenderer sr = GetComponent<SpriteRenderer>();
sr.drawMode = SpriteDrawMode.Sliced;
sr.size = new Vector2(3f, 2f); // Resize without distorting borders
```

### Sprite Masking

Use **SpriteMask** component to hide or reveal parts of sprites:

```csharp
// Create a sprite mask programmatically
GameObject maskObj = new GameObject("SpriteMask");
SpriteMask mask = maskObj.AddComponent<SpriteMask>();
mask.sprite = maskSprite;

// Configure renderer to respond to the mask
SpriteRenderer sr = GetComponent<SpriteRenderer>();
sr.maskInteraction = SpriteMaskInteraction.VisibleInsideMask;
// Or: SpriteMaskInteraction.VisibleOutsideMask
```

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/sprite-landing.html

## SpriteRenderer API

The SpriteRenderer is "A component that renders a Sprite" using position, rotation, and scale from the Transform component.

### All Key Properties

```csharp
SpriteRenderer sr = GetComponent<SpriteRenderer>();

// Core rendering
sr.sprite = mySprite;                    // Sprite asset to display
sr.color = Color.white;                  // Tint color (white = no tint)
sr.flipX = false;                        // Horizontal flip
sr.flipY = false;                        // Vertical flip

// Draw mode
sr.drawMode = SpriteDrawMode.Simple;     // Simple, Sliced, or Tiled
sr.size = new Vector2(1f, 1f);           // Dimensions (Sliced/Tiled only)
sr.tileMode = SpriteTileMode.Continuous; // Continuous or Adaptive
sr.adaptiveModeThreshold = 0.5f;         // Stretch threshold before tiling

// Sorting
sr.sortingLayerName = "Default";         // Sorting layer name
sr.sortingLayerID = 0;                   // Sorting layer ID (faster)
sr.sortingOrder = 0;                     // Order within sorting layer
sr.spriteSortPoint = SpriteSortPoint.Center; // Center or Pivot

// Masking
sr.maskInteraction = SpriteMaskInteraction.None;
```

### Sprite Change Callbacks

```csharp
// Register for notifications when sprite changes
SpriteRenderer sr = GetComponent<SpriteRenderer>();
sr.RegisterSpriteChangeCallback(OnSpriteChanged);

void OnSpriteChanged(SpriteRenderer renderer)
{
    Debug.Log($"Sprite changed to: {renderer.sprite.name}");
}

// Cleanup
void OnDestroy()
{
    sr.UnregisterSpriteChangeCallback(OnSpriteChanged);
}
```

### Draw Mode Examples

```csharp
// Simple mode - uniform scaling
sr.drawMode = SpriteDrawMode.Simple;
// Scale via Transform only

// Sliced mode - 9-slice scaling (sprite must have border defined)
sr.drawMode = SpriteDrawMode.Sliced;
sr.size = new Vector2(5f, 3f);

// Tiled mode - tiles the center section
sr.drawMode = SpriteDrawMode.Tiled;
sr.size = new Vector2(10f, 2f);
sr.tileMode = SpriteTileMode.Adaptive;
sr.adaptiveModeThreshold = 0.5f;
```

Source: https://docs.unity3d.com/6000.3/Documentation/ScriptReference/SpriteRenderer.html

## Sprite Atlas

A Sprite Atlas "packs several sprite textures tightly together within a single texture known as an atlas" to reduce draw calls.

### Creating a Sprite Atlas

1. **Assets > Create > 2D > Sprite Atlas** (creates `.spriteatlas` file)
2. In the Inspector, add sprites or folders to **Objects For Packing**
3. Configure packing settings
4. Click **Pack Preview** to see the packed result

### Sprite Atlas Properties

| Property | Default | Description |
|----------|---------|-------------|
| **Type** | Master | Master or Variant. Variant references a Master and applies a scale factor |
| **Include in Build** | Enabled | Pack and include in the build |
| **Allow Rotation** | Enabled | Rotate sprites for denser packing. Disable for Canvas UI |
| **Tight Packing** | Enabled | Use sprite outlines instead of rectangles |
| **Padding** | 4 | Pixel buffer between packed sprites |
| **Read/Write Enabled** | Disabled | Allow CPU access to texture data (doubles memory) |
| **Generate Mip Maps** | Disabled | Generate mipmaps for the atlas texture |
| **sRGB** | Enabled | Store in gamma space |
| **Filter Mode** | Bilinear | Texture filtering (overrides individual sprite settings) |

### Runtime Atlas API

```csharp
using UnityEngine;
using UnityEngine.U2D;

public class AtlasHelper : MonoBehaviour
{
    [SerializeField] private SpriteAtlas characterAtlas;

    // Get a single sprite by name
    public Sprite GetSprite(string spriteName)
    {
        return characterAtlas.GetSprite(spriteName);
    }

    // Get all sprites from the atlas
    public Sprite[] GetAllSprites()
    {
        Sprite[] sprites = new Sprite[characterAtlas.spriteCount];
        characterAtlas.GetSprites(sprites);
        return sprites;
    }
}
```

### Late Binding (On-Demand Loading)

Late binding lets you load atlases on demand rather than at startup. Useful for Addressables or AssetBundle workflows.

```csharp
using UnityEngine;
using UnityEngine.U2D;

public class AtlasLateBinder : MonoBehaviour
{
    void OnEnable()
    {
        SpriteAtlasManager.atlasRequested += OnAtlasRequested;
    }

    void OnDisable()
    {
        SpriteAtlasManager.atlasRequested -= OnAtlasRequested;
    }

    void OnAtlasRequested(string atlasTag, System.Action<SpriteAtlas> callback)
    {
        // Load from Resources, Addressables, or AssetBundle
        SpriteAtlas atlas = Resources.Load<SpriteAtlas>(atlasTag);
        if (atlas != null)
        {
            callback(atlas);
        }
        else
        {
            Debug.LogError($"Sprite Atlas not found: {atlasTag}");
        }
    }
}
```

### Atlas Best Practices

- Group sprites that appear together in the same scene into one atlas
- Keep atlas texture size under 2048x2048 for mobile, 4096x4096 for desktop
- Use Variant atlases with lower scale for low-end platforms
- Disable **Allow Rotation** for sprites used in Canvas UI elements
- Disable **Read/Write** unless you need CPU texture access (saves memory)
- Use **Tight Packing** for irregularly shaped sprites to maximize density
- Set appropriate **Padding** (4px default) to prevent bleeding between sprites

### Common Patterns

```csharp
// Animated sprite from atlas
public class AtlasAnimator : MonoBehaviour
{
    [SerializeField] private SpriteAtlas atlas;
    [SerializeField] private string spriteBaseName = "walk_";
    [SerializeField] private int frameCount = 8;
    [SerializeField] private float frameRate = 12f;

    private SpriteRenderer spriteRenderer;
    private Sprite[] frames;
    private float timer;
    private int currentFrame;

    void Start()
    {
        spriteRenderer = GetComponent<SpriteRenderer>();
        frames = new Sprite[frameCount];
        for (int i = 0; i < frameCount; i++)
        {
            frames[i] = atlas.GetSprite($"{spriteBaseName}{i}");
        }
    }

    void Update()
    {
        timer += Time.deltaTime;
        if (timer >= 1f / frameRate)
        {
            timer -= 1f / frameRate;
            currentFrame = (currentFrame + 1) % frameCount;
            spriteRenderer.sprite = frames[currentFrame];
        }
    }
}
```

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/atlas/atlas-landing.html
Source: https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/atlas/sprite-atlas-reference.html
