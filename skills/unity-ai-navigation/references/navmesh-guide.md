# NavMesh Complete Reference Guide

> Source: Unity AI Navigation 2.0.11 Documentation
> https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/index.html

## NavMesh Architecture

The navigation system consists of:

1. **NavMesh** -- Baked data describing walkable surfaces
2. **NavMeshAgent** -- Component that moves characters along the NavMesh
3. **NavMeshObstacle** -- Dynamic obstacles that modify agent behavior
4. **NavMeshSurface** -- Component that builds and owns NavMesh data
5. **NavMeshModifier** -- Per-object overrides for NavMesh generation
6. **NavMeshModifierVolume** -- Volume-based overrides for NavMesh generation
7. **NavMeshLink** -- Connections between NavMesh surfaces

## NavMeshSurface

### Properties

| Property | Description | Default |
|----------|-------------|---------|
| Agent Type | Which agent configuration uses this surface | Humanoid |
| Default Area | Area classification for generated mesh | Walkable |
| Use Geometry | Input source: Render Meshes or Physics Colliders | Render Meshes |
| Generate Links | Auto-create connections during bake | false |
| Collect Objects | Scope: All, Volume, Current Hierarchy, NavMeshModifier only | All |
| Include Layers | Layer filter for GameObjects | Everything |

### Advanced Baking

| Parameter | Description | Default |
|-----------|-------------|---------|
| Override Voxel Size | Geometry precision | 3 voxels per agent radius |
| Override Tile Size | Tile grid dimensions | 256 voxels |
| Minimum Region Area | Removes small disconnected segments | 0 |
| Build Height Mesh | Elevation data for placement | false |

**Physics Colliders vs Render Meshes:** Physics Colliders permit agents to navigate closer to environmental edges since collision geometry is typically simpler.

**Tile Size Trade-offs:** Smaller tiles increase fragmentation but improve carving performance with many obstacles. Larger tiles reduce overhead but carving recalculates more geometry.

### Excluded Objects

NavMeshSurface automatically excludes GameObjects with NavMeshAgent or NavMeshObstacle components during baking. These are dynamic navigation users, not static geometry.

### Scripting API

```csharp
using Unity.AI.Navigation;
using UnityEngine;

public class NavMeshSurfaceController : MonoBehaviour
{
    NavMeshSurface surface;

    void Start()
    {
        surface = GetComponent<NavMeshSurface>();
    }

    // Full bake (expensive)
    public void BakeNavMesh()
    {
        surface.BuildNavMesh();
    }

    // Incremental update (less expensive)
    public void UpdateExistingNavMesh()
    {
        surface.UpdateNavMesh(surface.navMeshData);
    }

    // Remove NavMesh data
    public void ClearNavMesh()
    {
        surface.RemoveData();
    }
}
```

## NavMeshAgent

### Properties Reference

**Agent Configuration:**

| Property | Type | Description |
|----------|------|-------------|
| agentTypeID | int | Agent type identifier |
| baseOffset | float | Collision cylinder offset from transform pivot |

**Steering:**

| Property | Type | Description |
|----------|------|-------------|
| speed | float | Max movement velocity (units/sec) |
| angularSpeed | float | Max rotation velocity (deg/sec) |
| acceleration | float | Max acceleration (units/sec^2) |
| stoppingDistance | float | Distance threshold before halting |
| autoBraking | bool | Decelerate when approaching destination |

**Obstacle Avoidance:**

| Property | Type | Description |
|----------|------|-------------|
| radius | float | Collision detection radius |
| height | float | Overhead clearance |
| obstacleAvoidanceType | ObstacleAvoidanceType | Quality: None, Low, Medium, Good, High |
| avoidancePriority | int | Priority 0-99 (lower = higher priority) |

**Pathfinding:**

| Property | Type | Description |
|----------|------|-------------|
| autoTraverseOffMeshLink | bool | Automatic link crossing |
| autoRepath | bool | Retry path on partial completion |
| areaMask | int | Bitfield of allowed NavMesh areas |

### Key Methods

