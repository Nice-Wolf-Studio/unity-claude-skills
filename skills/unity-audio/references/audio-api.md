# Unity Audio API Reference

> Based on Unity 6.3 LTS documentation

## AudioSource API

`UnityEngine.AudioSource` -- A representation of audio sources in 3D. Requires an AudioListener component in the scene (typically on the Main Camera).

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `clip` | AudioClip | The default AudioClip to play |
| `volume` | float | Playback volume (0.0 to 1.0) |
| `pitch` | float | Playback speed/pitch multiplier |
| `loop` | bool | Whether the clip loops on completion |
| `playOnAwake` | bool | Auto-play when the component/GameObject activates |
| `mute` | bool | Mutes the source without stopping playback |
| `isPlaying` | bool | Whether the source is currently playing (read-only) |
| `isVirtual` | bool | Whether all sounds played by this source are culled by the audio system (read-only) |
| `time` | float | Playback position in seconds |
| `timeSamples` | int | Playback position in PCM samples |
| `priority` | int | Priority of the AudioSource (0 = highest, 256 = lowest; default 128) |
| `resource` | AudioResource | Default AudioResource to play |
| `generator` | IAudioGenerator | The default IAudioGenerator to play |
| `generatorInstance` | AudioGeneratorHandle | Handle to the currently playing Generator |

### Spatial / 3D Properties

| Property | Type | Description |
|----------|------|-------------|
| `spatialBlend` | float | 2D (0.0) to 3D (1.0) spatialization blend |
| `spatialize` | bool | Enable/disable spatialization plugin |
| `spatializePostEffects` | bool | Whether spatializer runs after effect filters |
| `dopplerLevel` | float | Doppler effect scale for this source |
| `spread` | float | Spread angle in degrees for 3D stereo/multichannel |
| `rolloffMode` | AudioRolloffMode | Volume attenuation mode (Logarithmic, Linear, Custom) |
| `minDistance` | float | Distance within which volume is at maximum |
| `maxDistance` | float | Distance beyond which sound is inaudible or stops attenuating |
| `panStereo` | float | Stereo panning (-1 = full left, 1 = full right) |
| `reverbZoneMix` | float | Mix level into global reverb |
| `velocityUpdateMode` | AudioVelocityUpdateMode | Fixed or dynamic update mode for Doppler |

### Routing / Bypass Properties

| Property | Type | Description |
|----------|------|-------------|
| `outputAudioMixerGroup` | AudioMixerGroup | Target mixer group for signal routing |
| `bypassEffects` | bool | Bypass effects from filter components or global listener filters |
| `bypassListenerEffects` | bool | Prevents global AudioListener effects from applying |
| `bypassReverbZones` | bool | Disables routing into global reverb zones |
| `ignoreListenerPause` | bool | Allows playback when `AudioListener.pause` is true |
| `ignoreListenerVolume` | bool | Ignores the AudioListener volume setting |

### Gamepad Properties

| Property | Type | Description |
|----------|------|-------------|
| `gamepadSpeakerOutputType` | GamepadSpeakerOutputType | Gets/sets gamepad audio output type |

### Public Methods

#### Playback Control

```csharp
// Play the assigned clip
audioSource.Play();

// Play with a delay in seconds
audioSource.PlayDelayed(0.5f);

// Play a clip without interrupting the current one (supports overlapping)
audioSource.PlayOneShot(clip, volumeScale);

// Play at an exact DSP time (sample-accurate scheduling)
double dspTime = AudioSettings.dspTime + 1.0;
audioSource.PlayScheduled(dspTime);

// Set scheduled start/end times for gapless playback
audioSource.SetScheduledStartTime(dspTime);
audioSource.SetScheduledEndTime(dspTime + clipLength);

// Pause (remembers playback position)
audioSource.Pause();

// Resume from paused position
audioSource.UnPause();

// Stop playback entirely
audioSource.Stop();
```

#### Data / Analysis

