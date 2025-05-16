-- BladeAutoReload with SafeAutoExec wrapper
-- Safe autoexec wrapper that prevents freezing
local SafeAutoExec = {}

function SafeAutoExec:Queue(scriptFunction)
    task.spawn(function()
             print("[SafeAutoExec] Waiting 30 seconds before starting execution...")
        task.wait(30)
        print("[SafeAutoExec] Starting execution sequence...")
        -- Step 1: Wait for game to fully load
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end
        
        -- Step 2: Wait for player to be available
        local player = game:GetService("Players").LocalPlayer
        if not player then
            player = game:GetService("Players").PlayerAdded:Wait()
        end
        
        -- Step 3: Wait for character to load
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            player.CharacterAdded:Wait()
        end
        
        -- Step 4: Wait for GUI to initialize (crucial)
        if not player:FindFirstChild("PlayerGui") then
            player:WaitForChild("PlayerGui", 30)
        end
        
        -- Step 5: Additional safety delay
        task.wait(3)
        
        -- Step 6: Execute the actual script function
        local success, err = pcall(scriptFunction)
        if not success then
            warn("[SafeAutoExec] Script execution failed: " .. tostring(err))
        end
    end)
    
    return true -- Return true to indicate queuing was successful
end

-- ============ Your actual script goes here ============
SafeAutoExec:Queue(function()
    -- BladeAutoReload.lua
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
end)
