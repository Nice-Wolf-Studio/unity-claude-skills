# Async Cancellation Patterns Reference

Detailed reference for CancellationToken usage, error propagation, and async lifecycle management. Supplements the PATTERN blocks in the parent SKILL.md.

## CancellationToken Chain Patterns

### Basic: destroyCancellationToken

```csharp
// Every MonoBehaviour has destroyCancellationToken (Unity 6+)
// It triggers when OnDestroy begins
async Awaitable SimpleAsync()
{
    await Awaitable.WaitForSecondsAsync(5f, destroyCancellationToken);
    // If object destroyed during wait: OperationCanceledException thrown
}
```

### Linked: Combine destroy + custom cancellation

```csharp
// When you need to cancel for reasons OTHER than destruction
private CancellationTokenSource _abilityCts;

async Awaitable UseAbility()
{
    // Link both: cancels if object destroyed OR ability interrupted
    _abilityCts?.Cancel();
    _abilityCts?.Dispose();
    _abilityCts = CancellationTokenSource.CreateLinkedTokenSource(destroyCancellationToken);
    var token = _abilityCts.Token;

    try
    {
        // Charge phase
        await Awaitable.WaitForSecondsAsync(2f, token);
        // Release phase
        ExecuteAbility();
    }
    catch (OperationCanceledException)
    {
        // Either destroyed or interrupted -- handle both the same way
    }
}

public void InterruptAbility()
{
    _abilityCts?.Cancel();
}

void OnDestroy()
{
    _abilityCts?.Cancel();
    _abilityCts?.Dispose();
}
```

### Timeout Pattern

```csharp
async Awaitable<bool> LoadWithTimeout(string url, float timeoutSeconds)
{
    using var timeoutCts = new CancellationTokenSource();
    timeoutCts.CancelAfter(TimeSpan.FromSeconds(timeoutSeconds));

    using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
        destroyCancellationToken, timeoutCts.Token);

    try
    {
        var result = await FetchDataAsync(url, linkedCts.Token);
        ProcessResult(result);
        return true;
    }
    catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
    {
        Debug.LogWarning($"Request to {url} timed out after {timeoutSeconds}s");
        return false;
    }
    catch (OperationCanceledException)
    {
        // Object destroyed -- let it propagate or handle
        return false;
    }
}
```

---

## Awaitable + destroyCancellationToken Lifecycle

```
MonoBehaviour CREATED
  |
  v
Awake() -- destroyCancellationToken is available here
  |
  v
OnEnable()
  |
  v
Start() -- can be async Awaitable Start()
  |
  v
(async operations running, using destroyCancellationToken)
  |
  v
DESTRUCTION TRIGGERED (Destroy called, scene unload, etc.)
  |
  v
destroyCancellationToken.IsCancellationRequested = TRUE
  |
  v
All awaiting operations throw OperationCanceledException
  |
  v
OnDisable()
  |
  v
OnDestroy()
  |
  v
C# object eligible for GC (but "fake-null" until collected)
```

### Key Points

