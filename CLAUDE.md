# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Avatar Continued** displays the player's character model on screen as a decorative UI element. It revives the 8.0-era Avatar addon for WoW 12.1, with the original author's permission, so parts of it are old code patched forward: expect to verify anything API-related rather than trust it.

- **Interface**: 120100. **SavedVariables**: `AvatarDB` (AceDB profiles, plus `char.outfitPreview`)
- **Addon name** comes from the folder (`Avatar`): `core.lua` does `NewAddon(addon_name)` and `_G[addon_name] = Addon`. The folder name is load-bearing; `.pkgmeta`'s `package-as: Avatar` keeps it.
- **Libraries** (vendored in `libs/`): LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceEvent-3.0. Nothing else is used. Do not add AceHook/AceGUI/AceConfig back "just in case": an old copy of a shared library that loads first sets the version for every addon.
- **Verify APIs against Blizzard's source**, `Gethe/wow-ui-source`, and check the branch first (`live` was 12.1.0 build 69814 when this was last audited, 2026-09-14). The addon was fully audited against it then.

## Files

| File | Purpose |
|------|---------|
| `core.lua` | Addon object, DB defaults, model setup (`SetupModel`/`CaptureBaseline`/`ApplyAppearance`), visibility, lighting, per-race positioning and camera zoom, animation, the undress-aura check |
| `events.lua` | Event handlers, and the player-only `playerAuraWatcher` frame (registered in `OnEnable`) |
| `options.lua` | Profile popups and helpers, frame lock/unlock/save, the `/avatar` console handler |
| `settings.lua` | The settings window (custom three-column dialog with a live preview model) and the Options > AddOns launcher page |
| `settings.xml` | Templates for the settings window: category buttons, preview frame (inherits `BackdropTemplate`) |
| `AvatarFrame.xml` | `AvatarModelFrame` (DressUpModel) and `AvatarInstructionsFrame` (unlock overlay) |
| `welcome.lua` | First-run greeting and the once-per-update release notes (`RELEASE_NOTES`, `/avatar notes`). Ported from SquizzFrames/Squizzumables. New install vs upgrade comes from `Addon.hadSavedVariables`, snapshotted as the FIRST line of `OnInitialize`: WoW runs an addon's files before loading its SavedVariables (so a file-load check always sees nil), and `AceDB:New` creates `AvatarDB` right after (so a later check always sees a table). Stores `lastSeenVersion` on the `AvatarDB` root, outside profiles |

## How the model is dressed (read before touching appearance code)

