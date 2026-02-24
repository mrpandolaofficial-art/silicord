# [silicord](https://silicord.github.io) v1.0.0

A Discord bot framework for Lua with **Luau-inspired syntax**. Built for Roblox developers who want to write Discord bots using familiar patterns like `task.wait()`, Signals, and method chaining.

## For a more detailed and user-friendly coding experience, visit the official website at https://silicord.github.io/.

```bash
luarocks install silicord
```

---

## Requirements

- Lua 5.1+
- [luasocket](https://luarocks.org/modules/luasocket/luasocket)
- [luasec](https://luarocks.org/modules/brunoos/luasec)
- [copas](https://luarocks.org/modules/tieske/copas)
- [dkjson](https://luarocks.org/modules/dhkolf/dkjson)

These are installed automatically when you install silicord via LuaRocks.

---

## Quick Start

```lua
local silicord = require("silicord")

local client = silicord.Connect({
    token  = "your bot token here",
    prefix = "!"
})

client:CreateCommand("ping", function(message, args)
    message:Reply("Pong!")
end)

silicord.Run()
```

---

## silicord.Connect(config)

| Field    | Type   | Required | Description                                      |
|----------|--------|----------|--------------------------------------------------|
| `token`  | string | yes      | Your Discord bot token                           |
| `prefix` | string | no       | Command prefix (default: `"!"`)                  |
| `app_id` | string | no       | Your Discord application ID (for slash commands) |

```lua
local client = silicord.Connect({
    token  = "your token",
    prefix = "!",
    app_id = "your application id"  -- only needed for slash commands
})
```

---

## Commands

### Prefix Commands

```lua
-- Basic command
client:CreateCommand("ping", function(message, args)
    message:Reply("Pong!")
end)

-- Command with arguments
-- User types: !say hello world
client:CreateCommand("say", function(message, args)
    -- args[1] = "hello", args[2] = "world"
    -- args.raw = "hello world" (everything after the command)
    message:Reply(args.raw)
end)

-- Command with task.wait
client:CreateCommand("countdown", function(message, args)
    message:Reply("3...")
    silicord.task.wait(1)
    message:Reply("2...")
    silicord.task.wait(1)
    message:Reply("1... Go!")
end)
```

### Slash Commands

Slash commands require `app_id` in your Connect config.

```lua
client:CreateSlashCommand("ban", {
    description = "Ban a user from the server",
    options = {
        { name = "user",   description = "The user to ban",    type = "user",   required = true  },
        { name = "reason", description = "Reason for the ban", type = "string", required = false }
    }
}, function(interaction, args)
    interaction:Reply("Banned " .. args.user .. ". Reason: " .. (args.reason or "none"))
end)
```

**Supported argument types:** `string`, `integer`, `number`, `bool`, `user`, `channel`, `role`, `any`

---

## Message Object

| Method | Description |
|--------|-------------|
| `message:Reply(text)` | Reply to the message, pinging the author |
| `message:Reply(text, embed)` | Reply with text and an embed |
| `message:Reply(text, embed, components)` | Reply with text, embed, and buttons/menus |
| `message:Send(text)` | Send a regular message with no ping |
| `message:Send(text, embed)` | Send a message with an embed, no ping |
| `message:Send(text, embed, components)` | Send with text, embed, and components |
| `message:Edit(text)` | Edit the bot's own message |
| `message:React("👍")` | Add a reaction to the message |
| `message:Delete()` | Delete the message |
| `message:Pin()` | Pin the message in the channel |
| `message:Unpin()` | Unpin the message |
| `message:GetGuild()` | Returns a Guild object (uses cache automatically) |
| `message:GetMember()` | Returns a Member object for the message author |
| `message:SendPrivateMessage(text)` | DM the message author |
| `message:SendPrivateMessage(text, embed)` | DM the message author with an embed |

```lua
client:CreateCommand("info", function(message, args)
    message:React("👀")
    -- v1.0.0+: use Instance.new("Embed") — see Embeds section
    local embed = silicord.Instance.new("Embed")
    embed.Title       = "Hello!"
    embed.Description = "This is an embed."
    embed.Color       = "#5865F2"
    embed.Footer      = "silicord"
    message:Reply(embed:Build())
end)

-- Send without pinging
client:CreateCommand("announce", function(message, args)
    message:Send("📢 " .. args.raw)
end)
```

### message.author

```lua
message.author.id        -- user ID
message.author.username  -- username
message.author.bot       -- true if the author is a bot
```

---

## Member Object

Get a member from a message, interaction, or guild:

```lua
local member = message:GetMember()
local member = interaction:GetMember()
local member = guild:GetMember(user_id)
```

| Method | Description |
|--------|-------------|
| `member:Kick(reason)` | Kick the member |
| `member:Ban(reason, delete_days)` | Ban the member |
| `member:Timeout(seconds, reason)` | Apply a Discord native timeout |
| `member:RemoveTimeout()` | Remove an active timeout |
| `member:GiveRole(role_id)` | Give the member a role |
| `member:RemoveRole(role_id)` | Remove a role from the member |
| `member:SetNickname(nick)` | Set the member's nickname |
| `member:ResetNickname()` | Reset the member's nickname to their username |
| `member:SendDM(text)` | Send the member a DM |
| `member:SendDM(text, embed)` | Send the member a DM with an embed |

```lua
client:CreateCommand("timeout", function(message, args)
    local member = message:GetMember()
    member:Timeout(300, "Spamming")   -- 5 minute timeout
    message:Reply("Member timed out for 5 minutes.")
end)

client:CreateCommand("giverole", function(message, args)
    local guild  = message:GetGuild()
    local member = guild:GetMember(args[1])
    member:GiveRole(args[2])
    message:Reply("Role given!")
end)
```

### member properties

```lua
member.id        -- user ID
member.username  -- username
member.nickname  -- server nickname (nil if not set)
member.roles     -- table of role IDs the member has
member.user      -- raw Discord user object
```

---

## Interaction Object (Slash Commands & Components)

```lua
interaction:Reply("Hello!")
interaction:Reply(text, embed)
interaction:Reply(text, embed, components)
interaction:Update("Updated content")        -- update the original message (for buttons)
interaction:Update(text, embed, components)
interaction:GetGuild()
interaction:GetMember()                      -- returns a Member object
interaction:SendPrivateMessage(text)
interaction:SendPrivateMessage(text, embed)

interaction.args       -- slash command arguments keyed by name
interaction.values     -- selected values from a select menu
interaction.author     -- the user who triggered the interaction
interaction.custom_id  -- the custom_id of the triggering component
interaction.guild_id   -- the guild ID
interaction.channel_id -- the channel ID
```

---

## Embeds

### ✅ OOP API — recommended (v1.0.0+)

Use `silicord.Instance.new("Embed")` for a clean builder. Pass a `Color3` object directly to `.Color` — no `:ToInt()` required.

```lua
local embed = silicord.Instance.new("Embed")
embed.Title       = "My Embed"
embed.Description = "This is the description."
embed.Color       = silicord.Color3.fromRGB(88, 101, 242)  -- Color3 object, no :ToInt() needed
embed.Url         = "https://example.com"
embed.Timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ")
embed.Author      = "Author Name"
embed.AuthorIcon  = "https://example.com/icon.png"
embed.AuthorUrl   = "https://example.com"
embed.Footer      = "Footer text"
embed.FooterIcon  = "https://example.com/icon.png"
embed.Image       = "https://example.com/image.png"
embed.Thumbnail   = "https://example.com/thumb.png"
embed:AddField("Field 1", "Value 1", true)
embed:AddField("Field 2", "Value 2", true)
embed:AddField("Field 3", "Value 3", false)

message:Reply("Here's some info:", embed:Build())
```

| Property / Method | Description |
|---|---|
| `embed.Title` | Title string |
| `embed.Description` | Body text |
| `embed.Color` | Hex string, integer, or `Color3` object |
| `embed.Url` | URL for the title link |
| `embed.Timestamp` | ISO 8601 timestamp string |
| `embed.Author / .AuthorIcon / .AuthorUrl` | Author section |
| `embed.Footer / .FooterIcon` | Footer section |
| `embed.Image / .Thumbnail` | Image URLs |
| `embed:AddField(name, value, inline)` | Add a field; returns the embed for chaining |
| `embed:Build()` | Returns the final table to pass to `:Reply()` etc. |

### ⚠️ Table syntax — deprecated (pre-v0.4.3)

> **Deprecated since v1.0.0.** `silicord.Embed({ ... })` still works but prints a runtime warning. Migrate to `silicord.Instance.new("Embed")`. This helper will be removed in a future major version.

```lua
-- ⚠ DEPRECATED — use silicord.Instance.new("Embed") instead
local embed = silicord.Embed({
    title       = "My Embed",
    description = "This is the description.",
    color       = "#5865F2",
    fields = {
        { name = "Field 1", value = "Value 1", inline = true },
    }
})
message:Reply(embed)
```

---

## Color3 (v1.0.0+)

A Roblox-style color class. In v1.0.0+, `Color3` objects can be passed directly to any color field — no `:ToInt()` needed.

```lua
-- Create from RGB values (0–255)
local c = silicord.Color3.fromRGB(88, 101, 242)

-- Create from a hex string
local c = silicord.Color3.fromHex("#5865F2")

-- Use directly in an embed — no :ToInt() required
local embed = silicord.Instance.new("Embed")
embed.Color = silicord.Color3.fromHex("#57F287")

-- Use in guild:CreateRole
guild:CreateRole("Moderator", silicord.Color3.fromRGB(255, 165, 0))

-- Still works: get the raw integer if you need it
local int = c:ToInt()   -- 5793522
```

| Method / Property | Description |
|---|---|
| `Color3.fromRGB(r, g, b)` | Construct from 0–255 RGB values |
| `Color3.fromHex(hex)` | Construct from a hex string (`"#RRGGBB"` or `"RRGGBB"`) |
| `color.r / .g / .b` | Individual channel values (0–255) |
| `color:ToInt()` | Returns the packed 24-bit integer (rarely needed in v1.0.0+) |

---

## Components (Buttons & Select Menus)

### ✅ OOP API — recommended (v1.0.0+)

```lua
client:CreateCommand("vote", function(message, args)
    local yes = silicord.Instance.new("Button")
    yes.Label    = "Yes"
    yes.Style    = "success"
    yes.CustomId = "vote_yes"

    local no = silicord.Instance.new("Button")
    no.Label    = "No"
    no.Style    = "danger"
    no.CustomId = "vote_no"

    local row = silicord.Instance.new("ActionRow")
    row:Add(yes)
    row:Add(no)

    message:Reply("Cast your vote!", nil, { row:Build() })
end)

client:CreateComponent("vote_yes", function(interaction)
    interaction:Update("You voted **Yes**! ✅")
end)
```

**Button properties:**

| Property | Description |
|---|---|
| `button.Label` | Button text (default: `"Button"`) |
| `button.Style` | `"primary"`, `"secondary"`, `"success"`, `"danger"`, `"link"` |
| `button.CustomId` | ID matched by `client:CreateComponent()` |
| `button.Url` | URL for `"link"`-style buttons |
| `button.Emoji` | Emoji name string (e.g. `"👍"`) |
| `button.Disabled` | `true` to disable (default: `false`) |
| `button:Build()` | Returns the raw component table |

**SelectMenu (v1.0.0+):**

```lua
client:CreateCommand("color", function(message, args)
    local menu = silicord.Instance.new("SelectMenu")
    menu.CustomId    = "color_pick"
    menu.Placeholder = "Pick a color"
    menu:AddOption("Red",   "red",   "A warm color")
    menu:AddOption("Blue",  "blue",  "A cool color")
    menu:AddOption("Green", "green", "A natural color")

    local row = silicord.Instance.new("ActionRow")
    row:Add(menu)

    message:Reply("Choose a color:", nil, { row:Build() })
end)

client:CreateComponent("color_pick", function(interaction)
    interaction:Update("You picked: **" .. interaction.values[1] .. "**")
end)
```

| Property / Method | Description |
|---|---|
| `menu.CustomId` | ID matched by `client:CreateComponent()` |
| `menu.Placeholder` | Placeholder text (default: `"Select an option..."`) |
| `menu.MinValues` | Minimum selections required (default: 1) |
| `menu.MaxValues` | Maximum selections allowed (default: 1) |
| `menu:AddOption(label, value, desc, emoji, default)` | Add an option; returns the menu for chaining |
| `menu:Build()` | Returns the raw component table |

**ActionRow:**

```lua
local row = silicord.Instance.new("ActionRow")
row:Add(button)   -- accepts Instance objects or raw built tables
row:Add(menu)
local built = row:Build()
```

### ⚠️ Table syntax — deprecated (pre-v0.4.3)

> **Deprecated since v1.0.0.** These helpers still work but emit a yellow runtime warning. Migrate to the OOP API above.

```lua
-- ⚠ DEPRECATED
local row = silicord.ActionRow(
    silicord.Button({ label = "Yes", style = "success", custom_id = "vote_yes" }),
    silicord.Button({ label = "No",  style = "danger",  custom_id = "vote_no"  })
)

-- ⚠ DEPRECATED
silicord.SelectMenu({ custom_id = "pick", options = { ... } })
```

Deprecated helpers and their replacements:

| Deprecated | Replacement |
|---|---|
| `silicord.Embed({ ... })` | `silicord.Instance.new("Embed")` |
| `silicord.Button({ ... })` | `silicord.Instance.new("Button")` |
| `silicord.SelectMenu({ ... })` | `silicord.Instance.new("SelectMenu")` |
| `silicord.ActionRow(...)` | `silicord.Instance.new("ActionRow")` |

---

## Error Handling

silicord fires a `client.OnError` signal whenever something goes wrong during command or interaction dispatch. If you don't connect a handler, silicord falls back to printing the error to the console so nothing fails silently.

```lua
client.OnError:Connect(function(error_type, ctx, name, detail)
    if error_type == "CommandNotFound" then
        ctx:Reply("❌ Unknown command `!" .. name .. "`.")

    elseif error_type == "MissingArgument" then
        ctx:Reply("❌ Missing argument for `!" .. name .. "`.")

    elseif error_type == "CommandError" then
        ctx:Reply("❌ Something went wrong running `!" .. name .. "`.")
        print("CommandError in !" .. name .. ": " .. detail)

    elseif error_type == "SlashCommandError" then
        ctx:Reply("❌ Something went wrong running `/" .. name .. "`.")

    elseif error_type == "ComponentError" then
        print("ComponentError in " .. name .. ": " .. detail)

    elseif error_type == "UnknownInteraction" then
        ctx:Reply("❌ Unknown slash command.")
    end
end)
```

### Error types

| Error type | When it fires | `ctx` type | `name` | `detail` |
|---|---|---|---|---|
| `CommandNotFound` | User typed a prefix command with no registered handler | Message | command name | nil |
| `MissingArgument` | Command callback errored and args were empty | Message | command name | Lua error string |
| `CommandError` | Command callback threw a runtime error | Message | command name | Lua error string |
| `SlashCommandError` | Slash command callback threw a runtime error | Interaction | command name | Lua error string |
| `ComponentError` | Component callback threw a runtime error | Interaction | custom_id | Lua error string |
| `UnknownInteraction` | A slash command was triggered with no registered handler | Interaction | command name | nil |

---

## Guild Object

Get a guild from any message or interaction:

```lua
local guild = message:GetGuild()
-- guild.id, guild.name
```

| Method | Description |
|--------|-------------|
| `guild:CreateChannel(name, kind, options)` | Create a channel — see channel types below |
| `guild:EditChannel(channel_id, options)` | Edit an existing channel |
| `guild:DeleteChannel(channel_id)` | Delete a channel |
| `guild:CreateRole(name, color, permissions)` | Create a role — `color` accepts hex string, integer, or Color3 |
| `guild:EditRole(role_id, options)` | Edit an existing role — `options.color` accepts hex, integer, or Color3 |
| `guild:DeleteRole(role_id)` | Delete a role |
| `guild:GetMembers(limit)` | Returns a list of Member objects |
| `guild:GetMember(user_id)` | Returns a single Member object |
| `guild:GetRandomMember()` | Returns a random Member object (from first 100) |
| `guild:GetChannels()` | Returns all channels |
| `guild:GetRoles()` | Returns all roles |
| `guild:KickMember(user_id, reason)` | Kick a member by ID |
| `guild:BanMember(user_id, reason)` | Ban a member by ID |
| `guild:CreateEvent(options)` | Create a scheduled event |
| `guild:EditEvent(event_id, options)` | Edit a scheduled event |
| `guild:DeleteEvent(event_id)` | Delete a scheduled event |
| `guild:GetEvents()` | Returns all scheduled events |
| `guild:Edit(options)` | Edit the server itself |

### Channel types

```lua
guild:CreateChannel("general",    "text")
guild:CreateChannel("General",    "voice")
guild:CreateChannel("Info",       "category")
guild:CreateChannel("news",       "announcement")
guild:CreateChannel("Stage",      "stage")
guild:CreateChannel("help",       "forum")
guild:CreateChannel("media",      "media")
```

Channel options:

```lua
guild:CreateChannel("general", "text", {
    topic     = "General chat",
    parent_id = "category_channel_id",
    nsfw      = false,
    slowmode  = 5   -- seconds between messages
})

guild:CreateChannel("Music", "voice", {
    bitrate    = 64000,
    user_limit = 10
})
```

### Scheduled Events

```lua
-- External event (at a location)
guild:CreateEvent({
    name        = "Game Night",
    description = "Monthly game night!",
    type        = "external",
    location    = "Discord Stage",
    start_time  = "2025-09-01T20:00:00Z",
    end_time    = "2025-09-01T23:00:00Z"
})

-- Stage or voice event
guild:CreateEvent({
    name       = "Community Call",
    type       = "stage",
    channel_id = "stage_channel_id",
    start_time = "2025-09-01T20:00:00Z",
    end_time   = "2025-09-01T21:00:00Z"
})

guild:EditEvent(event_id, { name = "Updated Name" })
guild:DeleteEvent(event_id)

local events = guild:GetEvents()
```

---

## DataStore (v1.0.0+)

JSON file-based key-value persistence. Each store maps to a `<name>.datastore.json` file. Calling `silicord.DataStore("name")` twice returns the same cached instance.

**v1.0.0 safety improvements:**
- Empty or missing JSON files start as a fresh store instead of crashing.
- Corrupt JSON is automatically backed up to `name.datastore.json.corrupted_<timestamp>` and the store resets.
- All writes use an atomic temp-file swap — a crash mid-write can never corrupt your data.
- `IncrementAsync` resets non-numeric values to `0` with a warning instead of throwing an error.

```lua
local db = silicord.DataStore("PlayerData")

-- Write a value
db:SetAsync("score_user123", 500)

-- Read a value (returns nil if not set)
local score = db:GetAsync("score_user123")

-- Safely increment a numeric value
local new_score = db:IncrementAsync("score_user123", 10)

-- Remove a value
db:RemoveAsync("score_user123")

-- List all keys
local keys = db:GetKeys()
for _, k in ipairs(keys) do
    print(k, db:GetAsync(k))
end
```

| Method | Description |
|---|---|
| `store:SetAsync(key, value)` | Write any JSON-serializable value |
| `store:GetAsync(key)` | Read a value; returns `nil` if missing |
| `store:RemoveAsync(key)` | Delete a key |
| `store:IncrementAsync(key, delta)` | Add `delta` to a numeric key (default `+1`); safe against corrupt values |
| `store:GetKeys()` | Returns a table of all keys in the store |

---

## Signal

A Roblox-style event system for decoupling bot logic. `client.OnMessage` and `client.OnError` are built-in signals.

```lua
-- Create a custom signal
local mySignal = silicord.Signal.new()

-- Connect a listener (returns a connection with .Disconnect())
local conn = mySignal:Connect(function(a, b)
    print("Signal fired!", a, b)
end)

-- Fire the signal
mySignal:Fire("hello", 42)

-- Disconnect later
conn.Disconnect()

-- Yield the current coroutine until the signal fires
silicord.task.spawn(function()
    local a, b = mySignal:Wait()
    print("Resumed with:", a, b)
end)

-- Built-in: listen to all non-command messages
client.OnMessage:Connect(function(message)
    print(message.author.username .. ": " .. message.content)
end)
```

| Method | Description |
|---|---|
| `Signal.new()` | Create a new signal instance |
| `signal:Connect(callback)` | Add a listener; returns a connection object with `.Disconnect()` |
| `signal:Fire(...)` | Fire the signal; all listeners run in spawned threads |
| `signal:Wait()` | Yield the current coroutine until the signal fires; returns the fired arguments |

---

## Standard Libraries

silicord ships small utility modules that mirror Roblox's standard library extensions.

### silicord.math

| Function | Description |
|---|---|
| `silicord.math.clamp(n, min, max)` | Clamp `n` between `min` and `max` |
| `silicord.math.round(n)` | Round to the nearest integer |
| `silicord.math.lerp(a, b, t)` | Linear interpolation; `t` in 0–1 |
| `silicord.math.sign(n)` | Returns `1`, `-1`, or `0` |

### silicord.table

| Function | Description |
|---|---|
| `silicord.table.find(t, value)` | Returns the index of `value`, or `nil` |
| `silicord.table.contains(t, value)` | Returns `true` if `value` is in the table |
| `silicord.table.keys(t)` | Returns all keys as a sequential table |
| `silicord.table.values(t)` | Returns all values as a sequential table |
| `silicord.table.copy(t)` | Shallow copy of a table |

### silicord.string

| Function | Description |
|---|---|
| `silicord.string.split(str, sep)` | Split a string by a separator pattern (default: whitespace) |
| `silicord.string.trim(str)` | Remove leading and trailing whitespace |
| `silicord.string.startsWith(str, prefix)` | Returns `true` if `str` starts with `prefix` |
| `silicord.string.endsWith(str, suffix)` | Returns `true` if `str` ends with `suffix` |
| `silicord.string.pad(str, length, char)` | Right-pad `str` to `length` with `char` (default: space) |

```lua
local clamped = silicord.math.clamp(150, 0, 100)    -- 100
local lerped  = silicord.math.lerp(0, 10, 0.5)      -- 5.0

local parts = silicord.string.split("a,b,c", ",")   -- {"a","b","c"}
local clean = silicord.string.trim("  hello  ")     -- "hello"

local idx  = silicord.table.find({"a","b","c"}, "b") -- 2
local copy = silicord.table.copy(someTable)
```

---

## CollectionService

A Roblox-style tag registry. Attach string tags to any Lua value and query them later — useful for flagging users, channels, or custom objects.

```lua
local cs = silicord.CollectionService

-- Tag a user ID
cs:AddTag(message.author.id, "admin")
cs:AddTag(message.author.id, "vip")

-- Check tags
print(cs:HasTag(message.author.id, "admin"))  -- true

-- Get all objects with a tag
local admins = cs:GetTagged("admin")
for _, id in ipairs(admins) do print(id) end

-- Get all tags on an object
local tags = cs:GetTags(message.author.id)    -- { "admin", "vip" }

-- Remove a tag
cs:RemoveTag(message.author.id, "vip")
```

| Method | Description |
|---|---|
| `cs:AddTag(object, tag)` | Attach a tag string to any value |
| `cs:RemoveTag(object, tag)` | Remove a specific tag |
| `cs:HasTag(object, tag)` | Returns `true` if the object has the tag |
| `cs:GetTagged(tag)` | Returns all objects with this tag |
| `cs:GetTags(object)` | Returns all tags on this object |

---

## Middleware

Middleware hooks run before every prefix command and slash command. Return `false` to block the command. Multiple middleware functions are run in registration order.

```lua
-- Cooldown hook (3 seconds per command per user)
local cooldowns = {}
client:AddMiddleware(function(ctx, cmd, args)
    local key = ctx.author.id .. ":" .. cmd
    if os.time() - (cooldowns[key] or 0) < 3 then
        ctx:Reply("Slow down! Wait 3 seconds between commands.")
        return false
    end
    cooldowns[key] = os.time()
end)

-- Admin-only guard
local ADMIN_ID = "123456789012345678"
client:AddMiddleware(function(ctx, cmd, args)
    local protected = { ban = true, kick = true, purge = true }
    if protected[cmd] and ctx.author.id ~= ADMIN_ID then
        ctx:Reply("You do not have permission to use this command.")
        return false
    end
end)
```

---

## Caching

silicord automatically caches guild and user data from Discord gateway events. `message:GetGuild()` checks the cache before making an HTTP request.

```lua
client.cache.guilds   -- table of raw guild data keyed by guild ID
client.cache.users    -- table of raw user data keyed by user ID
client.cache.bot_user -- the bot's own user object (set after READY)
```

---

## Sharding

Sharding is fully automatic. silicord fetches the recommended shard count from Discord on startup and spawns the correct number of gateway connections with the required 5-second delay between each. You don't need to configure anything.

> Sharding is only needed for large bots (2500+ servers). For most bots, silicord's automatic handling works transparently in the background.

---

## task (Roblox-style Scheduler)

| Function | Description |
|---|---|
| `silicord.task.wait(n)` | Yield for `n` seconds; returns `n` |
| `silicord.task.spawn(f, ...)` | Run `f` in a new coroutine immediately |
| `silicord.task.defer(f, ...)` *(v1.0.0+)* | Run `f` on the next scheduler cycle — avoids stack overflows in recursive patterns |
| `silicord.task.delay(n, f, ...)` *(v1.0.0+)* | Call `f(...)` after `n` seconds without blocking the caller |

```lua
-- Pause inside any coroutine
silicord.task.wait(2)

-- Fire and forget a background thread
silicord.task.spawn(function()
    silicord.task.wait(5)
    print("5 seconds later")
end)

-- v1.0.0+: defer — runs after the current frame completes
silicord.task.defer(function()
    print("deferred to next cycle")
end)

-- v1.0.0+: delay — clean one-shot timer
silicord.task.delay(10, function()
    print("10 seconds have passed!")
end)

-- Practical: send a temp message that auto-deletes
client:CreateCommand("temp", function(message, args)
    message:Reply("This will disappear in 5 seconds!")
    silicord.task.delay(5, function()
        message:Delete()
    end)
end)
```

---

## Full Example

```lua
local silicord = require("silicord")

local client = silicord.Connect({
    token  = "your token here",
    prefix = "!",
    app_id = "your app id here"
})

-- Cooldown middleware
local cooldowns = {}
client:AddMiddleware(function(ctx, cmd, args)
    local key = ctx.author.id .. ":" .. cmd
    if os.time() - (cooldowns[key] or 0) < 3 then
        ctx:Reply("Wait 3 seconds between commands.")
        return false
    end
    cooldowns[key] = os.time()
end)

-- Error handling
client.OnError:Connect(function(error_type, ctx, name, detail)
    if error_type == "CommandNotFound" then
        ctx:Reply("❌ Unknown command `!" .. name .. "`.")
    elseif error_type == "MissingArgument" then
        ctx:Reply("❌ Missing argument for `!" .. name .. "`.")
    elseif error_type == "CommandError" or error_type == "SlashCommandError" then
        ctx:Reply("❌ Something went wrong. Please try again.")
        print("[Error] " .. name .. ": " .. detail)
    end
end)

-- !ping
client:CreateCommand("ping", function(message, args)
    message:Reply("Pong!")
end)

-- !timeout @user 60 spamming
client:CreateCommand("timeout", function(message, args)
    local member = message:GetMember()
    member:Timeout(60, args.raw)
    message:Reply("User timed out for 60 seconds.")
end)

-- !announce hello everyone
client:CreateCommand("announce", function(message, args)
    message:Send("📢 " .. args.raw)  -- no ping
end)

-- !event
client:CreateCommand("event", function(message, args)
    local guild = message:GetGuild()
    guild:CreateEvent({
        name       = "Game Night",
        type       = "external",
        location   = "Voice Chat",
        start_time = "2025-09-01T20:00:00Z",
        end_time   = "2025-09-01T23:00:00Z"
    })
    message:Reply("Event created!")
end)

-- !vote (buttons — v1.0.0+ OOP style)
client:CreateCommand("vote", function(message, args)
    local yes = silicord.Instance.new("Button")
    yes.Label    = "Yes"
    yes.Style    = "success"
    yes.CustomId = "vote_yes"

    local no = silicord.Instance.new("Button")
    no.Label    = "No"
    no.Style    = "danger"
    no.CustomId = "vote_no"

    local row = silicord.Instance.new("ActionRow")
    row:Add(yes)
    row:Add(no)

    message:Reply("Cast your vote!", nil, { row:Build() })
end)

client:CreateComponent("vote_yes", function(interaction)
    interaction:Update("You voted **Yes**! ✅")
end)

client:CreateComponent("vote_no", function(interaction)
    interaction:Update("You voted **No**! ❌")
end)

-- DataStore: persistent score counter (v1.0.0+)
local db = silicord.DataStore("scores")
client:CreateCommand("score", function(message, args)
    local new = db:IncrementAsync(message.author.id, 1)
    message:Reply("Your score: **" .. new .. "**")
end)

-- Auto-delete temp message using task.delay (v1.0.0+)
client:CreateCommand("temp", function(message, args)
    message:Reply("This disappears in 5 seconds!")
    silicord.task.delay(5, function()
        message:Delete()
    end)
end)

-- /ping (slash command)
client:CreateSlashCommand("ping", {
    description = "Replies with pong"
}, function(interaction, args)
    interaction:Reply("Pong!")
end)

silicord.Run()
```

---

## License

MIT: see [LICENSE](LICENSE)

---

## Links

- [LuaRocks page](https://luarocks.org/modules/mrpandolaofficial-art/silicord)
- [GitHub](https://github.com/mrpandolaofficial/silicord)
- [Discord Developer Portal](https://discord.com/developers/applications)

---

## Version History

- **v1.0.0** — DataStore safety (atomic writes, corrupt JSON backup, safe `IncrementAsync`); `Color3` objects accepted directly in all color fields (no `:ToInt()` required); `task.defer()` and `task.delay()` added; `Instance.new("SelectMenu")` and `Instance.new("ActionRow")` OOP classes added; `silicord.Embed()`, `silicord.Button()`, `silicord.SelectMenu()`, and `silicord.ActionRow()` deprecated with runtime warnings
- **v0.4.3** — Added nice favicon
- **v0.4.2** — Fixed typo in `README.md`
- **v0.4.1** — Added new website: https://silicord.github.io/
- **v0.4.0** — Added custom error handling for bots via `client.OnError`
- **v0.3.3** — Minor bug fixes and improvements
- **v0.3.2** — Introduced token validation before startup
- **v0.3.1** — Introduced better error messages for easier debugging
- **v0.3.0** — Member object with `:Kick()`, `:Ban()`, `:Timeout()`, `:RemoveTimeout()`, `:GiveRole()`, `:RemoveRole()`, `:SetNickname()`, `:ResetNickname()`, `:SendDM()`; expanded channel types (stage, forum, media, announcement, category); channel/role editing and deletion; scheduled events (`guild:CreateEvent()`, `:EditEvent()`, `:DeleteEvent()`, `:GetEvents()`); `message:Send()` for no-ping messages; `message:Edit()` to edit bot messages; `message:Pin()` / `message:Unpin()`; `message:GetMember()` and `interaction:GetMember()`; `guild:Edit()` to edit the server; removed confusing internal gateway log
- **v0.2.2** — Automatic sharding, buttons & select menus (`silicord.Button`, `silicord.SelectMenu`, `silicord.ActionRow`, `client:CreateComponent`), rate limit bucket controller with auto-retry, state caching (`client.cache`), middleware system (`client:AddMiddleware`)
- **v0.2.0** — Guild object (`message:GetGuild()`), reactions (`message:React()`), embeds (`silicord.Embed()`), DMs (`message:SendPrivateMessage()`), prefix command arguments (`args[1]`, `args.raw`), slash commands (`client:CreateSlashCommand()`), `task.wait()` support in commands
- **v0.1.0** — silicord prototype released, basic `:Reply()` syntax, WebSocket gateway connection
- **v0.0.2** — Fixed WebSocket frame masking