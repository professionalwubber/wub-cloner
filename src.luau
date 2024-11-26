if _G.wubcloner then
    return
end

_G.wubcloner = true

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local GameSettings = workspace:FindFirstChild("GameSettings")
local Content = workspace:FindFirstChild("content")

local Adding = {}
local Cache = {}

local AllBlocksLoaded = false

local function WaitForBlock(CreationDate: number)
    if game.PlaceId == 12519560096 then
        return
    end

    repeat
        task.wait()
    until Cache[CreationDate]

    return Cache[CreationDate] 
end

local function Serialize(Value: any)
    if typeof(Value) == "Color3" then
        return {"Color", {Value.R, Value.G, Value.B}}
    elseif typeof(Value) == "Vector3" then
        return {"Vector3", {Value.X, Value.Y, Value.Z}}
    elseif typeof(Value) == "CFrame" then
        return {"CFrame", {Value:GetComponents()}}
    elseif typeof(Value) == "Vector2" then
        return {"Vector2", {Value.X, Value.Y}}
    elseif typeof(Value) == "UDim" then
        return {"UDim", {Value.Scale, Value.Offset}}
    elseif typeof(Value) == "UDim2" then
        return {"UDim2", {Serialize(Value.X), Serialize(Value.Y)}}
    elseif typeof(Value) == "EnumItem" then
        return {"Enum", tostring(Value.EnumType).."."..Value.Name}
    elseif typeof(Value) == "BrickColor" then
        return {"BrickColor", Value.Name}
    end

    return Value
end

local function Deserialize(Value: any)
    if typeof(Value) == "table" then
        if Value[1] == "Color" then
            return Color3.new(table.unpack(Value[2]))
        elseif Value[1] == "Vector3" then
            return Vector3.new(table.unpack(Value[2]))
        elseif Value[1] == "CFrame" then
            return CFrame.new(table.unpack(Value[2]))
        elseif Value[1] == "Vector2" then
            return Vector2.new(table.unpack(Value[2]))
        elseif Value[1] == "UDim" then
            return UDim.new(table.unpack(Value[2]))
        elseif Value[1] == "UDim2" then
            return UDim2.new(Deserialize(Value[2][1]), Deserialize(Value[2][2]))
        elseif Value[1] == "Enum" then
            local Split = string.split(Value[2], ".")
            return Enum[Split[1]][Split[2]]
        elseif Value[1] == "BrickColor" then
            return BrickColor.new(Value[2])
        end
    end

    return Value
end

