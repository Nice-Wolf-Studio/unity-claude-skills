# NPC Behavior System Scaffolds

Detailed implementations for NPC behavior systems. Supplements the PATTERN blocks in the parent SKILL.md.

---

## 1. Complete PerceptionComponent

Full perception system with pluggable senses, staggered updates, and event callbacks.

### IPerceptionSense Interface

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Pluggable sense interface. Each sense is a separate MonoBehaviour component
/// attached to the NPC GameObject. PerceptionComponent auto-discovers all senses.
/// </summary>
public interface IPerceptionSense
{
    /// <summary>
    /// Evaluate nearby entities and add perceived targets to the results list.
    /// Called on a staggered schedule by PerceptionComponent.
    /// </summary>
    /// <param name="scratchBuffer">Pre-allocated collider buffer for NonAlloc queries.</param>
    /// <param name="results">List to populate with detected targets.</param>
    void EvaluateTargets(Collider[] scratchBuffer, List<PerceivedTarget> results);

    /// <summary>Maximum detection range for this sense. Used for broad-phase queries.</summary>
    float MaxRange { get; }
}
```

### PerceivedTarget Data Class

```csharp
using System;
using UnityEngine;

/// <summary>
/// Immutable snapshot of a perceived target. Created by senses, consumed by
/// PerceptionComponent for deduplication and event raising.
/// </summary>
[Serializable]
public class PerceivedTarget
{
    /// <summary>The transform of the detected entity.</summary>
    public Transform Transform;

    /// <summary>World-space position at the moment of detection (snapshot).</summary>
    public Vector3 LastKnownPosition;

    /// <summary>
    /// Normalized awareness level (0 = barely noticed, 1 = fully aware).
    /// Computed by the sense based on distance, angle, etc.
    /// </summary>
    public float Awareness;

    /// <summary>Time.time when this target was last perceived by any sense.</summary>
    public float LastSeenTime;

    /// <summary>Name of the sense that detected this target ("Sight", "Hearing", etc.).</summary>
    public string SenseType;

    /// <summary>Faction member component, cached for relationship checks.</summary>
    public FactionMember FactionMember;
}
```

### PerceptionComponent with Staggered Updates

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Central perception hub. Collects results from all IPerceptionSense components
/// on this GameObject. Maintains a deduplicated KnownTargets list. Staggers
/// updates across frames to distribute physics query cost.
/// </summary>
public class PerceptionComponent : MonoBehaviour
{
    [Tooltip("Seconds between perception updates. Staggered with random offset.")]
    [SerializeField] private float _updateInterval = 0.2f;

    [Tooltip("Layers that can be detected by perception senses.")]
    [SerializeField] private LayerMask _detectionLayers;

    [Tooltip("Maximum number of colliders per NonAlloc query.")]
    [SerializeField] private int _bufferSize = 32;

    [Tooltip("Only consider targets with faction relationships of these types.")]
    [SerializeField] private bool _filterByFaction = false;

    [SerializeField] private FactionMember _selfFaction;

    private readonly List<PerceivedTarget> _knownTargets = new();
    private readonly List<PerceivedTarget> _previousTargets = new();
    private IPerceptionSense[] _senses;
    private Collider[] _scratchBuffer;
    private float _nextUpdateTime;

    /// <summary>All currently perceived targets, deduplicated across senses.</summary>
    public IReadOnlyList<PerceivedTarget> KnownTargets => _knownTargets;

    /// <summary>Raised when a target is first detected by any sense.</summary>
    public event Action<PerceivedTarget> OnTargetDetected;

    /// <summary>Raised when a previously known target is no longer detected.</summary>
    public event Action<PerceivedTarget> OnTargetLost;

    /// <summary>Raised every perception update with the full target list.</summary>
    public event Action<IReadOnlyList<PerceivedTarget>> OnPerceptionUpdated;

    void Awake()
    {
        _senses = GetComponents<IPerceptionSense>();
        _scratchBuffer = new Collider[_bufferSize];

        // Stagger start time so NPCs don't all update on the same frame
        _nextUpdateTime = Time.time + UnityEngine.Random.Range(0f, _updateInterval);
    }

    void Update()
    {
        if (Time.time < _nextUpdateTime) return;
        _nextUpdateTime = Time.time + _updateInterval;

        RunPerceptionUpdate();
    }

    private void RunPerceptionUpdate()
    {
        // Snapshot previous targets for delta detection
        _previousTargets.Clear();
        _previousTargets.AddRange(_knownTargets);
        _knownTargets.Clear();

        // Collect from all senses
        foreach (var sense in _senses)
        {
            sense.EvaluateTargets(_scratchBuffer, _knownTargets);
        }

        // Cache faction members
        for (int i = 0; i < _knownTargets.Count; i++)
        {
            var t = _knownTargets[i];
            t.FactionMember ??= t.Transform.GetComponent<FactionMember>();
            _knownTargets[i] = t;
        }

        // Optional faction filtering (only keep hostiles/neutrals)
        if (_filterByFaction && _selfFaction != null)
        {
            _knownTargets.RemoveAll(t =>
                t.FactionMember != null && _selfFaction.IsFriendlyTo(t.FactionMember));
        }

        // Deduplicate by Transform, keeping highest awareness
        DeduplicateTargets();

        // Sort by awareness descending (highest threat first)
        _knownTargets.Sort((a, b) => b.Awareness.CompareTo(a.Awareness));

        // Fire delta events
        FireTargetEvents();

        OnPerceptionUpdated?.Invoke(_knownTargets);
    }

    private void DeduplicateTargets()
    {
        for (int i = _knownTargets.Count - 1; i >= 0; i--)
        {
            for (int j = i - 1; j >= 0; j--)
            {
                if (_knownTargets[i].Transform == _knownTargets[j].Transform)
                {
                    if (_knownTargets[i].Awareness > _knownTargets[j].Awareness)
                        _knownTargets[j] = _knownTargets[i];
                    _knownTargets.RemoveAt(i);
                    break;
                }
            }
        }
    }

    private void FireTargetEvents()
    {
        // New targets
        foreach (var current in _knownTargets)
        {
            bool isNew = true;
            foreach (var prev in _previousTargets)
            {
                if (prev.Transform == current.Transform) { isNew = false; break; }
            }
            if (isNew) OnTargetDetected?.Invoke(current);
        }

        // Lost targets
        foreach (var prev in _previousTargets)
        {
            bool isLost = true;
            foreach (var current in _knownTargets)
            {
                if (current.Transform == prev.Transform) { isLost = false; break; }
            }
            if (isLost) OnTargetLost?.Invoke(prev);
        }
    }

    /// <summary>Force an immediate perception update outside the normal schedule.</summary>
    public void ForceUpdate()
    {
        RunPerceptionUpdate();
        _nextUpdateTime = Time.time + _updateInterval;
    }
}
```