```csharp
// Get output audio data (for visualization)
float[] data = new float[1024];
audioSource.GetOutputData(data, channel);

// Get frequency spectrum data
float[] spectrum = new float[1024];
audioSource.GetSpectrumData(spectrum, channel, FFTWindow.BlackmanHarris);
```

#### Curves

```csharp
// Get a custom rolloff/spatial curve
AnimationCurve curve = audioSource.GetCustomCurve(AudioSourceCurveType.CustomRolloff);

// Set a custom rolloff/spatial curve
audioSource.SetCustomCurve(AudioSourceCurveType.CustomRolloff, myCurve);
```

`AudioSourceCurveType` values: `CustomRolloff`, `SpatialBlend`, `ReverbZoneMix`, `Spread`

#### Spatializer

```csharp
// Read/write custom spatializer effect parameters
audioSource.GetSpatializerFloat(index, out float value);
audioSource.SetSpatializerFloat(index, value);

// Read/write ambisonic decoder parameters
audioSource.GetAmbisonicDecoderFloat(index, out float value);
audioSource.SetAmbisonicDecoderFloat(index, value);
```

#### Gamepad

```csharp
// Play through a specific gamepad speaker
audioSource.PlayOnGamepad(playerIndex);

// Disable gamepad output
audioSource.DisableGamepadOutput();

// Check platform support for gamepad speaker output
bool supported = AudioSource.GamepadSpeakerSupportsOutputType(outputType);
```

### Static Methods

```csharp
// Play a clip at a world position (creates a temporary GameObject that self-destructs)
AudioSource.PlayClipAtPoint(clip, worldPosition, volume);
```

---

## AudioClip API

`UnityEngine.AudioClip` -- A container for audio data. Stores audio in compressed or uncompressed formats.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `length` | float | Duration in seconds (read-only) |
| `samples` | int | Duration in samples (read-only) |
| `channels` | int | Number of audio channels (read-only) |
| `frequency` | int | Sample frequency in Hz (read-only) |
| `ambisonic` | bool | True if clip contains ambisonic data (read-only) |
| `loadInBackground` | bool | Whether clip loads asynchronously |
| `loadState` | AudioDataLoadState | Current load state (Unloaded, Loading, Loaded, Failed) |
| `loadType` | AudioClipLoadType | Load type: DecompressOnLoad, CompressedInMemory, Streaming (read-only) |
| `preloadAudioData` | bool | Whether data preloads on scene load (read-only) |

### Methods

```csharp
// Create a runtime AudioClip
AudioClip clip = AudioClip.Create(
    "MyClip",       // name
    44100,           // lengthSamples
    1,               // channels
    44100,           // frequency
    false            // stream
);

// Read sample data into an array
float[] data = new float[clip.samples * clip.channels];
clip.GetData(data, offsetSamples);

// Write sample data from an array
clip.SetData(data, offsetSamples);

// Manually load/unload audio data
clip.LoadAudioData();
clip.UnloadAudioData();
```

### Delegates

```csharp
// Callback invoked when AudioClip reads data (for procedural audio)
AudioClip.PCMReaderCallback onRead;

// Callback invoked when the read head position changes
AudioClip.PCMSetPositionCallback onSetPosition;
```

### Procedural Audio Example

```csharp
using UnityEngine;

public class ProceduralAudio : MonoBehaviour
{
    [SerializeField] private AudioSource audioSource;
    private float frequency = 440f;
    private float phase;
    private int sampleRate;

    void Start()
    {
        sampleRate = AudioSettings.outputSampleRate;

        AudioClip clip = AudioClip.Create(
            "SineWave", sampleRate * 2, 1, sampleRate, true,
            OnAudioRead, OnAudioSetPosition
        );

        audioSource.clip = clip;
        audioSource.loop = true;
        audioSource.Play();
    }

    void OnAudioRead(float[] data)
    {
        float increment = frequency * 2f * Mathf.PI / sampleRate;
        for (int i = 0; i < data.Length; i++)
        {
            data[i] = Mathf.Sin(phase);
            phase += increment;
            if (phase > 2f * Mathf.PI)
                phase -= 2f * Mathf.PI;
        }
    }

    void OnAudioSetPosition(int newPosition)
    {
        phase = 0f;
    }
}
```

