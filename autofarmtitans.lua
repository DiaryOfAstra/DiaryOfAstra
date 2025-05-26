-- Holy-sweeper Titan killer with SafeAutoExec wrapper
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
    local SWING_DELAY    = math.random(80, 120) / 1000  -- Randomized swing rate (0.08-0.12s)
    local KILL_TIMEOUT   = 3             -- Reduced max time per Titan (was 8)
    local SWEEP_DISTANCE = 80            -- Distance to sweep horizontally
    local SWEEP_TIME     = 1.5           -- Time to sweep across nape
    local CHECK_INTERVAL = 0.2           -- How often to check if Titan is dead
    local BLADE_CHECK_INTERVAL = 0.3     -- How often to check blade status during attacks

    -- Helper: center-screen coords
    local function centerXY()
        local vs = cam.ViewportSize
        return vs.X/2, vs.Y/2
    end

    -- Precompute exact center once
    local MID_X, MID_Y = centerXY()

    -- **Lock the mouse at center with randomization to avoid detection**
    RunService.RenderStepped:Connect(function()
        -- Add small random offset to cursor position
        local offsetX = math.random(-2, 2)
        local offsetY = math.random(-2, 2)
        pcall(function()
            VIM:SendMouseMoveEvent(MID_X + offsetX, MID_Y + offsetY, game)
        end)
    end)

    -- Detect platform (PC or Mobile)
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    -- Debug
    local function log(msg)
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

    -- Find all refill stations in workspace with more robust detection
    local function findAllRefillStations()
        local refillStations = {}
        
        -- Check the common refill locations first (more reliable)
        if Workspace:FindFirstChild("Unclimbable") and 
           Workspace.Unclimbable:FindFirstChild("Reloads") then
            local reloads = Workspace.Unclimbable.Reloads
            
            -- Try both gas tanks and blades
            if reloads:FindFirstChild("GasTanks") and 
               reloads.GasTanks:FindFirstChild("Refill") then
                table.insert(refillStations, reloads.GasTanks.Refill)
            end
            
            if reloads:FindFirstChild("Blades") and 
               reloads.Blades:FindFirstChild("Refill") then
                table.insert(refillStations, reloads.Blades.Refill)
            end
        end
        
        -- Only if we didn't find the primary stations, we'll do a full search
        if #refillStations == 0 then
            -- Helper function to search recursively
            local function searchForRefill(parent, depth)
                if depth > 5 then return end  -- Prevent too deep recursion
                
                for _, child in pairs(parent:GetChildren()) do
                    if child:IsA("BasePart") and child.Name == "Refill" then
                        table.insert(refillStations, child)
                    elseif child:IsA("Model") or child:IsA("Folder") then
                        searchForRefill(child, depth + 1)
                    end
                end
            end
            
            searchForRefill(workspace, 0)
        end
        
        return refillStations
    end

    -- Safely teleport to a location using tweening for stability
    local function safeTeleport(targetPosition, lookAt)
        -- Create a stabilized position 5 studs above the target to prevent falling through
        local stabilizedPos = Vector3.new(
            targetPosition.X,
            targetPosition.Y + 5, -- Slightly above to prevent falling through
            targetPosition.Z
        )
        
        -- Create a CFrame that positions us at the position and optionally looks at target
        local targetCFrame
        if lookAt then
            targetCFrame = CFrame.new(stabilizedPos, lookAt)
        else
            targetCFrame = CFrame.new(stabilizedPos)
        end
        
        -- First move with tweening (more stable)
        local tween = TweenService:Create(
            root,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {CFrame = targetCFrame}
        )
        
        tween:Play()
        tween.Completed:Wait()
        
        -- Add a small delay for physics to stabilize
        wait(0.2)
        
        -- Finalize position with direct set to ensure accuracy
        root.CFrame = targetCFrame
        wait(0.3) -- Additional stabilization time
        
        return true
    end

    -- Auto-refill when blades are empty
    local function tryRefill()
        if not isBladeEmpty() then return false end
        
        -- Find all refill stations in the workspace
        local refillStations = findAllRefillStations()
        
        if #refillStations == 0 then
            return false
        end
        
        
        -- Try each refill station
        for i, refillPart in ipairs(refillStations) do
            
            -- Get refill position
            local refillPos = refillPart.Position
            
            -- Try multiple positions around the refill to find the most stable spot
            local positions = {
                {offset = Vector3.new(-7, 0, 0), name = "left"},
                {offset = Vector3.new(7, 0, 0), name = "right"},
                {offset = Vector3.new(0, 0, -7), name = "front"},
                {offset = Vector3.new(0, 0, 7), name = "back"}
            }
            
            -- Try each position until refill works
            for _, pos in ipairs(positions) do
                -- Calculate teleport target position
                local tryPos = refillPos + pos.offset
                
                
                safeTeleport(tryPos, refillPos)
                
                -- Check platform and use appropriate input method
                
                
                -- Try refilling multiple times
                local refillAttempts = 0
                local refillStartTime = tick()
                local maxRefillTime = 10 -- Maximum time to try refilling
                
                -- Continue attempting to refill until successful or timeout
                while not areBladesFull() and tick() - refillStartTime < maxRefillTime do
                    if isMobile then
                        triggerTouchRefill()
                    else
                        pressRefillKey()
                    end
                    
                    refillAttempts = refillAttempts + 1
                    
                    if refillAttempts % 5 == 0 then
                        
                    end
                    
                    -- Check if refill is working
                    if areBladesFull() then
                        
                        wait(0.5) -- Wait for stability
                        return true
                    end
                    
                    -- Short wait between attempts
                    wait(0.3)
                    
                    -- If taking too long, adjust position slightly and try again
                    if refillAttempts % 10 == 0 and refillAttempts < 20 then
                        -- Make a small adjustment to position
                        local adjustedPos = tryPos + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
                        safeTeleport(adjustedPos, refillPos)
                        
                    end
                end
                
                -- If we've reached this point, this position didn't work
                
            end
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
        
        
        
        -- Start attack loop
        local startTime = tick()
        local attacking = true
        local lastBladeCheck = tick()
        
        -- Auto-swing loop
        local acc = 0
        local swingConn = RunService.RenderStepped:Connect(function(dt)
            if not attacking then return end
            
            -- IMPORTANT FIX #1: Check if blades are empty periodically during attack
            if tick() - lastBladeCheck > BLADE_CHECK_INTERVAL then
                lastBladeCheck = tick()
                if isBladeEmpty() then
                    
                    attacking = false
                    return
                end
            end
            
            -- Calculate current position based on time elapsed
            local elapsedTime = tick() - startTime
            local alpha = math.min(elapsedTime / SWEEP_TIME, 1)
            
            -- Lerp between start and end positions
            local currentX = hoverPos.X + (endPos.X - hoverPos.X) * alpha
            local currentPos = Vector3.new(currentX, hoverPos.Y, hoverPos.Z)
            
            -- Update position while maintaining downward angle
            root.CFrame = CFrame.new(currentPos) * CFrame.Angles(math.rad(80), 0, 0)
            
            -- Ensure cursor is centered with slight randomization every frame
            local offsetX = math.random(-2, 2)
            local offsetY = math.random(-2, 2)
            pcall(function()
                VIM:SendMouseMoveEvent(MID_X + offsetX, MID_Y + offsetY, game)
            end)
            
            -- Swing timing with randomization
            acc = acc + dt
            local currentSwingDelay = math.random(80, 120) / 1000  -- Randomize each swing
            if acc >= currentSwingDelay then
                acc = acc - currentSwingDelay
                -- Add small random delay before clicking
                wait(math.random(1, 5) / 1000)  -- 1-5ms random delay
                -- Click down/up at center with slight randomization
                local clickX = MID_X + math.random(-3, 3)
                local clickY = MID_Y + math.random(-3, 3)
                pcall(function()
                    VIM:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
                    wait(math.random(10, 30) / 1000) -- Randomized click duration (10-30ms)
                    VIM:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
                end)
            end
            
            -- Check if Titan is dead periodically
            if elapsedTime % CHECK_INTERVAL < dt and isTitanDead(titanInfo) then
                
                attacking = false
                return
            end
            
            -- Check timeout and sweep completion
            if elapsedTime > SWEEP_TIME then
                -- After sweeping right, sweep back left
                if alpha >= 1 and currentX >= endPos.X - 0.1 then
                    
                    startTime = tick() - SWEEP_TIME -- Reset for reverse sweep
                    hoverPos, endPos = endPos, hoverPos -- Swap start/end to reverse
                end
            end
            
            -- Overall timeout
            if tick() - startTime > KILL_TIMEOUT then
                
                attacking = false
            end
        end)
        
        -- Create a separate thread to check if titan dies
        local deathCheckThread = coroutine.wrap(function()
            while attacking do
                if isTitanDead(titanInfo) then
                    
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
            -- IMPORTANT FIX #1: Check if blades are empty during the wait loop too
            if isBladeEmpty() then
                
                attacking = false
                break
            end
            
            if tick() - waitStart > KILL_TIMEOUT then
                attacking = false
            end
            wait(0.1)
        end
        
        swingConn:Disconnect()
        
        
        -- Return true if we stopped due to empty blades
        return isBladeEmpty()
    end

    -- Smooth movement between Titans using the safer teleport method
    local function moveToNextTitan(currentPos, targetPos)
        
        
        -- Use our safer teleport method instead of direct tweening
        local targetCF = CFrame.new(targetPos) * CFrame.Angles(math.rad(80), 0, 0)
        
        -- Create a smoother, more stable tween
        local move = TweenService:Create(
            root,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {CFrame = targetCF}
        )
        
        move:Play()
        move.Completed:Wait()
        wait(0.2) -- Small stabilization delay
    end

    -- Log platform info at startup
    if isMobile then
        
    else
        
    end

    -- Main
    spawn(function()
        while true do
            -- Step 1: Check if refill is needed FIRST before doing anything else
            if isBladeEmpty() then
                
                tryRefill()
                wait(2)
                
                -- If blades are still empty after refill attempt
                if isBladeEmpty() then
                    
                    wait(5)
                    continue
                end
                
                
            end

            -- Step 2: find & expand
            local titans = getTitans()
            if #titans == 0 then
                
                wait(1.5) -- Reduced wait time
                continue
            end
            expandNapes(titans)
            
            -- Sort titans by distance for more efficient killing
            titans = sortTitansByDistance(titans)

            -- Step 3: hover and sweep-attack each
            local needsRefill = false
            for i, t in ipairs(titans) do
                
                
                -- IMPORTANT FIX #1: Check blades before starting a new titan
                if isBladeEmpty() then
                    
                    needsRefill = true
                    break
                end
                
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
                local bladesEmptied = hoverAndSweep(t)
                
                -- IMPORTANT FIX #1: Check if we stopped due to empty blades
                if bladesEmptied or isBladeEmpty() then
                    
                    needsRefill = true
                    break
                end
                
                -- Add a very short randomized delay before moving to the next titan
                wait(math.random(200, 500) / 1000)  -- 200-500ms random delay
            end

            -- If we need to refill, skip the wait and immediately go to start of loop
            if needsRefill then
                
                continue
            end

            
            wait(math.random(500, 1500) / 1000) -- Randomized wait time (0.5-1.5s)
        end
    end)

    
end)
