# Level Design System Scaffolds

Detailed implementations for level design systems. Supplements the PATTERN blocks in the parent SKILL.md.

---

## 1. Complete TriggerZone

Full implementation with activation modes, filtering, cooldown, delay, debug visualization, and SO event output.

```csharp
using System.Threading;
using UnityEngine;

/// <summary>
/// Generic trigger volume that raises a GameEvent SO channel on activation.
/// Supports configurable activation count, tag/layer filtering, cooldown, and delay.
/// </summary>
[RequireComponent(typeof(Collider), typeof(Rigidbody))]
public class TriggerZone : MonoBehaviour
{
    /// <summary>How many times this trigger can activate.</summary>
    public enum ActivationMode
    {
        /// <summary>Activates exactly once, then disables.</summary>
        Once,
        /// <summary>Activates indefinitely, respecting cooldown.</summary>
        Repeating,
        /// <summary>Activates up to MaxActivations times.</summary>
        NTimes
    }

    [Header("Activation Rules")]
    [Tooltip("How many times this trigger can fire.")]
    [SerializeField] ActivationMode _mode = ActivationMode.Once;

    [Tooltip("Max activations when Mode is NTimes.")]
    [SerializeField] int _maxActivations = 1;

    [Tooltip("Minimum seconds between activations.")]
    [SerializeField] float _cooldownSeconds;

    [Tooltip("Delay in seconds before the event fires after trigger entry.")]
    [SerializeField] float _activationDelay;

    [Tooltip("Only objects with this tag can activate. Leave empty for any tag.")]
    [SerializeField] string _requiredTag = "Player";

    [Tooltip("Only objects on these layers can activate.")]
    [SerializeField] LayerMask _requiredLayer = ~0;

    [Header("Event Output")]
    [Tooltip("GameEvent SO raised on activation. See unity-game-architecture.")]
    [SerializeField] GameEvent _onActivated;

    [Header("Debug")]
    [SerializeField] Color _gizmoColor = new(0f, 1f, 0f, 0.25f);

    int _activationCount;
    float _lastActivationTime = float.NegativeInfinity;
    bool _activationInProgress;

    /// <summary>Current number of times this trigger has activated.</summary>
    public int ActivationCount => _activationCount;

    /// <summary>Whether this trigger can still activate.</summary>
    public bool CanStillActivate => _mode switch
    {
        ActivationMode.Once => _activationCount < 1,
        ActivationMode.NTimes => _activationCount < _maxActivations,
        ActivationMode.Repeating => true,
        _ => false
    };

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { /* No statics to reset */ }

    void Reset()
    {
        // Auto-configure Rigidbody as kinematic trigger on first add
        var rb = GetComponent<Rigidbody>();
        rb.isKinematic = true;
        rb.useGravity = false;
        GetComponent<Collider>().isTrigger = true;
    }

    void OnTriggerEnter(Collider other)
    {
        if (!PassesFilter(other)) return;
        if (!CanActivate()) return;
        _ = ActivateAsync();
    }

    /// <summary>
    /// Force-activate this trigger from code, bypassing collision detection.
    /// Still respects cooldown and activation count rules.
    /// </summary>
    public void ForceActivate()
    {
        if (!CanActivate()) return;
        _ = ActivateAsync();
    }

    /// <summary>Reset activation count, allowing the trigger to fire again.</summary>
    public void ResetActivations()
    {
        _activationCount = 0;
        _lastActivationTime = float.NegativeInfinity;
    }

    bool PassesFilter(Collider other)
    {
        if (!string.IsNullOrEmpty(_requiredTag) && !other.CompareTag(_requiredTag))
            return false;
        if ((_requiredLayer & (1 << other.gameObject.layer)) == 0)
            return false;
        return true;
    }

    bool CanActivate()
    {
        if (_activationInProgress) return false;
        if (!CanStillActivate) return false;
        if (Time.time - _lastActivationTime < _cooldownSeconds) return false;
        return true;
    }

    async Awaitable ActivateAsync()
    {
        _activationInProgress = true;

        try
        {
            if (_activationDelay > 0f)
                await Awaitable.WaitForSecondsAsync(_activationDelay, destroyCancellationToken);

            _activationCount++;
            _lastActivationTime = Time.time;
            _onActivated?.Raise();
        }
        catch (System.OperationCanceledException)
        {
            // Object destroyed during delay -- do nothing
        }
        finally
        {
            _activationInProgress = false;
        }
    }

    void OnDrawGizmos()
    {
        Gizmos.color = _gizmoColor;
        var col = GetComponent<Collider>();
        if (col is BoxCollider box)
        {
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.DrawCube(box.center, box.size);
            Gizmos.DrawWireCube(box.center, box.size);
        }
        else if (col is SphereCollider sphere)
        {
            Gizmos.DrawSphere(
                transform.TransformPoint(sphere.center),
                sphere.radius * Mathf.Max(transform.lossyScale.x,
                    transform.lossyScale.y, transform.lossyScale.z));
        }
    }
}
```

