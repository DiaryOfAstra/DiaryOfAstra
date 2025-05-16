local function runMainnScript()

-- Services
local Players      = game:GetService("Players")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local VIM          = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root      = character:WaitForChild("HumanoidRootPart")
local cam       = workspace.CurrentCamera

-- Configuration
local NAPE_WIDTH     = 106           -- Width as requested
local NAPE_DEPTH     = 106           -- Keeping proportional
local NAPE_HEIGHT    = 20000         -- Tall sky column
local HOVER_HEIGHT   = 150           -- Position reasonably above Titan
local SWING_DELAY    = 0.05          -- Swing rate
local KILL_TIMEOUT   = 3             -- Reduced max time per Titan (was 8)
local SWEEP_DISTANCE = 80            -- Distance to sweep horizontally
local SWEEP_TIME     = 1.5           -- Time to sweep across nape
local CHECK_INTERVAL = 0.2           -- How often to check if Titan is dead

-- Helper: center-screen coords
local function centerXY()
    local vs = cam.ViewportSize
    return vs.X/2, vs.Y/2
end

-- Precompute exact center once
local MID_X, MID_Y = centerXY()

-- **Lock the mouse at center every frame with pcall to prevent errors**
RunService.RenderStepped:Connect(function()
    pcall(function()
        VIM:SendMouseMoveEvent(MID_X, MID_Y, game)
    end)
end)

-- Detect platform (PC or Mobile)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Debug
local function log(msg)
    print(("[HolySweeperKiller] %s"):format(msg))
end

-- Check if blades are full
local function areBladesFull()
    local gui = player.PlayerGui.Interface.HUD.Main.Top.Blades
    return gui.Sets.Text == "3 / 3"
end

-- Blade empty?
local function isBladeEmpty()
    local gui = player.PlayerGui.Interface.HUD.Main.Top.Blades
    return gui.Sets.Text == "0 / 3"
       and gui.Inner.Bar.Gradient.Offset == Vector2.new(-0.15, 0)
end

-- Press keyboard refill key (for PC)
local function pressRefillKey()
    VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

-- Trigger touch refill (for mobile)
local function triggerTouchRefill()
    -- Touch down
    VIM:SendTouchEvent(0, 0, MID_X, MID_Y, game)
    wait(0.1)
    -- Touch up
    VIM:SendTouchEvent(0, 2, MID_X, MID_Y, game)
    wait(0.1)
end

-- Find all refill stations in workspace
local function findAllRefillStations()
    local refillStations = {}
    
    -- Helper function to search recursively
    local function searchForRefill(parent, depth)
        if depth > 5 then return end  -- Prevent too deep recursion
        
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name == "Refill" then
                table.insert(refillStations, child)
                log("Found refill part: " .. child:GetFullName())
            elseif child:IsA("Model") or child:IsA("Folder") then
                searchForRefill(child, depth + 1)
            end
        end
    end
    
    searchForRefill(workspace, 0)
    return refillStations
end

