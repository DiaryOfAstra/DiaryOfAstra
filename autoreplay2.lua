-- Services
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

if game.PlaceId == 91797414023830 then
    return -- Stop execution if PlaceId matches
end

-- Shortcuts
local player = Players.LocalPlayer
local dataRemote = ReplicatedStorage:WaitForChild("Bridgenet2Main"):WaitForChild("dataRemoteEvent")

-- Config
local BOSS_PREFIX = { "Eto_", "Tatara_", "Noro_", "Kuzen_" }
local AUTO_CLICK_ATTEMPTS = 20  -- Increased for more reliability
local CLICK_INTERVAL = 0.5      -- How often to try clicking the button
local MAX_REPLAY_WAIT = 300     -- 5 minutes of replay button checking
local SPAM_DURATION = 20
local PLATFORM = UserInputService.TouchEnabled and "Mobile" or "Desktop"
local DEBUG_MODE = true  -- Enable debug output

-- State
local isScriptActive = true
local bossSpawned = false
local connectionEstablished = false
local replayCheckActive = false

-- Debug printing function
local function debug(msg)
    if DEBUG_MODE then
        print("[AUTO-BOSS] " .. msg)
    end
end

debug("Script started - Platform: " .. PLATFORM)

-- Enhanced Mobile touch simulation with variable pressure
local function simulateMobileTap(x, y, duration)
    if not PLATFORM == "Mobile" then return end
    
    duration = duration or 0.1
    debug("Simulating mobile tap at " .. x .. ", " .. y .. " for " .. duration .. "s")
    
    -- Send press event
    VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(x, y), true)
    task.wait(duration)
    -- Send release event
    VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(x, y), false)
    
    -- Optional: Add slight finger movement for more natural tap
    local jitterX = x + math.random(-3, 3)
    local jitterY = y + math.random(-2, 2)
    task.wait(0.05)
    VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(jitterX, jitterY), true)
    task.wait(0.07)
    VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(jitterX, jitterY), false)
end

-- Mobile tap sequence (multiple taps in slightly different positions)
local function mobileTapSequence(centerX, centerY)
    -- Center tap
    simulateMobileTap(centerX, centerY, 0.15)
    task.wait(0.2)
    
    -- Surrounding taps in a small radius
    for i = 1, 3 do
        local offsetX = centerX + math.random(-15, 15)
        local offsetY = centerY + math.random(-10, 10)
        simulateMobileTap(offsetX, offsetY, 0.1)
        task.wait(0.15)
    end
end