### GameEvent SO Channel (cross-ref unity-game-architecture)

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// ScriptableObject event channel. Raise from triggers, listen from any MonoBehaviour.
/// See unity-game-architecture for full pattern.
/// </summary>
[CreateAssetMenu(menuName = "Events/Game Event")]
public class GameEvent : ScriptableObject
{
    readonly List<GameEventListener> _listeners = new();

    /// <summary>Raise this event, notifying all registered listeners.</summary>
    public void Raise()
    {
        // Iterate backwards so listeners can safely unregister during callback
        for (int i = _listeners.Count - 1; i >= 0; i--)
            _listeners[i].OnEventRaised();
    }

    /// <summary>Register a listener.</summary>
    public void Register(GameEventListener listener) => _listeners.Add(listener);

    /// <summary>Unregister a listener.</summary>
    public void Unregister(GameEventListener listener) => _listeners.Remove(listener);
}
```

```csharp
using UnityEngine;
using UnityEngine.Events;

/// <summary>
/// MonoBehaviour that listens to a GameEvent SO and invokes a UnityEvent response.
/// </summary>
public class GameEventListener : MonoBehaviour
{
    [SerializeField] GameEvent _event;
    [SerializeField] UnityEvent _response;

    void OnEnable() => _event?.Register(this);
    void OnDisable() => _event?.Unregister(this);

    /// <summary>Called by the GameEvent when raised.</summary>
    public void OnEventRaised() => _response?.Invoke();
}
```

---

## 2. Complete EncounterController

Full encounter system with async wave progression, spawn point management, enemy tracking, and completion events.

### WaveDefinition

```csharp
using System;
using UnityEngine;

/// <summary>
/// Defines a single wave within an encounter.
/// </summary>
[Serializable]
public struct WaveDefinition
{
    /// <summary>Enemy prefab to spawn in this wave.</summary>
    [Tooltip("Prefab to instantiate for this wave.")]
    public GameObject EnemyPrefab;

    /// <summary>Number of enemies to spawn.</summary>
    [Tooltip("How many enemies to spawn.")]
    public int Count;

    /// <summary>Seconds to wait before starting this wave.</summary>
    [Tooltip("Delay before this wave begins (after previous wave completes).")]
    public float DelayBeforeWave;

    /// <summary>If true, all enemies in this wave must be destroyed before advancing.</summary>
    [Tooltip("If true, all enemies must be defeated before the next wave.")]
    public bool WaitForClear;

    /// <summary>Seconds between individual enemy spawns within this wave.</summary>
    [Tooltip("Stagger delay between individual spawns.")]
    public float SpawnInterval;
}
```

### EncounterConfig SO

```csharp
using UnityEngine;

/// <summary>
/// Data asset defining an entire encounter: waves, events, and rules.
/// Designers create these as assets and assign to EncounterController prefabs.
/// </summary>
[CreateAssetMenu(menuName = "Level Design/Encounter Config")]
public class EncounterConfig : ScriptableObject
{
    /// <summary>Ordered list of waves in this encounter.</summary>
    [Tooltip("Waves execute in order. Each wave can optionally wait for clear.")]
    public WaveDefinition[] Waves;

    /// <summary>Event raised when the encounter starts.</summary>
    [Tooltip("Raised when the first wave begins.")]
    public GameEvent OnEncounterStart;

    /// <summary>Event raised when all waves are completed.</summary>
    [Tooltip("Raised after the final wave is cleared.")]
    public GameEvent OnEncounterComplete;

    /// <summary>Event raised when a single wave is cleared.</summary>
    [Tooltip("Raised each time a wave's enemies are all defeated.")]
    public GameEvent OnWaveCleared;
}
```

### EncounterController

```csharp
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

/// <summary>
/// Runs an encounter defined by an EncounterConfig SO.
/// Spawns enemies at designated spawn points and tracks wave progression.
/// </summary>
public class EncounterController : MonoBehaviour
{
    [Header("Configuration")]
    [SerializeField] EncounterConfig _config;

    [Header("Spawn Points")]
    [Tooltip("Transforms where enemies can spawn. Cycled through round-robin.")]
    [SerializeField] Transform[] _spawnPoints;

    [Header("Activation")]
    [Tooltip("GameEvent that triggers this encounter (e.g., from a TriggerZone).")]
    [SerializeField] GameEvent _activationEvent;
    [SerializeField] bool _startOnActivation = true;

    readonly List<GameObject> _activeEnemies = new();
    bool _isRunning;
    int _currentWaveIndex;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { }

    /// <summary>Whether this encounter is currently in progress.</summary>
    public bool IsRunning => _isRunning;

    /// <summary>Current wave index (0-based).</summary>
    public int CurrentWaveIndex => _currentWaveIndex;

    /// <summary>Number of active (alive) enemies.</summary>
    public int ActiveEnemyCount
    {
        get
        {
            CleanDestroyedEnemies();
            return _activeEnemies.Count;
        }
    }

