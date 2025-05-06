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
local AUTO_CLICK_ATTEMPTS = 10  -- Increased from 5 to 10
local SPAM_DURATION = 20
local PLATFORM = (UserInputService and UserInputService:GetLastInputType() == Enum.UserInputType.Touch) and "Mobile" or "Desktop"
local DEBUG_MODE = true  -- Enable debug output
local CHECK_INTERVAL = 2       -- How often to check for the replay button (seconds)
local RUNTIME_MINUTES = 15     -- How long the script should run (minutes)
local isRunning = true            -- Control variable for main loop
local lastClickTime = 0        -- Track when we last attempted to click a button

-- State
local isScriptActive = true
local bossSpawned = false
local connectionEstablished = false

local function debug(message)
    local timeStr = string.format("%.1f", tick())
    print("[ReplayClicker " .. timeStr .. "] " .. message)
end

debug("Script started - will run for " .. RUNTIME_MINUTES .. " minutes")
debug("Platform detected: " .. PLATFORM)

-- Track if selection is visible
local isSelectionVisible = true
pcall(function()
    isSelectionVisible = GuiService.SelectionImageObject ~= nil
end)

-- Mobile touch simulation with extended duration
local function simulateTap(x, y)
    if PLATFORM == "Mobile" then
        debug("Simulating extended mobile tap at " .. x .. ", " .. y)
        local startTime = os.clock()
        local TAP_DURATION = 15  -- 15 seconds of continuous tapping
        
        -- Create a new thread for extended tapping
        spawn(function()
            while os.clock() - startTime < TAP_DURATION and isScriptActive do
                -- Send press and release events with realistic timing
                pcall(function()
                    VirtualInputManager:SendTouchEvent(0, Vector2.new(x, y), true)
                    task.wait(math.random(0.03, 0.07))  -- Randomize press duration
                    VirtualInputManager:SendTouchEvent(0, Vector2.new(x, y), false)
                end)
                
                -- Add random delay between taps for human-like pattern
                task.wait(math.random(0.1, 0.3))
                
                -- Slightly vary position for more natural-looking taps
                local varX = x + math.random(-3, 3)
                local varY = y + math.random(-3, 3)
                pcall(function()
                    VirtualInputManager:SendTouchEvent(0, Vector2.new(varX, varY), true)
                    task.wait(math.random(0.03, 0.07))
                    VirtualInputManager:SendTouchEvent(0, Vector2.new(varX, varY), false)
                end)
                
                task.wait(math.random(0.1, 0.3))
            end
            debug("Extended tap sequence completed")
        end)
    end
end

-- Function to check if button click is on cooldown
local function isOnCooldown()
    local cooldownTime = 3 -- seconds between allowed click attempts
    return (tick() - lastClickTime) < cooldownTime
end

