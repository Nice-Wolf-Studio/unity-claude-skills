---
name: unity-ai-navigation
description: >
  Unity 6 AI and navigation guide. Use when working with NavMesh, pathfinding, NavMeshAgent, NavMeshSurface, NavMeshObstacle, off-mesh links, or Unity Sentis (ML model inference). Covers AI navigation package, runtime NavMesh baking, and common AI patterns like state machines and behavior trees. Based on Unity 6.3 LTS documentation.
---

# Unity 6 AI and Navigation Guide

> Source: Unity 6.3 LTS Documentation (6000.3)

## AI Navigation Overview

**Package:** `com.unity.ai.navigation` (v2.0.11 for Unity 6000.3)

The AI Navigation package is a high-level component system that enables NavMesh-based navigation and pathfinding. It supports runtime and edit-time NavMesh construction, dynamic obstacle management, and link systems for specialized actions (jumping, doors).

### Core Components

| Component | Purpose |
|-----------|---------|
| NavMeshSurface | Defines and builds NavMesh for a specific agent type |
| NavMeshAgent | Character pathfinding and movement |
| NavMeshObstacle | Dynamic obstacle avoidance |
| NavMeshModifier | Affects NavMesh generation based on transform hierarchy |
| NavMeshModifierVolume | Affects NavMesh generation based on volume |
| NavMeshLink | Connects same or different NavMesh surfaces |

## NavMesh Setup

### Baking a NavMesh

1. Add a **NavMeshSurface** component to a GameObject
2. Configure the **Agent Type** (determines which agents can use this surface)
3. Set **Use Geometry** to Render Meshes or Physics Colliders
4. Configure **Collect Objects** mode (All, Volume, Current Hierarchy, NavMeshModifier only)
5. Click **Bake** or call `BuildNavMesh()` at runtime

### NavMeshSurface Properties

| Property | Description |
|----------|-------------|
| Agent Type | Which NavMesh Agent configuration can use this surface |
| Default Area | Walkable (default), Not Walkable, Jump, plus 29 custom types |
| Use Geometry | Render Meshes or Physics Colliders (colliders allow closer edge navigation) |
| Generate Links | Auto-creates connections between collected GameObjects during bake |
| Collect Objects | All GameObjects, Volume, Current Hierarchy, NavMeshModifier only |
| Include Layers | Filters GameObjects by layer (default: Everything) |

### Advanced Baking Parameters

| Parameter | Description |
|-----------|-------------|
| Override Voxel Size | Precision (default: 3 voxels per agent radius) |
| Override Tile Size | Tile dimensions (default: 256 voxels); smaller = better carving |
| Minimum Region Area | Removes disconnected mesh segments below threshold |
| Build Height Mesh | Generates elevation data for character placement |

The system excludes GameObjects with NavMeshAgent or NavMeshObstacle during baking.

### Runtime NavMesh Baking

```csharp
using UnityEngine;
using Unity.AI.Navigation;

public class RuntimeNavMeshBaker : MonoBehaviour
{
    NavMeshSurface surface;

    void Start()
    {
        surface = GetComponent<NavMeshSurface>();
        surface.BuildNavMesh();
    }

    public void RebakeNavMesh()
    {
        surface.UpdateNavMesh(surface.navMeshData);
    }
}
```

## NavMeshAgent

The NavMeshAgent component handles both pathfinding and movement control.

Add via: **Add Component > Navigation > NavMesh Agent**

### Basic Movement

```csharp
using UnityEngine;
using UnityEngine.AI;

public class MoveTo : MonoBehaviour
{
    public Transform goal;

    void Start()
    {
        NavMeshAgent agent = GetComponent<NavMeshAgent>();
        agent.destination = goal.position;
    }
}
```

### Agent Properties

**Steering:** Speed, Angular Speed, Acceleration, Stopping Distance, Auto Braking

**Obstacle Avoidance:** Radius, Height, Quality (None to High), Priority (0-99; lower = higher)