    /// <summary>Start the encounter. Safe to call externally or via GameEvent listener.</summary>
    public void StartEncounter()
    {
        if (_isRunning) return;
        _ = RunEncounterAsync(destroyCancellationToken);
    }

    async Awaitable RunEncounterAsync(CancellationToken ct)
    {
        _isRunning = true;
        _currentWaveIndex = 0;
        _config.OnEncounterStart?.Raise();

        for (int i = 0; i < _config.Waves.Length; i++)
        {
            ct.ThrowIfCancellationRequested();
            _currentWaveIndex = i;
            var wave = _config.Waves[i];

            // Pre-wave delay
            if (wave.DelayBeforeWave > 0f)
                await Awaitable.WaitForSecondsAsync(wave.DelayBeforeWave, ct);

            // Spawn enemies for this wave
            await SpawnWaveAsync(wave, ct);

            // Optionally wait for all enemies in this wave to be destroyed
            if (wave.WaitForClear)
                await WaitForClearAsync(ct);

            _config.OnWaveCleared?.Raise();
        }

        _isRunning = false;
        _config.OnEncounterComplete?.Raise();
    }

    async Awaitable SpawnWaveAsync(WaveDefinition wave, CancellationToken ct)
    {
        for (int i = 0; i < wave.Count; i++)
        {
            ct.ThrowIfCancellationRequested();

            Transform spawnPoint = _spawnPoints[i % _spawnPoints.Length];
            var enemy = Instantiate(wave.EnemyPrefab, spawnPoint.position, spawnPoint.rotation);
            _activeEnemies.Add(enemy);

            if (wave.SpawnInterval > 0f && i < wave.Count - 1)
                await Awaitable.WaitForSecondsAsync(wave.SpawnInterval, ct);
        }
    }

    async Awaitable WaitForClearAsync(CancellationToken ct)
    {
        while (ActiveEnemyCount > 0)
        {
            ct.ThrowIfCancellationRequested();
            await Awaitable.WaitForSecondsAsync(0.25f, ct);
        }
    }

    void CleanDestroyedEnemies()
    {
        _activeEnemies.RemoveAll(e => e == null);
    }

    void OnDrawGizmosSelected()
    {
        if (_spawnPoints == null) return;
        Gizmos.color = Color.red;
        foreach (var sp in _spawnPoints)
        {
            if (sp == null) continue;
            Gizmos.DrawWireSphere(sp.position, 0.5f);
            Gizmos.DrawLine(transform.position, sp.position);
        }
    }
}
```

---

## 3. Complete CheckpointSystem

Full checkpoint system with snapshot capture/restore, ICheckpointable interface, and checkpoint trigger.

### ICheckpointable Interface

```csharp
/// <summary>
/// Implement on any MonoBehaviour that needs to save/restore state at checkpoints.
/// Examples: doors, switches, destructible objects, inventory holders.
/// </summary>
public interface ICheckpointable
{
    /// <summary>
    /// Unique identifier for this object. Must be stable across checkpoint cycles.
    /// Use a serialized GUID field initialized in Reset().
    /// </summary>
    string CheckpointId { get; }

    /// <summary>
    /// Capture the current state as a serializable object.
    /// Return a struct or class that can be stored in a Dictionary.
    /// </summary>
    object CaptureState();

    /// <summary>
    /// Restore state from a previously captured object.
    /// The object passed will be the same type returned by CaptureState().
    /// </summary>
    void RestoreState(object state);
}
```

### CheckpointSnapshot

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Captures the full game state at a checkpoint: player transform and all
/// ICheckpointable object states.
/// </summary>
public class CheckpointSnapshot
{
    /// <summary>Player world position at checkpoint.</summary>
    public Vector3 PlayerPosition;

    /// <summary>Player world rotation at checkpoint.</summary>
    public Quaternion PlayerRotation;

    /// <summary>
    /// Per-object state keyed by ICheckpointable.CheckpointId.
    /// Values are whatever each object returned from CaptureState().
    /// </summary>
    public Dictionary<string, object> ObjectStates = new();

    /// <summary>Name of the checkpoint that created this snapshot (for debugging).</summary>
    public string CheckpointName;

    /// <summary>Time.time when this snapshot was taken.</summary>
    public float Timestamp;
}
```

### CheckpointSystem Manager

