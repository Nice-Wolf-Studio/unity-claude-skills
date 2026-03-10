# Unity Claude Skills Plugin

A comprehensive Claude Code plugin providing **35 skills** covering the entire Unity Game Engine documentation. Based on **Unity 6.3 LTS** (6000.3) official documentation.

> **95 files | 37,900+ lines** of actionable Unity development guidance, patterns, and API references.

## Installation

### From a marketplace

```bash
# If this plugin is listed in a marketplace you've added:
/plugin install unity
```

### Direct (local testing)

```bash
# Clone the repo
git clone https://github.com/Nice-Wolf-Studio/unity-claude-skills.git

# Run Claude Code with the plugin loaded
claude --plugin-dir ./unity-claude-skills
```

### Verify installation

```
/help              # Should show all unity:* skills
/context           # Check skills are within context budget
```

## Skills Overview

All skills **auto-invoke** when Claude detects relevant Unity work. You can also invoke them directly with `/unity:<skill-name>`.

### Core Skills

| Skill | Scope | Files | Lines |
|-------|-------|-------|-------|
| `unity-foundations` | GameObjects, Components, Transforms, Prefabs, Scenes, ScriptableObjects | 4 | 1,536 |
| `unity-scripting` | MonoBehaviour lifecycle, coroutines, async/await, events, core APIs | 4 | 1,543 |

### Domain Skills

| Skill | Scope | Files | Lines |
|-------|-------|-------|-------|
| `unity-physics` | Rigidbody, colliders, raycasting, joints, CharacterController, 2D physics | 4 | 1,630 |
| `unity-graphics` | URP, HDRP, Shader Graph, materials, cameras, Render Graph | 5 | 1,415 |
| `unity-animation` | Animator, state machines, blend trees, Timeline | 4 | 1,645 |
| `unity-cinemachine` | CinemachineCamera, blending, FreeLook, impulse, state-driven cameras | 2 | 739 |
| `unity-ui` | UI Toolkit, USS/UXML, data binding, TextMeshPro, uGUI, Canvas | 5 | 2,330 |
| `unity-audio` | AudioSource, Audio Mixer, spatial audio, import settings | 2 | 970 |
| `unity-2d` | Sprites, tilemaps, 2D physics, 2D lighting, sorting | 3 | 1,257 |
| `unity-lighting-vfx` | Lighting modes, probes, APV, Particle System, VFX Graph | 4 | 1,915 |
| `unity-input` | New Input System, actions, gamepad, touch, rebinding | 2 | 1,130 |
| `unity-multiplayer` | Netcode for GameObjects, RPCs, NetworkVariables, Relay, Lobby | 3 | 1,583 |
| `unity-ai-navigation` | NavMesh, pathfinding, NavMeshAgent, Sentis ML inference | 3 | 1,184 |
| `unity-xr` | XR Interaction Toolkit, OpenXR, AR Foundation, hand tracking | 2 | 760 |
| `unity-ecs-dots` | Entities, ISystem, Jobs, Burst Compiler, baking, SubScene | 3 | 1,025 |
| `unity-performance` | Profiler, Memory Profiler, Frame Debugger, optimization patterns | 3 | 989 |
| `unity-editor-tools` | Custom inspectors, EditorWindow, PropertyDrawer, Gizmos | 4 | 1,479 |
| `unity-platforms` | Build profiles, platform defines, mobile optimization, IL2CPP | 3 | 918 |
| `unity-testing` | Unity Test Framework, Edit/Play Mode tests, CI/CD | 2 | 1,096 |
| `unity-packages-services` | Package Manager, Unity Gaming Services, 133 packages list | 2 | 709 |

### Correctness Skills (Tier 1)

These skills use a **PATTERN format** (WHEN/WRONG/RIGHT/GOTCHA) to catch Claude's most common mistakes -- wrong code that compiles and looks correct.