### SightSense with FOV + LOS

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Visual perception sense. Detects targets within a field-of-view cone
/// with line-of-sight raycast verification.
/// Cross-ref: unity-physics-queries for OverlapSphereNonAlloc patterns.
/// </summary>
public class SightSense : MonoBehaviour, IPerceptionSense
{
    [Tooltip("Maximum sight distance in meters.")]
    [SerializeField] private float _range = 20f;

    [Tooltip("Total field of view angle in degrees.")]
    [SerializeField] private float _fovAngle = 120f;

    [Tooltip("Layers containing potential targets.")]
    [SerializeField] private LayerMask _targetLayers;

    [Tooltip("Layers that block line of sight.")]
    [SerializeField] private LayerMask _obstacleLayers;

    [Tooltip("Point from which sight raycasts originate. Falls back to transform.")]
    [SerializeField] private Transform _eyePoint;

    [Tooltip("Height offset added to target position for LOS check.")]
    [SerializeField] private float _targetHeightOffset = 1.0f;

    /// <inheritdoc/>
    public float MaxRange => _range;

    /// <inheritdoc/>
    public void EvaluateTargets(Collider[] scratchBuffer, List<PerceivedTarget> results)
    {
        var origin = _eyePoint != null ? _eyePoint.position : transform.position;
        int count = Physics.OverlapSphereNonAlloc(origin, _range, scratchBuffer, _targetLayers);

        for (int i = 0; i < count; i++)
        {
            var col = scratchBuffer[i];
            if (col.transform == transform) continue; // Skip self

            var targetPos = col.transform.position + Vector3.up * _targetHeightOffset;
            var toTarget = targetPos - origin;
            var dir = toTarget.normalized;
            float dist = toTarget.magnitude;

            // FOV cone check
            float angle = Vector3.Angle(transform.forward, dir);
            if (angle > _fovAngle * 0.5f)
                continue;

            // Line-of-sight raycast
            var combinedMask = _obstacleLayers | _targetLayers;
            if (Physics.Raycast(origin, dir, out var hit, dist, combinedMask))
            {
                if (hit.collider == col)
                {
                    // Awareness falls off with distance and angle
                    float distFactor = 1f - (dist / _range);
                    float angleFactor = 1f - (angle / (_fovAngle * 0.5f));
                    float awareness = distFactor * 0.7f + angleFactor * 0.3f;

                    results.Add(new PerceivedTarget
                    {
                        Transform = col.transform,
                        LastKnownPosition = col.transform.position,
                        Awareness = Mathf.Clamp01(awareness),
                        LastSeenTime = Time.time,
                        SenseType = "Sight"
                    });
                }
            }
        }
    }

    void OnDrawGizmosSelected()
    {
        var origin = _eyePoint != null ? _eyePoint.position : transform.position;
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(origin, _range);

        // Draw FOV cone
        var forward = transform.forward * _range;
        var leftDir = Quaternion.Euler(0, -_fovAngle * 0.5f, 0) * forward;
        var rightDir = Quaternion.Euler(0, _fovAngle * 0.5f, 0) * forward;

        Gizmos.color = new Color(1f, 1f, 0f, 0.3f);
        Gizmos.DrawLine(origin, origin + leftDir);
        Gizmos.DrawLine(origin, origin + rightDir);
    }
}
```

### HearingSense

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Auditory perception sense. Detects targets that have emitted sounds
/// within hearing range. Does not require line of sight.
/// Sounds are registered via the static EmitSound method.
/// </summary>
public class HearingSense : MonoBehaviour, IPerceptionSense
{
    [Tooltip("Maximum hearing distance in meters.")]
    [SerializeField] private float _range = 15f;

    [Tooltip("Layers containing potential sound sources.")]
    [SerializeField] private LayerMask _targetLayers;

    /// <inheritdoc/>
    public float MaxRange => _range;

    // Simple global sound event list, cleared each frame
    private static readonly List<SoundEvent> _activeSounds = new();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics()
    {
        _activeSounds.Clear();
    }

    /// <summary>
    /// Emit a sound at a world position. All HearingSense components in range
    /// will detect it on their next perception update.
    /// </summary>
    /// <param name="position">World-space origin of the sound.</param>
    /// <param name="loudness">Range multiplier (1.0 = normal, 2.0 = very loud).</param>
    /// <param name="source">Transform that caused the sound.</param>
    public static void EmitSound(Vector3 position, float loudness, Transform source)
    {
        _activeSounds.Add(new SoundEvent
        {
            Position = position,
            Loudness = loudness,
            Source = source,
            Timestamp = Time.time
        });
    }

    /// <summary>Clear expired sounds. Call from a manager at end of frame.</summary>
    public static void ClearExpiredSounds(float maxAge = 1f)
    {
        _activeSounds.RemoveAll(s => Time.time - s.Timestamp > maxAge);
    }

    /// <inheritdoc/>
    public void EvaluateTargets(Collider[] scratchBuffer, List<PerceivedTarget> results)
    {
        var listenerPos = transform.position;

        foreach (var sound in _activeSounds)
        {
            if (sound.Source == transform) continue; // Ignore own sounds

            float effectiveRange = _range * sound.Loudness;
            float dist = Vector3.Distance(listenerPos, sound.Position);

            if (dist > effectiveRange) continue;

            results.Add(new PerceivedTarget
            {
                Transform = sound.Source,
                LastKnownPosition = sound.Position,
                Awareness = Mathf.Clamp01(1f - (dist / effectiveRange)) * 0.7f,
                LastSeenTime = Time.time,
                SenseType = "Hearing"
            });
        }
    }

    private struct SoundEvent
    {
        public Vector3 Position;
        public float Loudness;
        public Transform Source;
        public float Timestamp;
    }
}
```

