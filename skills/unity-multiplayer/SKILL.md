---
name: unity-multiplayer
description: >
  Unity 6 multiplayer and networking guide. Use when building multiplayer games, working with Netcode for GameObjects, NetworkManager, NetworkObject, NetworkBehaviour, RPCs (ServerRpc, ClientRpc), NetworkVariables, or Unity multiplayer services (Relay, Lobby). Covers client-server architecture, state synchronization, and scene management. Based on Unity 6.3 LTS documentation.
---

# Unity Multiplayer & Networking

## Multiplayer Architecture Overview

Unity's multiplayer ecosystem comprises several layers:

| Layer | Package/Service | Purpose |
|-------|----------------|---------|
| High-Level | Netcode for GameObjects | GameObject-based networking logic |
| High-Level | Netcode for Entities | DOTS-based networking |
| Low-Level | Unity Transport (`com.unity.transport`) | UDP/WebSocket communication with optional reliability, ordering, fragmentation |
| Services | Relay | NAT traversal via cloud relay servers |
| Services | Lobby | Matchmaking and session discovery |
| Services | Sessions SDK | Player group management |
| Tools | Multiplayer Play Mode | Simulate up to 4 players in-editor |
| Tools | Multiplayer Tools | Analysis, debugging, testing utilities |

**Topology options:**
- **Client-Server (Dedicated):** Server has authority; clients send inputs, server validates
- **Client-Server (Listen/Host):** One player acts as both server and client
- **Distributed Authority:** Ownership-based authority distributed among clients

Use the **Multiplayer Center** (Window > Multiplayer > Multiplayer Center) to get package recommendations based on your game's needs.

## Netcode for GameObjects Setup

### Installation
Install `com.unity.netcode.gameobjects` (v2.10+) via Package Manager. This automatically pulls in `com.unity.transport`.

### NetworkManager Configuration
Add a `NetworkManager` component to a GameObject in your scene. It is the singleton entry point for all networking.

```csharp
using Unity.Netcode;

public class GameLauncher : MonoBehaviour
{
    public void StartAsHost()
    {
        NetworkManager.Singleton.StartHost();
    }

    public void StartAsServer()
    {
        NetworkManager.Singleton.StartServer();
    }

    public void StartAsClient()
    {
        NetworkManager.Singleton.StartClient();
    }

    public void Shutdown()
    {
        NetworkManager.Singleton.Shutdown();
    }
}
```

**Key NetworkManager properties:**
- `IsServer`, `IsClient`, `IsHost` -- execution context
- `ConnectedClients` -- dictionary of connected clients
- `ConnectedClientsIds` -- read-only list of client IDs
- `LocalClientId` -- local client's ID
- `SceneManager` -- `NetworkSceneManager` instance
- `SpawnManager` -- `NetworkSpawnManager` instance
- `NetworkConfig` -- project network configuration

**Key NetworkManager events:** `OnClientConnectedCallback`, `OnClientDisconnectCallback`, `OnConnectionEvent`, `OnServerStarted`/`OnServerStopped`, `OnClientStarted`/`OnClientStopped`, `OnTransportFailure`

## NetworkObject and NetworkBehaviour

### NetworkObject
Every networked GameObject needs a `NetworkObject` component. It provides identity, ownership, and visibility.

**Key properties:**
- `NetworkObjectId` (ulong) -- unique ID synchronized across network
- `IsSpawned` -- whether spawned on the network
- `OwnerClientId` -- client ID of current owner
- `IsOwner` -- true if local player owns this object
- `HasAuthority` -- true if local instance has authority

**Spawning (server-side only):**
```csharp
// Basic spawn
NetworkObject netObj = Instantiate(prefab).GetComponent<NetworkObject>();
netObj.Spawn();

// Spawn with specific owner
netObj.SpawnWithOwnership(clientId);

// Spawn as player object
netObj.SpawnAsPlayerObject(clientId);

// Despawn
netObj.Despawn(destroy: true);
```

**Ownership (server-side only):**
```csharp
netObj.ChangeOwnership(newClientId);
netObj.RemoveOwnership();
```

**Visibility:**
```csharp
netObj.NetworkShow(clientId);
netObj.NetworkHide(clientId);
bool visible = netObj.IsNetworkVisibleTo(clientId);
```

### NetworkBehaviour
All networked scripts inherit from `NetworkBehaviour` instead of `MonoBehaviour`.

**Lifecycle methods (in order):**
1. `OnNetworkPreSpawn(ref NetworkManager)` -- before any spawning
2. `OnNetworkSpawn()` -- after NetworkObject spawns; register handlers here
3. `OnNetworkPostSpawn()` -- after all sibling NetworkBehaviours spawn
4. `OnNetworkPreDespawn()` -- before despawn
5. `OnNetworkDespawn()` -- on despawn

