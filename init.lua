local socket = require("socket")
local ssl = require("ssl")
local copas = require("copas")
local json = require("dkjson")
local ltn12 = require("ltn12")

math.randomseed(os.time())

local silicord = {}
silicord._clients = {}

-- 1. Internal Helpers
local function log_info(message)
    print(string.format("\27[1;35mINFO    %s silicord: %s\27[0m", os.date("%H:%M:%S"), message))
end

local function log_error(message)
    print(string.format("\27[1;31mERROR   %s silicord: %s\27[0m", os.date("%H:%M:%S"), message))
end

local function log_warn(message)
    print(string.format("\27[1;33mWARN    %s silicord: %s\27[0m", os.date("%H:%M:%S"), message))
end

local function hex_to_int(hex)
    hex = hex:gsub("^#", ""):gsub("^0x", "")
    return tonumber(hex, 16)
end

local function url_encode(str)
    return str:gsub("(.)", function(c)
        local b = string.byte(c)
        if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or
           (b >= 48 and b <= 57) or c == "-" or c == "_" or c == "." or c == "~" then
            return c
        end
        return string.format("%%%02X", b)
    end)
end

local function iso8601(seconds_from_now)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + seconds_from_now)
end

local function send_frame(conn, payload)
    local len = #payload
    local mask = {
        math.random(0, 255), math.random(0, 255),
        math.random(0, 255), math.random(0, 255)
    }
    local masked = {}
    for i = 1, len do
        masked[i] = string.char(string.byte(payload, i) ~ mask[(i - 1) % 4 + 1])
    end
    local header
    if len <= 125 then
        header = string.char(0x81, 0x80 + len)
    elseif len <= 65535 then
        header = string.char(0x81, 0xFE, math.floor(len / 256), len % 256)
    end
    conn:send(header .. string.char(mask[1], mask[2], mask[3], mask[4]) .. table.concat(masked))
end

local function send_close_frame(conn)
    local mask = { math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255) }
    local code = { 0x03, 0xE8 }
    local masked_code = {
        string.char(code[1] ~ mask[1]),
        string.char(code[2] ~ mask[2])
    }
    conn:send(
        string.char(0x88, 0x82) ..
        string.char(mask[1], mask[2], mask[3], mask[4]) ..
        table.concat(masked_code)
    )
end

-- 2. Task Scheduler
silicord.task = {
    wait = function(n)
        copas.pause(n or 0)
        return n
    end,
    spawn = function(f, ...)
        return copas.addthread(f, ...)
    end
}

-- 3. Signal System
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _listeners = {} }, Signal) end
function Signal:Connect(callback)
    table.insert(self._listeners, callback)
    return { Disconnect = function() end }
end
function Signal:Fire(...)
    for _, callback in ipairs(self._listeners) do
        silicord.task.spawn(callback, ...)
    end
end

-- 4. Embed Builder
function silicord.Embed(data)
    local embed = {}
    if data.color then
        embed.color = type(data.color) == "string" and hex_to_int(data.color) or data.color
    end
    if data.title       then embed.title       = data.title       end
    if data.description then embed.description = data.description end
    if data.url         then embed.url         = data.url         end
    if data.timestamp   then embed.timestamp   = data.timestamp   end
    if data.author then
        embed.author = { name = data.author, icon_url = data.author_icon, url = data.author_url }
    end
    if data.footer then
        embed.footer = { text = data.footer, icon_url = data.footer_icon }
    end
    if data.image     then embed.image     = { url = data.image }     end
    if data.thumbnail then embed.thumbnail = { url = data.thumbnail } end
    if data.fields then
        embed.fields = {}
        for _, field in ipairs(data.fields) do
            table.insert(embed.fields, {
                name   = field.name,
                value  = field.value,
                inline = field.inline or false
            })
        end
    end
    return embed
end

-- 5. Rate Limit Bucket Controller
local _rate_limit_pause = 0