- **`SetUnit("player")` runs exactly once per model widget.** Repeating it, or mixing it with `Dress()`/`TryOn()`, corrupts face geosets on some races (Vulpera). Setup is gated on `IsUnitModelReadyForUI("player")` and retried from `UNIT_MODEL_CHANGED`/`OnShow`, not timers.
- **Appearance is applied declaratively.** `CaptureBaseline` snapshots the model's `GetItemTransmogInfoList()` right after setup (deep-copied: the list holds live objects). `ApplyAppearance` then writes every slot with `SetItemTransmogInfo` or `UndressSlot`, from either that baseline or a saved outfit (`C_TransmogCollection.GetCustomSetItemTransmogInfoList`).
- **`SetKeepModelOnHide(true)`** on both models: without it the client discards the model when UIParent hides (ElvUI's AFK screen) and reloads it through the geoset-corrupting path.
- **Dressing a model fires `OnModelLoaded` synchronously.** `AvatarModelFrame_OnModelLoaded` has a `_modelLoadedBusy` guard, reset under pcall. The preview model's handler has NO guard, so it must never call anything that re-dresses (`RefreshEquipmentOnModel`). That would be an infinite loop, surfacing as a C stack overflow.
- **`OnAnimFinished` restarts the animation on the next frame**, never inside the handler, for the same reason.
- **Model alpha does not survive every rebuild.** Every path that changes the model re-applies `SetModelAlpha` straight afterwards, yet the avatar intermittently came back at full opacity with no pinnable trigger (V1.10): a piece that finishes loading later can reset it with no `OnModelLoaded` to answer. `AlphaWatch` (a 1s `OnUpdate` hooked in `AvatarModelFrame_OnLoad`) re-asserts the configured alpha while shown and below 1 — unconditionally, since `GetModelAlpha` may keep reporting the stored value after the reset. The nested `OnModelLoaded` also applies alpha before its re-entrancy bail. User-confirmed holding; if it ever recurs, the watch was a symptom fix, not the cause.

## 12.1 rules this addon has already hit

- **Auras are secret while restrictions are in effect** (combat, encounters, M+, PvP). `C_UnitAuras.GetPlayerAuraBySpellID` is `SecretWhenUnitAuraRestricted` + `RequiresNonSecretAura`, so it returns *nothing* then. `Addon:PlayerHasAura` returns `nil` ("unknown") via `C_Secrets.ShouldAurasBeSecret`/`ShouldSpellAuraBeSecret`; callers must treat nil as "leave it alone", not "no aura".
- **Never register the settings window as a Settings canvas.** `SettingsPanelMixin:ClearCurrentCategoryCanvas` calls `SetParent(nil)` + `ClearAllPoints()` + `Hide()` on a canvas frame when you leave its category. The registered canvas is a separate launcher page at the bottom of `settings.lua`.
- **StaticPopup:** the edit box is `dialog:GetEditBox()` (not `dialog.editBox`); `sound` must be a `SOUNDKIT` id; pass per-show state as `StaticPopup_Show`'s 4th argument (`data`), which arrives as `OnAccept`'s 2nd parameter.
- **Colour picker:** `ColorPickerFrame:SetupColorPickerAndShow(info)`; `cancelFunc` receives `previousValues`. `SetupRGB` does not exist.
- **Dropdowns:** `WowStyle1DropdownTemplate` + `SetupMenu`/`CreateRadio`/`CreateButton`, never `UIDropDownMenu` (legacy, and a taint source). Tooltips go on with `HookScript`, since the template owns `OnEnter`/`OnLeave`.
- **Deprecated templates** live in `Blizzard_FrameXML/DeprecatedTemplates.xml`; check there before using an old template name. Sliders use `UISliderTemplateWithLabels`.
- **Pushing values into widgets fires their change handlers.** `RefreshAllSettingsFromDB` sets `syncingFromDB` so sliders don't write rounded values back.
- **AceDB** errors on deleting the active profile or copying a profile onto itself; `DeleteProfileByName` switches profile first.

## Development

No build, lint or test tooling ships with the addon. Edit in place, `/reload` in game (log out for TOC/XML changes). The VS Code Lua language server can do a syntax/error pass from the command line:

```sh
"$USERPROFILE/.vscode/extensions/sumneko.lua-3.19.1-win32-x64/server/bin/lua-language-server.exe" --check="<addon folder>" --checklevel=Error
```

- **Never write code with backslashes, `%` or `$` through `sed`/`perl`**: they mangle escapes (a font path becomes an invalid escape that only fails at runtime). Use the Edit/Write tools.
- **XML comments cannot contain a double dash**; it breaks the whole file with an unrelated-looking error. Reword prose so none appear inside `<!-- -->`.

## Releasing

Tagging is what publishes; pushes to `main` never reach CurseForge. `.github/workflows/release.yml` (BigWigsMods/packager) builds the zip on a `v*` tag, uploads it to CurseForge (project **1533608**, read from `## X-Curse-Project-ID` in the TOC) and attaches it to a GitHub release. It needs a `CF_API_TOKEN` repository secret; `GITHUB_TOKEN` is automatic.

- **`changelog.txt` holds only the version being built.** The packager uploads it verbatim as that release's notes. When a version has shipped, move its section to the top of `CHANGELOG-ARCHIVE.txt` (ignored by `.pkgmeta`, never ships) before starting the next one.
- **The top changelog section stays open (no date) until the user says to ship.** Work accumulates there; closing it is part of tagging.
- **Changelog entries are for players**: name the visible symptom. Metadata, CI, library bumps and docs get a commit message, not a changelog line.
- **`## Version:` is a literal in the TOC** (not `@project-version@`), because development happens in the live AddOns folder where a placeholder would show in game. Bump it by hand.

To ship:

1. Bump `## Version:` in `Avatar.toc` if needed; make sure `changelog.txt` covers exactly this version.
2. Add a `RELEASE_NOTES["<version>"]` entry in `welcome.lua`: a few player-facing highlights, NOT a copy of the changelog. A missing entry is not fatal (the update note still appears, without bullets), which is exactly why it is easy to forget. It is keyed by the TOC version string, so adding it early is harmless.
3. Dry run first: Actions > "Package and release" > Run workflow with `dry_run` ticked. Nothing uploads; the zip comes back as an artifact.
4. `git tag -a v1.7 -m "Avatar Continued 1.7"` and `git push origin v1.7` (substitute the version being shipped).

Three failure modes a green checkmark will not show (all hit on the sibling addons first; Squizzumables' CLAUDE.md has the original writeups):

- **Tags must be annotated (`-a`).** `git describe` ignores lightweight tags, so the packager ships an *alpha* named after the commit hash.
- **`actions/upload-artifact` skips hidden paths** and the packager builds into `.release/`; the workflow sets `include-hidden-files: true`.
- **`release.sh` skips a missing token silently and exits 0.** Look for `CurseForge ID: 1533608 [token set]` in the log; no suffix means the token is empty. The dry run also prints both secrets' lengths. But a green run with nothing on CurseForge's *public* API is not proof of a missing token: new files sit in approval and are invisible there. Check the author dashboard first.

Tags list newest-first because the repo sets `git config tag.sort -creatordate` (local config; re-run it in a fresh clone). Versions like `1.10` sort before `1.9` alphabetically.

## Slash commands

| Command | Description |
|---------|-------------|
| `/avatar`, `/av` | Open the settings window |
| `/avatar toggle [weapon\|armor\|tabard]` | Toggle the avatar, or one part of the gear |
| `/avatar profile <name>` | Switch profile (case-sensitive) |
| `/avatar equip <link\|itemID\|itemID:bonusID>` | Try an item on the avatar |
| `/avatar unlock`, `/avatar lock` | Unlock to move/resize/rotate with the mouse |
| `/avatar notes` (or `changelog`) | Re-open the current release notes |
| `/avatar help` | Usage |
