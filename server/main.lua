Citizen.CreateThread(function()
	SetMapName('San Andreas')
	SetGameType('Roleplay')

	--SetConvarServerInfo('Forum', '')
	--SetConvarServerInfo('Discord', 'discord.gg/')

	local resourcesStopped = {}
	ExecuteCommand('add_ace resource.es_extended command.stop allow')

	for resourceName,reason in pairs(Config.IncompatibleResourcesToStop) do
		local status = GetResourceState(resourceName)

		if status == 'started' or status == 'starting' then
			while GetResourceState(resourceName) == 'starting' do
				Citizen.Wait(100)
			end

			ExecuteCommand(('stop %s'):format(resourceName))
			resourcesStopped[resourceName] = reason
		end
	end

	if ESX.Table.SizeOf(resourcesStopped) > 0 then
		local allStoppedResources = ''

		for resourceName,reason in pairs(resourcesStopped) do
			allStoppedResources = ('%s\n- ^3%s^7, %s'):format(allStoppedResources, resourceName, reason)
		end

		print(('[ESX] [^3WARNING^7] Stopped %s incompatible resource(s) that can cause issues when used with ESX. They are not needed and can safely be removed from your server, remove these resource(s) from your resource directory and your configuration file:%s'):format(ESX.Table.SizeOf(resourcesStopped), allStoppedResources))
	end
end)

--[[
AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == 'esx_kashacters' then
		print('[ESX] [^3WARNING^7] Resource ^3esx_kashacters^7 is stopping! Saving & unloading all players')

		for _,playerId in ipairs(ESX.GetPlayers()) do
			local xPlayer = ESX.GetPlayerFromId(playerId)

			if xPlayer then
				xPlayer.save(function()
					ESX.Players[playerId] = nil
				end)
			end
		end
	end
end)
]]

RegisterNetEvent('esx:onPlayerJoined')
AddEventHandler('esx:onPlayerJoined', function()
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		print(('[ESX] [^3WARNING^7] Player id "%s^7" who already is connected has been called ^3onPlayerJoined^7 on. ' ..
			'Will save player and query new character from database.'):format(playerId))

		ESX.SavePlayer(xPlayer, function()
			ESX.Players[playerId] = nil
			onPlayerJoined(playerId)
		end)
	else
		onPlayerJoined(playerId)
	end
end)

function generatePhoneNumber()
	while true do
		Citizen.Wait(100)
		local prefix, suffix = math.random(0, 999), math.random(0, 9999)
		local formattedNumber = ('%s-%s'):format(prefix, suffix)

		if isPhoneNumberAvailable(formattedNumber) then
			return formattedNumber
		end
	end
end

function isPhoneNumberAvailable(phoneNumber)
	local fetched = MySQL.Sync.fetchScalar('SELECT 1 FROM users WHERE phone_number = @phone_number', {
		['@phone_number'] = phoneNumber
	})

	return fetched == nil
end

function onPlayerJoined(playerId)
	local identifier

	for k,v in ipairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, 'steam:') then
			identifier = v
			break
		end
	end

	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			DropPlayer(playerId, ('there was an error loading your character!\nError code: identifier-active-ingame\n\n' ..
				'This error is caused because there is a player on the server with the same identifier as yours.\n\n' ..
				'Or this error can also be caused whilst the server saves your data to the hive, ' ..
				'please allow up to 10 minutes for your data to save. If it does not finish saving ' ..
				'there is a possiblity that your data had an issue saving.\n\n' ..
				'Your Steam identifier: %s'):format(GetPlayerIdentifier(playerId, 0)))
		else
			MySQL.Async.fetchScalar('SELECT 1 FROM users WHERE identifier = @identifier', {
				['@identifier'] = identifier
			}, function(result)
				if result then
					loadESXPlayer(identifier, playerId)
				else
					local accounts = {}

					for account,money in pairs(Config.StartingAccountMoney) do
						accounts[account] = money
					end

					MySQL.Async.execute('INSERT INTO users (accounts, identifier, phone_number) VALUES (@accounts, @identifier, @phone_number)', {
						['@accounts'] = json.encode(accounts),
						['@phone_number'] = generatePhoneNumber(),
						['@identifier'] = identifier
					}, function(rowsChanged)
						loadESXPlayer(identifier, playerId)
					end)
				end
			end)
		end
	else
		DropPlayer(playerId, 'there was an error loading your character!\nError code: identifier-missing-ingame\n\n' ..
			'This issue occured because your Steam identification isn\'t available, make sure Steam is running!')
	end
