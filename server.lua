local QBCore = exports['qb-core']:GetCoreObject()
local VehicleOffers = {} -- buyerId -> { sellerId, plate, price }

-- Command: /transfervehicle [playerId] [price]
RegisterCommand("transfervehicle", function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not args[1] or not args[2] then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /transfervehicle [playerID] [price]', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local price = tonumber(args[2])

    if not targetId or not price or price <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid target or price!', 'error')
        return
    end

    local target = QBCore.Functions.GetPlayer(targetId)
    if not target then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online!', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You must be in the vehicle to transfer!', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)

    -- verify ownership in DB
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, Player.PlayerData.citizenid}, function(result)
        if not result[1] then
            TriggerClientEvent('QBCore:Notify', src, 'This is not your vehicle!', 'error')
            return
        end

        -- store offer server-side
        VehicleOffers[targetId] = { sellerId = src, plate = plate, price = price }

        -- notify buyer
        TriggerClientEvent('transfervehicle:client:offer', targetId, src, plate, price)
        TriggerClientEvent('QBCore:Notify', src, 'Offer sent to player '..targetId..' for $'..price, 'success')
    end)
end)

-- buyer accepts
RegisterNetEvent('transfervehicle:server:accept', function(payMethod)
    local buyerId = source
    local offer = VehicleOffers[buyerId]
    if not offer then
        TriggerClientEvent('QBCore:Notify', buyerId, 'No active vehicle offer!', 'error')
        return
    end

    local Buyer = QBCore.Functions.GetPlayer(buyerId)
    local Seller = QBCore.Functions.GetPlayer(offer.sellerId)
    if not Buyer or not Seller then
        VehicleOffers[buyerId] = nil
        return
    end

    -- verify seller still owns vehicle
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {offer.plate, Seller.PlayerData.citizenid}, function(result)
        if not result[1] then
            TriggerClientEvent('QBCore:Notify', buyerId, 'Seller no longer owns this vehicle!', 'error')
            VehicleOffers[buyerId] = nil
            return
        end

        local price = offer.price
        local paid = false

        if payMethod == 'bank' then
            paid = Buyer.Functions.RemoveMoney('bank', price, 'vehicle-transfer')
        elseif payMethod == 'cash' then
            paid = Buyer.Functions.RemoveMoney('cash', price, 'vehicle-transfer')
        elseif payMethod == 'both' then
            if Buyer.Functions.RemoveMoney('cash', price, 'vehicle-transfer') then
                paid = true
            elseif Buyer.Functions.RemoveMoney('bank', price, 'vehicle-transfer') then
                paid = true
            end
        end

        if not paid then
            TriggerClientEvent('QBCore:Notify', buyerId, 'Not enough money!', 'error')
            TriggerClientEvent('QBCore:Notify', offer.sellerId, 'Buyer couldn\'t pay!', 'error')
            VehicleOffers[buyerId] = nil
            return
        end

        -- transfer ownership
        MySQL.update('UPDATE player_vehicles SET citizenid = ? WHERE plate = ?', {Buyer.PlayerData.citizenid, offer.plate})
        Seller.Functions.AddMoney('bank', price, 'vehicle-transfer')

        TriggerClientEvent('QBCore:Notify', buyerId, 'You bought ['..offer.plate..'] for $'..price, 'success')
        TriggerClientEvent('QBCore:Notify', offer.sellerId, 'You sold ['..offer.plate..'] for $'..price, 'success')

        VehicleOffers[buyerId] = nil
    end)
end)

-- buyer declines
RegisterNetEvent('transfervehicle:server:decline', function()
    local buyerId = source
    local offer = VehicleOffers[buyerId]
    if offer then
        TriggerClientEvent('QBCore:Notify', offer.sellerId, 'Buyer declined the transfer.', 'error')
        TriggerClientEvent('QBCore:Notify', buyerId, 'You declined the transfer.', 'error')
        VehicleOffers[buyerId] = nil
    end
end)
