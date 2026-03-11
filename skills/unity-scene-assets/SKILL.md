---
name: unity-scene-assets
description: >
  Unity scene and asset architecture decisions. Additive scene composition, Addressables vs
  Resources, AssetReference workflow, asset lifecycle coordination, loading screens.
  DECISION format: WHEN/DECISION/SCAFFOLD/GOTCHA. Based on Unity 6.3 LTS.
globs:
  - "**/*.cs"
  - "**/*.unity"
---

# Scene & Asset Management -- Decision Patterns

> **Prerequisite skills:** `unity-foundations/references/prefabs-and-scenes.md` (SceneManager API, additive loading), `unity-async-patterns` (Addressables handle lifecycle, async loading), `unity-game-architecture` (bootstrap patterns)

These patterns address the most common asset management failures: Claude hardcodes `Resources.Load`, ignores async loading, and does not account for memory lifecycle.

---

## PATTERN: Scene Architecture Strategy

WHEN: Structuring a project's scenes for a real game (not a prototype)

DECISION:
- **Single scene** -- Game jam, prototype, tiny game. Everything in one scene. No loading, no complexity. Outgrow it quickly.
- **Scene-per-level** -- Linear progression (platformers, puzzle games). `LoadScene(name, LoadSceneMode.Single)` between levels. Clean separation but no shared state without `DontDestroyOnLoad`.
- **Additive scene composition** -- Open worlds, persistent HUD, shared systems. A "Boot" or "Persistent" scene stays loaded, gameplay/UI scenes load additively. Most flexible, most complex.

SCAFFOLD (Additive scene coordinator):
```csharp
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneCoordinator : MonoBehaviour
{
    [SerializeField] private string persistentSceneName = "Persistent";
    private string _currentContentScene;

    public static SceneCoordinator Instance { get; private set; }

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() => Instance = null;

    /// <summary>
    /// Load a content scene additively, unloading the previous one.
    /// The persistent scene stays loaded.
    /// </summary>
    public async Awaitable LoadContentScene(string sceneName)
    {
        // Unload previous content scene
        if (!string.IsNullOrEmpty(_currentContentScene))
        {
            await SceneManager.UnloadSceneAsync(_currentContentScene);
        }

        // Load new content scene
        await SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
        _currentContentScene = sceneName;

        // Set active scene for lighting and new object spawning
        SceneManager.SetActiveScene(SceneManager.GetSceneByName(sceneName));
    }
}
```

GOTCHA: `SceneManager.SetActiveScene` determines which scene's lighting settings apply and where newly instantiated objects are placed. Forgetting this causes objects spawning in the persistent scene (wrong lightmaps, wrong navmesh). The persistent scene must be in Build Settings at index 0. Every additive scene must also be in Build Settings.

---

## PATTERN: Asset Loading Strategy

WHEN: Choosing how to load assets at runtime

DECISION:
- **Direct references (`[SerializeField]`)** -- Small projects where all assets are always in memory. Simplest. Assets load with the scene. No manual lifecycle management.
- **Resources.Load** -- Legacy. Avoid for new projects. The entire Resources folder is indexed at startup (slow) and included in builds (bloated).
- **Addressables** -- Medium-large projects, dynamic content, DLC, remote assets. Async, reference-counted, labelable. Requires learning the lifecycle.

SCAFFOLD (AssetReference pattern):
```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class EnemySpawner : MonoBehaviour
{
    [SerializeField] private AssetReference enemyPrefabRef; // Assign in Inspector

    private AsyncOperationHandle<GameObject> _handle;

    public async Awaitable<GameObject> SpawnEnemy(Vector3 position)
    {
        // Load the asset (ref-counted -- safe to call multiple times)
        _handle = enemyPrefabRef.LoadAssetAsync<GameObject>();
        var prefab = await _handle.Task;

        return Instantiate(prefab, position, Quaternion.identity);
    }

    void OnDestroy()
    {
        // Release when no longer needed
        if (_handle.IsValid())
            Addressables.Release(_handle);
    }
}
```

