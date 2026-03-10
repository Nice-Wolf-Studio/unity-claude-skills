# Unity 6 Particle System Reference

Comprehensive reference for the built-in Particle System, all modules, scripting API, and sub-emitter patterns in Unity 6.3 LTS.

## Overview

A particle is a small, simple image or mesh emitted by a Particle System to create fluid effects like smoke, fire, water, sparks, and magic. The Particle System is CPU-based and available in all render pipelines.

## Particle System Modules

### Main Module
Configures the initial state of new particles. Accessible via `ParticleSystem.main`.

Key properties:
- **Duration**: Length of the emission cycle
- **Looping**: Whether the system repeats
- **Prewarm**: Simulate one full cycle at start
- **Start Delay**: Delay before emission begins
- **Start Lifetime**: How long each particle lives
- **Start Speed**: Initial velocity magnitude
- **Start Size**: Initial particle size (3D option available)
- **Start Rotation**: Initial orientation (3D option available)
- **Start Color**: Initial particle color
- **Gravity Modifier**: Scales Physics gravity effect on particles
- **Simulation Space**: Local (moves with parent), World (independent), or Custom
- **Scaling Mode**: How Transform scale affects particles
- **Play On Awake**: Auto-start when GameObject activates
- **Max Particles**: Upper limit on simultaneous particles
- **Emitter Velocity Mode**: Rigidbody or Transform-based velocity
- **Stop Action**: Behavior when system ends (None, Disable, Destroy, Callback)

### Emission Module
Configures the rate and timing of particle emissions. Accessible via `ParticleSystem.emission`.

Key properties:
- **Rate over Time**: Particles emitted per second
- **Rate over Distance**: Particles emitted per unit of movement
- **Bursts**: Timed emission events with count, cycle count, interval, and probability

### Shape Module
Configures the volume/surface for emission and start velocity direction. Accessible via `ParticleSystem.shape`.

Shape types:
- Sphere, Hemisphere, Cone, Box, Mesh, MeshRenderer, SkinnedMeshRenderer
- Circle, Edge, Rectangle (2D shapes)
- Sprite, SpriteRenderer

Key properties:
- **Shape**: Emission geometry type
- **Radius/Angle**: Shape dimensions
- **Arc**: Partial shape emission (e.g., half-cone)
- **Emit from**: Edge, Shell, or Volume
- **Position/Rotation/Scale**: Shape transform offset
- **Randomize Direction**: Add randomness to start direction
- **Spherize Direction**: Blend toward spherical emission

### Velocity over Lifetime Module
Modify particle movement over their lifetime. Accessible via `ParticleSystem.velocityOverLifetime`.

- **Linear**: X, Y, Z velocity curves
- **Space**: Local or World
- **Orbital**: Orbital velocity around axes
- **Offset**: Orbital center offset
- **Radial**: Speed toward/away from center
- **Speed Modifier**: Multiplier curve

### Limit Velocity over Lifetime Module
Particles reduce in velocity over time. Accessible via `ParticleSystem.limitVelocityOverLifetime`.

- **Speed**: Maximum speed value
- **Dampen**: How quickly particles decelerate toward the limit (0-1)
- **Drag**: Velocity-proportional deceleration
- **Multiply by Size/Velocity**: Scale drag by particle properties

### Force over Lifetime Module
Simulated physics forces affecting particle movement. Accessible via `ParticleSystem.forceOverLifetime`.

- **X, Y, Z**: Force vectors (constant or curve)
- **Space**: Local or World
- **Randomize**: New random force direction per frame

### Inherit Velocity Module
Sub-emitter particles match parent velocity. Accessible via `ParticleSystem.inheritVelocity`.

- **Mode**: Initial (at birth) or Current (continuous)
- **Multiplier**: Velocity inheritance scale

### Lifetime by Emitter Speed Module
Adjusts particle lifespan based on emitter velocity at spawn time.

- **Multiplier Curve**: Maps emitter speed to lifetime multiplier
- **Speed Range**: Min/max emitter speed range for the curve

### Color over Lifetime Module
Color changes based on particle age. Accessible via `ParticleSystem.colorOverLifetime`.

- **Color**: Gradient over normalized lifetime (0 = birth, 1 = death)

### Color by Speed Module
Color changes based on particle velocity. Accessible via `ParticleSystem.colorBySpeed`.

- **Color**: Gradient mapped to speed
- **Speed Range**: Min/max speed for gradient mapping

