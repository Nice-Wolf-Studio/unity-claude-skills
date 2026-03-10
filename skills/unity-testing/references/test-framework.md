# Unity Test Framework -- Attribute & API Reference

> Based on Unity Test Framework 2.0 and 1.4 documentation for Unity 6.3.

---

## Unity-Specific Test Attributes

### [UnityTest]

Extends NUnit `[Test]` to support coroutines and yield instructions. Returns `IEnumerator` instead of `void`.

**Edit Mode behavior:** Runs in the `EditorApplication.update` callback loop. Each `yield return null` advances one editor update cycle.

**Play Mode behavior:** Runs as a coroutine on a test MonoBehaviour. Supports all Unity yield instructions.

**Best practice:** Only use `[UnityTest]` when you need yield instructions. Use `[Test]` for synchronous logic -- it runs faster.

```csharp
using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

// Edit Mode example
[UnityTest]
public IEnumerator EditorUtility_WhenExecuted_ReturnsSuccess()
{
    var utility = RunEditorUtilityInTheBackground();

    while (utility.isRunning)
    {
        yield return null; // Advances one EditorApplication.update
    }

    Assert.IsTrue(utility.isSuccess);
}

// Play Mode example
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

> **Source:** [UnityTest Attribute](https://docs.unity3d.com/Packages/com.unity.test-framework@1.4/manual/reference-attribute-unitytest.html)

---

### [UnitySetUp]

Unity extension of NUnit `[SetUp]` that allows yield instructions. Runs before each test as a coroutine.

```csharp
private GameObject _testObject;

[UnitySetUp]
public IEnumerator SetUp()
{
    _testObject = new GameObject("TestObject");
    _testObject.AddComponent<PlayerController>();
    yield return null; // Wait one frame for Awake/Start to execute
}
```

---

### [UnityTearDown]

Unity extension of NUnit `[TearDown]` that allows yield instructions. Runs after each test as a coroutine.

```csharp
[UnityTearDown]
public IEnumerator TearDown()
{
    if (_testObject != null)
    {
        Object.Destroy(_testObject);
        yield return null; // Wait for destruction to complete
    }
}
```

---

### [RequiresPlayMode]

Controls whether tests run in Play Mode or Edit Mode, overriding the default determined by the assembly definition platform settings.

| Parameter | Effect |
|-----------|--------|
| `[RequiresPlayMode(true)]` | Forces Play Mode execution |
| `[RequiresPlayMode(false)]` | Forces Edit Mode execution (no Play Mode) |

Can be applied at the class or method level.

```csharp
// Force this fixture to run in Edit Mode even if in a Play Mode assembly
[TestFixture]
[RequiresPlayMode(false)]
public class PureLogicTests
{
    [Test]
    public void Calculator_Add_ReturnsSum()
    {
        Assert.AreEqual(5, Calculator.Add(2, 3));
    }
}
```

> **Source:** [Edit Mode vs Play Mode Tests](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/edit-mode-vs-play-mode-tests.html)

---

### [UnityPlatform]

Restricts test execution to specific platforms.

```csharp
[Test]
[UnityPlatform(RuntimePlatform.WindowsEditor, RuntimePlatform.OSXEditor)]
public void EditorOnly_Feature_Works()
{
    // Only runs on Windows and macOS Editor
}

[Test]
[UnityPlatform(exclude = new[] { RuntimePlatform.WebGLPlayer })]
public void Feature_WorksOnAllPlatforms_ExceptWebGL()
{
    // Excluded from WebGL
}
```

---

### [TestMustExpectAllLogs]

When applied, every `Debug.Log`, `Debug.LogWarning`, and `Debug.LogError` emitted during the test must be matched by a `LogAssert.Expect()` call. If any log message is not expected, the test fails.

```csharp
[Test]
[TestMustExpectAllLogs]
public void AllLogs_MustBeExpected()
{
    LogAssert.Expect(LogType.Log, "Initialized");
    LogAssert.Expect(LogType.Warning, "Low health");

    MySystem.Initialize();  // Emits "Initialized" and "Low health"
}
```

---

### [ConditionalIgnore]

Conditionally ignores a test based on a registered condition key.

```csharp
// Register the condition (e.g., in a [SetUp] or assembly-level initializer)
ConditionalIgnoreAttribute.AddConditionalIgnoreMapping("IgnoreOnCI", true);