GOTCHA: `Resources.Load` is synchronous, includes all assets in the Resources folder in the build (even unused ones), and has no unloading strategy. Migration: replace `Resources.Load<T>("path")` with `Addressables.LoadAssetAsync<T>("path")`. `AssetReference` fields in the Inspector let you select Addressable assets without string keys -- prefer these over string-based loading.

---

## PATTERN: Addressables Group Strategy

WHEN: Organizing assets into Addressable groups for build and loading

DECISION:
- **By scene/level** -- Level-based games. Load all assets for a level together. Unload when leaving. Clean memory lifecycle.
- **By type** -- All characters, all VFX, all audio in separate groups. Good for shared assets used across multiple scenes.
- **By frequency** -- Core (always loaded: UI, player, common VFX), On-demand (enemy variants, level-specific), Rare (boss, cutscene, seasonal).

SCAFFOLD (Label-based loading):
```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using System.Collections.Generic;

public class LevelAssetLoader : MonoBehaviour
{
    private AsyncOperationHandle<IList<GameObject>> _levelAssetsHandle;

    public async Awaitable PreloadLevel(string levelLabel)
    {
        // Load all assets tagged with the level label
        _levelAssetsHandle = Addressables.LoadAssetsAsync<GameObject>(
            levelLabel,
            asset => Debug.Log($"Loaded: {asset.name}")
        );
        await _levelAssetsHandle.Task;
    }

    public void UnloadLevel()
    {
        if (_levelAssetsHandle.IsValid())
            Addressables.Release(_levelAssetsHandle);
    }
}
```

GOTCHA: Too many small groups create catalog overhead (each group = bundle metadata). Too few large groups force loading unneeded assets. Target 5-20 groups for most projects. Profile with the Addressables Event Viewer (Window > Asset Management > Addressables > Event Viewer) to verify load/unload timing.

---

## PATTERN: Loading Screen Coordination

WHEN: Transitioning between gameplay sections with asset loading

DECISION:
- **AsyncOperation.allowSceneActivation** -- Simple fade-to-black. Load to 90%, display loading screen, activate on ready. Single-scene approach.
- **Additive loading screen scene** -- Persistent loading UI in its own scene. Better for complex transitions with progress bars and tips.

SCAFFOLD (Scene transition with progress):
```csharp
public class SceneTransition : MonoBehaviour
{
    [SerializeField] private float minimumLoadScreenTime = 1f; // Prevent flash

    public async Awaitable TransitionTo(string sceneName, System.Action<float> onProgress = null)
    {
        // Show loading screen
        await SceneManager.LoadSceneAsync("LoadingScreen", LoadSceneMode.Additive);

        float startTime = Time.realtimeSinceStartup;

        // Begin loading target scene (paused at 90%)
        var loadOp = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
        loadOp.allowSceneActivation = false;

        // Unload current gameplay scene in parallel
        if (!string.IsNullOrEmpty(_currentContentScene))
        {
            var unloadOp = SceneManager.UnloadSceneAsync(_currentContentScene);
            while (!unloadOp.isDone)
            {
                await Awaitable.NextFrameAsync(destroyCancellationToken);
            }
        }

        // Wait for target to reach 90% (ready to activate)
        while (loadOp.progress < 0.9f)
        {
            // Normalize: AsyncOperation.progress maxes at 0.9 when allowSceneActivation=false
            float normalizedProgress = Mathf.Clamp01(loadOp.progress / 0.9f);
            onProgress?.Invoke(normalizedProgress);
            await Awaitable.NextFrameAsync(destroyCancellationToken);
        }

        // Enforce minimum display time
        float elapsed = Time.realtimeSinceStartup - startTime;
        if (elapsed < minimumLoadScreenTime)
        {
            await Awaitable.WaitForSecondsAsync(
                minimumLoadScreenTime - elapsed, destroyCancellationToken);
        }

        onProgress?.Invoke(1f);

        // Activate the scene
        loadOp.allowSceneActivation = true;
        while (!loadOp.isDone)
            await Awaitable.NextFrameAsync(destroyCancellationToken);

        _currentContentScene = sceneName;
        SceneManager.SetActiveScene(SceneManager.GetSceneByName(sceneName));

        // Unload loading screen
        await SceneManager.UnloadSceneAsync("LoadingScreen");
    }

    private string _currentContentScene;
}
```

