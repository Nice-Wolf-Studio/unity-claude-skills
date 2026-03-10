---
name: unity-npc-behavior
description: >
  Unity NPC behavior design-to-code translation. Perception system architecture,
  decision layer patterns, action execution pipeline, faction & relationship systems,
  NPC memory & forgetting, crowd & squad coordination. DESIGN INTENT format:
  INTENT/WRONG/RIGHT/SCAFFOLD/DESIGN HOOK. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.asset"
---

# NPC Behavior -- Design Translation Patterns

> **Prerequisite skills:** `unity-physics-queries` (perception raycasts, NonAlloc query patterns), `unity-state-machines` (decision FSM/BT architecture), `unity-game-architecture` (event bus, Service Locator, component composition)

Claude's default NPC is a single MonoBehaviour with an `Update()` that raycasts, decides, and moves all in one method. This is untestable and unextensible -- changing perception logic requires touching decision logic, adding a new sense means rewriting the entire method, and squad coordination is impossible when each NPC is a self-contained island. These patterns decompose NPC behavior into pluggable layers that designers can configure without programmer intervention.

---

## PATTERN: Perception System Architecture

DESIGN INTENT: NPCs sense the world through sight, hearing, and proximity. Different NPC types have different senses -- a guard has long-range sight but poor hearing; a dog has short sight but exceptional hearing. Senses are mix-and-match components that feed a unified target list.

WRONG (Claude default):
```csharp
// Raycast inside decision code -- can't swap senses, no batching, untestable
public class EnemyAI : MonoBehaviour
{
    void Update()
    {
        // Perception and decision jammed together
        var dir = (player.position - transform.position).normalized;
        if (Physics.Raycast(transform.position, dir, out var hit, 20f))
        {
            if (hit.collider.CompareTag("Player"))
            {
                // Immediately decide and act -- no separation
                Chase(hit.collider.transform);
            }
        }
    }
}
```

RIGHT:
```csharp
/// <summary>
/// Pluggable sense interface. Each sense is a separate component on the NPC.
/// Cross-ref: unity-physics-queries for OverlapSphereNonAlloc and raycast patterns.
/// </summary>
public interface IPerceptionSense
{
    /// <summary>Evaluate targets within range. Called by PerceptionComponent on staggered schedule.</summary>
    void EvaluateTargets(Collider[] scratchBuffer, List<PerceivedTarget> results);

    /// <summary>Maximum range of this sense for broad-phase overlap sphere.</summary>
    float MaxRange { get; }
}

/// <summary>
/// Central perception hub. Collects results from all IPerceptionSense components.
/// Maintains a deduplicated KnownTargets list for the decision layer.
/// </summary>
public class PerceptionComponent : MonoBehaviour
{
    [SerializeField] private float _updateInterval = 0.2f;
    [SerializeField] private LayerMask _detectionLayers;

    private readonly List<PerceivedTarget> _knownTargets = new();
    private IPerceptionSense[] _senses;
    private readonly Collider[] _scratchBuffer = new Collider[32];

    public IReadOnlyList<PerceivedTarget> KnownTargets => _knownTargets;
}
```

