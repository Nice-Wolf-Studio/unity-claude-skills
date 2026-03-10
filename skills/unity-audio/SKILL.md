---
name: unity-audio
description: >
  Unity 6 audio system guide. Use when working with sound effects, music, AudioSource, AudioClip, AudioListener, Audio Mixer, spatial audio, or audio optimization. Covers 3D sound, mixer groups, snapshots, and audio import settings. Based on Unity 6.3 LTS documentation.
---

# Unity Audio System

## Audio System Overview

Unity's audio system provides full 3D spatial sound, real-time mixing and mastering, hierarchies of mixers, snapshots, and predefined effects. The core architecture follows a source-listener model:

1. **AudioClip** -- A container for audio data imported into the project
2. **AudioSource** -- A component attached to a GameObject that plays AudioClips
3. **AudioListener** -- A microphone-like component (typically on the Main Camera) that receives audio from sources and outputs to speakers
4. **Audio Mixer** -- A central hub for mixing sources, applying effects, and mastering output

Sounds originate from AudioSources attached to objects and are picked up by the AudioListener. Unity calculates a source's distance and position from the listener to determine volume, panning, and 3D effects. The system also models the **Doppler Effect** using the relative speed of the source and listener objects.

### Supported Audio Formats

| Format | Type |
|--------|------|
| `.aif`, `.wav` | Uncompressed |
| `.mp3`, `.ogg` | Compressed |
| `.xm`, `.mod`, `.it`, `.s3m` | Tracker modules |

Unity supports mono, stereo, and multichannel audio assets (up to eight channels).

---

## AudioSource and AudioListener

### AudioSource

The AudioSource component plays an AudioClip in your scene and provides options to customize playback behavior. Key properties:

| Property | Description | Default |
|----------|-------------|---------|
| `clip` | The AudioClip to play | None |
| `volume` | Playback volume (0.0 to 1.0) | 1.0 |
| `pitch` | Playback speed/pitch multiplier | 1.0 |
| `loop` | Whether the clip loops on completion | false |
| `playOnAwake` | Auto-play when the GameObject activates | true |
| `spatialBlend` | 2D (0.0) to 3D (1.0) blend | 0.0 |
| `priority` | Source priority (0 = highest, 256 = lowest) | 128 |
| `mute` | Mutes the source without stopping playback | false |
| `outputAudioMixerGroup` | Target mixer group for routing | None |

### 3D Sound Settings

| Property | Description |
|----------|-------------|
| `dopplerLevel` | Doppler effect intensity scale |
| `spread` | Spread angle in degrees for 3D stereo/multichannel |
| `rolloffMode` | How volume attenuates over distance (Logarithmic, Linear, Custom) |
| `minDistance` | Distance within which volume is at maximum |
| `maxDistance` | Distance beyond which sound is inaudible or stops attenuating |
| `panStereo` | Stereo panning position (-1 left to 1 right) |
| `reverbZoneMix` | Mix level into global reverb |

### AudioListener

The AudioListener acts as a microphone-like device that receives input from AudioSources in the scene and outputs through speakers. Critical rules:

- **Only one AudioListener per scene** -- this is a hard constraint
- Added to the **Main Camera** by default
- Has **no configurable Inspector properties** -- it simply must be added to work
- Processes both 3D positional audio and 2D audio (which ignores 3D processing)
- Applies Reverb Zones and Audio Effects to all audible sounds

Static properties available via script:
- `AudioListener.volume` -- Master volume (0.0 to 1.0)
- `AudioListener.pause` -- Pauses/unpauses the entire audio system

---

## AudioClip and Import Settings

### Load Types

| Load Type | Behavior | Best For |
|-----------|----------|----------|
| **Decompress On Load** | Decompresses immediately on load; uses ~10x memory for Vorbis, ~3.5x for ADPCM | Small, frequently-used sound effects |
| **Compressed In Memory** | Keeps compressed in memory, decompresses during playback; slight CPU overhead | Medium sounds where decompress-on-load exceeds memory budget |
| **Streaming** | Decodes on the fly from disk; uses ~200KB buffer per clip | Long audio like music or ambient tracks |

### Compression Formats

| Format | Ratio | Best For |
|--------|-------|----------|
| **PCM** | 1:1 (uncompressed) | Very short effects requiring zero CPU decode cost |
| **ADPCM** | 3.5:1 | Noise-heavy sounds (footsteps, impacts, weapons) |
| **Vorbis/MP3** | Variable (quality slider) | Music and medium-length effects |

### Import Settings