```csharp
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

/// <summary>
/// Manages checkpoint save/restore. Singleton that lives in a persistent scene.
/// Call SaveCheckpoint when the player enters a checkpoint trigger.
/// Call RestoreCheckpoint when the player dies.
/// </summary>
public class CheckpointSystem : MonoBehaviour
{
    /// <summary>Singleton instance.</summary>
    public static CheckpointSystem Instance { get; private set; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() => Instance = null;

    [SerializeField] GameEvent _onCheckpointSaved;
    [SerializeField] GameEvent _onCheckpointRestored;

    CheckpointSnapshot _currentSnapshot;
    ICheckpointable[] _checkpointableCache;
    bool _cacheDirty = true;

    /// <summary>Whether a checkpoint snapshot exists.</summary>
    public bool HasCheckpoint => _currentSnapshot != null;

    /// <summary>Name of the current checkpoint, or null.</summary>
    public string CurrentCheckpointName => _currentSnapshot?.CheckpointName;

    void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
    }

    /// <summary>
    /// Mark the cache as dirty. Call when scenes are loaded/unloaded
    /// so FindCheckpointables rescans.
    /// </summary>
    public void InvalidateCache() => _cacheDirty = true;

    /// <summary>
    /// Capture a checkpoint snapshot from the player and all ICheckpointable objects.
    /// </summary>
    /// <param name="player">Player transform to save position/rotation.</param>
    /// <param name="checkpointName">Debug name for this checkpoint.</param>
    public void SaveCheckpoint(Transform player, string checkpointName = "")
    {
        _currentSnapshot = new CheckpointSnapshot
        {
            PlayerPosition = player.position,
            PlayerRotation = player.rotation,
            CheckpointName = checkpointName,
            Timestamp = Time.time
        };

        foreach (var obj in GetCheckpointables())
        {
            _currentSnapshot.ObjectStates[obj.CheckpointId] = obj.CaptureState();
        }

        _onCheckpointSaved?.Raise();
    }

    /// <summary>
    /// Restore the last checkpoint snapshot. Returns false if no checkpoint exists.
    /// </summary>
    /// <param name="player">Player transform to restore position/rotation.</param>
    public bool RestoreCheckpoint(Transform player)
    {
        if (_currentSnapshot == null) return false;

        player.position = _currentSnapshot.PlayerPosition;
        player.rotation = _currentSnapshot.PlayerRotation;

        // Reset velocity if player has a Rigidbody
        if (player.TryGetComponent<Rigidbody>(out var rb))
        {
            rb.linearVelocity = Vector3.zero;
            rb.angularVelocity = Vector3.zero;
        }

        foreach (var obj in GetCheckpointables())
        {
            if (_currentSnapshot.ObjectStates.TryGetValue(obj.CheckpointId, out var state))
                obj.RestoreState(state);
        }

        _onCheckpointRestored?.Raise();
        return true;
    }

    /// <summary>Clear the current checkpoint (e.g., on new game).</summary>
    public void ClearCheckpoint() => _currentSnapshot = null;

    ICheckpointable[] GetCheckpointables()
    {
        if (_cacheDirty || _checkpointableCache == null)
        {
            _checkpointableCache = FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None)
                .OfType<ICheckpointable>()
                .ToArray();
            _cacheDirty = false;
        }
        return _checkpointableCache;
    }
}
```

### CheckpointTrigger

```csharp
using UnityEngine;

/// <summary>
/// Trigger zone that saves a checkpoint when the player enters.
/// Extends the TriggerZone pattern (Pattern 1) conceptually.
/// Uses its own OnTriggerEnter for direct CheckpointSystem integration.
/// </summary>
[RequireComponent(typeof(Collider), typeof(Rigidbody))]
public class CheckpointTrigger : MonoBehaviour
{
    [SerializeField] string _checkpointName;
    [SerializeField] string _requiredTag = "Player";
    [SerializeField] bool _activateOnce = true;
    [SerializeField] GameEvent _onCheckpointActivated;

    bool _hasActivated;

    void Reset()
    {
        var rb = GetComponent<Rigidbody>();
        rb.isKinematic = true;
        rb.useGravity = false;
        GetComponent<Collider>().isTrigger = true;
    }

    void OnTriggerEnter(Collider other)
    {
        if (_activateOnce && _hasActivated) return;
        if (!string.IsNullOrEmpty(_requiredTag) && !other.CompareTag(_requiredTag)) return;

        if (CheckpointSystem.Instance == null)
        {
            Debug.LogError($"[CheckpointTrigger] No CheckpointSystem found. " +
                           $"Ensure one exists in a persistent scene.", this);
            return;
        }

        CheckpointSystem.Instance.SaveCheckpoint(other.transform, _checkpointName);
        _hasActivated = true;
        _onCheckpointActivated?.Raise();
    }

    void OnDrawGizmos()
    {
        Gizmos.color = _hasActivated
            ? new Color(0f, 1f, 0f, 0.3f)
            : new Color(1f, 1f, 0f, 0.3f);

        var col = GetComponent<Collider>();
        if (col is BoxCollider box)
        {
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.DrawCube(box.center, box.size);
        }
    }
}
```

### Example ICheckpointable Implementation

```csharp
using System;
using UnityEngine;

/// <summary>
/// Example: a door that saves its open/closed state at checkpoints.
/// </summary>
public class CheckpointableDoor : MonoBehaviour, ICheckpointable
{
    [SerializeField] string _id;

    bool _isOpen;

    /// <summary>Stable checkpoint identifier.</summary>
    public string CheckpointId => _id;

    void Reset()
    {
        // Generate a stable GUID on first add
        if (string.IsNullOrEmpty(_id))
            _id = Guid.NewGuid().ToString();
    }

    /// <summary>Open or close the door.</summary>
    public void SetOpen(bool open)
    {
        _isOpen = open;
        // Apply visual state (animation, collider toggle, etc.)
    }

    /// <inheritdoc/>
    public object CaptureState() => _isOpen;

    /// <inheritdoc/>
    public void RestoreState(object state)
    {
        if (state is bool open)
            SetOpen(open);
    }
}
```

