# Vassilis DungeonPlaner 0.4.0

A German and English event planner for **WoW: Forever**, targeting Interface **16001**. Plan raids, dungeons and other events, manage signups and invite friends, with or without a guild.

This version has been tested with simulated WoW APIs. Compatibility and layout in the actual Forever client still need an in-game check.

## Install and open

1. Close WoW.
2. Copy `VassilisDungeonPlaner` to your client's `Interface/AddOns` directory. The final path must be `Interface/AddOns/VassilisDungeonPlaner/VassilisDungeonPlaner.toc`.
3. Enable **Vassilis DungeonPlaner** in the addon list.
4. Use `/vdp` or click the VDP minimap icon. `/dungeonplaner`, `/gb` and `/guildboard` also work.

For an existing installation using the `VassilisDungeonPlaner` folder, replace the addon files while WoW is closed and keep the SavedVariables. Version 0.4.0 retains the data format and sync protocol of 0.3.0.

**Moving from the old GuildBoard folder:** Close WoW and back up your WTF folder. If present, copy `WTF/Account/<Account>/SavedVariables/GuildBoard.lua` to `VassilisDungeonPlaner.lua` in the same directory. Keep the contents, including `GuildBoardDB`, unchanged. Keep the original as a backup. If the destination already exists, compare the saved data before replacing anything. Move the old `GuildBoard` addon folder outside `Interface/AddOns`, then install the new folder. Do not run both copies together. Repeat for each account you use.

## Choose a language

The default is **Automatic**: German clients use German, all other client languages use English.

Open `/vdp` and click **Language: …** (or **Sprache: …**) in the top-right corner. Choose **Automatic / Automatisch**, **Deutsch** or **English**. The UI updates immediately without a reload. The preference applies to all characters on this WoW account and is saved on `/reload`, normal logout or exit.

Menus, dialogs, roles, statuses, calendar labels, tooltips, errors, reminders and outgoing whisper invitations use the selected language. Event titles, descriptions, character names and notes remain as entered. Players using different addon languages can sync with each other.

The empty search field displays **Search …**. The hint stays visible while the field is focused, disappears when you type and returns when you clear the text.

## Plan and join events

- Create an event with a title, activity, date, local time, 1–40 slots and a description. Choose guild visibility or invitation-only visibility when creating it.
- Click **Your signup** to choose Tank, Healer or DPS and accept, decline or answer Maybe. Click **Save** to submit.
- The event creator manages confirmations and standby. Accepting an invitation or signing up does not guarantee a confirmed slot. Changing a confirmed signup requires a new confirmation.
- Use **+ Participant / invitation** to add someone manually. **Save** only saves their entry; **Send invitation** also requests a whisper invitation.
- Addon users open `/vdp invites`, open the event and then sign up. Players without the addon can reply to the organizer with `Accept A7B2C3 Healer`, `Maybe A7B2C3` or `Decline A7B2C3`, using their actual invitation code. Tank and DPS also work. German response and role names are accepted regardless of your language setting.
- Use the filters and search box to find events. Right-click the minimap icon or use `/vdp sync` to request a sync.

## Sync and storage

Data is stored locally; there is no central server. Guild members exchange event copies through addon messages. External guests sync their invited events directly with the organizer, so both must be reachable online. Normal whispers are not offline mail, and players without the addon do not receive automatic updates for changed times or cancellations.

Times are displayed in each player's local time. Whisper invitations explicitly use the organizer's local time. Reminders appear in chat during the last 15 minutes before an event while WoW is running.

See [the detailed German guide](README.md) for migration notes, sync limitations and an in-game test checklist.
