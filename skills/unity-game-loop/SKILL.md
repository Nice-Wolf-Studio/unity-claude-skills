---
name: unity-game-loop
description: >
  Unity game loop and progression design-to-code translation. Core loop scaffolding,
  session lifecycle, win/lose condition architecture, meta loop hooks, tunable difficulty,
  pacing & encounter timing. DESIGN INTENT format: INTENT/WRONG/RIGHT/SCAFFOLD/DESIGN HOOK.
  Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.asset"
---

# Game Loop & Progression -- Design Translation Patterns

> **Prerequisite skills:** `unity-state-machines` (session FSM), `unity-game-architecture` (events, Service Locator, bootstrap), `unity-data-driven` (SO configs for difficulty/pacing)

Claude's most common gameplay failure mode is building features in isolation without a unifying loop structure. It will create movement, inventory, combat, and crafting systems that all work independently but never form a cohesive game. The result is a playable sandbox with no progression, no session boundaries, no win/lose conditions, and no hooks for designers to tune pacing or difficulty. These patterns translate design intent ("the player explores, collects, crafts, then survives the night") into code architecture that enforces phase ordering, tracks session state, and exposes tuning surfaces to designers.

---

## PATTERN: Core Loop Scaffolding

DESIGN INTENT: Designer describes the game as "explore, collect, craft, survive night" -- needs a code skeleton that enforces this cycle with extensible phases that run in order.

WRONG (Claude default):
```csharp
// Systems built independently with no phase concept -- everything runs simultaneously.
// ExplorationManager, InventoryManager, CraftingManager, CombatManager all live in the scene
// and run their Update loops at the same time. There is no concept of "it is now the crafting
// phase" or "exploration has ended." The game is a flat sandbox.
public class GameManager : MonoBehaviour
{
    [SerializeField] private ExplorationManager _exploration;
    [SerializeField] private InventoryManager _inventory;
    [SerializeField] private CombatManager _combat;

    private void Start()
    {
        _exploration.Enable();
        _inventory.Enable();
        _combat.Enable(); // all systems active from frame 1
    }
}
```

RIGHT:
```csharp
// GameLoopController manages phase transitions via IGamePhase interface.
// Each phase gets Enter/Tick/Exit. Phases are configured as SO assets.
// Only one phase is active at a time, enforcing the designer's intended cycle.
public interface IGamePhase
{
    /// <summary>Name shown in debug UI and logs.</summary>
    string PhaseName { get; }

    /// <summary>Called when this phase becomes active. Load assets, enable systems.</summary>
    Awaitable EnterAsync(CancellationToken ct);

    /// <summary>Called every frame while this phase is active.</summary>
    void Tick(float deltaTime);

    /// <summary>Called when transitioning away. Cleanup, disable systems.</summary>
    Awaitable ExitAsync(CancellationToken ct);
}

[CreateAssetMenu(menuName = "Game Loop/Phase Config")]
public class GamePhaseConfig : ScriptableObject
{
    [Tooltip("Display name for this phase")]
    public string phaseName;

    [Tooltip("Assembly-qualified type name of the IGamePhase implementation")]
    public string phaseTypeName;

    [Tooltip("Duration in seconds, 0 = phase decides when to end")]
    public float maxDuration;
}
```