### Size over Lifetime Module
Dimension changes over particle age. Accessible via `ParticleSystem.sizeOverLifetime`.

- **Size**: Curve over normalized lifetime
- **Separate Axes**: Independent X, Y, Z sizing

### Size by Speed Module
Dimension changes based on velocity. Accessible via `ParticleSystem.sizeBySpeed`.

- **Size**: Curve mapped to speed
- **Speed Range**: Min/max speed range

### Rotation over Lifetime Module
Orientation changes over particle age. Accessible via `ParticleSystem.rotationOverLifetime`.

- **Angular Velocity**: Rotation speed curve
- **Separate Axes**: Independent X, Y, Z rotation

### Rotation by Speed Module
Orientation changes based on velocity. Accessible via `ParticleSystem.rotationBySpeed`.

- **Angular Velocity**: Mapped to particle speed
- **Speed Range**: Min/max speed range

### Noise Module
Turbulence for organic, chaotic particle motion. Accessible via `ParticleSystem.noise`.

- **Strength**: Noise force magnitude
- **Frequency**: How quickly noise values change
- **Scroll Speed**: Noise pattern movement speed
- **Damping**: Strength proportional to frequency
- **Octaves**: Layered noise detail levels
- **Quality**: Low (1D), Medium (2D), High (3D) noise

### Collision Module
Particle collisions with scene geometry. Accessible via `ParticleSystem.collision`.

- **Type**: World (physics colliders) or Planes (defined planes)
- **Mode**: 2D or 3D collision
- **Dampen**: Speed reduction on collision (0-1)
- **Bounce**: Velocity retained after bounce (0-1)
- **Lifetime Loss**: Lifetime reduction on collision
- **Min Kill Speed**: Destroy particles below this speed after collision
- **Radius Scale**: Particle collision radius multiplier
- **Collision Quality**: High, Medium, Low
- **Send Collision Messages**: Enable OnParticleCollision callbacks

### Triggers Module
Designates particles as triggers when entering/exiting collider volumes.

- **Colliders**: List of trigger colliders
- **Inside/Outside/Enter/Exit**: Actions per state (Kill, Ignore, Callback)

### Sub Emitters Module
Particles that emit other particles. Accessible via `ParticleSystem.subEmitters`.

Trigger events:
- **Birth**: When particle is created
- **Collision**: When particle collides
- **Death**: When particle dies
- **Trigger**: When particle triggers
- **Manual**: Triggered via script (`TriggerSubEmitter()`)

Properties per sub-emitter:
- **Inherit**: Color, Size, Rotation, Lifetime from parent
- **Emit Probability**: Chance of sub-emitter firing (0-1)

### Texture Sheet Animation Module
Texture grid animation frames. Accessible via `ParticleSystem.textureSheetAnimation`.

- **Mode**: Grid (rows/columns) or Sprites (individual frames)
- **Tiles**: Grid dimensions (X x Y)
- **Animation**: Whole Sheet or Single Row
- **Frame over Time**: Animation curve
- **Start Frame**: Initial frame
- **Cycles**: Animation repetitions over lifetime

### Trails Module
Motion trail rendering. Accessible via `ParticleSystem.trails`.

- **Mode**: Particles (trails behind each particle) or Ribbon (connect particles)
- **Lifetime**: Trail duration relative to particle life
- **Minimum Vertex Distance**: Trail detail level
- **Die with Particles**: Trail disappears when particle dies
- **World Space**: Trail positions in world space
- **Color over Lifetime/Trail**: Trail coloring
- **Width over Trail**: Trail width curve
- **Texture Mode**: Stretch, Tile, DistributePerSegment, RepeatPerSegment

### Lights Module
Real-time lights on particles. Accessible via `ParticleSystem.lights`.

- **Light**: Light prefab reference
- **Ratio**: Fraction of particles receiving lights
- **Random Distribution**: Randomize which particles get lights
- **Use Particle Color**: Match light color to particle color
- **Size Affects Range**: Particle size scales light range
- **Alpha Affects Intensity**: Particle alpha scales light brightness
- **Maximum Lights**: Upper limit on simultaneous lights

### External Forces Module
Wind zones and force fields. Accessible via `ParticleSystem.externalForces`.

- **Multiplier**: Force strength scale
- **Influence Filter**: List or Layer Mask filtering
- **Influence Mask**: Layer-based force field filtering

### Renderer Module
Controls how particles are rendered. Accessible via `ParticleSystem.GetComponent<ParticleSystemRenderer>()`.

