function RFP.LOCK(idBinding, strCommand)
	print("--proxy lock--")

	LockControl("lock")
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
    local lockCode = Properties["Lock Code"]

	local switchServiceCall = {
		domain = "lock",
		service = service,

		service_data = {},

		target = {
			entity_id = EntityID
		}
	}

    if lockCode ~= nil and lockCode ~= "" then
        switchServiceCall.service_data = {
            code = lockCode
        }
    end

	local tParams = {
		JSON = JSON:encode(switchServiceCall)
	}

	C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        print("NO DATA")
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if not Connected then
        C4:SendToProxy(5001, 'LOCK_STATUS_CHANGED', { LOCK_STATUS = LOCK_STATE }, "NOTIFY")
        Connected = true
    end

    if attributes == nil then
        C4:SendToProxy(5001, 'LOCK_STATUS_CHANGED', { LOCK_STATUS = "unknown" }, "NOTIFY")
        return
    end

    if attributes["available"] ~= nil then
        local message = attributes["available"]
        if message == "false" then
            C4:SendToProxy(5001, 'LOCK_STATUS_CHANGED', { LOCK_STATUS = "unknown" }, "NOTIFY")
        end
    end

    if attributes["lock_battery"] ~= nil then
        local message = attributes["lock_battery"]

        local batteryLevel = tonumber(message)
        local batteryString = ""
        if batteryLevel > 50 then
            batteryString = "normal"
        elseif batteryLevel > 25 then
            batteryString = "warning"
        else
            batteryString = "critical"
        end

        C4:SendToProxy(5001, 'BATTERY_STATUS_CHANGED', { BATTERY_STATUS = batteryString }, "NOTIFY")
    end

    if state ~= nil then
        C4:SendToProxy(5001, 'LOCK_STATUS_CHANGED', { LOCK_STATUS = state }, "NOTIFY")
        LOCK_STATE = state
    end
end