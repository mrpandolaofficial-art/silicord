--[[ Here is a sample Lua script. You can modify it as needed. 
This script demonstrates a simple bot using silicord.
You can run this script after installing silicord via LuaRocks. 
Make sure to replace your bot token and other necessary 
information like prefixes and app ID.]]

local silicord = require("silicord") -- always require the library at the top

silicord.Connect({ -- provide necessary connection details
    token = "YourBotTokenHere", -- replace with your bot token
    prefix = "!", -- replace with your desired command prefix
    app_id = "YourAppIDHere", -- replace with your application ID; this is required for slash commands
})

-- simple command !ping
silicord:CreateCommand("ping", function(message, args)
    message:reply("Pong!")
end)

-- simple slash command /echo {text}
silicord:CreateSlashCommand("echo", {
    description = "Echoes back the provided text",
    options = {
        { name = "text", description = "The text to echo back", type = "string", required = true }
    }
}, function(interaction, args)
    interaction:Reply(args.text) -- replies with the text provided by the user
end)

silicord:CreateCommand("help", function(message, args)
    local embed = silicord.Embed({ -- note that using silicord.Embed({}) is deprecated, you can simply use silicord.Instance.new("Embed") instead.
        title = "Help",
        description = "Here are the available commands:",
        fields = {
            { name = "!ping", value = "Replies with Pong!", inline = true },
            { name = "/echo {text}", value = "Echoes back the provided text", inline = true },
            { name = "!help", value = "Shows this help message", inline = true },
            { name = "!hello", value = "Replies with Hi!", inline = true },
            { name = "Coming soon...", value = "More commands will be added in the future!", inline = false }
        }
    })
    message:Reply(embed)
end)

--[[ silicord provides native support and treats both 
prefix and slash commands equally ]]

-- try making a command called !hello which replies "Hi" below this line.