---

## 4. Complete SequencePlayer

Full scripted sequence system with ISequenceStep, SequencePlayer, and concrete step implementations.

### ISequenceStep Interface

```csharp
using System.Threading;

/// <summary>
/// A single step in a scripted sequence (cutscene, tutorial, event).
/// Steps are composed in the Inspector via [SerializeReference].
/// </summary>
public interface ISequenceStep
{
    /// <summary>
    /// Execute this step asynchronously. Must respect cancellation for skip support.
    /// When cancelled, apply the end state immediately rather than leaving
    /// the step half-complete.
    /// </summary>
    Awaitable ExecuteAsync(CancellationToken ct);
}
```

### SequencePlayer

```csharp
using System;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

/// <summary>
/// Plays a sequence of ISequenceStep instances in order.
/// Steps are authored in the Inspector via [SerializeReference].
/// Supports skip (cancellation) and completion events.
/// </summary>
public class SequencePlayer : MonoBehaviour
{
    [SerializeReference]
    List<ISequenceStep> _steps = new();

    [Header("Playback")]
    [SerializeField] bool _playOnStart;
    [SerializeField] bool _disablePlayerInputDuringPlayback = true;

    [Header("Events")]
    [SerializeField] GameEvent _onSequenceStart;
    [SerializeField] GameEvent _onSequenceComplete;

    bool _isPlaying;
    CancellationTokenSource _skipSource;

    /// <summary>Whether a sequence is currently playing.</summary>
    public bool IsPlaying => _isPlaying;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { }

    async void Start()
    {
        if (_playOnStart)
            await PlayAsync(destroyCancellationToken);
    }

    /// <summary>
    /// Play the full sequence. External cancellation aborts immediately.
    /// Call Skip() for graceful skip (steps apply end states).
    /// </summary>
    public async Awaitable PlayAsync(CancellationToken ct = default)
    {
        if (_isPlaying) return;
        _isPlaying = true;

        _skipSource = new CancellationTokenSource();
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(
            ct, destroyCancellationToken, _skipSource.Token);

        _onSequenceStart?.Raise();

        foreach (var step in _steps)
        {
            if (linked.Token.IsCancellationRequested) break;

            try
            {
                await step.ExecuteAsync(linked.Token);
            }
            catch (OperationCanceledException)
            {
                // Step was skipped or sequence was cancelled
                break;
            }
        }

        _skipSource?.Dispose();
        _skipSource = null;
        _isPlaying = false;
        _onSequenceComplete?.Raise();
    }

    /// <summary>
    /// Skip the current sequence. Steps should apply their end state
    /// when they detect cancellation.
    /// </summary>
    public void Skip()
    {
        _skipSource?.Cancel();
    }
}
```

### CameraMoveStep

```csharp
using System;
using System.Threading;
using UnityEngine;

/// <summary>
/// Sequence step: smoothly move the camera to a target transform over a duration.
/// On skip, snaps immediately to the target.
/// </summary>
[Serializable]
public class CameraMoveStep : ISequenceStep
{
    [Tooltip("Target position and rotation for the camera.")]
    [SerializeField] Transform _target;

    [Tooltip("Duration of the camera move in seconds.")]
    [SerializeField] float _duration = 1f;

    [Tooltip("Easing curve for the move.")]
    [SerializeField] AnimationCurve _easeCurve = AnimationCurve.EaseInOut(0f, 0f, 1f, 1f);

    /// <inheritdoc/>
    public async Awaitable ExecuteAsync(CancellationToken ct)
    {
        var cam = Camera.main;
        if (cam == null || _target == null) return;

        Transform camTransform = cam.transform;
        Vector3 startPos = camTransform.position;
        Quaternion startRot = camTransform.rotation;
        float elapsed = 0f;

        while (elapsed < _duration)
        {
            if (ct.IsCancellationRequested)
            {
                // Skip: snap to end state
                camTransform.SetPositionAndRotation(_target.position, _target.rotation);
                return;
            }

            elapsed += Time.deltaTime;
            float t = _easeCurve.Evaluate(Mathf.Clamp01(elapsed / _duration));
            camTransform.position = Vector3.Lerp(startPos, _target.position, t);
            camTransform.rotation = Quaternion.Slerp(startRot, _target.rotation, t);

            await Awaitable.NextFrameAsync(ct);
        }

        camTransform.SetPositionAndRotation(_target.position, _target.rotation);
    }
}
```

### WaitStep

```csharp
using System;
using System.Threading;
using UnityEngine;

/// <summary>
/// Sequence step: wait for a specified duration. Instantly skippable.
/// </summary>
[Serializable]
public class WaitStep : ISequenceStep
{
    [Tooltip("How long to wait in seconds.")]
    [SerializeField] float _duration = 1f;

    /// <inheritdoc/>
    public async Awaitable ExecuteAsync(CancellationToken ct)
    {
        await Awaitable.WaitForSecondsAsync(_duration, ct);
    }
}
```