SCAFFOLD (full implementation):
```csharp
using System;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

/// <summary>
/// Drives the core game loop through a sequence of phases.
/// Phases are defined by <see cref="GamePhaseConfig"/> assets and cycle in order.
/// </summary>
public class GameLoopController : MonoBehaviour
{
    [SerializeField] private List<GamePhaseConfig> _phaseConfigs;

    private readonly List<IGamePhase> _phases = new();
    private int _currentIndex = -1;
    private IGamePhase _currentPhase;
    private bool _transitioning;

    /// <summary>Fires when a new phase begins. Arg: phase index.</summary>
    public event Action<int> OnPhaseStarted;

    /// <summary>Fires when a phase ends. Arg: phase index.</summary>
    public event Action<int> OnPhaseEnded;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { }

    private async void Start()
    {
        foreach (var config in _phaseConfigs)
        {
            var type = Type.GetType(config.phaseTypeName);
            if (type == null)
            {
                Debug.LogError($"Phase type not found: {config.phaseTypeName}");
                continue;
            }
            _phases.Add((IGamePhase)Activator.CreateInstance(type));
        }

        if (_phases.Count > 0)
            await TransitionToPhaseAsync(0);
    }

    private void Update()
    {
        if (_currentPhase != null && !_transitioning)
            _currentPhase.Tick(Time.deltaTime);
    }

    /// <summary>Advance to the next phase. Wraps to index 0 after the last phase.</summary>
    public async Awaitable AdvancePhaseAsync()
    {
        int next = (_currentIndex + 1) % _phases.Count;
        await TransitionToPhaseAsync(next);
    }

    /// <summary>Jump to a specific phase by index.</summary>
    public async Awaitable TransitionToPhaseAsync(int index)
    {
        if (_transitioning) return;
        _transitioning = true;

        var ct = destroyCancellationToken;

        if (_currentPhase != null)
        {
            await _currentPhase.ExitAsync(ct);
            OnPhaseEnded?.Invoke(_currentIndex);
        }

        _currentIndex = index;
        _currentPhase = _phases[_currentIndex];

        await _currentPhase.EnterAsync(ct);
        OnPhaseStarted?.Invoke(_currentIndex);

        _transitioning = false;
    }
}
```

DESIGN HOOK: New phases require only a new `IGamePhase` class and a `GamePhaseConfig` SO asset -- no changes to `GameLoopController`. Designers reorder or add phases by rearranging the SO list in the Inspector.

GOTCHA: Phase transitions must be async (loading assets, fading screens, enabling/disabling systems). Using instant switches causes frame-spike hitches and race conditions when systems check their enabled state mid-transition. Always use `Awaitable`, never synchronous calls.

---

## PATTERN: Session Lifecycle

DESIGN INTENT: Clear start/end boundaries for a play session -- a roguelike run, a multiplayer match, a puzzle level. Players can restart without a full scene reload.

WRONG (Claude default):
```csharp
// Gameplay starts in Awake/Start with no session concept.
// "Restarting" means reloading the entire scene, losing any cross-session state.
// Score, timer, and run-specific data are scattered across multiple MonoBehaviours.
public class GameManager : MonoBehaviour
{
    public int score;
    public float timer;

    private void Start()
    {
        score = 0;
        timer = 0;
    }

    public void Restart()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex); // nuclear option
    }
}
```

RIGHT:
```csharp
// SessionManager owns all session-scoped state. Explicit StartSession/EndSession
// with events. Systems subscribe to session events to init/cleanup. Restart
// without scene reload by ending then starting a new session.
using System;
using System.Threading;
using UnityEngine;

/// <summary>
/// Manages the lifecycle of a single play session (run, match, level attempt).
/// Separates session state from persistent meta progression.
/// </summary>
public class SessionManager : MonoBehaviour
{
    public static SessionManager Instance { get; private set; }

    [SerializeField] private SessionConfig _defaultConfig;

    /// <summary>Current session data. Null when no session is active.</summary>
    public SessionData CurrentSession { get; private set; }

    /// <summary>True while a session is in progress.</summary>
    public bool IsSessionActive => CurrentSession != null;

    public event Action<SessionConfig> OnSessionStarted;
    public event Action<SessionResult> OnSessionEnded;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() => Instance = null;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    /// <summary>Begin a new session with the given configuration.</summary>
    public void StartSession(SessionConfig config = null)
    {
        config ??= _defaultConfig;
        CurrentSession = new SessionData(config);
        OnSessionStarted?.Invoke(config);
    }

    /// <summary>End the current session and publish the result.</summary>
    public SessionResult EndSession(bool victory)
    {
        if (CurrentSession == null) return default;

        var result = new SessionResult
        {
            Config = CurrentSession.Config,
            Victory = victory,
            Score = CurrentSession.Score,
            ElapsedTime = CurrentSession.ElapsedTime,
            EndTime = DateTime.UtcNow
        };

        OnSessionEnded?.Invoke(result);
        CurrentSession = null;
        return result;
    }

    /// <summary>Restart the session without reloading the scene.</summary>
    public void RestartSession()
    {
        var config = CurrentSession?.Config ?? _defaultConfig;
        EndSession(false);
        StartSession(config);
    }
}
```

