--[[
Copyright 2020 Enapter, Tatyana Yugaj <tyugaj@enapter.com>
Licensed under the Apache License, Version 2.0 (the “License”);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
“AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
--]]

enapter = cloud.new("h2xiq", "v1")
mb = modbus.new(38400, 8, "N", 2)
address = 1

function tofloat(register)
    raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
    return string.unpack(">f", raw_str)
end

function todate(register)
    raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
    return string.unpack(">I4", raw_str)
end

function registration()
    enapter:send_registration({ vendor = "Crowcon", model = "XgardIQ" })
end

function metrics()
    local telemetry = {}
    local success = false

    local result, data = mb:read_holding(address, 99, 1, 1000)
    if result == OK then
        if data[1] == 0 then
            telemetry["sensor_ready"] = "undetected"
            success = true
        elseif data[1] == 1 then
            telemetry["sensor_ready"] = "invalid"
            success = true
        elseif data[1] == 2 then
            telemetry["sensor_ready"] = "initializing"
            success = true
        elseif data[1] == 3 then
            telemetry["sensor_ready"] = "ready"
            success = true
        end
    end

    local result, data = mb:read_holding(address, 106, 2, 1000)
    if result == OK then
        telemetry["calibration_due"] = todate(data)
        success = true
    end

    local result, data = mb:read_holding(address, 111, 2, 1000)
    if result == OK then
        telemetry["last_calibration"] = todate(data) 
        success = true
    end

    local result, data = mb:read_holding(address, 301, 2, 1000)
    if result == OK then
        telemetry["h2_concentration"] = tofloat(data)
        success = true
    end

    local result, data = mb:read_holding(address, 303, 1, 1000)
    if result == OK then
        if data[1] == 0 then
            telemetry["status"] = "ok"
            success = true
        elseif data[1] == 1 then
            telemetry["status"] = "reminder"
            success = true
        elseif data[1] == 2 then
            telemetry["status"] = "warning"
            success = true
        elseif data[1] == 3 then
            telemetry["status"] = "fault"
            success = true
        end
    end

    local result, data = mb:read_holding(address, 304, 1, 1000)
    if result == OK then
        if data[1] == 0 then
            telemetry["alarm1"] = false
            success = true
        else
            telemetry["alarm1"] = true
            success = true
        end
    end

    local result, data = mb:read_holding(address, 305, 1, 1000)
    if result == OK then
        if data[1] == 0 then
            telemetry["alarm2"] = false
            success = true
        else
            telemetry["alarm2"] = true
            success = true
        end
    end

    if success then
        enapter:send_telemetry(telemetry)
    else
        enapter:send_telemetry({ error = modbus.err_to_str(result) })
    end
end

scheduler.add(10000, registration)
scheduler.add(1000, metrics)