Agents avoid others of higher priority and ignore those of lower priority.

**Pathfinding:** Auto Traverse OffMesh Link, Auto Repath, Area Mask

### Agent Scripting Patterns

```csharp
using UnityEngine;
using UnityEngine.AI;

public class AIController : MonoBehaviour
{
    NavMeshAgent agent;

    void Start() { agent = GetComponent<NavMeshAgent>(); }

    public void MoveToTarget(Vector3 target) { agent.SetDestination(target); }

    bool HasReachedDestination()
    {
        if (!agent.pathPending
            && agent.remainingDistance <= agent.stoppingDistance
            && (!agent.hasPath || agent.velocity.sqrMagnitude == 0f))
            return true;
        return false;
    }

    public void StopMoving() { agent.isStopped = true; }
    public void ResumeMoving() { agent.isStopped = false; }
    public void WarpTo(Vector3 position) { agent.Warp(position); }
}
```

### Partial Paths

When a destination is unreachable, the agent generates a partial path to the nearest reachable location:

```csharp
if (agent.pathStatus == NavMeshPathStatus.PathPartial)
    Debug.Log("Destination unreachable, using partial path");
else if (agent.pathStatus == NavMeshPathStatus.PathInvalid)
    Debug.Log("No valid path found");
```

## NavMeshObstacle

Defines dynamic obstacles that agents avoid. Add via: **Add Component > Navigation > NavMesh Obstacle**

**Shapes:** Box (Center + Size) or Capsule (Center + Radius + Height)

### Carving

| Property | Description |
|----------|-------------|
| Move Threshold | Distance triggering update for moving obstacles |
| Time To Stationary | Seconds before classified as stationary |
| Carve Only Stationary | Only carve when not moving |

- **Carved:** Dynamically modify NavMesh topology (barrels, crates, doors)
- **Non-carved:** Exclusion zones without mesh modification (moving characters)

```csharp
using UnityEngine;
using UnityEngine.AI;

public class DynamicObstacle : MonoBehaviour
{
    NavMeshObstacle obstacle;

    void Start()
    {
        obstacle = GetComponent<NavMeshObstacle>();
        obstacle.carving = true;
        obstacle.carveOnlyStationary = true;
    }

    public void SetBlocking(bool blocking) { obstacle.enabled = blocking; }
}
```

## Off-Mesh Links (NavMeshLink)

Connects separate NavMesh surfaces. Use for doors, jump points, ledges, ladders.

Add via: **GameObject > AI > NavMesh Link** or **Add Component > Navigation > NavMesh Link**

| Property | Description |
|----------|-------------|
| Agent Type | Which agent type can traverse |
| Start/End Transform | GameObjects at link edges |
| Width | Link span width |
| Bidirectional | Two-way traversal |
| Area Type | Walkable, Not Walkable, or Jump |
| Activated | Controls link usability |

### Custom Link Traversal

```csharp
using UnityEngine;
using UnityEngine.AI;
using System.Collections;

public class CustomLinkTraversal : MonoBehaviour
{
    NavMeshAgent agent;

    void Start()
    {
        agent = GetComponent<NavMeshAgent>();
        agent.autoTraverseOffMeshLink = false;
    }

    void Update()
    {
        if (agent.isOnOffMeshLink) StartCoroutine(TraverseLink());
    }

    IEnumerator TraverseLink()
    {
        OffMeshLinkData linkData = agent.currentOffMeshLinkData;
        Vector3 startPos = agent.transform.position;
        Vector3 endPos = linkData.endPos + Vector3.up * agent.baseOffset;
        float elapsed = 0f, duration = 0.5f;

        while (elapsed < duration)
        {
            float t = elapsed / duration;
            agent.transform.position = Vector3.Lerp(startPos, endPos, t)
                + Vector3.up * Mathf.Sin(t * Mathf.PI) * 2f;
            elapsed += Time.deltaTime;
            yield return null;
        }
        agent.CompleteOffMeshLink();
    }
}
```