---

## AudioListener API

`UnityEngine.AudioListener` -- Represents a microphone-like device in 3D space. Only one AudioListener can exist per scene.

### Static Properties

| Property | Type | Description |
|----------|------|-------------|
| `volume` | float | Master game volume (0.0 to 1.0) |
| `pause` | bool | Pauses/unpauses the entire audio system |

### Instance Properties

| Property | Type | Description |
|----------|------|-------------|
| `velocityUpdateMode` | AudioVelocityUpdateMode | Whether listener updates during Fixed or Dynamic update |

### Static Methods

```csharp
// Get the listener's master output data (for visualization)
float[] data = new float[1024];
AudioListener.GetOutputData(data, channel);

// Get the listener's frequency spectrum data
float[] spectrum = new float[1024];
AudioListener.GetSpectrumData(spectrum, channel, FFTWindow.BlackmanHarris);
```

---

## AudioMixer API

`UnityEngine.Audio.AudioMixer` -- Represents an Audio Mixer asset. Organizes audio groups hierarchically with paths formatted as `"Master Group/Child/Grandchild"`.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `outputAudioMixerGroup` | AudioMixerGroup | The routing target for this mixer's output |
| `updateMode` | AudioMixerUpdateMode | How time progresses during snapshot transitions (Normal or UnscaledTime) |

### Methods

#### Parameter Control

```csharp
using UnityEngine.Audio;

AudioMixer mixer;

// Set an exposed parameter value
// IMPORTANT: Once SetFloat is called, snapshots no longer control that parameter
// until ClearFloat is called
bool success = mixer.SetFloat("MasterVolume", -10f); // value in dB

// Get an exposed parameter value
// Returns false if the parameter name doesn't exist
float value;
bool exists = mixer.GetFloat("MasterVolume", out value);

// Reset a parameter back to snapshot control
mixer.ClearFloat("MasterVolume");
```

#### Snapshot Operations

```csharp
// Find a snapshot by exact name
AudioMixerSnapshot snapshot = mixer.FindSnapshot("Underwater");
if (snapshot != null)
{
    // Transition to this snapshot over 2 seconds
    snapshot.TransitionTo(2.0f);
}

// Transition to a weighted blend of multiple snapshots
AudioMixerSnapshot[] snapshots = new AudioMixerSnapshot[] { normal, underwater };
float[] weights = new float[] { 0.3f, 0.7f }; // 30% normal, 70% underwater
mixer.TransitionToSnapshots(snapshots, weights, 1.5f);
```

#### Group Queries

```csharp
// Find groups by path pattern
// Paths use format "Master/Child/Grandchild"
AudioMixerGroup[] waterGroups = mixer.FindMatchingGroups("Master/SFX/Water");

// Substring matching also works
AudioMixerGroup[] allR = mixer.FindMatchingGroups("/R");

// Empty string returns all groups
AudioMixerGroup[] allGroups = mixer.FindMatchingGroups("");
```

---

## AudioMixerGroup

`UnityEngine.Audio.AudioMixerGroup` -- Represents a group (bus) within an AudioMixer.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `audioMixer` | AudioMixer | The parent AudioMixer this group belongs to |

### Usage with AudioSource

```csharp
using UnityEngine;
using UnityEngine.Audio;

public class AudioRouting : MonoBehaviour
{
    [SerializeField] private AudioSource sfxSource;
    [SerializeField] private AudioMixerGroup sfxGroup;

    void Start()
    {
        // Route this AudioSource through the SFX mixer group
        sfxSource.outputAudioMixerGroup = sfxGroup;
    }
}
```

---

## AudioMixerSnapshot

`UnityEngine.Audio.AudioMixerSnapshot` -- Represents a saved set of parameter values for an AudioMixer.

### Methods

```csharp
// Transition to this snapshot over the given time in seconds
snapshot.TransitionTo(2.0f);
```

---

## Import Settings Reference

### Load Type Recommendations

