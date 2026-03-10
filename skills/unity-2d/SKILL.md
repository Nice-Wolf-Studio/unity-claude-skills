---
name: unity-2d
description: >
  Unity 6 2D game development guide. Use when building 2D games, working with sprites, sprite atlas, SpriteRenderer, tilemaps, 2D physics (Rigidbody2D, Collider2D), 2D lighting, sorting layers, or sorting groups. Based on Unity 6.3 LTS documentation.
---

# Unity 2D Development

## 2D Project Setup

Unity supports dedicated 2D project creation. When starting a 2D project:

- Select the **2D** template (or **2D (URP)** for 2D lighting support) when creating a new project
- The 2D template auto-installs required packages: **2D Sprite**, **2D Tilemap Editor**, **2D Animation**
- The Scene view defaults to orthographic (top-down XY plane)
- The camera is set to Orthographic projection by default
- Imported images default to Sprite (2D and UI) texture type

Core 2D subsystems from the docs:
- **Sprites**: "2D graphic objects" -- the foundation for 2D games
- **Tilemaps**: "A GameObject that allows you to quickly create 2D levels using tiles and a grid overlay"
- **2D Physics**: Dedicated physics system with 2D-optimized components
- **2D Rendering in URP**: 2D lights, lighting effects, and pixelated visual styles

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/Unity2D.html

## Sprites and SpriteRenderer

### Sprite Assets

Sprites are "a type of 2D asset you can use in your Unity project." They function as 2D graphic objects with specialized import and management features. The 2D Sprite package must be installed (included with 2D templates).

Key sprite capabilities:
- Import sprites or spritesheets from textures
- Use the **Sprite Editor** to cut sprites from textures (slicing)
- Apply cropping to remove transparent areas
- Create collision geometry for sprite physics
- **9-slicing** for reusing sprites at various sizes
- **Masking** to hide or reveal parts of a sprite or group of sprites

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/sprite-landing.html

### SpriteRenderer Component

The SpriteRenderer component controls how sprites display in scenes. Key properties:

| Property | Description |
|----------|-------------|
| `sprite` | The Sprite asset to render |
| `color` | Tint color applied to the sprite (default: white = no tint) |
| `flipX` / `flipY` | Flip the sprite along an axis without moving the Transform |
| `drawMode` | Simple, Sliced, or Tiled |
| `size` | Dimensions when using Sliced or Tiled draw modes |
| `sortingLayerName` | Name of the renderer's sorting layer |
| `sortingOrder` | Priority within a sorting layer (lower renders first) |
| `maskInteraction` | None, Visible Inside Mask, or Visible Outside Mask |
| `spriteSortPoint` | Center or Pivot -- determines sort distance from camera |

**Draw Modes:**
- **Simple** (default): Uniformly scales the entire sprite
- **Sliced**: For 9-sliced sprites; scales according to 9-slice regions using Width/Height
- **Tiled**: For 9-sliced sprites; tiles the middle section. Tile Mode options: Continuous (even tiling) or Adaptive (stretches until threshold, then tiles)

**Default material**: `Sprite-Lit-Default` (customizable via Material picker)

```csharp
// SpriteRenderer basic usage
SpriteRenderer sr = GetComponent<SpriteRenderer>();
sr.sprite = newSprite;
sr.color = Color.red;
sr.flipX = true;
sr.flipY = true;
sr.sortingLayerName = "Foreground";
sr.sortingOrder = 5;
```

See `references/sprites-and-atlas.md` for draw mode examples, sprite masking, and change callbacks.

Source: https://docs.unity3d.com/6000.3/Documentation/ScriptReference/SpriteRenderer.html

## Sprite Atlas

A Sprite Atlas is "a utility that packs several sprite textures tightly together within a single texture known as an atlas." This reduces draw calls -- Unity uses one draw call for the atlas instead of separate calls per sprite.

**Create**: Assets > Create > 2D > Sprite Atlas (generates `.spriteatlas` file)

### Sprite Atlas Properties