SCAFFOLD (full implementation): See `references/game-loop-scaffolds.md` for `SessionConfig`, `SessionData`, `SessionResult`, and complete integration example.

DESIGN HOOK: `SessionConfig` SO defines starting conditions (initial lives, time limit, starting inventory). Gameplay systems subscribe to `OnSessionStarted` / `OnSessionEnded` to initialize and tear down their per-session state without coupling to the manager.

GOTCHA: Session state (score, timer, run inventory) must be strictly separated from persistent state (meta progression, unlocks, currency). Mixing them causes "restart doesn't reset" bugs where meta values get wiped or session values survive between runs.

---

## PATTERN: Win/Lose Condition Architecture

DESIGN INTENT: Designers iterate rapidly on what constitutes winning or losing per level -- "kill all enemies", "survive 3 minutes", "reach the exit" -- without programmer intervention for each change.

WRONG (Claude default):
```csharp
// Hardcoded compound condition buried in a manager.
// Adding a new condition means editing this class. Cannot vary per level.
public class LevelManager : MonoBehaviour
{
    private void Update()
    {
        if (enemies.Count == 0 && objectiveCaptured && timer > 30f)
        {
            WinGame(); // hardcoded, untestable, not reusable
        }
        if (playerHealth <= 0)
        {
            LoseGame();
        }
    }
}
```

RIGHT:
```csharp
// IWinCondition/ILoseCondition interfaces evaluated by a ConditionEvaluator.
// Conditions are SO assets dragged onto the level's evaluator in the Inspector.
// Composable AND/OR groups. Event-driven evaluation, not per-frame polling.
using UnityEngine;

/// <summary>
/// A single win condition that can be evaluated at any time.
/// Implement as a ScriptableObject for Inspector assignment.
/// </summary>
public abstract class WinConditionBase : ScriptableObject
{
    /// <summary>Human-readable description for the Inspector.</summary>
    public abstract string Description { get; }

    /// <summary>Initialize this condition for a new session/level.</summary>
    public abstract void Initialize();

    /// <summary>Returns true when the condition is satisfied.</summary>
    public abstract bool IsMet();

    /// <summary>Cleanup when the session/level ends.</summary>
    public abstract void Teardown();
}

/// <summary>
/// A single lose condition.
/// </summary>
public abstract class LoseConditionBase : ScriptableObject
{
    /// <summary>Human-readable description for the Inspector.</summary>
    public abstract string Description { get; }

    public abstract void Initialize();
    public abstract bool IsMet();
    public abstract void Teardown();
}
```

SCAFFOLD (full implementation):
```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Evaluates a set of win and lose conditions for the current level.
/// Supports AND (all must be true) and OR (any must be true) composition.
/// </summary>
public class ConditionEvaluator : MonoBehaviour
{
    public enum CompositionMode { AllRequired, AnyRequired }

    [SerializeField] private CompositionMode _winMode = CompositionMode.AllRequired;
    [SerializeField] private List<WinConditionBase> _winConditions;
    [SerializeField] private CompositionMode _loseMode = CompositionMode.AnyRequired;
    [SerializeField] private List<LoseConditionBase> _loseConditions;

    private bool _resolved;

    /// <summary>Fires when win conditions are satisfied.</summary>
    public event Action OnWin;

    /// <summary>Fires when lose conditions are satisfied.</summary>
    public event Action OnLose;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { }

    private void OnEnable()
    {
        _resolved = false;
        foreach (var c in _winConditions) c.Initialize();
        foreach (var c in _loseConditions) c.Initialize();
    }

    private void OnDisable()
    {
        foreach (var c in _winConditions) c.Teardown();
        foreach (var c in _loseConditions) c.Teardown();
    }

    /// <summary>
    /// Call this from gameplay events (enemy killed, timer tick, objective captured)
    /// instead of polling every frame.
    /// </summary>
    public void Evaluate()
    {
        if (_resolved) return;

        if (CheckLose())
        {
            _resolved = true;
            OnLose?.Invoke();
            return;
        }

        if (CheckWin())
        {
            _resolved = true;
            OnWin?.Invoke();
        }
    }

    private bool CheckWin()
    {
        if (_winConditions.Count == 0) return false;
        return _winMode == CompositionMode.AllRequired
            ? _winConditions.TrueForAll(c => c.IsMet())
            : _winConditions.Exists(c => c.IsMet());
    }

    private bool CheckLose()
    {
        if (_loseConditions.Count == 0) return false;
        return _loseMode == CompositionMode.AnyRequired
            ? _loseConditions.Exists(c => c.IsMet())
            : _loseConditions.TrueForAll(c => c.IsMet());
    }
}
```