**Ownership callbacks:**
- `OnGainedOwnership()` / `OnLostOwnership()`
- `OnOwnershipChanged(ulong previous, ulong current)` -- fires on all clients

```csharp
using Unity.Netcode;

public class PlayerController : NetworkBehaviour
{
    public override void OnNetworkSpawn()
    {
        if (IsOwner)
        {
            // Initialize local player controls
            EnableInput();
        }
    }

    void Update()
    {
        if (!IsOwner) return;
        // Only the owner processes input
        HandleMovement();
    }

    public override void OnNetworkDespawn()
    {
        // Cleanup
    }
}
```

**Status checks:** `IsServer`, `IsClient`, `IsHost`, `IsOwner`, `IsSpawned`, `IsLocalPlayer`, `HasAuthority`

## NetworkVariables

`NetworkVariable<T>` synchronizes state from server to all clients automatically. Type `T` must be `unmanaged` (primitives, unmanaged structs).

```csharp
public class PlayerHealth : NetworkBehaviour
{
    public NetworkVariable<int> Health = new NetworkVariable<int>(
        value: 100,
        readPerm: NetworkVariableReadPermission.Everyone,
        writePerm: NetworkVariableWritePermission.Server
    );

    public override void OnNetworkSpawn()
    {
        Health.OnValueChanged += OnHealthChanged;
    }

    public override void OnNetworkDespawn()
    {
        Health.OnValueChanged -= OnHealthChanged;
    }

    private void OnHealthChanged(int oldValue, int newValue)
    {
        Debug.Log($"Health changed: {oldValue} -> {newValue}");
        UpdateHealthUI(newValue);
    }

    // Server-side only (due to WritePerm.Server)
    public void TakeDamage(int amount)
    {
        if (!IsServer) return;
        Health.Value -= amount;
    }
}
```

**Write permissions:**
- `NetworkVariableWritePermission.Server` (default) -- only server can write
- `NetworkVariableWritePermission.Owner` -- only owner can write

**NetworkList<T>** -- synchronized list (T must be `unmanaged` + `IEquatable<T>`):
```csharp
public class Inventory : NetworkBehaviour
{
    public NetworkList<int> Items;

    void Awake()
    {
        Items = new NetworkList<int>();
    }

    public override void OnNetworkSpawn()
    {
        Items.OnListChanged += OnItemsChanged;
    }

    private void OnItemsChanged(NetworkListEvent<int> changeEvent)
    {
        Debug.Log($"List changed: {changeEvent.Type}");
    }
}
```

## RPCs (ServerRpc, ClientRpc)

RPCs are remote procedure calls between server and clients. Methods must be in a `NetworkBehaviour` and use the `[Rpc]` attribute with a `SendTo` target.

### Unified Rpc Attribute (v2.x)
```csharp
public class CombatSystem : NetworkBehaviour
{
    // Server executes this when any client calls it
    [Rpc(SendTo.Server)]
    void AttackRpc(int targetId, RpcParams rpcParams = default)
    {
        ulong senderId = rpcParams.Receive.SenderClientId;
        ProcessAttack(senderId, targetId);
    }

    // All clients (and host) execute this
    [Rpc(SendTo.ClientsAndHost)]
    void ShowDamageEffectRpc(Vector3 position, int damage)
    {
        SpawnDamagePopup(position, damage);
    }

    // Only the owner executes this
    [Rpc(SendTo.Owner)]
    void NotifyOwnerRpc(string message)
    {
        Debug.Log(message);
    }

    // Everyone including sender
    [Rpc(SendTo.Everyone)]
    void PlaySoundRpc(int soundId)
    {
        AudioManager.Play(soundId);
    }
}
```

### SendTo Targets

| Target | Description |
|--------|-------------|
| `Server` | Executes on server; locally if called on server |
| `NotServer` | All clients except server (excludes host) |
| `Owner` | Object's owner only |
| `NotOwner` | Everyone except owner |
| `Authority` | Server in client-server; owner in distributed authority |
| `NotAuthority` | All non-authority instances |
| `ClientsAndHost` | All clients including host |
| `Everyone` | All instances on the observer list |
| `Me` | Local execution only |
| `NotMe` | Everyone except sender |
| `SpecifiedInParams` | Target set at runtime via `RpcSendParams` |

### Legacy Attributes (still supported)
```csharp
[ServerRpc]
void RequestSpawnServerRpc(ServerRpcParams rpcParams = default)
{
    // Runs on server; only owner can call by default
}

[ClientRpc]
void UpdateUIClientRpc(int score)
{
    // Runs on all clients
}
```

## Connection Approval

Use `ConnectionApprovalCallback` on `NetworkManager` to validate connecting clients.

