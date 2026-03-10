---
name: unity-packages-services
description: >
  Unity 6 packages and services guide. Use when working with Package Manager, installing/updating packages, scoped registries, or Unity Gaming Services (Authentication, Cloud Save, Analytics, Leaderboards, Matchmaker). Covers essential packages list and version compatibility. Based on Unity 6.3 LTS documentation.
---

# Unity Packages and Services Skill

## Package Manager Workflow

The Package Manager window (accessed via **Window > Package Manager**) manages UPM packages, feature sets, and asset packages.

### Core Components

- **Navigation panel**: Select package contexts (Unity Registry, In Project, My Assets)
- **Search box**: Locate packages by name
- **Sort menu**: Sort by name or date
- **Filter menu**: Narrow results by category or status
- **Details panel**: View package info, version, dependencies, and changelog
- **Action buttons**: Install, remove, update, and customize packages

### Package States

- **Released**: Fully tested and verified for the current Unity version
- **Pre-release**: Available but not yet fully verified
- **Experimental**: Unstable, indicated by a warning badge
- **Built-in**: Core Unity features that can be toggled on/off to reduce build size
- **Deprecated**: No longer maintained

## Installing and Managing Packages

### Via Package Manager UI

1. Open **Window > Package Manager**
2. Select **Unity Registry** to browse available packages
3. Select a package and click **Install**
4. To update: select installed package, choose new version, click **Update**
5. To remove: select installed package, click **Remove**

### Via manifest.json

Edit `Packages/manifest.json` directly to add dependencies:

```json
{
    "dependencies": {
        "com.unity.addressables": "2.9.1",
        "com.unity.cinemachine": "3.1.0",
        "com.unity.inputsystem": "1.19.0"
    }
}
```

### Via Git URL

Add packages from Git repositories:

```json
{
    "dependencies": {
        "com.example.package": "https://github.com/user/repo.git#v1.0.0"
    }
}
```

Or via the Package Manager UI: click the **+** button > **Add package from git URL**.

### Package Customization

- **Copy to project**: The Manage dropdown allows copying UPM packages to project folders for modification
- **Mutable packages**: Local and embedded packages can have their manifests edited directly
- **Built-in toggle**: Disable unused built-in packages to reduce build size

## Scoped Registries

Scoped registries enable Package Manager to communicate with custom package registry servers, allowing access to multiple package collections simultaneously.

### Primary Use Case

Organizations use scoped registries to distribute custom packages internally.

### Configuration

Add to `Packages/manifest.json`:

```json
{
    "scopedRegistries": [
        {
            "name": "My Company Registry",
            "url": "https://npm.mycompany.com",
            "scopes": [
                "com.mycompany",
                "com.mycompany.tools"
            ]
        }
    ],
    "dependencies": {
        "com.mycompany.core-utils": "1.0.0"
    }
}
```

### Configuration Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | String | Display name shown in Package Manager UI |
| `url` | String | npm-compatible registry server endpoint |
| `scopes` | Array | Package namespaces to route to this registry |

### Scope Matching Rules

- Exact package name matches take priority
- Longer namespace matches override shorter ones
- Unmapped packages default to Unity's official registry
- **Wildcards and glob patterns are not supported**
- Scopes use reverse domain notation (`com.example`, not `@scope`)

### Registry Compatibility

The registry server must implement the `/-/v1/search` or `/-/all` endpoints. Not all npm registries are compatible.

### Authentication

For protected registries, configure credentials in your Package Manager user configuration file using npm authentication patterns.

## Essential Packages List

Unity 6.3 LTS ships with 133 released (verified) packages. See `references/common-packages.md` for the full categorized list with IDs and versions.

### Most-Used Packages (Quick Reference)

| Package | ID | Version |
|---------|----|---------|
| Input System | com.unity.inputsystem | 1.19 |
| Addressables | com.unity.addressables | 2.9 |
| Cinemachine | com.unity.cinemachine | 3.1 |
| Burst | com.unity.burst | 1.8 |
| Collections | com.unity.collections | 2.6 |
| Entities | com.unity.entities | 1.4 |
| Timeline | com.unity.timeline | 1.8 |
| Netcode for GameObjects | com.unity.netcode.gameobjects | 2.10 |
| Localization | com.unity.localization | 1.5 |
| ProBuilder | com.unity.probuilder | 6.0 |
| Visual Scripting | com.unity.visualscripting | 1.9 |

### Key UGS Packages

| Package | ID |
|---------|----|
| Authentication | com.unity.services.authentication |
| Cloud Save | com.unity.services.cloudsave |
| Analytics | com.unity.services.analytics |
| Cloud Code | com.unity.services.cloudcode |
| Economy | com.unity.services.economy |
| Leaderboards | com.unity.services.leaderboards |
| In-App Purchasing | com.unity.purchasing |
| Remote Config | com.unity.remote-config |

## Unity Gaming Services Overview