### SetActiveStep

```csharp
using System;
using System.Threading;
using UnityEngine;

/// <summary>
/// Sequence step: enable or disable a GameObject. Executes instantly.
/// </summary>
[Serializable]
public class SetActiveStep : ISequenceStep
{
    [Tooltip("Target GameObject to enable/disable.")]
    [SerializeField] GameObject _target;

    [Tooltip("Whether to activate (true) or deactivate (false).")]
    [SerializeField] bool _active = true;

    /// <inheritdoc/>
    public Awaitable ExecuteAsync(CancellationToken ct)
    {
        if (_target != null)
            _target.SetActive(_active);
        return Awaitable.NextFrameAsync(ct);
    }
}
```

### PlayAnimationStep

```csharp
using System;
using System.Threading;
using UnityEngine;

/// <summary>
/// Sequence step: trigger an Animator state. Waits for the animation to complete
/// or skips immediately.
/// </summary>
[Serializable]
public class PlayAnimationStep : ISequenceStep
{
    [Tooltip("Animator to control.")]
    [SerializeField] Animator _animator;

    [Tooltip("Trigger parameter name to set.")]
    [SerializeField] string _triggerName;

    [Tooltip("Animator layer to check for completion.")]
    [SerializeField] int _layer;

    [Tooltip("Expected animation duration. Used for wait.")]
    [SerializeField] float _expectedDuration = 1f;

    /// <inheritdoc/>
    public async Awaitable ExecuteAsync(CancellationToken ct)
    {
        if (_animator == null) return;

        _animator.SetTrigger(_triggerName);

        float elapsed = 0f;
        while (elapsed < _expectedDuration)
        {
            if (ct.IsCancellationRequested) return;
            elapsed += Time.deltaTime;
            await Awaitable.NextFrameAsync(ct);
        }
    }
}
```

### DialogueStep

```csharp
using System;
using System.Threading;
using UnityEngine;

/// <summary>
/// Sequence step: display dialogue text and wait for a duration or skip.
/// Integrate with your UI system -- this is a minimal scaffold.
/// </summary>
[Serializable]
public class DialogueStep : ISequenceStep
{
    [Tooltip("Speaker name.")]
    [SerializeField] string _speaker;

    [TextArea(3, 6)]
    [Tooltip("Dialogue text to display.")]
    [SerializeField] string _text;

    [Tooltip("How long to show before auto-advancing.")]
    [SerializeField] float _displayDuration = 3f;

    /// <inheritdoc/>
    public async Awaitable ExecuteAsync(CancellationToken ct)
    {
        // Show dialogue UI -- replace with your UI Toolkit integration
        Debug.Log($"[Dialogue] {_speaker}: {_text}");

        try
        {
            await Awaitable.WaitForSecondsAsync(_displayDuration, ct);
        }
        catch (OperationCanceledException)
        {
            // Skipped -- hide dialogue immediately
        }

        // Hide dialogue UI
        Debug.Log("[Dialogue] Hidden");
    }
}
```

---

## 5. Complete Interactable System

Player-side interaction detection, interactable component, and example interaction implementations.

### IInteraction Interface

```csharp
using UnityEngine;

/// <summary>
/// Defines an interaction behavior. Implement per interaction type.
/// Assigned to Interactable components via [SerializeReference].
/// </summary>
public interface IInteraction
{
    /// <summary>Text displayed on the interaction prompt (e.g., "Read Note", "Play Log").</summary>
    string PromptText { get; }

    /// <summary>Execute the interaction when the player confirms.</summary>
    /// <param name="interactor">The GameObject performing the interaction (usually the player).</param>
    void Execute(GameObject interactor);
}
```

### Interactable Component

```csharp
using UnityEngine;

/// <summary>
/// Marks a GameObject as interactable. Holds an IInteraction behavior
/// and the detection range for the interaction.
/// </summary>
public class Interactable : MonoBehaviour
{
    [Tooltip("Maximum distance from which the player can interact.")]
    [SerializeField] float _interactionRange = 2f;

    [Tooltip("The interaction behavior. Assigned via [SerializeReference].")]
    [SerializeReference] IInteraction _interaction;

    [Tooltip("Optional: world-space offset for the prompt position.")]
    [SerializeField] Vector3 _promptOffset = Vector3.up * 2f;

    /// <summary>Maximum interaction distance.</summary>
    public float InteractionRange => _interactionRange;

    /// <summary>The interaction behavior.</summary>
    public IInteraction Interaction => _interaction;

    /// <summary>World-space position for the interaction prompt.</summary>
    public Vector3 PromptWorldPosition => transform.position + _promptOffset;

    /// <summary>Whether this interactable has a valid interaction assigned.</summary>
    public bool IsValid => _interaction != null;

    void OnDrawGizmosSelected()
    {
        Gizmos.color = new Color(0f, 0.8f, 1f, 0.3f);
        Gizmos.DrawWireSphere(transform.position, _interactionRange);

        Gizmos.color = Color.cyan;
        Gizmos.DrawSphere(PromptWorldPosition, 0.1f);
    }
}
```