---

## 2. Complete NPCBlackboard

Type-safe per-instance data store bridging perception, memory, and decision layers.

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Per-NPC-instance data store. Perception and memory systems write;
/// decision and action systems read. Plain C# class for testability.
/// IMPORTANT: Must be instantiated per NPC, never shared or static.
/// </summary>
public class NPCBlackboard
{
    // ---- Common key constants ----

    /// <summary>Current primary target Transform.</summary>
    public const string KEY_PRIMARY_TARGET = "PrimaryTarget";

    /// <summary>Float threat level of current target (0-1).</summary>
    public const string KEY_THREAT_LEVEL = "ThreatLevel";

    /// <summary>Vector3 last known position of primary target.</summary>
    public const string KEY_LAST_KNOWN_POS = "LastKnownPosition";

    /// <summary>Float current health percentage (0-1).</summary>
    public const string KEY_HEALTH_PERCENT = "HealthPercent";

    /// <summary>Int count of nearby allies.</summary>
    public const string KEY_ALLIES_NEARBY = "AlliesNearby";

    /// <summary>Bool whether the NPC is in combat.</summary>
    public const string KEY_IN_COMBAT = "InCombat";

    /// <summary>Vector3 home/patrol origin position.</summary>
    public const string KEY_HOME_POSITION = "HomePosition";

    /// <summary>Float distance to primary target.</summary>
    public const string KEY_TARGET_DISTANCE = "TargetDistance";

    /// <summary>String current decision state name.</summary>
    public const string KEY_CURRENT_STATE = "CurrentState";

    /// <summary>Bool whether the NPC has been damaged recently.</summary>
    public const string KEY_RECENTLY_DAMAGED = "RecentlyDamaged";

    // ---- Internal storage ----

    private readonly Dictionary<string, object> _data = new();

    /// <summary>Event raised when any key is changed.</summary>
    public event Action<string> OnKeyChanged;

    /// <summary>Set a typed value on the blackboard.</summary>
    public void Set<T>(string key, T value)
    {
        _data[key] = value;
        OnKeyChanged?.Invoke(key);
    }

    /// <summary>
    /// Get a typed value from the blackboard.
    /// Returns fallback if key is missing or wrong type.
    /// </summary>
    public T Get<T>(string key, T fallback = default)
    {
        if (_data.TryGetValue(key, out var val) && val is T typed)
            return typed;
        return fallback;
    }

    /// <summary>Check if a key exists on the blackboard.</summary>
    public bool Has(string key) => _data.ContainsKey(key);

    /// <summary>Remove a single key from the blackboard.</summary>
    public void Clear(string key)
    {
        if (_data.Remove(key))
            OnKeyChanged?.Invoke(key);
    }

    /// <summary>Remove all data from the blackboard.</summary>
    public void ClearAll()
    {
        _data.Clear();
    }

    /// <summary>
    /// Try to get a value. Returns false if key missing or wrong type.
    /// Avoids allocating a default value.
    /// </summary>
    public bool TryGet<T>(string key, out T value)
    {
        if (_data.TryGetValue(key, out var val) && val is T typed)
        {
            value = typed;
            return true;
        }
        value = default;
        return false;
    }

    /// <summary>Get all keys currently on the blackboard (for debug display).</summary>
    public IEnumerable<string> AllKeys => _data.Keys;

    /// <summary>Number of entries on the blackboard.</summary>
    public int Count => _data.Count;
}
```

---

## 3. Complete ActionExecutor

Full action lifecycle system with interruption handling and a sample melee attack.

### INPCAction Interface

```csharp
/// <summary>
/// Action lifecycle interface. Actions own their execution duration,
/// animation triggers, and exit conditions. Actions are not instantaneous --
/// they play out over time with interruptible phases.
/// </summary>
public interface INPCAction
{
    /// <summary>
    /// Called when the action begins. Initialize timers, trigger entry animations.
    /// </summary>
    void Enter(NPCActionContext context);

    /// <summary>
    /// Called each frame while the action is active.
    /// Returns true when the action is complete and should transition out.
    /// </summary>
    bool Tick(NPCActionContext context, float deltaTime);

    /// <summary>
    /// Called when the action ends, either naturally (complete) or via interruption.
    /// Must clean up state, cancel pending effects, reset animations.
    /// </summary>
    /// <param name="context">Shared NPC context.</param>
    /// <param name="wasInterrupted">True if ended by interruption, false if completed normally.</param>
    void Exit(NPCActionContext context, bool wasInterrupted);

    /// <summary>
    /// Whether this action can be interrupted by a higher-priority action.
    /// Some phases may be interruptible while others are not.
    /// </summary>
    bool CanInterrupt { get; }

    /// <summary>Display name for debugging.</summary>
    string ActionName { get; }
}

/// <summary>
/// Shared context passed to all actions. Contains references to NPC components
/// that actions need to operate.
/// </summary>
public class NPCActionContext
{
    /// <summary>The NPC's own transform.</summary>
    public UnityEngine.Transform Self;

    /// <summary>Current target transform (may be null).</summary>
    public UnityEngine.Transform Target;

    /// <summary>Animator for triggering animation states.</summary>
    public UnityEngine.Animator Animator;

    /// <summary>NPC's blackboard for reading/writing state.</summary>
    public NPCBlackboard Blackboard;

