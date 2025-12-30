local Services = setmetatable({}, { __index = function(Self, Key) return game.GetService(game, Key) end })
local Client = Services.Players.LocalPlayer
local SMethod = (WebSocket and WebSocket.connect)

if not SMethod then return Client:Kick("Executor does not support WebSockets") end

local task = task or {wait = wait, spawn = spawn}

local function SafeMain()

    local Success, WS = pcall(SMethod, "ws://localhost:9000/")
    
    if not Success or not WS then
        return 
    end

    local Closed = false

    WS:Send(Services.HttpService:JSONEncode({
        Method = "Authorization",
        Name = Client.Name
    }))

    WS.OnMessage:Connect(function(Unparsed)
        local Success, Parsed = pcall(function() return Services.HttpService:JSONDecode(Unparsed) end)
        if not Success then return end
        
        if (Parsed.Method == "Execute") then
            local Function, Error = loadstring(Parsed.Data)
            if Error then 
                pcall(function() WS:Send(Services.HttpService:JSONEncode({Method = "Error", Message = Error})) end)
                return 
            end
            task.spawn(Function)
        end
    end)

    WS.OnClose:Connect(function()
        Closed = true
    end)

    -- วนลูปเช็คสถานะในนี้
    while not Closed do
        task.wait(1)
    end
end

task.spawn(function()
    print("Bridge System: Started")
    while true do
        SafeMain()
        task.wait(5) 
    end
end)