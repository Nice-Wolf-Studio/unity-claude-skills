# State System Scaffolds

Complete implementations for FSM, HFSM, Behavior Tree, and Stack machine. Copy-paste ready.

## IState + StateMachine (Complete)

```csharp
using System;
using System.Collections.Generic;

/// <summary>State interface. All states are plain C# classes.</summary>
public interface IState
{
    void Enter();
    void Tick(float deltaTime);
    void Exit();
}

/// <summary>
/// Generic state machine. Owns current state, handles transitions.
/// Driven by a MonoBehaviour calling Tick() in Update().
/// </summary>
public class StateMachine
{
    private IState _currentState;
    private readonly Dictionary<Type, IState> _states = new();

    public IState CurrentState => _currentState;
    public event Action<IState, IState> OnStateChanged; // old, new

    /// <summary>Register a state instance by its type.</summary>
    public void AddState<T>(T state) where T : class, IState
    {
        _states[typeof(T)] = state;
    }

    /// <summary>Transition to a registered state by type.</summary>
    public void ChangeState<T>() where T : class, IState
    {
        if (!_states.TryGetValue(typeof(T), out var newState))
            throw new InvalidOperationException($"State {typeof(T).Name} not registered");

        var old = _currentState;
        _currentState?.Exit();
        _currentState = newState;
        _currentState.Enter();
        OnStateChanged?.Invoke(old, _currentState);
    }

    /// <summary>Transition to a state instance directly (unregistered).</summary>
    public void ChangeState(IState newState)
    {
        var old = _currentState;
        _currentState?.Exit();
        _currentState = newState;
        _currentState?.Enter();
        OnStateChanged?.Invoke(old, _currentState);
    }

    /// <summary>Call from MonoBehaviour.Update().</summary>
    public void Tick(float deltaTime) => _currentState?.Tick(deltaTime);
}
```

### MonoBehaviour Driver

```csharp
using UnityEngine;

/// <summary>
/// MonoBehaviour that owns and drives a StateMachine.
/// States receive context through a shared object.
/// </summary>
public class EnemyAI : MonoBehaviour
{
    [SerializeField] private float detectionRange = 10f;
    [SerializeField] private float attackRange = 2f;

    private StateMachine _fsm;
    private EnemyContext _ctx;

    void Awake()
    {
        _ctx = new EnemyContext
        {
            Transform = transform,
            DetectionRange = detectionRange,
            AttackRange = attackRange
        };

        _fsm = new StateMachine();
        _fsm.AddState(new IdleState(_ctx, _fsm));
        _fsm.AddState(new ChaseState(_ctx, _fsm));
        _fsm.AddState(new AttackState(_ctx, _fsm));
    }

    void OnEnable() => _fsm.ChangeState<IdleState>();

    void Update() => _fsm.Tick(Time.deltaTime);
}

/// <summary>Shared context passed to all states.</summary>
public class EnemyContext
{
    public Transform Transform;
    public Transform PlayerTransform; // Set by a detection system
    public float DetectionRange;
    public float AttackRange;

    public float DistanceToPlayer =>
        PlayerTransform != null
            ? Vector3.Distance(Transform.position, PlayerTransform.position)
            : float.MaxValue;
}
```

### Example States