```csharp
// Server-side: register approval callback
NetworkManager.Singleton.ConnectionApprovalCallback = (request, response) =>
{
    string password = System.Text.Encoding.UTF8.GetString(request.Payload);
    response.Approved = (password == "secret");
    response.CreatePlayerObject = response.Approved;
    // Optionally set: response.PlayerPrefabHash, response.Position, response.Rotation
    if (!response.Approved) response.Reason = "Invalid password";
    response.Pending = false; // Signal decision is made
};

// Client-side: set payload before connecting
NetworkManager.Singleton.NetworkConfig.ConnectionData =
    System.Text.Encoding.UTF8.GetBytes("secret");
NetworkManager.Singleton.StartClient();
```

## Scene Management

`NetworkSceneManager` (accessed via `NetworkManager.Singleton.SceneManager`) handles synchronized scene loading.

```csharp
public class GameSceneManager : NetworkBehaviour
{
    public void LoadGameScene()
    {
        if (!IsServer) return;
        // Server-only: loads scene on all clients
        NetworkManager.Singleton.SceneManager.LoadScene("GameScene", LoadSceneMode.Single);
    }

    public void LoadAdditiveScene()
    {
        if (!IsServer) return;
        NetworkManager.Singleton.SceneManager.LoadScene("Arena", LoadSceneMode.Additive);
    }

    public override void OnNetworkSpawn()
    {
        NetworkManager.Singleton.SceneManager.OnSceneEvent += OnSceneEvent;
    }

    void OnSceneEvent(SceneEvent sceneEvent)
    {
        switch (sceneEvent.SceneEventType)
        {
            case SceneEventType.LoadComplete:
                Debug.Log($"Client {sceneEvent.ClientId} loaded {sceneEvent.SceneName}");
                break;
            case SceneEventType.LoadEventCompleted:
                Debug.Log($"All clients loaded {sceneEvent.SceneName}");
                break;
            case SceneEventType.SynchronizeComplete:
                Debug.Log($"Client {sceneEvent.ClientId} fully synchronized");
                break;
        }
    }
}
```

**Scene event types:** `OnLoad`, `OnUnload`, `OnSynchronize`, `OnLoadComplete`, `OnUnloadComplete`, `OnLoadEventCompleted`, `OnUnloadEventCompleted`, `OnSynchronizeComplete`

**Important:** Do NOT start new scene events within scene event callbacks.

## Unity Multiplayer Services (Relay, Lobby)

> Full integration examples in `references/transport-layer.md`

### Unity Relay
Relay provides NAT punchthrough via cloud relay servers (no port forwarding needed). Requires UGS authentication.

**Host flow:** Create allocation, get join code, configure transport, start host.
**Client flow:** Join allocation with code, configure transport, start client.

```csharp
// Host: create relay and start
Allocation allocation = await RelayService.Instance.CreateAllocationAsync(maxPlayers);
string joinCode = await RelayService.Instance.GetJoinCodeAsync(allocation.AllocationId);
transport.SetRelayServerData(allocation.ToRelayServerData("dtls")); // "dtls" = encrypted UDP
NetworkManager.Singleton.StartHost();

// Client: join relay and connect
JoinAllocation join = await RelayService.Instance.JoinAllocationAsync(joinCode);
transport.SetRelayServerData(join.ToRelayServerData("dtls"));
NetworkManager.Singleton.StartClient();
```

### Unity Lobby
Lobby provides session discovery and matchmaking. Store the Relay join code in lobby data.

```csharp
// Create lobby with relay join code
_lobby = await LobbyService.Instance.CreateLobbyAsync(name, maxPlayers, new CreateLobbyOptions {
    Data = new Dictionary<string, DataObject> {
        { "JoinCode", new DataObject(DataObject.VisibilityOptions.Member, relayJoinCode) }
    }
});

// Query available lobbies
QueryResponse response = await Lobbies.Instance.QueryLobbiesAsync(new QueryLobbiesOptions {
    Filters = new List<QueryFilter> {
        new QueryFilter(QueryFilter.FieldOptions.AvailableSlots, "0", QueryFilter.OpOptions.GT)
    }
});

// Join and extract relay code
Lobby lobby = await LobbyService.Instance.JoinLobbyByIdAsync(lobbyId);
string joinCode = lobby.Data["JoinCode"].Value;

// IMPORTANT: Send heartbeats every 15s or lobby expires
await LobbyService.Instance.SendHeartbeatPingAsync(lobby.Id);
```

## Common Patterns

### Player Spawning with Custom Prefab (Server-Side)
```csharp
// In a NetworkBehaviour on the server:
NetworkManager.Singleton.OnClientConnectedCallback += (ulong clientId) => {
    GameObject player = Instantiate(playerPrefab);
    player.GetComponent<NetworkObject>().SpawnAsPlayerObject(clientId);
};
```

