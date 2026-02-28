# To be added in silicord v1.2.x

### v1.2.0 Additions

- Addition of new `message` actions like `:Unreact()`.
- Addition of new SilicordServices and `silicord:GetService("service")`:
    - `AIService`: Use a paid/free API key to connect an external AI to your bot.
    - `HttpService`: Make requests to external HTTP links.
    - `VoiceChatService`: Allows the bot creator to use functions like `VCS:JoinVoiceChannel(channel)`, etc.
- Addition of `client:SetPresence()`
    - Example:
    ```lua
    local silicord = require("silicord")

    local client = silicord.Connect({
        token = 'MTQ..........'
        prefix = '!'
        app_id = '123456789012' -- required for presence
    })

    client:SetPresence({
        presence = 'online' -- online, dnd, idle, or invisible
        status = 'blah blah blah' -- the status that appears under the bots name
    })

    -- command logic below
    ```
    
- Allow `:Reply()` and `:Send()` to return the message object. For example
    ```lua
    local response = message:Reply("Here is my message!")
    silicord.task.wait(2)
    response:Edit("This message has been edited now!")
    ```