```csharp
NavMeshAgent agent = GetComponent<NavMeshAgent>();

// Navigation
agent.SetDestination(targetPosition);      // Set target and calculate path
agent.destination = targetPosition;         // Property alternative
agent.Warp(position);                       // Teleport to position
agent.Move(offset);                         // Move by offset (respects NavMesh)
agent.ResetPath();                          // Clear current path
agent.CompleteOffMeshLink();                // Finish off-mesh link traversal

// State queries
bool pending = agent.pathPending;           // Path calculation in progress
float dist = agent.remainingDistance;       // Distance to destination
bool hasPath = agent.hasPath;              // Currently has a valid path
bool onMesh = agent.isOnNavMesh;           // Agent is on NavMesh
bool onLink = agent.isOnOffMeshLink;       // Agent is on off-mesh link
NavMeshPathStatus status = agent.pathStatus; // PathComplete, PathPartial, PathInvalid

// Control
agent.isStopped = true;                    // Pause movement
agent.isStopped = false;                   // Resume movement
agent.velocity = Vector3.zero;             // Stop immediately
agent.updatePosition = false;              // Manual position control
agent.updateRotation = false;              // Manual rotation control
```

### Path Status Types

| Status | Meaning |
|--------|---------|
| `PathComplete` | Full path to destination found |
| `PathPartial` | Destination unreachable; path goes to nearest point |
| `PathInvalid` | No valid path exists |

### Agent Priority System

Agents avoid others of higher priority (lower number) and ignore those of lower priority (higher number). Range: 0 (highest) to 99 (lowest).

### Manual Path Calculation

```csharp
// Calculate path without moving
NavMeshPath path = new NavMeshPath();
bool found = agent.CalculatePath(targetPosition, path);

if (path.status == NavMeshPathStatus.PathComplete)
{
    // Inspect waypoints
    Vector3[] corners = path.corners;
    for (int i = 0; i < corners.Length; i++)
    {
        Debug.Log($"Waypoint {i}: {corners[i]}");
    }
}

// Or use static method
NavMesh.CalculatePath(startPos, endPos, NavMesh.AllAreas, path);
```

## NavMeshObstacle

### Properties Reference

| Property | Type | Description |
|----------|------|-------------|
| shape | NavMeshObstacleShape | Box or Capsule |
| center | Vector3 | Position offset from transform |
| size | Vector3 | Box dimensions (Box shape only) |
| radius | float | Capsule radius (Capsule shape only) |
| height | float | Capsule height (Capsule shape only) |
| carving | bool | Enable NavMesh hole carving |
| carvingMoveThreshold | float | Distance triggering update |
| carvingTimeToStationary | float | Seconds before considered stationary |
| carveOnlyStationary | bool | Only carve when not moving |

### Carving vs Non-Carving

**Carved obstacles:** Dynamically modify NavMesh topology. Agents recalculate paths around carved holes. Best for: barrels, crates, closed doors, destructible walls.

**Non-carved obstacles:** Agents use local avoidance to steer around them. NavMesh topology unchanged. Best for: moving characters, projectiles, temporary barriers.

### Scripting

```csharp
using UnityEngine;
using UnityEngine.AI;

public class Door : MonoBehaviour
{
    NavMeshObstacle obstacle;

    void Start()
    {
        obstacle = GetComponent<NavMeshObstacle>();
        obstacle.shape = NavMeshObstacleShape.Box;
        obstacle.carving = true;
        obstacle.carveOnlyStationary = true;
    }

    public void Open()
    {
        obstacle.enabled = false;
        // Play open animation
    }

    public void Close()
    {
        obstacle.enabled = true;
        // Play close animation
    }
}
```

## NavMeshLink

### Properties Reference

| Property | Type | Description |
|----------|------|-------------|
| agentTypeID | int | Which agent type can traverse |
| startTransform | Transform | Start edge reference |
| endTransform | Transform | End edge reference |
| startPoint | Vector3 | Start position (local space) |
| endPoint | Vector3 | End position (local space) |
| width | float | Link span width |
| costModifier | float | Cost override (-1 = use area cost) |
| autoUpdate | bool | Update when transforms change |
| bidirectional | bool | Two-way traversal |
| area | int | Area type index |
| activated | bool | Link usability |

### Area Types

| Built-in Type | Description |
|---------------|-------------|
| Walkable | Default; permits crossing |
| Not Walkable | Blocks traversal |
| Jump | Auto-generated link default |

Plus 29 user-defined custom area types accessible via **Navigation > Areas** tab.

## NavMesh Static Queries

### SamplePosition

Find nearest point on NavMesh:

```csharp
NavMeshHit hit;
float maxDistance = 10f;
if (NavMesh.SamplePosition(worldPosition, out hit, maxDistance, NavMesh.AllAreas))
{
    Vector3 nearestPoint = hit.position;
    float distance = hit.distance;
    int areaMask = hit.mask;
}
```