| Property | Description |
|----------|-------------|
| **Type** | Master (default) or Variant |
| **Include in Build** | Include in current build (default: enabled) |
| **Allow Rotation** | Rotate sprites when packing to maximize density (default: enabled). Disable for Canvas UI |
| **Tight Packing** | Use sprite outlines instead of rectangles for denser packing (default: enabled) |
| **Padding** | Buffer space between sprites (default: 4 pixels) |
| **Read/Write Enabled** | Allow script access to texture data (doubles memory) |
| **Generate Mip Maps** | Enable mipmaps for the atlas |
| **Filter Mode** | Controls texture filtering, overrides individual sprite settings |
| **Objects For Packing** | List of sprites/folders to pack into the atlas |

**Runtime API**: "You can use the Sprite Atlas API to control loading the Sprite Atlases at your project's runtime."

```csharp
// Load a sprite from a SpriteAtlas at runtime
using UnityEngine;
using UnityEngine.U2D;

public class AtlasLoader : MonoBehaviour
{
    [SerializeField] private SpriteAtlas atlas;
    private SpriteRenderer spriteRenderer;

    void Start()
    {
        spriteRenderer = GetComponent<SpriteRenderer>();
        Sprite sprite = atlas.GetSprite("player_idle");
        spriteRenderer.sprite = sprite;
    }
}
```

**Late binding**: Subscribe to `SpriteAtlasManager.atlasRequested` to load atlases on demand (for Addressables/AssetBundle workflows). See `references/sprites-and-atlas.md` for full late binding example.

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/atlas/atlas-landing.html

## Tilemap System

Tilemaps allow rapid 2D level creation using tiles and a grid overlay. The Tilemap component "stores and manages Tile Assets" and "transfers the required information from the tiles placed on it to other related components such as the Tilemap Renderer and the Tilemap Collider 2D."

### Tilemap Component Properties

| Property | Description |
|----------|-------------|
| **Animation Frame Rate** | Playback speed multiplier for tile animations |
| **Color** | Tint applied to all tiles (default: white) |
| **Tile Anchor** | Offset for tile anchor positions (measured in cells) |
| **Orientation** | XY, XZ, YX, YZ, ZX, ZY, or Custom |

### TilemapRenderer Modes

| Mode | Description |
|------|-------------|
| **Chunk** | Groups tiles by location/texture for batching. Best rendering performance |
| **Individual** | Renders each tile separately. Allows interaction with other renderers and custom sorting |
| **SRP Batch** | Compatible with URP 15+. Groups tiles with sequential batching |

Additional TilemapRenderer properties:
- **Sort Order**: Direction tiles are sorted during rendering
- **Detect Chunk Culling Bounds**: Auto or Manual (prevents sprite clipping)
- **Material**: Material for rendering sprite textures
- **Mask Interaction**: None, Visible Inside Mask, or Visible Outside Mask
- **Sorting Layer** / **Order in Layer**: Render priority controls

### Tilemap Scripting API

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;

Tilemap tilemap = GetComponent<Tilemap>();

// Single tile operations
tilemap.SetTile(new Vector3Int(x, y, 0), tile);      // Place tile
tilemap.SetTile(new Vector3Int(x, y, 0), null);       // Remove tile
TileBase t = tilemap.GetTile(new Vector3Int(x, y, 0)); // Read tile

// Batch operations (faster than individual SetTile in loops)
tilemap.SetTiles(positionsArray, tilesArray);
tilemap.BoxFill(pos, tile, startX, endX, startY, endY);
tilemap.FloodFill(pos, tile);
tilemap.SwapTile(oldTile, newTile);

// Coordinate conversion
Vector3 worldPos = tilemap.CellToWorld(cellPos);
Vector3Int cellPos = tilemap.WorldToCell(worldPosition);

// Bounds management -- ALWAYS call after procedural generation
tilemap.CompressBounds();
BoundsInt bounds = tilemap.cellBounds;