SCAFFOLD (full implementation):
```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>Data class representing a target detected by a perception sense.</summary>
[Serializable]
public class PerceivedTarget
{
    /// <summary>The transform of the detected target.</summary>
    public Transform Transform;

    /// <summary>Last known world-space position of the target.</summary>
    public Vector3 LastKnownPosition;

    /// <summary>Normalized awareness level (0 = barely noticed, 1 = fully aware).</summary>
    public float Awareness;

    /// <summary>Time.time when this target was last perceived.</summary>
    public float LastSeenTime;

    /// <summary>Which sense detected this target.</summary>
    public string SenseType;
}

/// <summary>
/// Pluggable sense interface. Attach multiple senses as components on the NPC GameObject.
/// </summary>
public interface IPerceptionSense
{
    /// <summary>Evaluate nearby colliders and populate results with perceived targets.</summary>
    void EvaluateTargets(Collider[] scratchBuffer, List<PerceivedTarget> results);

    /// <summary>Maximum detection range for this sense.</summary>
    float MaxRange { get; }
}

/// <summary>
/// Central perception component. Gathers all IPerceptionSense components, staggers
/// updates to avoid per-frame cost, and maintains a deduplicated known-targets list.
/// </summary>
public class PerceptionComponent : MonoBehaviour
{
    [SerializeField] private float _updateInterval = 0.2f;
    [SerializeField] private LayerMask _detectionLayers;

    private readonly List<PerceivedTarget> _knownTargets = new();
    private IPerceptionSense[] _senses;
    private readonly Collider[] _scratchBuffer = new Collider[32];
    private float _nextUpdateTime;

    /// <summary>All currently perceived targets.</summary>
    public IReadOnlyList<PerceivedTarget> KnownTargets => _knownTargets;

    /// <summary>Event raised when a new target is first detected.</summary>
    public event Action<PerceivedTarget> OnTargetDetected;

    /// <summary>Event raised when a target is lost (no sense detects it).</summary>
    public event Action<PerceivedTarget> OnTargetLost;

    void Awake()
    {
        _senses = GetComponents<IPerceptionSense>();
        // Stagger start time so NPCs don't all update on the same frame
        _nextUpdateTime = Time.time + UnityEngine.Random.Range(0f, _updateInterval);
    }

    void Update()
    {
        if (Time.time < _nextUpdateTime) return;
        _nextUpdateTime = Time.time + _updateInterval;

        var previousTargets = new List<PerceivedTarget>(_knownTargets);
        _knownTargets.Clear();

        foreach (var sense in _senses)
        {
            sense.EvaluateTargets(_scratchBuffer, _knownTargets);
        }

        // Deduplicate by Transform
        DeduplicateTargets();

        // Fire events
        foreach (var target in _knownTargets)
        {
            if (previousTargets.Find(t => t.Transform == target.Transform) == null)
                OnTargetDetected?.Invoke(target);
        }
        foreach (var prev in previousTargets)
        {
            if (_knownTargets.Find(t => t.Transform == prev.Transform) == null)
                OnTargetLost?.Invoke(prev);
        }
    }

    private void DeduplicateTargets()
    {
        for (int i = _knownTargets.Count - 1; i >= 0; i--)
        {
            for (int j = i - 1; j >= 0; j--)
            {
                if (_knownTargets[i].Transform == _knownTargets[j].Transform)
                {
                    // Keep the one with higher awareness
                    if (_knownTargets[i].Awareness > _knownTargets[j].Awareness)
                        _knownTargets[j] = _knownTargets[i];
                    _knownTargets.RemoveAt(i);
                    break;
                }
            }
        }
    }
}

/// <summary>
/// Sight sense: FOV cone check + line-of-sight raycast.
/// Uses OverlapSphereNonAlloc (see unity-physics-queries).
/// </summary>
public class SightSense : MonoBehaviour, IPerceptionSense
{
    [SerializeField] private float _range = 20f;
    [SerializeField] private float _fovAngle = 120f;
    [SerializeField] private LayerMask _targetLayers;
    [SerializeField] private LayerMask _obstacleLayers;
    [SerializeField] private Transform _eyePoint;

    /// <inheritdoc/>
    public float MaxRange => _range;

    /// <inheritdoc/>
    public void EvaluateTargets(Collider[] scratchBuffer, List<PerceivedTarget> results)
    {
        var origin = _eyePoint != null ? _eyePoint.position : transform.position;
        int count = Physics.OverlapSphereNonAlloc(origin, _range, scratchBuffer, _targetLayers);

        for (int i = 0; i < count; i++)
        {
            var targetPos = scratchBuffer[i].transform.position;
            var dir = (targetPos - origin).normalized;

            // FOV check
            if (Vector3.Angle(transform.forward, dir) > _fovAngle * 0.5f)
                continue;

            float dist = Vector3.Distance(origin, targetPos);

            // LOS raycast
            if (Physics.Raycast(origin, dir, out var hit, dist, _obstacleLayers | _targetLayers))
            {
                if (hit.collider == scratchBuffer[i])
                {
                    results.Add(new PerceivedTarget
                    {
                        Transform = scratchBuffer[i].transform,
                        LastKnownPosition = targetPos,
                        Awareness = 1f - (dist / _range), // Closer = higher awareness
                        LastSeenTime = Time.time,
                        SenseType = "Sight"
                    });
                }
            }
        }
    }
}
```

DESIGN HOOK: New senses = new `IPerceptionSense` MonoBehaviour on the NPC prefab. Configure range, angle, update rate, and target layers per sense. `PerceptionComponent` auto-discovers senses via `GetComponents`.

GOTCHA: Perception queries are expensive. The `_updateInterval` staggers updates so not every NPC queries every frame. With 50 NPCs at 0.2s interval, only ~5 run per frame instead of 50. Also: `OverlapSphereNonAlloc` requires a pre-allocated buffer -- size it for your max expected nearby targets.

---

## PATTERN: Decision Layer Patterns

DESIGN INTENT: Different NPC archetypes (aggressive, cautious, cowardly) share the same perception but differ in decisions. A guard and a civilian both see the player -- the guard attacks, the civilian flees. Decision logic is data-driven per archetype.

WRONG (Claude default):
```csharp
// Decision logic jammed into perception callback -- can't vary by archetype
void OnTargetDetected(PerceivedTarget target)
{
    float dist = Vector3.Distance(transform.position, target.LastKnownPosition);
    if (dist < 5f)
        Attack(target.Transform);
    else if (dist < 15f)
        Chase(target.Transform);
    else
        Patrol();
}
```

RIGHT:
```csharp
/// <summary>
/// Clean 3-layer separation: Perception -> Blackboard -> Decision -> Action.
/// Decision profiles are ScriptableObject configs per archetype.
/// Cross-ref: unity-state-machines for FSM/BT implementation.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Decision Profile")]
public class DecisionProfile : ScriptableObject
{
    /// <summary>Distance at which NPC engages in combat.</summary>
    public float AggroRange = 10f;

    /// <summary>Distance at which NPC flees.</summary>
    public float FleeRange = 3f;

    /// <summary>Minimum awareness level to act on a target.</summary>
    public float AwarenessThreshold = 0.3f;

    /// <summary>Should this NPC call for help when engaging?</summary>
    public bool CallsForHelp = false;

    /// <summary>Preferred combat distance (0 = melee, higher = ranged).</summary>
    public float PreferredCombatDistance = 2f;
}
```

