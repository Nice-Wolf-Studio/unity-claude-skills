# PropertyDrawers in Unity 6.3

## Overview

PropertyDrawers customize how serialized fields appear in the Inspector. They serve two purposes:

1. **Custom attribute drawers** -- per-field customization using a `PropertyAttribute`
2. **Serializable class drawers** -- control rendering of all instances of a `[Serializable]` class

PropertyDrawer scripts **must** be placed in an `Editor/` folder.

**Source:** [PropertyDrawers Manual](https://docs.unity3d.com/6000.3/Documentation/Manual/editor-PropertyDrawers.html) | [PropertyDrawer API](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/PropertyDrawer.html)

---

## PropertyDrawer API

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `attribute` | PropertyAttribute | The attribute instance (null for class drawers) |
| `fieldInfo` | FieldInfo | Reflection info for the field |
| `preferredLabel` | string | The display label for this property |

### Methods to Override

| Method | Framework | Description |
|--------|-----------|-------------|
| `CreatePropertyGUI(SerializedProperty)` | UI Toolkit | Returns a VisualElement (recommended) |
| `OnGUI(Rect, SerializedProperty, GUIContent)` | IMGUI | Draw the property in a given rect |
| `GetPropertyHeight(SerializedProperty, GUIContent)` | IMGUI | Return pixel height for the property |

**Important:** UI Toolkit and IMGUI cannot be mixed within a single PropertyDrawer. Choose one.

---

## Custom Attribute + Drawer (IMGUI)

### Step 1: Define the PropertyAttribute

This goes in runtime code (outside `Editor/` folder) so it can be used on MonoBehaviour fields.

```csharp
using UnityEngine;

public class MyRangeAttribute : PropertyAttribute
{
    public readonly float min;
    public readonly float max;

    public MyRangeAttribute(float min, float max)
    {
        this.min = min;
        this.max = max;
    }
}
```

### Step 2: Implement the PropertyDrawer

This goes in an `Editor/` folder.

```csharp
using UnityEditor;
using UnityEngine;

[CustomPropertyDrawer(typeof(MyRangeAttribute))]
public class MyRangeDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        MyRangeAttribute range = (MyRangeAttribute)attribute;

        if (property.propertyType == SerializedPropertyType.Float)
            EditorGUI.Slider(position, property, range.min, range.max, label);
        else if (property.propertyType == SerializedPropertyType.Integer)
            EditorGUI.IntSlider(position, property, (int)range.min, (int)range.max, label);
        else
            EditorGUI.LabelField(position, label.text, "Use MyRange with float or int.");
    }
}
```

### Step 3: Use on Fields

```csharp
public class Enemy : MonoBehaviour
{
    [MyRange(0f, 100f)]
    public float health = 50f;

    [MyRange(1, 10)]
    public int level = 1;
}
```

---

## Custom Attribute + Drawer (UI Toolkit)

### PropertyAttribute (same as IMGUI)

```csharp
using UnityEngine;

public class ClampedAttribute : PropertyAttribute
{
    public readonly float min;
    public readonly float max;

    public ClampedAttribute(float min, float max)
    {
        this.min = min;
        this.max = max;
    }
}
```

### UI Toolkit Drawer

```csharp
using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine.UIElements;

[CustomPropertyDrawer(typeof(ClampedAttribute))]
public class ClampedDrawer : PropertyDrawer
{
    public override VisualElement CreatePropertyGUI(SerializedProperty property)
    {
        var clamped = (ClampedAttribute)attribute;

        var slider = new Slider(preferredLabel, clamped.min, clamped.max);
        slider.BindProperty(property);
        return slider;
    }
}
```

---

## Serializable Class Drawer

Draw all instances of a `[Serializable]` class in a custom way.

### The Serializable Class (runtime code)

```csharp
using System;
using UnityEngine;

[Serializable]
public class Ingredient
{
    public string name;
    public int amount = 1;
    public IngredientUnit unit;
}

public enum IngredientUnit
{
    Spoon,
    Cup,
    Bowl,
    Piece
}
```

### The Drawer (Editor folder)

```csharp
using UnityEditor;
using UnityEngine;

[CustomPropertyDrawer(typeof(Ingredient))]
public class IngredientDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        // Begin the property (handles prefab overrides, right-click menu)
        EditorGUI.BeginProperty(position, label, property);

        // Draw label and get remaining rect
        position = EditorGUI.PrefixLabel(position, GUIUtility.GetControlID(FocusType.Passive), label);

        // Don't indent child fields
        int indent = EditorGUI.indentLevel;
        EditorGUI.indentLevel = 0;

        // Calculate rects
        float totalWidth = position.width;
        var nameRect = new Rect(position.x, position.y, totalWidth * 0.4f, position.height);
        var amountRect = new Rect(position.x + totalWidth * 0.42f, position.y, totalWidth * 0.2f, position.height);
        var unitRect = new Rect(position.x + totalWidth * 0.64f, position.y, totalWidth * 0.36f, position.height);

        // Draw fields
        EditorGUI.PropertyField(nameRect, property.FindPropertyRelative("name"), GUIContent.none);
        EditorGUI.PropertyField(amountRect, property.FindPropertyRelative("amount"), GUIContent.none);
        EditorGUI.PropertyField(unitRect, property.FindPropertyRelative("unit"), GUIContent.none);

        // Restore indent
        EditorGUI.indentLevel = indent;

        EditorGUI.EndProperty();
    }
}
```

### Usage

```csharp
public class Recipe : MonoBehaviour
{
    public Ingredient[] ingredients;  // Each element uses IngredientDrawer
}
```

---

## Multi-Line / Variable Height Drawer

Override `GetPropertyHeight()` to change the vertical space allocated for IMGUI drawers.

```csharp
[CustomPropertyDrawer(typeof(NoteAttribute))]
public class NoteDrawer : PropertyDrawer
{
    public override float GetPropertyHeight(SerializedProperty property, GUIContent label)
    {
        // Default property height + extra space for the note
        return EditorGUIUtility.singleLineHeight * 2 + 4;
    }

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        var noteAttr = (NoteAttribute)attribute;

        // Top line: the note text
        var noteRect = new Rect(position.x, position.y, position.width, EditorGUIUtility.singleLineHeight);
        EditorGUI.LabelField(noteRect, noteAttr.text, EditorStyles.miniLabel);

        // Bottom line: the actual property
        var propRect = new Rect(position.x, position.y + EditorGUIUtility.singleLineHeight + 2,
            position.width, EditorGUIUtility.singleLineHeight);
        EditorGUI.PropertyField(propRect, property, label);
    }
}
```

---

## DecoratorDrawer

DecoratorDrawers add visual elements before a property without replacing the property itself. Unity's built-in `[Header]` and `[Space]` are DecoratorDrawers.

### Custom DecoratorDrawer

```csharp
// Attribute (runtime)
using UnityEngine;

public class SeparatorAttribute : PropertyAttribute
{
    public readonly float height;
    public readonly Color color;

    public SeparatorAttribute(float height = 1f, float r = 0.5f, float g = 0.5f, float b = 0.5f)
    {
        this.height = height;
        this.color = new Color(r, g, b);
    }
}
```

```csharp
// Drawer (Editor folder)
using UnityEditor;
using UnityEngine;

[CustomPropertyDrawer(typeof(SeparatorAttribute))]
public class SeparatorDrawer : DecoratorDrawer
{
    public override float GetHeight()
    {
        var sep = (SeparatorAttribute)attribute;
        return sep.height + 8f; // padding above and below
    }

    public override void OnGUI(Rect position)
    {
        var sep = (SeparatorAttribute)attribute;
        var lineRect = new Rect(position.x, position.y + 4f, position.width, sep.height);

        EditorGUI.DrawRect(lineRect, sep.color);
    }
}
```

### Usage

```csharp
public class MyComponent : MonoBehaviour
{
    public float speed = 5f;

    [Separator(2f, 0.8f, 0.2f, 0.2f)]
    public int health = 100;
}
```

---

## Prefab Override Support

Always wrap property drawing in `BeginProperty` / `EndProperty` to maintain prefab override styling (bold labels for overridden values, right-click revert menu):

```csharp
public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
{
    EditorGUI.BeginProperty(position, label, property);

    // All drawing between Begin/End preserves prefab override behavior
    EditorGUI.PropertyField(position, property, label);

    EditorGUI.EndProperty();
}
```

---

## Built-in PropertyAttributes Reference

Unity provides several built-in attributes that use PropertyDrawers internally:

| Attribute | Effect |
|-----------|--------|
| `[Range(min, max)]` | Slider control for numeric fields |
| `[Multiline(lines)]` | Multi-line text area |
| `[TextArea(min, max)]` | Scrollable text area |
| `[ColorUsage(showAlpha, hdr)]` | Color picker configuration |
| `[GradientUsage(hdr)]` | Gradient editor configuration |
| `[Header("text")]` | Bold label above the field (DecoratorDrawer) |
| `[Space(pixels)]` | Vertical spacing (DecoratorDrawer) |
| `[Tooltip("text")]` | Hover tooltip |
| `[HideInInspector]` | Hide from Inspector |
| `[Min(value)]` | Minimum value clamp |
| `[Delayed]` | Only apply value on Enter/focus loss |

---

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Using `EditorGUILayout` in PropertyDrawer | Not supported, causes layout errors | Use `EditorGUI` with `Rect` positions |
| Forgetting `EditorGUI.BeginProperty/EndProperty` | Prefab overrides and context menus break | Always wrap property drawing |
| Mixing UI Toolkit and IMGUI in one drawer | Not supported | Choose one framework |
| Drawer not in `Editor/` folder | Build error on target platform | Move to `Editor/` folder |
| Not handling wrong property type | Errors when attribute used on wrong field type | Check `property.propertyType` and show a warning |
| Hardcoded height without `GetPropertyHeight` | Content clips or overlaps | Override `GetPropertyHeight()` for multi-line drawers |
| Modifying `EditorGUI.indentLevel` without restoring | Indentation leaks to subsequent properties | Save and restore indent level |