## Unity Sentis Overview

**Package:** `com.unity.sentis` (v2.1) -- now renamed **Inference Engine** (`com.unity.ai.inference`)

Neural network inference library for running ONNX models (opset 7-15) on GPU/CPU across all Unity platforms.

### Core Workflow

```csharp
using UnityEngine;
using Unity.Sentis;

public class MLInference : MonoBehaviour
{
    public ModelAsset modelAsset;
    Model runtimeModel;
    Worker worker;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);
    }

    void RunInference()
    {
        Tensor<float> input = TextureConverter.ToTensor(
            Resources.Load("image") as Texture2D);
        worker.Schedule(input);
        Tensor<float> output = worker.PeekOutput() as Tensor<float>;
        input.Dispose();
    }

    void OnDestroy() { worker?.Dispose(); }
}
```

### Backend Types

| Backend | Performance | Notes |
|---------|-------------|-------|
| GPUCompute | Fastest (GPU) | Check `SystemInfo.supportsComputeShaders` |
| CPU | Fastest (CPU) | Slow on WebGL (Burst to WASM) |
| GPUPixel | Slower | Fallback without compute shaders |

See `skills/unity-ai-navigation/references/sentis-ml.md` for full API details.

## Common AI Patterns

### Simple State Machine

```csharp
using UnityEngine;
using UnityEngine.AI;

public enum AIState { Idle, Patrol, Chase, Attack }

public class AIStateMachine : MonoBehaviour
{
    public AIState currentState = AIState.Idle;
    public Transform[] patrolPoints;
    public float chaseRange = 10f, attackRange = 2f;
    NavMeshAgent agent;
    Transform player;
    int patrolIndex;

    void Start()
    {
        agent = GetComponent<NavMeshAgent>();
        player = GameObject.FindWithTag("Player").transform;
    }

    void Update()
    {
        float dist = Vector3.Distance(transform.position, player.position);
        switch (currentState)
        {
            case AIState.Idle:
                if (dist < chaseRange) currentState = AIState.Chase;
                else if (patrolPoints.Length > 0) currentState = AIState.Patrol;
                break;
            case AIState.Patrol:
                agent.SetDestination(patrolPoints[patrolIndex].position);
                if (!agent.pathPending && agent.remainingDistance <= agent.stoppingDistance)
                    patrolIndex = (patrolIndex + 1) % patrolPoints.Length;
                if (dist < chaseRange) currentState = AIState.Chase;
                break;
            case AIState.Chase:
                agent.SetDestination(player.position);
                if (dist < attackRange) currentState = AIState.Attack;
                else if (dist > chaseRange * 1.5f) currentState = AIState.Patrol;
                break;
            case AIState.Attack:
                agent.isStopped = true;
                if (dist > attackRange) { agent.isStopped = false; currentState = AIState.Chase; }
                break;
        }
    }
}
```

### Behavior Tree Nodes

```csharp
public enum NodeState { Running, Success, Failure }

public abstract class BTNode { public abstract NodeState Evaluate(); }

public class Selector : BTNode
{
    BTNode[] children;
    public Selector(params BTNode[] children) { this.children = children; }
    public override NodeState Evaluate()
    {
        foreach (var child in children)
        {
            var result = child.Evaluate();
            if (result != NodeState.Failure) return result;
        }
        return NodeState.Failure;
    }
}

public class Sequence : BTNode
{
    BTNode[] children;
    public Sequence(params BTNode[] children) { this.children = children; }
    public override NodeState Evaluate()
    {
        foreach (var child in children)
        {
            var result = child.Evaluate();
            if (result != NodeState.Success) return result;
        }
        return NodeState.Success;
    }
}
```

### NavMesh Queries