SCAFFOLD (full implementation):
```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Per-NPC-instance data store. Perception writes, Decision reads.
/// Plain C# class -- testable without MonoBehaviour.
/// </summary>
public class NPCBlackboard
{
    // Common key constants
    public const string KEY_PRIMARY_TARGET = "PrimaryTarget";
    public const string KEY_THREAT_LEVEL = "ThreatLevel";
    public const string KEY_LAST_KNOWN_POS = "LastKnownPosition";
    public const string KEY_HEALTH_PERCENT = "HealthPercent";
    public const string KEY_ALLIES_NEARBY = "AlliesNearby";

    private readonly Dictionary<string, object> _data = new();

    /// <summary>Set a typed value on the blackboard.</summary>
    public void Set<T>(string key, T value) => _data[key] = value;

    /// <summary>Get a typed value. Returns default if key missing.</summary>
    public T Get<T>(string key, T fallback = default)
    {
        return _data.TryGetValue(key, out var val) && val is T typed ? typed : fallback;
    }

    /// <summary>Check if a key exists.</summary>
    public bool Has(string key) => _data.ContainsKey(key);

    /// <summary>Remove a key from the blackboard.</summary>
    public void Clear(string key) => _data.Remove(key);

    /// <summary>Remove all data.</summary>
    public void ClearAll() => _data.Clear();
}

/// <summary>
/// Decision-making component. Reads perception via blackboard, selects behavior
/// based on DecisionProfile. Drives a state machine (see unity-state-machines).
/// </summary>
public class NPCDecisionMaker : MonoBehaviour
{
    [SerializeField] private DecisionProfile _profile;
    [SerializeField] private PerceptionComponent _perception;

    private NPCBlackboard _blackboard;

    /// <summary>The NPC's blackboard instance.</summary>
    public NPCBlackboard Blackboard => _blackboard;

    /// <summary>Event raised when a decision is made.</summary>
    public event Action<string> OnDecision;

    void Awake()
    {
        _blackboard = new NPCBlackboard();
    }

    void Update()
    {
        UpdateBlackboard();
        EvaluateDecision();
    }

    private void UpdateBlackboard()
    {
        var targets = _perception.KnownTargets;
        if (targets.Count > 0)
        {
            var primary = targets[0]; // Highest awareness after dedup
            _blackboard.Set(NPCBlackboard.KEY_PRIMARY_TARGET, primary.Transform);
            _blackboard.Set(NPCBlackboard.KEY_LAST_KNOWN_POS, primary.LastKnownPosition);
            _blackboard.Set(NPCBlackboard.KEY_THREAT_LEVEL, primary.Awareness);
        }
        else
        {
            _blackboard.Clear(NPCBlackboard.KEY_PRIMARY_TARGET);
            _blackboard.Clear(NPCBlackboard.KEY_THREAT_LEVEL);
        }
    }

    private void EvaluateDecision()
    {
        float threat = _blackboard.Get<float>(NPCBlackboard.KEY_THREAT_LEVEL);
        var target = _blackboard.Get<Transform>(NPCBlackboard.KEY_PRIMARY_TARGET);

        if (target == null)
        {
            OnDecision?.Invoke("Patrol");
            return;
        }

        float dist = Vector3.Distance(transform.position, target.position);

        if (threat < _profile.AwarenessThreshold)
        {
            OnDecision?.Invoke("Suspicious");
        }
        else if (dist < _profile.FleeRange)
        {
            OnDecision?.Invoke("Flee");
        }
        else if (dist < _profile.AggroRange)
        {
            if (_profile.CallsForHelp)
                OnDecision?.Invoke("CallForHelp");
            OnDecision?.Invoke("Engage");
        }
        else
        {
            OnDecision?.Invoke("Investigate");
        }
    }
}
```

DESIGN HOOK: New NPC archetypes = new `DecisionProfile` ScriptableObject asset. A "coward" profile sets `FleeRange = 15f, AggroRange = 0f`. A "berserker" sets `FleeRange = 0f, AggroRange = 30f`. No code changes.

GOTCHA: `NPCBlackboard` must be a per-NPC class instance, never a struct (value-type copying breaks shared references) and never static (all NPCs would share one brain). Allocate in `Awake()`.

---

## PATTERN: Action Execution Pipeline

DESIGN INTENT: Once an NPC decides to attack, the action plays out with wind-up animation, strike timing, damage application, and recovery. Actions can be interrupted mid-execution (enemy staggers during wind-up). Actions are not instantaneous.

WRONG (Claude default):
```csharp
// Instant execution in decision tick -- no wind-up, no animation, no interruption
void OnDecision(string decision)
{
    if (decision == "Engage")
    {
        target.GetComponent<Health>().TakeDamage(10); // Instant!
        _animator.Play("Attack"); // Animation is cosmetic afterthought
    }
}
```

RIGHT:
```csharp
/// <summary>
/// Action lifecycle interface. Actions own their execution duration,
/// animation triggers, and exit conditions.
/// </summary>
public interface INPCAction
{
    /// <summary>Called when action begins. Set up animation, timers.</summary>
    void Enter(NPCActionContext context);

    /// <summary>Called each frame while action is active. Returns true when complete.</summary>
    bool Tick(NPCActionContext context, float deltaTime);

    /// <summary>Called when action ends (naturally or via interruption).</summary>
    void Exit(NPCActionContext context, bool wasInterrupted);

    /// <summary>Whether this action can be interrupted by a higher-priority action.</summary>
    bool CanInterrupt { get; }
}

/// <summary>Shared context passed to actions.</summary>
public class NPCActionContext
{
    public Transform Self;
    public Transform Target;
    public Animator Animator;
    public NPCBlackboard Blackboard;
}
```