local function make_request_sync(token, url, method, body)
    local https = require("ssl.https")
    if _rate_limit_pause > 0 then
        local wait_for = _rate_limit_pause
        _rate_limit_pause = 0
        log_warn("Rate limited. Pausing for " .. wait_for .. "s...")
        silicord.task.wait(wait_for)
    end
    local result = {}
    local _, code = https.request({
        url    = url,
        method = method,
        headers = {
            ["Authorization"] = "Bot " .. token,
            ["Content-Type"]   = "application/json",
            ["Content-Length"] = tostring(#body)
        },
        source = ltn12.source.string(body),
        sink   = ltn12.sink.table(result),
        verify = "none"
    })
    local body_str = table.concat(result)
    if code == 429 then
        local data = json.decode(body_str)
        local retry_after = (data and data.retry_after) or 1
        log_warn("429 Too Many Requests. Retrying after " .. retry_after .. "s")
        _rate_limit_pause = retry_after
        silicord.task.wait(retry_after)
        return make_request_sync(token, url, method, body)
    end
    if code ~= 200 and code ~= 201 and code ~= 204 then
        return nil, code
    end
    return json.decode(body_str), code
end

local function make_request(token, url, method, body)
    silicord.task.spawn(function()
        make_request_sync(token, url, method, body)
    end)
end

-- 6. Token Validator
-- Checks token and app_id before starting the bot.
-- Returns true if valid, false + reason if not.
local function validate_credentials(token, app_id)
    local https = require("ssl.https")
    local result = {}
    local _, code = https.request({
        url    = "https://discord.com/api/v10/users/@me",
        method = "GET",
        headers = {
            ["Authorization"] = "Bot " .. token,
            ["Content-Type"]  = "application/json",
            ["Content-Length"] = "0"
        },
        source = ltn12.source.string(""),
        sink   = ltn12.sink.table(result),
        verify = "none"
    })
    if code ~= 200 then
        return false, "token"
    end
    if app_id then
        local result2 = {}
        local _, code2 = https.request({
            url    = string.format("https://discord.com/api/v10/applications/%s/commands", app_id),
            method = "GET",
            headers = {
                ["Authorization"] = "Bot " .. token,
                ["Content-Type"]  = "application/json",
                ["Content-Length"] = "0"
            },
            source = ltn12.source.string(""),
            sink   = ltn12.sink.table(result2),
            verify = "none"
        })
        if code2 ~= 200 then
            return false, "app_id"
        end
    end
    return true
end

-- 7. Slash Command Option Types
local OPTION_TYPES = {
    string  = 3, integer = 4, bool    = 5,
    boolean = 5, user    = 6, channel = 7,
    role    = 8, number  = 10, any    = 3
}

-- 8. Member Object
local Member = {}
Member.__index = Member

function Member.new(data, guild_id, token)
    return setmetatable({
        user      = data.user,
        id        = data.user and data.user.id,
        username  = data.user and data.user.username,
        nickname  = data.nick,
        roles     = data.roles or {},
        _guild_id = guild_id,
        _token    = token
    }, Member)
end

function Member:Kick(reason)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self._guild_id, self.id),
        "DELETE", reason and json.encode({ reason = reason }) or "")
    log_info("Kicked " .. self.username)
end

function Member:Ban(reason, delete_days)
    local body = {}
    if reason then body.reason = reason end
    if delete_days then body.delete_message_days = delete_days end
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/bans/%s", self._guild_id, self.id),
        "PUT", json.encode(body))
    log_info("Banned " .. self.username)
end

function Member:Timeout(seconds, reason)
    local body = { communication_disabled_until = iso8601(seconds) }
    if reason then body.reason = reason end
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self._guild_id, self.id),
        "PATCH", json.encode(body))
    log_info("Timed out " .. self.username .. " for " .. seconds .. "s")
end

function Member:RemoveTimeout()
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self._guild_id, self.id),
        "PATCH", json.encode({ communication_disabled_until = json.null }))
    log_info("Removed timeout from " .. self.username)
end