DESIGN HOOK: Designers drag condition SOs onto the level's `ConditionEvaluator` in the Inspector. Programmers add new condition types by subclassing `WinConditionBase` or `LoseConditionBase`. No evaluator code changes needed.

GOTCHA: Conditions must handle late-join scenarios (multiplayer) and mid-level rule changes. Evaluate on gameplay events (enemy killed, objective captured), not at a single check time. Subscribe gameplay events to call `ConditionEvaluator.Evaluate()`.

---

## PATTERN: Meta Loop Hooks

DESIGN INTENT: Between sessions, persistent progression accumulates -- currency, unlocks, upgrades, account XP. This meta layer gives meaning to individual runs and drives long-term retention.

WRONG (Claude default):
```csharp
// Meta progression mixed directly into session code.
// XP increments happen inside the combat script. Unlock checks are in the UI.
// Restarting a session wipes currency. Nothing persists.
public class EnemyHealth : MonoBehaviour
{
    public static int totalXP; // static, no reset safety, no persistence

    public void TakeDamage(int dmg)
    {
        hp -= dmg;
        if (hp <= 0)
        {
            totalXP += 50; // meta progression buried in combat code
            Destroy(gameObject);
        }
    }
}
```

RIGHT:
```csharp
// MetaProgressionService is a plain C# class registered via Service Locator.
// It persists between sessions. It listens for SessionResult events and
// dispatches IMetaReward SO assets. Save/load is delegated to unity-save-system.
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// A reward granted after a session ends. Implement as ScriptableObject.
/// </summary>
public abstract class MetaRewardBase : ScriptableObject
{
    /// <summary>Human-readable description.</summary>
    public abstract string Description { get; }

    /// <summary>Apply this reward to the meta progression state.</summary>
    public abstract void Apply(MetaProgressionState state);
}

/// <summary>
/// Persistent player progression state that survives between sessions.
/// </summary>
[Serializable]
public class MetaProgressionState
{
    public int Currency;
    public int AccountXP;
    public int AccountLevel;
    public List<string> UnlockedItemIds = new();
}

/// <summary>
/// Service that manages meta progression. Registered via Service Locator,
/// not a MonoBehaviour -- survives scene transitions naturally.
/// </summary>
public class MetaProgressionService
{
    private MetaProgressionState _state;

    /// <summary>Fires after rewards are applied.</summary>
    public event Action<MetaProgressionState> OnProgressionUpdated;

    public MetaProgressionState State => _state;

    public MetaProgressionService(MetaProgressionState loadedState = null)
    {
        _state = loadedState ?? new MetaProgressionState();
    }

    /// <summary>Process end-of-session rewards.</summary>
    public void ProcessSessionResult(SessionResult result, List<MetaRewardBase> rewards)
    {
        foreach (var reward in rewards)
        {
            reward.Apply(_state);
        }
        OnProgressionUpdated?.Invoke(_state);
    }

    /// <summary>Check whether an item is unlocked.</summary>
    public bool IsUnlocked(string itemId) => _state.UnlockedItemIds.Contains(itemId);
}
```