end

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
	deferrals.defer()
	local tempId, identifier = source
	Citizen.Wait(0)

	for k,v in ipairs(GetPlayerIdentifiers(tempId)) do
		if string.match(v, 'steam:') then
			identifier = v
			break
		end
	end

	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			deferrals.done(('there was an error loading your character!\nError code: identifier-active\n\n' ..
				'This error is caused because there is a player on the server with the same identifier as yours.\n\n' ..
				'Or this error can also be caused whilst the server saves your data to the hive, ' ..
				'please allow up to 10 minutes for your data to save. If it does not finish saving ' ..
				'there is a possiblity that your data had an issue saving.\n\n' ..
				'Your Steam identifier: %s'):format(GetPlayerIdentifier(tempId, 0)))
		else
			deferrals.done()
		end
	else
		deferrals.done('there was an error loading your character!\nError code: identifier-missing\n\n' ..
			'This issue occured because your Steam identification isn\'t available, make sure Steam is running!')
	end
end)

function loadESXPlayer(identifier, playerId)
	local userData = {
		playerId = PlayerId,
		identifier = identifier,
		accounts = {},
		inventory = {},
		job = {},
		loadout = {},
		weight = 0
	}

	MySQL.Async.fetchAll([===[
		SELECT
			groups, accounts, job, job_grade, loadout, position,
			name, skin, status, phone_number, inventory, health, armour
		FROM users
		WHERE identifier = @identifier
	]===], {
		['@identifier'] = identifier
	}, function(result)
		if result and result[1] then
			local job, grade, jobObject, gradeObject = result[1].job, tostring(result[1].job_grade)
			local foundAccounts, foundItems = {}, {}

			userData.name = result[1].name
			userData.phoneNumber = result[1].phone_number
			userData.health = result[1].health
			userData.armour = result[1].armour

			-- Skin
			if result[1].skin and result[1].skin ~= '' then
				local skin = json.decode(result[1].skin)

				if skin then
					userData.skin = skin
				end
			end

			-- Status
			if result[1].status and result[1].status ~= '' then
				local status = json.decode(result[1].status)

				if status then
					userData.status = status
				end
			end

			-- Accounts
			if result[1].accounts and result[1].accounts ~= '' then
				local accounts = json.decode(result[1].accounts)

				for account,money in pairs(accounts) do
					foundAccounts[account] = money
				end
			end

			for account,label in pairs(Config.Accounts) do
				table.insert(userData.accounts, {
					name = account,
					money = foundAccounts[account] or Config.StartingAccountMoney[account] or 0,
					label = label
				})
			end

			-- Job
			if ESX.DoesJobExist(job, grade) then
				jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
			else
				print(('[ESX] [^3WARNING^7] Ignoring invalid job for %s [job: %s, grade: %s]'):format(identifier, job, grade))
				job, grade = 'unemployed', '0'
				jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
			end

			userData.job.id = jobObject.id
			userData.job.name = jobObject.name
			userData.job.label = jobObject.label

			userData.job.grade = tonumber(grade)
			userData.job.grade_name = gradeObject.name
			userData.job.grade_label = gradeObject.label
			userData.job.grade_salary = gradeObject.salary

			userData.job.skin_male = {}
			userData.job.skin_female = {}

			if gradeObject.skin_male then userData.job.skin_male = json.decode(gradeObject.skin_male) end
			if gradeObject.skin_female then userData.job.skin_female = json.decode(gradeObject.skin_female) end

			-- Inventory
			if result[1].inventory and result[1].inventory ~= '' then
				local inventory = json.decode(result[1].inventory)

				for name,count in pairs(inventory) do
					local item = ESX.Items[name]

					if item then
						foundItems[name] = count
					else
						print(('[ESX] [^3WARNING^7] Ignoring invalid item "%s" for "%s"'):format(name, identifier))
					end
				end
			end

			for name,item in pairs(ESX.Items) do
				local count = foundItems[name] or 0
				if count > 0 then userData.weight = userData.weight + (item.weight * count) end

				table.insert(userData.inventory, {
					name = name,
					count = count,
					label = item.label,
					weight = item.weight,
					usable = ESX.UsableItemsCallbacks[name] ~= nil,
					rare = item.rare,
					canRemove = item.canRemove
				})
			end

			table.sort(userData.inventory, function(a, b)
				return a.label < b.label
			end)

			-- Groups
			if result[1].groups and result[1].groups ~= '' then
				local groups = json.decode(result[1].groups)
				userData.groups = groups
			else
				userData.groups = {['user'] = true}
			end

			-- Loadout
			if result[1].loadout and result[1].loadout ~= '' then
				local loadout = json.decode(result[1].loadout)

				for name,weapon in pairs(loadout) do
					local label = ESX.GetWeaponLabel(name)

					if label then
						if not weapon.components then weapon.components = {} end
						if not weapon.tintIndex then weapon.tintIndex = 0 end

						table.insert(userData.loadout, {
							name = name,
							ammo = weapon.ammo,
							label = label,
							components = weapon.components,
							tintIndex = weapon.tintIndex
						})
					end
				end
			end

			-- Position
			if result[1].position and result[1].position ~= '' then
				userData.coords = json.decode(result[1].position)
			else
				userData.coords = {x = -269.4, y = -955.3, z = 31.2, heading = 205.8}
			end

			-- Create ESX player object
			local xPlayer = CreateESXPlayer(userData)

			ESX.Players[playerId] = xPlayer
			TriggerEvent('esx:playerLoaded', playerId, xPlayer)

			xPlayer.triggerEvent('esx:playerLoaded', { -- all this under will REPLACE PlayerData
				inventory = xPlayer.getInventory(false, true),
				maxWeight = xPlayer.getMaxWeight(),
				loadout = xPlayer.getLoadout(),
				accounts = xPlayer.getAccounts(false, true),
				coords = xPlayer.getCoords(),
				identifier = xPlayer.getIdentifier(),
				job = xPlayer.getJob(),
				money = xPlayer.getMoney(), -- deprecated
				skin = xPlayer.getSkin(),
				status = xPlayer.getStatus()
			})

			xPlayer.triggerEvent('esx:setGroups', userData.groups)
			xPlayer.triggerEvent('esx:createMissingPickups', ESX.Pickups)
			xPlayer.triggerEvent('esx:registerSuggestions', ESX.RegisteredCommands)
			print(('[ESX] [^2INFO^7] A player with name "%s^7" has connected to the server with assigned player id %s'):format(xPlayer.getName(), playerId))
		else
			DropPlayer(playerId, 'Character query failed')
		end
	end)
