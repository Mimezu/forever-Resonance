# 2.0.0-forever.11

Layout and polish (all styles):

- One grid for every window: content keeps 12px from the window border on both sides, and controls in a row sit 6–8px apart.
- Header: the title is centred inside the native title bar instead of crossing its bottom line. The tagline and the toolbar (Sounds, Sound library, Sound sets, Stop) sit centred in the band below it, and the toolbar ends on the editor's right edge. The window is 8px taller, so the content keeps its size. The library and sound-set dialogs use the same header.
- Left column: the search box, action list and new-section row are exactly as wide as the drop slot. The list scroll bar sits inside its well.
- Editor: the title-row toggle, both button rows and the moment cards end on one right edge. Layer controls are anchored from the right with even gaps; "ms" is centred on the delay box.
- The left column and the editor end on the same line. A footer row below them holds the status line, Undo removal (only after a removal) and the style selector.
- Scroll bars appear only when the content overflows; rows and cards use the full width otherwise. The mouse wheel scrolls one row.
- Status messages stay for 6 seconds instead of being replaced by the next refresh, then the active-profile line returns.
- Menus tick the current choice and open scrolled to it.
- Layers that are off are dimmed; muted actions show a grey icon; Play layers is disabled on an empty moment.
- Sound library: controls close up in browse mode, playback state is coloured (Played, No playback), the pager and custom-sound row share the list's right edge, and a divider separates adding your own sound.
- Sound sets: the action row ends on the same edge as the text box.

Window styles (footer "Style" button or `/res style a|b|c`):

- A · Classic: the existing look.
- B · Legacy: the Legacy window used by Forever Names and Petal — challenge leather, bronze plate buttons, regular challenge cards with the brown ribbon, and minimal scroll bars. The leather stops above the atlas's streaked bottom rows, which tall panels such as the editor otherwise stretch into view.
- C · Flat: dark panels with thin borders and flat buttons; no client atlases.

# 2.0.0-forever.10

- Casting a spell that belongs to no action no longer builds tooltip data: misses are remembered until the actions change, and the channel check runs only for a new rank of a configured spell family.
- Spellbook rescans (SPELLS_CHANGED) identify spells by name and rank only; tooltip data is read just for new ranks of configured families.
- The per-sound playability record is rewritten only when its result changes, not on every cast.

# Unreleased

- Replace the permanent 50 Hz audio loop with one cancellable timer for the next sound or cleanup deadline. Cancel queued layers immediately on interruption and stop all scheduler work when idle.
- Coalesce spellbook scans onto one callback; defer combat scans until PLAYER_REGEN_ENABLED without polling. Add scheduler deadline, cancellation, expiry and combat tests.

- Add an explicit Save button that updates the active sound set.
- Display the active profile and Save destination in both the editor and dialog; use Default when no named profile is loaded.
- Show the active set in the dialog and synchronize the name field on load, save, and reopen.
- Keep Save as for saving under the entered name, with clear save confirmation.
- Verify saving over a loaded set and switching away and back through the UI callbacks.

# 2.0.0-forever.9

- Autosave edits directly to the active named set as well as the working setup.
- Rebind active set data after reload without replacing working edits with an older snapshot.
- Preserve previous sets when switching or using Save as; keep recovery backups independent.
- Identify the autosaving set in the footer and explain that manual saving is unnecessary.
- Cover reload, delay/rank/toggle persistence, save-as isolation, set switching, and backup recovery in regression checks.

# 2.0.0-forever.8

- Draw dialog headings above native border art so Sound library and Your sound sets titles stay visible.
- Refine empty-state typography, shorten moment descriptions, simplify action metadata, and make footer instructions reflect the current selection.
- Add search/section/set-name hints and labels for custom sound identifiers and names.
- Constrain long labels to one line, left-align layer names, and expose full sound names/details in tooltips.
- Align numeric delays; restore the last valid value after an invalid edit loses focus.
- Hide assignment buttons in library browse mode, explain how to assign sounds, and make favorites controls explicit.
- Provide no-results guidance and disable pagination controls at their limits.
- Add modal click shields, native Escape handling, and select an existing action when reopening an unselected setup.

# 2.0.0-forever.7

- Use a continuous middle strip on expanded moment cards to remove repeating gaps in the side borders, retaining fixed-size top and bottom caps.

# 2.0.0-forever.6

- Restore native square 24-pixel close buttons and anchor them at the top-right border.
- Pack the main title-bar controls beside the close button with consistent two-pixel gaps.

# 2.0.0-forever.5

- Match the darker Legacy challenge reference using its native incomplete-card textures, muted teal ribbon, and softer gray moment text.
- Keep the existing gold card edges, layout, and active controls.

# 2.0.0-forever.4

- Wrap Cast, Casting, and Channeling in the native Legacy challenge card artwork.
- Expand each card around its sound layers with tiled sides, fixed border caps, and inset controls.

# 2.0.0-forever.3

- Remove the opaque fallback rectangle when native borders are present.
- Inset window backgrounds, header bands, and header dividers to the visible gold border so they no longer protrude around it.
- Align the main header buttons within the native title strip.

# 2.0.0-forever.2

- Style the editor, sound library, and saved-set dialog with native Forever/Legacy textures.
- Use the Legacy reward-track background, native metal and inset borders, brown section ribbons, and Legacy vertical divider.
- Add warm action selection, framed icons, and native close buttons while retaining editor dimensions and control positions.
- Keep readable fallback surfaces if a future client removes an atlas.

# 2.0.0-forever.1

- New Forever action editor: drag actions into an empty setup; no predefined spell list or presets.
- Automatic instant/cast/channel detection with manual type selection.
- Shared rank sounds with optional independent rank configurations and reset-to-shared.
- Layered sound selection, delays, previews, favorites, search, categories, and custom identifiers.
- Per-build playback results for the inherited sound library.
- User-defined sections, action reordering, remove/undo, and character sound snapshots.
- Validated class-matching set import/export and automatic backup before loading a set.
- Cast/channel interruption cleanup, success-event deduplication, and shared item-trigger conflict messages.
- Installation-specific saved-variable bridge completed after the initial missing-file reload report.
