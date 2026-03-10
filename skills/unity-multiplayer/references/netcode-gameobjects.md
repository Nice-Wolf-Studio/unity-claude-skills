# Netcode for GameObjects -- Full API Reference

> Source: [Netcode for GameObjects 2.10 API Docs](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.10/)

## NetworkObject API

`NetworkObject` is a MonoBehaviour that marks a GameObject as network-enabled. Every networked prefab or scene object requires this component.

### Identity & State Properties

| Property | Type | Description |
|----------|------|-------------|
| `NetworkObjectId` | `ulong` | Unique ID synchronized across the network |
| `IsSpawned` | `bool` | Whether the object has been spawned on the network |
| `IsSceneObject` | `bool?` | Whether instantiated as part of a scene |
| `IsPlayerObject` | `bool` | Whether this is a player object |

### Ownership Properties

| Property | Type | Description |
|----------|------|-------------|
| `OwnerClientId` | `ulong` | ClientId of the current owner |
| `IsOwner` | `bool` | True if owned by local player |
| `IsOwnedByServer` | `bool` | True if server owns the object |
| `IsLocalPlayer` | `bool` | True if this is the local client's player object |
| `HasAuthority` | `bool` | True if local instance has authority |
| `IsOwnershipLocked` | `bool` | Prevents ownership transfer |
| `IsOwnershipDistributable` | `bool` | Ownership can be distributed among clients |
| `IsOwnershipTransferable` | `bool` | Any non-owner can acquire ownership |
| `IsOwnershipRequestRequired` | `bool` | Non-owner must request ownership |

### Spawning Methods (Server-Side Only)

```csharp
// Spawn with default settings
netObj.Spawn(destroyWithScene: true);

// Spawn with a specific owner
netObj.SpawnWithOwnership(clientId: 1, destroyWithScene: true);

// Spawn as a player object for a client
netObj.SpawnAsPlayerObject(clientId: 1, destroyWithScene: true);

// Instantiate and spawn in one call
NetworkObject.InstantiateAndSpawn(prefab, networkManager, ownerClientId);
```

### Despawning

```csharp
// Despawn and optionally destroy
netObj.Despawn(destroy: true);

// Deferred despawn (distributed authority)
netObj.DeferDespawn(tickOffset: 3, destroy: true);
```

### Ownership Management

```csharp
// Transfer ownership (server only)
netObj.ChangeOwnership(newOwnerClientId);

// Remove ownership (server only)
netObj.RemoveOwnership();

// Request ownership (distributed authority, non-owner)
netObj.RequestOwnership();

// Lock/unlock ownership
netObj.SetOwnershipLock(locked: true);

// Configure ownership flags
netObj.SetOwnershipStatus(OwnershipStatus.Transferable, true);
netObj.RemoveOwnershipStatus(OwnershipStatus.Transferable);
```

### Visibility

```csharp
// Show/hide from specific clients
netObj.NetworkShow(clientId);
netObj.NetworkHide(clientId);

// Check visibility
bool visible = netObj.IsNetworkVisibleTo(clientId);

// Get all observers
var observers = netObj.GetObservers();

// Custom visibility check delegate
netObj.CheckObjectVisibility = (clientId) =>
{
    // Return true to show, false to hide
    return Vector3.Distance(GetClientPosition(clientId), transform.position) < 100f;
};
```

### Parenting

```csharp
// Parent to another NetworkObject
netObj.TrySetParent(parentNetworkObject, worldPositionStays: true);
netObj.TrySetParent(parentGameObject);
netObj.TrySetParent(parentTransform);

// Remove parent
netObj.TryRemoveParent(worldPositionStays: true);
```

### Configuration Fields

| Field | Description |
|-------|-------------|
| `SpawnWithObservers` | Initialize with visibility to all clients |
| `DontDestroyWithOwner` | Persist if owner disconnects |
| `DestroyWithScene` | Remove when scene unloads |
| `AutoObjectParentSync` | Automatic parent synchronization |
| `AlwaysReplicateAsRoot` | Ignore parents, replicate as root |
| `ActiveSceneSynchronization` | Auto-migrate to new active scene |
| `SceneMigrationSynchronization` | Sync scene changes to clients |
| `SynchronizeTransform` | Send transform data on spawn |

## NetworkBehaviour API

`NetworkBehaviour` is the base class for all networked game logic. Inherits from `MonoBehaviour`.

