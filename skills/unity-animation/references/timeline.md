# Timeline Reference

> Based on Unity 6.3 LTS documentation

## Overview

Unity Timeline creates cinematic content, gameplay sequences, audio sequences, and complex particle effects. It provides a multi-track sequencing interface for orchestrating animations, audio, and events across time.

**Package:** `com.unity.timeline` v1.8.11 (Unity 6.3 LTS compatible)

**Source:** [Timeline Package](https://docs.unity3d.com/Packages/com.unity.timeline@1.8/manual/index.html)

## Core Components

### Timeline Asset

A reusable asset that defines tracks, clips, and their arrangement. Stored in the Project window as a `.playable` file.

- Contains the track structure and clip data
- Reusable across multiple scenes and GameObjects
- Does not reference specific scene objects directly

### Timeline Instance

A runtime instance created when a Timeline Asset is assigned to a Playable Director. Binds abstract tracks to specific scene objects.

### Playable Director Component

The component that plays Timeline assets and manages bindings between tracks and scene objects.

| Property | Description |
|----------|-------------|
| **Playable Asset** | Reference to the Timeline Asset |
| **Update Method** | Game Time, Unscaled Game Time, DSP Clock, Manual |
| **Play On Awake** | Automatically play when scene starts |
| **Wrap Mode** | None, Loop, Hold |
| **Initial Time** | Starting playback position |

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class TimelineController : MonoBehaviour
{
    PlayableDirector director;

    void Start()
    {
        director = GetComponent<PlayableDirector>();
    }

    public void PlayCutscene()
    {
        director.Play();
    }

    public void StopCutscene()
    {
        director.Stop();
    }

    public void PauseCutscene()
    {
        director.Pause();
    }

    public void ResumeFromTime(double time)
    {
        director.time = time;
        director.Play();
    }

    public void SetSpeed(float speed)
    {
        // Playable Director doesn't have a speed property directly;
        // control speed through the PlayableGraph
        var graph = director.playableGraph;
        if (graph.IsValid())
        {
            graph.GetRootPlayable(0).SetSpeed(speed);
        }
    }
}
```

## Track Types

### Animation Track

Controls an Animator component on a bound GameObject. Supports:
- Playing animation clips at specific times
- Blending between clips using overlap
- Recording new animation directly in the Timeline
- Animation Override tracks for layered animation

```csharp
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

// Binding an Animation Track to an Animator at runtime
public class TimelineBindingExample : MonoBehaviour
{
    public PlayableDirector director;
    public TimelineAsset timeline;
    public Animator characterAnimator;

    void Start()
    {
        director.playableAsset = timeline;

        // Iterate through tracks to find and bind animation tracks
        foreach (var output in director.playableAsset.outputs)
        {
            if (output.streamName == "CharacterAnimation")
            {
                director.SetGenericBinding(output.sourceObject, characterAnimator);
            }
        }

        director.Play();
    }
}
```

### Audio Track

Plays AudioClips on a bound AudioSource.
- Clips can overlap for crossfading
- Volume and pitch curves adjustable per clip
- Supports audio easing in/out

### Activation Track

Enables and disables a bound GameObject at specific times.
- Useful for showing/hiding objects during cutscenes
- Post-playback behavior: Active, Inactive, Revert, or Leave As Is

### Signal Track

Fires events at specific points in the Timeline via Signal assets and SignalReceiver components.

#### Signal Setup

1. Create a Signal Asset (Project > Create > Signal)
2. Add a Signal Track to the Timeline
3. Place Signal Emitters at desired times, referencing Signal Assets
4. Add a SignalReceiver component to the bound GameObject
5. Map Signal Assets to UnityEvents in the SignalReceiver

```csharp
using UnityEngine;
using UnityEngine.Timeline;

// Responding to Timeline signals
public class CutsceneEventHandler : MonoBehaviour
{
    // These methods are called via SignalReceiver UnityEvents
    public void OnDialogueStart(string dialogueId)
    {
        Debug.Log($"Starting dialogue: {dialogueId}");
    }

    public void OnCameraShake(float intensity)
    {
        StartCoroutine(ShakeCamera(intensity, 0.5f));
    }

    public void OnSpawnEnemy()
    {
        // Spawn logic triggered at a specific timeline moment
    }

    System.Collections.IEnumerator ShakeCamera(float intensity, float duration)
    {
        float elapsed = 0f;
        Vector3 originalPos = Camera.main.transform.localPosition;
        while (elapsed < duration)
        {
            float x = Random.Range(-1f, 1f) * intensity;
            float y = Random.Range(-1f, 1f) * intensity;
            Camera.main.transform.localPosition = originalPos + new Vector3(x, y, 0);
            elapsed += Time.deltaTime;
            yield return null;
        }
        Camera.main.transform.localPosition = originalPos;
    }
}
```

### Control Track

Triggers sub-Timelines, particle systems, or other Playable Directors.
- Nests Timeline assets within other Timelines
- Controls particle system playback
- Manages Playable Director components on other GameObjects

### Playable Track

Custom track using the Playables API for user-defined behavior.

## Playable Director Events

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class DirectorEventHandler : MonoBehaviour
{
    PlayableDirector director;

    void OnEnable()
    {
        director = GetComponent<PlayableDirector>();
        director.played += OnPlayed;
        director.paused += OnPaused;
        director.stopped += OnStopped;
    }

    void OnDisable()
    {
        director.played -= OnPlayed;
        director.paused -= OnPaused;
        director.stopped -= OnStopped;
    }

    void OnPlayed(PlayableDirector dir)
    {
        Debug.Log("Timeline started playing");
    }

    void OnPaused(PlayableDirector dir)
    {
        Debug.Log("Timeline paused");
    }

    void OnStopped(PlayableDirector dir)
    {
        Debug.Log("Timeline finished or stopped");
        // Common pattern: transition back to gameplay
        OnCutsceneComplete();
    }

    void OnCutsceneComplete()
    {
        // Re-enable player input, hide UI overlays, etc.
    }
}
```

## Playables API

The Playables API is the underlying system powering Timeline. It can be used directly for custom animation and audio mixing beyond what Timeline provides.

### Custom Playable Behaviour

```csharp
using UnityEngine;
using UnityEngine.Playables;

// Custom playable that fades a CanvasGroup
public class FadeBehaviour : PlayableBehaviour
{
    public float startAlpha = 1f;
    public float endAlpha = 0f;

    public override void ProcessFrame(Playable playable, FrameData info, object playerData)
    {
        CanvasGroup canvasGroup = playerData as CanvasGroup;
        if (canvasGroup == null) return;

        float progress = (float)(playable.GetTime() / playable.GetDuration());
        progress = Mathf.Clamp01(progress);
        canvasGroup.alpha = Mathf.Lerp(startAlpha, endAlpha, progress);
    }
}
```

### Custom Track and Clip Assets

```csharp
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

// Custom track that targets a CanvasGroup
[TrackBindingType(typeof(CanvasGroup))]
[TrackClipType(typeof(FadeClip))]
public class FadeTrack : TrackAsset { }

// Custom clip asset
public class FadeClip : PlayableAsset
{
    public float startAlpha = 1f;
    public float endAlpha = 0f;

    public override Playable CreatePlayable(PlayableGraph graph, GameObject owner)
    {
        var playable = ScriptPlayable<FadeBehaviour>.Create(graph);
        var behaviour = playable.GetBehaviour();
        behaviour.startAlpha = startAlpha;
        behaviour.endAlpha = endAlpha;
        return playable;
    }
}
```

## Cinemachine Integration

Timeline integrates with Cinemachine for camera sequencing during cutscenes.

### Cinemachine Track

When Cinemachine is installed, a dedicated Cinemachine Track type becomes available:
- Place Cinemachine Shot clips to activate virtual cameras at specific times
- Overlapping clips create smooth camera blends
- Each clip references a CinemachineVirtualCamera in the scene

### Common Cutscene Camera Pattern

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class CutsceneCameraManager : MonoBehaviour
{
    public PlayableDirector cutsceneDirector;
    public GameObject gameplayCamera;
    public GameObject cutsceneCamera;

    void OnEnable()
    {
        cutsceneDirector.played += OnCutsceneStart;
        cutsceneDirector.stopped += OnCutsceneEnd;
    }

    void OnDisable()
    {
        cutsceneDirector.played -= OnCutsceneStart;
        cutsceneDirector.stopped -= OnCutsceneEnd;
    }

    void OnCutsceneStart(PlayableDirector dir)
    {
        gameplayCamera.SetActive(false);
        cutsceneCamera.SetActive(true);
    }

    void OnCutsceneEnd(PlayableDirector dir)
    {
        cutsceneCamera.SetActive(false);
        gameplayCamera.SetActive(true);
    }
}
```

## Sub-Timelines

Nest Timeline assets within other Timelines for modular composition:

1. Add a Control Track to the parent Timeline
2. Drag a GameObject with a Playable Director onto the Control Track
3. The sub-Timeline plays at the specified time within the parent

Benefits:
- Reusable cinematic sequences
- Team members can work on different Timeline assets independently
- Simpler to manage than a single monolithic Timeline

## Timeline Workflow Patterns

### Cutscene Trigger

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class CutsceneTrigger : MonoBehaviour
{
    public PlayableDirector director;
    public bool playOnce = true;
    private bool hasPlayed = false;

    void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag("Player")) return;
        if (playOnce && hasPlayed) return;

        hasPlayed = true;
        director.Play();
    }
}
```

### Skippable Cutscene

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class SkippableCutscene : MonoBehaviour
{
    PlayableDirector director;
    public float skipHoldTime = 1.0f;
    float holdTimer = 0f;

    void Start()
    {
        director = GetComponent<PlayableDirector>();
    }

    void Update()
    {
        if (director.state != PlayState.Playing) return;

        if (Input.GetKey(KeyCode.Escape) || Input.GetKey(KeyCode.Space))
        {
            holdTimer += Time.unscaledDeltaTime;
            if (holdTimer >= skipHoldTime)
            {
                director.time = director.duration;
                director.Evaluate();
                director.Stop();
            }
        }
        else
        {
            holdTimer = 0f;
        }
    }
}
```

### Dynamic Track Binding

```csharp
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

public class DynamicBinding : MonoBehaviour
{
    public PlayableDirector director;
    public TimelineAsset timeline;

    public void BindCharacter(Animator character, string trackName)
    {
        director.playableAsset = timeline;

        foreach (var output in timeline.outputs)
        {
            if (output.streamName == trackName)
            {
                director.SetGenericBinding(output.sourceObject, character);
                break;
            }
        }
    }
}
```

## Animation Override Tracks

Humanoid animation support within Timeline allows:
- Base animation track controlling the character
- Override tracks layering additional animation on top
- Useful for adding facial expressions or upper body actions during locomotion

## Common Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Single massive Timeline | Hard to edit and maintain | Use sub-Timelines for modular composition |
| No Signal system usage | Hard-coded time checks in scripts | Use Signals for decoupled event handling |
| Play On Awake for triggered cutscenes | Cutscene plays immediately on scene load | Disable Play On Awake; trigger from script |
| Not unsubscribing from Director events | Memory leaks, ghost callbacks | Unsubscribe in OnDisable |
| Wrap Mode None without stop handling | Timeline reaches end silently | Subscribe to stopped event or use Hold mode |
| Binding at edit time for dynamic objects | Breaks when objects are spawned at runtime | Use SetGenericBinding for runtime binding |

## Related Documentation

- [Timeline Package Manual](https://docs.unity3d.com/Packages/com.unity.timeline@1.8/manual/index.html)
- [Playable Director](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Playables.PlayableDirector.html)
- [Playables API](https://docs.unity3d.com/6000.3/Documentation/Manual/Playables.html)
- [Cinemachine](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/index.html)
