# Addressables & Scene Patterns Reference

Detailed implementations for scene coordination and Addressables workflows. Supplements the DECISION blocks in the parent SKILL.md.

## Complete SceneCoordinator (Additive Scene Management)

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// Manages additive scene loading with a persistent scene pattern.
/// Attach to a GameObject in the persistent/boot scene.
/// </summary>
public class SceneCoordinator : MonoBehaviour
{
    public static SceneCoordinator Instance { get; private set; }

    private readonly HashSet<string> _loadedScenes = new();
    private string _activeContentScene;

    public event Action<string> OnSceneLoadStarted;
    public event Action<string> OnSceneLoadCompleted;
    public event Action<string> OnSceneUnloaded;

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void ResetStatic() => Instance = null;

    /// <summary>Load a scene additively.</summary>
    public async Awaitable LoadScene(string sceneName, bool setActive = false,
        CancellationToken token = default)
    {
        if (_loadedScenes.Contains(sceneName))
        {
            Debug.LogWarning($"Scene '{sceneName}' is already loaded");
            return;
        }

        OnSceneLoadStarted?.Invoke(sceneName);

        await SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
        _loadedScenes.Add(sceneName);

        if (setActive)
        {
            SceneManager.SetActiveScene(SceneManager.GetSceneByName(sceneName));
            _activeContentScene = sceneName;
        }

        OnSceneLoadCompleted?.Invoke(sceneName);
    }

    /// <summary>Unload an additively loaded scene.</summary>
    public async Awaitable UnloadScene(string sceneName, CancellationToken token = default)
    {
        if (!_loadedScenes.Contains(sceneName))
        {
            Debug.LogWarning($"Scene '{sceneName}' is not loaded");
            return;
        }

        await SceneManager.UnloadSceneAsync(sceneName);
        _loadedScenes.Remove(sceneName);

        if (_activeContentScene == sceneName)
            _activeContentScene = null;

        OnSceneUnloaded?.Invoke(sceneName);
    }

    /// <summary>Swap one content scene for another.</summary>
    public async Awaitable SwapContentScene(string newScene,
        System.Action<float> onProgress = null, CancellationToken token = default)
    {
        // Unload current content scene
        if (!string.IsNullOrEmpty(_activeContentScene))
        {
            await UnloadScene(_activeContentScene, token);
        }

        // Load new content scene
        await LoadScene(newScene, setActive: true, token);
        onProgress?.Invoke(1f);
    }

    /// <summary>Check if a scene is currently loaded.</summary>
    public bool IsSceneLoaded(string sceneName) => _loadedScenes.Contains(sceneName);
}
```

---

## AssetReference Workflow

### Inspector Assignment

```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class ProjectileLauncher : MonoBehaviour
{
    // Assigned in Inspector -- designer picks from Addressable assets
    [SerializeField] private AssetReference projectilePrefabRef;
    [SerializeField] private AssetReference impactVFXRef;

    private GameObject _projectilePrefab;
    private GameObject _impactVFXPrefab;
    private AsyncOperationHandle<GameObject> _projHandle;
    private AsyncOperationHandle<GameObject> _vfxHandle;

    async Awaitable Start()
    {
        // Pre-load both assets
        _projHandle = projectilePrefabRef.LoadAssetAsync<GameObject>();
        _vfxHandle = impactVFXRef.LoadAssetAsync<GameObject>();

        _projectilePrefab = await _projHandle.Task;
        _impactVFXPrefab = await _vfxHandle.Task;
    }

    public void Fire(Vector3 position, Vector3 direction)
    {
        if (_projectilePrefab == null) return;
        var proj = Instantiate(_projectilePrefab, position, Quaternion.LookRotation(direction));
        // Configure projectile...
    }

    void OnDestroy()
    {
        if (_projHandle.IsValid()) Addressables.Release(_projHandle);
        if (_vfxHandle.IsValid()) Addressables.Release(_vfxHandle);
    }
}
```

### AssetReference vs String Key

| Feature | `AssetReference` | String key |
|---------|-----------------|------------|
| Inspector support | Drag-and-drop | Manual string entry |
| Refactoring safety | Reference survives rename | String breaks on rename |
| Validation | Compile-time type check | Runtime error |
| Flexibility | Single asset | Wildcard, labels, multiple |
| Best for | Single asset fields | Dynamic/label-based loading |

---

## Loading Screen Implementation

```csharp
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UIElements;