Unity Gaming Services (UGS) is a suite of backend services for live game operations. Services include Authentication, Cloud Save, Cloud Code, Analytics, Economy, Leaderboards, Friends, Multiplayer, Matchmaker, and more.

### Getting Started with UGS

1. Link your Unity project to a UGS project in **Edit > Project Settings > Services**
2. Install the required service packages via Package Manager
3. Initialize services in code before using them

```csharp
using Unity.Services.Core;
using UnityEngine;

public class ServicesInitializer : MonoBehaviour
{
    async void Start()
    {
        await UnityServices.InitializeAsync();
        Debug.Log("Unity Services initialized");
    }
}
```

## Authentication

The Authentication service provides player identity management. Install `com.unity.services.authentication`.

### Sign-In Methods

- **Anonymous**: No credentials required, auto-generates player ID
- **Platform-specific**: Steam, PlayStation, Xbox, Apple, Google Play, etc.
- **Custom authentication**: OAuth/OIDC integration
- **Unity Player Accounts**: Cross-platform identity

### Anonymous Sign-In

```csharp
using Unity.Services.Authentication;
using Unity.Services.Core;
using UnityEngine;

public class AuthManager : MonoBehaviour
{
    async void Start()
    {
        await UnityServices.InitializeAsync();

        AuthenticationService.Instance.SignedIn += () =>
        {
            Debug.Log($"Signed in. Player ID: {AuthenticationService.Instance.PlayerId}");
        };

        await AuthenticationService.Instance.SignInAnonymouslyAsync();
    }
}
```

### Session Management

- Sessions persist automatically across app restarts
- Access token refreshes automatically
- Player ID is consistent across sessions for the same device
- Link multiple sign-in methods to one player ID for cross-platform play

### Key API

| API | Purpose |
|-----|---------|
| `AuthenticationService.Instance.SignInAnonymouslyAsync()` | Anonymous sign-in |
| `AuthenticationService.Instance.PlayerId` | Get current player ID |
| `AuthenticationService.Instance.IsSignedIn` | Check sign-in status |
| `AuthenticationService.Instance.SignOut()` | Sign out current player |
| `AuthenticationService.Instance.AccessToken` | Get current access token |

## Cloud Save

Cloud Save persists player data and game state to the cloud. Install `com.unity.services.cloudsave`.

### Data Types

- **Player Data**: Per-player key-value storage (settings, progress, inventory)
- **Game Data**: Shared data across all players (leaderboard snapshots, game config)

### Saving and Loading Data

```csharp
using Unity.Services.CloudSave;
using Unity.Services.Core;
using Unity.Services.Authentication;
using UnityEngine;
using System.Collections.Generic;

public class CloudSaveManager : MonoBehaviour
{
    async void Start()
    {
        await UnityServices.InitializeAsync();
        await AuthenticationService.Instance.SignInAnonymouslyAsync();

        // Save data
        var data = new Dictionary<string, object>
        {
            { "playerLevel", 5 },
            { "playerName", "Hero" },
            { "highScore", 12500 }
        };
        await CloudSaveService.Instance.Data.Player.SaveAsync(data);
        Debug.Log("Data saved to cloud");

        // Load data
        var keys = new HashSet<string> { "playerLevel", "highScore" };
        var loadedData = await CloudSaveService.Instance.Data.Player.LoadAsync(keys);

        if (loadedData.TryGetValue("playerLevel", out var levelItem))
        {
            int level = levelItem.Value.GetAs<int>();
            Debug.Log($"Player level: {level}");
        }
    }
}
```

### Key API

| API | Purpose |
|-----|---------|
| `CloudSaveService.Instance.Data.Player.SaveAsync()` | Save player key-value data |
| `CloudSaveService.Instance.Data.Player.LoadAsync()` | Load player data by keys |
| `CloudSaveService.Instance.Data.Player.LoadAllAsync()` | Load all player data |
| `CloudSaveService.Instance.Data.Player.DeleteAsync()` | Delete specific keys |

## Analytics

Unity Analytics tracks player behavior and game events. Install `com.unity.services.analytics`.

### Event Types

- **Standard Events**: Pre-defined events (e.g., level completion, transaction)
- **Custom Events**: Developer-defined events with custom parameters

### Recording Events

```csharp
using Unity.Services.Analytics;
using Unity.Services.Core;
using UnityEngine;

public class AnalyticsManager : MonoBehaviour
{
    async void Start()
    {
        await UnityServices.InitializeAsync();
        AnalyticsService.Instance.StartDataCollection();
    }

    public void RecordLevelComplete(int level, float time)
    {
        var parameters = new Dictionary<string, object>
        {
            { "levelIndex", level },
            { "completionTime", time },
            { "livesRemaining", 3 }
        };
        AnalyticsService.Instance.CustomData("levelComplete", parameters);
    }

    public void RecordPurchase(string itemId, float price)
    {
        var parameters = new Dictionary<string, object>
        {
            { "itemId", itemId },
            { "price", price },
            { "currency", "USD" }
        };
        AnalyticsService.Instance.CustomData("itemPurchased", parameters);
    }
}
```

