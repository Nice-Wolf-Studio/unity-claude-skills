# Coroutines and Async/Await Reference

> Sources: [Unity 6.3 Coroutines](https://docs.unity3d.com/6000.3/Documentation/Manual/Coroutines.html) and [Async/Await Support](https://docs.unity3d.com/6000.3/Documentation/Manual/async-await-support.html)

## Coroutines

### How Coroutines Work

Coroutines are methods with an `IEnumerator` return type and a `yield return` statement. They suspend execution and resume later based on the yield instruction. Variables and parameters maintain their values between yields.

Synchronous operations within a coroutine still execute on the main thread -- coroutines do NOT provide multi-threading.

### Basic Pattern

```csharp
IEnumerator Fade()
{
    Color c = renderer.material.color;
    for (float alpha = 1f; alpha >= 0; alpha -= 0.1f)
    {
        c.a = alpha;
        renderer.material.color = c;
        yield return new WaitForSeconds(0.1f);
    }
}

void Update()
{
    if (Input.GetKeyDown("f"))
    {
        StartCoroutine(Fade());
    }
}
```

### Yield Instructions

| Instruction | Resumes When | Execution Order Position |
|-------------|-------------|--------------------------|
| `yield return null` | Next frame after Update | After Update |
| `yield return new WaitForSeconds(t)` | After t seconds (scaled) | After Update |
| `yield return new WaitForSecondsRealtime(t)` | After t unscaled seconds | After Update |
| `yield return new WaitForFixedUpdate()` | After next FixedUpdate | After FixedUpdate + physics |
| `yield return new WaitForEndOfFrame()` | After rendering completes | After all rendering |
| `yield return new WaitUntil(() => cond)` | When condition becomes true | After Update |
| `yield return new WaitWhile(() => cond)` | When condition becomes false | After Update |
| `yield return StartCoroutine(other)` | When nested coroutine finishes | Depends on nested yields |
| `yield return asyncOperation` | When AsyncOperation completes | After Update |

### Starting and Stopping

```csharp
// Start by method call (preferred -- allows parameters)
Coroutine handle = StartCoroutine(MyCoroutine(param));

// Start by string name (avoid -- no compile-time safety)
StartCoroutine("MyCoroutine");

// Stop specific coroutine
StopCoroutine(handle);

// Stop by string name (only works if started by string)
StopCoroutine("MyCoroutine");

// Stop all coroutines on this MonoBehaviour
StopAllCoroutines();
```

### Coroutine Lifecycle Rules

- Coroutines stop when the **GameObject is deactivated** (`SetActive(false)`)
- Coroutines stop when the **MonoBehaviour is destroyed**
- Setting `enabled = false` on the MonoBehaviour does **NOT** stop coroutines
- Coroutines cannot return values (use callbacks, events, or shared state)

### Common Coroutine Patterns

#### Timed Sequence

```csharp
IEnumerator SpawnWaves()
{
    for (int wave = 0; wave < 5; wave++)
    {
        SpawnEnemies(wave);
        yield return new WaitForSeconds(10f);
    }
    Debug.Log("All waves complete");
}
```

#### Polling Condition

```csharp
IEnumerator WaitForPlayerReady()
{
    yield return new WaitUntil(() => player.IsReady);
    StartGame();
}
```

#### Chained Coroutines

```csharp
IEnumerator GameSequence()
{
    yield return StartCoroutine(FadeIn());
    yield return StartCoroutine(PlayIntro());
    yield return StartCoroutine(FadeOut());
    LoadNextLevel();
}
```

#### Frame-by-Frame Processing

```csharp
IEnumerator ProcessLargeList(List<Item> items)
{
    int batchSize = 10;
    for (int i = 0; i < items.Count; i++)
    {
        ProcessItem(items[i]);
        if (i % batchSize == 0)
            yield return null; // Spread across frames
    }
}
```

---

## Awaitable (Unity 6 Async/Await)

### Overview

`Awaitable` is Unity's custom async type supporting C# `async`/`await`. It works with coroutines, threading operations, `AsyncOperation` types, Unity Events, and GPU readback functions. Awaitable coroutines are usually more efficient than iterator-based coroutines.

### Basic Pattern

```csharp
async Awaitable<List<Achievement>> GetAchievementsAsync()
{
    var apiResult = await SomeMethodReturningATask();
    List<Achievement> achievements = JsonConvert.DeserializeObject<List<Achievement>>(apiResult);
    return achievements;
}

async Awaitable ShowAchievementsView()
{
    ShowLoadingOverlay();
    List<Achievement> achievements = await GetAchievementsAsync();
    HideLoadingOverlay();
    ShowAchievementsList(achievements);
}
```

### Awaitable Static Methods

| Method | Purpose | Equivalent Yield |
|--------|---------|-----------------|
| `Awaitable.NextFrameAsync()` | Resume next frame | `yield return null` |
| `Awaitable.FixedUpdateAsync()` | Resume at next FixedUpdate | `yield return new WaitForFixedUpdate()` |
| `Awaitable.EndOfFrameAsync()` | Resume at end of frame | `yield return new WaitForEndOfFrame()` |
| `Awaitable.WaitForSecondsAsync(float)` | Resume after delay | `yield return new WaitForSeconds(t)` |
| `Awaitable.MainThreadAsync()` | Force continuation on main thread | N/A |
| `Awaitable.BackgroundThreadAsync()` | Force continuation on background thread | N/A |

### Critical Constraint: Single Await

Awaitable instances are pooled to limit allocations. **It is never safe to `await` more than once on an `Awaitable` instance.** Multiple awaits cause undefined behavior including exceptions or deadlocks.

```csharp
// WRONG -- undefined behavior
var awaitable = Awaitable.NextFrameAsync();
await awaitable;
await awaitable; // DANGER: second await on same instance

// CORRECT -- wrap with AsTask() if you need multiple awaits
var task = SomeAwaitableReturningFunction().AsTask();
var result1 = await task;
var result2 = await task; // Safe -- Task supports multiple awaits
```

### Thread Switching

```csharp
async Awaitable ProcessDataAsync(CancellationToken token)
{
    // Start on main thread
    var inputData = GatherInputFromScene();

    await Awaitable.BackgroundThreadAsync();
    // Now on background thread -- no Unity API access
    var processed = HeavyComputation(inputData);

    await Awaitable.MainThreadAsync();
    // Back on main thread -- safe to use Unity API
    ApplyResults(processed);
}
```

**Continuation behavior:**
- Called from main thread -> resumes on main thread
- Called from background thread -> resumes on ThreadPool thread
- `MainThreadAsync()` from a background thread waits until next frame update
- `MainThreadAsync()` from the main thread resumes immediately (most efficient)

### Cancellation with destroyCancellationToken

```csharp
public class AsyncExample : MonoBehaviour
{
    async void Start()
    {
        try
        {
            await DoWorkAsync(destroyCancellationToken);
        }
        catch (OperationCanceledException)
        {
            // MonoBehaviour was destroyed -- clean exit
        }
    }

    async Awaitable DoWorkAsync(CancellationToken token)
    {
        while (true)
        {
            token.ThrowIfCancellationRequested();
            await Awaitable.NextFrameAsync();
            // Per-frame work
        }
    }
}
```

### Conditional Wait (Awaitable WaitUntil equivalent)

```csharp
public static async Awaitable AwaitableUntil(Func<bool> condition, CancellationToken cancellationToken)
{
    while (!condition())
    {
        cancellationToken.ThrowIfCancellationRequested();
        await Awaitable.NextFrameAsync();
    }
}

// Usage
cancellationTokenSource = new CancellationTokenSource();
await AwaitableUntil(() => player.IsReady, cancellationTokenSource.Token);
```

### Loading Resources

```csharp
public async Awaitable LoadResourcesAsync()
{
    var operation = Resources.LoadAsync("my-texture");
    await operation;
    var texture = operation.asset as Texture2D;
}
```

### Composing Async Operations

```csharp
public async Awaitable Bar()
{
    await CallSomeThirdPartyAPIReturningDotnetTask();
    await Awaitable.NextFrameAsync();
    await SceneManager.LoadSceneAsync("my-scene");
    await SomeUserCodeReturningAwaitable();
}
```

### Job System Scheduling

```csharp
async Awaitable SampleSchedulingJobsForNextFrame()
{
    await Awaitable.EndOfFrameAsync();
    var jobHandle = ScheduleSomethingWithJobSystem();
    await Awaitable.NextFrameAsync();
    jobHandle.Complete();
}
```

### Wrapping Awaitable as .NET Task

```csharp
public static class AwaitableExtensions
{
    public static async Task AsTask(this Awaitable a)
    {
        await a;
    }

    public static async Task<T> AsTask<T>(this Awaitable<T> a)
    {
        return await a;
    }
}
```

### Async Tests

```csharp
[UnityTest]
public IEnumerator SomeAsyncTest()
{
    async Awaitable TestImplementation()
    {
        // test something with async/await support here
    };
    return TestImplementation();
}
```

---

## Comparison: Coroutines vs Awaitable

| Feature | Coroutine (IEnumerator) | Awaitable (Unity 6) |
|---------|------------------------|---------------------|
| **Return values** | No | Yes (`Awaitable<T>`) |
| **Error handling** | No try/catch across yields | Full try/catch/finally |
| **Thread switching** | No (main thread only) | Yes (MainThreadAsync, BackgroundThreadAsync) |
| **Cancellation** | Manual StopCoroutine | CancellationToken |
| **Memory** | Per-yield allocation overhead | Pooled, minimal allocations |
| **Multiple awaits** | N/A | NOT safe (single await only) |
| **Nesting** | `yield return StartCoroutine()` | `await OtherAsync()` |
| **Stopping** | StopCoroutine / StopAllCoroutines | CancellationToken |
| **Lifecycle** | Tied to GameObject active state | Tied to CancellationToken |
| **Composition** | Awkward chaining | Natural async composition |
| **Debugging** | Hard to trace | Standard async stack traces |

## When to Use Which

**Use Coroutines when:**
- Working with legacy Unity code
- Simple frame-by-frame sequences
- You need to stop all coroutines easily

**Use Awaitable when:**
- You need return values from async operations
- You need error handling across async boundaries
- You need background thread computation
- You want cancellation via tokens
- Composing multiple async operations
- New Unity 6 projects

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Starting coroutines without storing handle | Cannot stop them later | Store the `Coroutine` reference |
| Nested `StartCoroutine` without `yield return` | Nested coroutine runs independently | `yield return StartCoroutine(Nested())` |
| Using `async void` without try/catch | Unhandled exceptions crash silently | Wrap in try/catch or use `async Awaitable` |
| Awaiting same Awaitable twice | Undefined behavior | Await once, or use `.AsTask()` |
| Heavy computation in coroutine | Blocks main thread | Use Awaitable with BackgroundThreadAsync |
| Ignoring cancellation in async loops | Runs after object destroyed | Check `destroyCancellationToken` |
