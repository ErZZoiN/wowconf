local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("Scan_CHAT", "AceEvent-3.0", "AceConsole-3.0")
local Debug = core.Debug

local HBD = LibStub("HereBeDragons-2.0")

local globaldb

function module:OnInitialize()
    self.db = core.db:RegisterNamespace("Scan_Chat", {
        profile = {
            enabled = true,
        },
    })
    globaldb = core.db.global

    local config = core:GetModule("Config", true)
    if config then
        config.options.args.scanning.plugins.chat = {
            chat = {
                type = "group",
                name = "Chat",
                get = function(info) return self.db.profile[info[#info]] end,
                set = function(info, v) self.db.profile[info[#info]] = v end,
                args = {
                    enabled = config.toggle("Enabled", "Listen for mobs that announce themselves in chat", 10),
                },
            },
        }
    end
end

function module:OnEnable()
    self:RegisterEvent("CHAT_MSG_MONSTER_EMOTE", "OnChatMessage")
    self:RegisterEvent("CHAT_MSG_MONSTER_SAY", "OnChatMessage")
    self:RegisterEvent("CHAT_MSG_MONSTER_WHISPER", "OnChatMessage")
    self:RegisterEvent("CHAT_MSG_MONSTER_YELL", "OnChatMessage")
end

local redirects = {
    [62352] = 62346, -- Chief Salyis => Galleon
}

function module:OnChatMessage(event, text, name, ...)
    if not self.db.profile.enabled then return end
    if not core.db.profile.instances and IsInInstance() then return end
    local zone = HBD:GetPlayerZone()
    local guid = select(10, ...)
    local id, x, y
    if guid then
        id = ns.IdFromGuid(guid)
    elseif name then
        id = core:IdForMob(name, zone)
    end
    Debug("OnChatMessage", event, text, name, id, guid)
    if id and redirects[id] then
        id = redirects[id]
    end
    if not id or not (ns.mobdb[id] or globaldb.always[id]) then return end
    if not globaldb.always[id] and not (ns.mobsByZone[zone] and ns.mobsByZone[zone][id]) then
        -- Only announce from chat message in zones that a rare is known to
        -- exist in (or if they're manually-added rares). Avoids issues like
        -- the Shadowlands pre-event where a lot of boss names got reused and
        -- started getting rare-alerts in their older versions in instances.
        return
    end
    -- Guess from the event whether we're anywhere near the mob
    if event == "CHAT_MSG_MONSTER_SAY" or event == "CHAT_MSG_MONSTER_EMOTE" then
        x, y = HBD:GetPlayerZonePosition()
    else
        x, y = 0, 0
    end
    core:NotifyForMob(id, zone, x, y, false, "chat")
end