// Clear
tilemap.ClearAllTiles();
tilemap.RefreshAllTiles();
```

Key properties: `cellBounds`, `localBounds`, `size`, `origin`, `animationFrameRate`
Key events: `tilemapTileChanged`, `tilemapPositionsChanged`, `loopEndedForTileAnimation`

See `references/tilemaps.md` for procedural generation examples, Rule Tiles, and TilemapCollider2D setup.

Source: https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Tilemaps.Tilemap.html

## 2D Physics Overview

Unity's 2D physics system provides optimized components for 2D interactions. "Unity's physics system lets you handle 2D physics to make use of optimizations available with 2D."

### Core Components

| Component | Description |
|-----------|-------------|
| **Rigidbody2D** | "A component that allows a GameObject to be affected by simulated gravity and other forces" |
| **Collider2D** | "An invisible shape that is used to handle physical collisions for an object" |
| **Physics Material 2D** | Controls friction and bounce between colliding 2D physics objects |
| **Constant Force 2D** | Adds constant force or torque to GameObjects with a Rigidbody |
| **Effectors 2D** | Control forces when GameObject colliders are in contact |
| **2D Joints** | Dynamic connections between Rigidbody components allowing constrained movement |

### Rigidbody2D Key Properties

| Property | Description |
|----------|-------------|
| `bodyType` | Dynamic, Kinematic, or Static |
| `linearVelocity` | Rate of position change (world units/second) |
| `angularVelocity` | Rotation speed (degrees/second) |
| `mass` | Rigidbody weight |
| `gravityScale` | Degree of gravity influence |
| `linearDamping` | Linear velocity resistance |
| `angularDamping` | Angular velocity resistance |
| `constraints` | Freeze position/rotation on axes |
| `collisionDetectionMode` | Discrete or Continuous |
| `interpolation` | None, Interpolate, or Extrapolate |

### Rigidbody2D Key Methods

```csharp
Rigidbody2D rb = GetComponent<Rigidbody2D>();

// Apply forces
rb.AddForce(Vector2.up * 10f);
rb.AddForce(Vector2.right * 5f, ForceMode2D.Impulse);
rb.AddForceAtPosition(force, position);
rb.AddTorque(15f);

// Move (use in FixedUpdate for physics-safe movement)
rb.MovePosition(rb.position + velocity * Time.fixedDeltaTime);
rb.MoveRotation(rb.rotation + rotationSpeed * Time.fixedDeltaTime);

// Query
rb.Cast(direction, results, distance);
rb.ClosestPoint(worldPoint);
rb.Distance(otherCollider);
rb.GetContacts(contacts);
rb.IsAwake();
rb.IsSleeping();
```

### Physics2D Static Methods (Queries)

```csharp
// Raycast
RaycastHit2D hit = Physics2D.Raycast(origin, direction, distance, layerMask);
RaycastHit2D[] hits = Physics2D.RaycastAll(origin, direction);

// Shape casts
RaycastHit2D boxHit = Physics2D.BoxCast(origin, size, angle, direction, distance);
RaycastHit2D circleHit = Physics2D.CircleCast(origin, radius, direction, distance);

// Overlap detection
Collider2D col = Physics2D.OverlapCircle(point, radius, layerMask);
Collider2D[] cols = Physics2D.OverlapCircleAll(point, radius);
Collider2D boxCol = Physics2D.OverlapBox(point, size, angle, layerMask);
Collider2D pointCol = Physics2D.OverlapPoint(point, layerMask);

// Utilities
float dist = Physics2D.Distance(colliderA, colliderB).distance;
bool touching = Physics2D.IsTouching(colliderA, colliderB);
```

```csharp
// 2D platformer: ground check + jump + horizontal movement
Rigidbody2D rb = GetComponent<Rigidbody2D>();

// In Update: ground check and jump
bool isGrounded = Physics2D.OverlapCircle(groundCheck.position, 0.2f, groundLayer);
// Note: Uses legacy Input Manager for simplicity. See unity-input for the new Input System.
if (Input.GetButtonDown("Jump") && isGrounded)
    rb.AddForce(Vector2.up * jumpForce, ForceMode2D.Impulse);

// In FixedUpdate: horizontal movement (preserves vertical velocity)
float move = Input.GetAxisRaw("Horizontal");
rb.linearVelocity = new Vector2(move * moveSpeed, rb.linearVelocity.y);
```

Source: https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Rigidbody2D.html
Source: https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics2D.html

## 2D Lighting (URP)

2D Lighting requires the **Universal Render Pipeline (URP)** with a **2D Renderer**. Use the 2D (URP) template or configure URP manually.

### Light 2D Types

| Type | Description |
|------|-------------|
| **Global** | Illuminates all objects on target sorting layers. Cannot use normal maps |
| **Freeform** | Custom-shaped light defined by editable vertices |
| **Sprite** | Uses a sprite texture to define light shape |
| **Spot** | Cone-shaped light with direction and angle |
| **Point** | Emits light in all directions from a point |

### Light 2D Properties

| Property | Description |
|----------|-------------|
| **Color** | Light color |
| **Intensity** | Brightness multiplier (can exceed 1 to overbrighten sprites) |
| **Light Order** | Render queue position (lower renders first) |
| **Overlap Operation** | Additive (pixel values added) or Alpha Blend |
| **Target Sorting Layers** | Lights only illuminate sprites on selected sorting layers |
| **Distance** | Perceived distance between light and surface |
| **Volume Opacity** | Volumetric lighting visibility (0-1) |
| **Shadow Intensity** | How much Shadow Caster 2Ds block light (0-1) |
| **Normal Maps** | Supported on non-global light types |

```csharp
using UnityEngine;
using UnityEngine.Rendering.Universal;