| Setting | Description |
|---------|-------------|
| **Force To Mono** | Mixes multi-channel audio down to a mono track before packing |
| **Normalize** | Normalizes audio during mono conversion |
| **Load In Background** | Loads the clip asynchronously to avoid blocking the main thread |
| **Ambisonic** | Marks the file as containing Ambisonic-encoded soundfields (for XR/360) |
| **Preload Audio Data** | Preloads clip data when the scene finishes loading (default: enabled) |
| **Quality** | Compression quality slider for Vorbis/MP3 formats |
| **Sample Rate Setting** | Preserve, Optimize (auto-adjust), or Override (manual reduction) |

---

## Audio Mixer

The Audio Mixer provides mixing, effects processing, and mastering for audio output. Every Audio Mixer asset contains a **Master Group** by default.

### Core Concepts

- **Groups (Buses)** -- Signal chains that control volume attenuation and pitch correction; organized hierarchically (e.g., `Master/SFX/Weapons`)
- **Snapshots** -- Saved parameter configurations that can be transitioned between at runtime to create different moods or atmospheres
- **Effects** -- DSP effects (reverb, echo, EQ, etc.) applied within group signal chains
- **Send/Return** -- Passes the result from one bus to another for shared effects processing
- **Ducking** -- Modifies one group's output based on activity in another (e.g., lower ambient when dialogue plays)
- **Views** -- Different visibility configurations for managing complex mixer layouts
- **Exposed Parameters** -- Mixer parameters exposed for script control via `SetFloat`/`GetFloat`

**Note:** The Web platform only partially supports Audio Mixers.

### Mixer Scripting

```csharp
using UnityEngine;
using UnityEngine.Audio;

public class MixerController : MonoBehaviour
{
    [SerializeField] private AudioMixer mixer;

    // Set exposed parameter (must be exposed in the Mixer Inspector)
    public void SetVolume(float linear)
    {
        float dB = Mathf.Log10(Mathf.Max(linear, 0.0001f)) * 20f;
        mixer.SetFloat("MasterVolume", dB);
    }

    // Read exposed parameter (convert dB back to linear)
    public float GetVolume()
    {
        if (mixer.GetFloat("MasterVolume", out float dB))
            return Mathf.Pow(10f, dB / 20f);
        return 1f;
    }

    // Reset parameter to snapshot-defined value
    public void ResetVolume() => mixer.ClearFloat("MasterVolume");

    // Transition to a named snapshot
    public void GoToSnapshot(string name, float time)
    {
        var snap = mixer.FindSnapshot(name);
        if (snap != null) snap.TransitionTo(time);
    }

    // Blend multiple snapshots with weights
    public void BlendSnapshots(AudioMixerSnapshot[] snaps, float[] weights, float time)
        => mixer.TransitionToSnapshots(snaps, weights, time);
}
```

---

## 3D Spatial Audio

### Basic 3D Sound Setup

Set `spatialBlend` to 1.0 for full 3D positioning. Unity's built-in panning regulates left/right ear contributions based on distance and angle from the listener.

### Spatialization Plugins (HRTF)

For advanced 3D audio, Unity supports spatialization plugins with **HRTF** filtering. Setup: (1) **Edit > Project Settings > Audio** -- select the spatializer plugin, (2) enable `Spatialize` on each AudioSource, (3) optionally set `spatializePostEffects`. Performance tip: spatialize only nearby sounds; use traditional panning on distant ones.

### Rolloff Modes

- **Logarithmic** -- Realistic: loud up close, rapid falloff (default)
- **Linear** -- Constant attenuation between minDistance and maxDistance
- **Custom** -- User-defined AnimationCurve

```csharp
using UnityEngine;

public class SpatialAudioSetup : MonoBehaviour
{
    [SerializeField] private AudioSource audioSource;

    void Start()
    {
        // Configure for 3D spatial audio
        audioSource.spatialBlend = 1.0f;       // Full 3D
        audioSource.rolloffMode = AudioRolloffMode.Logarithmic;
        audioSource.minDistance = 1f;
        audioSource.maxDistance = 50f;
        audioSource.dopplerLevel = 1.0f;
        audioSource.spread = 0f;               // Point source

        // Enable spatialization plugin (if configured in Project Settings)
        audioSource.spatialize = true;
    }
}
```

---

## Common Patterns

### Playing Sound Effects

```csharp
using UnityEngine;

public class SoundEffectPlayer : MonoBehaviour
{
    [SerializeField] private AudioSource audioSource;
    [SerializeField] private AudioClip shootClip;
    [SerializeField] private AudioClip reloadClip;

    // Play the assigned clip
    public void PlayShoot()
    {
        audioSource.Play();
    }

    // PlayOneShot: plays a clip without interrupting the current one
    // Supports overlapping sounds and per-call volume scaling
    public void PlayReload(float volumeScale = 1.0f)
    {
        audioSource.PlayOneShot(reloadClip, volumeScale);
    }

    // Play a clip at a world position (creates a temporary AudioSource)
    public void PlayExplosionAt(Vector3 position)
    {
        AudioSource.PlayClipAtPoint(shootClip, position, 1.0f);
    }

    // Play with a delay (in seconds)
    public void PlayDelayed()
    {
        audioSource.PlayDelayed(0.5f);
    }

    // Scheduled playback on DSP timeline (sample-accurate)
    public void PlayScheduled()
    {
        double startTime = AudioSettings.dspTime + 1.0;
        audioSource.PlayScheduled(startTime);
    }
}
```