-- Auto-refill when blades are empty
local function tryRefill()
    if not isBladeEmpty() then return false end
    log("Blades empty: refilling…")
    
    -- Find all refill stations in the workspace
    local refillStations = findAllRefillStations()
    
    if #refillStations == 0 then
        log("ERROR: No refill stations found in workspace")
        return false
    end
    
    log("Found " .. #refillStations .. " refill stations")
    
    -- Try each refill station
    for i, refillPart in ipairs(refillStations) do
        log("Trying refill station " .. i .. "/" .. #refillStations)
        
        -- Teleport directly to the refill station with a small offset and facing it
        local refillPos = refillPart.Position
        
        -- Create a position 5 studs away from the refill in a horizontal direction
        local offsetPos = Vector3.new(refillPos.X - 5, refillPos.Y, refillPos.Z)
        
        -- Create a CFrame that positions us at the offset position and looks at the refill
        root.CFrame = CFrame.new(offsetPos, refillPos)
        
        log("Teleported to refill position")
        wait(1)
        
        -- Check platform and use appropriate input method
        if isMobile then
            log("Using mobile touch controls for refill")
            
            -- Start continuous touch pressing for mobile
            local touchActive = true
            local touchThread = coroutine.wrap(function()
                local touchCount = 0
                while touchActive do
                    -- Check if blades are full
                    if areBladesFull() then
                        log("Blades full! Stopping touch")
                        touchActive = false
                        break
                    end
                    
                    -- Send touch event at center of screen
                    pcall(function()
                        triggerTouchRefill()
                    end)
                    
                    touchCount = touchCount + 1
                    if touchCount % 5 == 0 then
                        log(("Still touching... (count: %d)"):format(touchCount))
                    end
                    
                    -- Safety check to prevent infinite loop
                    if touchCount > 100 then
                        log("Safety limit reached, stopping touch")
                        touchActive = false
                        break
                    end
                end
            end)
            
            -- Start the touch thread
            touchThread()
        else
            log("Using keyboard controls for refill")
            
            -- Start continuous key pressing for PC
            local keyActive = true
            local keyThread = coroutine.wrap(function()
                local keyCount = 0
                while keyActive do
                    -- Check if blades are full
                    if areBladesFull() then
                        log("Blades full! Stopping key press")
                        keyActive = false
                        break
                    end
                    
                    -- Send R key event
                    pcall(function()
                        pressRefillKey()
                    end)
                    
                    keyCount = keyCount + 1
                    if keyCount % 5 == 0 then
                        log(("Still pressing R... (count: %d)"):format(keyCount))
                    end
                    
                    -- Safety check to prevent infinite loop
                    if keyCount > 100 then
                        log("Safety limit reached, stopping key press")
                        keyActive = false
                        break
                    end
                end
            end)
            
            -- Start the key thread
            keyThread()
        end
        
        -- Wait for blades to be full or timeout
        local startTime = tick()
        while not areBladesFull() and tick() - startTime < 10 do
            wait(0.1)
        end
        
        if areBladesFull() then
            log("Refill successful!")
        else
            log("Refill timeout or failed - turning around to try again")
            -- Try a 180° turn and retry if first attempt failed
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(180), 0)
            wait(0.5)
            
            -- Second attempt with appropriate input method
            local secondStartTime = tick()
            local attempt = 0
            
            while not areBladesFull() and tick() - secondStartTime < 5 do
                attempt = attempt + 1
                if isMobile then
                    triggerTouchRefill() 
                else
                    pressRefillKey()
                end
                
                if attempt % 3 == 0 then
                    log("Still trying to refill after turning around...")
                end
                wait(0.3)
            end
            
            if areBladesFull() then
                log("Second refill attempt successful!")
            else
                log("All refill attempts failed")
            end
        end
        
        wait(1)
        return true
    end
    return false
end

-- Get all Titans
local function getTitans()
    local out = {}
    local folder = Workspace:FindFirstChild("Titans")
    if not folder then return out end
    for _, mdl in ipairs(folder:GetChildren()) do
        local n = mdl:FindFirstChild("Hitboxes")
            and mdl.Hitboxes:FindFirstChild("Hit")
            and mdl.Hitboxes.Hit:FindFirstChild("Nape")
        local humanoid = mdl:FindFirstChild("Humanoid")
        if n and n:IsA("BasePart") and humanoid and humanoid.Health > 0 then
            table.insert(out, {mdl=mdl, nape=n, humanoid=humanoid})
        end
    end
    return out
end

-- Expand into sky-columns
local function expandNapes(titans)
    for _, t in ipairs(titans) do
        local n = t.nape
        n.Locked       = false
        n.Size         = Vector3.new(NAPE_WIDTH, NAPE_HEIGHT, NAPE_DEPTH)
        n.CanCollide   = false
        n.Transparency = 0.8
    end
    log("All napes expanded")
end

-- Sort titans by distance
local function sortTitansByDistance(titans)
    local playerPos = root.Position
    table.sort(titans, function(a, b)
        local distA = (a.nape.Position - playerPos).Magnitude
        local distB = (b.nape.Position - playerPos).Magnitude
        return distA < distB
    end)
    return titans
end

-- Check if titan is dead by checking humanoid health
local function isTitanDead(titanInfo)
    -- Check if model or humanoid is gone
    if not titanInfo.mdl:IsDescendantOf(game.Workspace) then
        return true
    end
    
    -- Check humanoid health
    local humanoid = titanInfo.humanoid
    if not humanoid or not humanoid:IsDescendantOf(game.Workspace) or humanoid.Health <= 0 then
        return true
    end
    
    return false
end

-- Hover above and sweep across a Titan's nape hitbox while attacking
local function hoverAndSweep(titanInfo)
    local nape = titanInfo.nape
    -- Calculate position inside nape hitbox but at reasonable height
    local napePos = nape.Position
    local hoverPos = Vector3.new(
        napePos.X - SWEEP_DISTANCE/2, -- Start from left side
        napePos.Y + HOVER_HEIGHT,     -- Position reasonably above Titan
        napePos.Z
    )
    
    local endPos = Vector3.new(
        napePos.X + SWEEP_DISTANCE/2, -- End at right side
        napePos.Y + HOVER_HEIGHT,     -- Same height
        napePos.Z                     -- Same Z
    )
    
    -- Initial positioning (teleport to starting position)
    local startCF = CFrame.new(hoverPos) * CFrame.Angles(math.rad(80), 0, 0)
    root.CFrame = startCF
    wait(0.5) -- Short pause to stabilize
    
    log("Starting sweep attack across nape")
    
    -- Start attack loop
    local startTime = tick()
    local attacking = true
    
    -- Auto-swing loop
    local acc = 0
    local swingConn = RunService.RenderStepped:Connect(function(dt)
        if not attacking then return end
        
        -- Calculate current position based on time elapsed
        local elapsedTime = tick() - startTime
        local alpha = math.min(elapsedTime / SWEEP_TIME, 1)
        
        -- Lerp between start and end positions
        local currentX = hoverPos.X + (endPos.X - hoverPos.X) * alpha
        local currentPos = Vector3.new(currentX, hoverPos.Y, hoverPos.Z)
        
        -- Update position while maintaining downward angle
        root.CFrame = CFrame.new(currentPos) * CFrame.Angles(math.rad(80), 0, 0)
        
        -- Ensure cursor is centered every frame
        pcall(function()
            VIM:SendMouseMoveEvent(MID_X, MID_Y, game)
        end)
        
        -- Swing timing
        acc = acc + dt
        if acc >= SWING_DELAY then
            acc = acc - SWING_DELAY
            -- Click down/up at center with pcall to prevent errors
            pcall(function()
                VIM:SendMouseButtonEvent(MID_X, MID_Y, 0, true, game, 0)
                wait(0.01) -- Shorter click duration for faster swings
                VIM:SendMouseButtonEvent(MID_X, MID_Y, 0, false, game, 0)
            end)
        end
        
        -- Check if Titan is dead periodically
        if elapsedTime % CHECK_INTERVAL < dt and isTitanDead(titanInfo) then
            log("Titan killed! Moving to next target")
            attacking = false
            return
        end
        
        -- Check timeout and sweep completion
        if elapsedTime > SWEEP_TIME then
            -- After sweeping right, sweep back left
            if alpha >= 1 and currentX >= endPos.X - 0.1 then
                log("Reversing sweep direction")
                startTime = tick() - SWEEP_TIME -- Reset for reverse sweep
                hoverPos, endPos = endPos, hoverPos -- Swap start/end to reverse
            end
        end
        
        -- Overall timeout
        if tick() - startTime > KILL_TIMEOUT then
            log("Timeout reached, moving to next Titan")
            attacking = false
        end
    end)
    
    -- Create a separate thread to check if titan dies
    local deathCheckThread = coroutine.wrap(function()
        while attacking do
            if isTitanDead(titanInfo) then
                log("Titan death detected! Moving on quickly")
                attacking = false
                break
            end
            wait(CHECK_INTERVAL)
        end
    end)
    deathCheckThread()
    
    -- Wait for kill or timeout
    local waitStart = tick()
    while attacking do
        if tick() - waitStart > KILL_TIMEOUT then
            attacking = false
        end
        wait(0.1)
    end
    
    swingConn:Disconnect()
    log("Finished sweep attack")
end

-- Smooth movement between Titans
local function moveToNextTitan(currentPos, targetPos)
    local targetCF = CFrame.new(targetPos) * CFrame.Angles(math.rad(80), 0, 0)
    
    local move = TweenService:Create(
        root,
        TweenInfo.new(1, Enum.EasingStyle.Linear), -- Faster travel (was 2)
        {CFrame = targetCF}
    )
    
    log("Moving to next Titan...")
    move:Play()
    move.Completed:Wait()
end

-- Log platform info at startup
if isMobile then
    log("Running on mobile platform - using touch controls")
else
    log("Running on PC/desktop platform - using keyboard controls")
end

-- Main
spawn(function()
    while true do
        -- Step 1: refill if needed
        local refillAttempted = tryRefill()
        if refillAttempted then
            log("Refill attempt completed - waiting before continuing")
            wait(2)
            -- Check if blades still empty after refill attempt
            if isBladeEmpty() then
                log("Blades still empty after refill attempt - trying alternative methods")
                -- Try multiple positions around the refill station
                local foundRefill = false
                
                -- Try finding the refill again
                local refillPart = nil
                if Workspace:FindFirstChild("Unclimbable") and 
                   Workspace.Unclimbable:FindFirstChild("Reloads") then
                    local reloads = Workspace.Unclimbable.Reloads
                    -- Try both gas tanks and blades
                    if reloads:FindFirstChild("GasTanks") and 
                       reloads.GasTanks:FindFirstChild("Refill") then
                        refillPart = reloads.GasTanks.Refill
                    elseif reloads:FindFirstChild("Blades") and 
                          reloads.Blades:FindFirstChild("Refill") then
                        refillPart = reloads.Blades.Refill
                    end
                end
                
                if refillPart then
                    log("Making additional refill attempts with different positions")
                    local positions = {
                        {offset = Vector3.new(-5, 0, 0), name = "left"},
                        {offset = Vector3.new(5, 0, 0), name = "right"},
                        {offset = Vector3.new(0, 0, -5), name = "front"},
                        {offset = Vector3.new(0, 0, 5), name = "back"}
                    }
                    
                    for _, pos in ipairs(positions) do
                        if not isBladeEmpty() then
                            foundRefill = true
                            break
                        end
                        
                        local refillPos = refillPart.Position
                        local tryPos = refillPos + pos.offset
                        
                        log("Trying refill from " .. pos.name .. " position")
                        root.CFrame = CFrame.new(tryPos, refillPos)
                        wait(0.5)
                        
                        -- Try input several times
                        for i = 1, 5 do
                            if isMobile then
                                triggerTouchRefill()
                            else
                                pressRefillKey()
                            end
                            wait(0.3)
                            
                            if areBladesFull() then
                                log("Refill successful from " .. pos.name .. " position!")
                                foundRefill = true
                                break
                            end
                        end
                        
                        if foundRefill then break end
                        wait(0.5)
                    end
                else
                    log("Couldn't find refill part for additional attempts")
                end
            end
            continue  -- Skip the rest of the loop after a refill attempt
        end

        -- Step 2: find & expand
        local titans = getTitans()
        if #titans == 0 then
            log("No Titans found—waiting…")
            wait(1.5) -- Reduced wait time (was 3)
            continue
        end
        expandNapes(titans)
        
        -- Sort titans by distance for more efficient killing
        titans = sortTitansByDistance(titans)

        -- Step 3: hover and sweep-attack each
        for i, t in ipairs(titans) do
            log(("Attacking %d/%d: %s"):format(i, #titans, t.mdl.Name))
            
            -- Calculate starting position (left side of nape)
            local napePos = t.nape.Position
            local nextPos = Vector3.new(
                napePos.X - SWEEP_DISTANCE/2,
                napePos.Y + HOVER_HEIGHT,
                napePos.Z
            )
            
            -- If not the first Titan, move smoothly to the next one
            if i > 1 then
                moveToNextTitan(root.Position, nextPos)
            end
            
            -- Execute the sweep attack
            hoverAndSweep(t)
            
            -- Add a very short delay before moving to the next titan
            wait(0.2)
        end

        log("Cycle complete—restarting")
        wait(0.5) -- Reduced wait time (was 1)
    end
end)

log("Holy-sweeper Titan killer loaded")
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
    
    runMainnScript()
end)
