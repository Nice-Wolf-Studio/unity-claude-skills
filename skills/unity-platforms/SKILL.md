---
name: unity-platforms
description: >
  Unity 6 platform targeting and build guide. Use when building for specific platforms, configuring build profiles, using platform scripting defines (#if UNITY_IOS, #if UNITY_ANDROID), optimizing for mobile, WebGL, or consoles, working with Addressables/asset bundles, or choosing between IL2CPP and Mono. Based on Unity 6.3 LTS documentation.
---

# Unity Platforms Skill

## Supported Platforms

Unity 6 supports the following platform categories:

- **Desktop**: Windows, macOS, Linux
- **Mobile**: Android, iOS
- **Emerging**: visionOS, tvOS
- **Web**: WebGL (including Facebook Instant Games)
- **Server**: Dedicated Server
- **Embedded**: Embedded Linux, QNX
- **UWP**: Universal Windows Platform
- **Closed Platforms**: PlayStation, Xbox (Game Core), Nintendo (require confidentiality/legal agreements and registration via Platform Module Installation)

## Build Profiles and Settings

Build Profiles replace the old Build Settings window. A build profile is a set of configuration settings for building your application on a particular platform.

### Two Profile Types

1. **Platforms**: Display currently installed platforms with shared settings across all configurations. Enabling options like Development Build applies universally. Platforms share identical scene data across profiles.
2. **Build Profiles**: Independent configurations not shared across platforms. Each can specify unique scenes and settings. Stored as asset files compatible with version control.

### Key Features

- Custom naming for organizing multiple build configurations
- Version control integration (profiles stored as asset files)
- Per-profile scene assignment
- Development builds (debug symbols, Profiler access) and release builds
- Access via **File > Build Profiles**
- Duplicate a platform via right-click > "Copy to new profile"

### Scene Management

Scenes are managed per-profile. You can add, exclude, remove, and reorder scenes in your build. Each unique Scene file represents a unique level or screen.

## Platform Scripting Defines

Use `#if` directives to conditionally compile code per platform.

### Platform Defines

| Define | Platform |
|--------|----------|
| `UNITY_EDITOR` | Any Editor code |
| `UNITY_EDITOR_WIN` | Windows Editor |
| `UNITY_EDITOR_OSX` | macOS Editor |
| `UNITY_EDITOR_LINUX` | Linux Editor |
| `UNITY_STANDALONE_OSX` | macOS Standalone |
| `UNITY_STANDALONE_WIN` | Windows Standalone |
| `UNITY_STANDALONE_LINUX` | Linux Standalone |
| `UNITY_STANDALONE` | Any Standalone (Win/Mac/Linux) |
| `UNITY_SERVER` | Dedicated Server |
| `UNITY_IOS` | iOS |
| `UNITY_ANDROID` | Android |
| `UNITY_TVOS` | tvOS |
| `UNITY_VISIONOS` | visionOS |
| `UNITY_WEBGL` | WebGL |
| `UNITY_WSA` | Universal Windows Platform |
| `UNITY_WSA_10_0` | UWP 10.0 |
| `UNITY_EMBEDDED_LINUX` | Embedded Linux |
| `UNITY_QNX` | QNX |
| `UNITY_FACEBOOK_INSTANT_GAMES` | Facebook Instant Games |

### Feature and Backend Defines

| Define | Meaning |
|--------|---------|
| `UNITY_ANALYTICS` | Analytics enabled |
| `UNITY_ASSERTIONS` | Assertions enabled |
| `UNITY_64` | 64-bit platform |
| `ENABLE_MONO` | Mono scripting backend |
| `ENABLE_IL2CPP` | IL2CPP scripting backend |
| `ENABLE_VR` | VR support enabled |
| `ENABLE_INPUT_SYSTEM` | New Input System enabled |
| `ENABLE_LEGACY_INPUT_MANAGER` | Legacy Input Manager enabled |
| `ENABLE_WINMD_SUPPORT` | WinMD support |
| `DEVELOPMENT_BUILD` | Development build |
| `UNITY_CLOUD_BUILD` | Cloud Build |

### .NET API Level Defines

| Define | API Level |
|--------|-----------|
| `NET_STANDARD_2_0` | .NET Standard 2.0 |
| `NET_STANDARD_2_1` | .NET Standard 2.1 |
| `NET_STANDARD` / `NETSTANDARD` | Any .NET Standard |
| `NETSTANDARD2_1` | .NET Standard 2.1 (C# define) |
| `NET_4_6` | .NET Framework |
| `NET_2_0` / `NET_LEGACY` | .NET 2.0 (legacy) |
| `CSHARP_7_3_OR_NEWER` | C# 7.3+ available |

### Version Defines

Format: `UNITY_X`, `UNITY_X_Y`, `UNITY_X_Y_Z`, `UNITY_X_Y_OR_NEWER`

Example for Unity 6000.0.33:
- `UNITY_6000`, `UNITY_6000_0`, `UNITY_6000_0_33`, `UNITY_6000_0_OR_NEWER`

## Mobile Optimization

### iOS

**Architecture**: ARM64 only (no ARMv7).

**Scripting Backend**: IL2CPP required for iOS (no Mono option).

**Player Settings** (Edit > Project Settings > Player > iOS):
- Bundle Identifier: `com.CompanyName.ProductName`
- Signing Team ID + Automatic Sign for Xcode
- Target minimum iOS version selectable
- Metal API Validation for debug shader issues
- Metal Write-Only Backbuffer for performance in non-default orientations
- Force hard shadows on Metal (point sampling for performance)
- Orientation: Portrait, Landscape, or Auto Rotation with allowed orientations
- Launch Screen: Default, Image, or Custom Storyboard
- Requires ARKit support restricts to iPhone 6s/iOS 11+

### Android

**Architectures**: ARMv7 and ARM64 (ARM64 requires IL2CPP).

**Player Settings** (Edit > Project Settings > Player > Android):
- Package Name: `com.YourCompanyName.YourProductName`
- Minimum API Level and Target API Level
- Graphics API: Auto (Vulkan first, GLES fallback), Vulkan, or OpenGL ES 3.x
- Split APKs by target architecture for smaller downloads on Google Play
- Keystore configuration for signing (custom keystore for production)
- Scripting Backend: Mono or IL2CPP
- API Compatibility: .NET Framework or .NET Standard 2.1
- Managed Stripping Level: Minimal to High

**Key Difference**: Android hardware capabilities vary significantly between models. Test across multiple devices.

### Mobile Optimization Tips

- Use ASTC texture compression (supported on both iOS and Android modern devices)
- Minimize draw calls via batching (static and dynamic)
- Use AssetBundles or Addressables for on-demand content
- Profile with Unity Profiler and platform-specific tools
- Reduce shader complexity on mobile GPUs

## WebGL Considerations

### Memory Management

- Unity heap implemented as WebAssembly Memory (resizable ArrayBuffer)
- Heap can expand up to **4 GB** (Maximum Memory Size in Player Settings)
- Asset data unpacked from `.data` file into virtual memory file system (Emscripten)
- Garbage collector only runs at end of each frame (no mid-frame collection)
- Available memory depends on device, OS, browser (32/64-bit), and tab isolation model

### Memory Optimization

Use `StringBuilder` instead of string concatenation in loops:

```csharp
// BAD: Creates ~15 GB temporary allocations for 100k iterations
string hugeString = "";
for (int i = 0; i < 100000; i++)
    hugeString += "foo";

// GOOD: Pre-allocated StringBuilder
var sb = new StringBuilder();
for (int i = 0; i < 10000; i++)
    sb.Append("foo");
```

Use `NativeArray<T>` for temporary allocations to bypass GC:

```csharp
using (var data = new NativeArray<byte>(size, Allocator.Temp))
{
    // Memory freed immediately upon scope exit
}
```

Use **AssetBundles** for asset loading (downloads directly into Unity heap without extra browser allocation).

Enable **Data Caching** (IndexedDB/Caching APIs) to reduce re-downloads.

### JavaScript Interop

Unity supports two JavaScript plug-in file types:
- **.jslib**: Define functions callable from C# code
- **.jspre**: Include existing JavaScript libraries

**Limitation**: Only ECMAScript 5 (ES5) syntax supported in .jslib and .jspre files. ES6 is not yet supported.

#### .jslib Plugin Example

```javascript
// Assets/Plugins/WebGL/MyPlugin.jslib
mergeInto(LibraryManager.library, {
    ShowAlert: function (message) {
        window.alert(UTF8ToString(message));
    },
});
```

#### C# Calling JavaScript

```csharp
using System.Runtime.InteropServices;
using UnityEngine;

public class WebGLBridge : MonoBehaviour
{
    [DllImport("__Internal")]
    private static extern void ShowAlert(string message);

    void Start()
    {
        #if UNITY_WEBGL && !UNITY_EDITOR
        ShowAlert("Hello from Unity!");
        #endif
    }
}
```

## IL2CPP vs Mono

### IL2CPP (Intermediate Language To C++)

IL2CPP is Unity's custom AOT scripting backend that converts C# to native code via C++.

**Conversion Pipeline**:
1. Roslyn compiler converts C# to .NET managed assemblies (DLLs)
2. Managed code stripping reduces application size
3. All managed assemblies convert to standard C++ code
4. C++ compiler generates platform-specific machine code
5. Creates executables, DLLs, APK/AAB, or app bundles

**Advantages**:
- Improved runtime performance over Mono
- Shorter application startup times
- Supported across all platforms
- Supports managed code debugging identically to Mono

**Disadvantages**:
- Significantly longer build times than Mono
- Increased final application size
- Cross-compilation generally unsupported (must build on target OS)
- Exception: Linux cross-compilation supported from any desktop platform

**Configuration**:
- Player Settings: Edit > Project Settings > Player > Configuration > Scripting Backend
- Scripting API: `PlayerSettings.SetScriptingBackend`

**Build Speed Optimization**:
- Exclude project folders from antimalware scans
- Use fastest available storage drives
- Select "Optimize for code size and build time" (trades runtime performance)
- Use Burst compiler alongside IL2CPP for compatible code

### Mono

- Faster build times (JIT compilation)
- Smaller build output
- Not available on all platforms (iOS requires IL2CPP)
- Less runtime performance than IL2CPP

### When to Choose

| Criteria | IL2CPP | Mono |
|----------|--------|------|
| iOS builds | Required | Not available |
| Android builds | Recommended for ARM64 | Available for ARMv7 |
| Build iteration speed | Slower | Faster |
| Runtime performance | Better | Good |
| Console platforms | Required | Not available |
| WebGL | Required | Not available |

## Addressables Overview

The Addressable Asset System (com.unity.addressables v2.9.1) enables referencing assets by address rather than direct paths.

### Key Concepts

- Mark any asset as "addressable" to generate a unique address callable from anywhere
- Supports loading from local or remote locations
- Uses asynchronous loading with automatic dependency resolution
- Replaces direct references, traditional asset bundles, and Resources folders
- Access via: Window > Asset Management > Addressables

### Basic Usage Pattern

```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class AddressableLoader : MonoBehaviour
{
    [SerializeField] private AssetReference prefabRef;

    async void Start()
    {
        AsyncOperationHandle<GameObject> handle =
            Addressables.InstantiateAsync(prefabRef);
        await handle.Task;

        if (handle.Status == AsyncOperationStatus.Succeeded)
        {
            Debug.Log("Asset loaded successfully");
        }
    }

    void OnDestroy()
    {
        // Always release when done
        prefabRef.ReleaseAsset();
    }
}
```

## Common Patterns

### Platform-Specific Code

```csharp
public class PlatformManager : MonoBehaviour
{
    void Start()
    {
        #if UNITY_IOS
        Application.targetFrameRate = 60;
        #elif UNITY_ANDROID
        Application.targetFrameRate = 60;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
        #elif UNITY_WEBGL
        // WebGL runs at browser refresh rate
        #elif UNITY_STANDALONE
        Application.targetFrameRate = -1; // Uncapped
        #endif
    }
}
```

### Runtime Platform Check

```csharp
void ConfigureForPlatform()
{
    switch (Application.platform)
    {
        case RuntimePlatform.IPhonePlayer:
            SetupMobileControls();
            break;
        case RuntimePlatform.Android:
            SetupMobileControls();
            break;
        case RuntimePlatform.WebGLPlayer:
            SetupWebControls();
            break;
        default:
            SetupDesktopControls();
            break;
    }
}
```

### Build Profile Scripting

```csharp
#if DEVELOPMENT_BUILD
    Debug.Log("Development build active");
#endif

#if ENABLE_IL2CPP
    // IL2CPP-specific code
#elif ENABLE_MONO
    // Mono-specific code
#endif
```

## Anti-Patterns

1. **Using Resources folder for everything** instead of Addressables. Resources folder loads all assets at startup, increasing memory usage and load times.

2. **Not using platform defines** and relying solely on runtime checks. Compile-time defines exclude unused code from builds entirely.

3. **String concatenation in WebGL loops**. GC only runs at frame end in WebGL, causing massive temporary allocations. Use `StringBuilder` or `NativeArray<T>`.

4. **Ignoring IL2CPP AOT restrictions**. Reflection-heavy code, `System.Reflection.Emit`, and runtime code generation will fail under IL2CPP. Design with AOT in mind.

5. **Shipping with Development Build enabled**. Development builds include Profiler overhead and debug symbols, increasing size and reducing performance.

6. **Not splitting APKs by architecture on Android**. Shipping a single fat APK with both ARMv7 and ARM64 wastes user bandwidth. Use Split APKs or App Bundles.

7. **Hardcoding platform paths**. Use `Application.persistentDataPath`, `Application.streamingAssetsPath`, and `Application.temporaryCachePath` for cross-platform file access.

8. **Not testing on actual devices**. Android hardware varies enormously. Emulators and simulators do not represent real performance characteristics.

## Key API Quick Reference

| API | Purpose |
|-----|---------|
| `Application.platform` | Runtime platform detection |
| `RuntimePlatform` enum | Platform constants for runtime checks |
| `SystemInfo.graphicsDeviceType` | Current graphics API (Vulkan, Metal, etc.) |
| `SystemInfo.supportsComputeShaders` | Check compute shader support |
| `PlayerSettings.SetScriptingBackend()` | Set IL2CPP or Mono via script |
| `Addressables.InstantiateAsync()` | Load and instantiate addressable asset |
| `Addressables.LoadAssetAsync<T>()` | Load addressable asset without instantiation |
| `AssetReference` | Serializable reference to an addressable asset |
| `Application.targetFrameRate` | Set target frame rate |
| `Screen.sleepTimeout` | Prevent screen dimming on mobile |
| `Application.persistentDataPath` | Platform-safe writable data path |

## Related Skills

- **unity-graphics** — Rendering pipelines, shaders, and visual effects
- **unity-packages-services** — Package Manager workflow and Unity Gaming Services

## Additional Resources

- [Platform-Specific Development](https://docs.unity3d.com/6000.3/Documentation/Manual/PlatformSpecific.html)
- [Build Profiles](https://docs.unity3d.com/6000.3/Documentation/Manual/build-profiles.html)
- [Scripting Symbol Reference](https://docs.unity3d.com/6000.3/Documentation/Manual/scripting-symbol-reference.html)
- [iOS Development](https://docs.unity3d.com/6000.3/Documentation/Manual/iphone.html)
- [Android Development](https://docs.unity3d.com/6000.3/Documentation/Manual/android.html)
- [WebGL Development](https://docs.unity3d.com/6000.3/Documentation/Manual/webgl.html)
- [IL2CPP Scripting Backend](https://docs.unity3d.com/6000.3/Documentation/Manual/scripting-backends-il2cpp.html)
- [Addressables Package](https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.addressables.html)
- [Build Settings](https://docs.unity3d.com/6000.3/Documentation/Manual/BuildSettings.html)
