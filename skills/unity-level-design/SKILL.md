---
name: unity-level-design
description: >
  Unity level design-to-code translation. Trigger & event architecture, encounter design
  contracts, checkpoint & respawn, cinematic & scripted sequences, environmental storytelling
  hooks, level streaming & loading seams. DESIGN INTENT format: INTENT/WRONG/RIGHT/SCAFFOLD/
  DESIGN HOOK. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.unity"
  - "**/*.asset"
---

# Level Design -- Design Translation Patterns

> **Prerequisite skills:** `unity-scene-assets` (additive scenes, Addressables), `unity-async-patterns` (async loading, cancellation), `unity-game-architecture` (SO events, bootstrap)

Claude treats levels as static scene files with no contract layer between level designers and gameplay programmers. Triggers are one-off scripts with game logic jammed into `OnTriggerEnter`, encounters are hardcoded spawn sequences, and checkpoints break on scene reload because nobody thought about what state needs to survive. These patterns establish the translation layer: designers author intent through data assets and Inspector configuration, programmers provide the systems that honor that intent.

---

## PATTERN 1: Trigger & Event Architecture

DESIGN INTENT: Level designers place trigger volumes in the editor that fire game events -- spawn enemies, play dialogue, open a door. The trigger is a generic, reusable component; the response is wired in the Inspector via ScriptableObject event channels.

WRONG:
```csharp
// Each trigger is a bespoke script -- 47 of these in the project
public class Door3Trigger : MonoBehaviour
{
    public GameObject door;
    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
            door.GetComponent<Animator>().SetTrigger("Open");
    }
}
```
Every trigger is a unique MonoBehaviour. No reuse, no designer control, no way to disable or reconfigure without code changes.

RIGHT: Generic `TriggerZone` component with configurable activation rules and SO event channel output. Designer wires event in Inspector -- zero per-trigger code.
```csharp
using UnityEngine;

/// <summary>
/// Generic trigger volume that raises a GameEvent SO channel on activation.
/// Configurable activation count, tag filter, cooldown, and delay.
/// </summary>
[RequireComponent(typeof(Collider), typeof(Rigidbody))]
public class TriggerZone : MonoBehaviour
{
    public enum ActivationMode { Once, Repeating, NTimes }

    [Header("Activation Rules")]
    [SerializeField] ActivationMode _mode = ActivationMode.Once;
    [SerializeField] int _maxActivations = 1;
    [SerializeField] float _cooldownSeconds;
    [SerializeField] float _activationDelay;
    [SerializeField] string _requiredTag = "Player";
    [SerializeField] LayerMask _requiredLayer = ~0;

    [Header("Event Output")]
    [SerializeField] GameEvent _onActivated;

    int _activationCount;
    float _lastActivationTime = float.NegativeInfinity;

    // See unity-game-architecture for GameEvent SO channel pattern

    void Reset()
    {
        // Guarantee Rigidbody is kinematic and collider is trigger
        var rb = GetComponent<Rigidbody>();
        rb.isKinematic = true;
        GetComponent<Collider>().isTrigger = true;
    }

    void OnTriggerEnter(Collider other)
    {
        if (!PassesFilter(other)) return;
        if (!CanActivate()) return;
        _ = ActivateAsync();
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
        if (_mode == ActivationMode.Once && _activationCount >= 1) return false;
        if (_mode == ActivationMode.NTimes && _activationCount >= _maxActivations) return false;
        if (Time.time - _lastActivationTime < _cooldownSeconds) return false;
        return true;
    }

    async Awaitable ActivateAsync()
    {
        if (_activationDelay > 0f)
            await Awaitable.WaitForSecondsAsync(_activationDelay, destroyCancellationToken);

        _activationCount++;
        _lastActivationTime = Time.time;
        _onActivated?.Raise();
    }
}
```

SCAFFOLD:
- `TriggerZone` MonoBehaviour (above) -- the generic trigger component
- `GameEvent` ScriptableObject channel -- cross-ref `unity-game-architecture`
- `TriggerConfig` fields -- activation mode, count, cooldown, delay, tag/layer filter

DESIGN HOOK: Designers place trigger volumes in the scene, assign a `GameEvent` SO in the Inspector, and configure activation rules. Zero per-trigger code. New trigger behaviors = new `GameEvent` listeners, not new trigger scripts.