### InteractionDetector (Player-Side)

```csharp
using UnityEngine;

/// <summary>
/// Attach to the player. Detects nearby Interactables, shows prompts,
/// and executes interactions on input.
/// Cross-ref unity-input-correctness for Input System integration.
/// </summary>
public class InteractionDetector : MonoBehaviour
{
    [Header("Detection")]
    [Tooltip("Radius to scan for interactables.")]
    [SerializeField] float _detectionRadius = 5f;

    [Tooltip("Layer mask for interactable objects.")]
    [SerializeField] LayerMask _interactableLayer;

    [Header("UI")]
    [Tooltip("UI document for the interaction prompt (UI Toolkit).")]
    [SerializeField] UnityEngine.UIElements.UIDocument _promptDocument;

    Interactable _currentTarget;
    Camera _cachedCamera;
    readonly Collider[] _overlapBuffer = new Collider[16];

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { }

    void Start()
    {
        _cachedCamera = Camera.main;
        HidePrompt();
    }

    void Update()
    {
        var previous = _currentTarget;
        _currentTarget = FindClosestInteractable();

        if (_currentTarget != previous)
        {
            if (_currentTarget != null && _currentTarget.IsValid)
                ShowPrompt(_currentTarget);
            else
                HidePrompt();
        }

        if (_currentTarget != null)
            UpdatePromptPosition(_currentTarget);

        // Input check -- replace with Input System action
        // See unity-input-correctness for proper Input System usage
        // Example: if (_interactAction.WasPressedThisFrame()) TryInteract();
    }

    /// <summary>
    /// Execute the current interaction. Call from Input System action callback.
    /// </summary>
    public void TryInteract()
    {
        if (_currentTarget == null || !_currentTarget.IsValid) return;
        _currentTarget.Interaction.Execute(gameObject);
    }

    Interactable FindClosestInteractable()
    {
        int count = Physics.OverlapSphereNonAlloc(
            transform.position, _detectionRadius, _overlapBuffer, _interactableLayer);

        Interactable closest = null;
        float closestDist = float.MaxValue;

        for (int i = 0; i < count; i++)
        {
            if (!_overlapBuffer[i].TryGetComponent<Interactable>(out var interactable))
                continue;
            if (!interactable.IsValid) continue;

            float dist = Vector3.Distance(transform.position, interactable.transform.position);
            if (dist > interactable.InteractionRange) continue;

            if (dist < closestDist)
            {
                closest = interactable;
                closestDist = dist;
            }
        }

        return closest;
    }

    void ShowPrompt(Interactable target)
    {
        if (_promptDocument == null) return;
        var root = _promptDocument.rootVisualElement;
        root.style.display = UnityEngine.UIElements.DisplayStyle.Flex;

        var label = root.Q<UnityEngine.UIElements.Label>("prompt-text");
        if (label != null)
            label.text = target.Interaction.PromptText;
    }

    void HidePrompt()
    {
        if (_promptDocument == null) return;
        _promptDocument.rootVisualElement.style.display =
            UnityEngine.UIElements.DisplayStyle.None;
    }

    void UpdatePromptPosition(Interactable target)
    {
        if (_cachedCamera == null || _promptDocument == null) return;

        Vector3 screenPos = _cachedCamera.WorldToScreenPoint(target.PromptWorldPosition);

        // Off-screen check: if behind camera, hide
        if (screenPos.z < 0)
        {
            HidePrompt();
            return;
        }

        // Convert to UI Toolkit coordinates (origin top-left)
        float uiX = screenPos.x;
        float uiY = Screen.height - screenPos.y;

        var root = _promptDocument.rootVisualElement;
        root.style.left = uiX;
        root.style.top = uiY;
    }
}
```

### ReadNoteInteraction Example

```csharp
using System;
using UnityEngine;

/// <summary>
/// Interaction: display a readable note/document to the player.
/// </summary>
[Serializable]
public class ReadNoteInteraction : IInteraction
{
    [SerializeField] string _promptText = "Read Note";

    [TextArea(5, 15)]
    [SerializeField] string _noteContent;

    [SerializeField] string _noteTitle;

    /// <inheritdoc/>
    public string PromptText => _promptText;

    /// <inheritdoc/>
    public void Execute(GameObject interactor)
    {
        // Replace with your UI system -- show note panel with title and content
        Debug.Log($"[Note] {_noteTitle}\n{_noteContent}");
    }
}
```

### PlayAudioLogInteraction Example