    /// <summary>NPC's NavMeshAgent for movement actions.</summary>
    public UnityEngine.AI.NavMeshAgent NavAgent;
}
```

### ActionExecutor MonoBehaviour

```csharp
using UnityEngine;
using UnityEngine.AI;

/// <summary>
/// Manages the current action lifecycle on an NPC. Handles starting new actions,
/// interrupting current actions, and ticking the active action each frame.
/// </summary>
public class ActionExecutor : MonoBehaviour
{
    private INPCAction _currentAction;
    private INPCAction _queuedAction;
    private NPCActionContext _context;

    /// <summary>Whether an action is currently executing.</summary>
    public bool IsExecuting => _currentAction != null;

    /// <summary>The currently executing action, if any.</summary>
    public INPCAction CurrentAction => _currentAction;

    /// <summary>Event raised when an action starts.</summary>
    public event System.Action<INPCAction> OnActionStarted;

    /// <summary>Event raised when an action completes or is interrupted.</summary>
    public event System.Action<INPCAction, bool> OnActionEnded;

    void Awake()
    {
        _context = new NPCActionContext
        {
            Self = transform,
            Animator = GetComponentInChildren<Animator>(),
            NavAgent = GetComponent<NavMeshAgent>()
        };
    }

    /// <summary>
    /// Inject the blackboard reference. Call after blackboard is created.
    /// </summary>
    public void Initialize(NPCBlackboard blackboard)
    {
        _context.Blackboard = blackboard;
    }

    /// <summary>
    /// Execute an action. If a current action is running and interruptible,
    /// it will be interrupted. If not interruptible, the new action is queued.
    /// Returns true if the action started immediately.
    /// </summary>
    public bool Execute(INPCAction action, Transform target = null)
    {
        _context.Target = target;

        if (_currentAction != null)
        {
            if (!_currentAction.CanInterrupt)
            {
                // Queue for later
                _queuedAction = action;
                return false;
            }

            // Interrupt current action
            var interrupted = _currentAction;
            _currentAction.Exit(_context, wasInterrupted: true);
            OnActionEnded?.Invoke(interrupted, true);
        }

        _currentAction = action;
        _currentAction.Enter(_context);
        OnActionStarted?.Invoke(_currentAction);
        return true;
    }

    /// <summary>Force-cancel the current action regardless of CanInterrupt.</summary>
    public void ForceCancel()
    {
        if (_currentAction != null)
        {
            var cancelled = _currentAction;
            _currentAction.Exit(_context, wasInterrupted: true);
            _currentAction = null;
            _queuedAction = null;
            OnActionEnded?.Invoke(cancelled, true);
        }
    }

    /// <summary>Cancel the current action only if it is interruptible.</summary>
    public void Cancel()
    {
        if (_currentAction != null && _currentAction.CanInterrupt)
        {
            ForceCancel();
        }
    }

    void Update()
    {
        if (_currentAction == null)
        {
            // Try to start queued action
            if (_queuedAction != null)
            {
                var queued = _queuedAction;
                _queuedAction = null;
                Execute(queued, _context.Target);
            }
            return;
        }

        bool complete = _currentAction.Tick(_context, Time.deltaTime);
        if (complete)
        {
            var completed = _currentAction;
            _currentAction.Exit(_context, wasInterrupted: false);
            _currentAction = null;
            OnActionEnded?.Invoke(completed, false);

            // Auto-start queued action
            if (_queuedAction != null)
            {
                var queued = _queuedAction;
                _queuedAction = null;
                Execute(queued, _context.Target);
            }
        }
    }
}
```

### MeleeAttackAction with 3 Phases

```csharp
using UnityEngine;

/// <summary>
/// Melee attack action with wind-up, strike, and recovery phases.
/// Damage is only applied during the strike phase if the target is in range.
/// Interruptible during wind-up only -- once the strike begins, it commits.
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
    public bool CanInterrupt => _phase == Phase.WindUp;

    /// <inheritdoc/>
    public string ActionName => "MeleeAttack";

    /// <summary>
    /// Create a melee attack action with configurable timing.
    /// </summary>
    /// <param name="windUp">Seconds before the strike (interruptible).</param>
    /// <param name="strike">Seconds of the strike window (commits).</param>
    /// <param name="recovery">Seconds of cooldown after strike.</param>
    /// <param name="damage">Damage dealt on hit.</param>
    /// <param name="range">Maximum distance for the strike to connect.</param>
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

        // Stop movement during attack
        if (context.NavAgent != null)
            context.NavAgent.isStopped = true;

        context.Animator?.SetTrigger("MeleeWindUp");
    }

    /// <inheritdoc/>
    public bool Tick(NPCActionContext context, float deltaTime)
    {
        _phaseTimer += deltaTime;

        switch (_phase)
        {
            case Phase.WindUp:
                // Face target during wind-up
                if (context.Target != null)
                {
                    var lookDir = (context.Target.position - context.Self.position);
                    lookDir.y = 0;
                    if (lookDir.sqrMagnitude > 0.001f)
                        context.Self.rotation = Quaternion.Slerp(
                            context.Self.rotation,
                            Quaternion.LookRotation(lookDir),
                            deltaTime * 10f);
                }

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
                        var health = context.Target.GetComponent<Health>();
                        if (health != null)
                        {
                            health.TakeDamage(_damage);
                            _damageApplied = true;
                        }
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
        // Resume movement
        if (context.NavAgent != null)
            context.NavAgent.isStopped = false;

        if (wasInterrupted)
        {
            // Interrupted -- ensure no damage was applied (wind-up phase)
            context.Animator?.SetTrigger("Interrupted");
        }

        // Reset animator state
        context.Animator?.ResetTrigger("MeleeWindUp");
        context.Animator?.ResetTrigger("MeleeStrike");
        context.Animator?.ResetTrigger("MeleeRecover");
    }
}
```

### RangedAttackAction Example

```csharp
using UnityEngine;