-- Enhanced button clicker that keeps trying if the GUI appears
local function persistentReplayButtonClicker()
    if replayCheckActive then return end
    replayCheckActive = true
    
    debug("Starting persistent replay button checker (will run for 5 minutes)")
    
    -- Start a persistent timer
    local startTime = os.time()
    local buttonFound = false
    
    -- Keep checking until time expires or script deactivated
    while os.time() - startTime < MAX_REPLAY_WAIT and isScriptActive do
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then 
            task.wait(1)
            continue 
        end
        
        -- Try finding the vote GUI
        local voteGui = playerGui:FindFirstChild("Vote")
        if voteGui then
            local replayButton = voteGui.Frame.CosmeticInterface:FindFirstChild("Replay")
            if replayButton then
                debug("Replay button found at " .. os.time() - startTime .. "s into checking")
                buttonFound = true
                
                -- Get inset and calculate position
                local inset = GuiService:GetGuiInset()
                local posX = replayButton.AbsolutePosition.X + replayButton.AbsoluteSize.X/2 + inset.X
                local posY = replayButton.AbsolutePosition.Y + replayButton.AbsoluteSize.Y/2 + inset.Y
                
                -- Visual selection (works on Desktop)
                GuiService.SelectedObject = replayButton
                task.wait(0.1)
                
                -- Execute platform-specific click methods
                if PLATFORM == "Desktop" then
                    debug("Executing desktop click sequence")
                    -- Multiple click attempts
                    for i = 1, AUTO_CLICK_ATTEMPTS do
                        if not replayButton:IsDescendantOf(game) then 
                            debug("Button disappeared, stopping click sequence")
                            break 
                        end
                        
                        -- Force UI selection before each click
                        GuiService.SelectedObject = replayButton
                        task.wait(0.05)
                        
                        -- Mouse click
                        VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, true, game, 1)
                        task.wait(0.05)
                        VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, false, game, 1)
                        
                        -- Direct activation attempts
                        pcall(function() firesignal(replayButton.Activated) end)
                        pcall(function() firesignal(replayButton.MouseButton1Click) end)
                        
                        debug("Click attempt " .. i)
                        task.wait(CLICK_INTERVAL)
                    end
                else
                    debug("Executing mobile tap sequence")
                    -- Mobile-specific tap sequence
                    for i = 1, AUTO_CLICK_ATTEMPTS do
                        if not replayButton:IsDescendantOf(game) then 
                            debug("Button disappeared, stopping tap sequence")
                            break 
                        end
                        
                        -- Enhanced mobile tap sequence
                        mobileTapSequence(posX, posY)
                        
                        -- Direct activation attempts
                        pcall(function() firesignal(replayButton.Activated) end)
                        pcall(function() firesignal(replayButton.MouseButton1Click) end)
                        
                        debug("Tap sequence " .. i)
                        task.wait(CLICK_INTERVAL)
                    end
                end
                
                -- Break out of the loop if button is gone (likely successful)
                if not voteGui:IsDescendantOf(game) or not replayButton:IsDescendantOf(game) then
                    debug("Button/GUI removed - click likely successful")
                    break
                end
            end
        end
        
        -- Also check for any buttons with "Replay" text in the entire GUI
        if not buttonFound then
            for _, gui in pairs(player.PlayerGui:GetDescendants()) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and 
                   ((gui.Text and gui.Text:lower():find("replay")) or 
                    (gui.Name:lower():find("replay"))) then
                    
                    debug("Found alternative replay button: " .. gui:GetFullName())
                    buttonFound = true
                    
                    -- Get position
                    local inset = GuiService:GetGuiInset()
                    local altPosX = gui.AbsolutePosition.X + gui.AbsoluteSize.X/2 + inset.X
                    local altPosY = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y/2 + inset.Y
                    
                    -- Set selection
                    GuiService.SelectedObject = gui
                    task.wait(0.1)
                    
                    -- Platform-specific clicking
                    if PLATFORM == "Desktop" then
                        for i = 1, AUTO_CLICK_ATTEMPTS do
                            VirtualInputManager:SendMouseButtonEvent(altPosX, altPosY, 0, true, game, 1)
                            task.wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(altPosX, altPosY, 0, false, game, 1)
                            pcall(function() firesignal(gui.Activated) end)
                            pcall(function() firesignal(gui.MouseButton1Click) end)
                            task.wait(CLICK_INTERVAL)
                        end
                    else
                        for i = 1, AUTO_CLICK_ATTEMPTS do
                            mobileTapSequence(altPosX, altPosY)
                            pcall(function() firesignal(gui.Activated) end)
                            pcall(function() firesignal(gui.MouseButton1Click) end)
                            task.wait(CLICK_INTERVAL)
                        end
                    end
                    
                    break
                end
            end
        }
        
        -- Short delay between checks to prevent performance impact
        task.wait(1)
    end
    
    debug("Persistent replay button check ended after " .. (os.time() - startTime) .. " seconds")
    replayCheckActive = false
end