### Audio Object Pooling

```csharp
using UnityEngine;
using System.Collections.Generic;

public class AudioPool : MonoBehaviour
{
    [SerializeField] private int poolSize = 10;
    private List<AudioSource> pool = new List<AudioSource>();

    void Awake()
    {
        for (int i = 0; i < poolSize; i++)
        {
            var obj = new GameObject($"PooledAudio_{i}");
            obj.transform.SetParent(transform);
            var src = obj.AddComponent<AudioSource>();
            src.playOnAwake = false;
            pool.Add(src);
        }
    }

    public AudioSource Play(AudioClip clip, Vector3 pos, float volume = 1f)
    {
        var source = pool.Find(s => !s.isPlaying);
        if (source == null) return null;
        source.transform.position = pos;
        source.clip = clip;
        source.volume = volume;
        source.Play();
        return source;
    }
}
```

### Audio Fading with Coroutines

```csharp
using UnityEngine;
using System.Collections;

public class AudioFader : MonoBehaviour
{
    [SerializeField] private AudioSource musicSource;

    public void CrossFadeTo(AudioClip newClip, float duration)
    {
        StartCoroutine(CrossFadeCoroutine(newClip, duration));
    }

    private IEnumerator CrossFadeCoroutine(AudioClip newClip, float duration)
    {
        float startVol = musicSource.volume;
        float half = duration / 2f;

        // Fade out
        for (float t = 0f; t < half; t += Time.deltaTime)
        { musicSource.volume = Mathf.Lerp(startVol, 0f, t / half); yield return null; }

        // Switch clip and fade in
        musicSource.clip = newClip;
        musicSource.Play();
        for (float t = 0f; t < half; t += Time.deltaTime)
        { musicSource.volume = Mathf.Lerp(0f, startVol, t / half); yield return null; }

        musicSource.volume = startVol;
    }
}
```

### Mixer Volume Control with UI Slider

```csharp
using UnityEngine;
using UnityEngine.Audio;
using UnityEngine.UI;

public class VolumeSettings : MonoBehaviour
{
    [SerializeField] private AudioMixer mixer;
    [SerializeField] private Slider masterSlider;

    void Start()
    {
        masterSlider.value = PlayerPrefs.GetFloat("MasterVol", 1f);
        masterSlider.onValueChanged.AddListener(v => SetVolume("MasterVol", v));
    }

    // Exposed parameter names must match those set in the Audio Mixer Inspector
    private void SetVolume(string param, float linear)
    {
        float dB = linear > 0.0001f ? Mathf.Log10(linear) * 20f : -80f;
        mixer.SetFloat(param, dB);
        PlayerPrefs.SetFloat(param, linear);
    }
}
```

### Pausing and Resuming Audio

```csharp
// Pause all audio globally
AudioListener.pause = true;

// UI sounds can bypass the global pause
uiSource.ignoreListenerPause = true;

// Resume all audio
AudioListener.pause = false;

// Pause/resume a single source (remembers playback position)
musicSource.Pause();
musicSource.UnPause();
```

---

## Anti-Patterns

### 1. Multiple AudioListeners in a Scene

Only one AudioListener can exist per scene. Remove AudioListener from secondary cameras, or disable/enable them when switching cameras.

### 2. Using Play() for Overlapping Sound Effects

```csharp
// BAD: Play() restarts the clip, cutting off the previous playback
void OnShoot()
{
    audioSource.clip = gunshot;
    audioSource.Play(); // Interrupts previous gunshot
}

// GOOD: PlayOneShot allows overlapping instances
void OnShoot()
{
    audioSource.PlayOneShot(gunshot, 0.8f);
}
```

### 3. Setting Mixer Volume with Linear Values

```csharp
// BAD: Mixer parameters use decibels, not linear 0-1
mixer.SetFloat("MasterVol", 0.5f); // Almost silent, not half volume

// GOOD: Convert linear to logarithmic decibels
float dB = Mathf.Log10(Mathf.Max(value, 0.0001f)) * 20f;
mixer.SetFloat("MasterVol", dB);
```

### 4. Loading All Audio as Decompress On Load

Large audio files (music, dialogue) set to Decompress On Load consume massive memory (~10x for Vorbis). Use **Streaming** for long clips and **Compressed In Memory** for medium-length clips.