/// <summary>
/// Ranged attack action: aim, fire, cooldown.
/// Spawns a projectile prefab during the fire phase.
/// </summary>
public class RangedAttackAction : INPCAction
{
    private enum Phase { Aim, Fire, Cooldown }

    private readonly float _aimDuration;
    private readonly float _cooldownDuration;
    private readonly GameObject _projectilePrefab;
    private readonly Transform _muzzlePoint;
    private readonly float _projectileSpeed;

    private Phase _phase;
    private float _phaseTimer;
    private bool _projectileFired;

    /// <inheritdoc/>
    public bool CanInterrupt => _phase == Phase.Aim;

    /// <inheritdoc/>
    public string ActionName => "RangedAttack";

    public RangedAttackAction(GameObject projectilePrefab, Transform muzzlePoint,
                               float aimDuration = 0.5f, float cooldown = 0.8f,
                               float projectileSpeed = 20f)
    {
        _projectilePrefab = projectilePrefab;
        _muzzlePoint = muzzlePoint;
        _aimDuration = aimDuration;
        _cooldownDuration = cooldown;
        _projectileSpeed = projectileSpeed;
    }

    /// <inheritdoc/>
    public void Enter(NPCActionContext context)
    {
        _phase = Phase.Aim;
        _phaseTimer = 0f;
        _projectileFired = false;

        if (context.NavAgent != null)
            context.NavAgent.isStopped = true;

        context.Animator?.SetTrigger("RangedAim");
    }

    /// <inheritdoc/>
    public bool Tick(NPCActionContext context, float deltaTime)
    {
        _phaseTimer += deltaTime;

        switch (_phase)
        {
            case Phase.Aim:
                // Track target during aim
                if (context.Target != null)
                {
                    var lookDir = (context.Target.position - context.Self.position);
                    lookDir.y = 0;
                    if (lookDir.sqrMagnitude > 0.001f)
                        context.Self.rotation = Quaternion.LookRotation(lookDir);
                }

                if (_phaseTimer >= _aimDuration)
                {
                    _phase = Phase.Fire;
                    _phaseTimer = 0f;
                    FireProjectile(context);
                    context.Animator?.SetTrigger("RangedFire");
                }
                break;

            case Phase.Fire:
                _phase = Phase.Cooldown;
                _phaseTimer = 0f;
                break;

            case Phase.Cooldown:
                if (_phaseTimer >= _cooldownDuration)
                    return true;
                break;
        }

        return false;
    }

    private void FireProjectile(NPCActionContext context)
    {
        if (_projectileFired || _projectilePrefab == null) return;

        var spawnPos = _muzzlePoint != null ? _muzzlePoint.position : context.Self.position;
        var dir = context.Target != null
            ? (context.Target.position - spawnPos).normalized
            : context.Self.forward;

        var go = Object.Instantiate(_projectilePrefab, spawnPos, Quaternion.LookRotation(dir));
        var rb = go.GetComponent<Rigidbody>();
        if (rb != null)
            rb.linearVelocity = dir * _projectileSpeed;

        _projectileFired = true;
    }

    /// <inheritdoc/>
    public void Exit(NPCActionContext context, bool wasInterrupted)
    {
        if (context.NavAgent != null)
            context.NavAgent.isStopped = false;

        context.Animator?.ResetTrigger("RangedAim");
        context.Animator?.ResetTrigger("RangedFire");
    }
}
```

---

## 4. Complete FactionDatabase

Full faction system with bidirectional relationship lookup and runtime overrides.

### Faction ScriptableObject

```csharp
using UnityEngine;

/// <summary>
/// Faction identity asset. One per faction in the game.
/// Create via Assets > Create > NPC > Faction.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Faction")]
public class Faction : ScriptableObject
{
    /// <summary>Display name for UI, dialogue, and debug.</summary>
    [Tooltip("Display name shown in UI and debug views.")]
    public string DisplayName;

    /// <summary>Color for debug gizmos, minimap icons, health bars.</summary>
    [Tooltip("Color used for debug visualization.")]
    public Color DebugColor = Color.white;

    /// <summary>Optional icon for UI display.</summary>
    [Tooltip("Faction icon for UI elements.")]
    public Sprite Icon;