function Member:GiveRole(role_id)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s/roles/%s",
            self._guild_id, self.id, role_id),
        "PUT", "{}")
    log_info("Gave role " .. role_id .. " to " .. self.username)
end

function Member:RemoveRole(role_id)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s/roles/%s",
            self._guild_id, self.id, role_id),
        "DELETE", "")
    log_info("Removed role " .. role_id .. " from " .. self.username)
end

function Member:SetNickname(nick)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self._guild_id, self.id),
        "PATCH", json.encode({ nick = nick }))
    log_info("Set nickname for " .. self.username .. " to " .. tostring(nick))
end

function Member:ResetNickname()
    self:SetNickname(json.null)
end

function Member:SendDM(text, embed)
    silicord.task.spawn(function()
        local dm_data = make_request_sync(self._token,
            "https://discord.com/api/v10/users/@me/channels",
            "POST", json.encode({ recipient_id = self.id }))
        if not dm_data or not dm_data.id then
            log_error("Failed to open DM with " .. self.id)
            return
        end
        local payload = {}
        if type(text) == "table" then
            payload.embeds = { text }
        else
            payload.content = text
            if embed then payload.embeds = { embed } end
        end
        make_request_sync(self._token,
            string.format("https://discord.com/api/v10/channels/%s/messages", dm_data.id),
            "POST", json.encode(payload))
    end)
end

-- 9. Guild Object
local Guild = {}
Guild.__index = Guild

function Guild.new(data, token)
    return setmetatable({
        id     = data.id,
        name   = data.name,
        _token = token,
        _data  = data
    }, Guild)
end

local CHANNEL_TYPES = {
    text         = 0,
    dm           = 1,
    voice        = 2,
    category     = 4,
    announcement = 5,
    stage        = 13,
    forum        = 15,
    media        = 16,
}

function Guild:CreateChannel(name, kind, options)
    options = options or {}
    local body = {
        name                = name,
        type                = CHANNEL_TYPES[kind] or 0,
        topic               = options.topic,
        parent_id           = options.parent_id,
        nsfw                = options.nsfw,
        bitrate             = options.bitrate,
        user_limit          = options.user_limit,
        rate_limit_per_user = options.slowmode,
    }
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/channels", self.id),
        "POST", json.encode(body))
    if data then log_info("Created channel #" .. name) end
    return data
end

function Guild:EditChannel(channel_id, options)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/channels/%s", channel_id),
        "PATCH", json.encode(options))
end

function Guild:DeleteChannel(channel_id)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/channels/%s", channel_id),
        "DELETE", "")
    log_info("Deleted channel " .. channel_id)
end

function Guild:CreateRole(name, color, permissions)
    local body = { name = name }
    if color then body.color = type(color) == "string" and hex_to_int(color) or color end
    if permissions then body.permissions = tostring(permissions) end
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/roles", self.id),
        "POST", json.encode(body))
    if data then log_info("Created role @" .. name) end
    return data
end

function Guild:EditRole(role_id, options)
    if options.color and type(options.color) == "string" then
        options.color = hex_to_int(options.color)
    end
    return make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/roles/%s", self.id, role_id),
        "PATCH", json.encode(options))
end

function Guild:DeleteRole(role_id)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/roles/%s", self.id, role_id),
        "DELETE", "")
    log_info("Deleted role " .. role_id)
end

function Guild:GetMembers(limit)
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members?limit=%d", self.id, limit or 100),
        "GET", "")
    if not data then return {} end
    local members = {}
    for _, m in ipairs(data) do
        table.insert(members, Member.new(m, self.id, self._token))
    end
    return members
end

function Guild:GetMember(user_id)
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self.id, user_id),
        "GET", "")
    if not data then return nil end
    return Member.new(data, self.id, self._token)
end

function Guild:GetRandomMember()
    local members = self:GetMembers(100)
    if not members or #members == 0 then return nil end
    return members[math.random(1, #members)]
end

function Guild:GetChannels()
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/channels", self.id),
        "GET", "")
    return data or {}
end

function Guild:GetRoles()
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/roles", self.id),
        "GET", "")
    return data or {}