SCAFFOLD (full implementation):
```csharp
using UnityEngine;

/// <summary>
/// Manages the current action lifecycle. Handles transitions and interruption.
/// </summary>
public class ActionExecutor : MonoBehaviour
{
    private INPCAction _currentAction;
    private NPCActionContext _context;

    /// <summary>Whether an action is currently executing.</summary>
    public bool IsExecuting => _currentAction != null;

    /// <summary>The currently executing action, if any.</summary>
    public INPCAction CurrentAction => _currentAction;

    void Awake()
    {
        _context = new NPCActionContext
        {
            Self = transform,
            Animator = GetComponentInChildren<Animator>()
        };
    }

    /// <summary>Inject blackboard reference after creation.</summary>
    public void Initialize(NPCBlackboard blackboard)
    {
        _context.Blackboard = blackboard;
    }

    /// <summary>Begin a new action. Interrupts current if allowed.</summary>
    public bool Execute(INPCAction action, Transform target = null)
    {
        if (_currentAction != null)
        {
            if (!_currentAction.CanInterrupt) return false;
            _currentAction.Exit(_context, wasInterrupted: true);
        }

        _context.Target = target;
        _currentAction = action;
        _currentAction.Enter(_context);
        return true;
    }

    /// <summary>Force-cancel the current action.</summary>
    public void Cancel()
    {
        if (_currentAction != null)
        {
            _currentAction.Exit(_context, wasInterrupted: true);
            _currentAction = null;
        }
    }

    void Update()
    {
        if (_currentAction == null) return;

        bool complete = _currentAction.Tick(_context, Time.deltaTime);
        if (complete)
        {
            _currentAction.Exit(_context, wasInterrupted: false);
            _currentAction = null;
        }
    }
}

/// <summary>
/// Melee attack with 3 phases: wind-up, strike, recovery.
/// Damage only applies during strike phase.
/// </summary>
public class MeleeAttackAction : INPCAction
{
    private enum Phase { WindUp, Strike, Recovery }

    private readonly float _windUpDuration;
    private readonly float _strikeDuration;
    private readonly float _recoveryDuration;
    private readonly float _damage;
    private readonly float _strikeRange;

    private Phase _phase;
    private float _phaseTimer;
    private bool _damageApplied;

    /// <inheritdoc/>
    public bool CanInterrupt => _phase == Phase.WindUp; // Only interruptible during wind-up

    public MeleeAttackAction(float windUp = 0.3f, float strike = 0.15f,
                              float recovery = 0.4f, float damage = 10f, float range = 2f)
    {
        _windUpDuration = windUp;
        _strikeDuration = strike;
        _recoveryDuration = recovery;
        _damage = damage;
        _strikeRange = range;
    }

    /// <inheritdoc/>
    public void Enter(NPCActionContext context)
    {
        _phase = Phase.WindUp;
        _phaseTimer = 0f;
        _damageApplied = false;
        context.Animator?.SetTrigger("MeleeWindUp");
    }

    /// <inheritdoc/>
    public bool Tick(NPCActionContext context, float deltaTime)
    {
        _phaseTimer += deltaTime;

        switch (_phase)
        {
            case Phase.WindUp:
                if (_phaseTimer >= _windUpDuration)
                {
                    _phase = Phase.Strike;
                    _phaseTimer = 0f;
                    context.Animator?.SetTrigger("MeleeStrike");
                }
                break;

            case Phase.Strike:
                if (!_damageApplied && context.Target != null)
                {
                    float dist = Vector3.Distance(
                        context.Self.position, context.Target.position);
                    if (dist <= _strikeRange)
                    {
                        // Apply damage only once, only if in range
                        var health = context.Target.GetComponent<Health>();
                        health?.TakeDamage(_damage);
                        _damageApplied = true;
                    }
                }
                if (_phaseTimer >= _strikeDuration)
                {
                    _phase = Phase.Recovery;
                    _phaseTimer = 0f;
                    context.Animator?.SetTrigger("MeleeRecover");
                }
                break;

            case Phase.Recovery:
                if (_phaseTimer >= _recoveryDuration)
                    return true; // Action complete
                break;
        }

        return false;
    }

    /// <inheritdoc/>
    public void Exit(NPCActionContext context, bool wasInterrupted)
    {
        if (wasInterrupted && !_damageApplied)
        {
            // Interrupted before damage -- no damage applied (design intent)
            context.Animator?.SetTrigger("Interrupted");
        }
    }
}
```

DESIGN HOOK: New actions implement `INPCAction`. Timing values (wind-up, strike, recovery) belong on a ScriptableObject config. Animation event names are string constants -- keep them in a shared `AnimationKeys` class.

GOTCHA: If interrupted during wind-up, damage must NOT apply. The `Exit(wasInterrupted: true)` path must cancel any pending damage. Test this case explicitly.

---

## PATTERN: Faction & Relationship System

DESIGN INTENT: NPCs belong to factions with configurable relationships. Guards are hostile to bandits, neutral to civilians, friendly to other guards. Relationships can change at runtime (betrayal, alliance shifts). Perception filters results by faction stance.