    /// <summary>Brief description for tooltips.</summary>
    [TextArea(2, 4)]
    [Tooltip("Faction description for designer reference.")]
    public string Description;
}
```

### FactionDatabase ScriptableObject

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>Relationship stance between two factions.</summary>
public enum Relationship
{
    /// <summary>Factions will attack on sight.</summary>
    Hostile,
    /// <summary>Factions ignore each other.</summary>
    Neutral,
    /// <summary>Factions cooperate and will not attack.</summary>
    Friendly
}

/// <summary>A single relationship entry between two factions.</summary>
[Serializable]
public class FactionRelationship
{
    /// <summary>First faction in the relationship.</summary>
    public Faction FactionA;

    /// <summary>Second faction in the relationship.</summary>
    public Faction FactionB;

    /// <summary>The stance between these factions.</summary>
    public Relationship Stance = Relationship.Neutral;
}

/// <summary>
/// Central faction database. One instance per game. Stores all faction
/// relationships in an Inspector-editable list. Supports runtime overrides
/// for dynamic alliance shifts.
/// Create via Assets > Create > NPC > Faction Database.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Faction Database")]
public class FactionDatabase : ScriptableObject
{
    [Tooltip("All faction relationships. Both directions are checked.")]
    [SerializeField] private List<FactionRelationship> _relationships = new();

    [Tooltip("Default relationship when no explicit entry exists.")]
    [SerializeField] private Relationship _defaultRelationship = Relationship.Neutral;

    // Runtime overrides (not serialized, lost on domain reload)
    private Dictionary<(Faction, Faction), Relationship> _runtimeOverrides;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics()
    {
        // No static state to reset -- runtime overrides are per-instance
    }

    /// <summary>
    /// Get the relationship between two factions.
    /// Checks: same faction (Friendly) -> runtime overrides -> authored list -> default.
    /// </summary>
    public Relationship GetRelationship(Faction a, Faction b)
    {
        if (a == null || b == null) return _defaultRelationship;
        if (a == b) return Relationship.Friendly;

        // Runtime overrides first
        if (_runtimeOverrides != null)
        {
            if (_runtimeOverrides.TryGetValue((a, b), out var r1)) return r1;
            if (_runtimeOverrides.TryGetValue((b, a), out var r2)) return r2;
        }

        // Authored relationships (bidirectional check)
        foreach (var rel in _relationships)
        {
            if ((rel.FactionA == a && rel.FactionB == b) ||
                (rel.FactionA == b && rel.FactionB == a))
            {
                return rel.Stance;
            }
        }

        return _defaultRelationship;
    }

    /// <summary>
    /// Check if two factions are hostile to each other.
    /// </summary>
    public bool AreHostile(Faction a, Faction b)
    {
        return GetRelationship(a, b) == Relationship.Hostile;
    }

    /// <summary>
    /// Check if two factions are friendly to each other.
    /// </summary>
    public bool AreFriendly(Faction a, Faction b)
    {
        return GetRelationship(a, b) == Relationship.Friendly;
    }

    /// <summary>
    /// Override a relationship at runtime (e.g., betrayal, quest reward).
    /// Does NOT modify the authored asset -- override is lost on domain reload.
    /// </summary>
    public void SetRelationshipRuntime(Faction a, Faction b, Relationship stance)
    {
        _runtimeOverrides ??= new Dictionary<(Faction, Faction), Relationship>();
        _runtimeOverrides[(a, b)] = stance;
    }

    /// <summary>
    /// Remove a runtime override, reverting to the authored relationship.
    /// </summary>
    public void ClearRuntimeOverride(Faction a, Faction b)
    {
        _runtimeOverrides?.Remove((a, b));
        _runtimeOverrides?.Remove((b, a));
    }

    /// <summary>Clear all runtime relationship overrides.</summary>
    public void ClearAllRuntimeOverrides()
    {
        _runtimeOverrides?.Clear();
    }
}
```

### FactionMember Component

```csharp
using UnityEngine;

/// <summary>
/// Component that identifies a GameObject's faction membership.
/// Attach to any entity that participates in the faction system
/// (NPCs, player, destructible objects, turrets, etc.).
/// </summary>
public class FactionMember : MonoBehaviour
{
    [Tooltip("This entity's faction.")]
    [SerializeField] private Faction _faction;

    [Tooltip("Reference to the game's faction database.")]
    [SerializeField] private FactionDatabase _database;

    /// <summary>This entity's faction.</summary>
    public Faction Faction
    {
        get => _faction;
        set => _faction = value; // Allow runtime faction changes (defection)
    }

    /// <summary>Get the relationship between this entity and another.</summary>
    public Relationship GetRelationshipTo(FactionMember other)
    {
        if (other == null) return Relationship.Neutral;
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

    /// <summary>Check if another entity is neutral.</summary>
    public bool IsNeutralTo(FactionMember other)
    {
        return GetRelationshipTo(other) == Relationship.Neutral;
    }

    void OnDrawGizmosSelected()
    {
        if (_faction != null)
        {
            Gizmos.color = _faction.DebugColor;
            Gizmos.DrawWireSphere(transform.position, 0.5f);
        }
    }
}
```

---

## 5. Complete NPCMemory

Full memory system with timestamped entries, confidence decay, and configurable pruning.

### MemoryEntry Struct

```csharp
using UnityEngine;

/// <summary>
/// A single memory record. Position is a world-space snapshot at the time
/// of perception -- it does NOT track the target's current position.
/// This is intentional: it creates search/investigation behavior.
/// </summary>
public struct MemoryEntry
{
    /// <summary>Type of stimulus ("Sight", "Hearing", "Damage", "Alert").</summary>
    public string StimulusType;

    /// <summary>World-space position where the stimulus occurred (snapshot).</summary>
    public Vector3 Position;

    /// <summary>
    /// Current confidence level. Starts at 1.0, decays toward 0 over time.
    /// When below prune threshold, the memory is removed.
    /// </summary>
    public float Confidence;

    /// <summary>Time.time when this memory was created or last refreshed.</summary>
    public float Timestamp;

    /// <summary>
    /// The source transform that created this stimulus. May become null
    /// if the source is destroyed.
    /// </summary>
    public Transform Source;

    /// <summary>Priority level for sorting (higher = more important).</summary>
    public int Priority;
}
```

### MemoryConfig ScriptableObject

```csharp
using UnityEngine;

/// <summary>
/// Configuration for NPC memory behavior. Different archetypes get
/// different configs -- elite guards remember longer than basic enemies.
/// Create via Assets > Create > NPC > Memory Config.
/// </summary>
[CreateAssetMenu(menuName = "NPC/Memory Config")]
public class MemoryConfig : ScriptableObject
{
    [Tooltip("Seconds until a memory fully decays from confidence 1.0 to 0.0.")]
    public float MemoryDuration = 30f;

    [Tooltip("Confidence level below which memories are pruned.")]
    [Range(0.01f, 0.5f)]
    public float PruneThreshold = 0.05f;

    [Tooltip("Maximum number of memories to retain. Oldest are pruned first when exceeded.")]
    public int MaxMemories = 20;

    [Tooltip("Multiplier for memory duration per stimulus type. Damage memories last longer.")]
    public float DamageMemoryMultiplier = 2.0f;

    [Tooltip("Multiplier for memory duration of sound-based memories.")]
    public float SoundMemoryMultiplier = 0.5f;
}
```

### NPCMemory Class

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// NPC memory system. Stores timestamped memories with confidence decay.
/// Memory positions are world-space snapshots -- the NPC investigates the
/// OLD position, not the target's current position. This creates search behavior.
///
/// Usage:
///   var memory = new NPCMemory(memoryConfig);
///   memory.Remember("Sight", targetPos, targetTransform);
///   memory.DecayAndPrune(); // Call each decision tick
///   if (memory.TryGetBestMemory("Sight", out var mem)) { /* investigate mem.Position */ }
/// </summary>
public class NPCMemory
{
    private readonly List<MemoryEntry> _memories = new();
    private readonly MemoryConfig _config;