### Full Lifecycle Order

```
Awake()
OnNetworkPreSpawn(ref NetworkManager)
OnNetworkSpawn()
OnNetworkPostSpawn()
--- object is live on the network ---
OnNetworkPreDespawn()
OnNetworkDespawn()
OnDestroy()
```

### Status Properties

```csharp
public class MyNetBehaviour : NetworkBehaviour
{
    void Example()
    {
        // Execution context
        bool server = IsServer;        // Running on server?
        bool client = IsClient;        // Running on client?
        bool host   = IsHost;          // Running as host (server + client)?

        // Ownership
        bool owner    = IsOwner;           // Do I own this object?
        bool myPlayer = IsLocalPlayer;     // Is this my player object?
        ulong ownerId = OwnerClientId;     // Who owns this?
        bool auth     = HasAuthority;      // Do I have authority?

        // State
        bool spawned = IsSpawned;          // Safe to access in FixedUpdate

        // References
        NetworkObject netObj = NetworkObject;
        NetworkManager mgr   = NetworkManager;
        ulong objId          = NetworkObjectId;
        ushort behId         = NetworkBehaviourId;
    }
}
```

### Ownership Change Callbacks

```csharp
public class OwnershipTracker : NetworkBehaviour
{
    public override void OnGainedOwnership()
    {
        Debug.Log("I now own this object");
    }

    public override void OnLostOwnership()
    {
        Debug.Log("I lost ownership");
    }

    public override void OnOwnershipChanged(ulong previousOwner, ulong newOwner)
    {
        // Called on ALL clients, not just the one gaining/losing
        Debug.Log($"Ownership: {previousOwner} -> {newOwner}");
    }
}
```

### Custom Synchronization

Override `OnSynchronize` to send custom data when a client joins or object spawns:

```csharp
public class CustomSync : NetworkBehaviour
{
    private int _cachedScore;

    protected override void OnSynchronize<T>(ref BufferSerializer<T> serializer)
    {
        serializer.SerializeValue(ref _cachedScore);
    }
}
```

### Special Callbacks

```csharp
// Called after all in-scene NetworkObjects finish spawning
public override void OnInSceneObjectsSpawned() { }

// Client-side: after new client synchronization completes
public override void OnNetworkSessionSynchronized() { }

// When parent NetworkObject changes
public override void OnNetworkObjectParentChanged(NetworkObject parentNetworkObject) { }
```

## NetworkVariable<T> Full Reference

### Supported Types

`T` must be `unmanaged`: `bool`, `byte`, `int`, `float`, `double`, `long`, `ulong`, `Vector3`, `Quaternion`, `FixedString32Bytes`, `FixedString64Bytes`, and any unmanaged struct.

### Permissions

```csharp
// Default: server writes, everyone reads
public NetworkVariable<int> Score = new(0,
    NetworkVariableReadPermission.Everyone,
    NetworkVariableWritePermission.Server);

// Owner writes (e.g., for client-authoritative input)
public NetworkVariable<Vector3> InputDirection = new(Vector3.zero,
    NetworkVariableReadPermission.Everyone,
    NetworkVariableWritePermission.Owner);
```

### Complete Usage Pattern

```csharp
public class SyncedPlayer : NetworkBehaviour
{
    public NetworkVariable<int> Health = new(100);
    public NetworkVariable<FixedString64Bytes> PlayerName = new();

    public override void OnNetworkSpawn()
    {
        // Subscribe to changes
        Health.OnValueChanged += (int prev, int curr) =>
        {
            Debug.Log($"Health: {prev} -> {curr}");
            UpdateHealthBar(curr);
        };

        // Read current value (already synced for late joiners)
        UpdateHealthBar(Health.Value);
    }

    public override void OnNetworkDespawn()
    {
        Health.OnValueChanged -= OnHealthChanged;
    }

    // Server modifies value
    [Rpc(SendTo.Server)]
    void TakeDamageRpc(int amount)
    {
        Health.Value = Mathf.Max(0, Health.Value - amount);
    }
}
```

### Dirty State for Collections

When using managed collections inside a NetworkVariable, changes to the collection's contents are not auto-detected:

```csharp
public NetworkVariable<NativeArray<int>> Scores = new();

void UpdateScore(int index, int value)
{
    var arr = Scores.Value;
    arr[index] = value;
    Scores.CheckDirtyState(forceCheck: true); // Force dirty check
}
```

