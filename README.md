# silicord

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
| `message:React("👍")` | Add a reaction to the message |
| `message:Delete()` | Delete the message |
| `message:GetGuild()` | Returns a Guild object for the server |
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

## Interaction Object (Slash Commands)

Interactions have the same methods as Message with one difference — `Reply` sends an interaction response instead of a regular message.

```lua
interaction:Reply("Hello!")
interaction:Reply(embed)
interaction:Reply("Text", embed)
interaction:GetGuild()
interaction:SendPrivateMessage("Hey!")
interaction.args        -- table of slash command arguments keyed by name
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

-- !embed
client:CreateCommand("embed", function(message, args)
    local embed = silicord.Embed({
        title       = "silicord",
        description = "A Discord bot framework for Lua.",
        color       = "#5865F2",
        footer      = "Built with silicord"
    })
    message:Reply(embed)
end)

-- !ban @user spamming
client:CreateCommand("ban", function(message, args)
    local guild = message:GetGuild()
    if guild and args[1] then
        guild:BanMember(args[1], args.raw:match("^%S+%s+(.+)$"))
        message:Reply("User banned.")
    end
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