[Test]
[ConditionalIgnore("IgnoreOnCI", "Skipped in CI environment")]
public void VisualTest_RequiresHumanReview()
{
    // Only runs locally, skipped in CI
}
```

---

### [ParametrizedIgnore]

Ignores specific parameterized test cases based on argument values.

```csharp
[TestCase(1, 2, ExpectedResult = 3)]
[TestCase(0, 0, ExpectedResult = 0)]
[ParametrizedIgnore(0, 0)]  // Skip the (0,0) case
public int Add_ReturnsSum(int a, int b)
{
    return Calculator.Add(a, b);
}
```

---

### [PrebuildSetup] and [PostBuildCleanup]

Execute code before building the test player and after the build completes. Used for modifying Unity state or the filesystem around player builds.

```csharp
// Implementation class
public class MyPrebuildSetup : IPrebuildSetup
{
    public void Setup()
    {
        // Modify build settings or prepare test data
        PlayerSettings.SetScriptingBackend(
            BuildTargetGroup.Standalone, ScriptingImplementation.IL2CPP);
    }
}

public class MyPostBuildCleanup : IPostBuildCleanup
{
    public void Cleanup()
    {
        // Restore settings or clean up temp files
    }
}

// Apply to test
[TestFixture]
[PrebuildSetup(typeof(MyPrebuildSetup))]
[PostBuildCleanup(typeof(MyPostBuildCleanup))]
public class StandalonePlayerTests
{
    [UnityTest]
    public IEnumerator Game_StartsSuccessfully()
    {
        yield return null;
        Assert.IsTrue(GameManager.IsRunning);
    }
}
```

---

### [TestPlayerBuildModifier]

Modifies player build options or separates the build and run operations for test players.

```csharp
public class MyBuildModifier : ITestPlayerBuildModifier
{
    public BuildPlayerOptions ModifyOptions(BuildPlayerOptions playerOptions)
    {
        playerOptions.options |= BuildOptions.Development;
        return playerOptions;
    }
}

[assembly: TestPlayerBuildModifier(typeof(MyBuildModifier))]
```

---

### [TestRunCallback]

Assembly-level attribute that subscribes a type to receive test progress updates.

```csharp
public class TestProgressLogger : ITestRunCallback
{
    public void RunStarted(ITest testsToRun) { }
    public void RunFinished(ITestResult testResults) { }
    public void TestStarted(ITest test) { }
    public void TestFinished(ITestResult result)
    {
        Debug.Log($"{result.Test.Name}: {result.ResultState}");
    }
}

[assembly: TestRunCallback(typeof(TestProgressLogger))]
```

---

### [RequirePlatformSupport] (UTF 2.0)

Requires that player build support for specified platforms is installed.

```csharp
[Test]
[RequirePlatformSupport(BuildTarget.Android)]
public void AndroidSpecific_Feature_Works()
{
    // Only runs if Android build support is installed
}
```

---

### [PreservedValues] (UTF 2.0)

Similar to NUnit `[Values]`, provides literal arguments for a test parameter.

```csharp
[Test]
public void Damage_IsAlwaysPositive([PreservedValues(1, 5, 10, 100)] int damage)
{
    var health = new HealthSystem(100);
    health.TakeDamage(damage);
    Assert.Less(health.CurrentHealth, 100);
}
```

> **Source:** [Custom Attributes](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/reference-custom-attributes.html)

---

## NUnit Attributes (Commonly Used with Unity)

| Attribute | Signature | Purpose |
|-----------|-----------|---------|
| `[Test]` | `public void MethodName()` | Synchronous test method |
| `[TestFixture]` | class-level | Marks class as test container |
| `[SetUp]` | `public void SetUp()` | Runs before each test |
| `[TearDown]` | `public void TearDown()` | Runs after each test |
| `[OneTimeSetUp]` | `public void OneTimeSetUp()` | Runs once before all tests in fixture |
| `[OneTimeTearDown]` | `public void OneTimeTearDown()` | Runs once after all tests in fixture |
| `[TestCase(args)]` | method-level | Parameterized test with inline data |
| `[TestCaseSource("name")]` | method-level | Parameterized test with external data source |
| `[Values(args)]` | parameter-level | Provides values for a parameter |
| `[Range(from, to, step)]` | parameter-level | Generates range of values |
| `[Category("name")]` | class or method | Categorizes tests for filtering |
| `[Ignore("reason")]` | class or method | Skips test unconditionally |
| `[Timeout(ms)]` | method-level | Maximum execution time |
| `[Repeat(n)]` | method-level | Repeats test n times |
| `[Retry(n)]` | method-level | Retries on failure up to n times |
| `[Order(n)]` | method-level | Execution order within fixture |
| `[Explicit]` | method-level | Only runs when explicitly selected |
| `[Description("text")]` | method-level | Documents the test |

---

## Assertion Methods

### NUnit Assert Class

```csharp
// --- Equality ---
Assert.AreEqual(expected, actual);
Assert.AreEqual(expected, actual, "Custom failure message");
Assert.AreEqual(1.0f, actual, 0.001f);  // Float with delta tolerance
Assert.AreNotEqual(unexpected, actual);