-- Space spam function with mobile support
local function spamSpace()
    debug("Starting space/touch spam for " .. SPAM_DURATION .. " seconds")
    local startTime = os.time()
    while os.time() - startTime < SPAM_DURATION and isScriptActive do
        if PLATFORM == "Desktop" then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        else
            -- For mobile, simulate tap in center screen
            local viewportSize = workspace.CurrentCamera.ViewportSize
            local centerX = viewportSize.X / 2
            local centerY = viewportSize.Y / 2
            
            VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(centerX, centerY), true)
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(centerX, centerY), false)
        end
        task.wait(0.5)
    end
    debug("Space/touch spam completed")
end

-- Boss detection system with lifecycle tracking
local function setupBossDetection()
    -- Loop to find boss
    while isScriptActive do
        local bossFound = false
        for _, ent in ipairs(workspace.Entities:GetChildren()) do
            for _, prefix in ipairs(BOSS_PREFIX) do
                if ent.Name:find("^"..prefix) then
                    bossFound = true
                    bossSpawned = true
                    
                    debug("Boss detected: " .. ent.Name)
                    
                    -- Connect to boss removal to detect death
                    local function onBossRemoved()
                        if not bossSpawned then return end -- Prevent duplicate triggers
                        
                        debug("Boss removed/died - starting replay button check")
                        bossSpawned = false
                        
                        -- Start replay button checker in separate thread
                        task.spawn(persistentReplayButtonClicker)
                        
                        -- Also spam space as a backup method
                        task.spawn(function()
                            task.wait(1)
                            spamSpace()
                        end)
                    end
                    
                    -- Connect to multiple events to detect boss death
                    local ancestryConn
                    ancestryConn = ent.AncestryChanged:Connect(function(_, newParent)
                        if not newParent then
                            debug("Boss removed from workspace")
                            ancestryConn:Disconnect()
                            onBossRemoved()
                        end
                    end)
                    
                    -- Also watch for humanoid death
                    local humanoid = ent:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        local diedConn
                        diedConn = humanoid.Died:Connect(function()
                            debug("Boss humanoid died")
                            diedConn:Disconnect()
                            onBossRemoved()
                        end)
                    end
                    
                    -- Additional health-based detection
                    local health = ent:FindFirstChild("Health")
                    if health and health:IsA("NumberValue") then
                        -- Set up health change watch
                        local conn
                        conn = health.Changed:Connect(function(newHealth)
                            if newHealth <= 0 then
                                debug("Boss health reached zero")
                                conn:Disconnect()
                                onBossRemoved()
                            end
                        end)
                    end
                    
                    break
                end
            end
            if bossFound then break end
        end
        
        if not bossFound then
            bossSpawned = false
        end
        
        task.wait(2)
    end
end

