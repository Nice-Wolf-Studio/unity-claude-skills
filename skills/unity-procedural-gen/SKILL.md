---
name: unity-procedural-gen
description: >
  Unity procedural generation design-to-code translation. Noise-based terrain/placement,
  tile & grid systems, dungeon/room generation, seed & reproducibility, content budget
  & constraint systems, runtime vs baked generation. DESIGN INTENT format:
  INTENT/WRONG/RIGHT/SCAFFOLD/DESIGN HOOK. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.asset"
  - "**/*.compute"
---

# Procedural Generation -- Design Translation Patterns

> **Prerequisite skills:** `unity-3d-math` (noise math, spatial operations), `unity-data-driven` (ScriptableObject configs for generation parameters), `unity-editor-tools` (preview tooling, custom inspectors)

These patterns address the most common procedural generation failure: Claude generates procedural content with hardcoded algorithms and no designer control. The result works once but cannot be tuned, previewed, or constrained. Designers need knobs, constraints, and preview tools -- not just algorithm code. Every generation system should expose its parameters as ScriptableObject configs, support seed-based reproducibility, and provide editor previews.

---

## PATTERN 1: Noise-Based Generation

DESIGN INTENT: Designers want natural-feeling terrain ("rolling hills with occasional mountains") or placement ("dense forests with clearings"). They need to tune the character of randomness without touching code.

WRONG:
```csharp
// Hardcoded single octave, no designer control, no reproducibility
float height = Mathf.PerlinNoise(x * 0.1f, y * 0.1f) * 10f;
terrain.SetHeight(x, y, height);
```

RIGHT: `NoiseConfig` ScriptableObject with frequency, amplitude, octaves, persistence, lacunarity, and offset. `NoiseGenerator` static utility class implements fractal Brownian motion (fBm) sampling. Supports domain warping for organic results. All parameters are designer-editable.

SCAFFOLD:
```csharp
/// <summary>
/// Configuration for noise-based generation. Each biome or terrain type gets its own asset.
/// </summary>
[CreateAssetMenu(fileName = "New Noise Config", menuName = "ProcGen/Noise Config")]
public class NoiseConfig : ScriptableObject
{
    [Header("Base Noise")]
    [Range(0.001f, 1f)] public float frequency = 0.05f;
    [Range(0f, 100f)] public float amplitude = 10f;

    [Header("Fractal")]
    [Range(1, 8)] public int octaves = 4;
    [Range(0f, 1f)] public float persistence = 0.5f;
    [Range(1f, 4f)] public float lacunarity = 2f;

    [Header("Transform")]
    public Vector2 offset;
    [Range(0f, 1f)] public float domainWarpStrength = 0f;
}

/// <summary>
/// Stateless noise sampling utilities. Uses fBm for natural-looking results.
/// </summary>
public static class NoiseGenerator
{
    /// <summary>
    /// Samples 2D fractal Brownian motion noise at the given coordinates.
    /// </summary>
    /// <returns>Noise value scaled by config amplitude.</returns>
    public static float Sample2D(float x, float y, NoiseConfig config)
    {
        float sum = 0f;
        float freq = config.frequency;
        float amp = 1f;
        float maxAmp = 0f;

        for (int i = 0; i < config.octaves; i++)
        {
            float sampleX = (x + config.offset.x) * freq;
            float sampleY = (y + config.offset.y) * freq;
            sum += Mathf.PerlinNoise(sampleX, sampleY) * amp;
            maxAmp += amp;
            amp *= config.persistence;
            freq *= config.lacunarity;
        }

        return (sum / maxAmp) * config.amplitude;
    }
}
```

DESIGN HOOK: Designers tune noise in the Inspector with `[Range]` attributes. Different biomes use different `NoiseConfig` ScriptableObjects. Preview via `[ExecuteAlways]` and `OnValidate` regeneration. See `unity-editor-tools` for building a noise preview EditorWindow.

GOTCHA: `Mathf.PerlinNoise` returns values in the 0-1 range, NOT -1 to 1 like most noise libraries (libnoise, FastNoiseLite). For consistent behavior, normalize or document the expected range in your `NoiseConfig`. If you need -1 to 1 range, use `Mathf.PerlinNoise(x, y) * 2f - 1f`.

---

