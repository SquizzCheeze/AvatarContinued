# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Avatar Continued** is a World of Warcraft addon that displays the player's character model on-screen as a decorative UI element. The model can be moved, scaled, rotated, and customized with lighting/animations.

- **Interface version**: 120100 (Midnight/12.0+)
- **Dependencies**: Ace3 libraries bundled in `/libs` (LibStub, CallbackHandler, AceAddon, AceDB, AceEvent, AceHook, AceGUI, AceConfig)
- **SavedVariables**: `AvatarDB` (profile-based)

## Architecture

### Core Files

| File | Purpose |
|------|---------|
| `core.lua` | Main addon logic: initialization, model handling, equipment/lighting/animation, frame positioning, race-specific offsets, slash commands |
| `events.lua` | Event handlers: `PLAYER_ENTERING_WORLD`, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_AURA`, `UNIT_MODEL_CHANGED` |
| `options.lua` | Legacy custom options panel (kept for profile management, popups, and widget helpers) |
| `settings.lua` | **Modern Settings API (12.0+) panel**: three-column layout with live avatar preview, all 29 settings registered via `Settings.RegisterAddOnSetting()`, real-time preview updates, AceDB sync |
| `settings.xml` | XML frame templates: `AvatarSettingsPanel` (SettingsPanelTemplate), category buttons, preview frame with embedded DressUpModel |
| `AvatarFrame.xml` | XML frame definitions: `AvatarModelFrame` (DressUpModel), `AvatarInstructionsFrame` (unlock overlay) |

### Key Objects

- **`Addon`** (global): AceAddon-3.0 instance with AceEvent-3.0, AceHook-3.0 mixins
- **`AvatarModelFrame`**: DressUpModel frame showing player unit, handles mouse drag/resize/rotate
- **`AvatarInstructionsFrame`**: Overlay shown when frame is unlocked with lock button

### Data Flow

1. `OnInitialize()` → sets up DB defaults, slash commands (`/avatar`, `/av`), registers profile callbacks
2. `OnEnable()` → registers events, calls `RefreshAvatar()`
3. `RefreshAvatar()` → `SetUnit("player")`, updates race positioning, refreshes frame
4. `SetFrameSettings()` → applies position, size, strata, level, facing, alpha, lighting
5. Equipment toggles (`show.weapon`, `show.armor`, etc.) → `RefreshEquipmentToggle()` dresses/undresses slots
6. **Settings Panel** (`/avatar`): Opens WoW Settings API panel with three-column layout
   - `ShowSettingsPanel()` → `Settings.OpenToCategory()` opens the registered panel
   - Category clicks → show/hide settings groups in center column
   - Setting changes → `Settings.SetOnValueChangedCallback()` → `HandleSettingChange()` → AceDB write + `ApplySettingToPreview()`
   - Profile change → `OnProfileChanged()` → `RefreshAllSettingsFromDB()` syncs Settings API widgets

### Race/Gender Positioning

`RACE_POSITIONS` table (core.lua:299-382) contains per-race/gender camera offsets. Fallback to `[0]` default.

### Lighting

Spherical coordinates (yaw/pitch) converted to Cartesian in `UpdateLightDirection()`. Applied via `SetLight()` with ambient + diffuse components.

### Profiles

- Per-character profiles: `"Name - Realm"`
- Global profile: `"Global Profile"` (shared across characters)
- Profile changes trigger `OnProfileChanged` → `RefreshAvatar()` + UI refresh

## Slash Commands

| Command | Description |
|---------|-------------|
| `/avatar` or `/av` | Open options panel |
| `/avatar toggle` | Toggle avatar visibility |
| `/avatar toggle weapon\|armor\|tabard` | Toggle equipment visibility |
| `/avatar profile [name]` | Switch profile |
| `/avatar equip [itemlink]` | Try on item on model |
| `/avatar unlock` | Unlock frame for positioning |
| `/avatar lock` | Lock frame |
| `/avatar help` | Show usage |

## Development Notes

### No Build/Lint/Test System

This is a pure Lua WoW addon. There are no build tools, linters, or test frameworks. Development workflow:

1. Edit `.lua`/`.xml` files directly
2. Reload UI in-game (`/reload`) to test changes
3. Use `/avatar` to open settings panel (new Settings API panel with live preview)

### Settings API Panel Architecture (settings.lua + settings.xml)

The modern settings panel uses WoW's **Settings API (12.0+)** with a **three-column layout**:
- **Left column**: Category list (General, Display, Frame Settings, Miscellaneous, Animation, Lighting, Profiles)
- **Center column**: Scrollable settings controls for the selected category (created via `Settings.Create*Initializer()`)
- **Right column**: Live avatar preview using `DressUpModel` that updates in real-time

Settings are registered via `Settings.RegisterAddOnSetting()` and use the **secret/secure value system** (`Settings.SettingFlags.Secure`) for profile operations.

To add a new setting:
1. Add entry to `SETTING_META` table in `settings.lua` (variable name, DB path, type, default)
2. Add default to `defaults.profile` in `core.lua`
3. Add UI control in the appropriate `Build*Settings()` function using `RegisterAVSetting()` + `Settings.Create*Initializer()`
4. Add apply logic in `Addon:ApplySettingToPreview()` in `settings.lua`
5. Add sync in `RefreshAllSettingsFromDB()` if it needs special handling

### Key Patterns

- **Frame lock/unlock**: `LockFrame()` / `UnlockFrame()` toggle mouse/strata/backdrop visibility
- **Position saving**: `SavePosition()` called on mouse up, stores point/relativePoint/x/y + width/height/facing
- **Animation handling**: `ApplyAnimation()` sets animation ID, loops non-looping animations via `OnAnimFinished`
- **Conditional hide**: Aura 176438 (likely a specific buff) triggers full undress in `UpdateConditionalToggle()`

### Libraries (bundled in `/libs`)

Ace3 libraries are embedded via `@no-lib-strip@` in TOC. Do not modify library files directly — update via Ace3 releases if needed.