- `destroyCancellationToken` is triggered at the START of the destruction process
- It fires BEFORE `OnDisable` and `OnDestroy`
- After cancellation, the token stays cancelled (it's one-shot)
- The token is per-MonoBehaviour, not per-GameObject
- Disabled components still have a valid `destroyCancellationToken`

---

## Error Propagation Comparison

### Coroutine Exception Behavior

```csharp
IEnumerator Parent()
{
    Debug.Log("Parent start");
    yield return StartCoroutine(Child());
    Debug.Log("Parent end"); // REACHED even if Child threw (in some cases)
}

IEnumerator Child()
{
    Debug.Log("Child start");
    throw new Exception("oops");
    // Exception is logged to console
    // Child coroutine stops
    // Parent behavior depends on Unity version:
    //   - Unity 6: Parent also stops (improved from older versions)
    //   - Older Unity: Parent may continue
}

// No way to try/catch the exception from the caller
void Start()
{
    StartCoroutine(Parent());
    // If Parent/Child throws, Start doesn't know about it
}
```

### Awaitable Exception Behavior

```csharp
async Awaitable Parent()
{
    Debug.Log("Parent start");
    try
    {
        await Child();
    }
    catch (Exception e)
    {
        Debug.LogError($"Child failed: {e.Message}"); // CAUGHT properly
    }
    Debug.Log("Parent end"); // Reached because exception was caught
}

async Awaitable Child()
{
    Debug.Log("Child start");
    throw new Exception("oops"); // Propagates to awaiter
}

async Awaitable Start()
{
    try
    {
        await Parent();
    }
    catch (Exception e)
    {
        Debug.LogError($"Unhandled: {e.Message}"); // Full control
    }
}
```

### Comparison Table

| Feature | Coroutine | Awaitable | UniTask |
|---------|-----------|-----------|---------|
| Exception propagation | Console log only | To awaiter (proper) | To awaiter (proper) |
| try/catch around yield | Compiler error | Full support | Full support |
| Cancellation | StopCoroutine (manual) | CancellationToken | CancellationToken |
| Return values | Not supported | `Awaitable<T>` | `UniTask<T>` |
| Thread switching | Not possible | BackgroundThreadAsync | SwitchToThreadPool |
| Allocation | Per yield (WaitForSeconds etc.) | Pooled (zero-alloc) | Zero-alloc |
| Multiple await | N/A | NO (pooled, single-await) | Yes |
| WhenAll/WhenAny | Manual | Not built-in | Yes |
| Editor play mode | Works | Works | Works |
| Batch mode | WaitForEndOfFrame hangs | EndOfFrameAsync hangs | DelayFrame works |

---

## Addressables Async Patterns

### Loading Assets

```csharp
public class AssetLoader : MonoBehaviour
{
    private readonly List<AsyncOperationHandle> _handles = new();

    // Load a single asset
    public async Awaitable<T> LoadAsset<T>(string address) where T : Object
    {
        var handle = Addressables.LoadAssetAsync<T>(address);
        _handles.Add(handle);
        return await handle.Task;
    }

    // Load multiple assets
    public async Awaitable<IList<T>> LoadAssets<T>(IList<string> addresses) where T : Object
    {
        var handle = Addressables.LoadAssetsAsync<T>(addresses,
            obj => { /* callback per loaded asset */ },
            Addressables.MergeMode.Union);
        _handles.Add(handle);
        return await handle.Task;
    }

    // Instantiate (tracked automatically)
    public async Awaitable<GameObject> InstantiateAsync(string address, Transform parent = null)
    {
        var handle = Addressables.InstantiateAsync(address, parent);
        _handles.Add(handle);
        return await handle.Task;
    }

    // Release everything on destroy
    void OnDestroy()
    {
        foreach (var handle in _handles)
        {
            if (handle.IsValid())
                Addressables.Release(handle);
        }
        _handles.Clear();
    }
}
```

### Loading Scenes

```csharp
public class SceneLoader : MonoBehaviour
{
    private AsyncOperationHandle<SceneInstance> _sceneHandle;

    public async Awaitable LoadScene(string sceneAddress)
    {
        _sceneHandle = Addressables.LoadSceneAsync(sceneAddress,
            UnityEngine.SceneManagement.LoadSceneMode.Additive);
        await _sceneHandle.Task;
    }

    public async Awaitable UnloadScene()
    {
        if (_sceneHandle.IsValid())
        {
            await Addressables.UnloadSceneAsync(_sceneHandle).Task;
        }
    }
}
```

### Progress Reporting

```csharp
public async Awaitable LoadWithProgress(string address, System.Action<float> onProgress)
{
    var handle = Addressables.LoadAssetAsync<GameObject>(address);

    while (!handle.IsDone)
    {
        onProgress?.Invoke(handle.PercentComplete);
        await Awaitable.NextFrameAsync(destroyCancellationToken);
    }

    onProgress?.Invoke(1f);

    if (handle.Status == AsyncOperationStatus.Failed)
    {
        Debug.LogError($"Failed to load {address}: {handle.OperationException}");
        Addressables.Release(handle);
        return;
    }

    var asset = handle.Result;
    // Use asset...
}
```

---

## Common Awaitable Patterns

### Sequential Operations

```csharp
async Awaitable SequentialLoad()
{
    var token = destroyCancellationToken;

    await Awaitable.NextFrameAsync(token);
    var config = await LoadConfigAsync(token);

    await Awaitable.NextFrameAsync(token);
    var assets = await LoadAssetsAsync(config, token);

    await Awaitable.NextFrameAsync(token);
    InitializeGame(assets);
}
```

### Fire-and-Forget (with safety)

```csharp
// When you can't await (e.g., from a synchronous callback)
void OnTriggerEnter(Collider other)
{
    // Can't make OnTriggerEnter async, so fire-and-forget
    _ = HandleTriggerAsync(other);
}

async Awaitable HandleTriggerAsync(Collider other)
{
    try
    {
        await Awaitable.WaitForSecondsAsync(0.5f, destroyCancellationToken);
        if (other) // Check if other still exists
            ProcessTrigger(other);
    }
    catch (OperationCanceledException) { }
    catch (Exception e)
    {
        Debug.LogError($"Trigger async failed: {e}");
    }
}
```

### Debounce Pattern

```csharp
private CancellationTokenSource _debounceCts;

async Awaitable DebouncedSearch(string query)
{
    _debounceCts?.Cancel();
    _debounceCts?.Dispose();
    _debounceCts = CancellationTokenSource.CreateLinkedTokenSource(destroyCancellationToken);

    try
    {
        await Awaitable.WaitForSecondsAsync(0.3f, _debounceCts.Token); // Wait for typing to stop
        var results = await SearchAsync(query, _debounceCts.Token);
        DisplayResults(results);
    }
    catch (OperationCanceledException) { }
}
```