end

function Guild:KickMember(user_id, reason)
    Member.new({ user = { id = user_id, username = user_id } }, self.id, self._token):Kick(reason)
end

function Guild:BanMember(user_id, reason)
    Member.new({ user = { id = user_id, username = user_id } }, self.id, self._token):Ban(reason)
end

function Guild:CreateEvent(options)
    local entity_type = ({ stage=1, voice=2, external=3 })[options.type] or 3
    local body = {
        name                 = options.name,
        description          = options.description,
        scheduled_start_time = options.start_time,
        scheduled_end_time   = options.end_time,
        entity_type          = entity_type,
        privacy_level        = 2,
    }
    if entity_type == 3 then
        body.entity_metadata = { location = options.location or "TBD" }
    else
        body.channel_id = options.channel_id
    end
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/scheduled-events", self.id),
        "POST", json.encode(body))
    if data then log_info("Created event: " .. options.name) end
    return data
end

function Guild:EditEvent(event_id, options)
    if options.type then
        options.entity_type = ({ stage=1, voice=2, external=3 })[options.type] or 3
        options.type = nil
    end
    if options.location then
        options.entity_metadata = { location = options.location }
        options.location = nil
    end
    return make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/scheduled-events/%s", self.id, event_id),
        "PATCH", json.encode(options))
end

function Guild:DeleteEvent(event_id)
    make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/scheduled-events/%s", self.id, event_id),
        "DELETE", "")
    log_info("Deleted event " .. event_id)
end

function Guild:GetEvents()
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/scheduled-events", self.id),
        "GET", "")
    return data or {}
end

function Guild:Edit(options)
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s", self.id),
        "PATCH", json.encode(options))
    if data then self.name = data.name or self.name end
    return data
end

-- 10. Interaction Object
local Interaction = {}
Interaction.__index = Interaction

function Interaction.new(data, token)
    local self = setmetatable({}, Interaction)
    self._token     = token
    self.id         = data.id
    self.token      = data.token
    self.guild_id   = data.guild_id
    self.channel_id = data.channel_id
    self.author     = data.member and data.member.user or data.user
    self.message    = data.message
    self.custom_id  = data.data and data.data.custom_id
    self.args       = {}
    if data.data and data.data.options then
        for _, opt in ipairs(data.data.options) do
            self.args[opt.name] = opt.value
        end
    end
    self.values = data.data and data.data.values or {}
    return self
end

function Interaction:Reply(text, embed, components)
    local payload = { type = 4, data = {} }
    if type(text) == "table" and not text.title and not text.description then
        payload.data.components = text
    elseif type(text) == "table" then
        payload.data.embeds = { text }
    else
        payload.data.content = text
        if embed then payload.data.embeds = { embed } end
        if components then payload.data.components = components end
    end
    make_request(self._token,
        string.format("https://discord.com/api/v10/interactions/%s/%s/callback", self.id, self.token),
        "POST", json.encode(payload))
end

function Interaction:Update(text, embed, components)
    local payload = { type = 7, data = {} }
    if type(text) == "table" and not text.title and not text.description then
        payload.data.components = text
    elseif type(text) == "table" then
        payload.data.embeds = { text }
    else
        if text then payload.data.content = text end
        if embed then payload.data.embeds = { embed } end
    end
    if components then payload.data.components = components end
    make_request(self._token,
        string.format("https://discord.com/api/v10/interactions/%s/%s/callback", self.id, self.token),
        "POST", json.encode(payload))
end

function Interaction:GetGuild()
    if not self.guild_id then return nil end
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s", self.guild_id),
        "GET", "")
    if not data then return nil end
    return Guild.new(data, self._token)
end

function Interaction:GetMember()
    if not self.guild_id or not self.author then return nil end
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self.guild_id, self.author.id),
        "GET", "")
    if not data then return nil end
    return Member.new(data, self.guild_id, self._token)
end