## NetworkList<T> Full Reference

`NetworkList<T>` is an event-driven synchronized list. `T` must be `unmanaged` and implement `IEquatable<T>`.

### Declaration and Initialization

```csharp
public class LeaderboardManager : NetworkBehaviour
{
    // Must be initialized in Awake, not field initializer
    public NetworkList<ScoreEntry> Scores;

    void Awake()
    {
        Scores = new NetworkList<ScoreEntry>();
    }
}

public struct ScoreEntry : INetworkSerializable, IEquatable<ScoreEntry>
{
    public ulong PlayerId;
    public int Score;

    public void NetworkSerialize<T>(BufferSerializer<T> serializer) where T : IReaderWriter
    {
        serializer.SerializeValue(ref PlayerId);
        serializer.SerializeValue(ref Score);
    }

    public bool Equals(ScoreEntry other)
    {
        return PlayerId == other.PlayerId && Score == other.Score;
    }
}
```

### Operations

```csharp
// Add, insert, remove
Scores.Add(new ScoreEntry { PlayerId = 1, Score = 100 });
Scores.Insert(0, entry);
Scores.Remove(entry);
Scores.RemoveAt(index);
Scores.Clear();

// Access
ScoreEntry first = Scores[0];
Scores[0] = updatedEntry;
int count = Scores.Count;
bool has = Scores.Contains(entry);
int idx = Scores.IndexOf(entry);

// Zero-allocation read (valid until next mutation)
NativeArray<ScoreEntry> view = Scores.AsNativeArray();

// Iterate
foreach (var score in Scores)
{
    Debug.Log($"Player {score.PlayerId}: {score.Score}");
}
```

### Change Events

```csharp
public override void OnNetworkSpawn()
{
    Scores.OnListChanged += OnScoresChanged;
}

void OnScoresChanged(NetworkListEvent<ScoreEntry> evt)
{
    switch (evt.Type)
    {
        case NetworkListEvent<ScoreEntry>.EventType.Add:
            Debug.Log($"Added at index {evt.Index}");
            break;
        case NetworkListEvent<ScoreEntry>.EventType.Remove:
            Debug.Log($"Removed from index {evt.Index}");
            break;
        case NetworkListEvent<ScoreEntry>.EventType.Value:
            Debug.Log($"Changed at index {evt.Index}");
            break;
        case NetworkListEvent<ScoreEntry>.EventType.Clear:
            Debug.Log("List cleared");
            break;
    }
}
```

## Custom Serialization (INetworkSerializable)

Implement `INetworkSerializable` for custom struct types used in RPCs or NetworkVariables:

```csharp
public struct PlayerInput : INetworkSerializable
{
    public Vector3 MoveDirection;
    public bool Jump;
    public float LookAngle;

    public void NetworkSerialize<T>(BufferSerializer<T> serializer) where T : IReaderWriter
    {
        serializer.SerializeValue(ref MoveDirection);
        serializer.SerializeValue(ref Jump);
        serializer.SerializeValue(ref LookAngle);
    }
}

// Usage in RPC
[Rpc(SendTo.Server)]
void SendInputRpc(PlayerInput input)
{
    ProcessInput(input);
}
```

## Prefab Registration

All networked prefabs must be registered with NetworkManager:

```csharp
// Via Inspector: Add to NetworkManager > NetworkPrefabs list

// Via code (runtime):
NetworkManager.Singleton.AddNetworkPrefab(myPrefab);
NetworkManager.Singleton.RemoveNetworkPrefab(myPrefab);
```

## Object Pooling

Use `INetworkPrefabInstanceHandler` for custom spawn/despawn logic (e.g., pooling):

```csharp
public class PooledPrefabHandler : INetworkPrefabInstanceHandler
{
    private Queue<NetworkObject> _pool = new();
    private GameObject _prefab;

    public PooledPrefabHandler(GameObject prefab, int preloadCount)
    {
        _prefab = prefab;
        for (int i = 0; i < preloadCount; i++)
        {
            var obj = Object.Instantiate(prefab);
            obj.SetActive(false);
            _pool.Enqueue(obj.GetComponent<NetworkObject>());
        }
    }

    public NetworkObject Instantiate(ulong ownerClientId, Vector3 position, Quaternion rotation)
    {
        NetworkObject obj;
        if (_pool.Count > 0)
        {
            obj = _pool.Dequeue();
            obj.transform.SetPositionAndRotation(position, rotation);
            obj.gameObject.SetActive(true);
        }
        else
        {
            obj = Object.Instantiate(_prefab, position, rotation).GetComponent<NetworkObject>();
        }
        return obj;
    }

    public void Destroy(NetworkObject networkObject)
    {
        networkObject.gameObject.SetActive(false);
        _pool.Enqueue(networkObject);
    }
}

// Register the handler
var handler = new PooledPrefabHandler(bulletPrefab, 20);
NetworkManager.Singleton.PrefabHandler.AddHandler(bulletPrefab, handler);
```