GOTCHA: `OnTriggerEnter` requires one collider to have `isTrigger = true` and at least one Rigidbody in the pair. The `TriggerZone` adds its own kinematic Rigidbody via `[RequireComponent]` and sets it up in `Reset()` to guarantee this works regardless of what enters. Without this, triggers silently fail when the entering object has no Rigidbody.

---

## PATTERN 2: Encounter Design Contracts

DESIGN INTENT: Designers define encounters (enemy waves, arena lockdowns, puzzles) as data assets and place them in levels via prefabs. The encounter definition is separate from the encounter instance.

WRONG:
```csharp
// Hardcoded encounter -- can't reuse, can't tune without code changes
public class ArenaEncounter : MonoBehaviour
{
    public GameObject zombiePrefab;
    public GameObject skeletonPrefab;

    async Awaitable Start()
    {
        // Wave 1
        Instantiate(zombiePrefab, transform.position, Quaternion.identity);
        Instantiate(zombiePrefab, transform.position + Vector3.right * 3, Quaternion.identity);
        await Awaitable.WaitForSecondsAsync(10f);
        // Wave 2
        Instantiate(skeletonPrefab, transform.position, Quaternion.identity);
    }
}
```
Every encounter is a unique script. Wave timing, enemy types, and spawn positions are all hardcoded.

RIGHT: `EncounterConfig` SO defines waves as data. `EncounterController` prefab reads the config and manages spawning.
```csharp
using System;
using UnityEngine;

/// <summary>
/// Defines a single wave within an encounter: enemy types, counts, and timing.
/// </summary>
[Serializable]
public struct WaveDefinition
{
    /// <summary>Enemy prefab to spawn in this wave.</summary>
    public GameObject EnemyPrefab;
    /// <summary>Number of enemies to spawn.</summary>
    public int Count;
    /// <summary>Seconds to wait before starting this wave (after previous completes).</summary>
    public float DelayBeforeWave;
    /// <summary>If true, all enemies must be defeated before next wave starts.</summary>
    public bool WaitForClear;
}

/// <summary>
/// Data asset defining an entire encounter: sequence of waves and completion rules.
/// </summary>
[CreateAssetMenu(menuName = "Level Design/Encounter Config")]
public class EncounterConfig : ScriptableObject
{
    /// <summary>Ordered list of waves in this encounter.</summary>
    public WaveDefinition[] Waves;
    /// <summary>Event raised when the encounter begins.</summary>
    public GameEvent OnEncounterStart;
    /// <summary>Event raised when all waves are cleared.</summary>
    public GameEvent OnEncounterComplete;
}
```

```csharp
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

/// <summary>
/// Runs an encounter defined by an EncounterConfig SO.
/// Place in scene with spawn point transforms as children.
/// </summary>
public class EncounterController : MonoBehaviour
{
    [SerializeField] EncounterConfig _config;
    [SerializeField] Transform[] _spawnPoints;
    [SerializeField] GameEvent _triggerEvent; // Listens for this to start

    readonly List<GameObject> _activeEnemies = new();

    // Full implementation in references/level-system-scaffolds.md
}
```

SCAFFOLD:
- `EncounterConfig` SO -- wave definitions, completion events
- `WaveDefinition` serializable struct -- enemy prefab, count, timing, clear condition
- `EncounterController` MonoBehaviour -- async wave progression, spawn management

DESIGN HOOK: Designers create `EncounterConfig` SOs per encounter and place `EncounterController` prefabs at encounter locations. Spawn points are child Transforms on the controller. Tuning wave counts, timing, and enemy types requires zero code changes.

GOTCHA: Spawn points must be defined per-encounter in the scene (Transform array on the controller), not in the SO. ScriptableObjects cannot reference scene objects -- they are project-level assets. If you put Transform references in the SO, they will be null at runtime.

---

## PATTERN 3: Checkpoint & Respawn

DESIGN INTENT: Players die and respawn at the last activated checkpoint. Checkpoint state survives across attempts -- doors stay opened, keys stay collected, enemies stay dead.

WRONG:
```csharp
// Full scene reload on death -- all progress lost
public class DeathHandler : MonoBehaviour
{
    public void OnPlayerDied()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }
}
```
Reloading the scene resets everything. Doors re-lock, enemies respawn, puzzles reset. The player must redo the entire level.