```csharp
public class IdleState : IState
{
    private readonly EnemyContext _ctx;
    private readonly StateMachine _fsm;

    public IdleState(EnemyContext ctx, StateMachine fsm) { _ctx = ctx; _fsm = fsm; }

    public void Enter() { /* play idle animation */ }

    public void Tick(float deltaTime)
    {
        if (_ctx.DistanceToPlayer < _ctx.DetectionRange)
            _fsm.ChangeState<ChaseState>();
    }

    public void Exit() { }
}

public class ChaseState : IState
{
    private readonly EnemyContext _ctx;
    private readonly StateMachine _fsm;

    public ChaseState(EnemyContext ctx, StateMachine fsm) { _ctx = ctx; _fsm = fsm; }

    public void Enter() { /* play run animation */ }

    public void Tick(float deltaTime)
    {
        if (_ctx.DistanceToPlayer > _ctx.DetectionRange * 1.5f)
        {
            _fsm.ChangeState<IdleState>();
            return;
        }

        if (_ctx.DistanceToPlayer < _ctx.AttackRange)
        {
            _fsm.ChangeState<AttackState>();
            return;
        }

        // Move toward player
        var dir = (_ctx.PlayerTransform.position - _ctx.Transform.position).normalized;
        _ctx.Transform.position += dir * 5f * deltaTime;
    }

    public void Exit() { }
}
```

---

## Minimal Behavior Tree (Complete)

```csharp
using System.Collections.Generic;

public enum BTStatus { Success, Failure, Running }

/// <summary>Base node for all BT nodes.</summary>
public abstract class BTNode
{
    public abstract BTStatus Tick(Blackboard bb);
}

/// <summary>Shared data store for the behavior tree.</summary>
public class Blackboard
{
    private readonly Dictionary<string, object> _data = new();

    public void Set<T>(string key, T value) => _data[key] = value;

    public T Get<T>(string key, T defaultValue = default)
    {
        if (_data.TryGetValue(key, out var value) && value is T typed)
            return typed;
        return defaultValue;
    }

    public bool Has(string key) => _data.ContainsKey(key);
    public void Remove(string key) => _data.Remove(key);
}

/// <summary>
/// Selector (OR): Tries children in order, succeeds on first Success.
/// Returns Running if a child is Running. Fails if ALL children fail.
/// </summary>
public class Selector : BTNode
{
    private readonly List<BTNode> _children;

    public Selector(params BTNode[] children) => _children = new List<BTNode>(children);

    public override BTStatus Tick(Blackboard bb)
    {
        foreach (var child in _children)
        {
            var status = child.Tick(bb);
            if (status != BTStatus.Failure)
                return status; // Success or Running
        }
        return BTStatus.Failure;
    }
}

/// <summary>
/// Sequence (AND): Runs children in order, fails on first Failure.
/// Returns Running if a child is Running. Succeeds if ALL children succeed.
/// </summary>
public class Sequence : BTNode
{
    private readonly List<BTNode> _children;
    private int _runningIndex; // Resume from running child

    public Sequence(params BTNode[] children) => _children = new List<BTNode>(children);

    public override BTStatus Tick(Blackboard bb)
    {
        for (int i = _runningIndex; i < _children.Count; i++)
        {
            var status = _children[i].Tick(bb);
            if (status == BTStatus.Running)
            {
                _runningIndex = i;
                return BTStatus.Running;
            }
            if (status == BTStatus.Failure)
            {
                _runningIndex = 0;
                return BTStatus.Failure;
            }
        }
        _runningIndex = 0;
        return BTStatus.Success;
    }
}

/// <summary>Action leaf: executes a function and returns its status.</summary>
public class ActionLeaf : BTNode
{
    private readonly System.Func<Blackboard, BTStatus> _action;

    public ActionLeaf(System.Func<Blackboard, BTStatus> action) => _action = action;

    public override BTStatus Tick(Blackboard bb) => _action(bb);
}

/// <summary>Condition leaf: checks a predicate, returns Success or Failure.</summary>
public class ConditionLeaf : BTNode
{
    private readonly System.Func<Blackboard, bool> _condition;

    public ConditionLeaf(System.Func<Blackboard, bool> condition) => _condition = condition;

    public override BTStatus Tick(Blackboard bb) =>
        _condition(bb) ? BTStatus.Success : BTStatus.Failure;
}

/// <summary>Inverter decorator: flips Success/Failure.</summary>
public class Inverter : BTNode
{
    private readonly BTNode _child;

    public Inverter(BTNode child) => _child = child;

    public override BTStatus Tick(Blackboard bb)
    {
        var status = _child.Tick(bb);
        return status switch
        {
            BTStatus.Success => BTStatus.Failure,
            BTStatus.Failure => BTStatus.Success,
            _ => status
        };
    }
}
```

