RegisterNetEvent('transfervehicle:client:offer', function(sellerId, plate, price)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local sellerPed = GetPlayerPed(GetPlayerFromServerId(sellerId))
    local sellerCoords = GetEntityCoords(sellerPed)

    if #(coords - sellerCoords) > 5.0 then
        TriggerServerEvent('transfervehicle:server:decline', sellerId)
        return
    end

    local accept = lib.alertDialog({
        header = 'Vehicle Transfer',
        content = ('Player %s is selling you [%s] for $%s.'):format(sellerId, plate, price),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Accept',
            cancel = 'Decline'
        }
    })

    if accept == 'confirm' then
        local method = lib.inputDialog('Payment Method', {
            { type = 'select', label = 'Choose payment method', options = {
                { label = 'Bank', value = 'bank' },
                { label = 'Cash', value = 'cash' },
                { label = 'Try Cash then Bank', value = 'both' }
            }}
        })

        if method and method[1] then
            TriggerServerEvent('transfervehicle:server:accept', sellerId, plate, price, method[1])
        else
            TriggerServerEvent('transfervehicle:server:decline', sellerId)
        end
    else
        TriggerServerEvent('transfervehicle:server:decline', sellerId)
    end
end)