RIGHT: `CheckpointSystem` captures a `CheckpointSnapshot` on activation. On death, the snapshot is restored without a scene reload. Objects that need save/restore implement `ICheckpointable`.
```csharp
using UnityEngine;

/// <summary>
/// Implement on any object that needs to save/restore state at checkpoints.
/// </summary>
public interface ICheckpointable
{
    /// <summary>Unique ID for this object (use a serialized GUID).</summary>
    string CheckpointId { get; }
    /// <summary>Capture current state as serializable data.</summary>
    object CaptureState();
    /// <summary>Restore state from previously captured data.</summary>
    void RestoreState(object state);
}
```

```csharp
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Snapshot of all checkpointable state at a specific checkpoint.
/// </summary>
public class CheckpointSnapshot
{
    /// <summary>Player position at checkpoint activation.</summary>
    public Vector3 PlayerPosition;
    /// <summary>Player rotation at checkpoint activation.</summary>
    public Quaternion PlayerRotation;
    /// <summary>Saved state per checkpointable object, keyed by CheckpointId.</summary>
    public Dictionary<string, object> ObjectStates = new();
}
```

```csharp
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

/// <summary>
/// Manages checkpoint save/restore. Singleton, lives in persistent scene.
/// </summary>
public class CheckpointSystem : MonoBehaviour
{
    public static CheckpointSystem Instance { get; private set; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() => Instance = null;

    CheckpointSnapshot _currentSnapshot;

    void Awake()
    {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this;
    }

    /// <summary>
    /// Captures a checkpoint snapshot from the player and all ICheckpointable objects.
    /// </summary>
    public void SaveCheckpoint(Transform player)
    {
        _currentSnapshot = new CheckpointSnapshot
        {
            PlayerPosition = player.position,
            PlayerRotation = player.rotation
        };

        foreach (var obj in FindCheckpointables())
            _currentSnapshot.ObjectStates[obj.CheckpointId] = obj.CaptureState();
    }

    /// <summary>
    /// Restores the last checkpoint snapshot. Returns false if no checkpoint exists.
    /// </summary>
    public bool RestoreCheckpoint(Transform player)
    {
        if (_currentSnapshot == null) return false;

        player.position = _currentSnapshot.PlayerPosition;
        player.rotation = _currentSnapshot.PlayerRotation;

        foreach (var obj in FindCheckpointables())
        {
            if (_currentSnapshot.ObjectStates.TryGetValue(obj.CheckpointId, out var state))
                obj.RestoreState(state);
        }
        return true;
    }

    IEnumerable<ICheckpointable> FindCheckpointables() =>
        FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None).OfType<ICheckpointable>();
}
```

SCAFFOLD:
- `CheckpointSystem` manager (singleton, persistent scene) -- save/restore orchestration
- `CheckpointSnapshot` -- player transform + dictionary of object states
- `ICheckpointable` interface -- `CaptureState()` / `RestoreState(object)`
- `CheckpointTrigger` -- extends TriggerZone pattern (Pattern 1) to call `CheckpointSystem.SaveCheckpoint`

DESIGN HOOK: Objects implement `ICheckpointable` to participate in checkpoint save/restore (doors, switches, destructibles). Designers place checkpoint trigger volumes in the scene. The system handles the rest.

GOTCHA: The checkpoint must save ALL mutable state. If a door was opened between checkpoints, the opened state must be in the snapshot. Audit every gameplay object for `ICheckpointable` -- a single missing implementation means that object resets on death while everything else restores, creating impossible states. Also: `FindObjectsByType` is expensive -- cache the results if checkpoints are frequent.

---

## PATTERN 4: Cinematic & Scripted Sequences

DESIGN INTENT: In-game cutscenes, camera moves, NPC dialogue, and timed events as authored sequences that designers compose in the Inspector without writing code.

WRONG:
```csharp
// Coroutine chain -- fragile, not reusable, not skippable
IEnumerator PlayCutscene()
{
    camera.transform.position = new Vector3(10, 5, 0);
    yield return new WaitForSeconds(2f);
    npc.GetComponent<Animator>().SetTrigger("Talk");
    dialogueUI.Show("Welcome, hero!");
    yield return new WaitForSeconds(3f);
    door.SetActive(false);
}
```
Hardcoded positions, no cancellation, not skippable, uses deprecated coroutine pattern.

