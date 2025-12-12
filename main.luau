-- // Services Shortcut
local Services = setmetatable({}, {
    __index = function(_, Key)
        return game:GetService(Key)
    end
})

local Client = Services.Players.LocalPlayer
local SMethod = (WebSocket and WebSocket.connect)

-- // Executor Check
if not SMethod then
    return Client:Kick("Executor is too shitty.")
end

-- // Check if local server is up
local function is_server_up()
    local success, err = pcall(
        Services.HttpService.GetAsync,
        Services.HttpService,
        "http://localhost:9000/"
    )

    if success then
        return true
    end

    if err:find("ConnectFail") then
        return false
    end

    -- Port open but wrong protocol/other error
    return true
end

-- // Main Loop
local function Main()
    if not is_server_up() then
        return
    end

    local success, WebSocket = pcall(SMethod, "ws://localhost:9000/")
    if not success then
        return
    end

    local Closed = false

    -- // Identify client
    WebSocket:Send(Services.HttpService:JSONEncode({
        Method = "Authorization",
        Name = Client.Name
    }))

    -- // Receive Messages
    WebSocket.OnMessage:Connect(function(raw)
        local Parsed = Services.HttpService:JSONDecode(raw)

        if Parsed.Method == "Execute" then
            local func, err = loadstring(Parsed.Data)

            if err then
                return WebSocket:Send(Services.HttpService:JSONEncode({
                    Method = "Error",
                    Message = err
                }))
            end

            func()
        end
    end)

    -- // Detect Close
    WebSocket.OnClose:Connect(function()
        Closed = true
    end)

    repeat
        task.wait()
    until Closed
end

-- // Retry Loop
while task.wait(1) do
    local ok, err = pcall(Main)
    if not ok then
        warn(err)
    end
end
