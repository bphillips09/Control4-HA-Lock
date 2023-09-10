--Globals
EC = {}
OPC = {}
RFP = {}
REQ = {}
EntityID = Properties["Entity ID"]
Connected = false

JSON = require("module.json")
require('commands')

function HandlerDebug(init, tParams, args)
	if (not DEBUGPRINT) then
		return
	end

	if (type(init) ~= 'table') then
		return
	end

	local output = init

	if (type(tParams) == 'table' and next(tParams) ~= nil) then
		table.insert(output, '----PARAMS----')
		for k, v in pairs(tParams) do
			local line = tostring(k) .. ' = ' .. tostring(v)
			table.insert(output, line)
		end
	end

	if (type(args) == 'table' and next(args) ~= nil) then
		table.insert(output, '----ARGS----')
		for k, v in pairs(args) do
			local line = tostring(k) .. ' = ' .. tostring(v)
			table.insert(output, line)
		end
	end

	local t, ms
	if (C4.GetTime) then
		t = C4:GetTime()
		ms = '.' .. tostring(t % 1000)
		t = math.floor(t / 1000)
	else
		t = os.time()
		ms = ''
	end
	local s = os.date('%x %X') .. ms

	table.insert(output, 1, '-->  ' .. s)
	table.insert(output, '<--')
	output = table.concat(output, '\r\n')
	print(output)
	C4:DebugLog(output)
end

function ExecuteCommand(strCommand, tParams)
	tParams = tParams or {}
	local init = {
		'ExecuteCommand: ' .. strCommand,
	}
	HandlerDebug(init, tParams)

	if (strCommand == 'LUA_ACTION') then
		if (tParams.ACTION) then
			strCommand = tParams.ACTION
			tParams.ACTION = nil
		end
	end

	strCommand = string.gsub(strCommand, '%s+', '_')

	local success, ret

	if (EC and EC[strCommand] and type(EC[strCommand]) == 'function') then
		success, ret = pcall(EC[strCommand], tParams)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		print('ExecuteCommand error: ', ret, strCommand)
	end
end

function OnPropertyChanged(strProperty)
	local value = Properties[strProperty]
	if (type(value) ~= 'string') then
		value = ''
	end

	local init = {
		'OnPropertyChanged: ' .. strProperty,
		value,
	}
	HandlerDebug(init)

	strProperty = string.gsub(strProperty, '%s+', '_')

	local success, ret

	if (OPC and OPC[strProperty] and type(OPC[strProperty]) == 'function') then
		success, ret = pcall(OPC[strProperty], value)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		print('OnPropertyChanged error: ', ret, strProperty, value)
	end
end

function ReceivedFromProxy(idBinding, strCommand, tParams)
	strCommand = strCommand or ''
	tParams = tParams or {}
	local args = {}
	if (tParams.ARGS) then
		local parsedArgs = C4:ParseXml(tParams.ARGS)
		for _, v in pairs(parsedArgs.ChildNodes) do
			args[v.Attributes.name] = v.Value
		end
		tParams.ARGS = nil
	end

	local init = {
		'ReceivedFromProxy: ' .. idBinding, strCommand,
	}
	HandlerDebug(init, tParams, args)

	local success, ret

	if (RFP and RFP[strCommand] and type(RFP[strCommand]) == 'function') then
		success, ret = pcall(RFP[strCommand], idBinding, strCommand, tParams, args)
	elseif (RFP and RFP[idBinding] and type(RFP[idBinding]) == 'function') then
		success, ret = pcall(RFP[idBinding], idBinding, strCommand, tParams, args)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		print('ReceivedFromProxy error: ', ret, idBinding, strCommand)
	end
end

function OnDriverInit()
	print("--driver init--")
end

function OnDriverLateInit()
	print("--driver late init--")

	for property, _ in pairs(Properties) do
		OnPropertyChanged(property)
	end

	LOCK_STATE = "unknown"
end

function OnDriverDestroyed()
	print("--driver destroyed--")
end

function UIRequest(strCommand, tParams)
	local success, ret

	if (REQ and REQ[strCommand] and type(REQ[strCommand]) == 'function') then
		success, ret = pcall(REQ[strCommand], strCommand, tParams)
	end

	if (success == true) then
		return (ret)
	elseif (success == false) then
		print('UIRequest error: ', ret, strCommand)
	end
end

function OPC.Entity_ID(value)
	EntityID = value

	local tParams = {
		entity = value
	}

	C4:SendToProxy(999, "HA_GET_STATE", tParams)
end

function OPC.Driver_Version(value)
	local version = C4:GetDriverConfigInfo('version')
	C4:UpdateProperty('Driver Version', version)
end

function OPC.Debug_Mode(value)
	if (DebugPrintTimer and DebugPrintTimer.Cancel) then
		DebugPrintTimer = DebugPrintTimer:Cancel()
	end
	DEBUGPRINT = (value == 'On')

	if (DEBUGPRINT) then
		local _timer = function(timer)
			C4:UpdateProperty('Debug Mode', 'Off')
			OnPropertyChanged('Debug Mode')
		end
		DebugPrintTimer = C4:SetTimer(60 * 60 * 1000, _timer)
	end
end

function RFP.LOCK(idBinding, strCommand)
	print("--proxy lock--")

	LockControl("unlock")
end

function RFP.TOGGLE(idBinding, strCommand)
	print("--proxy lock--")

	if LOCK_STATE == "locked" then
		RFP:UNLOCK(strCommand)
	else
		RFP:LOCK(strCommand)
	end

end

function RFP.UNLOCK(idBinding, strCommand)
	print("--proxy unlock--")

	LockControl("unlock")
end

function LockControl(service)
	local switchServiceCall = {
		domain = "lock",
		service = service,

		service_data = {},

		target = {
			entity_id = EntityID
		}
	}

	local tParams = {
		JSON = JSON:encode(switchServiceCall)
	}

	C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end