WRONG (Claude default):
```csharp
// Hardcoded tag checks -- adding a new faction means editing every NPC script
void OnPerceiveTarget(PerceivedTarget target)
{
    if (target.Transform.CompareTag("Player")) Attack();
    else if (target.Transform.CompareTag("Bandit")) Attack();
    else if (target.Transform.CompareTag("Guard")) Ignore();
    // Every new faction = more if/else here
}
```

RIGHT:
```csharp
/// <summary>
/// Faction identity. ScriptableObject asset per faction.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Faction")]
public class Faction : ScriptableObject
{
    /// <summary>Display name for UI.</summary>
    public string DisplayName;

    /// <summary>Faction color for debug gizmos.</summary>
    public Color DebugColor = Color.white;
}

/// <summary>
/// Centralized relationship matrix. One asset for the entire game.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Faction Database")]
public class FactionDatabase : ScriptableObject
{
    // Relationship lookup driven by SO references, not strings or tags.
    public Relationship GetRelationship(Faction a, Faction b) { /* ... */ }
    public void SetRelationship(Faction a, Faction b, Relationship r) { /* ... */ }
}
```

SCAFFOLD (full implementation):
```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>Relationship stance between two factions.</summary>
public enum Relationship { Hostile, Neutral, Friendly }

/// <summary>Faction identity asset.</summary>
[CreateAssetMenu(menuName = "NPC/Faction")]
public class Faction : ScriptableObject
{
    /// <summary>Display name for UI and debug.</summary>
    public string DisplayName;

    /// <summary>Color used in debug gizmos and minimap.</summary>
    public Color DebugColor = Color.white;
}

/// <summary>
/// Stores a relationship between two factions.
/// </summary>
[Serializable]
public class FactionRelationship
{
    public Faction FactionA;
    public Faction FactionB;
    public Relationship Stance = Relationship.Neutral;
}

/// <summary>
/// Central faction database. One instance for the game.
/// Designers edit the relationship list in the Inspector.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Faction Database")]
public class FactionDatabase : ScriptableObject
{
    [SerializeField] private List<FactionRelationship> _relationships = new();
    [SerializeField] private Relationship _defaultRelationship = Relationship.Neutral;

    // Runtime overrides (betrayal, alliance shifts)
    private Dictionary<(Faction, Faction), Relationship> _runtimeOverrides;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { /* No statics to reset in this SO */ }

    /// <summary>Get the relationship between two factions. Checks runtime overrides first.</summary>
    public Relationship GetRelationship(Faction a, Faction b)
    {
        if (a == b) return Relationship.Friendly;

        // Check runtime overrides
        if (_runtimeOverrides != null)
        {
            if (_runtimeOverrides.TryGetValue((a, b), out var overrideR)) return overrideR;
            if (_runtimeOverrides.TryGetValue((b, a), out var overrideR2)) return overrideR2;
        }

        // Check authored relationships (bidirectional)
        foreach (var rel in _relationships)
        {
            if ((rel.FactionA == a && rel.FactionB == b) ||
                (rel.FactionA == b && rel.FactionB == a))
                return rel.Stance;
        }

        return _defaultRelationship;
    }

    /// <summary>Change a relationship at runtime (e.g., betrayal event).</summary>
    public void SetRelationshipRuntime(Faction a, Faction b, Relationship stance)
    {
        _runtimeOverrides ??= new Dictionary<(Faction, Faction), Relationship>();
        _runtimeOverrides[(a, b)] = stance;
    }

    /// <summary>Clear all runtime relationship overrides.</summary>
    public void ClearRuntimeOverrides()
    {
        _runtimeOverrides?.Clear();
    }
}

/// <summary>
/// Component that identifies an entity's faction membership.
/// Attach to any GameObject that participates in the faction system.
/// </summary>
public class FactionMember : MonoBehaviour
{
    [SerializeField] private Faction _faction;
    [SerializeField] private FactionDatabase _database;

    /// <summary>This entity's faction.</summary>
    public Faction Faction => _faction;

    /// <summary>Get this entity's relationship to another faction member.</summary>
    public Relationship GetRelationshipTo(FactionMember other)
    {
        return _database.GetRelationship(_faction, other._faction);
    }

    /// <summary>Check if another entity is hostile.</summary>
    public bool IsHostileTo(FactionMember other)
    {
        return GetRelationshipTo(other) == Relationship.Hostile;
    }

    /// <summary>Check if another entity is friendly.</summary>
    public bool IsFriendlyTo(FactionMember other)
    {
        return GetRelationshipTo(other) == Relationship.Friendly;
    }
}
```

DESIGN HOOK: Designers edit the faction relationship matrix in the Inspector on the `FactionDatabase` asset. Runtime events (quest completion, story beats) call `SetRelationshipRuntime` to shift alliances. Perception filtering uses `FactionMember.IsHostileTo()` to decide whether a detected target is a threat.

GOTCHA: Relationship lookup must be bidirectional. If you define Guards->Bandits as Hostile but forget Bandits->Guards, the database falls back to the default. The `GetRelationship` implementation checks both orderings, but designers should still define both explicitly for clarity. Also: runtime overrides are lost on domain reload -- persist them in your save system if needed.

---

## PATTERN: NPC Memory & Forgetting