local function Save()
    if game.PlaceId == 12519560096 then
        return
    end

    local BlockProperties = require(ReplicatedStorage.BlockProperties)
    local Attributes = BlockProperties.GetAttributes()

    local World = {
        Name = GameSettings:GetAttribute("GameName"),
        Description = GameSettings:GetAttribute("GameDescription"),
        Thumbnail = GameSettings:GetAttribute("ImageId"),
        MaxPlayers = GameSettings:GetAttribute("MaxPlayers"),
        Settings = {},
        Blocks = {},
        Zones = {},
        Teams = {},
        Stats = {}
    }

    for Name: string, Value: any in pairs(GameSettings.SavedSettings:GetAttributes()) do
        Name = string.gsub(Name, "_", " ")
        table.insert(World.Settings, {Name, Serialize(Value)})
    end

    for _, Block in ipairs(Content:GetChildren()) do
        local Id = Block:GetAttribute("PropertiesID")
        local OriginalCFrame = Block:GetAttribute("OriginalCFrame")
        
        local Properties = BlockProperties.GetProperties(Id)
        local ToSave = {
            Properties = {},
            Attributes = {},
            Connections = {},
            CreationDate = Block:GetAttribute("CreationDate")
        }

        for Category: string, Info: any in pairs(Properties) do
            if Category ~= "Name" then
                for Name: string, Value: any in pairs(Info) do
                    if not string.match(Name, "HINT") then
                        local NewValue

                        if table.find(Value, false, 3) then
                            local Child = Value[1]

                            if Child then
                                NewValue = Block:FindFirstChild(Child, true)[Name]
                            else
                                NewValue = Block[Name]
                            end
                        else
                            NewValue = Block:GetAttribute(Name)
                        end

                        ToSave.Properties[Name] = {Value[1] or Properties.Name[1], Serialize(NewValue)}
                    end
                end
            end
        end

        ToSave.Properties["1"] = Block.Name
        ToSave.Properties["2"] = Serialize(OriginalCFrame)

        for _, Child in ipairs(Block:GetChildren()) do
            if Child:IsA("ObjectValue") and Attributes[Child.Name] and not ToSave.Attributes[Child.Name] then
                local Attribute = {
                    [1] = Child.Name,
                    [2] = {
                        [1] = "self",
                        [2] = Child:FindFirstChild("FOR2") and Child.FOR2.Value ~= Child.FOR1.Value and Child.FOR2.Value:GetAttribute("CreationDate") or "self",
                        [3] = Serialize(Child:GetAttribute("Face") and Enum.NormalId[Child:GetAttribute("Face")] or Enum.NormalId.Front)
                    },
                    [3] = {}
                }
                
                for Name: string, Info: any in pairs(Attributes[Child.Name][2]) do
                    if not string.match(Name, "HINT") then
                        Attribute[3][Name] = Serialize(Child:GetAttribute(Name))
                    end
                end

                table.insert(ToSave.Attributes, Attribute)
            end
        end

        if Block:GetAttribute("TypeOf") and Block:FindFirstChild("WiringWire") then
            for _, Wire in ipairs(Block:GetChildren()) do
                if Wire.Name == "WiringWire" and Wire:FindFirstChild("OUTPUT") and Wire.OUTPUT.Value then
                    table.insert(ToSave.Connections, {"self", Wire.OUTPUT.Value:GetAttribute("CreationDate")})
                end
            end
        end

        table.insert(World.Blocks, ToSave)
    end

    for _, Zone in ipairs(workspace.Zones:GetChildren()) do
        local ZoneProperties = BlockProperties.GetZones(Zone.Name)
        local Properties = {}

        for Category: string, Info: any in pairs(ZoneProperties) do
            if Category ~= "Name" then
                for Name: string, Value: any in pairs(Info) do
                    if not string.match(Name, "HINT") then
                        local NewValue

                        if table.find(Value, false, 3) then
                            local Child = Value[1]

                            if Child then
                                NewValue = Zone:FindFirstChild(Child, true)[Name]
                            else
                                NewValue = Zone[Name]
                            end
                        else
                            NewValue = Zone:GetAttribute(Name)
                        end

                        Properties[Name] = {Value[1] or Zone.Name, Serialize(NewValue)}
                    end
                end
            end
        end

        Properties["1"] = Zone.Name
        Properties["2"] = Serialize(Zone:GetAttribute("OriginalCFrame"))

        table.insert(World.Zones, Properties)
    end

    for _, Team: Team in ipairs(Teams:GetTeams()) do
        table.insert(World.Teams, {
            Name = Team.Name,
            TeamColor = Team.TeamColor.Name,
            Auto = Team.AutoAssignable
        })
    end

    for _, Stat in ipairs(GameSettings.SavedStats.KnownStats:GetChildren()) do
        table.insert(World.Stats, {
            Name = Stat.Name,
            Save = Stat:GetAttribute("SAVE"),
            Visible = Stat:GetAttribute("VISIBLE")
        })
    end

    local JSON = HttpService:JSONEncode(World)
    writefile("wub cloner/"..game.PlaceId..".txt", JSON)
end