## PATTERN 2: Tile & Grid Systems

DESIGN INTENT: Grid-based placement (city builder, farming sim, tactical RPG) with rules about adjacency and valid placement. Designers define tile types and placement rules as data, not code.

WRONG:
```csharp
// Raw 2D array, adjacency rules buried in placement code, no validation
int[,] grid = new int[width, height];
grid[x, y] = tileId;
// Scattered checks like: if (grid[x-1, y] == WATER) canPlace = false;
```

RIGHT: `Grid<T>` generic container with coordinate helpers (neighbors, bounds, iteration). `TileDefinition` ScriptableObject per tile type. `IPlacementRule` interface for adjacency/placement validation. `GridPlacer` validates against all rules before placing.

SCAFFOLD:
```csharp
/// <summary>
/// Generic 2D grid container with coordinate utilities.
/// </summary>
[System.Serializable]
public class Grid<T>
{
    [SerializeField] private int width;
    [SerializeField] private int height;
    [SerializeField] private float cellSize = 1f;
    private T[] cells;

    public int Width => width;
    public int Height => height;
    public float CellSize => cellSize;

    public Grid(int width, int height, float cellSize = 1f)
    {
        this.width = width;
        this.height = height;
        this.cellSize = cellSize;
        cells = new T[width * height];
    }

    /// <summary>Returns true if coordinates are within grid bounds.</summary>
    public bool InBounds(Vector2Int coord)
        => coord.x >= 0 && coord.x < width && coord.y >= 0 && coord.y < height;

    public T this[Vector2Int coord]
    {
        get => cells[coord.y * width + coord.x];
        set => cells[coord.y * width + coord.x] = value;
    }

    /// <summary>Converts grid coordinates to world position (center of cell).</summary>
    public Vector3 GridToWorld(Vector2Int coord)
        => new Vector3((coord.x + 0.5f) * cellSize, 0f, (coord.y + 0.5f) * cellSize);

    /// <summary>Converts world position to grid coordinates.</summary>
    public Vector2Int WorldToGrid(Vector3 worldPos)
        => new Vector2Int(Mathf.FloorToInt(worldPos.x / cellSize),
                          Mathf.FloorToInt(worldPos.z / cellSize));
}

/// <summary>Defines a tile type and its placement constraints.</summary>
[CreateAssetMenu(fileName = "New Tile", menuName = "ProcGen/Tile Definition")]
public class TileDefinition : ScriptableObject
{
    public string tileName;
    public GameObject prefab;
    public TileDefinition[] allowedNeighbors;
}

/// <summary>Validates whether a tile can be placed at a grid position.</summary>
public interface IPlacementRule
{
    bool CanPlace(Vector2Int coord, TileDefinition tile, Grid<TileDefinition> grid);
}
```

DESIGN HOOK: New tiles are created as `TileDefinition` ScriptableObjects with allowed neighbor lists. Grid state is visualized with Gizmos for debugging. Rules are composable -- add new `IPlacementRule` implementations without modifying placement logic.

GOTCHA: Grid coordinates vs world coordinates -- always convert explicitly. Provide `GridToWorld(Vector2Int)` and `WorldToGrid(Vector3)` helpers with configurable cell size. Off-by-one errors at grid edges are the most common bug; use `InBounds()` before every access.

---

## PATTERN 3: Dungeon/Room Generation

DESIGN INTENT: Roguelike needs random but valid dungeon layouts with rooms, corridors, and a guaranteed path from start to exit. Designers control room sizes, density, and special room placement.

WRONG:
```csharp
// Random placement with no overlap check, no connectivity guarantee
for (int i = 0; i < roomCount; i++)
{
    var room = new Rect(Random.Range(0, mapWidth), Random.Range(0, mapHeight),
                        Random.Range(5, 15), Random.Range(5, 15));
    rooms.Add(room); // May overlap, may be disconnected
}
```

RIGHT: BSP (Binary Space Partition) for room placement -- recursively split space into regions, place rooms within leaves, connect sibling leaves with corridors. Post-generation validation: connectivity check via flood fill, min/max room count enforcement, critical path identification from start to exit.

