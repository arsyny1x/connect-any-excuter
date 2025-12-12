Services = setmetatable({}, { __index = function(Self, Key) return game:GetService(Key) end })
local Client = Services.Players.LocalPlayer
local SMethod = (WebSocket and WebSocket.connect)

if not SMethod then return Client:Kick("Executor is too shitty.") end

local Main = function()
    local Success, WebSocket = pcall(SMethod, "ws://localhost:9000/")
    if not Success or not WebSocket then 
        return 
    end

    local Closed = false
    local StartTime = tick()
    local Timeout = 3 

    WebSocket:Send(Services.HttpService:JSONEncode({
        Method = "Authorization",
        Name = Client.Name
    }))

    WebSocket.OnMessage:Connect(function(Unparsed)
        local Parsed = Services.HttpService:JSONDecode(Unparsed)

        if Parsed.Method == "Execute" then
            local Function, Error = loadstring(Parsed.Data)

            if Error then 
                WebSocket:Send(Services.HttpService:JSONEncode({
                    Method = "Error",
                    Message = Error
                }))
                return
            end
            
            Function()
        end
    end)
    
    WebSocket.OnClose:Connect(function()
        Closed = true
    end)

    while not Closed do
        if tick() - StartTime > Timeout then
            break 
        end
        task.wait()
    end
end

while task.wait(1) do
    local Success, Error = pcall(Main)
    if not Success then print(Error) end
end
