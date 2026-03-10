# Mobile Optimization Reference

iOS and Android optimization guidelines for Unity 6.

Sources:
- [iOS Development](https://docs.unity3d.com/6000.3/Documentation/Manual/iphone.html)
- [Android Development](https://docs.unity3d.com/6000.3/Documentation/Manual/android.html)
- [iOS Player Settings](https://docs.unity3d.com/6000.3/Documentation/Manual/class-PlayerSettingsiOS.html)
- [Android Player Settings](https://docs.unity3d.com/6000.3/Documentation/Manual/class-PlayerSettingsAndroid.html)

## iOS Configuration

### Architecture and Backend

- **Architecture**: ARM64 only (no ARMv7 support)
- **Scripting Backend**: IL2CPP required (Mono not available on iOS)
- **Target SDK**: Device SDK or Simulator SDK
- **Simulator Architecture**: ARM64, X86_64, or Universal

### Player Settings

| Setting | Recommendation |
|---------|---------------|
| Bundle Identifier | `com.CompanyName.ProductName` |
| Signing Team ID | Required for automatic signing |
| Automatically Sign | Enable for Xcode auto-signing |
| Minimum iOS Version | Set to lowest version you support |
| Metal API Validation | Enable during development, disable for release |
| Metal Write-Only Backbuffer | Enable for performance in non-default orientations |
| Force hard shadows on Metal | Enable point sampling for performance |

### iOS Graphics

- Metal is the sole graphics API on iOS
- Use Metal API Validation during development to catch shader issues
- Metal Write-Only Backbuffer improves performance when orientation differs from default
- Force hard shadows on Metal uses point sampling to boost shadow performance

### Orientation

- Options: Portrait, Portrait Upside Down, Landscape Right, Landscape Left, Auto Rotation
- Auto Rotation allows selecting which orientations are permitted
- Fewer allowed orientations means fewer layout recalculations

### Launch Screen

- Options: Default, None, Image and background (relative/constant size), Custom Storyboard
- Custom Storyboard recommended for full control over launch experience
- VR Splash Image available for VR apps

## Android Configuration

### Architecture and Backend

| Architecture | Scripting Backend | Notes |
|-------------|-------------------|-------|
| ARMv7 | Mono or IL2CPP | Legacy 32-bit devices |
| ARM64 | IL2CPP required | Modern 64-bit devices (Google Play requires) |

**Split APKs by target architecture**: Enable to create separate downloads per architecture, reducing user download sizes on Google Play.

### Graphics API

| API | Notes |
|-----|-------|
| Vulkan | Modern, preferred. Better performance and feature set |
| OpenGL ES 3.0 | Broad compatibility fallback |
| OpenGL ES 3.1 | Compute shader support |
| OpenGL ES 3.1 + AEP | Android Extension Pack |
| OpenGL ES 3.2 | Latest GLES version |

**Auto Graphics API** (default): Attempts Vulkan first, falls back to GLES.

### Keystore and Signing

- Debug keystore provided by Unity for testing
- Custom keystore required for production/Google Play
- Enable **Custom Keystore** and browse to select keystore file
- Set keystore and key passwords

### Player Settings

| Setting | Recommendation |
|---------|---------------|
| Package Name | `com.YourCompanyName.YourProductName` |
| Minimum API Level | Lowest Android version to support |
| Target API Level | Latest stable API level |
| API Compatibility | .NET Standard 2.1 (smaller) or .NET Framework (more APIs) |
| Managed Stripping Level | High for smallest builds, Minimal for safest |

## Texture Compression

### Recommended Formats

| Format | iOS | Android | Notes |
|--------|-----|---------|-------|
| ASTC | Yes | Yes (most modern) | Best quality-to-size ratio, variable block sizes (4x4 to 12x12) |
| PVRTC | Yes (legacy) | No | Older iOS devices, being replaced by ASTC |
| ETC2 | No | Yes (OpenGL ES 3.0+) | Standard Android compression, good quality |
| ETC | No | Yes (legacy) | OpenGL ES 2.0 fallback, no alpha support |

**Recommendation**: Use ASTC for both platforms when targeting modern devices. ASTC 4x4 for highest quality, ASTC 8x8 or larger for smaller file sizes.

### Texture Tips

- Use power-of-two textures where possible for compatibility
- Enable mipmaps for 3D objects to reduce aliasing and GPU bandwidth
- Disable mipmaps for UI textures (never viewed at reduced size)
- Compress all textures; uncompressed textures waste memory and bandwidth
- Use texture atlases to reduce draw calls

## Batching and Draw Calls

### Static Batching

Mark non-moving objects as **Static** in the Inspector. Unity combines their meshes at build time to reduce draw calls.

```csharp
// Mark via script
gameObject.isStatic = true;
```

**Trade-off**: Increases memory usage (combined mesh stored) but reduces draw calls significantly.

### Dynamic Batching

Unity automatically batches small meshes that share the same material. Requirements:
- Fewer than 300 vertices (after shader attributes calculated)
- Same material instance
- Same transform scale (uniform scaling)

### GPU Instancing

For many identical objects (trees, grass, particles):

```csharp
// Enable on material
material.enableInstancing = true;
```

### SRP Batcher

When using URP or HDRP, the SRP Batcher reduces CPU time for rendering by batching shader state changes rather than geometry. Enabled by default in URP/HDRP.

## Memory Management

### General Mobile Guidelines

- **Target memory budget**: Stay under 200 MB for broad device compatibility
- Monitor memory with Unity Profiler > Memory module
- Use `Profiler.GetTotalAllocatedMemoryLong()` for runtime checks

### Asset Loading

- Use Addressables or AssetBundles for on-demand loading
- Unload unused assets: `Resources.UnloadUnusedAssets()`
- Avoid Resources folder for large assets (loaded at startup)

### Texture Memory

Textures are typically the largest memory consumer on mobile:

```csharp
// Check texture memory at runtime
long textureMemory = Profiler.GetAllocatedMemoryForGraphicsDriver();
```

- Reduce texture resolution for mobile targets
- Use compressed formats (ASTC preferred)
- Use sprite atlases for 2D games

### Object Pooling

Avoid runtime instantiation/destruction on mobile. Use object pools:

```csharp
public class SimplePool : MonoBehaviour
{
    [SerializeField] private GameObject prefab;
    [SerializeField] private int poolSize = 20;
    private Queue<GameObject> pool = new Queue<GameObject>();

    void Awake()
    {
        for (int i = 0; i < poolSize; i++)
        {
            var obj = Instantiate(prefab);
            obj.SetActive(false);
            pool.Enqueue(obj);
        }
    }

    public GameObject Get()
    {
        if (pool.Count == 0) return Instantiate(prefab);
        var obj = pool.Dequeue();
        obj.SetActive(true);
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
        pool.Enqueue(obj);
    }
}
```

### Garbage Collection

- Avoid allocations in Update/FixedUpdate
- Cache component references in Awake/Start
- Use `StringBuilder` instead of string concatenation
- Use `NonAlloc` variants of Physics queries:

```csharp
// BAD: Allocates array every call
Collider[] hits = Physics.OverlapSphere(pos, radius);

// GOOD: Reuse pre-allocated array
private Collider[] hitBuffer = new Collider[32];
int count = Physics.OverlapSphereNonAlloc(pos, radius, hitBuffer);
```

## Frame Rate and Performance

### Target Frame Rate

```csharp
// Set 60 FPS target on mobile
Application.targetFrameRate = 60;

// For battery-conscious apps, 30 FPS is acceptable
Application.targetFrameRate = 30;

// Prevent screen dimming
Screen.sleepTimeout = SleepTimeout.NeverSleep;
```

### Shader Optimization

- Use Mobile-specific shaders (URP/Lit with simplified settings)
- Minimize shader variants via Shader Variant Collection
- Avoid complex fragment shaders (per-pixel operations expensive on mobile GPUs)
- Use shader LOD to reduce complexity at distance

### Physics Optimization

- Reduce Fixed Timestep to 0.02 (50 Hz) or 0.033 (30 Hz) for mobile
- Use simplified collision meshes (box/sphere colliders over mesh colliders)
- Disable unnecessary physics layers via Layer Collision Matrix

## Build Size Reduction

### Android

- Enable Split APKs by architecture (separate ARM64/ARMv7 downloads)
- Use Android App Bundle (AAB) format for Google Play
- Enable Managed Stripping Level: High
- Remove unused packages from Package Manager
- Compress textures and audio

### iOS

- Enable IL2CPP code stripping
- Use Managed Stripping Level: High (test thoroughly)
- Remove unused packages
- Use On Demand Resources for large assets
- Compress textures and audio

### Both Platforms

- Use Addressables for remote content delivery
- Enable code stripping (link.xml to preserve needed types)
- Audit included scenes in Build Profiles
- Remove development/debug code via `#if !DEVELOPMENT_BUILD`

## Anti-Patterns

1. **Loading all assets at startup** via Resources folder. Use Addressables for on-demand loading.
2. **Allocating in hot paths** (Update, FixedUpdate). Cache references and use object pools.
3. **Uncompressed textures** on mobile. Always use ASTC or platform-appropriate compression.
4. **Ignoring device fragmentation on Android**. Test on low-end, mid-range, and high-end devices.
5. **Not profiling on device**. Editor performance does not represent mobile performance.
6. **Using Mesh Colliders everywhere**. Prefer primitive colliders (Box, Sphere, Capsule).
7. **Running at uncapped frame rate on mobile**. Set `Application.targetFrameRate` to save battery and reduce thermal throttling.
8. **Not using IL2CPP for release builds on Android**. IL2CPP provides better performance than Mono for production.