SCAFFOLD:
```csharp
/// <summary>
/// Configuration for dungeon generation. Designers tune all parameters in Inspector.
/// </summary>
[CreateAssetMenu(fileName = "New Dungeon Config", menuName = "ProcGen/Dungeon Config")]
public class DungeonConfig : ScriptableObject
{
    [Header("Dimensions")]
    [Min(20)] public int mapWidth = 64;
    [Min(20)] public int mapHeight = 64;

    [Header("Rooms")]
    [Range(4, 20)] public int minRoomSize = 6;
    [Range(6, 30)] public int maxRoomSize = 14;
    [Range(3, 20)] public int roomCountMin = 5;
    [Range(5, 30)] public int roomCountMax = 12;

    [Header("BSP")]
    [Range(2, 8)] public int splitDepth = 4;
    [Range(0.3f, 0.7f)] public float minSplitRatio = 0.4f;

    [Header("Corridors")]
    [Range(1, 5)] public int corridorWidth = 2;

    [Header("Special Rooms")]
    public GameObject bossRoomPrefab;
    public GameObject treasureRoomPrefab;
}

/// <summary>Represents a room in the dungeon layout.</summary>
public class Room
{
    public RectInt Bounds { get; }
    public Vector2Int Center => new(Bounds.x + Bounds.width / 2,
                                    Bounds.y + Bounds.height / 2);
    public bool IsSpecial { get; set; }

    public Room(RectInt bounds) => Bounds = bounds;
}

/// <summary>Represents a corridor connecting two rooms.</summary>
public class Corridor
{
    public Vector2Int Start { get; }
    public Vector2Int End { get; }
    public int Width { get; }

    public Corridor(Vector2Int start, Vector2Int end, int width)
    {
        Start = start;
        End = end;
        Width = width;
    }
}

/// <summary>
/// Validates dungeon connectivity using flood fill.
/// </summary>
public static class ConnectivityValidator
{
    /// <summary>
    /// Returns true if all rooms are reachable from the first room.
    /// </summary>
    public static bool IsFullyConnected(Grid<bool> walkableGrid, List<Room> rooms)
    {
        if (rooms.Count == 0) return true;
        var visited = new HashSet<Vector2Int>();
        var queue = new Queue<Vector2Int>();
        queue.Enqueue(rooms[0].Center);
        visited.Add(rooms[0].Center);

        while (queue.Count > 0)
        {
            var current = queue.Dequeue();
            foreach (var neighbor in GetCardinalNeighbors(current))
            {
                if (walkableGrid.InBounds(neighbor)
                    && walkableGrid[neighbor]
                    && visited.Add(neighbor))
                {
                    queue.Enqueue(neighbor);
                }
            }
        }

        return rooms.All(r => visited.Contains(r.Center));
    }

    private static IEnumerable<Vector2Int> GetCardinalNeighbors(Vector2Int pos)
    {
        yield return pos + Vector2Int.up;
        yield return pos + Vector2Int.down;
        yield return pos + Vector2Int.left;
        yield return pos + Vector2Int.right;
    }
}
```

DESIGN HOOK: `DungeonConfig` ScriptableObject lets designers tune all generation parameters. Room templates can be pre-authored prefabs for special rooms (boss room, treasure room) assigned in the config. Designers add new special room types without code changes.

GOTCHA: BSP can produce very narrow rooms if the split ratio is not constrained -- enforce minimum room dimensions during the split step, not just after. If you check only after splitting, you waste BSP iterations and may end up with fewer rooms than requested.

---

## PATTERN 4: Seed & Reproducibility

DESIGN INTENT: Players share seeds ("try seed 42!"), speedrunners need reproducible layouts, QA reproduces bugs by re-entering the seed. Every run must be deterministic for a given seed.

WRONG:
```csharp
// Global mutable state, non-reproducible, state leaks between systems
int count = UnityEngine.Random.Range(3, 8);
var pos = new Vector3(UnityEngine.Random.Range(-10f, 10f), 0,
                      UnityEngine.Random.Range(-10f, 10f));
```

RIGHT: `SeededRandom` wrapper around `System.Random`. A master seed derives per-subsystem seeds via hashing (dungeon layout, loot, enemy placement each get independent streams). Zero usage of `UnityEngine.Random` in generation code. Seed is stored in save data and displayed to the player.