- **Render Mode**: Billboard, Stretched Billboard, Horizontal/Vertical Billboard, Mesh
- **Material**: Particle material/shader
- **Sort Mode**: None, By Distance, Oldest in Front, Youngest in Front
- **Min/Max Particle Size**: Screen-space size limits
- **Render Alignment**: View, World, Local, Facing, Velocity
- **Pivot**: Particle pivot offset
- **Masking**: Visible Inside/Outside Mask, Default
- **Shadow Casting**: On, Off, Two Sided, Shadows Only
- **Receive Shadows**: Enable shadow receiving
- **GPU Instancing**: Enable instanced rendering

### Custom Data Module
Attach custom data to particles. Accessible via `ParticleSystem.customData`.

- **Mode**: Disabled, Vector (up to 4 components), Color
- **Per-component curves**: Custom values over lifetime
- Used with shaders via Custom Vertex Streams

## Scripting API (UnityEngine.ParticleSystem)

### Key Properties
```
main            -- Primary settings module
emission        -- Emission rate and behavior
shape           -- Spawn shape configuration
noise           -- Noise/turbulence module
collision       -- Collision detection module
colorOverLifetime / colorBySpeed
sizeOverLifetime / sizeBySpeed
rotationOverLifetime / rotationBySpeed
velocityOverLifetime
forceOverLifetime
limitVelocityOverLifetime
inheritVelocity
trails          -- Trail rendering module
lights          -- Light emission module
customData      -- Custom particle data
```

### Status Properties
```
isPlaying       -- Currently playing
isPaused        -- Currently paused
isStopped       -- Currently stopped
isEmitting      -- Currently emitting
particleCount   -- Active particle count
time            -- Current playback time
totalTime       -- Total elapsed time
randomSeed      -- RNG seed
useAutoRandomSeed -- Auto-generate seed
```

### Playback Methods
```csharp
Play()                  // Start playback
Play(withChildren)      // Start with/without children
Pause()                 // Pause emission and updates
Pause(withChildren)     // Pause with/without children
Stop()                  // Stop emitting
Stop(withChildren, stopBehavior)  // Stop with options
Simulate(time)          // Fast-forward simulation
Simulate(time, withChildren, restart, fixedTimeStep)
```

### Particle Manipulation
```csharp
Emit(count)                     // Spawn particles immediately
GetParticles(particles)         // Retrieve particle data array
SetParticles(particles, size)   // Write modified particle data
Clear()                         // Remove all particles
Clear(withChildren)             // Clear with/without children
IsAlive()                       // Check for active particles
TriggerSubEmitter(index)        // Fire sub-emitter manually
```

### State Management
```csharp
GetPlaybackState()    // Save current state
SetPlaybackState(state) // Restore saved state
GetTrails()           // Retrieve trail data
SetParticlesAndTrails(particles, trails) // Combined update
```

### Important Usage Pattern

When setting properties on module structs, Unity immediately writes to native code. **Always cache the module reference in a local variable:**

```csharp
// CORRECT: Cache module reference
var emission = ps.emission;
emission.rateOverTimeMultiplier = 50f;
emission.enabled = true;

// WRONG: Do not chain -- each access creates a new copy
// ps.emission.rateOverTimeMultiplier = 50f;  // Compiler error (value type)
```

**Constant shorthand** -- assign numbers directly instead of MinMaxCurve:
```csharp
var main = ps.main;
main.startLifetime = 5f;  // Equivalent to new MinMaxCurve(5f)
```

## Common Scripting Patterns

### Basic Particle System Control
```csharp
using UnityEngine;

public class ParticleController : MonoBehaviour
{
    ParticleSystem ps;

    void Start()
    {
        ps = GetComponent<ParticleSystem>();

        var main = ps.main;
        main.startLifetime = 3f;
        main.startSpeed = 5f;
        main.startSize = 0.5f;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = 1000;

        var emission = ps.emission;
        emission.rateOverTime = 20f;
    }

    public void BurstEmit(int count)
    {
        ps.Emit(count);
    }

    public void SetEmissionRate(float rate)
    {
        var emission = ps.emission;
        emission.rateOverTimeMultiplier = rate;
    }

    public void StopAndClear()
    {
        ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
    }
}
```

