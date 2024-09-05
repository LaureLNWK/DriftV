player = {}
saison = Config.playerSeason
PlayerCount = 1
GlobalState.mode = 'open'

function InitPlayer(source)
    local function initializeNewPlayer(source, license)
        local data = {
            pName = GetPlayerName(source),
            license = license,
            money = Config.DefaultMoney,
            driftPoint = 0,
            exp = 0,
            level = 0,
            cars = {},
            succes = {},
            needSave = false,
            crew = "None",
            crewOwner = false,
        }
        player[source] = data
        pCrew[source] = "None"
        SavePlayer(source)
        debugPrint("Player created into database")
        return data
    end

    local function loadExistingPlayer(source, data)
        data.succes = data.succes or {}
        data.crew = data.crew or "None"
        data.crewOwner = data.crewOwner or false

        if crew[data.crew] == nil then
            data.crew = "None"
        end

        data.needSave = false
        pCrew[source] = data.crew
        player[source] = data

        debugPrint("Loaded player from database (" .. data.money .. " " .. data.driftPoint .. ")")
    end

    PlayerCount = PlayerCount + 1
    local source = tonumber(source)
    local license = GetLicense(source)

    local db = rockdb:new()
    db:SaveInt("PlayerCount", PlayerCount)

    local data = db:GetTable("player_" .. tostring(license) .. saison)

    if data == nil then
        data = initializeNewPlayer(source, license)
    else
        loadExistingPlayer(source, data)
    end

    TriggerClientEvent("syncEvents", source, Events)
    SetPlayerInstance(source, 1)
    RefreshPlayerData(source)
end


function RefreshPlayerData(source)
    TriggerClientEvent("driftV:RefreshData", source, player[source])
    RefreshOtherPlayerData()
end

function RefreshOtherPlayerData()
    TriggerClientEvent("driftV:RefreshOtherPlayerData", -1, crew, pCrew, KingDriftCrew, CrewRanking) --TODO: Rework. This is completely bad for network.
end

function SavePlayer(source)
    local db = rockdb:new()
    local license = GetLicense(source)
    db:SaveTable("player_"..tostring(license)..saison, player[source])
    debugPrint("Player ("..source..") saved")
    player[source].needSave = false
end

Citizen.CreateThread(function()
    local db = rockdb:new()
    local data = db:GetInt("PlayerCount")
    PlayerCount = data ~= nil and data or 1
    while true do
        for k,v in pairs(player) do

            if GetPlayerPing(k) == 0 then
                player[k] = nil
            else
                if v.needSave then
                    SavePlayer(k)
                    v.needSave = false
                end
            end
        end
        Wait(10*1000)
    end
end)

RegisterNetEvent("driftV:InitPlayer")
AddEventHandler("driftV:InitPlayer", function()
    local source = source
    InitPlayer(source)
end)

AddEventHandler('playerDropped', function (reason)
    local source = source
    if player[source] ~= nil then
        SavePlayer(source)
        player[source] = nil
        pCrew[source] = nil
    end
end)

RegisterSecuredNetEvent(Events.setDriftPoint, function(point)
    local source = source
    player[source].driftPoint = player[source].driftPoint + point
    player[source].money = math.floor(player[source].money + point / 200)
    TriggerClientEvent("FeedM:showNotification", source, "+ ~g~"..tostring(math.floor(point / 200)).."~s~$", 2000, "success")
    AddPointsToCrew(source, point)

    RefreshPlayerData(source)
    player[source].needSave = true

end)

RegisterSecuredNetEvent(Events.addMoney, function(money)
    local source = source
    player[source].money = math.floor(player[source].money + money)
    TriggerClientEvent("FeedM:showNotification", source, "+ ~g~"..tostring(math.floor(money)).."~s~$", 2000, "success")
end)

RegisterSecuredNetEvent(Events.SetExp, function(point)
    local source = source
    player[source].exp = math.floor(point)

    RefreshPlayerData(source)
    player[source].needSave = true

end)

RegisterSecuredNetEvent(Events.setArchivment, function(arch)
    player[source].succes = arch
    player[source].needSave = true
end)

RegisterSecuredNetEvent(Events.reqSync, function()
    local players = {}
    for k,v in pairs(player) do
        table.insert(players, {name = GetPlayerName(k), exp = v.exp, servID = k, ping = GetPlayerPing(k), crew = v.crew})
    end

    TriggerClientEvent(Events.getSync, source, players)
end)

local inPassive = {}
RegisterSecuredNetEvent(Events.setPassive, function(status)
    if status then
        inPassive[source] = source
    else
        inPassive[source] = nil
    end
    TriggerClientEvent(Events.setPassive, -1, inPassive)
end)


RegisterSecuredNetEvent(Events.buyVeh, function(price, label, model)

    if price <= player[source].money and price > 49000 then
        player[source].money = player[source].money - price
        table.insert(player[source].cars, {label = label, model = model, props = {}})
        TriggerClientEvent("FeedM:showNotification", source, "New vehicle added to your garage !", 5000, "success")

        RefreshPlayerData(source)
        player[source].needSave = true
    end
end)

RegisterSecuredNetEvent(Events.refreshCars, function(cars)
    player[source].cars = cars
    player[source].needSave = true
end)


RegisterSecuredNetEvent(Events.busted, function(cops)
    TriggerClientEvent("FeedM:showNotification", -1, "The player "..GetPlayerName(source).." got busted with "..cops.." cops !", 15000, "danger")
end)

RegisterSecuredNetEvent(Events.pay, function(price)
    player[source].money = player[source].money - price
    TriggerClientEvent("FeedM:showNotification", source, "- ~r~"..tostring(math.floor(price)).."~s~$", 2000, "success")
    player[source].needSave = true
    RefreshPlayerData(source)
end)