SCAFFOLD:
```csharp
/// <summary>
/// Deterministic random number generator wrapping System.Random.
/// Each subsystem gets its own instance derived from a master seed.
/// </summary>
public class SeededRandom
{
    private readonly System.Random rng;

    /// <summary>The seed used to initialize this instance.</summary>
    public int Seed { get; }

    public SeededRandom(int seed)
    {
        Seed = seed;
        rng = new System.Random(seed);
    }

    /// <summary>Returns a random int in [min, max).</summary>
    public int Range(int min, int max) => rng.Next(min, max);

    /// <summary>Returns a random float in [0, 1).</summary>
    public float Float01() => (float)rng.NextDouble();

    /// <summary>Returns a random float in [min, max).</summary>
    public float Range(float min, float max) => min + Float01() * (max - min);

    /// <summary>
    /// Selects an item from weighted entries. Higher weight = more likely.
    /// </summary>
    public T WeightedChoice<T>(IReadOnlyList<(T item, float weight)> entries)
    {
        float totalWeight = 0f;
        foreach (var e in entries) totalWeight += e.weight;

        float roll = Float01() * totalWeight;
        float cumulative = 0f;
        foreach (var e in entries)
        {
            cumulative += e.weight;
            if (roll < cumulative) return e.item;
        }

        return entries[^1].item;
    }

    /// <summary>
    /// Derives a child seed for a named subsystem. Deterministic for the
    /// same master seed + subsystem name combination.
    /// </summary>
    public static int DeriveSeed(int masterSeed, string subsystem)
        => HashCode.Combine(masterSeed, subsystem.GetHashCode(StringComparison.Ordinal));
}
```

DESIGN HOOK: Seed can be player-entered (text field in UI) or auto-generated (`System.Environment.TickCount`). Displayed in the pause menu and saved with run data. Designers can lock a seed during playtesting for consistent iteration.

GOTCHA: `System.Random` is NOT thread-safe. If using the Jobs system or Burst, use `Unity.Mathematics.Random` instead (it is a value type, safe for per-thread usage). Never share a `System.Random` instance across threads. Also, `string.GetHashCode()` is not deterministic across .NET versions -- use `GetHashCode(StringComparison.Ordinal)` for stable seed derivation.

---

## PATTERN 5: Content Budget & Constraint Systems

DESIGN INTENT: Generated content must satisfy designer constraints -- minimum 3 enemies per room, maximum 2 treasure chests per floor, difficulty curve from easy to hard. Pure random placement produces incoherent game feel.

WRONG:
```csharp
// No awareness of balance, guarantees, or budgets
for (int i = 0; i < Random.Range(1, 10); i++)
{
    var prefab = enemyPrefabs[Random.Range(0, enemyPrefabs.Length)];
    Instantiate(prefab, randomPosition, Quaternion.identity);
}
```

RIGHT: `ContentBudget` ScriptableObject defines per-category minimum/maximum counts, rarity weights, and mandatory placements. `ContentPlacer` consumes the budget, tracks running totals, guarantees minimums first. Post-placement validation ensures all constraints are met.