RIGHT: `ISequenceStep` interface with async `ExecuteAsync(CancellationToken)`. `SequencePlayer` runs steps in order. Steps are composed in the Inspector via `[SerializeReference]`.
```csharp
using System.Threading;

/// <summary>
/// A single step in a scripted sequence. Implement for each step type.
/// </summary>
public interface ISequenceStep
{
    /// <summary>
    /// Execute this step. Must respect cancellation for skip support.
    /// When cancelled, the step should immediately apply its end state.
    /// </summary>
    Awaitable ExecuteAsync(CancellationToken ct);
}
```

```csharp
using System;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

/// <summary>
/// Plays a sequence of ISequenceStep instances in order.
/// Steps are composed via [SerializeReference] in the Inspector.
/// </summary>
public class SequencePlayer : MonoBehaviour
{
    [SerializeReference] List<ISequenceStep> _steps = new();
    [SerializeField] bool _playOnStart;
    [SerializeField] GameEvent _onSequenceComplete;

    bool _isPlaying;

    /// <summary>Play the full sequence. Cancellation skips remaining steps.</summary>
    public async Awaitable PlayAsync(CancellationToken ct = default)
    {
        if (_isPlaying) return;
        _isPlaying = true;

        using var linked = CancellationTokenSource.CreateLinkedTokenSource(
            ct, destroyCancellationToken);

        foreach (var step in _steps)
        {
            if (linked.Token.IsCancellationRequested) break;

            try
            {
                await step.ExecuteAsync(linked.Token);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }

        _isPlaying = false;
        _onSequenceComplete?.Raise();
    }

    async void Start()
    {
        if (_playOnStart)
            await PlayAsync(destroyCancellationToken);
    }
}
```

Example step implementations:
```csharp
using System;
using System.Threading;
using UnityEngine;

/// <summary>Wait for a specified duration. Skippable via cancellation.</summary>
[Serializable]
public class WaitStep : ISequenceStep
{
    [SerializeField] float _duration = 1f;

    public async Awaitable ExecuteAsync(CancellationToken ct)
    {
        await Awaitable.WaitForSecondsAsync(_duration, ct);
    }
}

/// <summary>Enable or disable a GameObject.</summary>
[Serializable]
public class SetActiveStep : ISequenceStep
{
    [SerializeField] GameObject _target;
    [SerializeField] bool _active = true;

    public Awaitable ExecuteAsync(CancellationToken ct)
    {
        if (_target != null) _target.SetActive(_active);
        return Awaitable.NextFrameAsync(ct);
    }
}
```

SCAFFOLD:
- `ISequenceStep` interface -- `ExecuteAsync(CancellationToken)`
- `SequencePlayer` MonoBehaviour -- runs `[SerializeReference]` step list in order
- Step types: `CameraMoveStep`, `DialogueStep`, `WaitStep`, `SetActiveStep`

DESIGN HOOK: New sequence step = implement `ISequenceStep`. Designers compose sequences in the Inspector by adding/removing/reordering steps in the `[SerializeReference]` list. No code changes to create new cutscenes.

GOTCHA: `[SerializeReference]` requires concrete types in the same assembly or an assembly that references the interface assembly. Unity's default Inspector does not provide a nice UI for `[SerializeReference]` -- you need a custom PropertyDrawer or use a package like Odin Inspector / SerializeReferenceDropdown. Steps must handle cancellation gracefully: when cancelled (skip), apply the end state immediately (e.g., snap camera to final position) rather than leaving the step half-complete.

---

## PATTERN 5: Environmental Storytelling Hooks

DESIGN INTENT: Objects react to player proximity or interaction -- notes to read, audio logs to play, environmental animations to trigger. All interactive objects share a consistent UX pattern.

WRONG:
```csharp
// Each interactive object is a unique script with bespoke logic
public class Note47 : MonoBehaviour
{
    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player") && Input.GetKeyDown(KeyCode.E))
            UIManager.Instance.ShowNote("Note 47 text...");
    }
}
```
No shared interaction UX. Each object checks input differently. Prompt display is inconsistent. New interaction types require new scripts from scratch.

