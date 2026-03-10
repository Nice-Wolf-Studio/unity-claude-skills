---
name: unity-testing
description: >
  Unity 6 testing guide. Use when writing unit tests, integration tests, or doing TDD with Unity Test Framework. Covers Edit Mode and Play Mode tests, NUnit attributes ([Test], [UnityTest], [SetUp], [TearDown]), testing MonoBehaviours and coroutines, and CI/CD integration. Based on Unity 6.3 LTS documentation.
---

# Unity Test Framework

## Test Framework Overview

The Unity Test Framework (UTF) is Unity's built-in testing solution, integrating a custom version of NUnit (based on NUnit 3.5) adapted for Unity. It enables testing C# code in **Edit Mode**, **Play Mode**, and on **target platforms** (Standalone, Android, iOS).

UTF extends NUnit with Unity-specific attributes (`[UnityTest]`, `[UnitySetUp]`, `[UnityTearDown]`) that support coroutines, yield instructions, and frame-based execution.

**Key capabilities:**
- Edit Mode tests for editor extensions and pure logic
- Play Mode tests for gameplay, physics, and coroutine-based code
- Standalone player test builds for platform-specific validation
- Command-line execution for CI/CD pipelines
- NUnit XML result output

> **Source:** [Unity Test Framework 2.0 Manual](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/index.html)

---

## Setup and Configuration

### Installing the Test Framework

UTF ships with Unity by default. Open the Test Runner via **Window > General > Test Runner**.

### Creating a Test Assembly

Test code must live in its own assembly definition (`.asmdef`) that references NUnit.

Create via **Window > General > Test Runner** (click **Create a new Test Assembly Folder**) or **Assets > Create > Testing > Test Assembly Folder**.

This creates a `Tests` folder with an `.asmdef` file preconfigured with references to:
- `nunit.framework.dll`
- `UnityEngine.TestRunner`
- `UnityEditor.TestRunner` (Edit Mode only)

### Edit Mode Assembly Definition (.asmdef)

```json
{
    "name": "Tests",
    "references": [
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner"
    ],
    "includePlatforms": ["Editor"],
    "defineConstraints": ["UNITY_INCLUDE_TESTS"],
    "autoReferenced": false
}
```

### Play Mode Assembly Definition (.asmdef)

```json
{
    "name": "Tests.PlayMode",
    "references": [
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner",
        "MyGameAssembly"
    ],
    "includePlatforms": [],
    "optionalUnityReferences": ["TestAssemblies"],
    "defineConstraints": ["UNITY_INCLUDE_TESTS"],
    "autoReferenced": false
}
```

**Important:** To test your game code, add a reference to the assembly containing the code under test in the `references` array.