SCAFFOLD:
```csharp
/// <summary>
/// A single entry in a content budget -- one prefab with placement rules.
/// </summary>
[System.Serializable]
public struct ContentEntry
{
    public GameObject prefab;
    public string category;
    [Range(0.01f, 100f)] public float weight;
    [Min(0)] public int minimum;
    [Min(0)] public int maximum;
}

/// <summary>
/// Defines what content can be placed and in what quantities.
/// One per floor, biome, or difficulty tier.
/// </summary>
[CreateAssetMenu(fileName = "New Content Budget", menuName = "ProcGen/Content Budget")]
public class ContentBudget : ScriptableObject
{
    [Tooltip("Total placement slots available for this budget.")]
    [Min(1)] public int totalSlots = 20;

    public ContentEntry[] entries;
}

/// <summary>
/// Places content according to budget constraints.
/// Guarantees minimums first, then fills with weighted random.
/// </summary>
public class ContentPlacer
{
    private readonly Dictionary<string, int> placedCounts = new();

    /// <summary>
    /// Generates a placement list respecting budget constraints.
    /// </summary>
    public List<GameObject> GeneratePlacements(ContentBudget budget, SeededRandom rng)
    {
        var result = new List<GameObject>();
        placedCounts.Clear();

        // Phase 1: Place all mandatory minimums
        foreach (var entry in budget.entries)
        {
            for (int i = 0; i < entry.minimum; i++)
            {
                result.Add(entry.prefab);
                IncrementCount(entry.category);
            }
        }

        // Phase 2: Fill remaining slots with weighted random
        int remaining = budget.totalSlots - result.Count;
        var eligible = BuildWeightedList(budget);

        for (int i = 0; i < remaining && eligible.Count > 0; i++)
        {
            var chosen = rng.WeightedChoice(eligible);
            result.Add(chosen.prefab);
            IncrementCount(chosen.category);

            // Rebuild eligible list (removes entries at max)
            eligible = BuildWeightedList(budget);
        }

        return result;
    }

    private List<(ContentEntry item, float weight)> BuildWeightedList(ContentBudget budget)
    {
        var list = new List<(ContentEntry, float)>();
        foreach (var entry in budget.entries)
        {
            int placed = placedCounts.GetValueOrDefault(entry.category);
            if (entry.maximum <= 0 || placed < entry.maximum)
                list.Add((entry, entry.weight));
        }
        return list;
    }

    private void IncrementCount(string category)
    {
        placedCounts.TryGetValue(category, out int count);
        placedCounts[category] = count + 1;
    }
}
```

DESIGN HOOK: Designers author `ContentBudget` ScriptableObjects per floor or biome. Tune weights and constraints in the Inspector with `[Range]` and `[Min]` attributes. Different difficulty tiers use different budgets (easy floor = more health pickups, hard floor = more elite enemies).

GOTCHA: Weighted random must guarantee minimums FIRST, then fill remaining budget with weighted random selection. If you interleave mandatory and random placements, mandatory items may not fit when the budget runs out. Always validate that `sum of all minimums <= totalSlots`.

---

## PATTERN 6: Runtime vs Baked Generation

DESIGN INTENT: Some content generates once at build/load time (world map terrain mesh, static environment). Some generates per session (dungeon layout, loot rolls). Some needs editor preview for designer iteration. The generation algorithm should be reusable across all three contexts.

WRONG:
```csharp
// Everything at runtime -- huge load spike, no editor preview
void Start()
{
    for (int x = 0; x < 1000; x++)
        for (int y = 0; y < 1000; y++)
            GenerateChunk(x, y); // Freezes for seconds
}

// Or everything baked -- no dynamic content
// Designer manually places 500 trees in the editor
```

RIGHT: `IGenerator<TOutput>` interface with `Generate(GenerationContext)`. `GenerationContext` indicates runtime vs editor. Editor generators produce assets via `AssetDatabase`. Runtime generators produce lightweight data consumed by async instantiation. Same algorithm, different output targets.

SCAFFOLD:
```csharp
/// <summary>Indicates whether generation runs in Editor (bake) or Runtime (dynamic).</summary>
public enum GenerationMode { Editor, Runtime }

/// <summary>Context passed to generators with mode and seed information.</summary>
public struct GenerationContext
{
    public GenerationMode Mode;
    public SeededRandom Random;
    public CancellationToken CancellationToken;
}

/// <summary>
/// Interface for all procedural generators. Implement once, run in Editor or Runtime.
/// </summary>
public interface IGenerator<TOutput>
{
    /// <summary>Generates output data from the given context.</summary>
    TOutput Generate(GenerationContext context);
}

// --- Runtime runner: async, non-blocking ---
public class RuntimeGeneratorRunner : MonoBehaviour
{
    /// <summary>
    /// Runs a generator asynchronously, yielding periodically to avoid frame spikes.
    /// </summary>
    public async Awaitable<TOutput> RunAsync<TOutput>(
        IGenerator<TOutput> generator, int seed)
    {
        var context = new GenerationContext
        {
            Mode = GenerationMode.Runtime,
            Random = new SeededRandom(seed),
            CancellationToken = destroyCancellationToken
        };

        // Run generation off the main thread if it's pure data
        return await Awaitable.FromAsyncOperation(
            System.Threading.Tasks.Task.Run(
                () => generator.Generate(context),
                context.CancellationToken));
    }
}

#if UNITY_EDITOR
// --- Editor runner: bakes output to asset ---
public static class EditorGeneratorRunner
{
    [UnityEditor.MenuItem("ProcGen/Bake Selected Generator")]
    private static void BakeFromMenu()
    {
        // Editor-only bake workflow
        // Produces assets saved to disk via AssetDatabase
    }
}
#endif
```

