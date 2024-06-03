-- Variables
local Plates = {}
local PlayerStatus = {}
local Casings = {}
local BloodDrops = {}
local FingerDrops = {}
local Objects = {}
local KGCore = exports['kg-core']:GetCoreObject()
local updatingCops = false

-- Functions
local function UpdateBlips()
    local dutyPlayers = {}
    local players = KGCore.Functions.GetKGPlayers()
    for i = 1, #players do
        local v = players[i]
        if v and (v.PlayerData.job.type == 'leo' or v.PlayerData.job.type == 'ems') and v.PlayerData.job.onduty then
            local coords = GetEntityCoords(GetPlayerPed(v.PlayerData.source))
            local heading = GetEntityHeading(GetPlayerPed(v.PlayerData.source))
            dutyPlayers[#dutyPlayers + 1] = {
                source = v.PlayerData.source,
                label = v.PlayerData.metadata['callsign'],
                job = v.PlayerData.job.name,
                location = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    w = heading
                }
            }
        end
    end
    TriggerClientEvent('police:client:UpdateBlips', -1, dutyPlayers)
end

local function CreateBloodId()
    if BloodDrops then
        local bloodId = math.random(10000, 99999)
        while BloodDrops[bloodId] do
            bloodId = math.random(10000, 99999)
        end
        return bloodId
    else
        local bloodId = math.random(10000, 99999)
        return bloodId
    end
end

local function CreateFingerId()
    if FingerDrops then
        local fingerId = math.random(10000, 99999)
        while FingerDrops[fingerId] do
            fingerId = math.random(10000, 99999)
        end
        return fingerId
    else
        local fingerId = math.random(10000, 99999)
        return fingerId
    end
end

local function CreateCasingId()
    if Casings then
        local caseId = math.random(10000, 99999)
        while Casings[caseId] do
            caseId = math.random(10000, 99999)
        end
        return caseId
    else
        local caseId = math.random(10000, 99999)
        return caseId
    end
end

local function CreateObjectId()
    if Objects then
        local objectId = math.random(10000, 99999)
        while Objects[objectId] do
            objectId = math.random(10000, 99999)
        end
        return objectId
    else
        local objectId = math.random(10000, 99999)
        return objectId
    end
end

local function IsVehicleOwned(plate)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
    return result
end

local function GetCurrentCops()
    local amount = 0
    local players = KGCore.Functions.GetKGPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            amount += 1
        end
    end
    return amount
end

local function DnaHash(s)
    local h = string.gsub(s, '.', function(c)
        return string.format('%02x', string.byte(c))
    end)
    return h
end