RIGHT: `Interactable` component with `IInteraction` interface. Shared `InteractionDetector` on the player handles proximity detection and input prompting.
```csharp
using UnityEngine;

/// <summary>
/// Interface for interaction behaviors. Implement per interaction type.
/// </summary>
public interface IInteraction
{
    /// <summary>Text shown on the interaction prompt (e.g., "Read Note").</summary>
    string PromptText { get; }
    /// <summary>Execute the interaction.</summary>
    void Execute(GameObject interactor);
}
```

```csharp
using UnityEngine;

/// <summary>
/// Marks a GameObject as interactable. Holds an IInteraction and detection range.
/// </summary>
public class Interactable : MonoBehaviour
{
    [SerializeField] float _interactionRange = 2f;
    [SerializeReference] IInteraction _interaction;

    /// <summary>Maximum distance for interaction.</summary>
    public float InteractionRange => _interactionRange;
    /// <summary>The interaction behavior attached to this object.</summary>
    public IInteraction Interaction => _interaction;
}
```

```csharp
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

/// <summary>
/// Player-side component. Detects nearby Interactables and handles input prompting.
/// Cross-ref unity-input-correctness for input handling.
/// </summary>
public class InteractionDetector : MonoBehaviour
{
    [SerializeField] float _detectionRadius = 5f;
    [SerializeField] LayerMask _interactableLayer;

    Interactable _currentTarget;
    readonly Collider[] _overlapBuffer = new Collider[16];

    void Update()
    {
        _currentTarget = FindClosestInteractable();

        if (_currentTarget != null)
        {
            ShowPrompt(_currentTarget.Interaction.PromptText);
            // Input check -- see unity-input-correctness for Input System usage
        }
        else
        {
            HidePrompt();
        }
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

    void ShowPrompt(string text) { /* UI Toolkit prompt -- see implementation in scaffolds */ }
    void HidePrompt() { /* Hide prompt UI */ }
}
```

SCAFFOLD:
- `Interactable` MonoBehaviour -- holds `IInteraction` via `[SerializeReference]`, detection range
- `IInteraction` interface -- `PromptText`, `Execute(GameObject interactor)`
- `InteractionDetector` on player -- proximity detection, prompt display, input handling
- Example: `ReadNoteInteraction` implements `IInteraction`

DESIGN HOOK: New interaction type = implement `IInteraction`. Designers configure prompt text, range, and interaction type on the prefab. Consistent UX across all interactive objects.

GOTCHA: Interaction prompt must use world-to-screen positioning (`Camera.main.WorldToScreenPoint`) and handle off-screen clamping. Use `Physics.OverlapSphereNonAlloc` with a pre-allocated buffer -- do not allocate every frame. `Camera.main` is a `FindObjectWithTag` call under the hood; cache the camera reference.

---

## PATTERN 6: Level Streaming & Loading Seams

DESIGN INTENT: Large levels load/unload sections as the player moves -- open world, long corridors, hub with connected areas. The player never sees a loading screen during gameplay.

WRONG:
```csharp
// Entire world in one scene
// 500 MB memory usage, 45-second load time, untestable
```
Everything in one scene. Artists can't work in parallel (merge conflicts). Memory usage is unbounded. Initial load time grows forever.

RIGHT: `StreamingVolume` trigger zones that additively load/unload scene chunks via Addressables (cross-ref `unity-scene-assets`). Preloading based on player proximity. Hysteresis to prevent thrashing.
```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.ResourceProviders;

/// <summary>
/// Configuration for a streamable level chunk.
/// </summary>
[CreateAssetMenu(menuName = "Level Design/Level Chunk Config")]
public class LevelChunkConfig : ScriptableObject
{
    /// <summary>Addressable scene asset reference for this chunk.</summary>
    public AssetReference SceneReference;
    /// <summary>Distance at which to begin preloading this chunk.</summary>
    public float PreloadDistance = 50f;
    /// <summary>Distance at which to unload this chunk (must be > PreloadDistance).</summary>
    public float UnloadDistance = 80f;
}
```