SCAFFOLD (full implementation): See `references/game-loop-scaffolds.md` for `CurrencyReward`, `XPReward` examples and integration with `SessionManager`.

DESIGN HOOK: New reward types require only a new `MetaRewardBase` subclass SO. Designers configure which rewards are granted per session outcome by assigning reward SOs to level/session configs. No service code changes needed.

GOTCHA: Meta state must survive scene transitions. Use a plain C# class registered in the Service Locator (from `unity-game-architecture`), not a scene-bound MonoBehaviour. If using a MonoBehaviour, it must use `DontDestroyOnLoad` and have domain reload safety via `SubsystemRegistration`.

---

## PATTERN: Tunable Difficulty System

DESIGN INTENT: Designers need to tune enemy count, spawn rate, damage multiplier, and resource scarcity per level or dynamically based on player performance -- without touching code.

WRONG (Claude default):
```csharp
// Magic numbers scattered across multiple scripts.
// Changing difficulty means finding and editing every script.
// No way for designers to tune without a programmer.
public class EnemySpawner : MonoBehaviour
{
    private float spawnRate = 2f;        // magic number
    private int maxEnemies = 10;         // magic number
    private float enemyHealthMult = 1f;  // magic number

    private void Update()
    {
        // hardcoded scaling that nobody can tune
        if (Time.timeSinceLevelLoad > 60f)
            spawnRate = 1f;
        if (Time.timeSinceLevelLoad > 120f)
            spawnRate = 0.5f;
    }
}
```

RIGHT:
```csharp
// DifficultyConfig SO with AnimationCurve fields for visual tuning.
// DifficultyProvider service that systems query for current values.
// Supports static (per-level SO) and dynamic (adaptive) modes.
using System;
using UnityEngine;

/// <summary>
/// Defines difficulty parameters as curves over normalized progression (0-1).
/// 0 = level start (or lowest skill), 1 = level end (or highest skill).
/// </summary>
[CreateAssetMenu(menuName = "Game Loop/Difficulty Config")]
public class DifficultyConfig : ScriptableObject
{
    [Header("Enemy Scaling")]
    [Tooltip("Max concurrent enemies over normalized time (0=start, 1=end)")]
    public AnimationCurve maxEnemiesCurve = AnimationCurve.Linear(0, 5, 1, 20);

    [Tooltip("Seconds between spawns over normalized time")]
    public AnimationCurve spawnIntervalCurve = AnimationCurve.Linear(0, 3f, 1, 0.5f);

    [Header("Damage Scaling")]
    [Tooltip("Enemy damage multiplier over normalized time")]
    public AnimationCurve enemyDamageMultCurve = AnimationCurve.Linear(0, 1f, 1, 2.5f);

    [Tooltip("Player damage multiplier over normalized time")]
    public AnimationCurve playerDamageMultCurve = AnimationCurve.Constant(0, 1, 1f);

    [Header("Resource Scaling")]
    [Tooltip("Resource drop rate multiplier over normalized time")]
    public AnimationCurve resourceDropRateCurve = AnimationCurve.Linear(0, 1.5f, 1, 0.5f);
}

/// <summary>
/// Provides current difficulty values by evaluating curves at the current progression point.
/// Register via Service Locator. Systems query this instead of using magic numbers.
/// </summary>
public class DifficultyProvider
{
    private DifficultyConfig _config;
    private float _normalizedProgress;

    public DifficultyProvider(DifficultyConfig config)
    {
        _config = config ?? throw new ArgumentNullException(nameof(config));
    }

    /// <summary>Set the current progression point (0-1).</summary>
    public void SetProgress(float normalized)
    {
        _normalizedProgress = Mathf.Clamp01(normalized);
    }

    /// <summary>Current max enemies allowed.</summary>
    public int MaxEnemies => Mathf.RoundToInt(_config.maxEnemiesCurve.Evaluate(_normalizedProgress));

    /// <summary>Current spawn interval in seconds.</summary>
    public float SpawnInterval => _config.spawnIntervalCurve.Evaluate(_normalizedProgress);

    /// <summary>Current enemy damage multiplier.</summary>
    public float EnemyDamageMult => _config.enemyDamageMultCurve.Evaluate(_normalizedProgress);

    /// <summary>Current player damage multiplier.</summary>
    public float PlayerDamageMult => _config.playerDamageMultCurve.Evaluate(_normalizedProgress);

    /// <summary>Current resource drop rate multiplier.</summary>
    public float ResourceDropRate => _config.resourceDropRateCurve.Evaluate(_normalizedProgress);

    /// <summary>Swap the active config (e.g., for a new level or difficulty setting).</summary>
    public void SetConfig(DifficultyConfig config) => _config = config;
}
```