-- Commands
KGCore.Commands.Add('spikestrip', Lang:t('commands.place_spike'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:SpawnSpikeStrip', src)
    end
end)

KGCore.Commands.Add('grantlicense', Lang:t('commands.license_grant'), { { name = 'id', help = Lang:t('info.player_id') }, { name = 'license', help = Lang:t('info.license_type') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.grade.level >= Config.LicenseRank then
        if args[2] == 'driver' or args[2] == 'weapon' then
            local SearchedPlayer = KGCore.Functions.GetPlayer(tonumber(args[1]))
            if not SearchedPlayer then return end
            local licenseTable = SearchedPlayer.PlayerData.metadata['licences']
            if licenseTable[args[2]] then
                TriggerClientEvent('KGCore:Notify', src, Lang:t('error.license_already'), 'error')
                return
            end
            licenseTable[args[2]] = true
            SearchedPlayer.Functions.SetMetaData('licences', licenseTable)
            TriggerClientEvent('KGCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('success.granted_license'), 'success')
            TriggerClientEvent('KGCore:Notify', src, Lang:t('success.grant_license'), 'success')
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.error_license_type'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.rank_license'), 'error')
    end
end)

KGCore.Commands.Add('revokelicense', Lang:t('commands.license_revoke'), { { name = 'id', help = Lang:t('info.player_id') }, { name = 'license', help = Lang:t('info.license_type') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.grade.level >= Config.LicenseRank then
        if args[2] == 'driver' or args[2] == 'weapon' then
            local SearchedPlayer = KGCore.Functions.GetPlayer(tonumber(args[1]))
            if not SearchedPlayer then return end
            local licenseTable = SearchedPlayer.PlayerData.metadata['licences']
            if not licenseTable[args[2]] then
                TriggerClientEvent('KGCore:Notify', src, Lang:t('error.error_license'), 'error')
                return
            end
            licenseTable[args[2]] = false
            SearchedPlayer.Functions.SetMetaData('licences', licenseTable)
            TriggerClientEvent('KGCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('error.revoked_license'), 'error')
            TriggerClientEvent('KGCore:Notify', src, Lang:t('success.revoke_license'), 'success')
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.error_license'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.rank_revoke'), 'error')
    end
end)

KGCore.Commands.Add('pobject', Lang:t('commands.place_object'), { { name = 'type', help = Lang:t('info.poobject_object') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local type = args[1]:lower()
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        if type == 'cone' then
            TriggerClientEvent('police:client:spawnCone', src)
        elseif type == 'barrier' then
            TriggerClientEvent('police:client:spawnBarrier', src)
        elseif type == 'roadsign' then
            TriggerClientEvent('police:client:spawnRoadSign', src)
        elseif type == 'tent' then
            TriggerClientEvent('police:client:spawnTent', src)
        elseif type == 'light' then
            TriggerClientEvent('police:client:spawnLight', src)
        elseif type == 'delete' then
            TriggerClientEvent('police:client:deleteObject', src)
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('cuff', Lang:t('commands.cuff_player'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:CuffPlayer', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('escort', Lang:t('commands.escort'), {}, false, function(source)
    local src = source
    TriggerClientEvent('police:client:EscortPlayer', src)
end)

KGCore.Commands.Add('callsign', Lang:t('commands.callsign'), { { name = 'name', help = Lang:t('info.callsign_name') } }, false, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    Player.Functions.SetMetaData('callsign', table.concat(args, ' '))
end)

KGCore.Commands.Add('clearcasings', Lang:t('commands.clear_casign'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('evidence:client:ClearCasingsInArea', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('jail', Lang:t('commands.jail_player'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:JailPlayer', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('unjail', Lang:t('commands.unjail_player'), { { name = 'id', help = Lang:t('info.player_id') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('prison:client:UnjailPerson', tonumber(args[1]))
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('clearblood', Lang:t('commands.clearblood'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('evidence:client:ClearBlooddropsInArea', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('seizecash', Lang:t('commands.seizecash'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:SeizeCash', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('sc', Lang:t('commands.softcuff'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:CuffPlayerSoft', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('cam', Lang:t('commands.camera'), { { name = 'camid', help = Lang:t('info.camera_id') } }, false, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:ActiveCamera', src, tonumber(args[1]))
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('flagplate', Lang:t('commands.flagplate'), { { name = 'plate', help = Lang:t('info.plate_number') }, { name = 'reason', help = Lang:t('info.flag_reason') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        local reason = {}
        for i = 2, #args, 1 do
            reason[#reason + 1] = args[i]
        end
        Plates[args[1]:upper()] = {
            isflagged = true,
            reason = table.concat(reason, ' ')
        }
        TriggerClientEvent('KGCore:Notify', src, Lang:t('info.vehicle_flagged', { vehicle = args[1]:upper(), reason = table.concat(reason, ' ') }))
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('unflagplate', Lang:t('commands.unflagplate'), { { name = 'plate', help = Lang:t('info.plate_number') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        if Plates and Plates[args[1]:upper()] then
            if Plates[args[1]:upper()].isflagged then
                Plates[args[1]:upper()].isflagged = false
                TriggerClientEvent('KGCore:Notify', src, Lang:t('info.unflag_vehicle', { vehicle = args[1]:upper() }))
            else
                TriggerClientEvent('KGCore:Notify', src, Lang:t('error.vehicle_not_flag'), 'error')
            end
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.vehicle_not_flag'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('plateinfo', Lang:t('commands.plateinfo'), { { name = 'plate', help = Lang:t('info.plate_number') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        if Plates and Plates[args[1]:upper()] then
            if Plates[args[1]:upper()].isflagged then
                TriggerClientEvent('KGCore:Notify', src, Lang:t('success.vehicle_flagged', { plate = args[1]:upper(), reason = Plates[args[1]:upper()].reason }), 'success')
            else
                TriggerClientEvent('KGCore:Notify', src, Lang:t('error.vehicle_not_flag'), 'error')
            end
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.vehicle_not_flag'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('depot', Lang:t('commands.depot'), { { name = 'price', help = Lang:t('info.impound_price') } }, false, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:ImpoundVehicle', src, false, tonumber(args[1]))
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('impound', Lang:t('commands.impound'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:ImpoundVehicle', src, true)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('paytow', Lang:t('commands.paytow'), { { name = 'id', help = Lang:t('info.player_id') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        local playerId = tonumber(args[1])
        local OtherPlayer = KGCore.Functions.GetPlayer(playerId)
        if OtherPlayer then
            if OtherPlayer.PlayerData.job.name == 'tow' then
                OtherPlayer.Functions.AddMoney('bank', 500, 'police-tow-paid')
                TriggerClientEvent('KGCore:Notify', OtherPlayer.PlayerData.source, Lang:t('success.tow_paid'), 'success')
                TriggerClientEvent('KGCore:Notify', src, Lang:t('info.tow_driver_paid'))
            else
                TriggerClientEvent('KGCore:Notify', src, Lang:t('error.not_towdriver'), 'error')
            end
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('paylawyer', Lang:t('commands.paylawyer'), { { name = 'id', help = Lang:t('info.player_id') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' or Player.PlayerData.job.name == 'judge' then
        local playerId = tonumber(args[1])
        local OtherPlayer = KGCore.Functions.GetPlayer(playerId)
        if not OtherPlayer then return end
        if OtherPlayer.PlayerData.job.name == 'lawyer' then
            OtherPlayer.Functions.AddMoney('bank', 500, 'police-lawyer-paid')
            TriggerClientEvent('KGCore:Notify', OtherPlayer.PlayerData.source, Lang:t('success.tow_paid'), 'success')
            TriggerClientEvent('KGCore:Notify', src, Lang:t('info.paid_lawyer'))
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.not_lawyer'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('fine', Lang:t('commands.fine'), { { name = 'id', help = Lang:t('info.player_id') }, { name = 'amount', help = Lang:t('info.amount') } }, false, function(source, args)
    local biller = KGCore.Functions.GetPlayer(source)
    local billed = KGCore.Functions.GetPlayer(tonumber(args[1]))
    local amount = tonumber(args[2])
    if biller.PlayerData.job.type == 'leo' then
        if billed ~= nil then
            if biller.PlayerData.citizenid ~= billed.PlayerData.citizenid then
                if amount and amount > 0 then
                    if billed.Functions.RemoveMoney('bank', amount, 'paid-fine') then
                        TriggerClientEvent('KGCore:Notify', source, Lang:t('info.fine_issued'), 'success')
                        TriggerClientEvent('KGCore:Notify', billed.PlayerData.source, Lang:t('info.received_fine'))
                        exports['kg-banking']:AddMoney(biller.PlayerData.job.name, amount, 'Fine')
                    elseif billed.Functions.RemoveMoney('cash', amount, 'paid-fine') then
                        TriggerClientEvent('KGCore:Notify', source, Lang:t('info.fine_issued'), 'success')
                        TriggerClientEvent('KGCore:Notify', billed.PlayerData.source, Lang:t('info.received_fine'))
                        exports['kg-banking']:AddMoney(biller.PlayerData.job.name, amount, 'Fine')
                    else
                        MySQL.Async.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)', { billed.PlayerData.citizenid, amount, biller.PlayerData.job.name, biller.PlayerData.charinfo.firstname, biller.PlayerData.citizenid }, function(id)
                            if id then
                                TriggerClientEvent('kg-phone:client:AcceptorDenyInvoice', billed.PlayerData.source, id, biller.PlayerData.charinfo.firstname, biller.PlayerData.job.name, biller.PlayerData.citizenid, amount, GetInvokingResource())
                            end
                        end)
                        TriggerClientEvent('kg-phone:RefreshPhone', billed.PlayerData.source)
                    end
                else
                    TriggerClientEvent('KGCore:Notify', source, Lang:t('error.amount_higher'), 'error')
                end
            else
                TriggerClientEvent('KGCore:Notify', source, Lang:t('error.fine_yourself'), 'error')
            end
        else
            TriggerClientEvent('KGCore:Notify', source, Lang:t('error.not_online'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', source, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('anklet', Lang:t('commands.anklet'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:CheckDistance', src)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('ankletlocation', Lang:t('commands.ankletlocation'), { { name = 'cid', help = Lang:t('info.citizen_id') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        local citizenid = args[1]
        local Target = KGCore.Functions.GetPlayerByCitizenId(citizenid)
        if not Target then return end
        if Target.PlayerData.metadata['tracker'] then
            TriggerClientEvent('police:client:SendTrackerLocation', Target.PlayerData.source, src)
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.no_anklet'), 'error')
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('takedrivinglicense', Lang:t('commands.drivinglicense'), {}, false, function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' and Player.PlayerData.job.onduty then
        TriggerClientEvent('police:client:SeizeDriverLicense', source)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.on_duty_police_only'), 'error')
    end
end)

KGCore.Commands.Add('takedna', Lang:t('commands.takedna'), { { name = 'id', help = Lang:t('info.player_id') } }, true, function(source, args)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local OtherPlayer = KGCore.Functions.GetPlayer(tonumber(args[1]))
    if not OtherPlayer or Player.PlayerData.job.type ~= 'leo' or not Player.PlayerData.job.onduty then return end
    if exports['kg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1, false, 'kg-policejob:takedna') then
        local info = {
            label = Lang:t('info.dna_sample'),
            type = 'dna',
            dnalabel = DnaHash(OtherPlayer.PlayerData.citizenid)
        }
        if not exports['kg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, info, 'kg-policejob:takedna') then return end
        TriggerClientEvent('kg-inventory:client:ItemBox', src, KGCore.Shared.Items['filled_evidence_bag'], 'add')
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
    end
end)

RegisterNetEvent('police:server:SendTrackerLocation', function(coords, requestId)
    local Target = KGCore.Functions.GetPlayer(source)
    local msg = Lang:t('info.target_location', { firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname })
    local alertData = {
        title = Lang:t('info.anklet_location'),
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        },
        description = msg
    }
    TriggerClientEvent('police:client:TrackerMessage', requestId, msg, coords)
    TriggerClientEvent('kg-phone:client:addPoliceAlert', requestId, alertData)
end)

KGCore.Commands.Add('911p', Lang:t('commands.police_report'), { { name = 'message', help = Lang:t('commands.message_sent') } }, false, function(source, args)
    local src = source
    local message
    if args[1] then message = table.concat(args, ' ') else message = Lang:t('commands.civilian_call') end
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = KGCore.Functions.GetKGPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            local alertData = { title = Lang:t('commands.emergency_call'), coords = { x = coords.x, y = coords.y, z = coords.z }, description = message }
            TriggerClientEvent('kg-phone:client:addPoliceAlert', v.PlayerData.source, alertData)
            TriggerClientEvent('police:client:policeAlert', v.PlayerData.source, coords, message)
        end
    end
end)

-- Items
KGCore.Functions.CreateUseableItem('handcuffs', function(source)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if not Player.Functions.GetItemByName('handcuffs') then return end
    TriggerClientEvent('police:client:CuffPlayerSoft', src)
end)

KGCore.Functions.CreateUseableItem('moneybag', function(source, item)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not Player.Functions.GetItemByName('moneybag') or not item.info or item.info == '' then return end
    if not Player.PlayerData.job.type == 'leo' then return end
    if not exports['kg-inventory']:RemoveItem(src, 'moneybag', 1, item.slot, 'kg-policejob:moneybag') then return end
    Player.Functions.AddMoney('cash', tonumber(item.info.cash), 'kg-policejob:moneybag')
end)

-- Callbacks
KGCore.Functions.CreateCallback('police:server:isPlayerDead', function(_, cb, playerId)
    local Player = KGCore.Functions.GetPlayer(playerId)
    cb(Player.PlayerData.metadata['isdead'])
end)

KGCore.Functions.CreateCallback('police:GetPlayerStatus', function(_, cb, playerId)
    local Player = KGCore.Functions.GetPlayer(playerId)
    local statList = {}
    if Player then
        if PlayerStatus[Player.PlayerData.source] and next(PlayerStatus[Player.PlayerData.source]) then
            for k in pairs(PlayerStatus[Player.PlayerData.source]) do
                statList[#statList + 1] = PlayerStatus[Player.PlayerData.source][k].text
            end
        end
    end
    cb(statList)
end)

KGCore.Functions.CreateCallback('police:IsSilencedWeapon', function(source, cb, weapon)
    local Player = KGCore.Functions.GetPlayer(source)
    local itemInfo = Player.Functions.GetItemByName(KGCore.Shared.Weapons[weapon]['name'])
    local retval = false
    if itemInfo then
        if itemInfo.info and itemInfo.info.attachments then
            for k in pairs(itemInfo.info.attachments) do
                if itemInfo.info.attachments[k].component == 'COMPONENT_AT_AR_SUPP_02' or
                    itemInfo.info.attachments[k].component == 'COMPONENT_AT_AR_SUPP' or
                    itemInfo.info.attachments[k].component == 'COMPONENT_AT_PI_SUPP_02' or
                    itemInfo.info.attachments[k].component == 'COMPONENT_AT_PI_SUPP' then
                    retval = true
                end
            end
        end
    end
    cb(retval)
end)

KGCore.Functions.CreateCallback('police:GetDutyPlayers', function(_, cb)
    local dutyPlayers = {}
    local players = KGCore.Functions.GetKGPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            dutyPlayers[#dutyPlayers + 1] = {
                source = v.PlayerData.source,
                label = v.PlayerData.metadata['callsign'],
                job = v.PlayerData.job.name
            }
        end
    end
    cb(dutyPlayers)
end)

KGCore.Functions.CreateCallback('police:GetImpoundedVehicles', function(_, cb)
    local vehicles = {}
    MySQL.query('SELECT * FROM player_vehicles WHERE state = ?', { 2 }, function(result)
        if result[1] then
            vehicles = result
        end
        cb(vehicles)
    end)
end)

KGCore.Functions.CreateCallback('police:IsPlateFlagged', function(_, cb, plate)
    local retval = false
    if Plates and Plates[plate] then
        if Plates[plate].isflagged then
            retval = true
        end
    end
    cb(retval)
end)

KGCore.Functions.CreateCallback('police:GetCops', function(_, cb)
    local amount = 0
    local players = KGCore.Functions.GetKGPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
end)

KGCore.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(_, cb)
    local retval = false
    local players = KGCore.Functions.GetKGPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.grade.level >= 2 then
            retval = true
            break
        end
    end
    cb(retval)
end)

-- Events

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CreateThread(function()
            MySQL.query("DELETE FROM inventories WHERE identifier = 'policetrash'")
        end)
    end
end)

RegisterNetEvent('kg-policejob:server:stash', function()
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.type ~= 'leo' then return end
    local citizenId = Player.PlayerData.citizenid
    local stashName = 'policestash_' .. citizenId
    exports['kg-inventory']:OpenInventory(src, stashName)
end)

RegisterNetEvent('kg-policejob:server:trash', function()
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.type ~= 'leo' then return end
    exports['kg-inventory']:OpenInventory(src, 'policetrash', {
        maxweight = 4000000,
        slots = 300,
    })
end)

RegisterNetEvent('kg-policejob:server:evidence', function(currentEvidence)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.type ~= 'leo' then return end
    exports['kg-inventory']:OpenInventory(src, currentEvidence, {
        maxweight = 4000000,
        slots = 500,
    })
end)

RegisterNetEvent('police:server:SearchPlayer', function()
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if not Player then return end
    local PlayerData = Player.PlayerData
    if PlayerData.job.type ~= 'leo' then return end
    local player, distance = KGCore.Functions.GetClosestPlayer(src)
    if player ~= -1 and distance < 2.5 then
        local SearchedPlayer = KGCore.Functions.GetPlayer(tonumber(player))
        if not SearchedPlayer then return end
        exports['kg-inventory']:OpenInventoryById(src, tonumber(player))
        TriggerClientEvent('KGCore:Notify', src, Lang:t('info.cash_found', { cash = SearchedPlayer.PlayerData.money['cash'] }))
        TriggerClientEvent('KGCore:Notify', player, Lang:t('info.being_searched'))
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.none_nearby'), 'error')
    end
end)

RegisterNetEvent('police:server:policeAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = KGCore.Functions.GetKGPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            local alertData = { title = Lang:t('info.new_call'), coords = { x = coords.x, y = coords.y, z = coords.z }, description = text }
            TriggerClientEvent('kg-phone:client:addPoliceAlert', v.PlayerData.source, alertData)
            TriggerClientEvent('police:client:policeAlert', v.PlayerData.source, coords, text)
        end
    end
end)

RegisterNetEvent('police:server:TakeOutImpound', function(plate, garage)
    local src = source
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = Config.Locations['impound'][garage]
    if #(playerCoords - targetCoords) > 10.0 then return DropPlayer(src, 'Attempted exploit abuse') end
    MySQL.update('UPDATE player_vehicles SET state = ? WHERE plate = ?', { 0, plate })
    TriggerClientEvent('KGCore:Notify', src, Lang:t('success.impound_vehicle_removed'), 'success')
end)

RegisterNetEvent('police:server:CuffPlayer', function(playerId, isSoftcuff)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Player = KGCore.Functions.GetPlayer(src)
    local CuffedPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not CuffedPlayer or (not Player.Functions.GetItemByName('handcuffs') and Player.PlayerData.job.type ~= 'leo') then return end

    TriggerClientEvent('police:client:GetCuffed', CuffedPlayer.PlayerData.source, Player.PlayerData.source, isSoftcuff)
end)

RegisterNetEvent('police:server:EscortPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Player = KGCore.Functions.GetPlayer(source)
    local EscortPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not EscortPlayer then return end

    if (Player.PlayerData.job.type == 'leo' or Player.PlayerData.job.name == 'ambulance') or (EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] or EscortPlayer.PlayerData.metadata['inlaststand']) then
        TriggerClientEvent('police:client:GetEscorted', EscortPlayer.PlayerData.source, Player.PlayerData.source)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:KidnapPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Player = KGCore.Functions.GetPlayer(source)
    local EscortPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] or EscortPlayer.PlayerData.metadata['inlaststand'] then
        TriggerClientEvent('police:client:GetKidnappedTarget', EscortPlayer.PlayerData.source, Player.PlayerData.source)
        TriggerClientEvent('police:client:GetKidnappedDragger', Player.PlayerData.source, EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:SetPlayerOutVehicle', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local EscortPlayer = KGCore.Functions.GetPlayer(playerId)
    if not KGCore.Functions.GetPlayer(src) or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] then
        TriggerClientEvent('police:client:SetOutVehicle', EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local EscortPlayer = KGCore.Functions.GetPlayer(playerId)
    if not KGCore.Functions.GetPlayer(src) or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] then
        TriggerClientEvent('police:client:PutInVehicle', EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:BillPlayer', function(playerId, price)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Player = KGCore.Functions.GetPlayer(src)
    local OtherPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not OtherPlayer or Player.PlayerData.job.type ~= 'leo' then return end

    OtherPlayer.Functions.RemoveMoney('bank', price, 'paid-bills')
    exports['kg-banking']:AddMoney('police', price, 'Fine paid')
    TriggerClientEvent('KGCore:Notify', OtherPlayer.PlayerData.source, Lang:t('info.fine_received', { fine = price }))
end)

RegisterNetEvent('police:server:JailPlayer', function(playerId, time)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Player = KGCore.Functions.GetPlayer(src)
    local OtherPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not OtherPlayer or Player.PlayerData.job.type ~= 'leo' then return end

    local currentDate = os.date('*t')
    if currentDate.day == 31 then
        currentDate.day = 30
    end

    OtherPlayer.Functions.SetMetaData('injail', time)
    OtherPlayer.Functions.SetMetaData('criminalrecord', {
        ['hasRecord'] = true,
        ['date'] = currentDate
    })
    TriggerClientEvent('police:client:SendToJail', OtherPlayer.PlayerData.source, time)
    TriggerClientEvent('KGCore:Notify', src, Lang:t('info.sent_jail_for', { time = time }))
end)

RegisterNetEvent('police:server:SetHandcuffStatus', function(isHandcuffed)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMetaData('ishandcuffed', isHandcuffed)
    end
end)

RegisterNetEvent('heli:spotlight', function(state)
    local serverID = source
    TriggerClientEvent('heli:spotlight', -1, serverID, state)
end)

-- RegisterNetEvent('police:server:FlaggedPlateTriggered', function(camId, plate, street1, street2, blipSettings)
--     local src = source
--     for k, v in pairs(KGCore.Functions.GetPlayers()) do
--         local Player = KGCore.Functions.GetPlayer(v)
--         if Player then
--             if (Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty) then
--                 if street2 then
--                     TriggerClientEvent("112:client:SendPoliceAlert", v, "flagged", {
--                         camId = camId,
--                         plate = plate,
--                         streetLabel = street1 .. " " .. street2
--                     }, blipSettings)
--                 else
--                     TriggerClientEvent("112:client:SendPoliceAlert", v, "flagged", {
--                         camId = camId,
--                         plate = plate,
--                         streetLabel = street1
--                     }, blipSettings)
--                 end
--             end
--         end
--     end
-- end)

RegisterNetEvent('police:server:SeizeCash', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end
    local Player = KGCore.Functions.GetPlayer(src)
    local SearchedPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not SearchedPlayer then return end
    if Player.PlayerData.job.type ~= 'leo' then return end
    local moneyAmount = SearchedPlayer.PlayerData.money['cash']
    local info = { cash = moneyAmount }
    SearchedPlayer.Functions.RemoveMoney('cash', moneyAmount, 'police-cash-seized')
    exports['kg-inventory']:AddItem(src, 'moneybag', 1, false, info, 'police:server:SeizeCash')
    TriggerClientEvent('kg-inventory:client:ItemBox', src, KGCore.Shared.Items['moneybag'], 'add')
    TriggerClientEvent('KGCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('info.cash_confiscated'))
end)

RegisterNetEvent('police:server:SeizeDriverLicense', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local SearchedPlayer = KGCore.Functions.GetPlayer(playerId)
    if not KGCore.Functions.GetPlayer(src) or not SearchedPlayer then return end

    local driverLicense = SearchedPlayer.PlayerData.metadata['licences']['driver']
    if driverLicense then
        local licenses = { ['driver'] = false, ['business'] = SearchedPlayer.PlayerData.metadata['licences']['business'] }
        SearchedPlayer.Functions.SetMetaData('licences', licenses)
        TriggerClientEvent('KGCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('info.driving_license_confiscated'))
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.no_driver_license'), 'error')
    end
end)

RegisterNetEvent('police:server:RobPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Player = KGCore.Functions.GetPlayer(src)
    local SearchedPlayer = KGCore.Functions.GetPlayer(playerId)
    if not Player or not SearchedPlayer then return end

    local money = SearchedPlayer.PlayerData.money['cash']
    Player.Functions.AddMoney('cash', money, 'police-player-robbed')
    SearchedPlayer.Functions.RemoveMoney('cash', money, 'police-player-robbed')
    exports['kg-inventory']:OpenInventoryById(src, playerId)
    TriggerClientEvent('KGCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('info.cash_robbed', { money = money }))
    TriggerClientEvent('KGCore:Notify', Player.PlayerData.source, Lang:t('info.stolen_money', { stolen = money }))
end)

RegisterNetEvent('police:server:spawnObject', function(type)
    local src = source
    local objectId = CreateObjectId()
    Objects[objectId] = type
    TriggerClientEvent('police:client:spawnObject', src, objectId, type, src)
end)

RegisterNetEvent('police:server:deleteObject', function(objectId)
    TriggerClientEvent('police:client:removeObject', -1, objectId)
end)

RegisterNetEvent('police:server:Impound', function(plate, fullImpound, price, body, engine, fuel)
    local src = source
    price = price and price or 0
    if IsVehicleOwned(plate) then
        if not fullImpound then
            MySQL.query(
                'UPDATE player_vehicles SET state = ?, depotprice = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?',
                { 0, price, body, engine, fuel, plate })
            TriggerClientEvent('KGCore:Notify', src, Lang:t('info.vehicle_taken_depot', { price = price }))
        else
            MySQL.query(
                'UPDATE player_vehicles SET state = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?',
                { 2, body, engine, fuel, plate })
            TriggerClientEvent('KGCore:Notify', src, Lang:t('info.vehicle_seized'))
        end
    end
end)

RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    local src = source
    PlayerStatus[src] = data
end)

RegisterNetEvent('evidence:server:CreateBloodDrop', function(citizenid, bloodtype, coords)
    local bloodId = CreateBloodId()
    BloodDrops[bloodId] = {
        dna = citizenid,
        bloodtype = bloodtype
    }
    TriggerClientEvent('evidence:client:AddBlooddrop', -1, bloodId, citizenid, bloodtype, coords)
end)

RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local fingerId = CreateFingerId()
    FingerDrops[fingerId] = Player.PlayerData.metadata['fingerprint']
    TriggerClientEvent('evidence:client:AddFingerPrint', -1, fingerId, Player.PlayerData.metadata['fingerprint'], coords)
end)

RegisterNetEvent('evidence:server:ClearBlooddrops', function(blooddropList)
    if blooddropList and next(blooddropList) then
        for _, v in pairs(blooddropList) do
            TriggerClientEvent('evidence:client:RemoveBlooddrop', -1, v)
            BloodDrops[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddBlooddropToInventory', function(bloodId, bloodInfo)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if exports['kg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1, false, 'evidence:server:AddBlooddropToInventory') then
        if exports['kg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, bloodInfo, 'evidence:server:AddBlooddropToInventory') then
            TriggerClientEvent('kg-inventory:client:ItemBox', src, KGCore.Shared.Items['filled_evidence_bag'], 'add')
            TriggerClientEvent('evidence:client:RemoveBlooddrop', -1, bloodId)
            BloodDrops[bloodId] = nil
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
    end
end)

RegisterNetEvent('evidence:server:AddFingerprintToInventory', function(fingerId, fingerInfo)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if exports['kg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1, false, 'evidence:server:AddFingerprintToInventory') then
        if exports['kg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, fingerInfo, 'evidence:server:AddFingerprintToInventory') then
            TriggerClientEvent('kg-inventory:client:ItemBox', src, KGCore.Shared.Items['filled_evidence_bag'], 'add')
            TriggerClientEvent('evidence:client:RemoveFingerprint', -1, fingerId)
            FingerDrops[fingerId] = nil
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
    end
end)

RegisterNetEvent('evidence:server:CreateCasing', function(weapon, coords)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local casingId = CreateCasingId()
    local weaponInfo = KGCore.Shared.Weapons[weapon]
    local serieNumber = nil
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        if weaponItem then
            if weaponItem.info and weaponItem.info ~= '' then
                serieNumber = weaponItem.info.serie
            end
        end
    end
    TriggerClientEvent('evidence:client:AddCasing', -1, casingId, weapon, coords, serieNumber)
end)

RegisterNetEvent('police:server:UpdateCurrentCops', function()
    local amount = 0
    local players = KGCore.Functions.GetKGPlayers()
    if updatingCops then return end
    updatingCops = true
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            amount += 1
        end
    end
    TriggerClientEvent('police:SetCopCount', -1, amount)
    updatingCops = false
end)

RegisterNetEvent('evidence:server:ClearCasings', function(casingList)
    if casingList and next(casingList) then
        for _, v in pairs(casingList) do
            TriggerClientEvent('evidence:client:RemoveCasing', -1, v)
            Casings[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddCasingToInventory', function(casingId, casingInfo)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    if exports['kg-inventory']:RemoveItem(src, 'empty_evidence_bag', 1, false, 'evidence:server:AddCasingToInventory') then
        if exports['kg-inventory']:AddItem(src, 'filled_evidence_bag', 1, false, casingInfo, 'evidence:server:AddCasingToInventory') then
            TriggerClientEvent('kg-inventory:client:ItemBox', src, KGCore.Shared.Items['filled_evidence_bag'], 'add')
            TriggerClientEvent('evidence:client:RemoveCasing', -1, casingId)
            Casings[casingId] = nil
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.have_evidence_bag'), 'error')
    end
end)

RegisterNetEvent('police:server:showFingerprint', function(playerId)
    local src = source
    TriggerClientEvent('police:client:showFingerprint', playerId, src)
    TriggerClientEvent('police:client:showFingerprint', src, playerId)
end)

RegisterNetEvent('police:server:showFingerprintId', function(sessionId)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local fid = Player.PlayerData.metadata['fingerprint']
    TriggerClientEvent('police:client:showFingerprintId', sessionId, fid)
    TriggerClientEvent('police:client:showFingerprintId', src, fid)
end)

RegisterNetEvent('police:server:SetTracker', function(targetId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, 'Attempted exploit abuse') end

    local Target = KGCore.Functions.GetPlayer(targetId)
    if not KGCore.Functions.GetPlayer(src) or not Target then return end

    local TrackerMeta = Target.PlayerData.metadata['tracker']
    if TrackerMeta then
        Target.Functions.SetMetaData('tracker', false)
        TriggerClientEvent('KGCore:Notify', targetId, Lang:t('success.anklet_taken_off'), 'success')
        TriggerClientEvent('KGCore:Notify', src, Lang:t('success.took_anklet_from', { firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname }), 'success')
        TriggerClientEvent('police:client:SetTracker', targetId, false)
    else
        Target.Functions.SetMetaData('tracker', true)
        TriggerClientEvent('KGCore:Notify', targetId, Lang:t('success.put_anklet'), 'success')
        TriggerClientEvent('KGCore:Notify', src, Lang:t('success.put_anklet_on', { firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname }), 'success')
        TriggerClientEvent('police:client:SetTracker', targetId, true)
    end
end)

RegisterNetEvent('police:server:SyncSpikes', function(table)
    TriggerClientEvent('police:client:SyncSpikes', -1, table)
end)

-- Threads
CreateThread(function()
    while true do
        Wait(1000 * 60 * 10)
        local curCops = GetCurrentCops()
        TriggerClientEvent('police:SetCopCount', -1, curCops)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        UpdateBlips()
    end
end)