```csharp
using System;
using UnityEngine;

/// <summary>
/// Interaction: play an audio log with optional subtitle text.
/// </summary>
[Serializable]
public class PlayAudioLogInteraction : IInteraction
{
    [SerializeField] string _promptText = "Play Audio Log";
    [SerializeField] AudioClip _audioClip;
    [SerializeField] string _subtitleText;

    /// <inheritdoc/>
    public string PromptText => _promptText;

    /// <inheritdoc/>
    public void Execute(GameObject interactor)
    {
        if (_audioClip == null) return;

        // Play audio at the interactor's position
        AudioSource.PlayClipAtPoint(_audioClip, interactor.transform.position);

        // Show subtitles -- replace with your subtitle system
        if (!string.IsNullOrEmpty(_subtitleText))
            Debug.Log($"[AudioLog] {_subtitleText}");
    }
}
```

---

## 6. Level Architecture Diagram

```
LEVEL DESIGN SYSTEM ARCHITECTURE
=================================

  SCENE (Designer-authored)            DATA ASSETS (Designer-configured)
  +--------------------------------+   +--------------------------------+
  |                                |   |                                |
  |  [TriggerZone]                 |   |  [GameEvent SO]                |
  |    tag: Player                 |   |    "EncounterStart_Arena1"     |
  |    mode: Once              ----+-->|                                |
  |    event: EncounterStart       |   +-------+------------------------+
  |                                |           |
  |  [EncounterController]        |           |  Listener
  |    config: ArenaEncounter  <---+-----------+
  |    spawnPoints: [A, B, C]      |   +--------------------------------+
  |                                |   |  [EncounterConfig SO]          |
  |  [CheckpointTrigger]          |   |    "ArenaEncounter"            |
  |    name: "Arena Entrance"      |   |    waves:                     |
  |                                |   |      [0] Zombie x3, delay 0s  |
  |  [StreamingVolume]            |   |      [1] Skeleton x5, delay 5s |
  |    chunk: CaveSection_B        |   |    onComplete: ArenaComplete   |
  |    preload: 50m                |   +--------------------------------+
  |    unload:  80m                |
  |                                |   +--------------------------------+
  |  [Interactable]               |   |  [LevelChunkConfig SO]         |
  |    interaction: ReadNote       |   |    "CaveSection_B"            |
  |    range: 2m                   |   |    scene: cave_b.unity         |
  |                                |   |    preloadDist: 50            |
  |  [SequencePlayer]            |   |    unloadDist: 80             |
  |    steps:                      |   +--------------------------------+
  |      CameraMoveStep            |
  |      DialogueStep              |
  |      WaitStep                  |
  |      SetActiveStep             |
  +--------------------------------+

FLOW: Trigger --> Event --> System --> Completion Event
=======================================================

  Player enters       GameEvent SO         EncounterController      GameEvent SO
  TriggerZone    -->  "EncounterStart" --> reads EncounterConfig --> "EncounterComplete"
       |                                        |                        |
       |                                        v                        v
       |                                   Spawn waves             Door opens,
       |                                   Track enemies           next trigger
       |                                   Report clear            enabled, etc.
       v
  CheckpointSystem
  saves snapshot

CHECKPOINT SAVE/RESTORE FLOW
==============================

  [Save]                              [Restore (on death)]
  Player enters checkpoint            DeathHandler calls RestoreCheckpoint
       |                                     |
       v                                     v
  CheckpointSystem.SaveCheckpoint     CheckpointSystem.RestoreCheckpoint
       |                                     |
       +---> Save player pos/rot             +---> Restore player pos/rot
       |                                     |
       +---> For each ICheckpointable:       +---> For each ICheckpointable:
                CaptureState()                       RestoreState(saved)
                store in snapshot                    apply saved state
                                                     |
  Snapshot stored in memory                  Door re-opens, switch resets,
  (not saved to disk -- see                  enemies stay dead (if saved),
   unity-save-system for persistence)        inventory restored

STREAMING VOLUME LIFECYCLE
===========================

  Player distance    0m -------- 50m --------- 80m ---------> far
                      |           |              |
                      |   LOADED  |  HYSTERESIS  |  UNLOADED
                      |           |    BUFFER    |
                      |           |              |
  Moving toward:      |     <-- PreloadDist      |
                      |    Addressables.LoadScene |
                      |                          |
  Moving away:        |              UnloadDist ->|
                      |         Addressables.UnloadScene
                      |                          |
  Buffer prevents thrashing when player          |
  hovers near the boundary                       |

SEQUENCE STEP EXECUTION
=========================

  SequencePlayer.PlayAsync()
       |
       v
  For each ISequenceStep:
       |
       +---> step.ExecuteAsync(cancellationToken)
       |          |
       |          +---> Normal completion: next step
       |          |
       |          +---> Cancellation (skip):
       |                  Apply end state immediately
       |                  Break loop
       |
       v
  _onSequenceComplete.Raise()
```

---

**Cross-references:**
- Parent patterns: `skills/unity-level-design/SKILL.md`
- GameEvent SO channel: `unity-game-architecture`
- Addressable scene loading: `unity-scene-assets`
- Async/Awaitable patterns: `unity-async-patterns`
- Input System integration: `unity-input-correctness`
- Persistent save data: `unity-save-system`