### 5. Forgetting to Set spatialBlend for 3D Sounds

```csharp
// BAD: spatialBlend defaults to 0 (2D) -- sound ignores 3D position
AudioSource source = gameObject.AddComponent<AudioSource>();
source.clip = explosionClip;
source.Play(); // Plays at full volume regardless of distance

// GOOD: Set spatialBlend to 1 for 3D positioning
source.spatialBlend = 1.0f;
source.minDistance = 1f;
source.maxDistance = 50f;
source.Play();
```

### 6. Using PlayClipAtPoint for Frequent Effects

`PlayClipAtPoint` creates and destroys a temporary GameObject every call. For frequently played sounds (gunshots, footsteps), use an audio pool instead.

### 7. Not Using Force To Mono for 3D Sound Effects

Stereo files used as 3D sources waste memory -- stereo channels collapse to mono during 3D spatialization. Enable **Force To Mono** in import settings for 3D SFX.

---

## Key API Quick Reference

| API | Description | Notes |
|-----|-------------|-------|
| `AudioSource.Play()` | Plays the assigned clip | Restarts if already playing |
| `AudioSource.PlayOneShot(clip, vol)` | Plays clip without interrupting current | Supports overlapping |
| `AudioSource.PlayClipAtPoint(clip, pos)` | Static: plays at world position | Creates temporary GameObject |
| `AudioSource.PlayDelayed(delay)` | Plays after delay in seconds | |
| `AudioSource.PlayScheduled(time)` | Plays at DSP time | Sample-accurate scheduling |
| `AudioSource.Stop()` | Stops playback | |
| `AudioSource.Pause()` | Pauses playback | Remembers position |
| `AudioSource.UnPause()` | Resumes paused playback | |
| `AudioSource.isPlaying` | Whether source is currently playing | Read-only |
| `AudioSource.time` | Playback position in seconds | Read/write |
| `AudioSource.timeSamples` | Playback position in PCM samples | Read/write |
| `AudioListener.volume` | Global master volume | Static, 0.0-1.0 |
| `AudioListener.pause` | Pause all audio | Static bool |
| `AudioClip.length` | Clip duration in seconds | Read-only |
| `AudioClip.samples` | Clip duration in samples | Read-only |
| `AudioClip.channels` | Number of audio channels | Read-only |
| `AudioClip.frequency` | Sample rate in Hz | Read-only |
| `AudioClip.loadState` | Current load state | Read-only |
| `AudioClip.Create(name, len, ch, freq, stream)` | Creates a runtime AudioClip | |
| `AudioClip.GetData(data, offset)` | Reads sample data into array | |
| `AudioClip.SetData(data, offset)` | Writes sample data from array | |
| `AudioClip.LoadAudioData()` | Loads clip data into memory | |
| `AudioClip.UnloadAudioData()` | Unloads clip data from memory | |
| `AudioMixer.SetFloat(name, val)` | Sets exposed parameter | Returns false if not found |
| `AudioMixer.GetFloat(name, out val)` | Gets exposed parameter value | Returns false if not found |
| `AudioMixer.ClearFloat(name)` | Resets parameter to snapshot value | |
| `AudioMixer.FindSnapshot(name)` | Finds snapshot by exact name | Returns AudioMixerSnapshot |
| `AudioMixer.FindMatchingGroups(path)` | Finds groups by path pattern | Returns AudioMixerGroup[] |
| `AudioMixer.TransitionToSnapshots(snaps, weights, time)` | Weighted snapshot blend | |
| `AudioMixerSnapshot.TransitionTo(time)` | Transitions to this snapshot | |

---

## Related Skills

- **unity-foundations** -- GameObjects, Components, Transforms, Prefabs, ScriptableObjects
- **unity-scripting** -- C# scripting patterns, MonoBehaviour lifecycle, coroutines, events
- **unity-animation** -- Animator Controllers, Timeline, animation events (useful for syncing audio to animations)

---

## Additional Resources

- [Audio Overview](https://docs.unity3d.com/6000.3/Documentation/Manual/Audio.html)
- [AudioSource Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AudioSource.html)
- [AudioListener Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AudioListener.html)
- [AudioClip Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AudioClip.html)
- [Audio Mixer Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/AudioMixer.html)
- [Audio Files](https://docs.unity3d.com/6000.3/Documentation/Manual/AudioFiles.html)
- [Audio Spatializer SDK](https://docs.unity3d.com/6000.3/Documentation/Manual/AudioSpatializerSDK.html)
- [AudioSource API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AudioSource.html)
- [AudioClip API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AudioClip.html)
- [AudioListener API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AudioListener.html)
- [AudioMixer API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Audio.AudioMixer.html)
