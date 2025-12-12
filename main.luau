Services = setmetatable({}, { __index = function(_, Key) return game:GetService(Key) end })
local Client = Services.Players.LocalPlayer
local SMethod = (WebSocket and WebSocket.connect)

if not SMethod then 
    return Client:Kick("Executor does not support WebSocket.")
end

local function Main()
    local Success, WebSocket = pcall(SMethod, "ws://localhost:9000/")

    -- If cannot connect → exit safely
    if not Success or not WebSocket then
        return false
    end

    local Closed = false

    -- Safe close function to prevent freezing when server dies suddenly
    local function SafeClose()
        if not Closed then
            Closed = true
            pcall(function()
                WebSocket:Close()
            end)
        end
    end

    -- Send authorization
    pcall(function()
        WebSocket:Send(Services.HttpService:JSONEncode({
            Method = "Authorization",
            Name = Client.Name
        }))
    end)

    -- Handle messages
    WebSocket.OnMessage:Connect(function(Unparsed)
        local Parsed
        local ok, err = pcall(function()
            Parsed = Services.HttpService:JSONDecode(Unparsed)
        end)

        if not ok then
            SafeClose()
            return
        end

        if Parsed.Method == "Execute" then
            local fn, loadErr = loadstring(Parsed.Data)

            if loadErr then
                pcall(function()
                    WebSocket:Send(Services.HttpService:JSONEncode({
                        Method = "Error",
                        Message = loadErr
                    }))
                end)
                return
            end

            -- Run user code
            pcall(fn)
        end
    end)

    -- Detect server close
    WebSocket.OnClose:Connect(function()
        SafeClose()
    end)

    -- Heartbeat to detect silent dead socket (server crash)
    task.spawn(function()
        while not Closed do
            local ok = pcall(function()
                WebSocket:Send("ping")
            end)
            if not ok then
                SafeClose()
                break
            end
            task.wait(1)
        end
    end)

    -- Wait until closed
    while not Closed do
        task.wait()
    end

    return true
end

-- Delay reconnect to prevent freeze/spam
local retryDelay = 3

while task.wait(retryDelay) do
    local ok = pcall(Main)
    if not ok then
        warn("WebSocket connection failed, retrying...")
    end
end
