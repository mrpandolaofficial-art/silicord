# silicord v0.2.2

A Discord bot framework for Lua with **Luau-inspired syntax** — built for Roblox developers who want to write Discord bots using familiar patterns like `task.wait()`, Signals, and method chaining.

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
    -- args.user, args.reason are keyed by option name
    interaction:Reply("Banned " .. args.user .. ". Reason: " .. (args.reason or "none"))
end)
```

**Supported argument types:** `string`, `integer`, `number`, `bool`, `user`, `channel`, `role`, `any`

---

## Message Object

| Method | Description |
|--------|-------------|
| `message:Reply(text)` | Reply to the message |
| `message:Reply(embed)` | Reply with an embed only |
| `message:Reply(text, embed)` | Reply with text and an embed |
| `message:Reply(text, embed, components)` | Reply with text, embed, and buttons/menus |
| `message:React("👍")` | Add a reaction to the message |
| `message:Delete()` | Delete the message |
| `message:GetGuild()` | Returns a Guild object (uses cache automatically) |
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
```

### message.author

```lua
message.author.id        -- user ID
message.author.username  -- username
message.author.bot       -- true if the author is a bot
```

---

## Interaction Object (Slash Commands & Components)

Interactions have the same methods as Message with one difference — `Reply` sends an interaction response instead of a regular message.

```lua
interaction:Reply("Hello!")
interaction:Reply(embed)
interaction:Reply("Text", embed)
interaction:Update("Updated content")   -- update the original message (for buttons)
interaction:GetGuild()
interaction:SendPrivateMessage("Hey!")
interaction.args        -- table of slash command arguments keyed by name
interaction.values      -- selected values from a select menu
interaction.author      -- the user who triggered the command
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
-- or with text:
message:Reply("Here's some info:", embed)
```

---

## Components (Buttons & Select Menus)

```lua
-- Send a message with buttons
client:CreateCommand("vote", function(message, args)
    local row = silicord.ActionRow(
        silicord.Button({ label = "Yes",  style = "success",   custom_id = "vote_yes"  }),
        silicord.Button({ label = "No",   style = "danger",    custom_id = "vote_no"   }),
        silicord.Button({ label = "Skip", style = "secondary", custom_id = "vote_skip" })
    )
    message:Reply("Cast your vote!", nil, { row })
end)

-- Handle button clicks by custom_id
client:CreateComponent("vote_yes", function(interaction)
    interaction:Update("You voted **Yes**! ✅")
end)

client:CreateComponent("vote_no", function(interaction)
    interaction:Update("You voted **No**! ❌")
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
    -- interaction.values[1] is the selected value
    interaction:Update("You picked: **" .. interaction.values[1] .. "**")
end)
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
        -- check permissions here, return false to block
    end
end)
```

---

## Caching

silicord automatically caches guild and user data received from Discord gateway events. `message:GetGuild()` checks the cache first before ever making an HTTP request.

```lua
client.cache.guilds   -- table of guild data keyed by guild ID
client.cache.users    -- table of user data keyed by user ID
client.cache.bot_user -- the bot's own user object
```

---

## Sharding

Sharding is fully automatic. silicord fetches the recommended shard count from Discord on startup and spawns the correct number of gateway connections with the required delay between each. You don't need to configure anything.

---

## Guild Object

Get a guild from any message or interaction:

```lua
local guild = message:GetGuild()
-- guild.id, guild.name
```

| Method | Description |
|--------|-------------|
| `guild:CreateChannel(name, kind)` | Create a text or voice channel. `kind` = `"text"` or `"voice"` |
| `guild:CreateRole(name, color, permissions)` | Create a role |
| `guild:GetMembers(limit)` | Returns a list of members (max 1000) |
| `guild:GetRandomMember()` | Returns a random member's user object |
| `guild:GetChannels()` | Returns all channels in the guild |
| `guild:GetRoles()` | Returns all roles in the guild |
| `guild:KickMember(user_id, reason)` | Kick a member |
| `guild:BanMember(user_id, reason)` | Ban a member |

```lua
client:CreateCommand("randomuser", function(message, args)
    local guild = message:GetGuild()
    local user  = guild:GetRandomMember()
    message:Reply("Random pick: **" .. user.username .. "**")
end)

client:CreateCommand("setup", function(message, args)
    local guild = message:GetGuild()
    guild:CreateChannel("bot-logs", "text")
    guild:CreateRole("Member", "#3498DB")
    message:Reply("Server set up!")
end)
```

---

## task (Roblox-style Scheduler)

```lua
-- Yield for N seconds (works inside any command callback)
silicord.task.wait(2)

-- Spawn a new concurrent thread
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

-- !ping
client:CreateCommand("ping", function(message, args)
    message:Reply("Pong!")
end)

-- !say hello world
client:CreateCommand("say", function(message, args)
    if not args[1] then
        message:Reply("Usage: !say <text>")
        return
    end
    message:Reply(args.raw)
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
- [GitHub](https://github.com/mrpandolaofficial-art/silicord)
- [Discord Developer Portal](https://discord.com/developers/applications)

---

## Version History

- **v0.2.2** — Automatic sharding, buttons & select menus (`silicord.Button`, `silicord.SelectMenu`, `silicord.ActionRow`, `client:CreateComponent`), rate limit bucket controller with auto-retry, state caching (`client.cache`), middleware system (`client:AddMiddleware`)
- **v0.2.0** — Guild object (`message:GetGuild()`), reactions (`message:React()`), embeds (`silicord.Embed()`), DMs (`message:SendPrivateMessage()`), prefix command arguments (`args[1]`, `args.raw`), slash commands (`client:CreateSlashCommand()`), `task.wait()` support in commands
- **v0.1.0** — silicord prototype released, basic `:Reply()` syntax, WebSocket gateway connection
- **v0.0.2** — Fixed WebSocket frame masking