    /// <summary>All current memories (read-only view).</summary>
    public IReadOnlyList<MemoryEntry> Memories => _memories;

    /// <summary>Number of active memories.</summary>
    public int Count => _memories.Count;

    public NPCMemory(MemoryConfig config)
    {
        _config = config;
    }

    /// <summary>
    /// Record a new memory or refresh an existing one from the same source.
    /// If an existing memory from the same source exists, it is refreshed
    /// (position updated, confidence reset to 1.0).
    /// </summary>
    /// <param name="stimulusType">Type of stimulus ("Sight", "Hearing", "Damage").</param>
    /// <param name="position">World-space position of the stimulus (snapshot).</param>
    /// <param name="source">Transform that caused the stimulus (may be null).</param>
    /// <param name="priority">Priority level for sorting (default 0).</param>
    public void Remember(string stimulusType, Vector3 position,
                          Transform source = null, int priority = 0)
    {
        // Refresh existing memory from same source
        for (int i = 0; i < _memories.Count; i++)
        {
            if (_memories[i].Source != null && _memories[i].Source == source
                && _memories[i].StimulusType == stimulusType)
            {
                _memories[i] = new MemoryEntry
                {
                    StimulusType = stimulusType,
                    Position = position,
                    Confidence = 1f,
                    Timestamp = Time.time,
                    Source = source,
                    Priority = priority
                };
                return;
            }
        }

        // Enforce max memory count -- remove lowest priority oldest entry
        if (_memories.Count >= _config.MaxMemories)
        {
            int lowestIdx = 0;
            float lowestScore = float.MaxValue;
            for (int i = 0; i < _memories.Count; i++)
            {
                float score = _memories[i].Confidence + _memories[i].Priority;
                if (score < lowestScore)
                {
                    lowestScore = score;
                    lowestIdx = i;
                }
            }
            _memories.RemoveAt(lowestIdx);
        }

        _memories.Add(new MemoryEntry
        {
            StimulusType = stimulusType,
            Position = position,
            Confidence = 1f,
            Timestamp = Time.time,
            Source = source,
            Priority = priority
        });
    }

    /// <summary>
    /// Query the most confident memory of a given stimulus type.
    /// Returns false if no memories of that type exist.
    /// </summary>
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

    /// <summary>
    /// Query all memories of a given stimulus type, sorted by confidence descending.
    /// </summary>
    public List<MemoryEntry> GetMemories(string stimulusType)
    {
        var results = new List<MemoryEntry>();
        foreach (var mem in _memories)
        {
            if (mem.StimulusType == stimulusType)
                results.Add(mem);
        }
        results.Sort((a, b) => b.Confidence.CompareTo(a.Confidence));
        return results;
    }

    /// <summary>
    /// Query the most recent memory of any type at a position within a given radius.
    /// Useful for checking "do I remember anything happening near here?"
    /// </summary>
    public bool TryGetMemoryNear(Vector3 position, float radius, out MemoryEntry found)
    {
        found = default;
        float bestTime = 0f;
        float radiusSqr = radius * radius;

        foreach (var mem in _memories)
        {
            if ((mem.Position - position).sqrMagnitude <= radiusSqr && mem.Timestamp > bestTime)
            {
                found = mem;
                bestTime = mem.Timestamp;
            }
        }

        return bestTime > 0f;
    }

