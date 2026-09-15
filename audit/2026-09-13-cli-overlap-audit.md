# R2 — Overlap Audit: `unity` (ours, 35 skills) vs `unity-ops` (new, agent-driven) vs Unity's official `unity-cli`/skills repo

Base paths: ours = `~/Dev/Unity Claude Skills/skills/<name>/SKILL.md`; official = `Unity-Technologies/skills` repo (`gh api`, not cloned).

---

## 1. Verdict table (35 rows, CONFUSES first)

| skill | verdict | why | anchor | recommended action |
|---|---|---|---|---|
| unity-testing | CONFUSES | Ships a raw `Unity -runTests -batchmode -testPlatform ... -testResults ...` CLI recipe that duplicates and bypasses `unity test`, losing its JUnit report format, exit-code-8 "tests failed vs infra failure" contract, and `--allow-install`/`--timeout` handling. | `unity-testing/SKILL.md:391-421` | amend: replace the "Command Line (CI/CD)" section with `unity test --mode EditMode\|PlayMode --report-format junit --output ...`; keep the `[Test]`/`[UnityTest]`/asmdef material (still correct). |
| unity-packages-services | CONFUSES | Instructs "Edit `Packages/manifest.json` directly to add dependencies" with a worked JSON example — the exact anti-pattern Unity's own `unity-package-management` skill calls out by name as breaking dependency resolution. | `unity-packages-services/SKILL.md:40-49` | amend: delete the "Via manifest.json" section; point to the `unity-package-management` skill's `Client.AddAndRemove` headless pattern instead. Also rename/merge — see collision table row 6. |
| unity-physics | CONFUSES | The Collision Matrix table is followed by the blanket line "At least one dynamic (non-kinematic) Rigidbody is required for collision events" placed directly under a table that also covers Trigger Events — ambiguous enough to make an agent conclude two kinematic triggers won't fire `OnTriggerEnter`, which is precisely the wrong "prior training data" Unity's own `physics-3d-collision` skill was written to overrule. | `unity-physics/SKILL.md:244-257` | amend: scope that sentence explicitly to `OnCollision*` callbacks, and add an explicit line that Kinematic-Trigger vs Kinematic-Trigger **does** fire `OnTriggerEnter`. |
| unity-procedural-gen | CONFUSES | Models "bake to asset" as a `[MenuItem]`-triggered static method a human must click, instead of the live-Editor `eval` path unity-cli mandates for one-off scene/asset edits. | `unity-procedural-gen/SKILL.md:552-568` | amend: add "for an agent driving a connected Editor, run the bake via `unity command eval` instead of requiring a manual menu click; keep `[MenuItem]` only for a human-facing designer tool." |
| unity-2d | CONFUSES | "Use the **Sprite Editor** to cut sprites from textures (slicing)" is a GUI-click instruction an agent cannot perform; Unity's own `sprite-editor` skill exists specifically because this data "lives inside the importer, not in a file you can edit — reaching it means running C# through a live Editor." | `unity-2d/SKILL.md:35` | amend: replace the GUI instruction with a pointer to driving sprite-slicing via `ISpriteEditorDataProvider` through a live Editor (or defer to the official `sprite-editor` skill). |
| unity-editor-tools | NEUTRAL | Correct and useful for building human-facing dev tools (custom inspectors, EditorWindow, PropertyDrawer), but frames MenuItem/EditorWindow as *the* editor-automation surface with no mention that a connected agent should prefer `unity command eval` for one-off changes. | `unity-editor-tools/SKILL.md:128-209` | amend: add one line — "if you are an agent driving a connected Editor, `unity command eval` is faster and doesn't require a human click; reserve EditorWindow/MenuItem for tools end-users will reuse." |
| unity-graphics | NEUTRAL | Sound render-pipeline/Shader Graph/material concepts, no hand-edit-YAML or CLI-invocation instructions found; `.mat` files are in its glob trigger though, so it can fire while an agent is mid-edit on a serialized asset. | `unity-graphics/SKILL.md:1-15` (globs incl. `**/*.mat`) | gate behind unity-ops preflight (run `unity status` before acting on the triggering `.mat`/`.shadergraph` file). |
| unity-lighting-vfx | NEUTRAL | Descriptive lighting/probe/VFX Graph concepts; no editor-automation or CLI conflicts found. | `unity-lighting-vfx/SKILL.md` (whole file) | keep. |
| unity-animation | NEUTRAL | Animator/Timeline concepts, all runtime-API framed; no conflicts found. | `unity-animation/SKILL.md` (whole file) | keep. |
| unity-cinemachine | NEUTRAL | Pure Cinemachine 3.x API guide; no conflicts. | `unity-cinemachine/SKILL.md` (whole file) | keep. |
| unity-ui | NEUTRAL | Correct UI-Toolkit-vs-uGUI-vs-IMGUI comparison; content doesn't conflict, but the topic is split four ways in Unity's own repo (see collision table row 1). | `unity-ui/SKILL.md:1-15` | keep, but expect trigger contention with 4 official skills. |
| unity-audio | NEUTRAL | AudioSource/AudioMixer scripting guide is accurate but never mentions that routing a source into a Mixer Group is a live scene edit — no live-Editor caveat where the official skill has one. | `unity-audio/SKILL.md:110-163` | gate behind unity-ops preflight for the Mixer-routing sections specifically. |
| unity-input | NEUTRAL | New Input System overview, pure C#/asset concepts; no conflicts. | `unity-input/SKILL.md` (whole file) | keep. |
| unity-multiplayer | NEUTRAL | Netcode for GameObjects (RPCs, NetworkVariables) is a different layer than Unity's official Multiplayer Services skill (session/lobby/relay), but shares enough vocabulary to collide on triggering (see collision table row 5). | `unity-multiplayer/SKILL.md:1-15` | keep; note collision risk. |
| unity-ai-navigation | NEUTRAL | NavMesh/NavMeshAgent content is accurate and non-conflicting, but nearly duplicates the topic of Unity's own `initialize-ai-navigation` skill (see collision table row 4). | `unity-ai-navigation/SKILL.md:1-15` | keep; note collision risk. |
| unity-xr | NEUTRAL | XR Interaction Toolkit/OpenXR/AR Foundation guide; no official-repo equivalent, no conflicts. | `unity-xr/SKILL.md` (whole file) | keep. |
| unity-ecs-dots | NEUTRAL | ECS/DOTS/Jobs/Burst guide; no official-repo equivalent, no conflicts. | `unity-ecs-dots/SKILL.md` (whole file) | keep. |
| unity-performance | NEUTRAL | Profiler/Memory Profiler/Frame Debugger guide; overlaps loosely with official `optimize-web`/`optimize-audio`/`optimize-text-mesh-pro` on the word "optimize" but at a different (general vs. platform-specific) altitude. | `unity-performance/SKILL.md:1-15` | keep; low collision risk. |
| unity-platforms | NEUTRAL | Build Profiles/platform-defines/mobile concepts described via `File > Build Profiles` GUI; no CLI-invocation conflicts, but overlaps `optimize-web` on WebGL. | `unity-platforms/SKILL.md:1-40` | keep; low-med collision risk (see row 9). |
| unity-game-loop | NEUTRAL | Core-loop/session/difficulty design patterns are pure C#, no hand-edit issues; glob-triggers on `.asset`. | `unity-game-loop/SKILL.md:1-11` | gate behind unity-ops preflight. |
| unity-npc-behavior | NEUTRAL | Perception/decision/action-pipeline design patterns are pure C#; glob-triggers on `.asset`. | `unity-npc-behavior/SKILL.md:1-11` | gate behind unity-ops preflight. |
| unity-foundations | HELPS | Core GameObject/Component/Transform/Prefab/ScriptableObject vocabulary is exactly what an agent needs to write correct `unity command eval` one-liners (e.g. the CLI doc's own `new UnityEngine.GameObject("Joe")` example). | `unity-foundations/SKILL.md:1-50` | keep — point the new plugin at this as the eval-snippet vocabulary source. |
| unity-scripting | HELPS | MonoBehaviour lifecycle, Vector3/Quaternion/Time/Debug core API — same reasoning as foundations; this is the C# an agent's `eval` payloads and `--execute-method` targets will be written in. | `unity-scripting/SKILL.md:1-20` | keep. |
| unity-3d-math | HELPS | Correctness patterns for coordinate spaces/Quaternion/Bounds are pure C#, testable via `unity test`, no editor-file conflicts. | `unity-3d-math/SKILL.md:1-15` | keep. |
| unity-physics-queries | HELPS | Raycast/SphereCast/NonAlloc/LayerMask correctness patterns are pure runtime C#; doesn't touch the kinematic-trigger ambiguity that affects `unity-physics`, maps cleanly onto Play-Mode `unity test` assertions. | `unity-physics-queries/SKILL.md:1-15` | keep. |
| unity-lifecycle | HELPS | Correctly documents that `Update` in Edit mode only runs on Scene-view redraws and that `Application.isPlaying` distinguishes editor from play — directly useful for writing code safe to run headless. | `unity-lifecycle/SKILL.md:210-257` | keep. |
| unity-input-correctness | HELPS | New Input System correctness patterns are pure C#, no conflicts. | `unity-input-correctness/SKILL.md:1-15` | keep. |
| unity-async-patterns | HELPS | Explicitly warns that `WaitForEndOfFrame`/`EndOfFrameAsync` hang forever "in batch mode (`-batchmode` flag)... and some test runners" and tells the agent to use `yield return null`/`Awaitable.NextFrameAsync()` instead — a direct, correct guardrail for code that will run under `unity build`/`unity test`/`unity run`. | `unity-async-patterns/SKILL.md:252` | keep — flagship "already CLI-ready" skill. |
| unity-game-architecture | HELPS | Service Locator/DI/event-bus decision patterns are pure C#, no conflicts. | `unity-game-architecture/SKILL.md:1-15` | keep. |
| unity-state-machines | HELPS | FSM/HFSM/Behavior Tree decision patterns are pure C#, no conflicts. | `unity-state-machines/SKILL.md:1-15` | keep. |
| unity-save-system | HELPS | Serialization/versioning/PlayerPrefs guidance is pure C#, no conflicts. | `unity-save-system/SKILL.md:1-15` | keep. |
| unity-data-driven | HELPS | SO-vs-JSON decision patterns are sound; explicitly warns that runtime SO edits "persist... to disk" and are lost in builds — good gotcha. Glob-triggers on `.asset`. | `unity-data-driven/SKILL.md:63` | gate behind unity-ops preflight (still worth a preflight check before any `.asset` touch). |
| unity-scene-assets | HELPS | Additive-scene/Addressables guidance is all `SceneManager`/runtime-API framed, never tells the agent to hand-edit `.unity` YAML; glob-triggers on `.unity`. | `unity-scene-assets/SKILL.md:1-14` | gate behind unity-ops preflight. |
| unity-level-design | HELPS | Trigger/encounter/checkpoint design patterns are C#-and-Inspector-wiring framed, not YAML-editing; glob-triggers on `.unity`/`.asset`. | `unity-level-design/SKILL.md:1-20` | gate behind unity-ops preflight. |
| unity-ui-patterns | HELPS | Screen-flow/View-ViewModel patterns target UI Toolkit's `.uxml`/`.uss`, which are plain text formats Unity's own CLI mandate does **not** flag (only `.unity`/`.prefab`/`.asset` are called out) — safe to hand-edit even with a live Editor open. | `unity-ui-patterns/SKILL.md:1-15` | keep, no gating needed. |

Counts (see also section 5): CONFUSES 5, NEUTRAL 16, HELPS 14 — sums to 35.

---

## 2. Official-vs-ours collision table

| official skill(s) | our skill(s), same topic | trigger-collision risk | note |
|---|---|---|---|
| `unity-package-management` | `unity-packages-services` | **high** | Direct content contradiction (manifest.json hand-edit vs. Client-API-only), near-identical name/topic — the single worst collision in the set. |
| `2d-pixel-perfect`, `manage-sprite-atlas`, `sprite-editor`, `sprite-segment-3x3grid`, `tilemap-palette-create`, `tilemap-ruletile-createempty`, `tilemap-ruletile-createfromsegment` (7 skills) | `unity-2d` | **high** | Seven narrow, live-eval/scripted official skills vs. one broad conceptual guide that includes a GUI-click instruction (`unity-2d/SKILL.md:35`) the official set was built to replace. |
| `physics-3d-collision` | `unity-physics`, `unity-physics-queries` | **high** | Heavy keyword overlap (`OnCollisionEnter`/`OnTriggerEnter`/Raycast/layer masks) plus the confirmed kinematic-trigger factual ambiguity in `unity-physics` that the official skill exists to correct. |
| `initialize-ai-navigation` | `unity-ai-navigation` | **high** | Near-identical name and scope (NavMesh surfaces/agents/obstacles/links); official is live-eval setup-flow, ours is a static API reference — a trigger match could fire either or both. |
| `urp-postprocessing`, `migrate-birp-to-urp`, `shader-graph-create-custom-node`, `validate-urp-render-graph-renderer-feature` (4 skills) | `unity-lighting-vfx`, `unity-graphics` | **high** | Four specialized official skills against two broad ours on heavily overlapping vocabulary (URP, Shader Graph, Volume, post-processing, Render Graph). |
| `ui`, `ui-uitk`, `ui-ugui`, `ui-imgui` (4 skills) | `unity-ui`, `unity-ui-patterns` | **high** | Near-identical trigger vocabulary (UI Toolkit, uGUI, Canvas, IMGUI, UXML, USS); official `ui-imgui` explicitly defers *new* editor UI work to `ui-uitk` — a rule ours doesn't encode the same way. |
| `setup-multiplayer-services` | `unity-multiplayer` | **medium-high** | Shared vocabulary (Relay, Lobby, session-based play) but genuinely different layers — official = Unity Multiplayer Services APIs, ours = Netcode for GameObjects RPC/NetworkVariable — so some differentiation exists, but a naive keyword match on "lobby"/"relay" could pick either. |
| `audio-setup-mixers`, `optimize-audio` | `unity-audio` | **medium** | Overlapping topic (Audio Mixer routing/optimization); official mandates a live-Editor check before any mixer-routing edit that ours never states. |
| `optimize-web` | `unity-platforms`, `unity-performance` | **low-medium** | Official is WebGL/WebGPU-build-specific; ours are general-purpose platform/perf guides — narrower official scope limits actual collision. |
| `new-unity-project` | `unity-foundations` | **low** | `new-unity-project` explicitly delegates project-bootstrap mechanics to `unity-cli`/`unity-package-management` and states it "does not scaffold gameplay code" — complementary rather than competing with foundations' GameObject/Component/Prefab material. |

---

## 3. "Already CLI-ready" — worth pointing the new `unity-ops` plugin at

- `unity-async-patterns/SKILL.md:252` — explicit GOTCHA that `WaitForEndOfFrame`/`EndOfFrameAsync` hang forever under `-batchmode` and some test runners; tells the agent to use `yield return null` / `Awaitable.NextFrameAsync()` instead. This is a ready-made guardrail for any code an agent writes that will run under `unity build`/`unity test`/`unity run`.
- `unity-editor-tools/SKILL.md:265-286` (SerializedObject three-step pattern with `Undo.RecordObject`) and `:290-317` (`AssetDatabase.CreateAsset`/`LoadAssetAtPath`/`SaveAssets`) — the correct programmatic way to create/modify assets with proper Undo and dirty-flagging. This is exactly the API surface a `unity command eval` payload should use instead of hand-editing YAML.
- `unity-foundations/SKILL.md` and `unity-scripting/SKILL.md` — GameObject/Component/Transform/MonoBehaviour/Vector3/Quaternion vocabulary. This is the C# an agent needs to know to write correct `unity command eval '...'` one-liners (the unity-cli doc's own example, `new UnityEngine.GameObject("Joe")`, draws on exactly this vocabulary).
- `unity-testing/SKILL.md:22-263` (NUnit attributes `[Test]`/`[UnityTest]`/`[SetUp]`/`[TearDown]`, EditMode-vs-PlayMode assembly definitions) — the test-authoring half of this skill maps directly onto what `unity test --mode EditMode|PlayMode` executes; only its CLI-invocation section (lines 391-421) is stale.
- `unity-physics-queries/SKILL.md` (NonAlloc/LayerMask/hit-ordering correctness patterns) — pure runtime C#, directly testable via automated Play-Mode tests run through `unity test`, no editor-file conflict anywhere in it.

---

## 4. Top 5 concrete conflicts a new agent hits on day one

**1. Test execution — raw binary flags vs `unity test`**
> Ours: *"Unity -runTests -batchmode -projectPath /path/to/project \ -testPlatform EditMode -testResults /path/to/results.xml"* — `unity-testing/SKILL.md:395-396`
> Unity's: *"unity test /path/to/MyProject --editor-version 6000.0.47f1 --mode EditMode --report-format junit --output ./test-results.xml --allow-install --timeout 600"* and *"8 | `unity test` only — the tests ran and one or more **failed**."* — `unity-cli` SKILL.md (Commands reference / Exit codes table)
An agent following ours loses the JUnit report format and the exit-8 "tests failed, don't retry" signal that CI scripts key off.

**2. Package installs — hand-edit manifest.json vs Client API only**
> Ours: *"### Via manifest.json / Edit `Packages/manifest.json` directly to add dependencies"* — `unity-packages-services/SKILL.md:40-41`
> Unity's: *"Do **not** hand-edit `Packages/manifest.json` — the Client API resolves dependencies and compatible versions correctly, whereas manual edits routinely break resolution."* — official `unity-package-management/SKILL.md`
Direct, unambiguous contradiction on the exact same file.

**3. Kinematic-trigger physics — an ambiguity Unity wrote a skill to correct**
> Ours: *"At least one dynamic (non-kinematic) Rigidbody is required for collision events."* (stated directly under a table that also covers Trigger Events) — `unity-physics/SKILL.md:257`
> Unity's: *"Two kinematic triggers DO fire `OnTriggerEnter`... Your prior training data may suggest otherwise -- it is wrong."* — official `physics-3d-collision/SKILL.md`
Ours doesn't explicitly say kinematic-trigger-vs-kinematic-trigger fails, but it's phrased broadly enough, right where an agent would look, to reinforce exactly the wrong LLM prior Unity's skill exists to overrule.

**4. Editor automation surface — MenuItem/EditorWindow vs live `eval`**
> Ours: *"`[UnityEditor.MenuItem("ProcGen/Bake Selected Generator")]`... Same generator implementation runs in Editor (bake to asset via MenuItem) or at Runtime"* — `unity-procedural-gen/SKILL.md:556,566`
> Unity's: *"If a Unity Editor is open on this machine, this CLI can control it live — create and modify GameObjects, edit scenes and assets... When an Editor is available, drive it instead of hand-editing scene or asset files."* — official `unity-cli/SKILL.md` (top section)
Ours models automation as something a human must click; an agent with a connected Editor should just `unity command eval` the bake directly.

**5. Sprite slicing — GUI instruction an agent cannot execute**
> Ours: *"Use the **Sprite Editor** to cut sprites from textures (slicing)"* — `unity-2d/SKILL.md:35`
> Unity's: *"Sprite metadata (rects, borders, pivots, outlines) lives inside the importer, not in a file you can edit — reaching it means running C# through a live Editor."* — official `sprite-editor/SKILL.md`
Ours assumes a human with a mouse; an agent has neither the mouse nor a text file to edit — it needs the `ISpriteEditorDataProvider` C# path the official skill provides.

---

## 5. Counts and prior-audit check

- **CONFUSES: 5** — unity-testing, unity-packages-services, unity-physics, unity-procedural-gen, unity-2d
- **NEUTRAL: 16** — unity-editor-tools, unity-graphics, unity-lighting-vfx, unity-animation, unity-cinemachine, unity-ui, unity-audio, unity-input, unity-multiplayer, unity-ai-navigation, unity-xr, unity-ecs-dots, unity-performance, unity-platforms, unity-game-loop, unity-npc-behavior
- **HELPS: 14** — unity-foundations, unity-scripting, unity-3d-math, unity-physics-queries, unity-lifecycle, unity-input-correctness, unity-async-patterns, unity-game-architecture, unity-state-machines, unity-save-system, unity-data-driven, unity-scene-assets, unity-level-design, unity-ui-patterns

`~/Dev/Unity Claude Skills/README.md` documents the 35-skill plugin (Unity 6.3 LTS basis, "Built by Nice Wolf Studio," progressive-disclosure architecture) but predates the Unity CLI entirely — no mention of `unity-cli`, batch/live-editor workflows, or the official skills repo. `~/Dev/Unity Claude Skills/audit/` exists but is **empty** — no prior audit notes to reconcile against.
