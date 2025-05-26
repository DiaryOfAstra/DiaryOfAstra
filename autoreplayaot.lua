-- Place this in your autoexecute folder
-- Safe autoexec wrapper that prevents freezing
local SafeAutoExec = {}

function SafeAutoExec:Queue(scriptFunction)
    task.spawn(function()
        task.wait(15)
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
        end
    end)
    
    return true -- Return true to indicate queuing was successful
end

-- ============ Your actual script goes here ============
SafeAutoExec:Queue(function()
    local function runMainnnScript()
    -- Services
    local Players = game:GetService("Players")
    local GuiService = game:GetService("GuiService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local UserInputService = game:GetService("UserInputService")

    -- Config
    local AUTO_CLICK_ATTEMPTS = 10
    local CHECK_INTERVAL = 2
    local RUNTIME_MINUTES = 15
    local PLATFORM = (UserInputService:GetLastInputType() == Enum.UserInputType.Touch) and "Mobile" or "Desktop"
    local DEBUG_MODE = true

    -- State
    local isRunning = true
    local lastClickTime = 0
    local isScriptActive = true
    local player = Players.LocalPlayer

    local function debug(message)
        if DEBUG_MODE then
        end
    end

    local function getRetryButton()
        return player:WaitForChild("PlayerGui", 10)
            :WaitForChild("Interface", 5)
            :WaitForChild("Rewards", 5)
            :WaitForChild("Main", 3)
            :WaitForChild("Info", 3)
            :WaitForChild("Main", 3)
            :WaitForChild("Buttons", 3)
            :FindFirstChild("Retry")
    end

    local function simulateTap(x, y)
        if PLATFORM == "Mobile" then
            VirtualInputManager:SendTouchEvent(0, Vector2.new(x, y), true)
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(0, Vector2.new(x, y), false)
        end
    end

    local function isOnCooldown()
        return (tick() - lastClickTime) < 2.5
    end

    local function clickRetry()
        if isOnCooldown() then return end
        
        local retryButton = getRetryButton()
        if not retryButton then
            return
        end

        if not retryButton.Visible then
            return
        end

        lastClickTime = tick()

        -- Get click position with GUI inset
        local inset = GuiService:GetGuiInset()
        local posX = retryButton.AbsolutePosition.X + retryButton.AbsoluteSize.X/2 + inset.X
        local posY = retryButton.AbsolutePosition.Y + retryButton.AbsoluteSize.Y/2 + inset.Y

        -- Platform-specific interaction
        if PLATFORM == "Mobile" then
            -- Method 1: Direct GUI interaction
                local success1 = pcall(function()
                    GuiService.SelectedObject = retryButton
                    task.wait(0.1)
                    -- Try to directly invoke the button
                    if retryButton and retryButton.Activated then
                        retryButton.Activated:Fire()
                    end
                end)
                
                -- Method 2: Direct button invoke
                task.wait(0.1)
                pcall(function()
                    if typeof(retryButton) == "Instance" and retryButton:IsA("GuiButton") then
                        -- Try to find and call the click handler directly
                        for _, connection in pairs(getconnections(retryButton.MouseButton1Click)) do
                            connection:Fire()
                        end
                        for _, connection in pairs(getconnections(retryButton.Activated)) do
                            connection:Fire()
                        end
                    end
                end)
                
                -- Method 3: SendMouseButtonEvent without GUI inset
                task.wait(0.1)
                local posX = retryButton.AbsolutePosition.X + retryButton.AbsoluteSize.X/2
                local posY = retryButton.AbsolutePosition.Y + retryButton.AbsoluteSize.Y/2
                
                VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, false, game, 0)
        else
            for i = 1, AUTO_CLICK_ATTEMPTS do
                VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, false, game, 1)
            end
        end

        -- Direct signal activation
        pcall(function()
            firesignal(retryButton.Activated)
            firesignal(retryButton.MouseButton1Click)
        end)
    end

    -- Main loop
    local endTime = tick() + (RUNTIME_MINUTES * 60)

    spawn(function()
        while isRunning and tick() < endTime do
            clickRetry()
            for i = 1, CHECK_INTERVAL * 10 do
                if not isRunning then break end
                task.wait(0.1)
            end
        end
        isScriptActive = false
    end)

    -- Cleanup handlers
    UserInputService.WindowFocusReleased:Connect(function()
        isRunning = false
    end)

    player.CharacterAdded:Connect(function()
        clickRetry()  -- Extra click attempt on respawn
    end)
    end

    runMainnnScript()
end)