> **Source:** [Creating Test Assemblies](https://docs.unity3d.com/Packages/com.unity.test-framework@1.4/manual/workflow-create-test-assembly.html)

---

## Edit Mode vs Play Mode Tests

| Aspect | Edit Mode | Play Mode |
|--------|-----------|-----------|
| **Execution context** | `EditorApplication.update` callback loop | Coroutine on a MonoBehaviour |
| **Editor access** | Full Editor + game code | Game code only (unless in Editor) |
| **Coroutine support** | `yield return null` skips one update | Full yield instructions (`WaitForSeconds`, etc.) |
| **Platform targets** | Editor only | Editor Play Mode + standalone players |
| **Use cases** | Editor extensions, pure logic, serialization | Physics, gameplay, MonoBehaviour lifecycle |
| **Assembly platform** | `"includePlatforms": ["Editor"]` | `"includePlatforms": []` |

**When to use Edit Mode:**
- Testing editor tools, custom inspectors, ScriptableObject logic
- Pure C# logic that does not depend on runtime systems
- Tests that need access to `UnityEditor` APIs

**When to use Play Mode:**
- Testing MonoBehaviour lifecycle (Awake, Start, Update)
- Physics interactions requiring `WaitForFixedUpdate`
- Coroutine and async workflows
- Scene loading and object instantiation at runtime

**Best practice:** Use NUnit `[Test]` instead of `[UnityTest]` unless you need yield instructions. `[Test]` runs faster since it does not require coroutine overhead.

> **Source:** [Edit Mode vs Play Mode Tests](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/edit-mode-vs-play-mode-tests.html)

---

## Writing Tests

Create test scripts via **Assets > Create > Testing > C# Test Script** or using the Test Runner's **Create a new Test Script** button.

### Basic Test Structure

```csharp
using NUnit.Framework;

[TestFixture]
public class HealthSystemTests
{
    private HealthSystem _health;

    [SetUp]
    public void SetUp() => _health = new HealthSystem(maxHealth: 100);

    [TearDown]
    public void TearDown() => _health = null;

    [Test]
    public void TakeDamage_ReducesHealth()
    {
        _health.TakeDamage(30);
        Assert.AreEqual(70, _health.CurrentHealth);
    }

    [Test]
    public void TakeDamage_CannotGoBelowZero()
    {
        _health.TakeDamage(150);
        Assert.AreEqual(0, _health.CurrentHealth);
    }

    [Test]
    public void Heal_IncreasesHealth()
    {
        _health.TakeDamage(50);
        _health.Heal(20);
        Assert.AreEqual(70, _health.CurrentHealth);
    }
}
```

### NUnit Attributes Reference

| Attribute | Purpose |
|-----------|---------|
| `[Test]` | Marks a method as a synchronous test |
| `[TestFixture]` | Marks a class as containing tests |
| `[SetUp]` | Runs before each test method |
| `[TearDown]` | Runs after each test method |
| `[OneTimeSetUp]` | Runs once before all tests in the fixture |
| `[OneTimeTearDown]` | Runs once after all tests in the fixture |
| `[TestCase(args)]` | Parameterized test with inline data |
| `[Values(args)]` | Provides values for a test parameter |
| `[Category("name")]` | Categorizes tests for filtering |
| `[Ignore("reason")]` | Skips a test with a reason |
| `[Timeout(ms)]` | Sets a timeout for the test |

### Unity-Specific Attributes

| Attribute | Purpose |
|-----------|---------|
| `[UnityTest]` | Coroutine-based test supporting yield instructions |
| `[UnitySetUp]` | Coroutine-based setup (supports yield) |
| `[UnityTearDown]` | Coroutine-based teardown (supports yield) |
| `[RequiresPlayMode]` | Forces test to run in Play Mode (`true`) or Edit Mode (`false`) |
| `[UnityPlatform]` | Restricts test to specific platforms |
| `[TestMustExpectAllLogs]` | Requires all log messages to be expected |
| `[PrebuildSetup]` | Runs setup before player build |
| `[PostBuildCleanup]` | Runs cleanup after player build |
| `[ConditionalIgnore]` | Conditionally ignores tests |
| `[TestRunCallback]` | Subscribes to test progress updates |

### Common Assertions

```csharp
Assert.AreEqual(expected, actual);           // Equality
Assert.IsTrue(condition);                    // Boolean
Assert.IsNotNull(obj);                       // Null check
Assert.Throws<ArgumentException>(() => F()); // Exception
Assert.AreEqual(1.0f, actual, 0.01f);       // Float tolerance
StringAssert.Contains("sub", actualString);  // String
CollectionAssert.Contains(list, item);       // Collection
```

See `references/test-framework.md` for the full assertion API reference.

> **Source:** [Creating Tests](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/workflow-create-test.html)

---

## Testing MonoBehaviours

```csharp
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using System.Collections;

[TestFixture]
public class PlayerControllerTests
{
    private GameObject _playerObject;
    private PlayerController _player;

    [UnitySetUp]
    public IEnumerator SetUp()
    {
        _playerObject = new GameObject("Player");
        _player = _playerObject.AddComponent<PlayerController>();
        yield return null; // Wait one frame for Awake/Start
    }

    [UnityTearDown]
    public IEnumerator TearDown()
    {
        Object.Destroy(_playerObject);
        yield return null; // Wait for destruction
    }

    [UnityTest]
    public IEnumerator Player_MovesForward_WhenInputApplied()
    {
        var startPos = _player.transform.position;
        _player.Move(Vector3.forward);

        yield return new WaitForFixedUpdate();

        Assert.Greater(_player.transform.position.z, startPos.z);
    }
}
```

---

## Testing Coroutines and Async

### Edit Mode UnityTest (yields in EditorApplication.update)

```csharp
[UnityTest]
public IEnumerator EditorUtility_WhenExecuted_ReturnsSuccess()
{
    var utility = RunEditorUtilityInTheBackground();
    while (utility.isRunning) { yield return null; }
    Assert.IsTrue(utility.isSuccess);
}
```

### Play Mode UnityTest (coroutine-based)

```csharp
[UnityTest]
public IEnumerator GameObject_WithRigidBody_WillBeAffectedByPhysics()
{
    var go = new GameObject();
    go.AddComponent<Rigidbody>();
    var originalPosition = go.transform.position.y;
    yield return new WaitForFixedUpdate();
    Assert.AreNotEqual(originalPosition, go.transform.position.y);
}
```

### Available Yield Instructions (Play Mode)

| Yield Instruction | Effect |
|-------------------|--------|
| `yield return null` | Skip one frame |
| `yield return new WaitForSeconds(t)` | Wait for `t` seconds (scaled time) |
| `yield return new WaitForSecondsRealtime(t)` | Wait for `t` real-time seconds |
| `yield return new WaitForFixedUpdate()` | Wait for next physics update |
| `yield return new WaitForEndOfFrame()` | Wait until end of frame |
| `yield return new WaitUntil(() => cond)` | Wait until condition is true |
| `yield return new WaitWhile(() => cond)` | Wait while condition is true |

### Testing with LogAssert

```csharp
[Test]
public void LogWarning_IsExpected()
{
    LogAssert.Expect(LogType.Warning, "Expected warning message");
    Debug.LogWarning("Expected warning message");
}
```

Use `LogAssert.NoUnexpectedReceived()` to assert no unexpected log messages were emitted. `Debug.LogError` and `Debug.LogException` cause automatic test failure unless expected.

---

## Common Test Patterns

### Arrange-Act-Assert (AAA)

```csharp
[Test]
public void Inventory_AddItem_IncreasesCount()
{
    // Arrange
    var inventory = new Inventory(maxSlots: 10);
    var item = new Item("Sword");

    // Act
    inventory.Add(item);

    // Assert
    Assert.AreEqual(1, inventory.Count);
}
```

### Parameterized Tests

```csharp
[TestCase(100, 30, 70)]
[TestCase(100, 100, 0)]
[TestCase(100, 150, 0)]
[TestCase(50, 10, 40)]
public void TakeDamage_CalculatesCorrectly(int maxHp, int damage, int expectedHp)
{
    var health = new HealthSystem(maxHp);
    health.TakeDamage(damage);

    Assert.AreEqual(expectedHp, health.CurrentHealth);
}
```

### Testing Exceptions

```csharp
[Test]
public void Inventory_AddNull_ThrowsException()
{
    var inventory = new Inventory(maxSlots: 10);

    Assert.Throws<ArgumentNullException>(() =>
    {
        inventory.Add(null);
    });
}
```

### Scene-Based Testing

```csharp
[UnityTest]
public IEnumerator Scene_Loads_Successfully()
{
    SceneManager.LoadScene("GameScene", LoadSceneMode.Single);
    yield return new WaitUntil(() => SceneManager.GetActiveScene().name == "GameScene");
    Assert.IsTrue(SceneManager.GetActiveScene().isLoaded);
}
```

### Testing with Fakes (Dependency Injection)

```csharp
public class FakeAudioService : IAudioService
{
    public bool PlaySoundCalled { get; private set; }
    public void PlaySound(string name) => PlaySoundCalled = true;
}

[Test]
public void Attack_PlaysSound()
{
    var fakeAudio = new FakeAudioService();
    var weapon = new Weapon(fakeAudio);
    weapon.Attack();
    Assert.IsTrue(fakeAudio.PlaySoundCalled);
}
```

---

## Running Tests

### From the Test Runner Window

Open **Window > General > Test Runner**. Toggle **EditMode** / **PlayMode** checkboxes. Run tests via **Run All**, **Run Selected**, double-click, or right-click context menu. Filter using the search box or result icon buttons.

### From the Command Line (CI/CD)

```bash
# Run Edit Mode tests
Unity -runTests -batchmode -projectPath /path/to/project \
  -testPlatform EditMode -testResults /path/to/results.xml

# Run Play Mode tests
Unity -runTests -batchmode -projectPath /path/to/project \
  -testPlatform PlayMode -testResults /path/to/results.xml

# Run filtered tests by name and category
Unity -runTests -batchmode -projectPath /path/to/project \
  -testFilter "HealthSystemTests" -testCategory "Unit;Integration" \
  -testResults /path/to/results.xml
```

### Command-Line Arguments Reference

| Argument | Description |
|----------|-------------|
| `-runTests` | Required flag to run tests |
| `-testPlatform` | `EditMode`, `PlayMode`, or any `BuildTarget` value |
| `-testFilter` | Semicolon-separated test names or regex pattern; prefix with `!` to negate |
| `-testCategory` | Semicolon-separated category names; prefix with `!` to negate |
| `-testResults` | Output path for NUnit XML results (default: project root) |
| `-testNames` | Full test names in `FixtureName.TestName` format |
| `-assemblyNames` | Filter by specific test assembly names |
| `-batchmode` | Run without UI (required for CI/CD) |
| `-runSynchronously` | Execute all tests in one editor update (EditMode only) |
| `-playerHeartbeatTimeout` | Seconds to wait for player heartbeat (default: 600) |

### IDE Integration

JetBrains Rider supports running Unity tests directly from the IDE with full debugging support.

> **Source:** [Running Tests](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/workflow-run-test.html), [Command Line Reference](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/reference-command-line.html)

---

## Anti-Patterns

### 1. Using [UnityTest] when [Test] suffices
`[UnityTest]` adds coroutine overhead. Use `[Test]` for synchronous logic.

```csharp
// BAD - unnecessary coroutine overhead
[UnityTest]
public IEnumerator Add_ReturnsSum()
{
    var result = Calculator.Add(2, 3);
    yield return null;
    Assert.AreEqual(5, result);
}

// GOOD - simple synchronous test
[Test]
public void Add_ReturnsSum()
{
    var result = Calculator.Add(2, 3);
    Assert.AreEqual(5, result);
}
```

### 2. Not cleaning up GameObjects
Leaked objects contaminate other tests. Always destroy GameObjects in `[UnityTearDown]` or `[TearDown]`. Create objects in setup, destroy in teardown.

### 3. Testing private methods directly
Test through public interfaces. If you must, use `[assembly: InternalsVisibleTo("Tests")]`.

### 4. Hardcoding time-based waits
Use `WaitUntil` or `WaitForFixedUpdate` instead of arbitrary `WaitForSeconds`.

```csharp
// BAD - brittle, slow
yield return new WaitForSeconds(5f);
Assert.IsTrue(enemy.IsDead);

// GOOD - deterministic
yield return new WaitUntil(() => enemy.IsDead);
Assert.IsTrue(enemy.IsDead);
```

### 5. Tests depending on execution order
Each test must be independent. Use `[SetUp]` / `[TearDown]` to establish clean state.

### 6. Ignoring log errors
Unexpected `Debug.LogError` calls cause test failures by default. Use `LogAssert.Expect()` for expected errors or `LogAssert.ignoreFailingMessages = true` only when necessary.

### 7. Placing tests in production assemblies
Test assemblies use `UNITY_INCLUDE_TESTS` define constraint and are excluded from production builds. Never mix test code with game code assemblies.

---

## Related Skills

- **unity-scripting** -- C# scripting fundamentals, MonoBehaviour lifecycle, coroutines
- **unity-editor-tools** -- Custom editors, inspectors, and editor extensions

---

## Additional Resources

- [Unity Test Framework 2.0 Manual](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/index.html)
- [Custom Attributes Reference](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/reference-custom-attributes.html)
- [Command Line Reference](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/reference-command-line.html)
- [NUnit Documentation](https://docs.nunit.org/)