-- Main function to find and click replay button
local function autoClickReplay()
    if isOnCooldown() then return end
    
    debug("Searching for replay button...")
    
    -- Check if PlayerGui exists (player might be respawning)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        debug("PlayerGui not found - player might be respawning")
        return
    end
    
    -- Look for potential GUI containers that might hold the replay button
    local potentialGuis = {}
    
    -- First check for the Vote GUI
    local voteGui = playerGui:FindFirstChild("Vote")
    if voteGui then
        table.insert(potentialGuis, voteGui)
    end
    
    -- Look for other potential GUIs that might contain replay functionality
    for _, guiObject in pairs(playerGui:GetChildren()) do
        if guiObject:IsA("ScreenGui") and 
          (guiObject.Name:lower():find("game") or 
           guiObject.Name:lower():find("ui") or 
           guiObject.Name:lower():find("death") or 
           guiObject.Name:lower():find("end") or
           guiObject.Name:lower():find("result") or
           guiObject.Name:lower():find("round")) then
            table.insert(potentialGuis, guiObject)
        end
    end
    
    -- If we found no likely GUIs, check all screen GUIs
    if #potentialGuis == 0 then
        for _, guiObject in pairs(playerGui:GetChildren()) do
            if guiObject:IsA("ScreenGui") then
                table.insert(potentialGuis, guiObject)
            end
        end
    end
    
    -- Search for replay button in potential GUIs
    local replayButton
    
    -- First, try to find specifically named replay buttons in these GUIs
    for _, gui in ipairs(potentialGuis) do
        -- Try the specific path from original script first
        if gui.Name == "Vote" then
            local specificPath = gui:FindFirstChild("Frame") and 
                                gui.Frame:FindFirstChild("CosmeticInterface") and
                                gui.Frame.CosmeticInterface:FindFirstChild("Replay")
            
            if specificPath then
                replayButton = specificPath
                debug("Found replay button at expected path: " .. replayButton:GetFullName())
                break
            end
        end
        
        -- Then try to find any replay button by name
        for _, obj in pairs(gui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and
               (obj.Name == "Replay" or obj.Name:lower():find("replay")) then
                replayButton = obj
                debug("Found replay button by name: " .. replayButton:GetFullName())
                break
            end
            
            -- Check text property for buttons
            if obj:IsA("TextButton") and obj.Text and obj.Text:lower():find("replay") then
                replayButton = obj
                debug("Found replay button by text: " .. replayButton:GetFullName())
                break
            end
        end
        
        if replayButton then break end
    end
    
    -- If still not found, check for any GUI element with replay in its name/text
    if not replayButton then
        for _, guiElement in pairs(playerGui:GetDescendants()) do
            if (guiElement:IsA("TextButton") or guiElement:IsA("ImageButton")) then
                -- Check name
                if guiElement.Name:lower():find("replay") or guiElement.Name:lower():find("retry") then
                    replayButton = guiElement
                    debug("Found button with replay/retry in name: " .. guiElement:GetFullName())
                    break
                end
                
                -- Check text for TextButtons
                if guiElement:IsA("TextButton") and guiElement.Text and 
                   (guiElement.Text:lower():find("replay") or 
                    guiElement.Text:lower():find("play again") or 
                    guiElement.Text:lower():find("retry")) then
                    replayButton = guiElement
                    debug("Found button with replay/retry in text: " .. guiElement:GetFullName())
                    break
                end
            end
        end
    end
    
    if not replayButton then
        debug("No replay button found")
        return
    end
    
    -- Verify the button is still valid and visible
    if not replayButton:IsDescendantOf(game) then
        debug("Button is no longer in the game")
        return
    end
    
    -- Check if button is visible
    local isVisible = true
    pcall(function()
        isVisible = replayButton.Visible
    end)
    
    if not isVisible then
        debug("Button found but not visible")
        return
    end
    
    -- Set last click time to prevent rapid rechecking
    lastClickTime = tick()
    debug("Attempting to click replay button: " .. replayButton:GetFullName())
    
    -- Try to make button selectable if it isn't
    pcall(function()
        if replayButton:IsA("GuiObject") and not replayButton.Selectable then
            replayButton.Selectable = true
        end
    end)
    
    -- Visual selection (works on Desktop)
    if isSelectionVisible then
        pcall(function()
            GuiService.SelectedObject = replayButton
            debug("Set selected object")
        end)
    end
    
    -- Get click position accounting for platform differences
    local inset = GuiService:GetGuiInset()
    local posX = replayButton.AbsolutePosition.X + replayButton.AbsoluteSize.X/2 + inset.X
    local posY = replayButton.AbsolutePosition.Y + replayButton.AbsoluteSize.Y/2 + inset.Y
    
    debug("Clicking at position: " .. posX .. ", " .. posY)
    
    -- Start extended tapping for mobile devices
    if PLATFORM == "Mobile" then
        simulateTap(posX, posY)
    end
    
    -- Multiple attempts to ensure button click
    for i = 1, AUTO_CLICK_ATTEMPTS do
        if not replayButton:IsDescendantOf(game) then 
            debug("Replay button no longer exists, breaking loop")
            break 
        end
        
        -- Platform-specific input methods
        if PLATFORM == "Desktop" then
            debug("Desktop click attempt " .. i)
            VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, false, game, 1)
        else
            debug("Mobile tap attempt " .. i)
            -- For mobile, use TouchEvent with correct parameters
            VirtualInputManager:SendTouchEvent(0, Vector2.new(posX, posY), true)
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(0, Vector2.new(posX, posY), false)
            
            -- Add a slight delay then try again with slightly different coordinates
            task.wait(0.1)
            local offsetX = posX + math.random(-5, 5)
            local offsetY = posY + math.random(-5, 5)
            VirtualInputManager:SendTouchEvent(0, Vector2.new(offsetX, offsetY), true)
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(0, Vector2.new(offsetX, offsetY), false)
        end
        
        -- Direct signal activation (works on both platforms)
        debug("Attempting to fire Activated signal directly")
        if replayButton.ClassName == "TextButton" or replayButton.ClassName == "ImageButton" then
            pcall(function()
                firesignal(replayButton.Activated)
                debug("Direct signal fired")
            end)
            
            -- Additional attempt: MouseButton1Click signal
            pcall(function()
                firesignal(replayButton.MouseButton1Click)
                debug("MouseButton1Click signal fired")
            end)
        end
        
        -- Short delay between attempts
        task.wait(0.2)
    end
    
    debug("Finished replay button click attempts")
