local QBCore = exports['qb-core']:GetCoreObject()

-- Functions

local function GiveStarterItems(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    for _, v in pairs(QBCore.Shared.StarterItems) do
        local info = {}
        if v.item == "id_card" then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == "driver_license" then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = "Class C Driver License"
        end
        Player.Functions.AddItem(v.item, v.amount, false, info)
    end
end

local function loadHouseData(src)
    local HouseGarages = {}
    local Houses = {}
    local result = MySQL.query.await('SELECT * FROM houselocations', {})
    if result[1] ~= nil then
        for _, v in pairs(result) do
            local owned = false
            if tonumber(v.owned) == 1 then
                owned = true
            end
            local garage = v.garage ~= nil and json.decode(v.garage) or {}
            Houses[v.name] = {
                coords = json.decode(v.coords),
                owned = owned,
                price = v.price,
                locked = true,
                adress = v.label,
                tier = v.tier,
                garage = garage,
                decorations = {},
            }
            HouseGarages[v.name] = {
                label = v.label,
                takeVehicle = garage,
            }
        end
    end
    TriggerClientEvent("qb-garages:client:houseGarageConfig", src, HouseGarages)
    TriggerClientEvent("qb-houses:client:setHouseConfig", src, Houses)
end

-- Commands

QBCore.Commands.Add("logout", "Logout of Character (Admin Only)", {}, false, function(source)
    local src = source
    QBCore.Player.Logout(src)
    TriggerClientEvent('qb-multicharacter:client:chooseChar', src)
end, "admin")

QBCore.Commands.Add("closeNUI", "Close Multi NUI", {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-multicharacter:client:closeNUI', src)
end)

-- Events

RegisterNetEvent('qb-multicharacter:server:disconnect', function()
    local src = source
    DropPlayer(src, "You have disconnected from QBCore")
end)

RegisterNetEvent('qb-multicharacter:server:loadUserData', function(cData)
    local src = source
    if QBCore.Player.Login(src, cData.citizenid) then
        print('^2[qb-core]^7 '..GetPlayerName(src)..' (Citizen ID: '..cData.citizenid..') has succesfully loaded!')
        QBCore.Commands.Refresh(src)
        loadHouseData(src)
        TriggerClientEvent('apartments:client:setupSpawnUI', src, cData)
        TriggerEvent("qb-log:server:CreateLog", "joinleave", "Loaded", "green", "**".. GetPlayerName(src) .. "** ("..(QBCore.Functions.GetIdentifier(src, 'discord') or 'undefined') .." |  ||"  ..(QBCore.Functions.GetIdentifier(src, 'ip') or 'undefined') ..  "|| | " ..(QBCore.Functions.GetIdentifier(src, 'license') or 'undefined') .." | " ..cData.citizenid.." | "..src..") loaded..")
	end
end)

RegisterNetEvent('qb-multicharacter:server:createCharacter', function(data)
    local src = source
    local newData = {}
    newData.cid = data.cid
    newData.charinfo = data
    if QBCore.Player.Login(src, false, newData) then
        if Apartments.Starting then
            local randbucket = (GetPlayerPed(src) .. math.random(1,999))
            SetPlayerRoutingBucket(src, randbucket)
            print('^2[qb-core]^7 '..GetPlayerName(src)..' has succesfully loaded!')
            QBCore.Commands.Refresh(src)
            loadHouseData(src)
            TriggerClientEvent("qb-multicharacter:client:closeNUI", src)
            TriggerClientEvent('apartments:client:setupSpawnUI', src, newData)
            GiveStarterItems(src)
        else
            print('^2[qb-core]^7 '..GetPlayerName(src)..' has succesfully loaded!')
            QBCore.Commands.Refresh(src)
            loadHouseData(src)
            TriggerClientEvent("qb-multicharacter:client:closeNUIdefault", src)
            GiveStarterItems(src)
        end
	end
end)

RegisterNetEvent('qb-multicharacter:server:deleteCharacter', function(citizenid)
    local src = source
    QBCore.Player.DeleteCharacter(src, citizenid)
    TriggerClientEvent('QBCore:Notify', src, "Character deleted!" , "success")
end)

-- Callbacks

QBCore.Functions.CreateCallback("qb-multicharacter:server:GetUserCharacters", function(source, cb)
    local src = source
    local license = QBCore.Functions.GetIdentifier(src, 'license')

    MySQL.query('SELECT * FROM players WHERE license = ?', {license}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback("qb-multicharacter:server:GetServerLogs", function(_, cb)
    MySQL.query('SELECT * FROM server_logs', {}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback("qb-multicharacter:server:GetNumberOfCharacters", function(source, cb)
    local src = source
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    local numOfChars = 0

    if next(Config.PlayersNumberOfCharacters) then
        for _, v in pairs(Config.PlayersNumberOfCharacters) do
            if v.license == license then
                numOfChars = v.numberOfChars
                break
            else
                numOfChars = Config.DefaultNumberOfCharacters
            end
        end
    else
        numOfChars = Config.DefaultNumberOfCharacters
    end
    cb(numOfChars)
end)

QBCore.Functions.CreateCallback("qb-multicharacter:server:setupCharacters", function(source, cb)
    local license = QBCore.Functions.GetIdentifier(source, 'license')
    local plyChars = {}
    MySQL.query('SELECT * FROM players WHERE license = ?', {license}, function(result)
        for i = 1, (#result), 1 do
            result[i].charinfo = json.decode(result[i].charinfo)
            result[i].money = json.decode(result[i].money)
            result[i].job = json.decode(result[i].job)
            plyChars[#plyChars+1] = result[i]
        end
        cb(plyChars)
    end)
end)

QBCore.Functions.CreateCallback("qb-multicharacter:server:getSkin", function(_, cb, cid)
    local result = MySQL.query.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', {cid, 1})
    if result[1] ~= nil then
        cb(result[1].model, result[1].skin)
    else
        cb(nil)
    end
end)

if Config.AllowAdminDeleteCommand == true then
    local playertables = { -- Add tables as needed
        { table = 'players' },
        { table = 'apartments' },
        { table = 'bank_accounts' },
        { table = 'crypto_transactions' },
        { table = 'phone_invoices' },
        { table = 'phone_messages' },
        { table = 'playerskins' },
        { table = 'player_contacts' },
        { table = 'player_houses' },
        { table = 'player_mails' },
        { table = 'player_outfits' },
        { table = 'player_vehicles' }
    }

    function hasAccess(src, rank)
        if QBCore.Functions.HasPermission(src, rank) or IsPlayerAceAllowed(src, 'command') then
            return true
        else
            return false
        end
    end

    QBCore.Functions.CreateCallback('qb-multicharacter:server:hasaccess', function(source, cb)
        cb(hasAccess(source, "god"))
    end)

    RegisterNetEvent("qb-multicharacter:server:removechar")
    AddEventHandler("qb-multicharacter:server:removechar", function(citizenid)
        local Player = QBCore.Functions.GetPlayer(source)

        if Player == nil then return end
        if hasAccess(Player.PlayerData.source, "god") then
            local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
            if Target then
                Target.Functions.Logout()
                TriggerClientEvent('qb-multicharacter:client:chooseChar', Target.PlayerData.source)
                TriggerClientEvent("QBCore:Notify", Target.PlayerData.source, "Your character got deleted by an admin")
            end

            local queries = table.create(#playertables, 0)
            for i = 1, #playertables do
                queries[i] = {query = ("DELETE FROM %s WHERE citizenid = ?"):format(playertables[i].table), values = {citizenid}}
            end

            MySQL.transaction(queries, function(result2)
                if result2 then
                    TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Character Deleted By Admin', 'red', '**' .. GetPlayerName(Target.PlayerData.source) .. '** ' .. Target.PlayerData.license .. ' deleted **' .. citizenid .. '**, deleted by **' .. GetPlayerName(Player.PlayerData.source) .. "** (**" .. Player.PlayerData.license .. "**)")
                end
            end)
        else
            DropPlayer(Player.PlayerData.source, "Exploiting")
        end
    end)
end