local function Load(World)
    if game.PlaceId == 12519560096 then
        return
    end

    local BridgeNet2 = require(ReplicatedStorage:WaitForChild("BridgeNet2"))
    local ChangeBridge = BridgeNet2.ClientBridge("ChangeBridge")
    local RunCommand = BridgeNet2.ClientBridge("RunCommand")

    local ChangeAttribute = ReplicatedStorage.events.ChangeAttribute

    ChangeBridge:Fire{"settings", {"Game Name", World.Name}}
    ChangeBridge:Fire{"settings", {"Game Description", World.Description}}

    for _, Setting in ipairs(World.Settings) do
        Setting[2] = Deserialize(Setting[2])
        ChangeBridge:Fire{"settings", Setting}
    end

    for _, Team in ipairs(World.Teams) do
        RunCommand:Fire("!team add "..Team.Name.." "..Team.TeamColor)

        if Team.Auto then
            RunCommand:Fire("!team autoassign "..Team.Name.." true")
        end
    end

    for _, Stat in ipairs(World.Stats) do
        RunCommand:Fire("!stat add "..Stat.Name)
        
        if not Stat.Save then
            RunCommand:Fire("!stat save "..Stat.Name.." false")
        end

        if not Stat.Visible then
            RunCommand:Fire("!stat visible "..Stat.Name.." false")
        end
    end

    for _, Zone in ipairs(World.Zones) do
        for Name: string, Value: any in pairs(Zone) do
            if tostring(Name) ~= "1" and tostring(Name) ~= "2" then
                Zone[Name][2] = Deserialize(Value[2])
            else
                Zone[Name] = Deserialize(Value)
            end
        end

        ChangeBridge:Fire{"newzone", Zone}
    end

    AllBlocksLoaded = false

    for _, Block in ipairs(World.Blocks) do
        for Name: string, Value: any in pairs(Block.Properties) do
            if tostring(Name) ~= "1" and tostring(Name) ~= "2" then
                Block.Properties[Name][2] = Deserialize(Value[2])
            else
                Block.Properties[Name] = Deserialize(Value)
            end
        end

        table.insert(Adding, Block)
        ChangeBridge:Fire{"build", Block.Properties}

        task.spawn(function()
            repeat
                task.wait()
            until AllBlocksLoaded

            for _, Attribute in ipairs(Block.Attributes) do
                Attribute[2][1] = if Attribute[2][1] == "self" then WaitForBlock(Block.CreationDate) else WaitForBlock(Attribute[2][1])
                Attribute[2][2] = if Attribute[2][2] == "self" then WaitForBlock(Block.CreationDate) else WaitForBlock(Attribute[2][2])
                Attribute[2][3] = Deserialize(Attribute[2][3])

                for Name: string, Value: any in pairs(Attribute[3]) do
                    Attribute[3][Name] = Deserialize(Value)
                end

                ChangeAttribute:FireServer("createAttribute", Attribute)
                task.wait(0.05)
            end
            
            for _, Connection in ipairs(Block.Connections) do
                Connection[1] = if Connection[1] == "self" then WaitForBlock(Block.CreationDate) else WaitForBlock(Connection[1])
                Connection[2] = if Connection[2] == "self" then WaitForBlock(Block.CreationDate) else WaitForBlock(Connection[2])
            
                ChangeBridge:Fire{"newLine", Connection}
                task.wait(0.05)
            end
        end)

        task.wait()
    end

    repeat
        task.wait()
    until #Content:GetChildren() >= #World.Blocks

    task.wait(0.5)
    AllBlocksLoaded = true
end

local function Clear()
    local BridgeNet2 = require(ReplicatedStorage:WaitForChild("BridgeNet2"))
    local ChangeBridge = BridgeNet2.ClientBridge("ChangeBridge")
    local RunCommand = BridgeNet2.ClientBridge("RunCommand")

    ChangeBridge:Fire{
        "bulkdelete",
        {Content:GetChildren()}
    }

    for _, Zone in ipairs(workspace.Zones:GetChildren()) do
        ChangeBridge:Fire{
            "removezone",
            {Zone}
        }
    end

    for _, Stat in ipairs(GameSettings.SavedStats.KnownStats:GetChildren()) do
        RunCommand:Fire("!stat remove "..Stat.Name)
    end

    for _, Team in ipairs(Teams:GetTeams()) do
        RunCommand:Fire("!team remove "..Team.Name)
    end

    task.wait(0.5)
    if #Content:GetChildren() > 0 or #workspace.Zones:GetChildren() > 0 or #GameSettings.SavedStats.KnownStats:GetChildren() > 0 or #Teams:GetTeams() > 0 then
        Clear()
    end
end

if not isfolder("wub cloner") then
    makefolder("wub cloner")
end

if Content then
    Content.ChildAdded:Connect(function(Child)
        for Index: number, Block in ipairs(Adding) do
            local OriginalCFrame = Child:GetAttribute("OriginalCFrame")

            if not OriginalCFrame then
                Child:GetAttributeChangedSignal("OriginalCFrame"):Wait()
                OriginalCFrame = Child:GetAttribute("OriginalCFrame")
            end

            if Block.Properties["1"] == Child.Name and Block.Properties["2"] == OriginalCFrame then
                Cache[Block.CreationDate] = Child
                table.remove(Adding, Index)
                return
            end
        end
    end)
end