| Audio Type | Load Type | Compression | Rationale |
|------------|-----------|-------------|-----------|
| Short SFX (<1s) | Decompress On Load | ADPCM or PCM | Fast playback, small memory footprint |
| Medium SFX (1-10s) | Compressed In Memory | Vorbis | Balanced memory/CPU |
| Music / Ambient | Streaming | Vorbis | Minimal memory (~200KB buffer) |
| UI sounds | Decompress On Load | PCM | Zero latency, tiny files |
| Voice / Dialogue | Compressed In Memory | Vorbis | Good compression, moderate length |

### Compression Format Details

| Format | Compression | CPU Cost | Quality | Notes |
|--------|-------------|----------|---------|-------|
| PCM | None (1:1) | None | Perfect | Use for very short clips only |
| ADPCM | 3.5:1 | Low | Good | Best for noisy/percussive sounds |
| Vorbis | Variable | Medium | Adjustable | Quality slider 0-100%; best general-purpose |
| MP3 | Variable | Medium | Adjustable | Similar to Vorbis; platform-dependent |

### Memory Impact by Load Type

| Load Type | Memory Usage | Notes |
|-----------|-------------|-------|
| Decompress On Load | ~10x file size (Vorbis), ~3.5x (ADPCM) | Highest memory, lowest CPU |
| Compressed In Memory | ~1x file size | Balanced; slight CPU overhead during playback |
| Streaming | ~200KB per clip | Lowest memory; disk I/O overhead |

### Import Best Practices

- **Force To Mono**: Enable for all 3D sound effects. Stereo channels collapse during 3D spatialization, so stereo data wastes memory.
- **Load In Background**: Enable for large clips to avoid blocking the main thread during scene load.
- **Preload Audio Data**: Disable for clips that may not play in every session to reduce initial load time.
- **Sample Rate**: Use "Optimize Sample Rate" to let Unity analyze frequency content and reduce rate automatically.

---

## Spatial Audio Settings Reference

### Rolloff Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| **Logarithmic** | Realistic attenuation; loud up close, rapid falloff | Default; most natural for environmental sounds |
| **Linear** | Constant attenuation rate between min and max distance | Predictable volume control; good for gameplay-critical sounds |
| **Custom** | User-defined AnimationCurve | Fine-tuned artistic control over attenuation |

### Spatial Properties Quick Guide

| Property | Range | Effect |
|----------|-------|--------|
| `spatialBlend` | 0.0 - 1.0 | 0 = fully 2D (no position), 1 = fully 3D |
| `dopplerLevel` | 0.0 - 5.0 | Doppler pitch shift intensity; 0 disables |
| `spread` | 0 - 360 | Speaker spread; 0 = point source, 360 = omnidirectional |
| `minDistance` | > 0 | Volume is max within this radius |
| `maxDistance` | > minDistance | Volume reaches minimum (or stops attenuating) at this radius |

### Spatialization Plugin Setup

1. Install a spatializer plugin (e.g., Oculus Spatializer, Steam Audio, Resonance Audio)
2. **Edit > Project Settings > Audio** -- select the spatializer plugin from the dropdown
3. On each AudioSource that needs HRTF spatialization:
   - Enable `Spatialize` checkbox (or `audioSource.spatialize = true`)
   - Set `spatialBlend` to 1.0
   - Optionally set `spatializePostEffects` for post-effect spatialization

### Performance Note

From the Unity docs: spatialize only nearby sounds and "use traditional panning on the distant ones, to reduce the CPU load." The built-in panning uses simple gain adjustment per ear based on distance and angle, which is much cheaper than full HRTF processing.

---

## Source Documentation

- [AudioSource API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AudioSource.html)
- [AudioClip API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AudioClip.html)
- [AudioListener API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/AudioListener.html)
- [AudioMixer API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Audio.AudioMixer.html)
- [AudioSource Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AudioSource.html)
- [AudioClip Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AudioClip.html)
- [AudioListener Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/class-AudioListener.html)
- [Audio Mixer Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/AudioMixer.html)
- [Audio Spatializer SDK](https://docs.unity3d.com/6000.3/Documentation/Manual/AudioSpatializerSDK.html)