DESIGN INTENT: NPCs remember where they last saw the player, heard a noise, or were attacked. But memories fade -- if the player hides for 30 seconds, the guard stops searching and returns to patrol. Different NPCs have different memory spans (elite guards remember longer). Memory drives investigation behavior: NPCs go to the LAST KNOWN position, not the current one.

WRONG (Claude default):
```csharp
// Boolean that never resets -- NPC has perfect memory forever
private bool _hasSeenPlayer = false;

void Update()
{
    if (_hasSeenPlayer)
        ChasePlayer(); // Chases forever, even if player hid 5 minutes ago
}
```

RIGHT:
```csharp
/// <summary>
/// Timestamped memory entry. Confidence decays over time.
/// Position is a world-space snapshot -- it does NOT track the target's current position.
/// </summary>
public struct MemoryEntry
{
    public string StimulusType; // "Sight", "Sound", "Damage"
    public Vector3 Position;     // Where it happened (snapshot, not tracked)
    public float Confidence;     // 1.0 = certain, decays toward 0
    public float Timestamp;      // Time.time when recorded
    public Transform Source;     // Original source (may be null if forgotten)
}
```

SCAFFOLD (full implementation):
```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Timestamped memory record. Position is a world-space snapshot at time of perception.
/// </summary>
public struct MemoryEntry
{
    /// <summary>Type of stimulus that created this memory.</summary>
    public string StimulusType;

    /// <summary>World-space position where stimulus occurred (snapshot, not tracked).</summary>
    public Vector3 Position;

    /// <summary>Current confidence level. Decays over time from 1.0 toward 0.</summary>
    public float Confidence;

    /// <summary>Time.time when this memory was created or last refreshed.</summary>
    public float Timestamp;

    /// <summary>The source transform, if still valid. May become null.</summary>
    public Transform Source;
}

/// <summary>
/// Configuration for memory behavior. Per-archetype ScriptableObject.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Memory Config")]
public class MemoryConfig : ScriptableObject
{
    /// <summary>How many seconds until a memory fully decays.</summary>
    public float MemoryDuration = 30f;

    /// <summary>Confidence below this threshold triggers memory pruning.</summary>
    public float PruneThreshold = 0.05f;

    /// <summary>Maximum number of memories to retain.</summary>
    public int MaxMemories = 20;
}

/// <summary>
/// NPC memory system. Stores timestamped memories with confidence decay.
/// Memories drive investigation behavior -- NPC goes to remembered position,
/// not the target's current position.
/// </summary>
public class NPCMemory
{
    private readonly List<MemoryEntry> _memories = new();
    private readonly MemoryConfig _config;

    public NPCMemory(MemoryConfig config)
    {
        _config = config;
    }

    /// <summary>All current memories.</summary>
    public IReadOnlyList<MemoryEntry> Memories => _memories;

    /// <summary>Record a new memory or refresh an existing one from the same source.</summary>
    public void Remember(string stimulusType, Vector3 position, Transform source = null)
    {
        // Refresh existing memory from same source
        for (int i = 0; i < _memories.Count; i++)
        {
            if (_memories[i].Source != null && _memories[i].Source == source)
            {
                _memories[i] = new MemoryEntry
                {
                    StimulusType = stimulusType,
                    Position = position,
                    Confidence = 1f,
                    Timestamp = Time.time,
                    Source = source
                };
                return;
            }
        }

        // Add new memory
        if (_memories.Count >= _config.MaxMemories)
            _memories.RemoveAt(0); // Remove oldest

        _memories.Add(new MemoryEntry
        {
            StimulusType = stimulusType,
            Position = position,
            Confidence = 1f,
            Timestamp = Time.time,
            Source = source
        });
    }

    /// <summary>Query the most confident memory of a given stimulus type.</summary>
    public bool TryGetBestMemory(string stimulusType, out MemoryEntry best)
    {
        best = default;
        float bestConfidence = 0f;

        foreach (var mem in _memories)
        {
            if (mem.StimulusType == stimulusType && mem.Confidence > bestConfidence)
            {
                best = mem;
                bestConfidence = mem.Confidence;
            }
        }

        return bestConfidence > 0f;
    }

    /// <summary>Decay all memories and prune expired ones. Call once per decision tick.</summary>
    public void DecayAndPrune()
    {
        for (int i = _memories.Count - 1; i >= 0; i--)
        {
            float age = Time.time - _memories[i].Timestamp;
            float newConfidence = Mathf.Clamp01(1f - (age / _config.MemoryDuration));

            if (newConfidence <= _config.PruneThreshold)
            {
                _memories.RemoveAt(i);
            }
            else
            {
                var entry = _memories[i];
                entry.Confidence = newConfidence;
                _memories[i] = entry;
            }
        }
    }

    /// <summary>Forget all memories.</summary>
    public void ForgetAll() => _memories.Clear();
}
```

DESIGN HOOK: Memory duration and decay rate on `MemoryConfig` SO per archetype. Elite guards get 60s memory; basic enemies get 15s. Integrate with blackboard: when best memory confidence drops below threshold, NPC switches from "Search" to "ReturnToPatrol."

GOTCHA: Memory positions are world-space snapshots, NOT live references. When the NPC acts on a memory, it investigates the OLD position. This is intentional -- it creates search behavior. If the player moved, the NPC arrives at an empty spot and must re-perceive. Do NOT "fix" this by updating memory positions to track the target.