## NetworkManager -- Extended Reference

### Connection Events

```csharp
void Start()
{
    var nm = NetworkManager.Singleton;

    // Individual callbacks
    nm.OnClientConnectedCallback += (ulong clientId) =>
    {
        Debug.Log($"Client {clientId} connected");
    };

    nm.OnClientDisconnectCallback += (ulong clientId) =>
    {
        Debug.Log($"Client {clientId} disconnected");
    };

    // Consolidated event
    nm.OnConnectionEvent += (NetworkManager manager, ConnectionEventData data) =>
    {
        Debug.Log($"Connection event: {data.EventType} for client {data.ClientId}");
    };

    // Server/client lifecycle
    nm.OnServerStarted += () => Debug.Log("Server started");
    nm.OnServerStopped += (bool wasHost) => Debug.Log("Server stopped");
    nm.OnClientStarted += () => Debug.Log("Client started");
    nm.OnClientStopped += (bool wasHost) => Debug.Log("Client stopped");
    nm.OnTransportFailure += () => Debug.Log("Transport failure");
}
```

### Client Disconnection

```csharp
// Server disconnects a specific client
NetworkManager.Singleton.DisconnectClient(clientId, "Kicked for inactivity");
```

### Network Tick System

```csharp
// Access tick information
NetworkTickSystem tickSystem = NetworkManager.Singleton.NetworkTickSystem;
int currentTick = tickSystem.LocalTime.Tick;
double tickRate = tickSystem.LocalTime.TickRate;
```

## RPC -- Extended Reference

### RpcTarget for Runtime Targets

Use `RpcTarget` property on NetworkBehaviour for dynamic targeting:

```csharp
public class ChatSystem : NetworkBehaviour
{
    [Rpc(SendTo.SpecifiedInParams)]
    void SendWhisperRpc(string message, RpcParams rpcParams)
    {
        ShowChatMessage(message);
    }

    void SendWhisper(ulong targetClientId, string message)
    {
        // Send to a single specific client
        RpcParams rpcParams = RpcTarget.Single(targetClientId, RpcTargetUse.Temp);
        SendWhisperRpc(message, rpcParams);
    }

    void SendToGroup(ulong[] clientIds, string message)
    {
        RpcParams rpcParams = RpcTarget.Group(clientIds, RpcTargetUse.Temp);
        SendWhisperRpc(message, rpcParams);
    }

    void SendToAllExcept(ulong excludeClientId, string message)
    {
        RpcParams rpcParams = RpcTarget.Not(excludeClientId, RpcTargetUse.Temp);
        SendWhisperRpc(message, rpcParams);
    }
}
```

### Rpc Attribute Options

```csharp
// Allow overriding target at runtime
[Rpc(SendTo.Owner, AllowTargetOverride = true)]
void FlexibleRpc(RpcParams rpcParams = default) { }

// Defer local execution to next network tick
[Rpc(SendTo.Everyone, DeferLocal = true)]
void DeferredRpc() { }

// Unreliable delivery (for frequent, non-critical data)
[Rpc(SendTo.Server, Delivery = RpcDelivery.Unreliable)]
void UnreliableRpc(Vector3 position) { }
```

### Reading Sender Info

```csharp
[Rpc(SendTo.Server)]
void ActionRpc(RpcParams rpcParams = default)
{
    ulong senderId = rpcParams.Receive.SenderClientId;
    Debug.Log($"RPC from client {senderId}");
}
```

## Additional Resources

- [Netcode for GameObjects 2.10 Package Docs](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.10/)
- [Boss Room Sample](https://github.com/Unity-Technologies/com.unity.multiplayer.samples.coop)
- Related skills: unity-foundations, unity-scripting, unity-physics