/// <summary>
/// Loading screen that lives in its own additive scene.
/// Contains a UI Document with a progress bar and tip text.
/// </summary>
public class LoadingScreen : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;
    [SerializeField] private string[] loadingTips;

    private ProgressBar _progressBar;
    private Label _tipLabel;

    public static LoadingScreen Instance { get; private set; }

    void Awake()
    {
        Instance = this;
        var root = uiDocument.rootVisualElement;
        _progressBar = root.Q<ProgressBar>("loading-progress");
        _tipLabel = root.Q<Label>("loading-tip");

        // Show a random tip
        if (loadingTips.Length > 0)
            _tipLabel.text = loadingTips[Random.Range(0, loadingTips.Length)];
    }

    void OnDestroy() => Instance = null;

    public void SetProgress(float progress)
    {
        if (_progressBar != null)
        {
            _progressBar.value = progress * 100f;
            _progressBar.title = $"{(int)(progress * 100)}%";
        }
    }
}

/// <summary>
/// Scene transition helper. Shows loading screen, transitions, hides loading screen.
/// </summary>
public static class SceneTransitions
{
    public static async Awaitable TransitionTo(
        string targetScene,
        float minimumDisplayTime = 1.5f,
        CancellationToken token = default)
    {
        float startTime = Time.realtimeSinceStartup;

        // Show loading screen
        await SceneManager.LoadSceneAsync("LoadingScreen", LoadSceneMode.Additive);
        var loadingScreen = LoadingScreen.Instance;

        // Unload current content
        if (SceneCoordinator.Instance != null)
        {
            // Use coordinator for managed scenes
            await SceneCoordinator.Instance.SwapContentScene(targetScene,
                progress => loadingScreen?.SetProgress(progress), token);
        }

        // Enforce minimum display time (prevent loading screen flash)
        float elapsed = Time.realtimeSinceStartup - startTime;
        if (elapsed < minimumDisplayTime)
        {
            float remaining = minimumDisplayTime - elapsed;
            float timer = 0f;
            while (timer < remaining)
            {
                timer += Time.unscaledDeltaTime;
                // Fake progress during minimum time
                loadingScreen?.SetProgress(0.9f + 0.1f * (timer / remaining));
                await Awaitable.NextFrameAsync(token);
            }
        }

        loadingScreen?.SetProgress(1f);

        // Brief pause at 100% so the user sees completion
        await Awaitable.WaitForSecondsAsync(0.3f, token);

        // Unload loading screen
        await SceneManager.UnloadSceneAsync("LoadingScreen");
    }
}
```

---

## Addressables Group Organization

### Recommended Group Structure

```
Addressable Groups:
|
+-- Core (always loaded)
|     - PlayerPrefab
|     - CommonUI
|     - SharedVFX
|     - AudioMixerSnapshot
|
+-- Level_Forest
|     - ForestTerrain
|     - ForestEnemies
|     - ForestProps
|     - ForestAudio
|
+-- Level_Cave
|     - CaveTerrain
|     - CaveEnemies
|     - CaveProps
|
+-- Characters
|     - Player skins
|     - NPC models
|     - Companion prefabs
|
+-- UI
|     - Menu screens
|     - HUD elements
|     - Fonts
|
+-- Audio
|     - Music tracks
|     - Ambient loops
|     - SFX banks
```

### Group Settings

| Setting | Recommendation | Why |
|---------|---------------|-----|
| Bundle Mode | Pack Together | Fewer bundles, less overhead |
| Compression | LZ4 | Fast decompression, good ratio |
| Include in Build | Yes for local | No for remote/DLC |
| Build Path | LocalBuildPath | RemoteBuildPath for CDN |
| Load Path | LocalLoadPath | RemoteLoadPath for CDN |

### Labels for Cross-Cutting Concerns

```
Labels:
  "preload"     -> Assets loaded during splash/boot
  "level_forest" -> All forest level assets (across groups)
  "enemy"       -> All enemy prefabs (for random spawning)
  "loot"        -> All loot drop prefabs
  "audio_music" -> All music tracks
```

```csharp
// Load all assets with a label
var handle = Addressables.LoadAssetsAsync<GameObject>("enemy",
    asset => Debug.Log($"Loaded enemy: {asset.name}"));
var enemies = await handle.Task;
```

---

## Memory Lifecycle Diagram

```
SCENE ENTER
  |
  v
[Preload Phase]
  - Addressables.LoadAssetAsync for required assets
  - Track all handles in a list
  - Report progress to loading screen
  |
  v
[Gameplay Phase]
  - Instantiate from loaded assets (Instantiate, not InstantiateAsync)
  - Or use Addressables.InstantiateAsync for tracked instances
  - On-demand lazy loading for non-critical assets
  |
  v
[Scene Exit / Cleanup]
  - Destroy all instantiated objects FIRST
  - Then Addressables.Release all handles
  - Or Addressables.ReleaseInstance for tracked instances
  |
  v
[Unload Scene]
  - SceneManager.UnloadSceneAsync
  - Resources.UnloadUnusedAssets (optional, for safety)
```

**Key rule:** Destroy instances BEFORE releasing handles. Releasing a handle while instances exist = pink materials.