end

-- Handle player respawning
local function setupPlayerListeners()
    -- Listen for character added (respawn)
    player.CharacterAdded:Connect(function()
        debug("Player respawned - script continues running")
    end)
end

-- Setup death listener for first character
if player.Character then
    debug("Initial character exists")
end

-- Setup respawn listener
setupPlayerListeners()

-- Calculate end time (15 minutes from now)
local endTime = tick() + (RUNTIME_MINUTES * 60)

-- Main loop - run for 15 minutes
spawn(function()
    while isRunning and tick() < endTime do
        autoClickReplay()
        
        -- Wait before checking again
        for i = 1, CHECK_INTERVAL * 10 do
            if not isRunning then break end
            task.wait(0.1) -- smaller waits to allow for cleaner stopping
        end
    end
    
    debug("Script finished running after " .. RUNTIME_MINUTES .. " minutes")
    isScriptActive = false
end)

-- Provide a way to stop the script if needed
local function stopScript()
    isRunning = false
    isScriptActive = false
    debug("Script manually stopped")
end


-- Space spam function with mobile support
local function spamSpace()
    debug("Starting space/touch spam for " .. SPAM_DURATION .. " seconds")
    local startTime = os.time()
    while os.time() - startTime < SPAM_DURATION and isScriptActive do
        if PLATFORM == "Desktop" then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.3)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        else
            -- For mobile, simulate tap in center screen
            local viewportSize = workspace.CurrentCamera.ViewportSize
            local centerX = viewportSize.X / 2
            local centerY = viewportSize.Y / 2
            
            VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(centerX, centerY), true)
            task.wait(0.1)
            VirtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, 0, Vector2.new(centerX, centerY), false)
        end
        task.wait(0.5)
    end
    debug("Space/touch spam completed")
end

-- Boss detection system
local function waitForBossSpawn()
    while isScriptActive do
        for _, ent in ipairs(workspace.Entities:GetChildren()) do
            for _, prefix in ipairs(BOSS_PREFIX) do
                if ent.Name:find("^"..prefix) then
                    bossSpawned = true
                    return
                end
            end
        end
        task.wait(2)
    end
end

-- Main lifecycle manager
local function manageBattleCycle()
    while isScriptActive do
        -- Phase 1: Wait for boss spawn
        bossSpawned = false
        waitForBossSpawn()
        
        -- Phase 2: Run combat script
        if bossSpawned then
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
    end)

    -- Additional safety: watch for boss model removal
    local ancestryConn
    ancestryConn = bossModel.AncestryChanged:Connect(function(_, newParent)
        if not newParent then
            debug("Boss model removed from workspace!")
            bossDefeated.value = true
            stopSignal.value = true
            ancestryConn:Disconnect()
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

            
            -- When boss dies:
            -- 1. Wait 2 seconds
            task.wait(3)
            
            -- 2. Click replay button
            autoClickReplay()
            
            -- 3. Spam space/tap
            spamSpace()
        end
    end
end

-- Auto-attach initialization
spamSpace() -- Initial 10-second spam
task.wait(1)
manageBattleCycle()

-- Cleanup on script termination
game:GetService("UserInputService").WindowFocusReleased:Connect(function()
    isScriptActive = false
end)
