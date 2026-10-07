"""Offline loot recording and real packet transport between independent Lua clients."""
import unittest

import test_localization as localization


def drain(lua):
    lua.execute('for i = 1, 8002 do GB.Transport.frame.scripts.OnUpdate(nil, 0.31) end')
    packets = [dict(lua.globals().packets[i]) for i in range(1, len(lua.globals().packets) + 1)]
    lua.execute('packets = {}')
    for packet in packets:
        assert len(packet['message'].encode('utf-8')) <= 255
    return packets


def deliver(sender, recipient, packets=None, duplicate=False):
    for packet in drain(sender) if packets is None else packets:
        assert packet['channel'] == 'WHISPER'
        assert packet['target'].lower() == recipient.globals().GB.actor.lower()
        for _ in range(2 if duplicate else 1):
            recipient.globals().GB.Transport.frame.scripts.OnEvent(
                None, 'CHAT_MSG_ADDON_LOGGED', packet['prefix'], packet['message'],
                packet['channel'], sender.globals().GB.actor,
            )


def copy_saved(value, lua):
    if hasattr(value, 'items'):
        table = lua.table()
        for key, item in value.items():
            table[key] = copy_saved(item, lua)
        return table
    return value


class LootTests(unittest.TestCase):
    boot = localization.LocalizationTests.boot

    def recorded(self, client='deDE', player='Recorder', size=2):
        lua = self.boot(client, player=player)
        lua.globals().size = size
        lua.execute('''
            SetLootLocale(clientLocale)
            itemData[100] = { name = "Blaue Robe", quality = 3 }
            itemData[200] = { name = "Épischer Stab", quality = 4 }
            enterInstance("Geschmolzener Kern", "raid", 409)
            run = GB.Loot.Runs()[1]
            for i = 1, size do
                loot(i % 2 == 0 and 200 or 100, i % 2 == 0 and "Absent" or "self", 1, i)
            end
            now = now + 60
            enterInstance("World", "none", 0)
            assert(run.finished and #run.items == size)
        ''')
        return lua

    def test_localized_receipts_quality_quantity_and_duplicates(self):
        for client in ['deDE', 'enUS']:
            lua = self.boot(client)
            lua.execute('''
                SetLootLocale(clientLocale)
                GB.Locale.SetPreference(clientLocale == "deDE" and "enUS" or "deDE")
                itemData[100] = { name = "Blue", quality = 3 }
                itemData[200] = { name = "Purple", quality = 4 }
                itemData[300] = { name = "Green", quality = 2 }
                itemData[400] = { name = "Legendary", quality = 5 }
                loot(100, "self", 1, 1)
                assert(#GB.Loot.Runs() == 0)
                enterInstance("Dungeon", "party", 33)
                run = GB.Loot.Runs()[1]
                loot(100, "self", 2, 10)
                loot(100, "self", 2, 10)
                loot(200, "Éowyn", 3, 11)
                loot(100, "self", 2, 12)
                loot(300, "self", 1, 13)
                loot(400, "self", 1, 14)
                GB.Loot.OnLoot("You create: " .. lootLink(100) .. ".", 15)
                GB.Loot.OnLoot("Player won: " .. lootLink(200), 16)
                assert(#run.items == 3)
                assert(run.items[1].quantity == 2 and run.items[1].player == GB.actor)
                assert(run.items[2].quantity == 3 and run.items[2].player == "Éowyn-TestRealm")
                assert(run.items[2].quality == 4)
                assert(not GB.Loot.Share(run.id, "Absent"))
                LOOT_ITEM_MULTIPLE = "%2$s x%3$d -> %1$s"
                GB.Loot.OnLoot(lootLink(200) .. " x5 -> Other", 17)
                assert(#run.items == 4 and run.items[4].quantity == 5)
                local secret = {}
                issecretvalue = function(v) return v == secret end
                GB.Loot.OnLoot(secret, 18)
                assert(#run.items == 4)
            ''')

    def test_delayed_item_data_and_run_boundaries(self):
        lua = self.boot()
        lua.execute('''
            itemData[200] = { name = "Epic", quality = 4 }
            enterInstance("Dungeon", "party", 33)
            run = GB.Loot.Runs()[1]
            loot(100, "self", 1, 1)
            loot(200, "Other", 1, 2)
            assert(itemRequests[100] and #run.items == 1)
            now = now + 30
            enterInstance("World", "none", 0)
            assert(not GB.Loot.Share(run.id, "Absent"))
            itemData[100] = { name = "Loaded", quality = 3 }
            GB.Loot.frame.scripts.OnEvent(nil, "GET_ITEM_INFO_RECEIVED", 100, true)
            assert(#run.items == 2 and run.items[1].itemID == 100)
            GB.Loot.ResolvePending(); assert(#run.items == 2)
            now = now + 60
            enterInstance("Dungeon", "party", 33)
            assert(GB.Loot.data.active == run.id and #GB.Loot.Runs() == 1)
            assert(not GB.Loot.Delete(run.id))
            local second = assert(GB.Loot.NewRun())
            assert(second.id ~= run.id and run.finished and #GB.Loot.Runs() == 2)
            now = now + 60
            enterInstance("World", "none", 0)
            now = now + 601
            enterInstance("Dungeon", "party", 33)
            assert(#GB.Loot.Runs() == 3)
            assert(GB.Loot.Delete(run.id))
            assert(#GB.Loot.Runs() == 2)
        ''')

    def test_saved_history_and_pending_metadata_survive_reload(self):
        first = self.recorded()
        first.execute('''
            enterInstance("Other dungeon", "party", 34)
            loot(333, "self", 1, 999)
            assert(#GB.Loot.data.pending == 1)
        ''')
        second = self.boot(player='Recorder')
        second.globals().GuildBoardDB = copy_saved(first.globals().GuildBoardDB, second)
        second.execute('''
            GB.Loot.profile = nil; GB.Loot.Init()
            assert(#GB.Loot.Runs() == 2)
            itemData[333] = { name = "After reload", quality = 4 }
            GB.Loot.ResolvePending()
            assert(#GB.Loot.data.pending == 0)
            local total = 0
            for _, r in ipairs(GB.Loot.Runs()) do total = total + #r.items end
            assert(total == 3)
            now = now + 90 * 86400
            enterInstance("World", "none", 0)
            GB.Loot.Tick()
            assert(#GB.Loot.Runs() == 2)
        ''')

    def test_absent_english_player_imports_full_german_raid_and_acknowledges(self):
        sender = self.recorded(size=80)
        receiver = self.boot('enUS', player='Absent')
        sender.execute('assert(GB.Loot.Share(run.id, "Absent"))')
        deliver(sender, receiver, duplicate=True)
        receiver.execute('''
            assert(#GB.Loot.Runs() == 0 and #GB.Loot.Inbox() == 1)
            assert(chat[#chat]:find("shared", 1, true))
            assert(GB.Loot.Accept(GB.Loot.Inbox()[1].key))
        ''')
        deliver(receiver, sender)
        packets = drain(sender)
        self.assertGreater(len(packets), 80)
        deliver(sender, receiver, list(reversed(packets)), duplicate=True)
        receiver.execute('''
            assert(#GB.Loot.Inbox() == 0 and #GB.Loot.Runs() == 1)
            received = GB.Loot.Runs()[1]
            assert(#received.items == 80 and received.receivedFrom == "Recorder-TestRealm")
            assert(received.items[2].player == "Absent-TestRealm")
            assert(received.items[2].name == "Épischer Stab")
            assert(not GB.Loot.Share(received.id, "ThirdPlayer"))
        ''')
        deliver(receiver, sender)
        sender.execute('''
            assert(next(GB.Loot.outgoing) == nil)
            assert(chat[#chat]:find("empfangen und gespeichert", 1, true))
            now = now + 16
            assert(GB.Loot.Share(run.id, "Absent"))
        ''')
        receiver.execute('now = now + 16')
        deliver(sender, receiver)
        receiver.execute('assert(GB.Loot.Accept(GB.Loot.Inbox()[1].key))')
        deliver(receiver, sender)
        deliver(sender, receiver)
        receiver.execute('assert(#GB.Loot.Runs() == 1 and #GB.Loot.Runs()[1].items == 80)')

    def test_partial_or_corrupt_transfer_never_commits_and_expires(self):
        for corrupt in [False, True]:
            sender = self.recorded(size=3)
            receiver = self.boot('enUS', player='Absent')
            sender.execute('assert(GB.Loot.Share(run.id, "Absent"))')
            deliver(sender, receiver)
            receiver.execute('assert(GB.Loot.Accept(GB.Loot.Inbox()[1].key))')
            deliver(receiver, sender)
            if corrupt:
                # Modify one printable encoded data field without invalidating the packet framing.
                packets = drain(sender)
                for p in packets:
                    p['message'] = p['message'].replace('Blaue Robe', 'Andere Robe')
                deliver(sender, receiver, packets)
            else:
                # A truncated stream must not create a partially populated saved history.
                deliver(sender, receiver, drain(sender)[:1])
            receiver.execute('''
                assert(#GB.Loot.Runs() == 0)
                now = now + 1801; GB.Loot.Tick()
                assert(#GB.Loot.Inbox() == 0 and next(GB.Loot.incoming) == nil)
                assert(#GB.Loot.Runs() == 0)
            ''')

    def test_unsolicited_data_spoofing_and_decline(self):
        sender = self.recorded()
        receiver = self.boot('enUS', player='Absent')
        sender.execute('assert(GB.Loot.Share(run.id, "Absent"))')
        offer_packets = drain(sender)
        for packet in offer_packets:
            receiver.globals().GB.Transport.frame.scripts.OnEvent(
                None, 'CHAT_MSG_ADDON_LOGGED', packet['prefix'], packet['message'], 'GUILD', sender.globals().GB.actor)
        receiver.execute('assert(#GB.Loot.Inbox() == 0)')
        for packet in offer_packets:
            receiver.globals().GB.Transport.frame.scripts.OnEvent(
                None, 'CHAT_MSG_ADDON_LOGGED', packet['prefix'], packet['message'], 'WHISPER', 'Impostor-TestRealm')
        receiver.execute('assert(#GB.Loot.Inbox() == 0)')
        deliver(sender, receiver, offer_packets)
        receiver.execute('''
            GB.Loot.Receive({"I", "LOOT1", "123", "1", tostring(now), "100", "item:100", "3", "1", "Other-TestRealm", "Item"}, "Other-TestRealm")
            assert(#GB.Loot.Runs() == 0)
            assert(#GB.Loot.Inbox() == 1)
            GB.Loot.Dismiss(GB.Loot.Inbox()[1].key)
            assert(#GB.Loot.Inbox() == 0)
        ''')
        deliver(receiver, sender)
        sender.execute('assert(next(GB.Loot.outgoing) == nil)')

    def test_ui_modes_filters_tooltip_share_and_live_language(self):
        lua = self.recorded()
        lua.execute('''
            GB.UI.Toggle()
            assert(GB.UI.planning:IsShown() and not GB.UI.lootPanel:IsShown())
            click(GB.UI.lootTab)
            local view = GB.LootUI
            assert(GB.UI.lootPanel:IsShown() and not GB.UI.planning:IsShown())
            assert(view.detail:IsShown() and view.items[1]:IsShown())
            assert(view.searchHint:GetText() == "Suche …" and view.searchHint:IsShown())
            view.items[1].scripts.OnEnter(view.items[1])
            assert(GameTooltip.link:find("item:100", 1, true))
            click(view.qualities[4])
            assert(view.items[1].entry.itemID == 200 and not view.items[2]:IsShown())
            click(view.mineButton)
            assert(view.noItems:IsShown())
            click(view.qualities[0])
            assert(not view.noItems:IsShown() and view.items[1].entry.itemID == 100)
            click(view.shareButton)
            assert(view.shareOverlay:IsShown())
            GB.Locale.SetPreference("enUS")
            assert(view.sendButton.text:GetText() == "Send offer")
            view.target:SetText("Absent")
            click(view.sendButton)
            assert(not view.shareOverlay:IsShown() and next(GB.Loot.outgoing))
            assert(GB.UI.toast:GetText():find("Offer sent", 1, true))
            view.searchBox:SetText("missing")
            assert(view.empty:IsShown() and not view.detail:IsShown())
            view.searchBox:SetText("")
            assert(view.searchHint:IsShown() and view.detail:IsShown())
            click(GB.UI.planTab)
            assert(GB.UI.planning:IsShown() and not GB.UI.lootPanel:IsShown())
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
