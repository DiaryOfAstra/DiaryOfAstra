-- Services
local Players      = game:GetService("Players")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local VIM          = game:GetService("VirtualInputManager")

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

-- Debug
local function log(msg)
    print(("[HolySweeperKiller] %s"):format(msg))
end

-- Blade empty?
local function isBladeEmpty()
    local gui = player.PlayerGui.Interface.HUD.Main.Top.Blades
    return gui.Sets.Text == "0 / 3"
       and gui.Inner.Bar.Gradient.Offset == Vector2.new(-0.15, 0)
end

-- Auto-refill when blades are empty
local function tryRefill()
    if not isBladeEmpty() then return false end
    log("Blades empty: refilling…")
    local refillPart = Workspace:FindFirstChild("Unclimbable")
        and Workspace.Unclimbable:FindFirstChild("Reloads")
        and Workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
        and Workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
    if refillPart then
        root.CFrame = refillPart.CFrame
        wait(1)
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.R, false, game)
            VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        end)
        log("Refill key sent")
        wait(3)
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
        n.Transparency = 1
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

-- Main
spawn(function()
    while true do
        -- Step 1: refill if needed
        if tryRefill() then
            continue
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