### BT Usage Example

```csharp
public class EnemyBT : MonoBehaviour
{
    private BTNode _root;
    private Blackboard _bb;

    void Awake()
    {
        _bb = new Blackboard();
        _bb.Set("self", transform);
        _bb.Set("detectionRange", 10f);
        _bb.Set("attackRange", 2f);

        _root = new Selector(
            // Priority 1: Attack if in range
            new Sequence(
                new ConditionLeaf(bb => bb.Get<float>("distToPlayer") < bb.Get<float>("attackRange")),
                new ActionLeaf(bb => { /* attack logic */ return BTStatus.Success; })
            ),
            // Priority 2: Chase if detected
            new Sequence(
                new ConditionLeaf(bb => bb.Get<float>("distToPlayer") < bb.Get<float>("detectionRange")),
                new ActionLeaf(bb => { /* move toward player */ return BTStatus.Running; })
            ),
            // Priority 3: Idle
            new ActionLeaf(bb => { /* idle logic */ return BTStatus.Running; })
        );
    }

    void Update()
    {
        // Update blackboard with current world state
        _bb.Set("distToPlayer", Vector3.Distance(transform.position, playerPos));

        // Tick the tree
        _root.Tick(_bb);
    }
}
```

---

## Stack-Based State Machine (Complete)

```csharp
using System;
using System.Collections.Generic;

public interface IStackableState
{
    void Enter();
    void Tick(float deltaTime);
    void Exit();
    void Pause();   // Called when a new state is pushed on top
    void Resume();  // Called when the state above is popped
}

public class StateStack
{
    private readonly Stack<IStackableState> _stack = new();
    private const int MaxDepth = 10;

    public IStackableState Current => _stack.Count > 0 ? _stack.Peek() : null;
    public int Depth => _stack.Count;

    public event Action<IStackableState> OnPushed;
    public event Action<IStackableState> OnPopped;

    public void Push(IStackableState state)
    {
        if (_stack.Count >= MaxDepth)
        {
            UnityEngine.Debug.LogWarning($"StateStack at max depth ({MaxDepth}). Push ignored.");
            return;
        }

        Current?.Pause();
        _stack.Push(state);
        state.Enter();
        OnPushed?.Invoke(state);
    }

    public void Pop()
    {
        if (_stack.Count == 0) return;
        var popped = _stack.Pop();
        popped.Exit();
        OnPopped?.Invoke(popped);
        Current?.Resume();
    }

    /// <summary>Pop all states, calling Exit on each.</summary>
    public void Clear()
    {
        while (_stack.Count > 0)
        {
            var state = _stack.Pop();
            state.Exit();
            OnPopped?.Invoke(state);
        }
    }

    public void Tick(float deltaTime) => Current?.Tick(deltaTime);
}
```

### Stack Machine Usage (UI Navigation)

```csharp
public class UIManager : MonoBehaviour
{
    private StateStack _uiStack;

    void Awake()
    {
        _uiStack = new StateStack();
    }

    void Start()
    {
        _uiStack.Push(new MainMenuState(this));
    }

    void Update()
    {
        _uiStack.Tick(Time.unscaledDeltaTime); // unscaled for pause menus

        // Global back button
        if (Input.GetKeyDown(KeyCode.Escape) && _uiStack.Depth > 1)
            _uiStack.Pop();
    }

    public void OpenSettings() => _uiStack.Push(new SettingsState(this));
    public void OpenInventory() => _uiStack.Push(new InventoryState(this));
    public void ReturnToPrevious() => _uiStack.Pop();

    // State implementations show/hide UI panels
    // Enter: show panel, Resume: show panel
    // Exit: hide panel, Pause: hide panel
}
```
