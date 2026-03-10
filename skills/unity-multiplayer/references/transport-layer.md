# Transport Layer, Unity Relay & Lobby Service

> Sources:
> - [Unity Transport 2.x Docs](https://docs.unity3d.com/Packages/com.unity.transport@2.5/manual/index.html)
> - [Unity Relay Docs](https://docs.unity.com/ugs/en-us/manual/relay/manual/introduction)
> - [Unity Lobby Docs](https://docs.unity.com/ugs/en-us/manual/lobby/manual/unity-lobby-service)

## Unity Transport Overview

Unity Transport (`com.unity.transport`) is the low-level networking library underlying Netcode for GameObjects. It provides:

- **Connection-based abstraction** over UDP sockets and WebSockets
- **Optional pipelines** for reliability, packet ordering, and packet fragmentation
- **Encryption** support for both UDP and WebSocket protocols
- **All Unity platforms** supported; WebGL limited to WebSocket client mode

### Version Compatibility

| Netcode Version | Transport Version | Unity Editor |
|-----------------|-------------------|-------------|
| NGO 2.x+ | Transport 2.x | Unity 6 / 2023.1+ |
| NGO 1.2-1.x | Transport 1.x | 2021 LTS - 2022 LTS |

Transport 2.x is installed automatically with Netcode for GameObjects.

## UnityTransport Component

The `UnityTransport` component is the bridge between Netcode for GameObjects and the transport layer. Add it to the same GameObject as `NetworkManager`.

### Basic Configuration

```csharp
using Unity.Netcode.Transports.UTP;

public class TransportConfig : MonoBehaviour
{
    void ConfigureTransport()
    {
        var transport = NetworkManager.Singleton.GetComponent<UnityTransport>();

        // Direct connection settings
        transport.ConnectionData.Address = "127.0.0.1";
        transport.ConnectionData.Port = 7777;
        transport.ConnectionData.ServerListenAddress = "0.0.0.0";
    }
}
```

### Inspector Settings

| Setting | Description |
|---------|-------------|
| Protocol Type | UDP (default) or WebSockets |
| Address | Server IP address |
| Port | Server port (default: 7777) |
| Server Listen Address | Bind address for server (0.0.0.0 for all interfaces) |
| Max Connect Attempts | Connection retry count |
| Connect Timeout (ms) | Time between connection attempts |
| Disconnect Timeout (ms) | Time before a silent peer is considered disconnected |
| Heartbeat Timeout (ms) | Keep-alive interval |

## Unity Relay Integration

Unity Relay provides NAT traversal using cloud-hosted relay servers. Players connect through the relay instead of directly, eliminating the need for port forwarding.

### Requirements

- Unity Gaming Services (UGS) project linked in Project Settings
- Packages: `com.unity.services.relay`, `com.unity.services.authentication`, `com.unity.services.core`
- `UnityTransport` component on NetworkManager

### Complete Relay Host + Client Flow

```csharp
using System.Threading.Tasks;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Core;
using Unity.Services.Authentication;
using Unity.Services.Relay;
using Unity.Services.Relay.Models;

public class RelayNetworkManager : MonoBehaviour
{
    private string _joinCode;

    async void Start()
    {
        // Step 1: Initialize UGS and authenticate
        await UnityServices.InitializeAsync();
        if (!AuthenticationService.Instance.IsSignedIn)
        {
            await AuthenticationService.Instance.SignInAnonymouslyAsync();
        }
        Debug.Log($"Signed in as: {AuthenticationService.Instance.PlayerId}");
    }

    /// <summary>
    /// Host creates a relay allocation and starts hosting.
    /// </summary>
    public async Task<string> StartHostWithRelay(int maxPlayers = 4)
    {
        try
        {
            // Step 2: Create relay allocation (maxPlayers excludes host)
            Allocation allocation = await RelayService.Instance.CreateAllocationAsync(maxPlayers);

            // Step 3: Get a join code to share with clients
            _joinCode = await RelayService.Instance.GetJoinCodeAsync(allocation.AllocationId);
            Debug.Log($"Relay join code: {_joinCode}");

            // Step 4: Configure transport with relay data
            var transport = NetworkManager.Singleton.GetComponent<UnityTransport>();
            // "dtls" for encrypted UDP; use "wss" for encrypted WebSocket
            transport.SetRelayServerData(allocation.ToRelayServerData("dtls"));

            // Step 5: Start host
            NetworkManager.Singleton.StartHost();
            return _joinCode;
        }
        catch (RelayServiceException e)
        {
            Debug.LogError($"Relay host failed: {e.Message}");
            return null;
        }
    }

    /// <summary>
    /// Client joins an existing relay session using a join code.
    /// </summary>
    public async Task<bool> JoinWithRelay(string joinCode)
    {
        try
        {
            // Step 2: Join allocation using the code
            JoinAllocation joinAllocation = await RelayService.Instance.JoinAllocationAsync(joinCode);

            // Step 3: Configure transport
            var transport = NetworkManager.Singleton.GetComponent<UnityTransport>();
            transport.SetRelayServerData(joinAllocation.ToRelayServerData("dtls"));

            // Step 4: Start client
            return NetworkManager.Singleton.StartClient();
        }
        catch (RelayServiceException e)
        {
            Debug.LogError($"Relay join failed: {e.Message}");
            return false;
        }
    }
}
```

### Relay Connection Types

| Protocol String | Transport | Encryption |
|----------------|-----------|------------|
| `"dtls"` | UDP | Encrypted (recommended) |
| `"udp"` | UDP | Unencrypted |
| `"wss"` | WebSocket | Encrypted (required for WebGL) |
| `"ws"` | WebSocket | Unencrypted |

### Key Relay Concepts

- **Allocation:** A relay server reservation. The host creates it; capacity is set at creation time.
- **Join Code:** A short string (e.g., "ABCD1234") generated from an allocation. Share it with clients to connect.
- **Relay Region:** Allocations are created in the closest region by default. You can specify a region for geographic targeting.
- **DTLS Encryption:** Default and recommended. Encrypts all traffic between clients and the relay server.

## Unity Lobby Service

Lobby provides matchmaking and session discovery. Players create, search, and join lobbies before connecting through Relay.

### Requirements

- Package: `com.unity.services.lobby`
- UGS authentication (same as Relay)

### Creating a Lobby

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;
using Unity.Services.Lobbies;
using Unity.Services.Lobbies.Models;

public class LobbyManager : MonoBehaviour
{
    private Lobby _hostLobby;
    private float _heartbeatTimer;
    private const float HEARTBEAT_INTERVAL = 15f;

    /// <summary>
    /// Create a new lobby with custom data.
    /// </summary>
    public async Task<Lobby> CreateLobby(string lobbyName, int maxPlayers, string relayJoinCode)
    {
        var options = new CreateLobbyOptions
        {
            IsPrivate = false,
            Data = new Dictionary<string, DataObject>
            {
                // Public data visible in lobby queries
                {
                    "GameMode",
                    new DataObject(DataObject.VisibilityOptions.Public, "TeamDeathmatch")
                },
                {
                    "Map",
                    new DataObject(DataObject.VisibilityOptions.Public, "Arena01")
                },
                // Store relay join code so joiners can connect
                {
                    "RelayJoinCode",
                    new DataObject(DataObject.VisibilityOptions.Member, relayJoinCode)
                }
            },
            Player = new Player
            {
                Data = new Dictionary<string, PlayerDataObject>
                {
                    {
                        "PlayerName",
                        new PlayerDataObject(PlayerDataObject.VisibilityOptions.Member, "HostPlayer")
                    }
                }
            }
        };

        _hostLobby = await LobbyService.Instance.CreateLobbyAsync(lobbyName, maxPlayers, options);
        Debug.Log($"Created lobby: {_hostLobby.Name} ({_hostLobby.Id})");
        return _hostLobby;
    }
}
```

### Lobby Heartbeat (Required)

Lobbies expire if the host does not send periodic heartbeats:

```csharp
void Update()
{
    HandleLobbyHeartbeat();
}

async void HandleLobbyHeartbeat()
{
    if (_hostLobby == null) return;

    _heartbeatTimer -= Time.deltaTime;
    if (_heartbeatTimer <= 0f)
    {
        _heartbeatTimer = HEARTBEAT_INTERVAL;
        await LobbyService.Instance.SendHeartbeatPingAsync(_hostLobby.Id);
    }
}
```

### Querying Lobbies

```csharp
public async Task<List<Lobby>> FindLobbies()
{
    var options = new QueryLobbiesOptions
    {
        // Only show lobbies with available slots
        Filters = new List<QueryFilter>
        {
            new QueryFilter(
                field: QueryFilter.FieldOptions.AvailableSlots,
                value: "0",
                op: QueryFilter.OpOptions.GT
            )
        },
        // Filter by custom data
        // new QueryFilter(QueryFilter.FieldOptions.S1, "TeamDeathmatch", QueryFilter.OpOptions.EQ)

        Order = new List<QueryOrder>
        {
            new QueryOrder(asc: false, field: QueryOrder.FieldOptions.Created)
        },
        Count = 25
    };

    QueryResponse response = await Lobbies.Instance.QueryLobbiesAsync(options);
    return response.Results;
}
```

### Joining a Lobby

```csharp
// Join by lobby ID (from query results)
public async Task<Lobby> JoinLobbyById(string lobbyId)
{
    var options = new JoinLobbyByIdOptions
    {
        Player = new Player
        {
            Data = new Dictionary<string, PlayerDataObject>
            {
                { "PlayerName", new PlayerDataObject(PlayerDataObject.VisibilityOptions.Member, "JoiningPlayer") }
            }
        }
    };

    Lobby lobby = await LobbyService.Instance.JoinLobbyByIdAsync(lobbyId, options);

    // Extract relay join code and connect
    string relayCode = lobby.Data["RelayJoinCode"].Value;
    // Use relayCode with RelayNetworkManager.JoinWithRelay()

    return lobby;
}

// Join by lobby code (private lobbies)
public async Task<Lobby> JoinLobbyByCode(string lobbyCode)
{
    return await LobbyService.Instance.JoinLobbyByCodeAsync(lobbyCode);
}

// Quick join (auto-match to first available)
public async Task<Lobby> QuickJoin()
{
    var options = new QuickJoinLobbyOptions
    {
        Filter = new List<QueryFilter>
        {
            new QueryFilter(QueryFilter.FieldOptions.AvailableSlots, "0", QueryFilter.OpOptions.GT)
        }
    };

    return await LobbyService.Instance.QuickJoinLobbyAsync(options);
}
```

### Lobby Data Visibility

| Visibility | Who Can See |
|------------|-------------|
| `Public` | Anyone querying lobbies |
| `Member` | Only players in the lobby |
| `Private` | Only the lobby host |

### Polling for Lobby Updates

```csharp
private float _pollTimer;
private const float POLL_INTERVAL = 2f;

async void PollForLobbyUpdates()
{
    if (_currentLobby == null) return;

    _pollTimer -= Time.deltaTime;
    if (_pollTimer <= 0f)
    {
        _pollTimer = POLL_INTERVAL;
        _currentLobby = await LobbyService.Instance.GetLobbyAsync(_currentLobby.Id);
        // Update UI with current player list, lobby data, etc.
    }
}
```

### Leaving and Deleting Lobbies

```csharp
// Player leaves
public async Task LeaveLobby(string lobbyId, string playerId)
{
    await LobbyService.Instance.RemovePlayerAsync(lobbyId, playerId);
}

// Host deletes lobby
public async Task DeleteLobby(string lobbyId)
{
    await LobbyService.Instance.DeleteLobbyAsync(lobbyId);
}
```

## Complete Relay + Lobby Integration Pattern

This is the typical flow for a multiplayer game session:

```csharp
using System.Threading.Tasks;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Core;
using Unity.Services.Authentication;
using Unity.Services.Relay;
using Unity.Services.Relay.Models;
using Unity.Services.Lobbies;
using Unity.Services.Lobbies.Models;
using System.Collections.Generic;

public class MultiplayerSessionManager : MonoBehaviour
{
    private Lobby _lobby;
    private float _heartbeatTimer;

    async void Start()
    {
        await UnityServices.InitializeAsync();
        await AuthenticationService.Instance.SignInAnonymouslyAsync();
    }

    // ---- HOST FLOW ----
    public async Task HostGame(string lobbyName, int maxPlayers)
    {
        // 1. Create Relay allocation
        Allocation allocation = await RelayService.Instance.CreateAllocationAsync(maxPlayers - 1);
        string joinCode = await RelayService.Instance.GetJoinCodeAsync(allocation.AllocationId);

        // 2. Configure transport
        var transport = NetworkManager.Singleton.GetComponent<UnityTransport>();
        transport.SetRelayServerData(allocation.ToRelayServerData("dtls"));

        // 3. Start host
        NetworkManager.Singleton.StartHost();

        // 4. Create lobby with relay join code
        _lobby = await LobbyService.Instance.CreateLobbyAsync(lobbyName, maxPlayers,
            new CreateLobbyOptions
            {
                Data = new Dictionary<string, DataObject>
                {
                    { "JoinCode", new DataObject(DataObject.VisibilityOptions.Member, joinCode) }
                }
            });
    }

    // ---- CLIENT FLOW ----
    public async Task JoinGame(string lobbyId)
    {
        // 1. Join lobby
        _lobby = await LobbyService.Instance.JoinLobbyByIdAsync(lobbyId);

        // 2. Get relay join code from lobby data
        string joinCode = _lobby.Data["JoinCode"].Value;

        // 3. Join relay allocation
        JoinAllocation joinAllocation = await RelayService.Instance.JoinAllocationAsync(joinCode);

        // 4. Configure transport
        var transport = NetworkManager.Singleton.GetComponent<UnityTransport>();
        transport.SetRelayServerData(joinAllocation.ToRelayServerData("dtls"));

        // 5. Start client
        NetworkManager.Singleton.StartClient();
    }

    // ---- MAINTENANCE ----
    void Update()
    {
        if (_lobby == null || !NetworkManager.Singleton.IsHost) return;
        _heartbeatTimer -= Time.deltaTime;
        if (_heartbeatTimer <= 0f)
        {
            _heartbeatTimer = 15f;
            LobbyService.Instance.SendHeartbeatPingAsync(_lobby.Id);
        }
    }

    public async Task LeaveSession()
    {
        if (_lobby != null)
        {
            string playerId = AuthenticationService.Instance.PlayerId;
            await LobbyService.Instance.RemovePlayerAsync(_lobby.Id, playerId);
            _lobby = null;
        }
        NetworkManager.Singleton.Shutdown();
    }
}
```

## Transport Anti-Patterns

1. **Not setting relay data before StartHost/StartClient** -- `SetRelayServerData` must be called before starting the network session.
2. **Using "udp" instead of "dtls"** -- Always use encrypted transport in production.
3. **Forgetting lobby heartbeats** -- Lobbies expire after ~30 seconds without heartbeats.
4. **Not handling RelayServiceException** -- Relay allocation can fail (rate limits, region unavailable). Always wrap in try/catch.
5. **Polling lobby too frequently** -- Respect rate limits. Poll every 1-2 seconds at most.
6. **Not cleaning up lobbies on disconnect** -- Remove the player from the lobby when they leave or disconnect.

## Additional Resources

- [Unity Transport Package Docs](https://docs.unity3d.com/Packages/com.unity.transport@2.5/manual/index.html)
- [Unity Relay Docs](https://docs.unity.com/ugs/en-us/manual/relay/manual/introduction)
- [Unity Lobby Docs](https://docs.unity.com/ugs/en-us/manual/lobby/manual/unity-lobby-service)
- Related skills: unity-foundations, unity-scripting, unity-packages-services
