# [silicord](https://silicord.github.io) v0.4.3

A Discord bot framework for Lua with **Luau-inspired syntax** — built for Roblox developers who want to write Discord bots using familiar patterns like `task.wait()`, Signals, and method chaining.

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

```lua
client:CreateCommand("info", function(message, args)
    message:React("👀")
    local embed = silicord.Embed({
        title       = "Hello!",
        description = "This is an embed.",
        color       = "#5865F2",
        footer      = "silicord"
    })
    message:Reply(embed)
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
| `member:SendDM(text, embed)` | Send the member a DM |

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
interaction:Update("Updated content")     -- update the original message (for buttons)
interaction:Update(text, embed, components)
interaction:GetGuild()
interaction:GetMember()                   -- returns a Member object
interaction:SendPrivateMessage(text)
interaction.args    -- slash command arguments keyed by name
interaction.values  -- selected values from a select menu
interaction.author  -- the user who triggered the interaction
```

---

## Embeds

```lua
local embed = silicord.Embed({
    title       = "My Embed",
    description = "This is the description.",
    color       = "#5865F2",          -- hex string or integer
    url         = "https://example.com",
    timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),

    author      = "Author Name",
    author_icon = "https://example.com/icon.png",
    author_url  = "https://example.com",

    footer      = "Footer text",
    footer_icon = "https://example.com/icon.png",

    image       = "https://example.com/image.png",
    thumbnail   = "https://example.com/thumb.png",

    fields = {
        { name = "Field 1", value = "Value 1", inline = true  },
        { name = "Field 2", value = "Value 2", inline = true  },
        { name = "Field 3", value = "Value 3", inline = false }
    }
})

message:Reply(embed)
message:Reply("Here's some info:", embed)
```

---

## Components (Buttons & Select Menus)

```lua
-- Buttons
client:CreateCommand("vote", function(message, args)
    local row = silicord.ActionRow(
        silicord.Button({ label = "Yes",  style = "success",   custom_id = "vote_yes"  }),
        silicord.Button({ label = "No",   style = "danger",    custom_id = "vote_no"   }),
        silicord.Button({ label = "Skip", style = "secondary", custom_id = "vote_skip" })
    )
    message:Reply("Cast your vote!", nil, { row })
end)

client:CreateComponent("vote_yes", function(interaction)
    interaction:Update("You voted **Yes**! ✅")
end)
```

**Button styles:** `primary`, `secondary`, `success`, `danger`, `link`

```lua
-- Select menu
client:CreateCommand("color", function(message, args)
    local row = silicord.ActionRow(
        silicord.SelectMenu({
            custom_id   = "color_pick",
            placeholder = "Pick a color",
            options = {
                { label = "Red",   value = "red",   description = "A warm color"    },
                { label = "Blue",  value = "blue",  description = "A cool color"    },
                { label = "Green", value = "green", description = "A natural color" }
            }
        })
    )
    message:Reply("Choose a color:", nil, { row })
end)

client:CreateComponent("color_pick", function(interaction)
    interaction:Update("You picked: **" .. interaction.values[1] .. "**")
end)
```

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

The `ctx` argument is always either a Message or Interaction object, so you can always call `:Reply()` on it to send feedback directly to the user.

---

## Guild Object

Get a guild from any message or interaction:

```lua
local guild = message:GetGuild()
-- guild.id, guild.name
```

| Method | Description |
|--------|-------------|
| `guild:CreateChannel(name, kind, options)` | Create a channel. See channel types below |
| `guild:EditChannel(channel_id, options)` | Edit an existing channel |
| `guild:DeleteChannel(channel_id)` | Delete a channel |
| `guild:CreateRole(name, color, permissions)` | Create a role |
| `guild:EditRole(role_id, options)` | Edit an existing role |
| `guild:DeleteRole(role_id)` | Delete a role |
| `guild:GetMembers(limit)` | Returns a list of Member objects |
| `guild:GetMember(user_id)` | Returns a single Member object |
| `guild:GetRandomMember()` | Returns a random Member object |
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
    name       = "Game Night",
    description = "Monthly game night!",
    type       = "external",
    location   = "Discord Stage",
    start_time = "2025-09-01T20:00:00Z",
    end_time   = "2025-09-01T23:00:00Z"
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

