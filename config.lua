Config = {}
Config.Locale = 'en'

Config.Accounts = {
	bank = _U('account_bank'),
	black_money = _U('account_black_money'),
	money = _U('account_money')
}

Config.StartingAccountMoney = {bank = 5000, money = 1000}
Config.MaxWeight = 50   -- the max inventory weight without backpack
Config.PaycheckInterval = 7 * 60000
Config.EnableDebug = false

Config.IncompatibleResourcesToStop = {
	['essentialmode'] = 'ES for short, the performance heavy RP framework no one uses - and source for the random unwa' ..
	'nted ZAP ads you\'re seeing. Author of an invalid ESX DMCA takedown, claiming he wanted "the best for the community"',
	['es_admin2'] = 'Administration tool for the ancient ES framework that wont work with ESX',
	['esplugin_mysql'] = 'MySQL "plugin" for the ancient ES framework that has a SQL injection vulnerability',
	['es_ui'] = 'Money HUD for ES',
	['spawnmanager'] = 'Default resource that takes care of spawning players, ESX does this already',
	['mapmanager'] = 'Default resource that was required by spawnmanager, but neither are used',
	['basic-gamemode'] = 'Resource that is solely for choosing the default game type',
	['fivem'] = 'Resource that is solely for choosing the default game type, which only dictates spawn points',
	['fivem-map-hipster'] = 'Default spawn locations for mapmanager',
	['fivem-map-skater'] = 'Default spawn locations for mapmanager',
	['baseevents'] = 'Default resource for handling death events poorly, ESX does this already'
}