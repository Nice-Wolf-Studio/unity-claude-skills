---
name: unity-async-patterns
description: >
  Unity async and coroutine correctness patterns. Catches common mistakes with Awaitable
  double-await, missing cancellation tokens, thread context after BackgroundThreadAsync,
  coroutine error swallowing, batch mode WaitForEndOfFrame, and Addressables handle leaks.
  PATTERN format: WHEN/WRONG/RIGHT/GOTCHA. Based on Unity 6.3 LTS documentation.
globs:
  - "**/*.cs"
---

# Async & Coroutine Patterns -- Correctness Patterns

> **Prerequisite skills:** `unity-scripting` (coroutines, Awaitable API, yield types), `unity-lifecycle` (destruction timing, destroyCancellationToken)

These patterns target async bugs that are especially dangerous because they often work during testing and fail in production: exceptions silently swallowed, objects destroyed mid-await, and thread context violations.

---

## PATTERN: Awaitable Double-Await

WHEN: Storing an `Awaitable` instance and awaiting it more than once

WRONG (Claude default):
```csharp
Awaitable task = Awaitable.WaitForSecondsAsync(2f);
await task; // First await -- works
await task; // Second await -- UNDEFINED BEHAVIOR (may complete instantly or throw)
```

RIGHT:
```csharp
// Awaitable is POOLED -- after the first await completes, the instance is recycled
// Each Awaitable should be awaited exactly once

// If you need to await the same operation from multiple places, use .AsTask():
var task = Awaitable.WaitForSecondsAsync(2f).AsTask();
await task; // Works
await task; // Works -- Task is not pooled

// Or simply create separate Awaitables:
await Awaitable.WaitForSecondsAsync(2f);
await Awaitable.WaitForSecondsAsync(2f); // Fresh instance
```

GOTCHA: Unity pools `Awaitable` instances to avoid allocation. After completion, the instance is returned to the pool and may be reused by a completely different operation. A second `await` on the same instance may see a different operation's state, complete instantly, or throw. This is unlike `Task` which can be safely awaited multiple times. Use `.AsTask()` when you need multi-await semantics, but be aware this allocates.

---

## PATTERN: Missing destroyCancellationToken

WHEN: Writing async methods in MonoBehaviours

WRONG (Claude default):
```csharp
async Awaitable Start()
{
    await Awaitable.WaitForSecondsAsync(5f);
    // If object was destroyed during the wait:
    // - MissingReferenceException on next Unity API call
    // - Or worse: silently operates on a "fake-null" object
    transform.position = Vector3.zero;
}
```

RIGHT:
```csharp
async Awaitable Start()
{
    try
    {
        await Awaitable.WaitForSecondsAsync(5f, destroyCancellationToken);
        transform.position = Vector3.zero;
    }
    catch (OperationCanceledException)
    {
        // Object was destroyed -- this is expected, not an error
    }
}

// For methods that chain multiple awaits:
async Awaitable DoMultiStepWork()
{
    var token = destroyCancellationToken;

    await Awaitable.NextFrameAsync(token);
    ProcessStep1();

    await Awaitable.WaitForSecondsAsync(1f, token);
    ProcessStep2(); // Safe: would have thrown before reaching here if destroyed

    await LoadAssetAsync(token);
    ProcessStep3();
}
```

GOTCHA: `destroyCancellationToken` is a property on `MonoBehaviour` that triggers when `OnDestroy` begins. Every `Awaitable` wait method accepts an optional `CancellationToken`. Without it, the await completes normally even after the object is destroyed, leading to `MissingReferenceException`. Always pass the token AND catch `OperationCanceledException`.

---

## PATTERN: Thread Context After BackgroundThreadAsync

WHEN: Returning to Unity APIs after doing work on a background thread

WRONG (Claude default):
```csharp
async Awaitable ProcessData()
{
    await Awaitable.BackgroundThreadAsync();
    var result = HeavyComputation(); // OK: runs on background thread

    // CRASH: Accessing Unity API from background thread
    transform.position = new Vector3(result, 0, 0);
}
```

RIGHT:
```csharp
async Awaitable ProcessData()
{
    await Awaitable.BackgroundThreadAsync();
    var result = HeavyComputation(); // Runs on background thread

    await Awaitable.MainThreadAsync(); // Switch BACK to main thread
    transform.position = new Vector3(result, 0, 0); // Now safe

    // Can switch back and forth:
    await Awaitable.BackgroundThreadAsync();
    var moreData = AnotherHeavyTask();

    await Awaitable.MainThreadAsync();
    ApplyResults(moreData);
}
```