if isfile("wub cloner/steps.txt") then
    local Info = readfile("wub cloner/steps.txt")
    local Id, Amount = string.gsub(Info, "hub", "")

    if Amount > 0 then
        if game.PlaceId ~= 12519560096 then
            StarterGui:SetCore("SendNotification", {
                Title = "wub cloner",
                Text = "!clone - auto clone world\n!save - save a world\n!load {world_id} - load a saved world\n!id - copy the world id",
            })

            delfile("wub cloner/steps.txt")
        else
            writefile("wub cloner/steps.txt", Id)
            ReplicatedStorage.Events.CreateWorld:FireServer()
            TeleportService:SetTeleportGui(StarterGui.loading)
        end
    else
        if game.PlaceId ~= 12519560096 and isfile("wub cloner/"..Id..".txt") then
            if ReplicatedStorage:WaitForChild("StartupEvent", 5) and GameSettings:GetAttribute("GameCreationDate") == 0 then
                local JSON = readfile("wub cloner/"..Id..".txt")
                local World = HttpService:JSONDecode(JSON)

                ReplicatedStorage.StartupEvent:FireServer(1, World.Name)
                ReplicatedStorage.StartupEvent:FireServer(2, "Canvas")
                task.wait()
                ReplicatedStorage.StartupEvent:FireServer("done")

                if Players.LocalPlayer.PlayerGui:FindFirstChild("StartupGui") then
                    Players.LocalPlayer.PlayerGui.StartupGui:Destroy()
                end

                repeat
                    task.wait()
                until #Content:GetChildren() == 5
            end

            Clear()
            task.wait()
            Load(World)

            StarterGui:SetCore("SendNotification", {
                Title = "wub cloner",
                Text = "finished cloning "..Id
            })

            delfile("wub cloner/steps.txt")
        end
    end
else
    if game.PlaceId ~= 12519560096 then
        StarterGui:SetCore("SendNotification", {
            Title = "wub cloner",
            Text = "!clone - auto clone world\n!save - save a world\n!load {world_id} - load a saved world\n!id - copy the world id",
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "wub cloner",
            Text = "join a world to clone it"
        })
    end
end

Players.LocalPlayer.PlayerGui.ChildAdded:Connect(function(Gui)
    if Gui.Name == "StartupGui" then
        Gui:Destroy()
    end
end)

local Check = false
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if not Check then
        Check = true
        queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/professionalwubber/wub-cloner/refs/heads/main/src.luau'))()")
    end
end)

TextChatService.SendingMessage:Connect(function(Message: TextChatMessage)
    if not Message.TextSource or Message.TextSource.UserId ~= Players.LocalPlayer.UserId then
        return
    end
    
    if Message.Text == "!clone" then
        Save()
        writefile("wub cloner/steps.txt", "hub"..game.PlaceId)
        
        TeleportService.TeleportInitFailed:Connect(function(Plr: Player)
            if Player.Name == Players.LocalPlayer.Name then
                TeleportService:Teleport(12519560096, Plr, {Reason = "~ wub cloner ~\ncreating a new world to clone world into"})
            end
        end)

        TeleportService:Teleport(12519560096, Players.LocalPlayer, {Reason = "~ wub cloner ~\ncreating a new world to clone world into"})
    elseif Message.Text == "!save" then
        Save()
        
        StarterGui:SetCore("SendNotification", {
            Title = "wub cloner",
            Text = "finished saving "..game.PlaceId
        })
    elseif Message.Text == "!id" then
        setclipboard(tostring(game.PlaceId))

        StarterGui:SetCore("SendNotification", {
            Title = "wub cloner",
            Text = "copied "..game.PlaceId.." to clipboard"
        })
    else
        local Split = string.split(Message.Text, " ")

        if Split[1] == "!load" and tonumber(Split[2]) and isfile("wub cloner/"..Split[2]..".txt") then
            if game.PlaceId ~= 12519560096 then
                local JSON = readfile("wub cloner/"..Split[2]..".txt")
                local World = HttpService:JSONDecode(JSON)
                
                if ReplicatedStorage:WaitForChild("StartupEvent", 5) and GameSettings:GetAttribute("GameCreationDate") == 0 then
                    ReplicatedStorage.StartupEvent:FireServer(1, World.Name)
                    ReplicatedStorage.StartupEvent:FireServer(2, "Canvas")
                    task.wait()
                    ReplicatedStorage.StartupEvent:FireServer("done")

                    if Players.LocalPlayer.PlayerGui:FindFirstChild("StartupGui") then
                        Players.LocalPlayer.PlayerGui.StartupGui:Destroy()
                    end

                    repeat
                        task.wait()
                    until #Content:GetChildren() == 5
                end

                Clear()
                task.wait()
                Load(World)

                StarterGui:SetCore("SendNotification", {
                    Title = "wub cloner",
                    Text = "finished loading "..Split[2]
                })
            else
                StarterGui:SetCore("SendNotification", {
                    Title = "wub cloner",
                    Text = "join one of your worlds to use the load command"
                })
            end
        end
    end
end)
