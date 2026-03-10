# Tilemaps Reference

## Tilemap System Overview

Tilemaps are "A GameObject that allows you to quickly create 2D levels using tiles and a grid overlay." The Tilemap component "stores and manages Tile Assets" and "transfers the required information from the tiles placed on it to other related components such as the Tilemap Renderer and the Tilemap Collider 2D."

The 2D Tilemap Editor package is auto-installed with the 2D template or available via Package Manager.

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/tilemaps/tilemaps-landing.html

## Tilemap Hierarchy Structure

A typical tilemap setup in the scene hierarchy:

```
Grid (Grid component)
  +-- Ground (Tilemap + TilemapRenderer)
  +-- Walls (Tilemap + TilemapRenderer + TilemapCollider2D)
  +-- Decorations (Tilemap + TilemapRenderer)
```

- The **Grid** component defines the cell layout (Rectangle, Hexagon, Isometric)
- Each child **Tilemap** is an independent layer
- Use separate Tilemaps per layer for sorting and collision control

## Tilemap Component Properties

| Property | Description |
|----------|-------------|
| **Animation Frame Rate** | Playback speed multiplier for tile animations |
| **Color** | Tint applied to all tiles (default: white = no tint) |
| **Tile Anchor** | Offset for tile anchor positions along xyz axes (measured in cells) |
| **Orientation** | XY, XZ, YX, YZ, ZX, ZY, or Custom (with offset, rotation, scale) |

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/tilemaps/work-with-tilemaps/tilemap-reference.html

## TilemapRenderer Component

| Property | Description |
|----------|-------------|
| **Mode** | Chunk (best performance, batches tiles), Individual (per-tile rendering), SRP Batch (URP 15+) |
| **Sort Order** | Direction tiles are sorted during rendering |
| **Detect Chunk Culling Bounds** | Auto or Manual detection of chunk boundaries |
| **Chunk Culling Bounds** | Manually extend culling bounds (prevents sprite clipping) |
| **Material** | Material for rendering tile sprites |
| **Mask Interaction** | None, Visible Inside Mask, or Visible Outside Mask |
| **Sorting Layer** | Render layer assignment |
| **Order in Layer** | Priority within sorting layer (lower renders first) |

**Mode selection guide:**
- **Chunk**: Use for static tilemaps. Groups tiles by location/texture for batching. Best performance but incompatible with SRP Batcher
- **Individual**: Use when tiles need to interact with other renderers or require custom sorting axes
- **SRP Batch**: Use with URP 15+. Groups tiles with sequential batching, compatible with SRP Batcher

Source: https://docs.unity3d.com/6000.3/Documentation/Manual/tilemaps/work-with-tilemaps/tilemap-renderer-reference.html

## TilemapCollider2D

Add a **TilemapCollider2D** component to generate collision shapes from tiles that have physics shapes defined. Combine with a **CompositeCollider2D** for performance:

```csharp
// Setup tilemap collision in code
// Typically done in the editor, but can be configured via script:
TilemapCollider2D tilemapCollider = tilemap.gameObject.AddComponent<TilemapCollider2D>();
tilemapCollider.usedByComposite = true;

Rigidbody2D rb = tilemap.gameObject.AddComponent<Rigidbody2D>();
rb.bodyType = RigidbodyType2D.Static;

CompositeCollider2D composite = tilemap.gameObject.AddComponent<CompositeCollider2D>();
// CompositeCollider2D merges individual tile colliders into optimized shapes
```

**Best practice**: Always use CompositeCollider2D with TilemapCollider2D. Without it, each tile generates an individual collider, causing poor physics performance.

## Tilemap Scripting API

### Core Methods

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;

Tilemap tilemap = GetComponent<Tilemap>();
```

#### Setting and Getting Tiles

```csharp
// Set a single tile
tilemap.SetTile(new Vector3Int(x, y, 0), tile);

// Get a tile at position
TileBase tile = tilemap.GetTile(new Vector3Int(x, y, 0));

// Get typed tile
Tile specificTile = tilemap.GetTile<Tile>(new Vector3Int(x, y, 0));

// Remove a tile (set to null)
tilemap.SetTile(new Vector3Int(x, y, 0), null);

