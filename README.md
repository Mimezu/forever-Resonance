# Resonance for Forever

Version 2.0.0-forever.11 · client interface 16001

## Automatic saving

All edits update the current working setup immediately, including sound layers, delays, rank overrides, action toggles, and organization. Loading a named set makes it the active autosaving set and fills in its name. **Save** explicitly saves over the active set, regardless of text entered in the name field. **Save as** saves under the entered name (replacing that set if it exists) and makes it active. Use a new name to create a separately editable copy. The dialog and footer identify the active set. Switching sets preserves the previous set's latest edits and keeps a recovery snapshot in **Before last load**. When no named profile is loaded, the active profile is shown as **Default** and **Save** saves it under that name. The working setup also persists automatically. WoW writes SavedVariables on normal reload/logout; this is not a crash-recovery disk journal.

The composition pass adds visible dialog titles, field hints, full-name tooltips, left-aligned layer names, contextual empty/footer text, and a labeled custom-sound form. Library browsing hides assignment buttons; use **+ Sound** on a moment to choose a sound. The library and saved-set dialogs block background clicks. Named windows handle Escape locally outside combat, so opening the spellbook does not close the editor.

## Window styles

Choose a style with the **Style** button at the bottom right of the editor, or `/res style a`, `b`, or `c`. Styles change artwork only; layout, actions and sounds are the same.

- **A · Classic** (default): Legacy reward-track leather and red panel buttons.
- **B · Legacy**: the Legacy window used by Forever Names and Petal: challenge leather, bronze plate buttons and minimal scroll bars.
- **C · Flat**: dark panels with thin borders and flat buttons.

In style A the editor uses Forever's native Legacy leather background, metal window borders, inset edges, brown section ribbons, and gold dividers. The window keeps its original size. These atlases are loaded from the client; the Legacy System window does not need to be opened. Missing atlases fall back to dark brown surfaces with muted gold edges.

Open `/res` and drag a spell, active ability, mount, or usable item into the empty slot. New actions start silent. There are no built-in action lists or default sound presets.

Choose **+ Sound** under a moment to browse the sound library. Add multiple layers, toggle them individually, and enter delays in milliseconds (0–30000). **Play layers** previews the combination. **Stop** stops Resonance's own playback; it does not mute the game's original sounds.

- **Cast:** fires when the client reports successful activation. For channels this may be at the start of the channel.
- **Casting:** starts with the cast bar; playing sounds and pending layers stop when the bar stops, fails, or is interrupted.
- **Channeling:** starts with the channel bar and stops when it ends or is interrupted.

Automatic mode uses spell cast-time metadata and the localized channel tooltip. Observing a cast/channel start refines the detection. The Type menu provides a manual override; selecting a type cannot create a cast event that the client does not emit. Proc-induced instant casts still trigger Cast without a Casting sound.

## Ranks and organization

An action shares its sounds across ranks by default. Enable **Customize ranks**, choose a rank, and edit it to create an independent copy of the shared configuration. **Reset to shared** removes that override. Turning rank customization off keeps the overrides stored but uses shared sounds again.

Ranks are discovered from your spellbook, additional drops, and observed player casts. Future or unavailable ranks aren't guessed. Ranked spells are associated using the client's localized name and rank subtext; unrelated unranked spells are not merged by name. A new discovered rank inherits the shared configuration.

Create sections at the lower left. Move an action with its section selector or drag it onto another action or section heading. Search filters your actions. Removing an action shows **Undo removal** in the footer until another removal or reload.

The current setup and named sets belong to the character and class, with no specialization or talent-profile switching. **Sound sets** names or copies the current setup, exports it, or imports a set for later loading. Imported data is parsed and validated without executing Lua; it must match the character's class. Custom sound identifiers travel in the set; custom library labels and favorites remain local.

## Sound library

The initial library contains 1,012 distinct file/kit candidates from the existing Resonance research (the precise number of symbolic sound kits can vary by client). Search by name, description, category, or identifier. Use favorites, category filtering, previews, and **Played only** to narrow it. Add your own numeric FileDataID or SoundKit ID at the bottom of the picker.

Availability is checked by playback, per client build:

- **Untried:** no playback result on this build.
- **Played:** the client's playback API accepted the sound.
- **No playback:** the client did not report successful playback.

“Played” does not prove the sound was audible at your current volume or that it has been artistically curated for an action. The inherited library has not been fully re-audited against the Forever archive. No external audio is bundled. Audio layers use the SFX channel.

## Items and limitations

Usable items are resolved to their activation spell. When the client reports that spell, Resonance plays the configured sound. Events do not identify which item caused a shared activation spell: actions with the same trigger are rejected with an explanation, and an item's spell may also trigger when activated another way. Passive items, passive abilities, and macros are rejected. An uncached item requests its details and asks you to drop it again once loaded.

Playback listens to the player's cast events, not other players or pet autocasts. The addon does not replace native audio or execute the dropped action. A sound set supports 200 actions, 40 sections, and 16 sound layers per moment.

## Persistence on this installation

`ResonanceForeverDB` is an account saved variable, partitioned by character name/realm. The `_SavedVariables.local` junction points to this installation's account SavedVariables directory. Its TOC entry reads `Resonance.lua` to work around the Forever beta save-loader issue. The bridge was created on September 19 at 18:26:43, after an initial reload at 18:26:04 reported it missing. The link now resolves to the existing saved setup.

Do not recursively delete or distribute the junction. For another installation with a working save loader, omit the bridge TOC line and junction. For another affected Forever installation, configure a local bridge to that account's save folder. Retail's `ResonanceDB` and Retail addon files are not modified.

## Commands

- `/res` or `/resonance`: toggle the editor.
- `/res on`, `/res off`: enable or disable action sounds.
- `/res style a|b|c`: switch the window style (Classic, Legacy, Flat).
- `/res stop`: stop active Resonance audio and pending layers.
- `/res help`: show a short usage reminder.

## Verification

From the client root:

```
lua Interface/AddOns/Resonance/tests/Behavior.lua
lua Interface/AddOns/Resonance/tests/UI.lua
```

Behavior checks cover rank discovery/inheritance/overrides, cursor interpretation, passive and item rejection, trigger conflicts, player-only event dispatch, delays, interruption, channel stop, late events, duplicate success events, secret values, playback results, sound filtering, set round trips, invalid imports, backups, and character separation. UI mocks exercise construction, sound assignment, rank edits, previews, set sharing, removal/undo, filters, reopening, and reuse of pooled frames. Lua 5.1 syntax is checked for all shipped Lua files. These checks don't replace live visual, audible, and reload validation.