end

AddEventHandler('chatMessage', function(playerId, author, message)
	if message:sub(1, 1) == '/' and playerId > 0 then
		CancelEvent()
		local commandName = message:sub(1):gmatch("%w+")()
		TriggerClientEvent('chat:addMessage', playerId, {args = {('%s is not a valid command!'):format(commandName)}})
	end
end)

AddEventHandler('playerDropped', function(reason)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		TriggerEvent('esx:playerDropped', playerId, reason)

		ESX.SavePlayer(xPlayer, function()
			print(('[ESX] [^2INFO^7] A player with name "%s^7" with server id %s has left the server'):format(xPlayer.getName(), playerId))
			ESX.Players[playerId] = nil
		end)
	end
end)

RegisterNetEvent('esx:updateCoords')
AddEventHandler('esx:updateCoords', function(coords)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateCoords(coords)
	end
end)

RegisterNetEvent('esx:updateHealth')
AddEventHandler('esx:updateHealth', function(health, armour)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		if type(health) == 'number' and type(armour) == 'number' then
			xPlayer.updateHealth(health, armour)
		end
	end
end)

RegisterNetEvent('esx:updateWeaponAmmo')
AddEventHandler('esx:updateWeaponAmmo', function(weaponName, ammoCount)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateWeaponAmmo(weaponName, ammoCount)
	end
end)

