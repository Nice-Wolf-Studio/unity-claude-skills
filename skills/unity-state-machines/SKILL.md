---
name: unity-state-machines
description: >
  Unity state and behavior system architecture. FSM, Hierarchical FSM, Behavior Trees,
  stack-based state machines, Animator-vs-code decisions, state machine testing.
  DECISION format: WHEN/DECISION/SCAFFOLD/GOTCHA. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
---

# State & Behavior Systems -- Decision Patterns

> **Prerequisite skills:** `unity-game-architecture` (MonoBehaviour vs plain C#, component composition), `unity-animation` (Animator FSM, StateMachineBehaviour), `unity-scripting` (MonoBehaviour lifecycle)

These patterns address the most common state management failure: Claude writes ad-hoc `if/else` chains or giant switch statements with no structure, making state logic unmaintainable beyond 3-4 states.

---

## PATTERN: State System Selection

WHEN: Implementing AI behavior, game flow, character states, or UI navigation

DECISION:
- **Animator FSM** -- States are tied to animations. Character locomotion, attack combos, death animations. Designer-friendly visual graph. See `unity-animation` for full coverage -- do not build a code FSM just to drive animations.
- **Code FSM (enum or class-based)** -- Game flow (MainMenu/Playing/Paused/GameOver), ability systems, turn phases. Fully testable, no Animator overhead. Use when states have complex logic, not just animation swaps.
- **Hierarchical FSM (HFSM)** -- States within states. Combat contains {Melee, Ranged, Blocking}. When flat FSM has too many transitions between related states.
- **Behavior Tree (BT)** -- Complex AI with prioritization, interruptible sequences, parallel behaviors. When FSM has >8-10 states and transition explosion makes the graph unreadable.
- **Stack-Based (Pushdown)** -- UI screens, pause menus, modal dialogs. States push/pop, previous state is preserved and resumed.

```
How many states? What kind of transitions?
|
+-- 2-3 states, simple toggling?
|     --> if/else or bool flags (don't over-engineer)
|
+-- 4-8 states, clear transitions?
|     --> Code FSM (enum or IState)
|
+-- States group naturally into clusters?
|     --> HFSM (Locomotion > {Idle,Walk,Run}, Combat > {Melee,Ranged})
|
+-- AI with priorities, interrupts, parallel tasks?
|     --> Behavior Tree
|
+-- Need to return to previous state (back button, unpause)?
|     --> Stack-Based State Machine
|
+-- States tied to animations?
      --> Animator FSM (use unity-animation skill)
```

GOTCHA: Animator FSM has per-frame evaluation overhead even with no animations playing. Do not use Animator for pure logic state machines (game flow, turn systems). Build a code FSM instead.

---

## PATTERN: Class-Based FSM Architecture

WHEN: Building a code FSM with more than 3 states

DECISION:
- **Enum + switch** -- Up to ~5 states with minimal transition logic. Keep it simple.
- **IState interface + dictionary** -- 5+ states, each state has non-trivial Enter/Tick/Exit logic. States are plain C# classes (testable without MonoBehaviour).

SCAFFOLD (Enum FSM -- simple):
```csharp
public enum GameState { MainMenu, Playing, Paused, GameOver }

public class GameFlowManager : MonoBehaviour
{
    private GameState _state = GameState.MainMenu;

    public void ChangeState(GameState newState)
    {
        ExitState(_state);
        _state = newState;
        EnterState(_state);
    }

    void Update()
    {
        switch (_state)
        {
            case GameState.Playing:
                // game logic
                break;
            case GameState.Paused:
                // pause logic
                break;
        }
    }

    void EnterState(GameState state) { /* ... */ }
    void ExitState(GameState state) { /* ... */ }
}
```

SCAFFOLD (IState FSM -- scalable):
```csharp
// See references/state-system-scaffolds.md for complete implementation
public interface IState
{
    void Enter();
    void Tick(float deltaTime);
    void Exit();
}

public class StateMachine
{
    private IState _currentState;

    public void ChangeState(IState newState)
    {
        _currentState?.Exit();
        _currentState = newState;
        _currentState?.Enter();
    }

    public void Tick(float deltaTime) => _currentState?.Tick(deltaTime);
}
```

GOTCHA: States should be plain C# classes, NOT MonoBehaviours. The owning MonoBehaviour passes a shared context object (transform, rigidbody, references) to states via constructor or interface. This keeps states testable and avoids the performance overhead of empty MonoBehaviours.

---

## PATTERN: Hierarchical FSM (HFSM)

WHEN: States naturally group into super-states (Locomotion contains Idle/Walk/Run/Sprint)

DECISION:
- **Nested StateMachine** -- A super-state contains its own StateMachine. Clean separation. Best when hierarchy is 2 levels deep.
- **Flatten with guard conditions** -- If hierarchy would be 3+ levels, HFSM complexity may exceed a Behavior Tree. Consider switching to BT.

SCAFFOLD:
```csharp
// A super-state that contains a child state machine
public class HierarchicalState : IState
{
    private readonly StateMachine _subMachine;
    private readonly IState _defaultSubState;

    public HierarchicalState(StateMachine subMachine, IState defaultSubState)
    {
        _subMachine = subMachine;
        _defaultSubState = defaultSubState;
    }

    public void Enter() => _subMachine.ChangeState(_defaultSubState);
    public void Tick(float deltaTime) => _subMachine.Tick(deltaTime);
    public void Exit() => _subMachine.ChangeState(null); // Exit current sub-state
}

// Usage:
// var idleState = new IdleState(context);
// var walkState = new WalkState(context);
// var locomotionSubMachine = new StateMachine();
// var locomotionState = new HierarchicalState(locomotionSubMachine, idleState);
// mainMachine.ChangeState(locomotionState);
```

GOTCHA: Super-state Exit must propagate to the active sub-state. Exit order: sub-state.Exit() -> super-state.Exit(). Transitions can exist at both levels: sub-state transitions (Idle -> Walk) stay within the super-state, while super-state transitions (Locomotion -> Combat) exit the entire hierarchy.

---

## PATTERN: Behavior Tree Architecture

WHEN: AI needs priority-based decision making with interruptible sequences

DECISION:
- **Custom minimal BT** -- < 20 nodes, want full control, no external dependency. Build `Selector`, `Sequence`, `ActionLeaf`.
- **Third-party BT library** (NodeCanvas, Behavior Designer, Fluid BT) -- Visual editing, designer-friendly, 50+ node types. Worth the dependency when non-programmers design AI.

SCAFFOLD (Minimal BT):
```csharp
// See references/state-system-scaffolds.md for complete implementation
public enum BTStatus { Success, Failure, Running }

public abstract class BTNode
{
    public abstract BTStatus Tick(Blackboard bb);
}

// Selector: tries children in order, succeeds on first success
// Sequence: runs children in order, fails on first failure
// ActionLeaf: executes a single action
```

GOTCHA: Behavior Trees tick from the root every frame. For performance, cache the "running" node and resume from there instead of re-evaluating the entire tree. Large BTs (100+ nodes) should use a Blackboard for shared data rather than closures. A Blackboard is just a `Dictionary<string, object>` with typed accessors.

---

## PATTERN: Stack-Based State Machine

WHEN: UI navigation, pause menus, modal dialogs, undo-able state transitions

DECISION:
- **Stack machine** -- When you need to return to the previous state. Gameplay -> Pause -> Gameplay. Gameplay -> Inventory -> Crafting -> Inventory -> Gameplay.
- **Flat FSM** -- When transitions are not stack-like (you never "go back to where you were").

SCAFFOLD:
```csharp
public class StateStack
{
    private readonly Stack<IState> _stack = new();

    public IState Current => _stack.Count > 0 ? _stack.Peek() : null;

    public void Push(IState state)
    {
        Current?.Pause();  // Pause current (not Exit -- it stays on the stack)
        _stack.Push(state);
        state.Enter();
    }

    public void Pop()
    {
        if (_stack.Count == 0) return;
        var popped = _stack.Pop();
        popped.Exit();
        Current?.Resume();  // Resume the state underneath
    }

    public void Tick(float deltaTime) => Current?.Tick(deltaTime);
}

// Extended state interface for stack machines
public interface IStackableState : IState
{
    void Pause();   // Called when a new state is pushed on top
    void Resume();  // Called when the state above is popped
}
```

GOTCHA: Stack grows unbounded if you forget to pop. Set a max depth (e.g., 10) and log warnings. When clearing the stack (e.g., returning to main menu), pop all states in order so each gets its Exit call. Never push the same state instance twice -- create a new instance or use a flag to prevent double-push.

---

## PATTERN: Testing State Machines

WHEN: Writing tests for FSM or BT logic

DECISION: States are plain C# classes -> test with NUnit Edit Mode tests. No MonoBehaviour, no Play Mode, no scene needed.

SCAFFOLD:
```csharp
// State that returns a transition signal
public class IdleState : IState
{
    private readonly EnemyContext _ctx;
    public bool ShouldTransitionToChase { get; private set; }

    public IdleState(EnemyContext ctx) => _ctx = ctx;

    public void Enter() => ShouldTransitionToChase = false;

    public void Tick(float deltaTime)
    {
        if (_ctx.DistanceToPlayer < _ctx.DetectionRange)
            ShouldTransitionToChase = true;
    }

    public void Exit() { }
}

// Test (Edit Mode, no Unity runtime needed)
[Test]
public void IdleState_TransitionsToChase_WhenPlayerInRange()
{
    var ctx = new EnemyContext { DistanceToPlayer = 5f, DetectionRange = 10f };
    var idle = new IdleState(ctx);

    idle.Enter();
    idle.Tick(0.016f);

    Assert.IsTrue(idle.ShouldTransitionToChase);
}

[Test]
public void IdleState_StaysIdle_WhenPlayerOutOfRange()
{
    var ctx = new EnemyContext { DistanceToPlayer = 15f, DetectionRange = 10f };
    var idle = new IdleState(ctx);

    idle.Enter();
    idle.Tick(0.016f);

    Assert.IsFalse(idle.ShouldTransitionToChase);
}
```

GOTCHA: If states depend on `Time.deltaTime`, inject `float deltaTime` as a parameter to `Tick()` instead. If states need Unity APIs (Physics.Raycast), wrap those behind an interface so tests can provide stubs. Cross-ref: `unity-testing` for Test Framework setup.

---

## Comparison Table

| Feature | Enum FSM | IState FSM | HFSM | Behavior Tree | Stack Machine |
|---------|----------|-----------|------|---------------|---------------|
| **Complexity** | Low | Medium | Medium-High | High | Medium |
| **Best for** | 2-5 simple states | 5-15 states | Grouped states | Complex AI | UI navigation |
| **Testability** | Switch testing | Per-state testing | Per-state + hierarchy | Per-node testing | Push/pop testing |
| **Designer-friendly** | No | No | No | With visual editor | No |
| **Transition management** | Manual in switch | Dictionary or signals | Per-level transitions | Priority-based | Push/Pop |
| **Memory** | Minimal | Per-state instance | Nested machines | Full tree in memory | Stack depth |
| **Performance** | O(1) switch | O(1) delegate | O(depth) per tick | O(tree) per tick | O(1) |
| **When to avoid** | >5 states | Animation-tied states | >2 hierarchy levels | <8 states | Non-stack transitions |

## Related Skills

- **unity-animation** -- Animator FSM, StateMachineBehaviour, blend trees (use when states drive animations)
- **unity-game-architecture** -- MonoBehaviour vs Plain C# (states should be plain C#), Service Locator
- **unity-ai-navigation** -- NavMeshAgent integration with FSM/BT for AI movement
- **unity-testing** -- NUnit Edit Mode tests for state logic

## Additional Resources

- [Game Programming Patterns: State](https://gameprogrammingpatterns.com/state.html)
- [Behavior Trees in Unity (official)](https://docs.unity3d.com/6000.3/Documentation/Manual/behavior-trees.html)
- [Fluid Behavior Tree](https://github.com/ashblue/fluid-behavior-tree)
