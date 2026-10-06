"""Run with Python and lupa (Lua 5.1); no WoW client or network required."""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".test-deps"))
from lupa.lua51 import LuaRuntime

ADDON = ROOT / "VassilisDungeonPlaner"


class LocalizationTests(unittest.TestCase):
    def boot(self, client="deDE", preference=None, saved=None, player="Organizer"):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((ROOT / "tests" / "wow_mock.lua").read_text(encoding="utf-8"))
        lua.globals().clientLocale = client
        lua.globals().playerName = player
        lua.globals().GuildBoardDB = saved or lua.table()
        if preference is not None:
            lua.globals().GuildBoardDB.language = preference
        gb = lua.table()
        lua.globals().GB = gb
        for line in (ADDON / "VassilisDungeonPlaner.toc").read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                lua.execute((ADDON / line.strip()).read_text(encoding="utf-8"), "VassilisDungeonPlaner", gb)
        lua.execute('GB.Transport.frame.scripts.OnEvent(nil, "ADDON_LOADED", "VassilisDungeonPlaner"); GB.Transport.frame.scripts.OnEvent(nil, "PLAYER_LOGIN")')
        return lua

    def test_client_defaults_override_and_fallback(self):
        for client, expected in [("deDE", "deDE"), ("enUS", "enUS"), ("enGB", "enUS"), ("frFR", "enUS")]:
            lua = self.boot(client)
            self.assertEqual(lua.eval("GB.Locale.Current()"), expected)
            self.assertEqual(lua.eval("GuildBoardDB.language"), "auto")
            lua.execute('assert(GB.Locale.SetPreference("deDE"))')
            self.assertEqual(lua.eval('GB.L("ROLE_HEALER")'), "Heiler")
            lua.execute('assert(GB.Locale.SetPreference("enUS"))')
            self.assertEqual(lua.eval('GB.L("ROLE_HEALER")'), "Healer")
            lua.execute('assert(not GB.Locale.SetPreference("invalid")); assert(GB.Locale.SetPreference("auto"))')
            self.assertEqual(lua.eval("GB.Locale.Current()"), expected)
        self.assertEqual(self.boot("deDE", "broken").eval("GB.Locale.Current()"), "deDE")

    def test_catalogs_complete_and_formats_match(self):
        lua = self.boot()
        english = dict(lua.eval("GB.Locale.translations.enUS"))
        german = dict(lua.eval("GB.Locale.translations.deDE"))
        self.assertEqual(english.keys(), german.keys())
        for key in english:
            self.assertTrue(english[key] and german[key])
            # Date patterns intentionally differ; ordinary message placeholders must match.
            if not key.startswith("DATE_"):
                self.assertEqual(re.findall(r"%[sd]", english[key]), re.findall(r"%[sd]", german[key]), key)
        for file in ADDON.glob("*.lua"):
            for key in re.findall(r'(?:\bL|textKey)\("([A-Z_]+)"', file.read_text(encoding="utf-8")):
                self.assertIn(key, english, str(file))

    def test_live_language_controls_and_search_placeholder(self):
        lua = self.boot()
        lua.execute('''
            GB.UI.Toggle()
            assert(GB.UI.searchHint:GetText() == "Suche …")
            assert(GB.UI.searchHint.parent == GB.UI.searchBox.shell)
            assert(GB.UI.searchHint:IsShown())
            GB.UI.searchBox:SetFocus()
            assert(GB.UI.searchHint:IsShown())
            GB.UI.searchBox:SetText("Onyxia")
            assert(not GB.UI.searchHint:IsShown())
            click(GB.UI.languageButton)
            click(GB.UI.languagePanel.buttons.enUS)
            assert(GuildBoardDB.language == "enUS")
            assert(GB.UI.languageButton.text:GetText() == "Language: English")
            assert(GB.UI.newButton.text:GetText() == "+  Create event")
            assert(GB.UI.filters.ALL.text:GetText() == "All")
            assert(GB.UI.searchHint:GetText() == "Search …")
            assert(not GB.UI.searchHint:IsShown())
            assert(GB.UI.searchBox:GetText() == "Onyxia")
            GB.UI.searchBox:SetText("")
            assert(GB.UI.searchHint:IsShown())
            GB.UI.searchBox:ClearFocus()
            assert(GB.UI.searchHint:IsShown())
            click(GB.UI.historyButton)
            click(GB.UI.languagePanel.buttons.deDE)
            assert(GB.UI.historyButton.text:GetText() == "Vergangene: an")
            click(GB.UI.languagePanel.buttons.auto)
            assert(GuildBoardDB.language == "auto")
            assert(GB.UI.languageButton.text:GetText() == "Sprache: Automatisch")
            assert(GB.UI.languagePanel.buttons.auto.selected)
        ''')

    def test_editors_calendar_tooltips_and_confirmation_in_both_languages(self):
        lua = self.boot()
        lua.execute('''
            GB.UI.Toggle()
            for _, preference in ipairs({ "deDE", "enUS", "deDE" }) do
                GB.Locale.SetPreference(preference)
                local en = preference == "enUS"
                GB.UI.OpenEditor()
                assert(GB.UI.editor.save.text:GetText() == (en and "Save event" or "Termin speichern"))
                GB.UI.editor.title:SetText("Onyxia / Eigener Titel")
                GB.UI.editor.note:SetText("Treffpunkt / Meeting point")
                click(GB.UI.editor.day)
                assert(GB.UI.editor.datePicker.heading:GetText() == (en and "October 2026" or "Oktober 2026"))
                click(GB.UI.editor.datePicker.tomorrow)
                assert(GB.UI.editor.hour:GetText() == "20:00")
                click(GB.UI.editor.save)
                local id = GB.UI.selected
                assert(GB.model:GetEvent(id).title == "Onyxia / Eigener Titel")
                GB.UI.OpenGuest(GB.actor)
                assert(GB.UI.guestEditor.roles.HEALER.text:GetText() == (en and "Healer" or "Heiler"))
                assert(GB.UI.guestEditor.note.hint:GetText() == (en and "For example: I will be ten minutes late." or "Zum Beispiel: Bin zehn Minuten später da."))
                click(GB.UI.guestEditor.roles.HEALER)
                click(GB.UI.guestEditor.answers.YES)
                click(GB.UI.guestEditor.decisions.CONFIRMED)
                click(GB.UI.guestEditor.save)
                assert(GB.model:Status(id, GB.actor) == "CONFIRMED")
                assert(GB.UI.people[1].role:GetText() == (en and "Healer" or "Heiler"))
                GB.UI.people[1].scripts.OnEnter(GB.UI.people[1])
                GB.UI.OpenInvites()
                assert(GB.UI.inviteEmpty:GetText() == (en and "No pending invitations." or "Noch keine offenen Einladungen."))
                GB.UI.inboxOverlay:Hide()
                assert(StaticPopupDialogs.GUILDBOARD_CANCEL.button1 == (en and "Cancel event" or "Termin absagen"))
            end
        ''')

    def test_whisper_languages_and_reply_aliases(self):
        lua = self.boot()
        lua.execute('''
            local e = assert(GB.model:SaveEvent(nil, string.rep("Ä", 40), "RAID", now + 3600, 10, "", ""))
            local invite = assert(GB.Guests.Invite(e.event, "Guest"))
            assert(whispers[1].message:find("Antwort:", 1, true))
            assert(#whispers[1].message <= 255)
            GB.Locale.SetPreference("enUS")
            now = now + 11
            assert(GB.Guests.Invite(e.event, "Guest"))
            assert(whispers[2].message:find("Reply:", 1, true))
            assert(#whispers[2].message <= 255)
            GB.Guests.Whisper("Ja " .. invite.code .. " Heiler", "Guest-TestRealm")
            local signup = GB.model:GetSignup(e.event, "Guest-TestRealm")
            assert(signup.role == "HEALER" and signup.response == "YES")
            GB.Locale.SetPreference("deDE")
            GB.Guests.Whisper("Accept " .. invite.code .. " DPS", "Guest-TestRealm")
            signup = GB.model:GetSignup(e.event, "Guest-TestRealm")
            assert(signup.role == "DAMAGER" and signup.response == "YES")
            GB.Guests.Whisper("Decline " .. invite.code, "Guest-TestRealm")
            assert(GB.model:GetSignup(e.event, "Guest-TestRealm").response == "NO")
        ''')

    def test_language_preference_survives_restart_without_changing_events(self):
        lua = self.boot()
        lua.execute('''
            local event = assert(GB.model:SaveEvent(nil, "Deutscher Titel", "DUNGEON", now + 7200, 5, "English note", ""))
            assert(GB.model:SignUp(event.event, "HEALER", "YES", "Eigene Notiz", "PRIEST", 60))
            GB.Locale.SetPreference("enUS")
        ''')
        # Copy saved Lua values across independent runtimes, as a saved-variable reload would.
        def plain(value):
            if hasattr(value, "items"):
                return {key: plain(item) for key, item in value.items()}
            return value
        data = plain(lua.globals().GuildBoardDB)
        other = self.boot("deDE", saved=None)
        other.globals().GuildBoardDB = other.table_from(data, recursive=True)
        other.execute('GB.model = nil; GB.RefreshContext()')
        self.assertEqual(other.eval("GB.Locale.Current()"), "enUS")
        self.assertEqual(other.eval('GB.model:Events("ALL", "", false)[1].title'), "Deutscher Titel")
        self.assertEqual(other.eval('GB.model:Events("ALL", "", false)[1].note'), "English note")
        self.assertEqual(other.eval('GB.model:Participants(GB.model:Events("ALL", "", false)[1].event)[1].role'), "HEALER")

    def test_german_organizer_and_english_guest_sync(self):
        organizer = self.boot("deDE", player="Organizer")
        guest = self.boot("enUS", player="Guest")

        def deliver(sender, recipient):
            sender.execute('for i = 1, 100 do GB.Transport.frame.scripts.OnUpdate(nil, 0.31) end')
            packets = sender.globals().packets
            for i in range(1, len(packets) + 1):
                packet = packets[i]
                recipient.globals().GB.Transport.frame.scripts.OnEvent(
                    None, "CHAT_MSG_ADDON_LOGGED", packet.prefix, packet.message,
                    packet.channel, sender.globals().GB.actor,
                )
            sender.execute("packets = {}")

        organizer.execute('''
            event = assert(GB.model:SaveEvent(nil, "Onyxia", "RAID", now + 3600, 10, "Meet at the entrance", ""))
            assert(GB.Guests.Invite(event.event, "Guest"))
        ''')
        deliver(organizer, guest)
        guest.execute('''
            local inbox = GB.Guests.Inbox()
            assert(#inbox == 1)
            assert(chat[#chat]:find("Invitation from", 1, true))
            eventId = inbox[1].event.event
            assert(GB.Guests.Accept(eventId))
            assert(GB.model:SignUp(eventId, "HEALER", "YES", "Ready", "PRIEST", 60))
        ''')
        deliver(guest, organizer)
        organizer.execute('''
            assert(GB.model:GetSignup(event.event, "Guest-TestRealm").role == "HEALER")
            assert(GB.model:Decide(event.event, "Guest-TestRealm", "CONFIRMED"))
            GB.UI.Toggle()
            assert(GB.UI.people[1].role:GetText() == "Heiler")
        ''')
        deliver(organizer, guest)
        guest.execute('''
            GB.UI.Toggle()
            assert(GB.model:Status(eventId, GB.actor) == "CONFIRMED")
            assert(GB.UI.people[1].role:GetText() == "Healer")
            assert(GB.UI.people[1].status:GetText() == "Confirmed")
            assert(GB.model:GetEvent(eventId).note == "Meet at the entrance")
        ''')


if __name__ == "__main__":
    unittest.main(verbosity=2)