// Clear all tiles
tilemap.ClearAllTiles();
```

#### Batch Operations

```csharp
// Set multiple tiles at once (much faster than individual SetTile calls)
Vector3Int[] positions = new Vector3Int[] {
    new Vector3Int(0, 0, 0),
    new Vector3Int(1, 0, 0),
    new Vector3Int(2, 0, 0)
};
TileBase[] tiles = new TileBase[] { tileA, tileB, tileC };
tilemap.SetTiles(positions, tiles);

// Get all tiles in a rectangular region
BoundsInt bounds = new BoundsInt(0, 0, 0, 10, 10, 1);
TileBase[] tilesInRegion = tilemap.GetTilesBlock(bounds);

// Set a block of tiles
tilemap.SetTilesBlock(bounds, tilesArray);
```

#### Fill Operations

```csharp
// Box fill a region with a tile
tilemap.BoxFill(
    new Vector3Int(0, 0, 0), // position
    tile,                      // tile to fill
    0, 10,                     // startX, endX
    0, 10                      // startY, endY
);

// Flood fill from a position (fills connected empty/matching cells)
tilemap.FloodFill(new Vector3Int(5, 5, 0), tile);

// Replace all instances of one tile with another
tilemap.SwapTile(oldTile, newTile);
```

#### Coordinate Conversion

```csharp
// Convert cell position to world position
Vector3 worldPos = tilemap.CellToWorld(new Vector3Int(5, 3, 0));

// Convert world position to cell position
Vector3Int cellPos = tilemap.WorldToCell(worldPosition);

// Get the center of a cell in world space
Vector3 cellCenter = tilemap.GetCellCenterWorld(new Vector3Int(5, 3, 0));

// Convert cell to local space
Vector3 localPos = tilemap.CellToLocal(new Vector3Int(5, 3, 0));
```

#### Tile Refresh and Bounds

```csharp
// Refresh a single tile (re-evaluates tile state)
tilemap.RefreshTile(new Vector3Int(x, y, 0));

// Refresh all tiles
tilemap.RefreshAllTiles();

// Compress bounds to fit only placed tiles
// IMPORTANT: Call after procedural generation
tilemap.CompressBounds();

// Read bounds
BoundsInt bounds = tilemap.cellBounds;
Debug.Log($"Tilemap size: {tilemap.size}");
Debug.Log($"Tilemap origin: {tilemap.origin}");
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `cellBounds` | `BoundsInt` | Boundaries of the Tilemap in cell size |
| `localBounds` | `Bounds` | Boundaries in local space |
| `size` | `Vector3Int` | Size of the Tilemap in cells |
| `origin` | `Vector3Int` | Origin cell position |
| `animationFrameRate` | `float` | Frame rate for tile animations |

### Events

| Event | Description |
|-------|-------------|
| `tilemapTileChanged` | Callback when tiles are modified |
| `tilemapPositionsChanged` | Callback when tile positions update |
| `loopEndedForTileAnimation` | Callback when tile animation loops complete |

Source: https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Tilemaps.Tilemap.html

## Rule Tiles

Rule Tiles are scriptable tiles that automatically select the correct sprite based on neighboring tiles. They are part of the **2D Tilemap Extras** package.

### Setup

