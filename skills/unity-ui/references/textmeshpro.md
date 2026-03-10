# TextMeshPro Reference

> Unity 6.3 LTS (6000.3) — TextMeshPro package (com.unity.textmeshpro)
> [TextMeshPro Manual](https://docs.unity3d.com/Packages/com.unity.textmeshpro@3.0/manual/index.html)

## Overview

TextMeshPro (TMP) is Unity's recommended text solution, replacing both Legacy Text (UI.Text) and TextMesh (3D). It uses **Signed Distance Field (SDF)** rendering for crisp text at any size/resolution without blurriness.

### Setup

First-time setup: **Window > TextMeshPro > Import TMP Essential Resources**

### Two Components

| Component | Class | Renderer | Use Case |
|-----------|-------|----------|----------|
| **TextMeshPro - Text (UI)** | `TextMeshProUGUI` | Canvas / CanvasRenderer | HUD, menus, any UI in Canvas |
| **TextMeshPro - Text** | `TextMeshPro` | MeshRenderer | 3D world text (signs, labels, floating damage numbers) |

Both inherit from `TMP_Text` base class — same API for properties and methods.

---

## Key Properties (TMP_Text base)

| Property | Type | Description |
|----------|------|-------------|
| `text` | `string` | The text content (supports rich text tags) |
| `font` | `TMP_FontAsset` | Font asset (SDF-based, not regular Unity Font) |
| `fontSize` | `float` | Font size in points |
| `fontStyle` | `FontStyles` | Bold, Italic, Underline, Strikethrough (flags) |
| `color` | `Color` | Base text color |
| `alignment` | `TextAlignmentOptions` | Horizontal + vertical alignment |
| `enableWordWrapping` | `bool` | Word wrap within bounds |
| `overflowMode` | `TextOverflowModes` | Overflow, Ellipsis, Truncate, ScrollRect, etc. |
| `richText` | `bool` | Enable/disable rich text tag parsing |
| `margin` | `Vector4` | Text margins (left, top, right, bottom) |
| `characterSpacing` | `float` | Extra spacing between characters |
| `lineSpacing` | `float` | Extra spacing between lines |
| `paragraphSpacing` | `float` | Extra spacing between paragraphs |
| `maxVisibleCharacters` | `int` | For typewriter effects |
| `textInfo` | `TMP_TextInfo` | Detailed info about rendered text (character positions, etc.) |

---

## Key Methods

| Method | Description |
|--------|-------------|
| `SetText(string)` | Set text (more efficient than `text = ""` for frequent updates) |
| `SetText(string, float)` | Format with numeric args: `SetText("HP: {0}", health)` — avoids string allocation |
| `ForceMeshUpdate()` | Force immediate mesh rebuild (useful after changing text before reading `textInfo`) |
| `GetTextInfo(string)` | Get text layout info without rendering |

### Zero-Allocation Text Updates

```csharp
// GOOD: SetText with numeric formatting — no string allocation
tmpText.SetText("Score: {0}", score);
tmpText.SetText("{0:2}", floatValue); // 2 decimal places

// BAD: String concatenation every frame — GC allocation
tmpText.text = "Score: " + score.ToString(); // Allocates every call
```

---

## Rich Text Tags

TMP supports extensive rich text markup:

| Tag | Example | Effect |
|-----|---------|--------|
| `<b>` | `<b>bold</b>` | **Bold** |
| `<i>` | `<i>italic</i>` | *Italic* |
| `<u>` | `<u>underline</u>` | Underline |
| `<s>` | `<s>strike</s>` | Strikethrough |
| `<color>` | `<color=#FF0000>red</color>` | Color (hex or named) |
| `<size>` | `<size=24>big</size>` | Font size |
| `<sprite>` | `<sprite index=0>` | Inline sprite from TMP_SpriteAsset |
| `<link>` | `<link="id">click</link>` | Clickable link (handle via TMP_LinkInfo) |
| `<mark>` | `<mark=#FFFF00AA>highlight</mark>` | Background highlight |
| `<alpha>` | `<alpha=#80>half</alpha>` | Transparency |
| `<gradient>` | `<gradient="PresetName">text</gradient>` | Color gradient |
| `<rotate>` | `<rotate=45>tilted</rotate>` | Rotate characters |
| `<cspace>` | `<cspace=5>spaced</cspace>` | Character spacing |
| `<mspace>` | `<mspace=20>mono</mspace>` | Monospace width |
| `<nobr>` | `<nobr>no break</nobr>` | Prevent word break |

---

## Font Assets

TMP uses **TMP_FontAsset** (not Unity's `Font` class directly):

1. **Create from font file**: Right-click .ttf/.otf > Create > TextMeshPro > Font Asset
2. **Font Asset Creator**: Window > TextMeshPro > Font Asset Creator
   - Set character set (ASCII, Unicode range, custom)
   - Choose atlas resolution and sampling
   - SDF rendering mode (higher = sharper but larger atlas)

### Material Presets

Each font asset has a default material. Create presets for variations:
- Right-click Font Asset > Create > TextMeshPro > Material Preset
- Customize: outline, shadow, glow, underlay, bevel
- Share same font atlas — only material properties differ

---

## Common Patterns

### Typewriter Effect

```csharp
using TMPro;
using System.Collections;

IEnumerator TypewriterEffect(TMP_Text textComponent, string fullText, float delay = 0.05f)
{
    textComponent.text = fullText;
    textComponent.maxVisibleCharacters = 0;
    textComponent.ForceMeshUpdate();

    int total = textComponent.textInfo.characterCount;
    for (int i = 0; i <= total; i++)
    {
        textComponent.maxVisibleCharacters = i;
        yield return new WaitForSeconds(delay);
    }
}
```

### Floating Damage Numbers (3D)

```csharp
// Use TextMeshPro (3D) component on a world-space object
var dmgText = Instantiate(damageTextPrefab, hitPoint, Quaternion.identity);
var tmp = dmgText.GetComponent<TextMeshPro>();
tmp.SetText("{0}", damage);
tmp.color = isCritical ? Color.red : Color.white;
tmp.fontSize = isCritical ? 8f : 5f;
// Animate up + fade via DOTween or coroutine, then pool.Release()
```

### Clickable Links

```csharp
using TMPro;
using UnityEngine.EventSystems;

public class LinkHandler : MonoBehaviour, IPointerClickHandler
{
    TMP_Text textComponent;

    void Awake() => textComponent = GetComponent<TMP_Text>();

    public void OnPointerClick(PointerEventData eventData)
    {
        int linkIndex = TMP_TextUtilities.FindIntersectingLink(
            textComponent, eventData.position, null);
        if (linkIndex >= 0)
        {
            var linkInfo = textComponent.textInfo.linkInfo[linkIndex];
            string linkId = linkInfo.GetLinkID();
            Debug.Log($"Clicked link: {linkId}");
        }
    }
}
// Usage in text: "Click <link=\"shop\">here</link> to open shop"
```

---

## TextMeshPro vs Legacy Text

| Feature | TextMeshPro | UI.Text (Legacy) |
|---------|-------------|------------------|
| Rendering | SDF (crisp at any size) | Bitmap (blurry when scaled) |
| Rich text | 20+ tags | Basic (b, i, color, size) |
| Performance | Better (SDF atlas shared) | Worse (per-font texture) |
| Outline/Shadow | Shader-based (free) | Component-based (extra draw calls) |
| Inline sprites | Supported | Not supported |
| Status | Recommended | Legacy — do not use for new projects |

**Always use TextMeshPro for new projects.** `UI.Text` is legacy.