```csharp
using UnityEngine;
using UnityEngine.AI;

public class NavMeshQueries : MonoBehaviour
{
    public Vector3 GetNearestNavMeshPoint(Vector3 pos, float maxDist)
    {
        NavMeshHit hit;
        return NavMesh.SamplePosition(pos, out hit, maxDist, NavMesh.AllAreas)
            ? hit.position : pos;
    }

    public bool IsOnNavMesh(Vector3 pos)
    {
        NavMeshHit hit;
        return NavMesh.SamplePosition(pos, out hit, 0.1f, NavMesh.AllAreas);
    }

    public bool CanReachTarget(Vector3 start, Vector3 end)
    {
        NavMeshPath path = new NavMeshPath();
        NavMesh.CalculatePath(start, end, NavMesh.AllAreas, path);
        return path.status == NavMeshPathStatus.PathComplete;
    }

    public Vector3 GetRandomNavMeshPoint(Vector3 center, float range)
    {
        Vector3 dir = Random.insideUnitSphere * range + center;
        NavMeshHit hit;
        return NavMesh.SamplePosition(dir, out hit, range, NavMesh.AllAreas)
            ? hit.position : center;
    }
}
```

## Anti-Patterns

- **Baking NavMesh every frame** -- `BuildNavMesh()` is expensive. Only call when geometry changes. Use `UpdateNavMesh()` for incremental updates.
- **Not checking pathStatus** -- Always check `agent.pathStatus`. Partial or invalid paths cause agents to get stuck silently.
- **Setting destination in Update without guard** -- Recalculating paths every frame wastes CPU. Only update when target moves significantly.
- **NavMeshObstacle on agents** -- Do not add NavMeshObstacle to GameObjects that also have NavMeshAgent. Agents already avoid each other.
- **Forgetting area masks** -- Agents without proper Area Mask may walk through restricted zones.
- **Carving everything** -- Carving is expensive. Use non-carving obstacles for things agents can path around naturally.
- **Missing NavMeshSurface** -- Without a NavMeshSurface, there is no NavMesh. Agents will not move.
- **Not disposing Sentis workers** -- Always call `worker.Dispose()` in `OnDestroy()`.
- **Using CPU backend on WebGL** -- Burst compiles to WASM, resulting in very slow ML inference.

## Key API Quick Reference

| Class | Namespace | Purpose |
|-------|-----------|---------|
| `NavMeshAgent` | UnityEngine.AI | Pathfinding and movement |
| `NavMeshObstacle` | UnityEngine.AI | Dynamic obstacle |
| `NavMesh` | UnityEngine.AI | Static queries and sampling |
| `NavMeshPath` | UnityEngine.AI | Calculated path data |
| `NavMeshHit` | UnityEngine.AI | Raycast/sample result |
| `NavMeshSurface` | Unity.AI.Navigation | NavMesh baking |
| `NavMeshModifier` | Unity.AI.Navigation | Per-object overrides |
| `NavMeshModifierVolume` | Unity.AI.Navigation | Volume-based overrides |
| `NavMeshLink` | Unity.AI.Navigation | Surface connections |
| `ModelAsset` | Unity.Sentis | ONNX model reference |
| `ModelLoader` | Unity.Sentis | Runtime model loading |
| `Worker` | Unity.Sentis | Inference engine |
| `BackendType` | Unity.Sentis | GPUCompute, CPU, GPUPixel |
| `Tensor<T>` | Unity.Sentis | Input/output data |

## Related Skills

- `unity-foundations` -- GameObject, components, scene hierarchy
- `unity-scripting` -- C# scripting patterns, MonoBehaviour lifecycle
- `unity-physics` -- Colliders, raycasting, physics integration with NavMesh

## Additional Resources

- [AI Navigation Package](https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.ai.navigation.html)
- [AI Navigation 2.0 Manual](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/index.html)
- [NavMeshAgent](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshAgent.html)
- [NavMeshSurface](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshSurface.html)
- [NavMeshObstacle](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshObstacle.html)
- [NavMeshLink](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/NavMeshLink.html)
- [Unity Sentis](https://docs.unity3d.com/Packages/com.unity.sentis@2.1/manual/index.html)