function Interaction:SendPrivateMessage(text, embed)
    silicord.task.spawn(function()
        local dm_data = make_request_sync(self._token,
            "https://discord.com/api/v10/users/@me/channels",
            "POST", json.encode({ recipient_id = self.author.id }))
        if not dm_data or not dm_data.id then
            log_error("Failed to open DM with " .. self.author.id)
            return
        end
        local payload = {}
        if type(text) == "table" then payload.embeds = { text }
        else
            payload.content = text
            if embed then payload.embeds = { embed } end
        end
        make_request_sync(self._token,
            string.format("https://discord.com/api/v10/channels/%s/messages", dm_data.id),
            "POST", json.encode(payload))
    end)
end

-- 11. Component Builders
function silicord.Button(data)
    local styles = { primary=1, secondary=2, success=3, danger=4, link=5 }
    return {
        type      = 2,
        style     = styles[data.style] or data.style or 1,
        label     = data.label,
        custom_id = data.custom_id,
        url       = data.url,
        emoji     = data.emoji and { name = data.emoji } or nil,
        disabled  = data.disabled or false
    }
end

function silicord.SelectMenu(data)
    return {
        type        = 3,
        custom_id   = data.custom_id,
        placeholder = data.placeholder or "Select an option...",
        min_values  = data.min_values or 1,
        max_values  = data.max_values or 1,
        options     = data.options or {}
    }
end

function silicord.ActionRow(...)
    local components = {...}
    if #components == 1 and type(components[1][1]) == "table" then
        components = components[1]
    end
    return { type = 1, components = components }
end

-- 12. Message Object
local Message = {}
Message.__index = Message

function Message.new(data, token, cache)
    local self = setmetatable(data, Message)
    self._token     = token
    self._cache     = cache
    self.id         = data.id
    self.channel_id = data.channel_id
    self.guild_id   = data.guild_id
    self.content    = data.content or ""
    self.author     = data.author
    return self
end

function Message:Reply(text, embed, components)
    local payload = { message_reference = { message_id = self.id } }
    if type(text) == "table" and not text.title and not text.description then
        payload.components = text
    elseif type(text) == "table" then
        payload.embeds = { text }
    else
        payload.content = text
        if embed then payload.embeds = { embed } end
        if components then payload.components = components end
    end
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/messages", self.channel_id),
        "POST", json.encode(payload))
end

function Message:Send(text, embed, components)
    local payload = {}
    if type(text) == "table" and not text.title and not text.description then
        payload.components = text
    elseif type(text) == "table" then
        payload.embeds = { text }
    else
        payload.content = text
        if embed then payload.embeds = { embed } end
        if components then payload.components = components end
    end
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/messages", self.channel_id),
        "POST", json.encode(payload))
end

function Message:Edit(text, embed, components)
    local payload = {}
    if type(text) == "table" and not text.title and not text.description then
        payload.components = text
    elseif type(text) == "table" then
        payload.embeds = { text }
    else
        payload.content = text
        if embed then payload.embeds = { embed } end
        if components then payload.components = components end
    end
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/messages/%s", self.channel_id, self.id),
        "PATCH", json.encode(payload))
end

function Message:React(emoji)
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/messages/%s/reactions/%s/@me",
            self.channel_id, self.id, url_encode(emoji)),
        "PUT", "{}")
end

function Message:Delete()
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/messages/%s", self.channel_id, self.id),
        "DELETE", "")
end

function Message:Pin()
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/pins/%s", self.channel_id, self.id),
        "PUT", "{}")
end

function Message:Unpin()
    make_request(self._token,
        string.format("https://discord.com/api/v10/channels/%s/pins/%s", self.channel_id, self.id),
        "DELETE", "")
end

function Message:GetGuild()
    if not self.guild_id then return nil end
    if self._cache and self._cache.guilds[self.guild_id] then
        return Guild.new(self._cache.guilds[self.guild_id], self._token)
    end
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s", self.guild_id),
        "GET", "")
    if not data then return nil end
    return Guild.new(data, self._token)