| Skill | Scope | Files | Lines |
|-------|-------|-------|-------|
| `unity-3d-math` | Coordinate spaces, quaternions, Plane/Bounds, Camera projection, float precision | 2 | ~700 |
| `unity-physics-queries` | Query type selection, NonAlloc, hit ordering, layer masks, trigger interaction | 2 | ~600 |
| `unity-lifecycle` | Fake-null, Destroy deferral, editor vs runtime init, execution order, async destruction | 2 | ~600 |
| `unity-input-correctness` | Action reading, rebinding persistence, multiplayer devices, control schemes | 2 | ~550 |
| `unity-async-patterns` | Awaitable double-await, cancellation tokens, coroutine errors, Addressables | 2 | ~600 |

### Architecture Skills (Tier 2)

These skills use a **DECISION format** (WHEN/DECISION→Options/SCAFFOLD/GOTCHA) for architecture choices with genuine tradeoffs -- not one right answer, but the right answer for your context.

| Skill | Scope | Files | Lines |
|-------|-------|-------|-------|
| `unity-game-architecture` | Service Locator vs DI, MonoBehaviour vs plain C#, event architecture, bootstrap | 2 | ~800 |
| `unity-state-machines` | FSM, HFSM, Behavior Trees, stack machines, enum vs IState, testing | 2 | ~850 |
| `unity-data-driven` | SO vs JSON config, data pipelines, designer handoff, versioning/migration | 2 | ~750 |
| `unity-save-system` | Serialization formats, save architecture, PlayerPrefs, versioning, auto-save | 2 | ~850 |
| `unity-scene-assets` | Additive scenes, Addressables, AssetReference, loading screens, asset lifecycle | 2 | ~750 |

### Domain Translation Skills (Tier 3)

These skills use a **DESIGN INTENT format** (DESIGN INTENT/WRONG/RIGHT/SCAFFOLD/DESIGN HOOK) bridging designer vision to code architecture -- translating what the game SHOULD feel like into how it SHOULD be built.

| Skill | Scope | Files | Lines |
|-------|-------|-------|-------|
| `unity-game-loop` | Core loop scaffolding, session lifecycle, win/lose conditions, meta loops, difficulty, pacing | 2 | ~800 |
| `unity-npc-behavior` | Perception systems, decision layers, action pipelines, factions, NPC memory, squad coordination | 2 | ~850 |
| `unity-ui-patterns` | Screen flows, View/ViewModel, HUD architecture, feedback/juice, dynamic lists, transitions | 2 | ~800 |
| `unity-level-design` | Triggers, encounters, checkpoints, cinematics, interactables, level streaming | 2 | ~830 |
| `unity-procedural-gen` | Noise generation, tile/grid systems, dungeon generation, seeds, content budgets, baked vs runtime | 2 | ~850 |

## What Each Skill Provides

Every skill includes:

- **Core Concepts** — Essential knowledge distilled from Unity 6.3 docs
- **Common Patterns** — Idiomatic C# code examples with best practices
- **Anti-Patterns** — Common mistakes and why they're wrong (with fixes)
- **API Quick Reference** — Key classes and methods in table format
- **Reference Files** — Detailed API docs for progressive disclosure
- **Cross-References** — Links to related skills for connected topics

## Architecture

```
unity-claude-skills/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (name, version, author)
├── skills/
│   ├── unity-foundations/
│   │   ├── SKILL.md          # Core instructions (<500 lines)
│   │   └── references/       # Detailed API docs (loaded on demand)
│   ├── unity-scripting/
│   │   ├── SKILL.md
│   │   └── references/
│   ... (35 skills total)
└── README.md
```

**Progressive disclosure:** SKILL.md files contain the essentials Claude needs. Reference files provide deeper API details that Claude loads only when needed, keeping context usage efficient.

## Unity Version

All content is sourced from **Unity 6.3 LTS (6000.3)** official documentation as of March 2026. Key docs:

- [Unity 6.3 Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/)
- [Unity 6.3 Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/)

## Contributing

To update skills when Unity documentation changes:

1. WebFetch the updated docs pages
2. Update the relevant SKILL.md and reference files
3. Bump the version in `.claude-plugin/plugin.json`
4. Push — users with auto-update enabled will get the changes on next startup

## License

MIT

---

*Built by [Nice Wolf Studio](https://github.com/Nice-Wolf-Studio)*