```csharp
using System.Threading;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceProviders;
using UnityEngine.SceneManagement;

/// <summary>
/// Manages loading/unloading a level chunk based on player proximity.
/// Place at the seam between level sections.
/// Cross-ref unity-scene-assets for Addressable scene loading patterns.
/// </summary>
public class StreamingVolume : MonoBehaviour
{
    [SerializeField] LevelChunkConfig _chunkConfig;
    [SerializeField] Transform _playerTransform;

    AsyncOperationHandle<SceneInstance> _loadHandle;
    bool _isLoaded;
    bool _isLoading;

    void Update()
    {
        if (_playerTransform == null) return;
        float distance = Vector3.Distance(transform.position, _playerTransform.position);

        if (!_isLoaded && !_isLoading && distance < _chunkConfig.PreloadDistance)
            _ = LoadChunkAsync(destroyCancellationToken);
        else if (_isLoaded && distance > _chunkConfig.UnloadDistance)
            _ = UnloadChunkAsync();
    }

    async Awaitable LoadChunkAsync(CancellationToken ct)
    {
        _isLoading = true;
        _loadHandle = Addressables.LoadSceneAsync(
            _chunkConfig.SceneReference, LoadSceneMode.Additive);

        while (!_loadHandle.IsDone)
        {
            ct.ThrowIfCancellationRequested();
            await Awaitable.NextFrameAsync(ct);
        }

        _isLoaded = true;
        _isLoading = false;
    }

    async Awaitable UnloadChunkAsync()
    {
        if (!_loadHandle.IsValid()) return;
        var unload = Addressables.UnloadSceneAsync(_loadHandle);

        while (!unload.IsDone)
            await Awaitable.NextFrameAsync(destroyCancellationToken);

        _isLoaded = false;
    }

    void OnDestroy()
    {
        if (_isLoaded && _loadHandle.IsValid())
            Addressables.UnloadSceneAsync(_loadHandle);
    }
}
```

SCAFFOLD:
- `StreamingVolume` MonoBehaviour -- proximity-based load/unload with hysteresis
- `LevelChunkConfig` SO -- scene reference, preload distance, unload distance
- Async Addressable scene loading/unloading (cross-ref `unity-scene-assets`)

DESIGN HOOK: Designers place streaming volumes at level seams and assign chunk configs. Chunk configs define which Addressable scene to load and at what distances. Preload distance < unload distance provides hysteresis.

GOTCHA: Adjacent chunks must share a small overlap zone. Objects at the seam (e.g., a bridge between two areas) must exist in both chunks or in a persistent scene that is never unloaded. The unload distance must be strictly greater than the preload distance (hysteresis buffer) -- otherwise the system will thrash between loading and unloading every frame. Test with `Profiler.GetTotalAllocatedMemoryLong()` to verify chunks are actually freeing memory on unload.

---

## Anti-Patterns Summary

| Anti-Pattern | Problem | Pattern Fix |
|---|---|---|
| Bespoke trigger scripts | No reuse, no designer control | Pattern 1: Generic TriggerZone + SO events |
| Hardcoded spawn sequences | Can't tune without code changes | Pattern 2: EncounterConfig SO + EncounterController |
| Scene reload on death | All progress lost | Pattern 3: CheckpointSystem + ICheckpointable |
| Coroutine cutscene chains | Not skippable, not composable | Pattern 4: ISequenceStep + SequencePlayer |
| One-off interactive objects | Inconsistent UX, no reuse | Pattern 5: Interactable + IInteraction |
| Monolithic single scene | Memory, performance, collaboration | Pattern 6: StreamingVolume + Addressables |

---

## Related Skills

- `unity-game-architecture` -- GameEvent SO channel pattern, bootstrap scene, SO-based config
- `unity-scene-assets` -- Addressable asset loading, additive scene management
- `unity-async-patterns` -- Awaitable usage, cancellation tokens, async lifecycle
- `unity-input-correctness` -- Input System integration for interaction prompts
- `unity-save-system` -- Persistent save data (checkpoint snapshots are transient; save system is permanent)
- `unity-physics` -- Trigger collider setup, layer-based filtering, Rigidbody requirements

---

## Additional Resources

- Unity Manual: [Scene Loading](https://docs.unity3d.com/6000.0/Documentation/Manual/scene-loading.html)
- Unity Manual: [Addressables](https://docs.unity3d.com/Packages/com.unity.addressables@2.3/manual/index.html)
- Unity Manual: [SerializeReference](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/SerializeReference.html)
- Unity Manual: [ScriptableObject](https://docs.unity3d.com/6000.0/Documentation/Manual/class-ScriptableObject.html)