end

function Message:GetMember()
    if not self.guild_id or not self.author then return nil end
    local data = make_request_sync(self._token,
        string.format("https://discord.com/api/v10/guilds/%s/members/%s", self.guild_id, self.author.id),
        "GET", "")
    if not data then return nil end
    return Member.new(data, self.guild_id, self._token)
end

function Message:SendPrivateMessage(text, embed)
    silicord.task.spawn(function()
        local dm_data = make_request_sync(self._token,
            "https://discord.com/api/v10/users/@me/channels",
            "POST", json.encode({ recipient_id = self.author.id }))
        if not dm_data or not dm_data.id then
            log_error("Failed to open DM with " .. self.author.id)
            return
        end
        local payload = {}
        if type(text) == "table" then payload.embeds = { text }
        else
            payload.content = text
            if embed then payload.embeds = { embed } end
        end
        make_request_sync(self._token,
            string.format("https://discord.com/api/v10/channels/%s/messages", dm_data.id),
            "POST", json.encode(payload))
    end)
end

-- 13. Shard Gateway
local function register_slash_commands(token, app_id, pending_slash)
    for _, pending in ipairs(pending_slash) do
        local api_options = {}
        for _, opt in ipairs(pending.cfg.options or {}) do
            table.insert(api_options, {
                name        = opt.name,
                description = opt.description or opt.name,
                type        = OPTION_TYPES[opt.type] or 3,
                required    = opt.required or false
            })
        end
        silicord.task.spawn(function()
            local data = make_request_sync(token,
                string.format("https://discord.com/api/v10/applications/%s/commands", app_id),
                "POST", json.encode({
                    name        = pending.name,
                    description = pending.cfg.description or pending.name,
                    options     = api_options
                }))
            if data then log_info("Registered slash command: /" .. pending.name) end
        end)
    end
end