DESIGN HOOK: Same generator implementation runs in Editor (bake to asset via MenuItem) or at Runtime (async `Awaitable`). Designers preview results in a custom EditorWindow or via `[ExecuteAlways]` components. See `unity-editor-tools` for building generation preview windows.

GOTCHA: Editor-only code (`AssetDatabase`, `EditorWindow`, `MenuItem`) must be behind `#if UNITY_EDITOR` guards. Runtime builds will fail with compile errors otherwise. Keep generator logic in runtime-accessible code; only the bake harness goes behind the guard.

---

## Generation Strategy Comparison

| Strategy | Best For | Strengths | Weaknesses |
|----------|----------|-----------|------------|
| **Perlin/Simplex Noise (fBm)** | Terrain, heightmaps, biome distribution, organic placement | Continuous, tileable, intuitive parameters | Not suitable for discrete structures (rooms, corridors) |
| **BSP (Binary Space Partition)** | Dungeon rooms, building floor plans, space subdivision | Guarantees no overlap, natural corridor connections | Rooms tend toward rectangular, less organic feel |
| **Wave Function Collapse** | Tile-based levels, city blocks, pattern-driven generation | Respects adjacency constraints automatically, designer-friendly exemplar input | Slow for large grids, can fail to solve (backtracking needed) |
| **L-Systems** | Plants, branching structures, road networks, rivers | Compact rule representation, natural branching | Hard to constrain to specific bounds, unintuitive rule authoring |
| **Poisson Disk Sampling** | Object placement (trees, rocks, NPCs) | Even distribution with minimum spacing, natural look | Fixed density, not suitable for clustered placement |
| **Voronoi / Delaunay** | Region subdivision, biome boundaries, territory maps | Organic region shapes, dual graph useful for pathfinding | Requires external library or custom implementation |

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Hardcoded noise parameters | Cannot tune without code changes | `NoiseConfig` ScriptableObject with `[Range]` attributes |
| `UnityEngine.Random` in generation | Global state, non-reproducible, state leaks | `SeededRandom` wrapper around `System.Random` |
| No connectivity validation | Dungeons with unreachable rooms | Flood fill validation after generation |
| Generate everything in `Start()` | Frame spike / freeze on load | Async `Awaitable` generation, spread across frames |
| Ignoring placement constraints | Random content with no balance | `ContentBudget` SO with min/max/weight enforcement |
| Same code for editor and runtime bake | `#if UNITY_EDITOR` sprawl in core logic | `IGenerator<T>` interface with separate runners |
| Grid coordinate / world coordinate confusion | Objects placed at wrong positions | Explicit `GridToWorld` / `WorldToGrid` conversion helpers |
| Sharing `System.Random` across threads | Race conditions, non-deterministic output | `Unity.Mathematics.Random` (value type) for Jobs/Burst |

---

## Related Skills

- `unity-3d-math` -- Noise math foundations, spatial operations, coordinate transforms
- `unity-data-driven` -- ScriptableObject config hierarchies for generation parameters
- `unity-editor-tools` -- Custom inspectors, preview EditorWindows for generator output
- `unity-level-design` -- Authored content integration with generated content
- `unity-performance` -- Async generation, chunked loading, LOD for generated meshes
- `unity-game-loop` -- Generation timing relative to game state transitions
- `unity-physics` -- Collision validation for generated placement (overlap checks)

---

## Additional Resources

- **Unity.Mathematics.noise** -- GPU-friendly noise functions for Burst/Jobs (`noise.cnoise`, `noise.snoise`)
- **Poisson Disk Sampling** -- Bridson's algorithm for even-spaced point distribution
- **Wave Function Collapse** -- Constraint-based tile placement (see community packages on OpenUPM)
- **Red Blob Games** -- Amit Patel's guides on grids, pathfinding, and procedural generation (redblobgames.com)
- **Procedural Generation in Game Design** (Tanya X. Short, Tarn Adams) -- Design-focused reference on generation systems