1. Install **2D Tilemap Extras** via Package Manager
2. Create: **Assets > Create > 2D > Tiles > Rule Tile**
3. Define rules with neighbor conditions (This, Not This, Don't Care)
4. Assign sprites to each rule

### Rule Tile Usage

```csharp
// Rule Tiles work the same as regular tiles in code
using UnityEngine;
using UnityEngine.Tilemaps;

public class RuleTilePlacer : MonoBehaviour
{
    [SerializeField] private Tilemap tilemap;
    [SerializeField] private RuleTile wallRuleTile;

    public void PlaceWall(Vector3Int position)
    {
        tilemap.SetTile(position, wallRuleTile);
        // Rule Tile automatically selects the correct sprite
        // based on its neighbors
    }

    public void PlaceWallLine(Vector3Int start, Vector3Int end)
    {
        Vector3Int current = start;
        while (current != end)
        {
            tilemap.SetTile(current, wallRuleTile);
            current += Vector3Int.RoundToInt(
                ((Vector3)(end - current)).normalized);
        }
        tilemap.SetTile(end, wallRuleTile);
    }
}
```

## Procedural Tilemap Generation

### Basic Noise-Based Terrain

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;

public class ProceduralTerrain : MonoBehaviour
{
    [SerializeField] private Tilemap groundTilemap;
    [SerializeField] private Tilemap wallTilemap;
    [SerializeField] private TileBase grassTile;
    [SerializeField] private TileBase waterTile;
    [SerializeField] private TileBase wallTile;

    [SerializeField] private int width = 100;
    [SerializeField] private int height = 100;
    [SerializeField] private float noiseScale = 0.1f;
    [SerializeField] private float waterThreshold = 0.35f;

    void Start()
    {
        Generate();
    }

    void Generate()
    {
        groundTilemap.ClearAllTiles();
        wallTilemap.ClearAllTiles();

        float seed = Random.Range(0f, 10000f);

        // Use batch arrays for performance
        Vector3Int[] groundPositions = new Vector3Int[width * height];
        TileBase[] groundTiles = new TileBase[width * height];
        int index = 0;

        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                float noise = Mathf.PerlinNoise(
                    x * noiseScale + seed,
                    y * noiseScale + seed);

                Vector3Int pos = new Vector3Int(x, y, 0);
                groundPositions[index] = pos;
                groundTiles[index] = noise < waterThreshold
                    ? waterTile : grassTile;
                index++;
            }
        }

        // Batch set for performance
        groundTilemap.SetTiles(groundPositions, groundTiles);
        groundTilemap.CompressBounds();
        wallTilemap.CompressBounds();
    }
}
```

### Dungeon Room Generator

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;
using System.Collections.Generic;

public class DungeonGenerator : MonoBehaviour
{
    [SerializeField] private Tilemap floorTilemap;
    [SerializeField] private Tilemap wallTilemap;
    [SerializeField] private TileBase floorTile;
    [SerializeField] private TileBase wallTile;

    [SerializeField] private int roomCount = 10;
    [SerializeField] private Vector2Int roomSizeMin = new Vector2Int(4, 4);
    [SerializeField] private Vector2Int roomSizeMax = new Vector2Int(10, 10);

    private List<RectInt> rooms = new List<RectInt>();

    void Start()
    {
        GenerateDungeon();
    }

    void GenerateDungeon()
    {
        floorTilemap.ClearAllTiles();
        wallTilemap.ClearAllTiles();
        rooms.Clear();

        // Generate rooms
        for (int i = 0; i < roomCount; i++)
        {
            int w = Random.Range(roomSizeMin.x, roomSizeMax.x);
            int h = Random.Range(roomSizeMin.y, roomSizeMax.y);
            int x = Random.Range(0, 50 - w);
            int y = Random.Range(0, 50 - h);

            RectInt room = new RectInt(x, y, w, h);
            rooms.Add(room);
            CarveRoom(room);
        }

        // Connect rooms with corridors
        for (int i = 0; i < rooms.Count - 1; i++)
        {
            Vector2Int centerA = Vector2Int.RoundToInt(rooms[i].center);
            Vector2Int centerB = Vector2Int.RoundToInt(rooms[i + 1].center);
            CarveCorridor(centerA, centerB);
        }

        // Add walls around floors
        AddWalls();

        floorTilemap.CompressBounds();
        wallTilemap.CompressBounds();
    }

    void CarveRoom(RectInt room)
    {
        for (int x = room.xMin; x < room.xMax; x++)
        {
            for (int y = room.yMin; y < room.yMax; y++)
            {
                floorTilemap.SetTile(new Vector3Int(x, y, 0), floorTile);
            }
        }
    }

    void CarveCorridor(Vector2Int from, Vector2Int to)
    {
        Vector2Int current = from;

        // Horizontal then vertical
        while (current.x != to.x)
        {
            floorTilemap.SetTile(
                new Vector3Int(current.x, current.y, 0), floorTile);
            current.x += current.x < to.x ? 1 : -1;
        }
        while (current.y != to.y)
        {
            floorTilemap.SetTile(
                new Vector3Int(current.x, current.y, 0), floorTile);
            current.y += current.y < to.y ? 1 : -1;
        }
    }

    void AddWalls()
    {
        BoundsInt bounds = floorTilemap.cellBounds;

        for (int x = bounds.xMin - 1; x <= bounds.xMax; x++)
        {
            for (int y = bounds.yMin - 1; y <= bounds.yMax; y++)
            {
                Vector3Int pos = new Vector3Int(x, y, 0);
                if (floorTilemap.GetTile(pos) != null) continue;

                // Check if any neighbor is a floor tile
                for (int dx = -1; dx <= 1; dx++)
                {
                    for (int dy = -1; dy <= 1; dy++)
                    {
                        Vector3Int neighbor = new Vector3Int(
                            x + dx, y + dy, 0);
                        if (floorTilemap.GetTile(neighbor) != null)
                        {
                            wallTilemap.SetTile(pos, wallTile);
                            goto NextCell;
                        }
                    }
                }
                NextCell: continue;
            }
        }
    }
}
```