-- Main void & combat script (unchanged from your original)
local function runCombatScript()
    -- Services
    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService        = game:GetService("RunService")
    local TweenService      = game:GetService("TweenService")

    -- Shortcuts
    local player     = Players.LocalPlayer
    local dataRemote = ReplicatedStorage
        :WaitForChild("Bridgenet2Main")
        :WaitForChild("dataRemoteEvent")

    -- Config
    local ORIGINAL_VOID_POSITION = CFrame.new(-77.13, -60.28, -172.75) -- Keep as backup
    local VOID_DOWN_OFFSET       = Vector3.new(0, -10000, 0) -- Very deep void
    local ATTACK_DELAY           = 0.05
    local STICK_OFFSET           = Vector3.new(0, 3, 0)
    local BOSS_PREFIX            = { "Eto_", "Tatara_", "Noro_", "Kuzen_" }
    local VOID_TIMER             = 49 -- 49 seconds before forced void
    local REWARD_WAIT            = 250
    local VOID_TWEEN_INTERVAL    = 0.2 -- How often to force tween downward during void

    -- State
    local stopSignal     = { value = false }
    local bossDefeated   = { value = false }
    local isFirstSpawn   = true
    local debugMode      = true
    local voidingInProgress = false

    -- Debug printer
    local function debug(msg)
        if debugMode then
            print("[VOID SCRIPT] " .. msg)
        end
    end

    -- Dash before teleporting to make it work properly
    local function dashAndTeleport(destination)
        local char = player.Character
        if not char then return false end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        
        -- Fire dash twice for better results
        for i = 1, 2 do
            dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
            task.wait(0.01)
        end
        
        -- Then teleport
        hrp.CFrame = destination
        return true
    end

    -- Simple initial void for first spawn
    local function doInitialVoid()
        debug(">>> INITIAL VOID")
        local char = player.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        -- Use dash + teleport three times for reliability
        for i = 1, 3 do
            -- Dash + direct teleport
            dashAndTeleport(ORIGINAL_VOID_POSITION)
            task.wait(0.1)
            
            -- Dash + additional push down
            dashAndTeleport(CFrame.new(hrp.Position + Vector3.new(0, -500, 0)))
            task.wait(0.1)
        end
        
        debug("Initial void complete")
    end

    -- Strategic void function with dash before teleport
    local function forceVoidUntilRespawn()
        if voidingInProgress then return end
        voidingInProgress = true
        
        debug(">>> DASH + TELEPORT + VOID SEQUENCE STARTED")
        stopSignal.value = true -- Stop all other processes
        
        -- Create a separate thread for the void process
        task.spawn(function()
            local char = player.Character
            if not char then return end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- STEP 1: Forcefully break connection to boss
            debug("Step 1: Breaking boss connection")
            
            -- Cancel attack mode if it was enabled
            dataRemote:FireServer({ [1]={Module="Toggle",IsHolding=false}, [2]=utf8.char(5) })
            debug("Attack mode disabled")
            
            -- Reset animation states if possible
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                task.wait(0.1)
                hum:ChangeState(Enum.HumanoidStateType.Landed)
            end
            
            -- Reset all body velocities and forces
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new(0, 0, 0)
                    part.RotVelocity = Vector3.new(0, 0, 0)
                    
                    -- Remove any constraints or attachments
                    for _, attachment in pairs(part:GetChildren()) do
                        if attachment:IsA("Attachment") or attachment:IsA("Constraint") then
                            attachment:Destroy()
                        end
                    end
                end
            end
            
            -- Current position for reference
            local currentPos = hrp.Position
            
            -- STEP 2: Use dash + teleport to break connections
            debug("Step 2: Dash + teleport to break connections")
            local farDistance = 200 -- Move 200 studs away
            local randomDirection = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit
            local farPosition = currentPos + (randomDirection * farDistance)
            
            -- CRITICAL: Fire dash remote before teleporting
            debug("Firing dash remote before teleport")
            dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
            task.wait(0.01)
            dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
            task.wait(0.05)
            
            -- Direct teleport to break connections
            hrp.CFrame = CFrame.new(farPosition)
            debug("Teleported to new position")
            task.wait(0.5)
            
            -- Fire dash again to establish new position
            dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
            task.wait(0.1)
            
            -- STEP 3: Now perform a gradual descent from new position
            debug("Step 3: Beginning gradual descent")
            
            -- Create several stage drops from our new position
            local stageDrops = {
                {dist = -50, time = 0.8},   -- First small drop
                {dist = -100, time = 1.0},  -- Medium drop
                {dist = -300, time = 1.5},  -- Larger drop
                {dist = -500, time = 2.0},  -- Major drop
            }
            
            local initialChar = player.Character
            
            -- Execute stage drops
            for i, stage in ipairs(stageDrops) do
                if player.Character ~= initialChar then
                    debug("Character changed during descent - void successful")
                    break
                end
                
                -- Safety check
                if not hrp or not hrp.Parent then
                    debug("HumanoidRootPart no longer valid")
                    break
                end
                
                -- Fire dash before each tween
                debug("Firing dash before stage " .. i .. " tween")
                dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
                task.wait(0.05)
                
                -- Get current position to maintain horizontal position
                local currentHorizontalPos = Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
                
                -- Calculate next position (keep X,Z, lower Y)
                local nextPos = Vector3.new(
                    currentHorizontalPos.X,
                    currentHorizontalPos.Y + stage.dist,
                    currentHorizontalPos.Z
                )
                
                debug(("Stage %d: Descending %d studs over %.1f seconds"):format(i, -stage.dist, stage.time))
                
                -- Create and play descent tween
                local descentTween = TweenService:Create(
                    hrp, 
                    TweenInfo.new(stage.time, Enum.EasingStyle.Linear), 
                    {CFrame = CFrame.new(nextPos)}
                )
                descentTween:Play()
                
                -- Wait for tween or for character to change
                local tweenStartTime = os.time()
                while descentTween.PlaybackState ~= Enum.PlaybackState.Completed 
                      and player.Character == initialChar 
                      and os.time() - tweenStartTime < stage.time + 1 do
                    if hrp then
                        debug(("Current Y position: %.2f"):format(hrp.Position.Y))
                    end
                    task.wait(0.5)
                end
                
                -- If character changed, we're done
                if player.Character ~= initialChar then
                    debug("Character changed - void successful")
                    break
                end
            end
            
            -- STEP 4: If we're still not dead, do one final dash + teleport
            if player.Character == initialChar and hrp and hrp.Parent then
                debug("Final safety measure: dash + deep drop")
                
                -- Dash first
                dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
                task.wait(0.05)
                
                -- Then teleport
                hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -2000, 0))
                
                -- Wait a bit more to confirm void
                task.wait(2)
                
                -- If STILL not dead, try dash + noclipping + teleport
                if player.Character == initialChar and hrp and hrp.Parent then
                    debug("Extra safety: dash + noclip + teleport")
                    
                    -- Dash first
                    dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
                    task.wait(0.05)
                    
                    -- Disable collision on all parts
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                    
                    -- Final deep teleport
                    hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -5000, 0))
                end
            end
            
            debug("Void sequence complete")
            voidingInProgress = false
        end)
    end


    -- Locates boss model & root part
    local function findBoss()
        for _, ent in ipairs(workspace.Entities:GetChildren()) do
            for _, prefix in ipairs(BOSS_PREFIX) do
                if ent.Name:find("^"..prefix) then  -- Check if name starts with prefix
                    return ent
                end
            end
        end
        return nil
    end

    -- Attack loop
    local function performAttacks()
        debug("Attack loop started")
        local seq = {"M1", "Z"}
        while not stopSignal.value do
            for _, mod in ipairs(seq) do
                if stopSignal.value then break end
                dataRemote:FireServer({ [1]={Module=mod}, [2]=utf8.char(5) })
                task.wait(ATTACK_DELAY)
            end
        end
        debug("Attack loop ended")
    end

    -- Stick-to-boss loop
    local function maintainPosition()
        debug("Position loop started")
        while not stopSignal.value do
            local boss = findBoss()
            if boss then
                local root = boss:FindFirstChild("RootPart") or boss:FindFirstChild("Torso") or boss.PrimaryPart
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and hrp then
                    dataRemote:FireServer({ [1]={Module="Dash"}, [2]=utf8.char(5) })
                    task.wait(0.01)
                    hrp.CFrame = root.CFrame + STICK_OFFSET
                end
            end
            task.wait(0.25)
        end
        debug("Position loop ended")
    end

    -- Hook boss death
    local function watchBossDeath(bossModel)
        local hum = bossModel:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        local conn
        conn = hum.Died:Connect(function()
            debug("Boss Humanoid.Died detected!")
            bossDefeated.value = true
            stopSignal.value = true
            conn:Disconnect()
            
            -- Trigger replay button check when boss dies
            task.spawn(persistentReplayButtonClicker)
        end)

        -- Additional safety: watch for boss model removal
        local ancestryConn
        ancestryConn = bossModel.AncestryChanged:Connect(function(_, newParent)
            if not newParent then
                debug("Boss model removed from workspace!")
                bossDefeated.value = true
                stopSignal.value = true
                ancestryConn:Disconnect()
                
                -- Trigger replay button check when boss is removed
                task.spawn(persistentReplayButtonClicker)
            end
        end)
    end

    -- Main per-spawn routine
    local function onCharacterSpawned(char)
        debug("Character spawned ("..(isFirstSpawn and "FIRST" or "RESPAWN")..")")
        stopSignal.value = false
        bossDefeated.value = false
        voidingInProgress = false
        local spawnTime = os.time()
        task.wait(2)

        if isFirstSpawn then
            isFirstSpawn = false
            debug("FIRST SPAWN → immediate void")
            doInitialVoid()
            return
        end

        -- Boss fight setup
        debug("Entering boss fight")
        local boss = findBoss()
        if boss then
            watchBossDeath(boss)
        else
            debug("WARNING: Boss not found at fight start")
        end

        -- Toggle attack mode
        dataRemote:FireServer({ [1]={Module="Toggle",IsHolding=true}, [2]=utf8.char(5) })
        debug("Attack mode enabled")

        -- Spawn loops
        local atkThread = task.spawn(performAttacks)
        local posThread = task.spawn(maintainPosition)

        -- Simple void-timer thread
        local voidTimerConn
        voidTimerConn = task.spawn(function()
            debug("Void timer set for "..VOID_TIMER.."s")
            
            -- Wait exactly the specified time
            for i = 1, VOID_TIMER do
                if stopSignal.value or bossDefeated.value then break end
                task.wait(1)
                if i % 10 == 0 then
                    debug("Void timer: " .. (VOID_TIMER - i) .. "s remaining")
                end
            end

            if not bossDefeated.value and not stopSignal.value then
                debug("VOID TIMER FIRED - STOPPING ALL ACTIVITY AND STARTING VOID TWEEN")
                stopSignal.value = true  -- First stop all other processes
                
                -- Wait a brief moment for other loops to terminate
                task.wait(0.5)
                
                -- Then start the clean void tween
                forceVoidUntilRespawn()
            else
                debug("Void cancelled: boss already defeated or script stopped")
            end
        end)

        -- Boss-defeat reward waiter
        task.spawn(function()
            while not stopSignal.value do
                task.wait(0.5)
            end
            if bossDefeated.value then
                debug("Waiting "..REWARD_WAIT.."s for loot")
                task.wait(REWARD_WAIT)
                debug("Loot wait complete")
            end
        end)

        -- Wait for stop, then cleanup
        repeat task.wait(0.1) until stopSignal.value
        debug("Stopping loops and cleaning up")
        task.cancel(atkThread)
        task.cancel(posThread)
        debug("Cleanup done")
    end

    -- Setup keybind for emergency void
    local userInputService = game:GetService("UserInputService")
    userInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
            debug("V key pressed - emergency void")
            forceVoidUntilRespawn()
        end
    end)

    -- Init connection
    debug("Script initializing")
    player.CharacterAdded:Connect(onCharacterSpawned)
    if player.Character then
        debug("Character existed on init → running handler")
        onCharacterSpawned(player.Character)
    end
    debug("Setup complete")
}

-- Main execution
local function startScript()
    -- Start boss detection in a separate thread
    task.spawn(setupBossDetection)
    
    -- Initial space spam to help with startup
    spamSpace()
    
    -- Start combat script
    runCombatScript()
    
    -- Safety check: Start a periodic check for the replay button in case boss detection fails
    task.spawn(function()
        while isScriptActive do
            task.wait(30) -- Check every 30 seconds
            if not bossSpawned and not replayCheckActive then
                debug("Periodic safety check - looking for replay button")
                persistentReplayButtonClicker()
            end
        end
    end)
end

-- Script safety and cleanup
UserInputService.WindowFocusReleased:Connect(function()
    isScriptActive = false
end)

-- Start the script
startScript()