### Raycast

Cast ray along NavMesh surface:

```csharp
NavMeshHit hit;
if (NavMesh.Raycast(startPos, endPos, out hit, NavMesh.AllAreas))
{
    // Hit an edge or boundary
    Vector3 hitPosition = hit.position;
    Vector3 hitNormal = hit.normal;
}
```

### CalculatePath

Compute path between two points:

```csharp
NavMeshPath path = new NavMeshPath();
if (NavMesh.CalculatePath(start, end, NavMesh.AllAreas, path))
{
    // path.corners contains waypoints
    // path.status indicates completeness
}
```

### GetAreaCost / SetAreaCost

```csharp
// Get cost for area index
float cost = NavMesh.GetAreaCost(areaIndex);

// Set custom cost (higher = more expensive to traverse)
NavMesh.SetAreaCost(3, 5.0f); // Area 3 costs 5x

// Get area index from name
int areaIndex = NavMesh.GetAreaFromName("Water");
```

## NavMeshModifier

Applied to GameObjects to override NavMesh baking behavior:

- **Override Area** -- Set a specific NavMesh area type for this object's geometry
- **Ignore From Build** -- Exclude this object from NavMesh generation entirely
- **Affected Agents** -- Specify which agent types are affected by this modifier
- **Apply To Children** -- Whether the modifier affects child GameObjects

## NavMeshModifierVolume

Defines a box volume that overrides area types for any geometry within it:

- **Size** -- Volume dimensions
- **Center** -- Volume center offset from transform
- **Area Type** -- Override area for all geometry within the volume
- **Affected Agents** -- Which agent types are affected

Useful for marking entire regions (e.g., marking a swamp area as high-cost without modifying individual objects).

## Navigation Areas and Costs

Areas define different terrain types with associated traversal costs:

| Area | Default Cost | Use Case |
|------|-------------|----------|
| Walkable | 1 | Normal ground |
| Not Walkable | N/A | Impassable |
| Jump | 2 | Off-mesh links |
| Custom (3-31) | User-defined | Water, mud, roads, etc. |

Higher costs make agents prefer alternative routes. Agents choose the lowest total cost path.

```csharp
// Example: Make agents avoid water
int waterArea = NavMesh.GetAreaFromName("Water");
NavMesh.SetAreaCost(waterArea, 10.0f);

// Agent area mask: exclude specific areas
agent.areaMask = NavMesh.AllAreas & ~(1 << waterArea);
```

## Common Patterns

### Patrol Between Points

```csharp
using UnityEngine;
using UnityEngine.AI;

public class Patrol : MonoBehaviour
{
    public Transform[] points;
    int destPoint = 0;
    NavMeshAgent agent;

    void Start()
    {
        agent = GetComponent<NavMeshAgent>();
        agent.autoBraking = false;
        GoToNextPoint();
    }

    void GoToNextPoint()
    {
        if (points.Length == 0) return;
        agent.destination = points[destPoint].position;
        destPoint = (destPoint + 1) % points.Length;
    }

    void Update()
    {
        if (!agent.pathPending && agent.remainingDistance < 0.5f)
            GoToNextPoint();
    }
}
```

### Flee From Target

```csharp
public void FleeFrom(Vector3 threatPosition, float fleeDistance)
{
    Vector3 fleeDirection = (transform.position - threatPosition).normalized;
    Vector3 fleeTarget = transform.position + fleeDirection * fleeDistance;

    NavMeshHit hit;
    if (NavMesh.SamplePosition(fleeTarget, out hit, fleeDistance, NavMesh.AllAreas))
    {
        agent.SetDestination(hit.position);
    }
}
```

### Group Formation

```csharp
public void MoveInFormation(Vector3 leaderTarget, Vector3 offset)
{
    Vector3 formationTarget = leaderTarget + offset;
    NavMeshHit hit;
    if (NavMesh.SamplePosition(formationTarget, out hit, 2f, NavMesh.AllAreas))
    {
        agent.SetDestination(hit.position);
    }
}
```

## Additional Resources

- [NavMesh Agent Scripting API](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshAgent.html)
- [NavMesh Surface](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshSurface.html)
- [NavMesh Obstacle](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshObstacle.html)
- [NavMesh Link](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshLink.html)
- [NavMesh Building Components](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshBuildingComponents.html)
