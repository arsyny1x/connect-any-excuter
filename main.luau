Services = setmetatable({}, { __index = function(_, Key) return game:GetService(Key) end })
local Client = Services.Players.LocalPlayer
local SMethod = (WebSocket and WebSocket.connect)

-- Abort if the executor does not support WebSocket
if not SMethod then 
    return Client:Kick("Executor does not support required WebSocket features.")
end

local function Main()
    -- Try to connect to the local WebSocket server
    local Success, WebSocket = pcall(SMethod, "ws://localhost:9000/")
    
    -- If connection fails, exit immediately to avoid freezing
    if not Success or not WebSocket then 
        return 
    end

    local Closed = false
    local StartTime = tick()
    local Timeout = 3  -- Prevent infinite waiting if server never closes the connection

    -- Send authorization packet
    WebSocket:Send(Services.HttpService:JSONEncode({
        Method = "Authorization",
        Name = Client.Name
    }))

    -- Listen for incoming messages
    WebSocket.OnMessage:Connect(function(Unparsed)
        local Parsed = Services.HttpService:JSONDecode(Unparsed)

        if Parsed.Method == "Execute" then
            local Function, ErrorMsg = loadstring(Parsed.Data)

            -- Return error to server if the compilation failed
            if ErrorMsg then
                WebSocket:Send(Services.HttpService:JSONEncode({
                    Method = "Error",
                    Message = ErrorMsg
                }))
                return
            end
            
            -- Execute received code
            Function()
        end
    end)

    -- Detect disconnection
    WebSocket.OnClose:Connect(function()
        Closed = true
    end)

    -- Wait for disconnection or timeout
    while not Closed do
        if tick() - StartTime > Timeout then
            break  -- Prevent the game from freezing if VS Code server is not running
        end
        task.wait()
    end
end

-- Retry connection every 5 seconds (to prevent lag spikes)
local retryDelay = 5

while task.wait(retryDelay) do
    local Success, ErrorMsg = pcall(Main)
    if not Success then
        warn("WebSocket reconnect failed:", ErrorMsg)
    end
end