RegisterNetEvent('esx:giveInventoryItem')
AddEventHandler('esx:giveInventoryItem', function(target, type, itemName, itemCount)
	local playerId = source
	local sourceXPlayer = ESX.GetPlayerFromId(playerId)
	local targetXPlayer = ESX.GetPlayerFromId(target)

	if type == 'item_standard' then
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)

		if itemCount > 0 and sourceItem.count >= itemCount then
			if targetXPlayer.canCarryItem(itemName, itemCount) then
				sourceXPlayer.removeInventoryItem(itemName, itemCount)
				targetXPlayer.addInventoryItem   (itemName, itemCount)

				sourceXPlayer.showNotification(_U('gave_item', itemCount, sourceItem.label, targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_item', itemCount, sourceItem.label, sourceXPlayer.name))
			else
				sourceXPlayer.showNotification(_U('ex_inv_lim', targetXPlayer.name))
			end
		else
			sourceXPlayer.showNotification(_U('imp_invalid_quantity'))
		end
	elseif type == 'item_account' then
		if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
			sourceXPlayer.removeAccountMoney(itemName, itemCount)
			targetXPlayer.addAccountMoney   (itemName, itemCount)

			sourceXPlayer.showNotification(_U('gave_account_money', ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName], targetXPlayer.name))
			targetXPlayer.showNotification(_U('received_account_money', ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName], sourceXPlayer.name))
		else
			sourceXPlayer.showNotification(_U('imp_invalid_amount'))
		end
	elseif type == 'item_weapon' then
		if sourceXPlayer.hasWeapon(itemName) then
			local weaponLabel = ESX.GetWeaponLabel(itemName)

			if not targetXPlayer.hasWeapon(itemName) then
				local _, weapon = sourceXPlayer.getWeapon(itemName)
				local _, weaponObject = ESX.GetWeapon(itemName)
				itemCount = weapon.ammo

				sourceXPlayer.removeWeapon(itemName)
				targetXPlayer.addWeapon(itemName, itemCount)

				if weaponObject.ammo and itemCount > 0 then
					local ammoLabel = weaponObject.ammo.label
					sourceXPlayer.showNotification(_U('gave_weapon_withammo', weaponLabel, itemCount, ammoLabel, targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_weapon_withammo', weaponLabel, itemCount, ammoLabel, sourceXPlayer.name))
				else
					sourceXPlayer.showNotification(_U('gave_weapon', weaponLabel, targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_weapon', weaponLabel, sourceXPlayer.name))
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_hasalready', targetXPlayer.name, weaponLabel))
				targetXPlayer.showNotification(_U('received_weapon_hasalready', sourceXPlayer.name, weaponLabel))
			end
		end
	elseif type == 'item_ammo' then
		if sourceXPlayer.hasWeapon(itemName) then
			local weaponNum, weapon = sourceXPlayer.getWeapon(itemName)

			if targetXPlayer.hasWeapon(itemName) then
				local _, weaponObject = ESX.GetWeapon(itemName)

				if weaponObject.ammo then
					local ammoLabel = weaponObject.ammo.label

					if weapon.ammo >= itemCount then
						sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
						targetXPlayer.addWeaponAmmo(itemName, itemCount)

						sourceXPlayer.showNotification(_U('gave_weapon_ammo', itemCount, ammoLabel, weapon.label, targetXPlayer.name))
						targetXPlayer.showNotification(_U('received_weapon_ammo', itemCount, ammoLabel, weapon.label, sourceXPlayer.name))
					end
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_noweapon', targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_weapon_noweapon', sourceXPlayer.name, weapon.label))
			end
		end
	end
end)

RegisterNetEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(type, itemName, itemCount)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(source)

	if type == 'item_standard' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_quantity'))
		else
			local xItem = xPlayer.getInventoryItem(itemName)

			if (itemCount > xItem.count or xItem.count < 1) then
				xPlayer.showNotification(_U('imp_invalid_quantity'))
			else
				xPlayer.removeInventoryItem(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~b~%s~s~]'):format(xItem.label, itemCount)
				ESX.CreatePickup('item_standard', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_standard', itemCount, xItem.label))
			end
		end
	elseif type == 'item_account' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_amount'))
		else
			local account = xPlayer.getAccount(itemName)

			if (itemCount > account.money or account.money < 1) then
				xPlayer.showNotification(_U('imp_invalid_amount'))
			else
				xPlayer.removeAccountMoney(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(account.label, _U('locale_currency', ESX.Math.GroupDigits(itemCount)))
				ESX.CreatePickup('item_account', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_account', ESX.Math.GroupDigits(itemCount), string.lower(account.label)))
			end
		end
	elseif type == 'item_weapon' then
		itemName = string.upper(itemName)

		if xPlayer.hasWeapon(itemName) then
			local _, weapon = xPlayer.getWeapon(itemName)
			local _, weaponObject = ESX.GetWeapon(itemName)
			local components, pickupLabel = ESX.Table.Clone(weapon.components)
			xPlayer.removeWeapon(itemName)

			if weaponObject.ammo and weapon.ammo > 0 then
				local ammoLabel = weaponObject.ammo.label
				pickupLabel = ('~y~%s~s~ [~g~%s~s~ %s]'):format(weapon.label, weapon.ammo, ammoLabel)
				xPlayer.showNotification(_U('threw_weapon_ammo', weapon.label, weapon.ammo, ammoLabel))
			else
				pickupLabel = ('~y~%s~s~'):format(weapon.label)
				xPlayer.showNotification(_U('threw_weapon', weapon.label))
			end

			ESX.CreatePickup('item_weapon', itemName, weapon.ammo, pickupLabel, playerId, components, weapon.tintIndex)
		end
	end
end)

RegisterNetEvent('esx:useItem')
AddEventHandler('esx:useItem', function(itemName)
	local xPlayer = ESX.GetPlayerFromId(source)
	local count = xPlayer.getInventoryItem(itemName).count

	if count > 0 then
		ESX.UseItem(source, itemName)
	else
		xPlayer.showNotification(_U('act_imp'))
	end
end)

RegisterNetEvent('esx:onPickup')
AddEventHandler('esx:onPickup', function(pickupId)
	local pickup, xPlayer, success = ESX.Pickups[pickupId], ESX.GetPlayerFromId(source)

	if pickup then
		if pickup.type == 'item_standard' then
			if xPlayer.canCarryItem(pickup.name, pickup.count) then
				xPlayer.addInventoryItem(pickup.name, pickup.count)
				success = true
			else
				xPlayer.showNotification(_U('threw_cannot_pickup'))
			end
		elseif pickup.type == 'item_account' then
			success = true
			xPlayer.addAccountMoney(pickup.name, pickup.count)
		elseif pickup.type == 'item_weapon' then
			if xPlayer.hasWeapon(pickup.name) then
				xPlayer.showNotification(_U('threw_weapon_already'))
			else
				success = true
				xPlayer.addWeapon(pickup.name, pickup.count)
				xPlayer.setWeaponTint(pickup.name, pickup.tintIndex)

				for k,v in ipairs(pickup.components) do
					xPlayer.addWeaponComponent(pickup.name, v)
				end
			end
		end

		if success then
			ESX.Pickups[pickupId] = nil
			TriggerClientEvent('esx:removePickup', -1, pickupId)
		end
	end
end)

ESX.RegisterServerCallback('esx:spawnVehicle', function(playerId, cb, model, coords, heading)
	local entityHandle = Citizen.InvokeNative(GetHashKey('CREATE_AUTOMOBILE'), model, coords, heading)
	cb(NetworkGetNetworkIdFromEntity(entityHandle))
end)

ESX.StartDBSync()
ESX.StartPayCheck()