GOTCHA: After `BackgroundThreadAsync()`, ALL subsequent code runs on a thread pool thread until you explicitly switch back with `MainThreadAsync()`. Unity APIs (Transform, GameObject, Physics, etc.) are **not thread-safe** and will throw or corrupt state if called from a background thread. `MainThreadAsync()` resumes on the next frame's player loop update, not immediately.

---

## PATTERN: Coroutine Error Swallowing

WHEN: Exceptions occur inside coroutines

WRONG (Claude default):
```csharp
IEnumerator LoadAndProcess()
{
    yield return LoadData(); // If this throws, coroutine silently stops
    ProcessData();           // Never reached, no error in console (or just a log, no stack)
}

// try/catch doesn't work with yield:
IEnumerator BadErrorHandling()
{
    try
    {
        yield return SomethingDangerous(); // COMPILER ERROR: cannot yield in try block with catch
    }
    catch (Exception e)
    {
        Debug.LogError(e);
    }
}
```

RIGHT:
```csharp
// Option 1: Use Awaitable instead (proper exception propagation)
async Awaitable LoadAndProcess()
{
    try
    {
        await LoadDataAsync();
        ProcessData();
    }
    catch (Exception e)
    {
        Debug.LogError($"Load failed: {e}");
    }
}

// Option 2: Error handling without yield in the try block
IEnumerator LoadAndProcessCoroutine()
{
    bool success = false;
    Exception error = null;

    // Wrap the yield outside try/catch
    yield return LoadDataCoroutine(result =>
    {
        success = true;
    });

    // Handle errors after the yield
    if (!success)
    {
        Debug.LogError("Load failed");
        yield break;
    }

    ProcessData();
}
```