GOTCHA: `AsyncOperation.progress` maxes at **0.9** when `allowSceneActivation = false`. Normalize it: `Mathf.Clamp01(op.progress / 0.9f)`. The scene activates immediately when `allowSceneActivation` is set to `true` -- there is no additional delay. Use `Time.realtimeSinceStartup` for minimum load time (not `Time.time`, which is affected by timeScale).

---

## PATTERN: Asset Lifecycle Coordination

WHEN: Ensuring assets load before gameplay starts and unload when no longer needed

DECISION:
- **Preload on scene enter** -- Load all required assets in a loading phase, release on scene exit. Predictable memory, no runtime hitches. Best for level-based games.
- **Lazy load on demand** -- Load when first needed, cache reference, release when scene exits. Lower initial load time, possible frame hitches on first use. Best for open worlds.

SCAFFOLD (Asset preloader with progress):
```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using System.Collections.Generic;

public class AssetPreloader : MonoBehaviour
{
    private readonly List<AsyncOperationHandle> _handles = new();

    /// <summary>
    /// Preload a list of Addressable keys. Reports progress 0-1.
    /// </summary>
    public async Awaitable Preload(
        IList<string> keys,
        System.Action<float> onProgress = null,
        CancellationToken token = default)
    {
        int loaded = 0;
        int total = keys.Count;

        foreach (string key in keys)
        {
            token.ThrowIfCancellationRequested();

            var handle = Addressables.LoadAssetAsync<Object>(key);
            _handles.Add(handle);
            await handle.Task;

            loaded++;
            onProgress?.Invoke((float)loaded / total);
        }
    }

    /// <summary>Release all preloaded assets.</summary>
    public void ReleaseAll()
    {
        foreach (var handle in _handles)
        {
            if (handle.IsValid())
                Addressables.Release(handle);
        }
        _handles.Clear();
    }

    void OnDestroy() => ReleaseAll();
}
```

GOTCHA: Releasing an Addressable handle while instantiated objects still reference the loaded asset causes pink/missing materials at best, crashes at worst. Always destroy all instances before releasing the asset handle. Use `Addressables.InstantiateAsync` instead of manual `LoadAssetAsync` + `Instantiate` when you want automatic tracking -- then use `Addressables.ReleaseInstance` to clean up.

---

## Resources-to-Addressables Migration Checklist

| Step | Action |
|------|--------|
| 1 | Install Addressables package (`com.unity.addressables`) |
| 2 | Open Window > Asset Management > Addressables > Groups |
| 3 | Create default settings if prompted |
| 4 | Move assets OUT of `Resources/` folders to regular asset folders |
| 5 | Mark assets as Addressable (Inspector checkbox or drag to group) |
| 6 | Replace `Resources.Load<T>("path")` with `Addressables.LoadAssetAsync<T>("path")` |
| 7 | Add handle tracking and `Addressables.Release()` calls |
| 8 | Replace `Resources.LoadAll<T>()` with label-based `Addressables.LoadAssetsAsync` |
| 9 | Delete empty `Resources/` folders |
| 10 | Test with Addressables Event Viewer to verify no leaks |

**Keep in Resources:** Editor-only assets, test fixtures, assets needed before Addressables initializes (splash screen).

## Related Skills

- **unity-foundations/references/prefabs-and-scenes.md** -- SceneManager API, additive loading (do not duplicate)
- **unity-async-patterns** -- Addressables AsyncOperationHandle lifecycle, async cancellation (do not duplicate)
- **unity-game-architecture** -- Boot scene bootstrap, Service Locator for scene management
- **unity-performance** -- Memory profiling, Addressables memory tracking

## Additional Resources

- [Addressables Manual](https://docs.unity3d.com/Packages/com.unity.addressables@2.3/manual/index.html)
- [SceneManager API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/SceneManagement.SceneManager.html)
- [AsyncOperation](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AsyncOperation.html)
- [AssetReference API](https://docs.unity3d.com/Packages/com.unity.addressables@2.3/api/UnityEngine.AddressableAssets.AssetReference.html)