// --- Boolean ---
Assert.IsTrue(condition);
Assert.IsFalse(condition);
Assert.That(actual, Is.True);

// --- Null ---
Assert.IsNull(obj);
Assert.IsNotNull(obj);

// --- Reference ---
Assert.AreSame(expected, actual);
Assert.AreNotSame(unexpected, actual);

// --- Comparison ---
Assert.Greater(actual, threshold);
Assert.Less(actual, threshold);
Assert.GreaterOrEqual(actual, threshold);
Assert.LessOrEqual(actual, threshold);

// --- Type ---
Assert.IsInstanceOf<ExpectedType>(actual);
Assert.IsNotInstanceOf<UnexpectedType>(actual);

// --- Exception ---
Assert.Throws<ArgumentException>(() => MethodUnderTest());
Assert.DoesNotThrow(() => SafeMethod());
var ex = Assert.Throws<InvalidOperationException>(() => Method());
Assert.AreEqual("Expected message", ex.Message);

// --- String ---
StringAssert.Contains("substring", actualString);
StringAssert.StartsWith("prefix", actualString);
StringAssert.EndsWith("suffix", actualString);
StringAssert.AreEqualIgnoringCase("EXPECTED", actualString);
StringAssert.IsMatch(@"regex\d+", actualString);

// --- Collection ---
CollectionAssert.Contains(collection, expectedItem);
CollectionAssert.DoesNotContain(collection, unexpectedItem);
CollectionAssert.AreEqual(expectedCollection, actualCollection);
CollectionAssert.AreEquivalent(expectedCollection, actualCollection); // Order-independent
CollectionAssert.IsEmpty(collection);
CollectionAssert.IsNotEmpty(collection);
CollectionAssert.AllItemsAreNotNull(collection);
CollectionAssert.AllItemsAreUnique(collection);
CollectionAssert.IsSubsetOf(subset, superset);
```

### NUnit Constraint Model (Assert.That)

```csharp
Assert.That(actual, Is.EqualTo(expected));
Assert.That(actual, Is.Not.EqualTo(unexpected));
Assert.That(actual, Is.GreaterThan(5));
Assert.That(actual, Is.InRange(1, 10));
Assert.That(collection, Has.Count.EqualTo(3));
Assert.That(collection, Has.Member(item));
Assert.That(collection, Is.All.GreaterThan(0));
Assert.That(str, Does.Contain("substring"));
Assert.That(str, Does.StartWith("prefix"));
Assert.That(actual, Is.Null);
Assert.That(actual, Is.Not.Null);
Assert.That(actual, Is.InstanceOf<MyType>());
```

---

## Unity Test Utilities

### LogAssert

Test that expected log messages are emitted (or that no unexpected logs appear).

```csharp
using UnityEngine.TestTools;

// Expect a specific log message
LogAssert.Expect(LogType.Error, "Connection failed");
LogAssert.Expect(LogType.Warning, "Low memory");
LogAssert.Expect(LogType.Log, "Initialized");

// Expect a log matching a regex
LogAssert.Expect(LogType.Error, new System.Text.RegularExpressions.Regex("Error.*"));

// Assert no unexpected logs were emitted
LogAssert.NoUnexpectedReceived();

