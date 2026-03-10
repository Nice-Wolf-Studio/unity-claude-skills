# Unity Claude Skills Plugin

A comprehensive Claude Code plugin providing **20 skills** covering the entire Unity Game Engine documentation. Based on **Unity 6.3 LTS** (6000.3) official documentation.

> **65 files | 26,000+ lines** of actionable Unity development guidance, patterns, and API references.

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
│   ... (20 skills total)
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