    /// <summary>
    /// Decay all memories based on elapsed time and prune expired ones.
    /// Call this once per decision tick (not every frame).
    /// </summary>
    public void DecayAndPrune()
    {
        for (int i = _memories.Count - 1; i >= 0; i--)
        {
            float age = Time.time - _memories[i].Timestamp;

            // Apply stimulus-type-specific duration multiplier
            float duration = _config.MemoryDuration;
            var mem = _memories[i];
            if (mem.StimulusType == "Damage")
                duration *= _config.DamageMemoryMultiplier;
            else if (mem.StimulusType == "Hearing")
                duration *= _config.SoundMemoryMultiplier;

            float newConfidence = Mathf.Clamp01(1f - (age / duration));

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

    /// <summary>Check if the NPC has any memory of a specific stimulus type.</summary>
    public bool HasMemoryOf(string stimulusType)
    {
        foreach (var mem in _memories)
        {
            if (mem.StimulusType == stimulusType) return true;
        }
        return false;
    }

    /// <summary>Check if the NPC has any memory of a specific source transform.</summary>
    public bool RemembersSource(Transform source)
    {
        foreach (var mem in _memories)
        {
            if (mem.Source == source) return true;
        }
        return false;
    }

    /// <summary>Forget all memories of a specific stimulus type.</summary>
    public void Forget(string stimulusType)
    {
        _memories.RemoveAll(m => m.StimulusType == stimulusType);
    }

    /// <summary>Forget all memories.</summary>
    public void ForgetAll() => _memories.Clear();
}
```

---

## 6. NPC Architecture Diagram

```
+------------------------------------------------------------------+
|                        NPC BEHAVIOR PIPELINE                      |
+------------------------------------------------------------------+
|                                                                    |
|  WORLD                                                             |
|    |                                                               |
|    v                                                               |
|  +-------------------+                                             |
|  | PERCEPTION LAYER  |  IPerceptionSense components                |
|  |                   |  (SightSense, HearingSense, ProximitySense) |
|  | OverlapSphereNA   |  Staggered updates (_updateInterval)        |
|  | FOV + LOS checks  |  Cross-ref: unity-physics-queries           |
|  +--------+----------+                                             |
|           |                                                        |
|           | PerceivedTarget list                                   |
|           v                                                        |
|  +-------------------+     +-------------------+                   |
|  |   NPC MEMORY      |---->|   NPC BLACKBOARD  |                   |
|  |                   |     |                   |                   |
|  | MemoryEntry[]     |     | Key-Value store   |                   |
|  | Confidence decay  |     | PrimaryTarget     |                   |
|  | Position snapshot |     | ThreatLevel       |                   |
|  | Prune expired     |     | LastKnownPos      |                   |
|  +-------------------+     +--------+----------+                   |
|                                     |                              |
|                                     | Read blackboard data         |
|                                     v                              |
|  +-------------------+     +-------------------+                   |
|  | DECISION PROFILE  |---->| DECISION LAYER    |                   |
|  | (ScriptableObject)|     |                   |                   |
|  |                   |     | FSM or BT          |                   |
|  | AggroRange        |     | Cross-ref:         |                   |
|  | FleeRange         |     |  unity-state-      |                   |
|  | AwarenessThreshold|     |  machines           |                   |
|  +-------------------+     +--------+----------+                   |
|                                     |                              |
|                                     | Decision: "Engage"/"Flee"   |
|                                     v                              |
|                            +-------------------+                   |
|                            | ACTION EXECUTOR   |                   |
|                            |                   |                   |
|                            | INPCAction:       |                   |
|                            |  Enter/Tick/Exit  |                   |
|                            |  CanInterrupt     |                   |
|                            |                   |                   |
|                            | MeleeAttackAction |                   |
|                            |  WindUp -> Strike  |                   |
|                            |  -> Recovery       |                   |
|                            +-------------------+                   |
|                                                                    |
+------------------------------------------------------------------+
|                     CROSS-CUTTING SYSTEMS                         |
+------------------------------------------------------------------+
|                                                                    |
|  +-------------------+     +-------------------+                   |
|  | FACTION DATABASE  |     | SQUAD COORDINATOR |                   |
|  |                   |     |                   |                   |
|  | Relationship      |     | TacticalRole      |                   |
|  |  matrix (SO)      |     |  assignment        |                   |
|  | Runtime overrides |     | SquadBlackboard   |                   |
|  | Bidirectional     |     | NavMesh spread    |                   |
|  |  lookup           |     | Dynamic reassign  |                   |
|  +-------------------+     +-------------------+                   |
|                                                                    |
+------------------------------------------------------------------+

DATA FLOW:
  Perception --> Memory --> Blackboard --> Decision --> Action
                                ^                        |
                                |  Feedback (damage,     |
                                |   position updates)    |
                                +------------------------+

CONFIGURATION (ScriptableObjects):
  - DecisionProfile: aggro/flee ranges, thresholds per archetype
  - MemoryConfig: duration, decay rate, max memories per archetype
  - SquadTactics: spacing, engagement radius, role ratios
  - Faction / FactionDatabase: relationship matrix
```

### Component Wiring on a Typical NPC Prefab

```
NPC_Guard (GameObject)
 |
 +-- PerceptionComponent          (auto-discovers senses below)
 +-- SightSense                   (range=20, fov=120, targetLayers, obstacleLayers)
 +-- HearingSense                 (range=15, targetLayers)
 +-- FactionMember                (faction=Guards, database=MainFactionDB)
 +-- NPCDecisionMaker             (profile=GuardDecisionProfile, perception=self)
 +-- ActionExecutor               (initialized with blackboard in Awake)
 +-- NavMeshAgent                 (for pathfinding -- see unity-ai-navigation)
 +-- Animator                     (for action animation triggers)
 |
 +-- [EyePoint] (child Transform) (referenced by SightSense._eyePoint)
```

### Integration Example

```csharp
using UnityEngine;

/// <summary>
/// Wires all NPC subsystems together on a single prefab.
/// This is the only "glue" MonoBehaviour -- all logic lives in the subsystems.
/// </summary>
public class NPCController : MonoBehaviour
{
    [SerializeField] private PerceptionComponent _perception;
    [SerializeField] private NPCDecisionMaker _decisionMaker;
    [SerializeField] private ActionExecutor _actionExecutor;
    [SerializeField] private MemoryConfig _memoryConfig;

    private NPCMemory _memory;

    void Awake()
    {
        _memory = new NPCMemory(_memoryConfig);
        _actionExecutor.Initialize(_decisionMaker.Blackboard);
    }

    void OnEnable()
    {
        _perception.OnTargetDetected += HandleTargetDetected;
        _perception.OnTargetLost += HandleTargetLost;
        _decisionMaker.OnDecision += HandleDecision;
    }

    void OnDisable()
    {
        _perception.OnTargetDetected -= HandleTargetDetected;
        _perception.OnTargetLost -= HandleTargetLost;
        _decisionMaker.OnDecision -= HandleDecision;
    }

    void Update()
    {
        _memory.DecayAndPrune();

        // Feed best memory into blackboard when no direct perception
        if (_perception.KnownTargets.Count == 0 &&
            _memory.TryGetBestMemory("Sight", out var mem))
        {
            _decisionMaker.Blackboard.Set(
                NPCBlackboard.KEY_LAST_KNOWN_POS, mem.Position);
        }
    }

    private void HandleTargetDetected(PerceivedTarget target)
    {
        _memory.Remember(target.SenseType, target.LastKnownPosition, target.Transform);
    }

    private void HandleTargetLost(PerceivedTarget target)
    {
        // Memory persists after LOS is lost -- NPC will investigate last known pos
    }

    private void HandleDecision(string decision)
    {
        switch (decision)
        {
            case "Engage":
                var target = _decisionMaker.Blackboard.Get<Transform>(
                    NPCBlackboard.KEY_PRIMARY_TARGET);
                if (target != null)
                {
                    var attack = new MeleeAttackAction();
                    _actionExecutor.Execute(attack, target);
                }
                break;

            case "Investigate":
                var lastPos = _decisionMaker.Blackboard.Get<Vector3>(
                    NPCBlackboard.KEY_LAST_KNOWN_POS);
                // Navigate to last known position (see unity-ai-navigation)
                break;

            case "Patrol":
                _actionExecutor.Cancel();
                break;
        }
    }
}
```