### Owner-Authoritative Movement
```csharp
public class PlayerMovement : NetworkBehaviour
{
    public NetworkVariable<Vector3> Position = new(writePerm: NetworkVariableWritePermission.Owner);
    void Update()
    {
        if (!IsOwner) return;
        // Note: Uses legacy Input for brevity. See unity-input for the new Input System.
        Vector3 move = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));
        transform.position += move * Time.deltaTime * 5f;
        Position.Value = transform.position;
    }
}
```

### Server-Authoritative with Input RPCs
```csharp
public class ServerAuthMovement : NetworkBehaviour
{
    [Rpc(SendTo.Server)]
    void MoveRpc(Vector3 input) { transform.position += input * Time.deltaTime * 5f; }
    void Update()
    {
        if (!IsOwner) return;
        MoveRpc(new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"))); // legacy Input; see unity-input
    }
}
```

## Anti-Patterns

1. **Writing to NetworkVariable without authority** -- Only the server (or owner with `WritePerm.Owner`) can write. Client writes are silently ignored.

2. **Forgetting `IsOwner` checks in Update** -- Without owner checks, all clients run input logic, causing conflicting state.

3. **Using `Instantiate` without `Spawn`** -- Objects created with `Instantiate` alone are local-only. Always call `Spawn()` on the `NetworkObject` for network visibility.

4. **Spawning from client code** -- Only the server can spawn NetworkObjects. Clients must send an RPC to request spawning.

5. **Heavy data in RPCs instead of NetworkVariables** -- RPCs are fire-and-forget; late joiners miss them. Use NetworkVariables for persistent state.
6. **Not unsubscribing from OnValueChanged** -- Subscribe in `OnNetworkSpawn`, unsubscribe in `OnNetworkDespawn` to prevent leaks.

7. **Starting scene events inside scene event callbacks** -- `NetworkSceneManager` forbids this; causes undefined behavior.
8. **Not sending Lobby heartbeats** -- Lobbies expire without periodic `SendHeartbeatPingAsync` calls (every 15-30 seconds).

9. **Using `NetworkVariable` for frequent small updates** -- For high-frequency data (position), prefer `NetworkTransform` or custom serialization.
10. **Calling RPCs before `OnNetworkSpawn`** -- RPCs require the NetworkObject to be spawned. Defer to `OnNetworkSpawn`.

## Key API Quick Reference

| Class | Key Members |
|-------|-------------|
| `NetworkManager` | `StartHost()`, `StartServer()`, `StartClient()`, `Shutdown()`, `Singleton`, `ConnectedClients`, `LocalClientId`, `SceneManager`, `ConnectionApprovalCallback` |
| `NetworkObject` | `Spawn()`, `SpawnWithOwnership()`, `SpawnAsPlayerObject()`, `Despawn()`, `ChangeOwnership()`, `NetworkShow()`, `NetworkHide()`, `NetworkObjectId`, `OwnerClientId`, `IsOwner`, `HasAuthority` |
| `NetworkBehaviour` | `OnNetworkSpawn()`, `OnNetworkDespawn()`, `OnGainedOwnership()`, `OnLostOwnership()`, `IsServer`, `IsClient`, `IsHost`, `IsOwner`, `IsSpawned`, `HasAuthority`, `RpcTarget` |
| `NetworkVariable<T>` | `.Value`, `OnValueChanged`, `ReadPerm`, `WritePerm`, `CheckDirtyState()` |
| `NetworkList<T>` | `Add()`, `Remove()`, `Insert()`, `Clear()`, `Count`, `OnListChanged` |
| `NetworkSceneManager` | `LoadScene()`, `UnloadScene()`, `OnSceneEvent` |
| `[Rpc(SendTo.X)]` | `Server`, `Owner`, `NotOwner`, `ClientsAndHost`, `Everyone`, `NotMe`, `Authority`, `SpecifiedInParams` |

## Related Skills

- **unity-foundations** -- Core Unity concepts, GameObjects, components, scene hierarchy
- **unity-scripting** -- C# scripting, MonoBehaviour lifecycle, coroutines
- **unity-physics** -- Physics systems; use `NetworkRigidbody` for synced physics

## Additional Resources

- [Unity 6.3 Multiplayer Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/multiplayer.html)
- [Netcode for GameObjects 2.10 API](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.10/)
- [Unity Transport 2.x](https://docs.unity3d.com/Packages/com.unity.transport@2.5/manual/index.html)
- [Unity Relay Documentation](https://docs.unity.com/ugs/en-us/manual/relay/manual/introduction)
- [Unity Lobby Documentation](https://docs.unity.com/ugs/en-us/manual/lobby/manual/unity-lobby-service)
- [Boss Room Sample](https://github.com/Unity-Technologies/com.unity.multiplayer.samples.coop)