### Collision Callback
```csharp
using UnityEngine;
using System.Collections.Generic;

public class ParticleCollisionHandler : MonoBehaviour
{
    ParticleSystem ps;
    List<ParticleCollisionEvent> collisionEvents = new List<ParticleCollisionEvent>();

    void Start()
    {
        ps = GetComponent<ParticleSystem>();
        var collision = ps.collision;
        collision.enabled = true;
        collision.type = ParticleSystemCollisionType.World;
        collision.sendCollisionMessages = true;
    }

    void OnParticleCollision(GameObject other)
    {
        int numCollisions = ps.GetCollisionEvents(other, collisionEvents);
        for (int i = 0; i < numCollisions; i++)
        {
            Vector3 hitPoint = collisionEvents[i].intersection;
            Vector3 hitNormal = collisionEvents[i].normal;
            // Spawn impact effect, apply damage, etc.
        }
    }
}
```

### Sub-Emitter Setup via Script
```csharp
using UnityEngine;

public class SubEmitterSetup : MonoBehaviour
{
    [SerializeField] ParticleSystem mainPS;
    [SerializeField] ParticleSystem deathSubEmitter;

    void Start()
    {
        var subEmitters = mainPS.subEmitters;
        subEmitters.enabled = true;
        subEmitters.AddSubEmitter(
            deathSubEmitter,
            ParticleSystemSubEmitterType.Death,
            ParticleSystemSubEmitterProperties.InheritColor
        );
    }
}
```

### Reading and Modifying Individual Particles
```csharp
using UnityEngine;

public class ParticleManipulator : MonoBehaviour
{
    ParticleSystem ps;
    ParticleSystem.Particle[] particles;

    void Start()
    {
        ps = GetComponent<ParticleSystem>();
    }

    void LateUpdate()
    {
        int count = ps.particleCount;
        if (particles == null || particles.Length < count)
            particles = new ParticleSystem.Particle[count];

        ps.GetParticles(particles, count);

        for (int i = 0; i < count; i++)
        {
            // Example: attract particles toward a point
            Vector3 toTarget = transform.position - particles[i].position;
            particles[i].velocity += toTarget.normalized * Time.deltaTime * 5f;
        }

        ps.SetParticles(particles, count);
    }
}
```

### Burst Emission Configuration
```csharp
using UnityEngine;

public class BurstConfig : MonoBehaviour
{
    void Start()
    {
        var ps = GetComponent<ParticleSystem>();
        var emission = ps.emission;
        emission.rateOverTime = 0f; // Disable continuous emission

        // Add a burst: time=0, count=50, cycles=3, interval=0.5s, probability=1.0
        emission.SetBurst(0, new ParticleSystem.Burst(
            0f,     // time
            50,     // count
            3,      // cycleCount
            0.5f,   // repeatInterval
            1.0f    // probability
        ));
    }
}
```

### Particle System with Trails
```csharp
using UnityEngine;

public class TrailSetup : MonoBehaviour
{
    void Start()
    {
        var ps = GetComponent<ParticleSystem>();

        var trails = ps.trails;
        trails.enabled = true;
        trails.mode = ParticleSystemTrailMode.PerParticle;
        trails.lifetime = 0.5f;
        trails.minVertexDistance = 0.1f;
        trails.dieWithParticles = true;
        trails.worldSpace = true;
    }
}
```

## Anti-Patterns

1. **Not caching module references**: Each access on a module struct writes immediately to native code. Always store in a local variable before modifying.

2. **Using World simulation space for attached effects**: Particles drift away from moving parents. Use Local space for effects attached to characters/vehicles.

3. **Excessive particle counts**: Particle System is CPU-bound. For >10K particles, consider VFX Graph instead.

4. **Forgetting to Stop/Clear**: Leaked particle systems keep consuming CPU even when invisible. Use `Stop()` with `StopEmittingAndClear` or destroy the GameObject.

5. **Too many Lights module particles**: Each light particle creates a real-time light. Set Maximum Lights and use low Ratio values to control cost.

6. **Collision on every particle**: World collision with High quality on thousands of particles is expensive. Use Low quality or reduce checked particle fraction.

7. **Not setting Max Particles**: Without a cap, runaway emission can spike CPU usage. Always set a reasonable maximum.

8. **Ignoring Stop Action**: Without a Stop Action, one-shot particle systems remain as inactive GameObjects. Use Destroy or Disable for cleanup.

## References
- [Particle System Modules](https://docs.unity3d.com/6000.3/Documentation/Manual/configuring-particles.html)
- [ParticleSystem Scripting API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/ParticleSystem.html)
