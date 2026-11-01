-- Server side of the notifications (notify.lua):
--   exports['vi-hud']:Notify(playerId, { title = 'Paid', description = '$500', type = 'success' })
--   exports['vi-hud']:Notify(playerId, 'Message', 'error', 5000, 'Title')
-- playerId -1 = everyone.

exports('Notify', function(playerId, ...)
    TriggerClientEvent('vi-hud:notify', playerId, ...)
end)

-- Pause menu (pause.lua): "Leave server"
RegisterNetEvent('vi-hud:leave', function()
    local P = Config.PauseMenu or {}
    if not P.Enabled or P.LeaveButton == false then return end
    DropPlayer(source, P.LeaveMessage or 'Left via the pause menu')
end)
