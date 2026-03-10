# Platform Scripting Defines Reference

Complete list of Unity 6 platform-dependent compilation symbols.

Source: [Unity 6.3 Scripting Symbol Reference](https://docs.unity3d.com/6000.3/Documentation/Manual/scripting-symbol-reference.html)

## Platform Defines

### Editor

| Symbol | When Defined |
|--------|-------------|
| `UNITY_EDITOR` | Code running in any Unity Editor |
| `UNITY_EDITOR_WIN` | Windows Editor |
| `UNITY_EDITOR_OSX` | macOS Editor |
| `UNITY_EDITOR_LINUX` | Linux Editor |

### Standalone / Desktop

| Symbol | When Defined |
|--------|-------------|
| `UNITY_STANDALONE` | Any Standalone platform (Windows, macOS, Linux) |
| `UNITY_STANDALONE_WIN` | Windows Standalone Player |
| `UNITY_STANDALONE_OSX` | macOS Standalone Player |
| `UNITY_STANDALONE_LINUX` | Linux Standalone Player |

### Mobile

| Symbol | When Defined |
|--------|-------------|
| `UNITY_IOS` | iOS platform |
| `UNITY_ANDROID` | Android platform |
| `UNITY_TVOS` | tvOS platform |
| `UNITY_VISIONOS` | visionOS platform |

### Web and UWP

| Symbol | When Defined |
|--------|-------------|
| `UNITY_WEBGL` | WebGL platform |
| `UNITY_WSA` | Universal Windows Platform (UWP) |
| `UNITY_WSA_10_0` | UWP version 10.0 |
| `UNITY_FACEBOOK_INSTANT_GAMES` | Facebook Instant Games target |

### Server and Embedded

| Symbol | When Defined |
|--------|-------------|
| `UNITY_SERVER` | Dedicated Server build |
| `UNITY_EMBEDDED_LINUX` | Embedded Linux platform |
| `UNITY_QNX` | QNX platform |

## Feature Defines

| Symbol | When Defined |
|--------|-------------|
| `UNITY_ANALYTICS` | Analytics is enabled |
| `UNITY_ASSERTIONS` | Assertions API is available |
| `UNITY_64` | 64-bit architecture |
| `ENABLE_VR` | VR support is enabled in Player Settings |
| `ENABLE_WINMD_SUPPORT` | Windows Runtime (.winmd) support |
| `ENABLE_INPUT_SYSTEM` | New Input System package is enabled |
| `ENABLE_LEGACY_INPUT_MANAGER` | Legacy Input Manager is enabled |

## Scripting Backend Defines

| Symbol | When Defined |
|--------|-------------|
| `ENABLE_MONO` | Mono scripting backend active |
| `ENABLE_IL2CPP` | IL2CPP scripting backend active |

## .NET API Compatibility Defines

| Symbol | When Defined |
|--------|-------------|
| `NET_STANDARD_2_0` | .NET Standard 2.0 API compatibility |
| `NET_STANDARD_2_1` | .NET Standard 2.1 API compatibility |
| `NET_STANDARD` | Any .NET Standard profile |
| `NETSTANDARD` | Any .NET Standard (C# compiler define) |
| `NETSTANDARD2_1` | .NET Standard 2.1 (C# compiler define) |
| `NET_4_6` | .NET Framework API compatibility |
| `NET_2_0` | .NET 2.0 API compatibility (legacy) |
| `NET_2_0_SUBSET` | .NET 2.0 Subset (legacy) |
| `NET_LEGACY` | Legacy .NET API |
| `CSHARP_7_3_OR_NEWER` | C# language version 7.3 or newer available |

## Build Configuration Defines

| Symbol | When Defined |
|--------|-------------|
| `DEVELOPMENT_BUILD` | Development Build checkbox enabled |
| `UNITY_CLOUD_BUILD` | Build is running on Unity Cloud Build |

## Version Defines

Unity defines version symbols in the following formats:

- `UNITY_X` (major version)
- `UNITY_X_Y` (major.minor)
- `UNITY_X_Y_Z` (major.minor.patch)
- `UNITY_X_Y_OR_NEWER` (version or newer)

**Example** for Unity 6000.0.33:
- `UNITY_6000`
- `UNITY_6000_0`
- `UNITY_6000_0_33`
- `UNITY_6000_0_OR_NEWER`

## Conditional Compilation Patterns

### Basic Platform Check

```csharp
#if UNITY_IOS
    // iOS-only code
#elif UNITY_ANDROID
    // Android-only code
#elif UNITY_WEBGL
    // WebGL-only code
#else
    // All other platforms
#endif
```

### Editor vs Player

```csharp
#if UNITY_EDITOR
    Debug.Log("Running in Editor");
#else
    Debug.Log("Running in Player build");
#endif
```

### Combining Defines

```csharp
// Mobile platforms
#if UNITY_IOS || UNITY_ANDROID
    SetupMobileUI();
#endif

// Editor on macOS only
#if UNITY_EDITOR_OSX
    SetupMacEditorTools();
#endif

// Development builds only
#if DEVELOPMENT_BUILD && UNITY_ANDROID
    EnableAndroidDebugOverlay();
#endif
```

### Scripting Backend Check

```csharp
#if ENABLE_IL2CPP
    // AOT-safe code path
    // Avoid System.Reflection.Emit
#elif ENABLE_MONO
    // JIT-compatible code, dynamic code generation OK
#endif
```

### Version-Gated Features

```csharp
#if UNITY_6000_0_OR_NEWER
    // Use Unity 6+ APIs
#else
    // Fallback for older versions
#endif
```

### Input System Check

```csharp
#if ENABLE_INPUT_SYSTEM
    // New Input System code
    var action = new InputAction("Jump", binding: "<Keyboard>/space");
#elif ENABLE_LEGACY_INPUT_MANAGER
    // Legacy Input code
    if (Input.GetKeyDown(KeyCode.Space)) { }
#endif
```

### Custom Scripting Defines

You can add custom defines per Build Profile in Player Settings > Scripting Define Symbols. These allow feature toggling without changing code:

```csharp
// Define "PREMIUM_VERSION" in scripting define symbols
#if PREMIUM_VERSION
    UnlockAllLevels();
#else
    ShowUpgradePrompt();
#endif
```