### Data Privacy

- Call `AnalyticsService.Instance.StartDataCollection()` after obtaining user consent
- Comply with GDPR, CCPA, and platform privacy requirements
- Use `AnalyticsService.Instance.StopDataCollection()` if user revokes consent

### Key API

| API | Purpose |
|-----|---------|
| `AnalyticsService.Instance.StartDataCollection()` | Begin collecting analytics data |
| `AnalyticsService.Instance.StopDataCollection()` | Stop collecting data |
| `AnalyticsService.Instance.CustomData()` | Record a custom event with parameters |
| `AnalyticsService.Instance.Flush()` | Force-send queued events |

## Common Patterns

### Service Initialization Pattern

```csharp
using Unity.Services.Core;
using Unity.Services.Authentication;
using UnityEngine;

public class GameBootstrap : MonoBehaviour
{
    async void Awake()
    {
        try
        {
            await UnityServices.InitializeAsync();
            await AuthenticationService.Instance.SignInAnonymouslyAsync();
            Debug.Log($"Player ID: {AuthenticationService.Instance.PlayerId}");

            // Now safe to use Cloud Save, Analytics, etc.
        }
        catch (ServicesInitializationException e)
        {
            Debug.LogError($"Services failed to initialize: {e.Message}");
        }
        catch (AuthenticationException e)
        {
            Debug.LogError($"Authentication failed: {e.Message}");
        }
    }
}
```

### Managing Packages via Script

```csharp
#if UNITY_EDITOR
using UnityEditor.PackageManager;

public static class PackageHelper
{
    // Install: Client.Add("com.unity.cinemachine@3.1.0");
    // Remove:  Client.Remove("com.unity.cinemachine");
    // List:    Client.List();  // Returns ListRequest, poll IsCompleted
}
#endif
```

## Anti-Patterns

1. **Not initializing `UnityServices` before using any service.** Always call `UnityServices.InitializeAsync()` first. All UGS services depend on this.

2. **Not authenticating before using Cloud Save or other player-bound services.** Authentication is required before accessing per-player data.

3. **Collecting analytics without user consent.** Call `StartDataCollection()` only after obtaining consent. Violating privacy regulations risks legal action and platform removal.

4. **Storing sensitive data in Cloud Save without encryption.** Cloud Save is key-value storage, not a secure vault. Encrypt sensitive data before saving.

5. **Hardcoding package versions in manifest.json without checking compatibility.** Always verify package versions are compatible with your Unity version. Use the Package Manager UI to check verified versions.

6. **Installing packages via git URL for production without pinning a version/tag.** Always specify a tag or commit hash (e.g., `#v1.0.0`) to prevent unexpected breaking changes.

7. **Not handling service errors gracefully.** UGS calls are async network operations. Always wrap in try/catch and handle offline scenarios.

8. **Using `Resources.Load` instead of Addressables for dynamic content.** Resources folder cannot be updated post-build. Addressables support remote content updates.

9. **Adding scoped registries with overly broad scopes.** Broad scopes like `com` will route many packages to your custom registry. Use specific scopes like `com.mycompany`.

## Key API Quick Reference

| API | Purpose |
|-----|---------|
| `UnityServices.InitializeAsync()` | Initialize all UGS services |
| `AuthenticationService.Instance` | Access authentication service |
| `CloudSaveService.Instance` | Access cloud save service |
| `AnalyticsService.Instance` | Access analytics service |
| `UnityEditor.PackageManager.Client.Add()` | Install a package via script |
| `UnityEditor.PackageManager.Client.List()` | List installed packages |
| `UnityEditor.PackageManager.Client.Remove()` | Remove a package via script |

## Related Skills

- **unity-foundations** — Core Unity concepts, project setup, and C# scripting basics
- **unity-platforms** — Platform targeting, build profiles, and platform-specific optimization

## Additional Resources

- [Packages Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/PackagesList.html)
- [Package Manager Window](https://docs.unity3d.com/6000.3/Documentation/Manual/upm-ui.html)
- [Scoped Registries](https://docs.unity3d.com/6000.3/Documentation/Manual/upm-scoped.html)
- [Released Packages List](https://docs.unity3d.com/6000.3/Documentation/Manual/pack-safe.html)
- [Unity Gaming Services](https://docs.unity.com/ugs/en-us/manual/overview/manual/unity-gaming-services-home)
- [Authentication](https://docs.unity.com/ugs/en-us/manual/authentication/manual/overview)
- [Cloud Save](https://docs.unity.com/ugs/en-us/manual/cloud-save/manual/overview)
- [Analytics](https://docs.unity.com/ugs/en-us/manual/analytics/manual/overview)