SCAFFOLD (full implementation): See `references/game-loop-scaffolds.md` for complete integration with spawners and combat systems.

DESIGN HOOK: `AnimationCurve` fields let designers visually tune difficulty ramps in the Inspector. New difficulty parameters require only a new curve field on the SO and a corresponding property on the provider -- no consumer code changes.

GOTCHA: `AnimationCurve.Evaluate()` uses normalized time (0-1). You must clearly document what 0 and 1 represent: level start/end, player death count range, or session elapsed time ratio. Ambiguity here causes difficulty curves that feel wrong and are impossible to debug.

---

## PATTERN: Pacing & Encounter Timing

DESIGN INTENT: The game has rhythm -- tension/release cycles, escalating intensity, rest periods between encounters. Spawning enemies at fixed intervals or randomly creates flat, monotonous gameplay.

WRONG (Claude default):
```csharp
// Fixed-interval spawning with no concept of intensity or pacing.
// Every 5 seconds, an enemy appears. No tension curve, no rest periods,
// no escalation. The experience is flat from start to finish.
public class EnemySpawner : MonoBehaviour
{
    [SerializeField] private float _spawnInterval = 5f;
    private float _timer;

    private void Update()
    {
        _timer += Time.deltaTime;
        if (_timer >= _spawnInterval)
        {
            SpawnEnemy();
            _timer = 0;
        }
    }
}
```

RIGHT:
```csharp
// PacingDirector tracks a designer-authored intensity curve over session time.
// Triggers encounter events when intensity thresholds are crossed.
// Spawners and encounter systems subscribe to intensity events.
using System;
using UnityEngine;

/// <summary>
/// Defines the target intensity curve for a session.
/// X axis = normalized session time (0-1), Y axis = intensity (0-1).
/// </summary>
[CreateAssetMenu(menuName = "Game Loop/Pacing Curve Config")]
public class PacingCurveConfig : ScriptableObject
{
    [Tooltip("Target intensity over normalized session time. Y: 0=calm, 1=max intensity.")]
    public AnimationCurve intensityCurve = new(
        new Keyframe(0f, 0.1f),
        new Keyframe(0.2f, 0.5f),
        new Keyframe(0.35f, 0.2f),  // rest period
        new Keyframe(0.6f, 0.7f),
        new Keyframe(0.75f, 0.3f),  // rest period
        new Keyframe(0.9f, 0.9f),
        new Keyframe(1f, 1f)        // climax
    );

    [Tooltip("Total session duration in seconds for normalizing time")]
    public float sessionDurationSeconds = 600f;

    [Tooltip("Intensity thresholds that trigger encounter events")]
    public float[] intensityThresholds = { 0.25f, 0.5f, 0.75f, 0.9f };
}

/// <summary>
/// Reads the pacing curve and fires intensity events that encounter systems consume.
/// Uses unscaled time so pausing does not break the curve.
/// </summary>
public class PacingDirector : MonoBehaviour
{
    [SerializeField] private PacingCurveConfig _config;

    private float _sessionStartTime;
    private float _currentIntensity;
    private readonly bool[] _thresholdsFired = new bool[16];

    /// <summary>Current intensity value (0-1).</summary>
    public float CurrentIntensity => _currentIntensity;

    /// <summary>Fires every frame with the current intensity value.</summary>
    public event Action<float> OnIntensityChanged;

    /// <summary>Fires when an intensity threshold is crossed upward. Arg: threshold value.</summary>
    public event Action<float> OnThresholdCrossed;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatics() { }

    /// <summary>Begin tracking pacing for a new session.</summary>
    public void BeginSession()
    {
        _sessionStartTime = Time.realtimeSinceStartup;
        _currentIntensity = 0f;
        Array.Clear(_thresholdsFired, 0, _thresholdsFired.Length);
    }

    private void Update()
    {
        if (_config == null) return;

        float elapsed = Time.realtimeSinceStartup - _sessionStartTime;
        float normalized = Mathf.Clamp01(elapsed / _config.sessionDurationSeconds);

        _currentIntensity = _config.intensityCurve.Evaluate(normalized);
        OnIntensityChanged?.Invoke(_currentIntensity);

        for (int i = 0; i < _config.intensityThresholds.Length && i < _thresholdsFired.Length; i++)
        {
            if (!_thresholdsFired[i] && _currentIntensity >= _config.intensityThresholds[i])
            {
                _thresholdsFired[i] = true;
                OnThresholdCrossed?.Invoke(_config.intensityThresholds[i]);
            }
        }
    }
}
```