GOTCHA: In coroutines, `yield return` cannot appear inside a `try` block that has a `catch` clause (C# language restriction). Exceptions in yielded coroutines are logged to the console but execution silently stops -- no propagation to the caller. The caller's coroutine continues as if the nested one completed. Use `Awaitable` for any operation that can fail and needs error handling.

---

## PATTERN: WaitForEndOfFrame in Batch Mode

WHEN: Using `WaitForEndOfFrame` or `Awaitable.EndOfFrameAsync` in headless/server/test environments

WRONG (Claude default):
```csharp
IEnumerator CaptureScreenshot()
{
    yield return new WaitForEndOfFrame(); // HANGS in batch mode (no rendering)
    var tex = ScreenCapture.CaptureScreenshotAsTexture();
}

// Same issue with Awaitable:
async Awaitable WaitForRender()
{
    await Awaitable.EndOfFrameAsync(); // HANGS in batch mode
}
```

RIGHT:
```csharp
IEnumerator CaptureScreenshot()
{
    // Check if we're in batch mode
    if (Application.isBatchMode)
    {
        yield return null; // Just wait one frame instead
        Debug.LogWarning("Screenshot not available in batch mode");
        yield break;
    }

    yield return new WaitForEndOfFrame();
    var tex = ScreenCapture.CaptureScreenshotAsTexture();
}

// For tests that need frame advancement without rendering:
IEnumerator TestCoroutine()
{
    yield return null; // Advances one frame (works in all modes)
    // yield return new WaitForFixedUpdate(); // Also works in batch mode
}
```

GOTCHA: `WaitForEndOfFrame` and `EndOfFrameAsync` wait for the rendering phase. In batch mode (`-batchmode` flag), headless servers, and some test runners, there is no rendering -- so these yields never complete and the coroutine/async hangs forever. Use `yield return null` (next Update) or `Awaitable.NextFrameAsync()` for frame advancement that works everywhere.

---

## PATTERN: Nested Coroutine Cancellation

WHEN: Stopping a parent coroutine that launched child coroutines

WRONG (Claude default):
```csharp
Coroutine _mainRoutine;

void Start()
{
    _mainRoutine = StartCoroutine(MainLoop());
}

IEnumerator MainLoop()
{
    StartCoroutine(SubTaskA()); // Launched independently
    StartCoroutine(SubTaskB()); // Launched independently
    yield return new WaitForSeconds(10f);
}

void Cancel()
{
    StopCoroutine(_mainRoutine);
    // SubTaskA and SubTaskB continue running!
}
```

RIGHT:
```csharp
private Coroutine _mainRoutine;
private Coroutine _subA;
private Coroutine _subB;

IEnumerator MainLoop()
{
    _subA = StartCoroutine(SubTaskA());
    _subB = StartCoroutine(SubTaskB());
    yield return new WaitForSeconds(10f);
}

void Cancel()
{
    // Must stop each coroutine individually
    if (_mainRoutine != null) StopCoroutine(_mainRoutine);
    if (_subA != null) StopCoroutine(_subA);
    if (_subB != null) StopCoroutine(_subB);
}

// Better: yield return child coroutines (parent owns them)
IEnumerator MainLoopBetter()
{
    yield return StartCoroutine(SubTaskA()); // Waits for A, then...
    yield return StartCoroutine(SubTaskB()); // Waits for B
    // Stopping MainLoopBetter also stops the currently-yielded child
}
```

GOTCHA: `StartCoroutine(SubTask())` launches an **independent** coroutine. `StopCoroutine` only stops the specified coroutine. BUT: `yield return StartCoroutine(SubTask())` makes the parent wait for the child, and stopping the parent also stops the yielded child. The key distinction: `StartCoroutine` without `yield return` = fire-and-forget; with `yield return` = owned by parent. For complex cancellation trees, prefer `Awaitable` with `CancellationToken`.

---

## PATTERN: async void vs async Awaitable

WHEN: Declaring async methods in Unity scripts

WRONG (Claude default):
```csharp
// async void: exceptions crash the application with no way to catch them
async void DoWork()
{
    await Awaitable.WaitForSecondsAsync(1f);
    throw new Exception("oops"); // UNHANDLED -- crashes the app
}

void Start()
{
    DoWork(); // No way to catch the exception from here
}
```

RIGHT:
```csharp
// async Awaitable: proper exception propagation
async Awaitable DoWork()
{
    await Awaitable.WaitForSecondsAsync(1f);
    throw new Exception("oops"); // Propagates to caller
}

async Awaitable Start()
{
    try
    {
        await DoWork(); // Exception caught here
    }
    catch (Exception e)
    {
        Debug.LogError($"Work failed: {e.Message}");
    }
}

// async void is ONLY acceptable for Unity event handlers that require void:
// - Button.onClick handlers
// - UnityEvent callbacks
// Even then, wrap the body in try/catch:
async void OnButtonClicked()
{
    try
    {
        await SaveGameAsync();
    }
    catch (Exception e)
    {
        Debug.LogError(e);
    }
}
```

GOTCHA: `async void` methods propagate exceptions to the `SynchronizationContext`, which in Unity logs them and potentially crashes. `async Awaitable` methods propagate exceptions to the awaiter, allowing proper try/catch. Unity's lifecycle methods (`Start`, `OnEnable`, etc.) can return `Awaitable` -- prefer this over `void` when using async.

---

## PATTERN: Concurrent Awaitable Race Conditions

WHEN: Multiple async operations modify shared state

WRONG (Claude default):
```csharp
// Two async methods writing to the same field
async Awaitable OnClickSearch(string query)
{
    var results = await SearchAsync(query); // User types "cat"
    _displayedResults = results;            // Race: which query wins?
}
// User clicks twice quickly: "cat" then "dog"
// If "dog" returns first, "cat" results overwrite "dog" results
```

RIGHT:
```csharp
private CancellationTokenSource _searchCts;

async Awaitable OnClickSearch(string query)
{
    // Cancel the previous search
    _searchCts?.Cancel();
    _searchCts?.Dispose();
    _searchCts = new CancellationTokenSource();
    var token = _searchCts.Token;

    try
    {
        var results = await SearchAsync(query, token);
        token.ThrowIfCancellationRequested(); // Check before applying
        _displayedResults = results;          // Only the latest search applies
    }
    catch (OperationCanceledException)
    {
        // Previous search cancelled -- expected
    }
}

void OnDestroy()
{
    _searchCts?.Cancel();
    _searchCts?.Dispose();
}
```

GOTCHA: Unlike coroutines (which are single-threaded and frame-sequential), multiple `Awaitable` chains can interleave across frames. The cancel-previous pattern ensures only the most recent operation applies its results. Link the `CancellationTokenSource` token with `destroyCancellationToken` using `CancellationTokenSource.CreateLinkedTokenSource(destroyCancellationToken)` for automatic cleanup on destroy.

---

## PATTERN: Addressables AsyncOperationHandle Leak

WHEN: Loading assets with Addressables and not releasing them

WRONG (Claude default):
```csharp
async Awaitable LoadEnemy()
{
    var handle = Addressables.LoadAssetAsync<GameObject>("enemy_prefab");
    var prefab = await handle.Task;
    Instantiate(prefab);
    // Handle never released -- memory leak!
}
```

RIGHT:
```csharp
private AsyncOperationHandle<GameObject> _enemyHandle;

async Awaitable LoadEnemy()
{
    _enemyHandle = Addressables.LoadAssetAsync<GameObject>("enemy_prefab");
    var prefab = await _enemyHandle.Task;
    Instantiate(prefab);
}

void OnDestroy()
{
    // Release when no longer needed
    if (_enemyHandle.IsValid())
        Addressables.Release(_enemyHandle);
}

// For instantiated objects, use Addressables.InstantiateAsync (auto-tracked):
async Awaitable SpawnEnemy()
{
    var handle = Addressables.InstantiateAsync("enemy_prefab", spawnPoint.position, Quaternion.identity);
    var instance = await handle.Task;
    // When done: Addressables.ReleaseInstance(instance) instead of Destroy
}
```

GOTCHA: Every `Addressables.LoadAssetAsync` call increments a reference count. Without `Addressables.Release`, the asset stays in memory forever. `Addressables.InstantiateAsync` tracks instances automatically -- use `Addressables.ReleaseInstance` instead of `Destroy`. Scene loading with Addressables (`LoadSceneAsync`) auto-releases on scene unload. Releasing a handle with active instances may cause pink/missing material rendering.

---

## PATTERN: UniTask vs Awaitable Selection

WHEN: Choosing an async framework for a Unity project

WRONG (Claude default):
```csharp
// Mixing UniTask and Awaitable in the same method
async UniTask DoWork()
{
    await Awaitable.NextFrameAsync(); // Type mismatch: Awaitable in UniTask method
}
```

RIGHT:
```csharp
// Pick ONE async framework per project:

// === Option A: Awaitable (Unity 6+ built-in) ===
// Pros: No dependencies, integrated with Unity lifecycle, pooled (zero-alloc)
// Cons: Limited utilities (no WhenAll, WhenAny, no channel/queue)
async Awaitable DoWorkAwaitable()
{
    await Awaitable.NextFrameAsync(destroyCancellationToken);
    await Awaitable.WaitForSecondsAsync(1f, destroyCancellationToken);
}

// === Option B: UniTask (third-party: com.cysharp.unitask) ===
// Pros: Rich API (WhenAll, WhenAny, channels), PlayerLoop integration, zero-alloc
// Cons: External dependency, must learn UniTask-specific patterns
async UniTask DoWorkUniTask()
{
    await UniTask.NextFrame(cancellationToken: destroyCancellationToken);
    await UniTask.Delay(1000, cancellationToken: destroyCancellationToken);
    // UniTask extras: WhenAll, WhenAny, Channel, AsyncReactiveProperty
}

// Converting between them (if mixing is unavoidable):
// Awaitable -> UniTask: not directly; use .AsTask() as bridge
// UniTask -> Awaitable: not directly; use .AsTask() as bridge
```

GOTCHA: Awaitable is built into Unity 6+ and requires no packages. UniTask (com.cysharp.unitask) is a mature third-party library with richer functionality. Do NOT mix both in the same codebase without a clear boundary -- their cancellation patterns, pooling behavior, and PlayerLoop integration differ. If targeting Unity 6+, Awaitable covers most needs. Use UniTask if you need advanced patterns like `WhenAll`, async LINQ, or `IUniTaskAsyncEnumerable`.

---

## Anti-Patterns Quick Reference

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `await Task.Delay()` in Unity | Ignores TimeScale, no frame sync | Use `Awaitable.WaitForSecondsAsync()` |
| `Task.Run()` for Unity computation | Thread pool with no main thread return | Use `Awaitable.BackgroundThreadAsync()` + `MainThreadAsync()` |
| `StopAllCoroutines()` as cleanup | Nuclear option; stops coroutines you didn't start | Track and stop specific coroutines |
| Ignoring return value of `StartCoroutine` | Cannot cancel later | Store the `Coroutine` reference |
| `yield return new WaitForSeconds(0)` | Unclear intent, allocates | Use `yield return null` (no allocation) |
| `async Task` methods in MonoBehaviour | Task exceptions lost, no destroyCancellationToken integration | Use `async Awaitable` |

## Related Skills

- **unity-scripting** -- Coroutine fundamentals, Awaitable API reference, yield types
- **unity-lifecycle** -- destroyCancellationToken, object destruction timing
- **unity-performance** -- Async profiling, allocation tracking

## Additional Resources

- [Awaitable API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Awaitable.html)
- [Coroutines Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/Coroutines.html)
- [Addressables AsyncOperationHandle](https://docs.unity3d.com/Packages/com.unity.addressables@2.3/manual/index.html)
- [UniTask GitHub](https://github.com/Cysharp/UniTask)
