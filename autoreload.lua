
-- BladeAutoReload.lua
local function runMainScript()

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService =  game:GetService("GuiService")

local player     = Players.LocalPlayer
local pg         = player:WaitForChild("PlayerGui", 5)

-- follow your confirmed path
local iface      = pg:WaitForChild("Interface", 5)
local hud        = iface:WaitForChild("HUD",       5)
local main       = hud:WaitForChild("Main",      5)
local top        = main:WaitForChild("Top",       5)
local blades     = top:WaitForChild("Blades",    5)
local inner      = blades:WaitForChild("Inner",    5)
local bar        = inner:WaitForChild("Bar",       5)
local gradient   = bar:WaitForChild("Gradient",  5)  -- UIGradient

assert(gradient:IsA("UIGradient"), 
       "BladeAutoReload ▶ Gradient not found or wrong type")

-- confirm Vector2
assert(typeof(gradient.Offset) == "Vector2",
       "BladeAutoReload ▶ Expected Offset to be Vector2")

local debounce     = false
local DEBOUNCE_TIME = 0.5
local refill = game.Players.LocalPlayer.PlayerGui.Interface.Mobile.Refill
local inset = GuiService:GetGuiInset()
local posX = refill.AbsolutePosition.X + refill.AbsoluteSize.X/2 + inset.X
local posY = refill.AbsolutePosition.Y + refill.AbsoluteSize.Y/2 + inset.Y

RunService.RenderStepped:Connect(function()
    local x = gradient.Offset.X

    if x <= 0 and not debounce then
        debounce = true

        -- simulate R‐press (wrapped in pcall for safety)
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true,  "R", false, game)
            vim:SendKeyEvent(false, "R", false, game)
            task.wait(0.05)
            vim:SendMouseButtonEvent(posX, posY, 0, true, game, 1)
            task.wait(0.05)
            vim:SendMouseButtonEvent(posX, posY, 0, false, game, 1)
            task.wait(0.05)
            vim:SendTouchEvent(0, Vector2.new(posX, posY), true)
            task.wait(0.05)
            vim:SendTouchEvent(0, Vector2.new(posX, posY), false)
        end)

        -- reset after a short delay
        task.delay(DEBOUNCE_TIME, function()
            debounce = false
        end)
    end
end)
       end
task.spawn(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    local player = game:GetService("Players").LocalPlayer
    if not player then
        player = game:GetService("Players").PlayerAdded:Wait()
    end
    
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    
    task.wait(2) -- Additional safety wait
    
    runMainScript()
end)