---

## PATTERN: Crowd & Squad Coordination

DESIGN INTENT: Multiple NPCs coordinate tactically. A group of enemies doesn't all pathfind to the same point and stack on top of each other. Instead, a coordinator assigns tactical roles: one flanks left, one flanks right, one suppresses from range. When squad members die, roles are reassigned dynamically.

WRONG (Claude default):
```csharp
// Every NPC independently pathfinds to player -- they all pile up on the same spot
void OnEngageTarget(Transform target)
{
    _navAgent.SetDestination(target.position); // All 10 enemies go to exact same point
}
```

RIGHT:
```csharp
/// <summary>
/// Coordinates a squad of NPCs. Assigns tactical roles and spread positions.
/// Cross-ref: unity-ai-navigation for NavMesh position sampling.
/// </summary>
public class SquadCoordinator : MonoBehaviour
{
    // Manages role assignment, tactical positioning, and group awareness.
    // Squad members register/unregister dynamically (spawns, deaths).
}
```

SCAFFOLD (full implementation):
```csharp
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

/// <summary>Tactical role within a squad.</summary>
public enum TacticalRole
{
    /// <summary>Leads the engagement, draws attention.</summary>
    Leader,
    /// <summary>Approaches from the side.</summary>
    Flanker,
    /// <summary>Keeps distance, provides ranged pressure.</summary>
    Suppressor,
    /// <summary>Holds position, waits for opening.</summary>
    Reserve
}

/// <summary>
/// Squad-level tactical profile. Configures how the squad behaves as a unit.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Squad Tactics")]
public class SquadTactics : ScriptableObject
{
    /// <summary>Minimum spacing between squad members in meters.</summary>
    public float MinSpacing = 3f;

    /// <summary>Maximum squad engagement radius from target.</summary>
    public float EngagementRadius = 15f;

    /// <summary>How many flankers relative to squad size (0-1).</summary>
    [Range(0f, 1f)] public float FlankerRatio = 0.3f;

    /// <summary>How many suppressors relative to squad size (0-1).</summary>
    [Range(0f, 1f)] public float SuppressorRatio = 0.2f;
}

/// <summary>
/// Shared awareness for the squad. Members read and write group-level data.
/// </summary>
public class SquadBlackboard
{
    /// <summary>Current primary target for the squad.</summary>
    public Transform PrimaryTarget;

    /// <summary>Last known position of the primary target.</summary>
    public Vector3 LastKnownTargetPosition;

    /// <summary>Whether the squad is in active combat.</summary>
    public bool InCombat;

    /// <summary>Assigned positions per member.</summary>
    public readonly Dictionary<Transform, Vector3> AssignedPositions = new();
}

/// <summary>
/// Coordinates a squad of NPCs. Assigns tactical roles and spread positions.
/// Squad members register/unregister as they spawn or die.
/// </summary>
public class SquadCoordinator : MonoBehaviour
{
    [SerializeField] private SquadTactics _tactics;

    private readonly List<Transform> _members = new();
    private readonly Dictionary<Transform, TacticalRole> _roles = new();
    private readonly SquadBlackboard _blackboard = new();

    /// <summary>The squad's shared blackboard.</summary>
    public SquadBlackboard Blackboard => _blackboard;

    /// <summary>Current squad size.</summary>
    public int MemberCount => _members.Count;

    /// <summary>Register a new squad member.</summary>
    public void RegisterMember(Transform member)
    {
        if (_members.Contains(member)) return;
        _members.Add(member);
        ReassignRoles();
    }

    /// <summary>Unregister a squad member (death, despawn).</summary>
    public void UnregisterMember(Transform member)
    {
        _members.Remove(member);
        _roles.Remove(member);
        _blackboard.AssignedPositions.Remove(member);
        ReassignRoles();
    }

    /// <summary>Get the assigned role for a squad member.</summary>
    public TacticalRole GetRole(Transform member)
    {
        return _roles.TryGetValue(member, out var role) ? role : TacticalRole.Reserve;
    }

    /// <summary>Get the assigned tactical position for a squad member.</summary>
    public Vector3 GetAssignedPosition(Transform member)
    {
        return _blackboard.AssignedPositions.TryGetValue(member, out var pos)
            ? pos
            : member.position;
    }

    /// <summary>Set the squad's target and update tactical positions.</summary>
    public void EngageTarget(Transform target)
    {
        _blackboard.PrimaryTarget = target;
        _blackboard.LastKnownTargetPosition = target.position;
        _blackboard.InCombat = true;
        UpdateTacticalPositions();
    }

    /// <summary>Disengage -- clear target and return to passive behavior.</summary>
    public void Disengage()
    {
        _blackboard.PrimaryTarget = null;
        _blackboard.InCombat = false;
        _blackboard.AssignedPositions.Clear();
    }

    private void ReassignRoles()
    {
        _roles.Clear();
        if (_members.Count == 0) return;

        int flankerCount = Mathf.Max(0, Mathf.FloorToInt(_members.Count * _tactics.FlankerRatio));
        int suppressorCount = Mathf.Max(0, Mathf.FloorToInt(_members.Count * _tactics.SuppressorRatio));

        int idx = 0;

        // First member is leader
        if (idx < _members.Count)
            _roles[_members[idx++]] = TacticalRole.Leader;

        // Assign flankers
        for (int i = 0; i < flankerCount && idx < _members.Count; i++)
            _roles[_members[idx++]] = TacticalRole.Flanker;

        // Assign suppressors
        for (int i = 0; i < suppressorCount && idx < _members.Count; i++)
            _roles[_members[idx++]] = TacticalRole.Suppressor;

        // Remainder are reserve
        while (idx < _members.Count)
            _roles[_members[idx++]] = TacticalRole.Reserve;

        if (_blackboard.InCombat)
            UpdateTacticalPositions();
    }

    private void UpdateTacticalPositions()
    {
        if (_blackboard.PrimaryTarget == null) return;

        var targetPos = _blackboard.PrimaryTarget.position;
        _blackboard.AssignedPositions.Clear();

        foreach (var member in _members)
        {
            var role = GetRole(member);
            Vector3 desiredPos = role switch
            {
                TacticalRole.Leader => targetPos +
                    (member.position - targetPos).normalized * _tactics.MinSpacing,
                TacticalRole.Flanker => CalculateFlankPosition(
                    member, targetPos),
                TacticalRole.Suppressor => targetPos +
                    (member.position - targetPos).normalized * _tactics.EngagementRadius,
                TacticalRole.Reserve => member.position, // Hold position
                _ => member.position
            };

            // Validate position on NavMesh
            if (NavMesh.SamplePosition(desiredPos, out var hit, _tactics.MinSpacing, NavMesh.AllAreas))
                desiredPos = hit.position;

            _blackboard.AssignedPositions[member] = desiredPos;
        }
    }

    private Vector3 CalculateFlankPosition(Transform member, Vector3 targetPos)
    {
        // Perpendicular offset from leader->target line
        var toTarget = (targetPos - transform.position).normalized;
        var perpendicular = Vector3.Cross(toTarget, Vector3.up);

        // Alternate left/right based on member index
        int idx = _members.IndexOf(member);
        float side = (idx % 2 == 0) ? 1f : -1f;

        return targetPos + perpendicular * side * _tactics.MinSpacing * 2f
            + toTarget * -_tactics.MinSpacing;
    }

    void Update()
    {
        if (!_blackboard.InCombat || _blackboard.PrimaryTarget == null) return;

        // Update target position tracking
        _blackboard.LastKnownTargetPosition = _blackboard.PrimaryTarget.position;

        // Periodically refresh tactical positions
        UpdateTacticalPositions();
    }

    /// <summary>Remove destroyed members.</summary>
    void LateUpdate()
    {
        for (int i = _members.Count - 1; i >= 0; i--)
        {
            if (_members[i] == null)
            {
                _members.RemoveAt(i);
                ReassignRoles();
            }
        }
    }
}
```