local function start_shard(token, shard_id, total_shards, client)
    silicord.task.spawn(function()
        local tcp = socket.tcp()
        tcp:settimeout(5)
        local ok, err = tcp:connect("gateway.discord.gg", 443)
        if not ok then
            log_error(string.format("Shard %d TCP failed: %s", shard_id, tostring(err)))
            return
        end
        local conn = ssl.wrap(tcp, { mode = "client", protocol = "tlsv1_2", verify = "none" })
        conn:dohandshake()
        conn = copas.wrap(conn)
        client._conns[shard_id] = conn

        conn:send(
            "GET /?v=10&encoding=json HTTP/1.1\r\n" ..
            "Host: gateway.discord.gg\r\n" ..
            "Upgrade: websocket\r\n" ..
            "Connection: Upgrade\r\n" ..
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" ..
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        while true do
            local line = conn:receive("*l")
            if line == "" or not line then break end
        end

        while true do
            local head = conn:receive(2)
            if not head then
                log_error(string.format("Shard %d lost connection.", shard_id))
                break
            end
            local b1, b2      = string.byte(head, 1, 2)
            local opcode      = b1 % 16
            local payload_len = b2 % 128
            if opcode == 8 then
                log_error("Discord closed the connection unexpectedly. Check your intents.")
                os.exit(1)
            end
            if payload_len == 126 then
                local ext = conn:receive(2)
                payload_len = string.byte(ext, 1) * 256 + string.byte(ext, 2)
            end
            local payload = conn:receive(payload_len)
            if payload then
                local data = json.decode(payload)
                if not data then
                    log_error("Shard " .. shard_id .. ": malformed JSON.")
                else
                    -- Op 10: Hello — start heartbeat and identify
                    if data.op == 10 then
                        silicord.task.spawn(function()
                            local interval = data.d.heartbeat_interval / 1000
                            silicord.task.wait(interval * math.random())
                            while true do
                                send_frame(conn, json.encode({ op = 1, d = json.null }))
                                silicord.task.wait(interval)
                            end
                        end)
                        send_frame(conn, json.encode({
                            op = 2,
                            d  = {
                                token      = token,
                                intents    = 33281,
                                shard      = { shard_id, total_shards },
                                properties = { os = "linux", browser = "silicord", device = "silicord" }
                            }
                        }))
                    end

                    -- READY: bot is online, register slash commands now
                    if data.op == 0 and data.t == "READY" then
                        if total_shards > 1 then
                            log_info(string.format("Shard %d online! Logged in as %s.",
                                shard_id, data.d.user.username))
                        else
                            log_info("Bot online! Logged in as " .. data.d.user.username .. ". Press Ctrl+C to stop.")
                        end
                        client.cache.bot_user = data.d.user
                        -- Register slash commands only after confirmed login
                        if client._app_id and #client._pending_slash > 0 then
                            register_slash_commands(token, client._app_id, client._pending_slash)
                        end
                    end

                    -- Op 9: Invalid session
                    if data.op == 9 then
                        log_error("Invalid session. Check your token and Message Content Intent.")
                        os.exit(1)
                    end

                    -- Cache guild data
                    if data.t == "GUILD_CREATE" and data.d then
                        client.cache.guilds[data.d.id] = data.d
                        if data.d.members then
                            for _, member in ipairs(data.d.members) do
                                if member.user then
                                    client.cache.users[member.user.id] = member.user
                                end
                            end
                        end
                    end

                    -- Prefix command dispatch
                    if data.t == "MESSAGE_CREATE" then
                        local msg = Message.new(data.d, token, client.cache)
                        if msg.author then
                            client.cache.users[msg.author.id] = msg.author
                        end
                        if not msg.author.bot and msg.content:sub(1, #client._prefix) == client._prefix then
                            local body = msg.content:sub(#client._prefix + 1)
                            local parts = {}
                            for word in body:gmatch("%S+") do
                                table.insert(parts, word)
                            end
                            local cmd_name = parts[1]
                            local args = {}
                            for i = 2, #parts do args[i - 1] = parts[i] end
                            args.raw = body:match("^%S+%s+(.+)$") or ""
                            if cmd_name and client._commands[cmd_name] then
                                local allowed = true
                                for _, hook in ipairs(client._middleware) do
                                    local result = hook(msg, cmd_name, args)
                                    if result == false then allowed = false break end
                                end
                                if allowed then
                                    silicord.task.spawn(function()
                                        local ok, err = pcall(client._commands[cmd_name].callback, msg, args)
                                        if not ok then
                                            -- Detect missing argument errors vs general errors
                                            local error_type = "CommandError"
                                            if args.raw == "" and (tostring(err):find("nil") or tostring(err):find("index")) then
                                                error_type = "MissingArgument"
                                            end
                                            if #client.OnError._listeners > 0 then
                                                client.OnError:Fire(error_type, msg, cmd_name, tostring(err))
                                            else
                                                log_error(string.format("[%s] in !%s: %s", error_type, cmd_name, tostring(err)))
                                            end
                                        end
                                    end)
                                end
                            elseif cmd_name then
                                -- A prefix was used but no command matched
                                if #client.OnError._listeners > 0 then
                                    client.OnError:Fire("CommandNotFound", msg, cmd_name)
                                end
                            else
                                msg.content = body
                                client.OnMessage:Fire(msg)
                            end
                        end
                    end

                    -- Interaction dispatch (slash commands + components)
                    if data.t == "INTERACTION_CREATE" then
                        local interaction = Interaction.new(data.d, token)
                        local itype = data.d.type
                        if itype == 2 then
                            local cmd_name = data.d.data and data.d.data.name
                            if cmd_name and client._slash[cmd_name] then
                                local allowed = true
                                for _, hook in ipairs(client._middleware) do
                                    local result = hook(interaction, cmd_name, interaction.args)
                                    if result == false then allowed = false break end
                                end
                                if allowed then
                                    silicord.task.spawn(function()
                                        local ok, err = pcall(client._slash[cmd_name].callback, interaction, interaction.args)
                                        if not ok then
                                            if #client.OnError._listeners > 0 then
                                                client.OnError:Fire("SlashCommandError", interaction, cmd_name, tostring(err))
                                            else
                                                log_error(string.format("[SlashCommandError] in /%s: %s", cmd_name, tostring(err)))
                                            end
                                        end
                                    end)
                                end
                            elseif cmd_name then
                                if #client.OnError._listeners > 0 then
                                    client.OnError:Fire("UnknownInteraction", interaction, cmd_name)
                                end
                            end
                        end
                        if itype == 3 then
                            local custom_id = data.d.data and data.d.data.custom_id
                            if custom_id and client._components[custom_id] then
                                silicord.task.spawn(function()
                                    local ok, err = pcall(client._components[custom_id], interaction)
                                    if not ok then
                                        if #client.OnError._listeners > 0 then
                                            client.OnError:Fire("ComponentError", interaction, custom_id, tostring(err))
                                        else
                                            log_error(string.format("[ComponentError] in %s: %s", custom_id, tostring(err)))
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
            silicord.task.wait(0.01)
        end
    end)
end

-- 14. Connect
function silicord.Connect(config)
    local token  = config.token
    local prefix = config.prefix or "!"
    local app_id = config.app_id

    -- Validate credentials before doing anything else
    log_info("Validating credentials...")
    local ok, reason = validate_credentials(token, app_id)
    if not ok then
        print(string.format(
            "\27[1;31mERROR   %s silicord: Unable to run bot; please check if your %s is correct.\27[0m",
            os.date("%H:%M:%S"), reason == "app_id" and "APP_ID" or "TOKEN"
        ))
        os.exit(1)
    end
    log_info("Credentials verified.")

    local client = {
        OnMessage     = Signal.new(),
        OnError       = Signal.new(),
        Token         = token,
        _prefix       = prefix,
        _conns        = {},
        _commands     = {},
        _slash        = {},
        _pending_slash = {},  -- queued until READY
        _components   = {},
        _middleware   = {},
        _app_id       = app_id,
        cache = {
            guilds   = {},
            users    = {},
            bot_user = nil
        }
    }

    function client:CreateCommand(name, callback)
        self._commands[name] = { callback = callback }
        log_info("Registered command: " .. prefix .. name)
    end

    function client:CreateSlashCommand(name, cfg, callback)
        if not self._app_id then
            log_error("app_id required for slash commands.")
            return
        end
        -- Store the callback immediately
        self._slash[name] = { options = cfg.options or {}, callback = callback }
        -- Queue registration until READY
        table.insert(self._pending_slash, { name = name, cfg = cfg })
        log_info("Queued slash command: /" .. name)
    end

    function client:CreateComponent(custom_id, callback)
        self._components[custom_id] = callback
        log_info("Registered component: " .. custom_id)
    end

    function client:AddMiddleware(hook)
        table.insert(self._middleware, hook)
    end

    table.insert(silicord._clients, client)

    silicord.task.spawn(function()
        local gateway_data = make_request_sync(token,
            "https://discord.com/api/v10/gateway/bot", "GET", "")
        local total_shards = 1
        if gateway_data and gateway_data.shards then
            total_shards = gateway_data.shards
        end
        if total_shards > 1 then
            log_info(string.format("Spawning %d shards...", total_shards))
        end
        for shard_id = 0, total_shards - 1 do
            start_shard(token, shard_id, total_shards, client)
            if total_shards > 1 and shard_id < total_shards - 1 then
                silicord.task.wait(5)
            end
        end
    end)

    return client
end

-- 15. Run
function silicord.Run()
    log_info("Engine running...")
    local ok, err = pcall(copas.loop)
    if not ok and not err:match("interrupted") then
        log_error("Engine error: " .. tostring(err))
    end
    for _, c in ipairs(silicord._clients) do
        for _, conn in pairs(c._conns) do
            pcall(send_close_frame, conn)
        end
    end
    log_info("Bot disconnected.")
    os.exit(0)
end

return silicord