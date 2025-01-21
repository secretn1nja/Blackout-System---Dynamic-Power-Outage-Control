local isBlackoutInProgress = false
local isRepair = false
local isSabotaging = false
local isDrawtext = false
local isMiniGameStarted = false
local miniGameSequence = {}
local miniGameProgress = 0
local miniGameActive = false

function blackoutOnline()
    isBlackoutInProgress = true
    DisplayRadar(not Config.HideRadar)
    SetArtificialLightsState(true)
    showNotify("Emergency Service", "The blackout has started!", 5000, '#FF0000')
    notifyBlackoutStatus("The blackout has started!")
    checkRepairProximity()
end

function blackoutOffline()
    isBlackoutInProgress = false
    if Config.HideRadar then
        DisplayRadar(true)
    end
    SetArtificialLightsState(false)
    PlayMissionCompleteAudio('FRANKLIN_BIG_01');
    showNotify("Emergency Service", "The blackout has ended!", 5000, '#FF0000')
    notifyBlackoutStatus("The blackout has ended!")
    checkSabotageProximity()
end

function checkSolarStorm()
    if Config.EnableSolarStorms and math.random(1, 100) <= Config.SolarStormChance then
        blackoutOnline()
        showNotify("Townhall", 'A solar storm caused a blackout!', 5000, "#FF0000")
    end
end

function checkSabotageProximity()
    Citizen.CreateThread(function()
        while not isBlackoutInProgress do
            if #((GetEntityCoords(PlayerPedId())) - Config.SabotageCoords) < 2.0 and not isSabotaging then
                    drawtext((string.gsub((GetControlInstructionalButton(2, Config.Keybind, 1)), "t_", "")), 'Sabotage Generator')
                    if IsControlJustPressed(0, Config.Keybind) then
                        startBlackout(Config.SabotageCoords)
                        hideDrawText()
                    end
                else
                    hideDrawText()
                end
            Citizen.Wait(1)
        end
    end)
end

function checkRepairProximity()
    Citizen.CreateThread(function()
        while isBlackoutInProgress do
            adjustRepairDifficulty()
                if #((GetEntityCoords(PlayerPedId())) - Config.GeneratorCoords) < 2.0 and not isRepair then
                    drawtext((string.gsub((GetControlInstructionalButton(2, Config.Keybind, 1)), "t_", "")),
                        'Repair Generator')
                    if IsControlJustPressed(0, Config.Keybind) then
                        startPowerRestorationMiniGame(Config.GeneratorCoords)
                        hideDrawText()
                    end
                else
                    hideDrawText()
                end
            Citizen.Wait(1)
        end
    end)
end

function adjustRepairDifficulty()
    local weather = GetWeatherTypeTransition()
    if weather == "THUNDER" then
        Config.RepairTime = Config.RepairTime * 3.5
        showNotify("System", 'It is a thunderstorm, repairs will take longer.', 3000, "#FFFF00")
    end
end

function startBlackout(sabotageLocation)
    if isSabotaging then
        return
    else
        isSabotaging = true
        showNotify("Blackout imminent!", 'Sabotaging the generator...', 3000, "#FFFF00")
        TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_TOURIST_MOBILE", 0, true)

        Citizen.CreateThread(function()
            local startTime = GetGameTimer()

            while GetGameTimer() - startTime < (Config.SabotageTime * 1000) do
                Citizen.Wait(1)
                local progress = (GetGameTimer() - startTime) / (Config.SabotageTime * 1000)
                local progressText = string.format("Sabotaging generator... %.1f%%", progress * 100)
                DrawProgressBar(sabotageLocation.x, sabotageLocation.y, sabotageLocation.z, progress, 255, 0, 0,
                    "~r~" .. progressText)
            end

            ClearPedTasks(PlayerPedId())
            blackoutOnline()
            isSabotaging = false
            showNotify("Blackout initiated!", 'Generator sabotaged.', 5000, "#FF0000")
        end)
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        checkSabotageProximity()
    end
end)

function repairGenerator(generator)
    if isRepair then
        return
    else
        isRepair = true
        showNotify("System", 'Repairing blackout...', 5000, "#FFFF00")
        TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_WELDING", 0, true)

        Citizen.CreateThread(function()
            local startTime = GetGameTimer()

            while GetGameTimer() - startTime < (Config.RepairTime * 1000) do
                Citizen.Wait(1)
                local progress = (GetGameTimer() - startTime) / (Config.RepairTime * 1000)
                local progressText = string.format("Repairing generator... %.1f%%", progress * 100)
                DrawProgressBar(generator.x, generator.y, generator.z, progress, 0, 255, 0, "~g~" .. progressText)

                if GetGameTimer() - startTime >= (Config.RepairTime - 5000) and not isMiniGameStarted then
                    isMiniGameStarted = true
                end
            end

            if (math.random(1, 100)) <= Config.GeneratorFailureChance then
                showNotify("Repair failed.", 'The generator has failed!', 5000, "#FFFF00")
                isRepair = false
                ClearPedTasks(PlayerPedId())
                return
            end

            ClearPedTasks(PlayerPedId())
            isRepair = false
            showNotify("Blackout repaired!", 'The generator is repaired!', 5000, "#00FF00")
            blackoutOffline()
        end)
    end