public class DayNightCycle : MonoBehaviour
{
    [SerializeField] private Light2D globalLight;
    [SerializeField] private Color dayColor = Color.white;
    [SerializeField] private Color nightColor = new Color(0.1f, 0.1f, 0.3f);
    [SerializeField] private float cycleDuration = 60f;

    void Update()
    {
        float t = Mathf.PingPong(Time.time / cycleDuration, 1f);
        globalLight.color = Color.Lerp(dayColor, nightColor, t);
        globalLight.intensity = Mathf.Lerp(1f, 0.3f, t);
    }
}
```

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/urp/2d-light-properties-explained.html

## Sorting Layers and Order

"Sorting Groups allow you to group GameObjects with Sprite Renderers together, and control the order in which they render their sprites." Unity treats all Sprite Renderers within the same Sorting Group as a unified rendering unit.

### Sorting Layer System

Sorting layers define the broad rendering order. Within each layer, **Order in Layer** (integer) sets the specific priority. Lower numbers render first (appear behind higher numbers).

### Sorting Group Component

The Sorting Group component organizes child renderers into a single sortable unit. Use cases:
- Complex multi-sprite characters (body parts as separate sprites)
- Groups of related objects that should sort together against the environment

Properties:
- **Sorting Layer**: Assigns the group to a sorting layer
- **Order in Layer**: Priority within the sorting layer

Nested Sorting Groups are supported: inner groups sort among themselves first, then the outer group sorts as a unit against other renderers.

```csharp
// Y-sort for top-down games (attach to entities)
void LateUpdate()
{
    int order = Mathf.RoundToInt(-transform.position.y * 100);
    GetComponent<SpriteRenderer>().sortingOrder = order;
}

// Set sorting layer and order via script
SpriteRenderer sr = GetComponent<SpriteRenderer>();
sr.sortingLayerName = "Characters";
sr.sortingOrder = 10;
sr.sortingLayerID = SortingLayer.NameToID("Characters"); // faster
```

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/sorting-group/sorting-group-landing.html

## Common Patterns (C#)

### Top-Down Movement (Rigidbody2D, no gravity)

```csharp
public class TopDownMovement : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    private Rigidbody2D rb;
    private Vector2 moveInput;

    void Awake() { rb = GetComponent<Rigidbody2D>(); rb.gravityScale = 0f; }
    void Update() // legacy Input; see unity-input
    {
        moveInput = new Vector2(Input.GetAxisRaw("Horizontal"),
            Input.GetAxisRaw("Vertical")).normalized;
    }
    void FixedUpdate()
    {
        rb.MovePosition(rb.position + moveInput * moveSpeed * Time.fixedDeltaTime);
    }
}
```

### Sprite Direction Flip / Camera Follow / Tilemap Click

```csharp
// Flip sprite based on movement direction (legacy Input; see unity-input)
float h = Input.GetAxisRaw("Horizontal");
if (h != 0) spriteRenderer.flipX = h < 0;

// Simple 2D camera follow (attach to Camera, set offset.z = -10)
void LateUpdate()
{
    Vector3 desired = target.position + offset;
    transform.position = Vector3.Lerp(transform.position, desired, smoothSpeed * Time.deltaTime);
}