// Temporarily ignore all failing log messages
LogAssert.ignoreFailingMessages = true;
// ... code that emits errors ...
LogAssert.ignoreFailingMessages = false;
```

**Default behavior:** `Debug.LogError` and `Debug.LogException` cause test failure unless expected with `LogAssert.Expect()`.

---

### Yield Instructions for [UnityTest]

| Instruction | Context | Description |
|-------------|---------|-------------|
| `yield return null` | Edit + Play | Skip one frame / one editor update |
| `new WaitForFixedUpdate()` | Play Mode | Wait for next `FixedUpdate` (physics step) |
| `new WaitForSeconds(float)` | Play Mode | Wait for scaled game time |
| `new WaitForSecondsRealtime(float)` | Play Mode | Wait for unscaled real time |
| `new WaitForEndOfFrame()` | Play Mode | Wait until rendering completes |
| `new WaitUntil(Func<bool>)` | Play Mode | Wait until predicate returns true |
| `new WaitWhile(Func<bool>)` | Play Mode | Wait while predicate returns true |
| `new EnterPlayMode()` | Edit Mode | Enter Play Mode from an Edit Mode test |
| `new ExitPlayMode()` | Edit Mode | Exit Play Mode from an Edit Mode test |

---

### Testing MonoBehaviour Lifecycle

```csharp
[UnityTest]
public IEnumerator MonoBehaviour_ReceivesLifecycleCallbacks()
{
    var go = new GameObject();
    var tracker = go.AddComponent<LifecycleTracker>();

    // Awake is called immediately on AddComponent
    Assert.IsTrue(tracker.AwakeCalled);

    // Start is called on the next frame
    yield return null;
    Assert.IsTrue(tracker.StartCalled);

    // OnEnable was called during AddComponent
    Assert.IsTrue(tracker.OnEnableCalled);

    // Trigger OnDisable/OnDestroy
    Object.Destroy(go);
    yield return null;
    Assert.IsTrue(tracker.OnDestroyCalled);
}
```

---

### Assembly Definition Configurations

**Edit Mode tests (.asmdef):**
```json
{
    "name": "Tests.EditMode",
    "rootNamespace": "",
    "references": [
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner"
    ],
    "includePlatforms": [
        "Editor"
    ],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": true,
    "precompiledReferences": [
        "nunit.framework.dll"
    ],
    "autoReferenced": false,
    "defineConstraints": [
        "UNITY_INCLUDE_TESTS"
    ],
    "versionDefines": [],
    "noEngineReferences": false
}
```

**Play Mode tests (.asmdef):**
```json
{
    "name": "Tests.PlayMode",
    "rootNamespace": "",
    "references": [
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner",
        "MyGame.Runtime"
    ],
    "includePlatforms": [],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": true,
    "precompiledReferences": [
        "nunit.framework.dll"
    ],
    "autoReferenced": false,
    "defineConstraints": [
        "UNITY_INCLUDE_TESTS"
    ],
    "optionalUnityReferences": [
        "TestAssemblies"
    ],
    "versionDefines": [],
    "noEngineReferences": false
}
```

**Key difference:** Edit Mode sets `"includePlatforms": ["Editor"]`; Play Mode leaves `"includePlatforms": []` (any platform).

> **Source:** [Creating Test Assemblies](https://docs.unity3d.com/Packages/com.unity.test-framework@1.4/manual/workflow-create-test-assembly.html)

---

## Command-Line Test Execution Reference

| Argument | Description |
|----------|-------------|
| `-runTests` | Required to execute tests |
| `-batchmode` | Headless execution (no UI), required for CI/CD |
| `-testPlatform <value>` | `EditMode` (default), `PlayMode`, or `BuildTarget` enum |
| `-testFilter <value>` | Semicolon-separated names or regex; `!` prefix to exclude |
| `-testCategory <value>` | Semicolon-separated categories; `!` prefix to exclude |
| `-testResults <path>` | NUnit XML output path (default: project root) |
| `-testNames <value>` | Full names: `FixtureName.TestName` |
| `-assemblyNames <value>` | Filter by assembly name |
| `-requiresPlayMode <bool>` | Filter by Play Mode requirement |
| `-assemblyType <value>` | `EditorOnly` or `EditorAndPlatforms` |
| `-runSynchronously` | All tests in one editor update (EditMode only) |
| `-playerHeartbeatTimeout <sec>` | Player heartbeat timeout (default: 600s) |
| `-orderedTestListFile <path>` | Text file listing tests in execution order |

### CI/CD Example (GitHub Actions)

```yaml
- name: Run Edit Mode Tests
  run: |
    /path/to/Unity -runTests -batchmode -nographics \
      -projectPath ${{ github.workspace }}/MyProject \
      -testPlatform EditMode \
      -testResults ${{ github.workspace }}/edit-mode-results.xml

- name: Run Play Mode Tests
  run: |
    /path/to/Unity -runTests -batchmode -nographics \
      -projectPath ${{ github.workspace }}/MyProject \
      -testPlatform PlayMode \
      -testResults ${{ github.workspace }}/play-mode-results.xml
```

> **Source:** [Command Line Reference](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/reference-command-line.html)

---

## Known Limitations (UTF 2.0)

- WSA (Universal Windows Platform) is not supported
- Limited parameterized test support in some scenarios
- `[Retry]` attribute may not work correctly in Play Mode tests
- Tests generated at runtime have limitations
- Conditionally compiled tests may not display correctly in the Test Runner UI

> **Source:** [Unity Test Framework 2.0 Manual](https://docs.unity3d.com/Packages/com.unity.test-framework@2.0/manual/index.html)