### Tilemap Interaction Utilities

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;

public class TilemapInteraction : MonoBehaviour
{
    [SerializeField] private Tilemap tilemap;
    [SerializeField] private Camera cam;

    // Get tile under mouse cursor
    public TileBase GetTileUnderMouse()
    {
        Vector3 mouseWorld = cam.ScreenToWorldPoint(Input.mousePosition);
        Vector3Int cellPos = tilemap.WorldToCell(mouseWorld);
        return tilemap.GetTile(cellPos);
    }

    // Check if a world position has a tile
    public bool HasTileAt(Vector3 worldPos)
    {
        Vector3Int cellPos = tilemap.WorldToCell(worldPos);
        return tilemap.GetTile(cellPos) != null;
    }

    // Get all occupied cell positions
    public List<Vector3Int> GetAllOccupiedCells()
    {
        List<Vector3Int> occupied = new List<Vector3Int>();
        BoundsInt bounds = tilemap.cellBounds;

        foreach (Vector3Int pos in bounds.allPositionsWithin)
        {
            if (tilemap.GetTile(pos) != null)
            {
                occupied.Add(pos);
            }
        }
        return occupied;
    }

    // Count tiles of a specific type
    public int CountTiles(TileBase targetTile)
    {
        int count = 0;
        BoundsInt bounds = tilemap.cellBounds;

        foreach (Vector3Int pos in bounds.allPositionsWithin)
        {
            if (tilemap.GetTile(pos) == targetTile)
                count++;
        }
        return count;
    }
}
```

## Tile Palette Workflow

The Tile Palette is the editor tool for painting tiles onto tilemaps:

1. **Open**: Window > 2D > Tile Palette
2. **Create Palette**: Click "Create New Palette" in the Tile Palette window
3. **Add Tiles**: Drag sprite assets into the Tile Palette window to auto-create Tile assets
4. **Paint**: Select a tile and use the painting tools

### Painting Tools

| Tool | Shortcut | Description |
|------|----------|-------------|
| Select | S | Select tiles on the palette or tilemap |
| Move | M | Move selected tiles |
| Paint | B | Paint selected tile onto the tilemap |
| Box Fill | U | Fill a rectangular area |
| Pick | I | Pick a tile from the tilemap (eyedropper) |
| Erase | D | Remove tiles from the tilemap |
| Flood Fill | G | Fill connected area with selected tile |

## Anti-Patterns

1. **Individual SetTile calls in a loop**: Use `SetTiles()` with arrays for batch operations. Individual calls trigger refresh per tile, causing poor performance on large maps.

2. **Not using CompositeCollider2D with TilemapCollider2D**: Without it, each tile gets its own collider, creating thousands of individual physics shapes. Always add CompositeCollider2D.

3. **Forgetting CompressBounds()**: After procedural generation, `cellBounds` includes empty space. Always call `CompressBounds()` to recalculate actual bounds.

4. **Using Individual renderer mode for static tilemaps**: Chunk mode is significantly faster for tilemaps that don't need per-tile sorting interaction.

5. **Not separating tilemap layers**: Put ground, walls, decorations, and foreground on separate Tilemap components for independent sorting, collision, and management.