## Middleware

Middleware hooks run before every command. Return `false` to block the command entirely.

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

-- Admin-only hook
client:AddMiddleware(function(ctx, cmd, args)
    if cmd == "ban" then
        -- check permissions, return false to block
    end
end)
```

---

## Caching

silicord automatically caches guild and user data from Discord gateway events. `message:GetGuild()` checks the cache before making an HTTP request.

```lua
client.cache.guilds   -- table of guild data keyed by guild ID
client.cache.users    -- table of user data keyed by user ID
client.cache.bot_user -- the bot's own user object
```

---

## Sharding

Sharding is fully automatic. silicord fetches the recommended shard count from Discord on startup and spawns the correct number of gateway connections with the required delay between each. You don't need to configure anything.

---

## task (Roblox-style Scheduler)

```lua
silicord.task.wait(2)

silicord.task.spawn(function()
    silicord.task.wait(5)
    print("5 seconds later")
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
    local member = message:GetMember()  -- or guild:GetMember(id)
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

-- !vote (buttons)
client:CreateCommand("vote", function(message, args)
    local row = silicord.ActionRow(
        silicord.Button({ label = "Yes", style = "success", custom_id = "vote_yes" }),
        silicord.Button({ label = "No",  style = "danger",  custom_id = "vote_no"  })
    )
    message:Reply("Cast your vote!", nil, { row })
end)

client:CreateComponent("vote_yes", function(interaction)
    interaction:Update("You voted **Yes**! ✅")
end)

client:CreateComponent("vote_no", function(interaction)
    interaction:Update("You voted **No**! ❌")
end)

-- /ping (slash)
client:CreateSlashCommand("ping", {
    description = "Replies with pong"
}, function(interaction, args)
    interaction:Reply("Pong!")
end)

silicord.Run()
```

---

## License

MIT — see [LICENSE](LICENSE)

---

## Links

- [LuaRocks page](https://luarocks.org/modules/mrpandolaofficial-art/silicord)
- [GitHub](https://github.com/mrpandolaofficial/silicord)
- [Discord Developer Portal](https://discord.com/developers/applications)

---

## Version History
- **v0.4.3** - Added nice favicon
- **v0.4.2** - Fixed typo in `README.md`
- **v0.4.1** - Added new website: https://silicord.github.io/
- **v0.4.0** - Added custom error handling for bots via `client.OnError`
- **v0.3.3** - Minor bug fixes and improvements
- **v0.3.2** - Introduced token validation before startup
- **v0.3.1** - Introduced better error messages for easier debugging.
- **v0.3.0** — Member object with `:Kick()`, `:Ban()`, `:Timeout()`, `:RemoveTimeout()`, `:GiveRole()`, `:RemoveRole()`, `:SetNickname()`, `:ResetNickname()`, `:SendDM()`; expanded channel types (stage, forum, media, announcement, category); channel/role editing and deletion; scheduled events (`guild:CreateEvent()`, `:EditEvent()`, `:DeleteEvent()`, `:GetEvents()`); `message:Send()` for no-ping messages; `message:Edit()` to edit bot messages; `message:Pin()` / `message:Unpin()`; `message:GetMember()` and `interaction:GetMember()`; `guild:Edit()` to edit the server; removed confusing internal gateway log
- **v0.2.2** — Automatic sharding, buttons & select menus (`silicord.Button`, `silicord.SelectMenu`, `silicord.ActionRow`, `client:CreateComponent`), rate limit bucket controller with auto-retry, state caching (`client.cache`), middleware system (`client:AddMiddleware`)
- **v0.2.0** — Guild object (`message:GetGuild()`), reactions (`message:React()`), embeds (`silicord.Embed()`), DMs (`message:SendPrivateMessage()`), prefix command arguments (`args[1]`, `args.raw`), slash commands (`client:CreateSlashCommand()`), `task.wait()` support in commands
- **v0.1.0** — silicord prototype released, basic `:Reply()` syntax, WebSocket gateway connection
- **v0.0.2** — Fixed WebSocket frame masking