end

function startPowerRestorationMiniGame(generator)
    if miniGameActive then return end
    miniGameActive = true
    miniGameSequence = generateRandomSequence(Config.MiniGameLenghtSequence)
    miniGameProgress = 0
    showMiniGameInstructions(miniGameSequence)

    Citizen.CreateThread(function()
        local miniGameStartTime = GetGameTimer()
        local timeLimit = 10000

        while miniGameActive do
            Citizen.Wait(0)
            handleMiniGameInput()
            DisableAllControlActions(0)
            EnableControlAction(0, 73, true)
            EnableControlAction(0, 23, true)
            EnableControlAction(0, 32, true)
            EnableControlAction(0, 34, true)
            EnableControlAction(0, 74, true)

            if miniGameProgress >= #miniGameSequence then
                showNotify("System", "Mini-game completed! Repair in progress...", 5000, "#00FF00")
                miniGameActive = false
                EnableAllControlActions(0)
                repairGenerator(generator)
                return
            end
            if (GetGameTimer() - miniGameStartTime) > timeLimit then
                showNotify("System", "Mini-game failed! Try again.", 5000, "#FF0000")
                miniGameActive = false
                EnableAllControlActions(0)
                return
            end
        end
    end)
end

function generateRandomSequence(length)
    local keys = { 73, 23, 32, 34, 74 }
    local sequence = {}
    for i = 1, length do
        table.insert(sequence, keys[math.random(1, #keys)])
    end
    return sequence
end

function showMiniGameInstructions(sequence)
    local instructions = "Press the sequence: "
    for _, key in ipairs(sequence) do
        instructions = instructions ..
        (string.gsub((GetControlInstructionalButton(0, key, true)), "t_", "")) .. " | "
    end
    showNotify("Mini-Game", instructions, 10000, "#FFFF00")
end

function handleMiniGameInput()
    if miniGameProgress < #miniGameSequence then
        local currentKey = miniGameSequence[miniGameProgress + 1]
        if IsControlJustPressed(0, currentKey) then
            miniGameProgress = miniGameProgress + 1
        elseif IsControlJustPressed(0, 73) or IsControlJustPressed(0, 23) or IsControlJustPressed(0, 32) or IsControlJustPressed(0, 34) or IsControlJustPressed(0, 74) then
            miniGameActive = false
        end
    end
end

function DrawProgressBar(x, y, z, progress, colorr, colorg, colorgb, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayText(_x, _y)
        DrawRect(_x + 0.05, _y + -0.02, 0.2, 0.02, 0, 0, 0, 255)
        DrawRect(_x + 0.05, _y + -0.02, 0.2 * progress, 0.02, colorr, colorg, colorgb, 255)
    end
end

function drawtext(drawBtn, text)
    isDrawtext = not isDrawtext
    SendNuiMessage(json.encode({
        type = 'drawtxt',
        btn = drawBtn,
        text = text
    }))
end

function hideDrawText()
    SendNuiMessage(json.encode({
        type = 'hidetxt'
    }))
end

function showNotify(title, message, duration, color)
    SendNUIMessage({
        type = "notification",
        title = title,
        message = message,
        duration = duration or 3000,
        color = color or "#76C7C0"
    })
end

function notifyBlackoutStatus(status)
    TriggerEvent('chat:addMessage', { color = { 255, 0, 0 }, multiline = true, args = { "System", status } })
end

-- Commands

-- RegisterCommand('bka', function()
--     if not isBlackoutInProgress then
--         blackoutOnline()
--         print('Blackout activate manually..')
--     else
--         print('Blackout already active..')
--     end
-- end)

-- RegisterCommand('endBlackout', function()
--     if isBlackoutInProgress then
--         blackoutOffline()
--         print('Blackout turned off manually..')
--     else
--         print('Blackout is not active..')
--     end
-- end)

-- RegisterCommand('simulateSolarStorm', function ()
--     if Config.EnableSolarStorms == true then
--         checkSolarStorm()
--         print("A solar storm was simulated.")
--     else
--         print('Solar storms are not possible.')
--     end
-- end)