SCAFFOLD (full implementation): See `references/game-loop-scaffolds.md` for complete `PacingDirector` with cooldown resets and encounter spawner integration.

DESIGN HOOK: Designers edit the pacing curve visually in the Inspector, shaping tension/release cycles. Encounter spawners subscribe to `OnThresholdCrossed` to trigger waves, boss spawns, or environmental events at designer-defined intensity breakpoints.

GOTCHA: Pacing must use `Time.realtimeSinceStartup` or unscaled time if the game pauses. Using `Time.time` or `Time.deltaTime` causes the pacing curve to freeze during pause menus, then dump all the accumulated intensity on unpause -- breaking the designer's carefully authored rhythm.

---

## Anti-Patterns Quick Reference

| Anti-Pattern | Symptom | Fix |
|---|---|---|
| No phase concept | All systems active simultaneously, no progression structure | `GameLoopController` with `IGamePhase` |
| Scene reload for restart | Loading screen on every retry, meta state lost | `SessionManager` with explicit start/end |
| Hardcoded win conditions | Programmer needed for every level variant | `ConditionEvaluator` with SO-based conditions |
| Meta state in session code | Restart wipes currency, or currency survives when it shouldn't | `MetaProgressionService` separated from session |
| Magic number difficulty | Tuning requires code changes and recompile | `DifficultyConfig` SO with `AnimationCurve` fields |
| Fixed-interval spawning | Flat, monotonous pacing with no tension/release | `PacingDirector` with designer-authored intensity curve |

---

## Related Skills

- `unity-save-system` -- Persisting meta progression state between application launches
- `unity-npc-behavior` -- Enemy AI that responds to pacing director intensity levels
- `unity-state-machines` -- Underlying FSM pattern used by session and phase management
- `unity-game-architecture` -- Service Locator, event channels, bootstrap sequences used throughout
- `unity-data-driven` -- ScriptableObject config patterns used for phases, difficulty, and pacing

---

## Additional Resources

- [Unity Manual: Execution Order](https://docs.unity3d.com/6000.1/Documentation/Manual/execution-order.html)
- [Unity Manual: ScriptableObject](https://docs.unity3d.com/6000.1/Documentation/Manual/class-ScriptableObject.html)
- [Unity Manual: Awaitable](https://docs.unity3d.com/6000.1/Documentation/ScriptReference/Awaitable.html)
- [Unity Manual: RuntimeInitializeOnLoadMethodAttribute](https://docs.unity3d.com/6000.1/Documentation/ScriptReference/RuntimeInitializeOnLoadMethodAttribute.html)
- [Unity Manual: AnimationCurve](https://docs.unity3d.com/6000.1/Documentation/ScriptReference/AnimationCurve.html)