DESIGN HOOK: Squad tactics = `SquadTactics` SO profiles. "Aggressive Surround" uses high flanker ratio and small engagement radius. "Cautious Distance" uses high suppressor ratio and large radius. "Ambush" keeps everyone in Reserve until leader engages.

GOTCHA: Squad size changes at runtime as members die. The coordinator must reassign roles dynamically in `LateUpdate` null-checks and in `UnregisterMember`. Never cache squad size or assume fixed member count. Also: `NavMesh.SamplePosition` is needed to validate calculated tactical positions -- a flanking position might be off the navmesh (inside a wall).

---

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|---|---|---|
| God NPC MonoBehaviour | Single Update() does perception + decision + action | Separate into PerceptionComponent + NPCBlackboard + DecisionMaker + ActionExecutor |
| Tag-based faction checks | `CompareTag("Enemy")` in every NPC; adding a faction means editing all scripts | FactionDatabase SO with relationship matrix |
| Perfect memory | Boolean `hasSeenPlayer` never resets | MemoryEntry with confidence decay and pruning |
| Instant actions | `TakeDamage()` in decision tick, no wind-up or animation integration | INPCAction lifecycle with Enter/Tick/Exit phases |
| Independent crowd AI | Every NPC pathfinds to same point, stacking up | SquadCoordinator assigns spread positions and tactical roles |
| Hardcoded decision thresholds | Magic numbers (`if (dist < 10)`) buried in code | DecisionProfile SO with named, tunable fields |
| Shared static blackboard | All NPCs share one brain; setting "target" for one sets it for all | Per-instance NPCBlackboard class in Awake() |
| Perception every frame | Every NPC raycasts every Update() | Staggered _updateInterval with random offset |

---

## Related Skills

- `unity-ai-navigation` -- NavMeshAgent pathfinding, obstacle avoidance, area costs
- `unity-game-loop` -- Update ordering, fixed vs variable timestep for NPC ticks
- `unity-data-driven` -- ScriptableObject patterns for NPC configs (DecisionProfile, MemoryConfig, SquadTactics)
- `unity-physics-queries` -- OverlapSphereNonAlloc, raycast patterns, layer mask usage
- `unity-state-machines` -- FSM and Behavior Tree architecture for the decision layer
- `unity-game-architecture` -- Event bus for NPC-to-NPC communication, Service Locator for shared systems

## Additional Resources

- [Unity AI Navigation Manual](https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/index.html)
- [Game AI Pro (online chapters)](http://www.gameaipro.com/)
- [Millington - AI for Games, 3rd Edition](https://www.oreilly.com/library/view/ai-for-games/9780136005827/)