// Place tile at mouse click
Vector3 worldPos = cam.ScreenToWorldPoint(Input.mousePosition);
Vector3Int cellPos = tilemap.WorldToCell(worldPos);
tilemap.SetTile(cellPos, tileToPlace);
```

## Anti-Patterns

1. **Using 3D physics for 2D games**: Always use Rigidbody2D and Collider2D, never Rigidbody/BoxCollider. The 2D physics engine is separate and optimized for 2D.

2. **Moving Rigidbody2D with Transform**: Never use `transform.position` to move physics objects. Use `Rigidbody2D.MovePosition()` in FixedUpdate or `AddForce()`. Direct Transform manipulation bypasses physics simulation and breaks collision detection.

3. **Scaling sprites with Transform.localScale at runtime**: Use `SpriteRenderer.size` with Sliced/Tiled draw modes instead. Transform scale causes issues with colliders and is less performant.

4. **Forgetting to call CompressBounds() on procedural Tilemaps**: After generating tiles procedurally, call `tilemap.CompressBounds()` to recalculate bounds. Without it, iteration over `cellBounds` includes empty space.

5. **One draw call per sprite (no atlasing)**: Pack related sprites into a Sprite Atlas. Without atlasing, each unique texture triggers a separate draw call.

6. **Enabling Read/Write on Sprite Atlas unnecessarily**: This doubles memory usage. Only enable when you need script access via `Texture2D.SetPixels`.

7. **Using Allow Rotation on UI sprites**: Disable Allow Rotation in Sprite Atlas settings when packing sprites used in Canvas UI, as rotation breaks UI layout.

8. **Not setting TilemapRenderer mode appropriately**: Use Chunk mode for static tilemaps (best performance). Use Individual mode only when tiles need to interact with other renderers or require custom sorting.

9. **Using continuous collision detection everywhere**: Only set `collisionDetectionMode` to Continuous on fast-moving objects. Discrete is cheaper and sufficient for most 2D objects.

10. **Ignoring Sorting Layers**: Relying solely on Order in Layer leads to magic numbers. Define meaningful Sorting Layers (Background, Midground, Characters, Foreground, UI) and use Order in Layer for fine-tuning within each layer.

## Key API Quick Reference

| Class | Key Members |
|-------|-------------|
| `SpriteRenderer` | `.sprite`, `.color`, `.flipX`, `.flipY`, `.drawMode`, `.size`, `.sortingLayerName`, `.sortingOrder` |
| `SpriteAtlas` | `.GetSprite(name)`, `.GetSprites(sprites[])`, `SpriteAtlasManager.atlasRequested` |
| `Tilemap` | `.SetTile()`, `.GetTile()`, `.SetTiles()`, `.ClearAllTiles()`, `.BoxFill()`, `.FloodFill()`, `.SwapTile()`, `.WorldToCell()`, `.CellToWorld()`, `.CompressBounds()`, `.cellBounds` |
| `Rigidbody2D` | `.linearVelocity`, `.angularVelocity`, `.AddForce()`, `.MovePosition()`, `.MoveRotation()`, `.Cast()`, `.bodyType`, `.gravityScale`, `.mass` |
| `Physics2D` | `.Raycast()`, `.BoxCast()`, `.CircleCast()`, `.OverlapCircle()`, `.OverlapBox()`, `.OverlapPoint()`, `.IsTouching()` |
| `Light2D` | `.color`, `.intensity`, `.lightType` (requires `UnityEngine.Rendering.Universal`) |
| `SortingGroup` | `.sortingLayerName`, `.sortingOrder` |

## Related Skills

- **unity-foundations** -- GameObjects, Components, Transforms, Prefabs, ScriptableObjects
- **unity-physics** -- In-depth 3D/2D physics, joints, raycasting, physics materials
- **unity-graphics** -- Rendering pipelines, materials, shaders, post-processing
- **unity-lighting-vfx** -- URP lighting setup, visual effects, particle systems

## Additional Resources

- [Unity 2D Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/Unity2D.html)
- [Sprites](https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/sprite-landing.html)
- [SpriteRenderer Reference](https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/renderer/sprite-renderer-reference.html)
- [Sprite Atlas](https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/atlas/atlas-landing.html)
- [Tilemap Reference](https://docs.unity3d.com/6000.3/Documentation/Manual/tilemaps/work-with-tilemaps/tilemap-reference.html)
- [Tilemap Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Tilemaps.Tilemap.html)
- [Rigidbody2D API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Rigidbody2D.html)
- [Physics2D API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Physics2D.html)
- [2D Light Properties](https://docs.unity3d.com/6000.3/Documentation/Manual/urp/2d-light-properties-explained.html)
- [Sorting Groups](https://docs.unity3d.com/6000.3/Documentation/Manual/sprite/sorting-group/sorting-group-landing.html)
