local QBCore = exports['qb-core']:GetCoreObject()

-- Command: /transfervehicle [id] [price]
RegisterCommand("transfervehicle", function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not args[1] or not args[2] then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /transfervehicle [playerID] [price]', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local price = tonumber(args[2])

    if not targetId or not price or price < 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid arguments!', 'error')
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
        TriggerClientEvent('QBCore:Notify', src, 'You must be sitting in the vehicle you want to transfer!', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)
    if not plate then
        TriggerClientEvent('QBCore:Notify', src, 'Could not detect plate!', 'error')
        return
    end

    -- Verify ownership
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, Player.PlayerData.citizenid}, function(result)
        if result[1] then
            -- Send request to buyer
            TriggerClientEvent('transfervehicle:client:offer', targetId, src, plate, price)
            TriggerClientEvent('QBCore:Notify', src, 'Offer sent to player '..targetId..' for $'..price, 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'This is not your vehicle!', 'error')
        end
    end)
end)

RegisterNetEvent('transfervehicle:server:accept', function(sellerId, plate, price, payMethod)
    local buyerId = source
    local Buyer = QBCore.Functions.GetPlayer(buyerId)
    local Seller = QBCore.Functions.GetPlayer(sellerId)

    if not Buyer or not Seller then return end

    local paid = false
    if payMethod == 'bank' then
        paid = Buyer.Functions.RemoveMoney('bank', price, 'vehicle-transfer')
    elseif payMethod == 'cash' then
        paid = Buyer.Functions.RemoveMoney('cash', price, 'vehicle-transfer')
    elseif payMethod == 'both' then
        -- Try cash first, then bank
        if Buyer.Functions.RemoveMoney('cash', price, 'vehicle-transfer') then
            paid = true
        elseif Buyer.Functions.RemoveMoney('bank', price, 'vehicle-transfer') then
            paid = true
        end
    end

    if paid then
        Seller.Functions.AddMoney('bank', price, 'vehicle-transfer')

        MySQL.update('UPDATE player_vehicles SET citizenid = ? WHERE plate = ?', {
            Buyer.PlayerData.citizenid, plate
        })

        TriggerClientEvent('QBCore:Notify', buyerId, 'You bought ['..plate..'] for $'..price, 'success')
        TriggerClientEvent('QBCore:Notify', sellerId, 'You sold ['..plate..'] for $'..price, 'success')
    else
        TriggerClientEvent('QBCore:Notify', buyerId, 'You don\'t have enough money!', 'error')
        TriggerClientEvent('QBCore:Notify', sellerId, 'Buyer couldn\'t pay!', 'error')
    end
end)

RegisterNetEvent('transfervehicle:server:decline', function(sellerId)
    local src = source
    TriggerClientEvent('QBCore:Notify', sellerId, 'Buyer declined the transfer.', 'error')
    TriggerClientEvent('QBCore:Notify', src, 'You declined the transfer.', 'error')
end)
