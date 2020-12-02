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

enapter = cloud.new("dewcsi", "v1")
mb = modbus.new(19200, 8, "E", 1)
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
    enapter:send_registration({ vendor = "CS Instruments", model = "FA 510" })
end

function metrics()
    local telemetry = {}
    local success = false

    local result, data = mb:read_holding(address, 10, 2, 1000)
    if result == OK then
        telemetry["calibration_due"] = todate(data)
        success = true
    end

    local result, data = mb:read_holding(address, 1000, 2, 1000)
    if result == OK then
        telemetry["temperature"] = tofloat(data)
        success = true
    end

    local result, data = mb:read_holding(address, 1006, 2, 1000)
    if result == OK then
        telemetry["dew_point"] = tofloat(data)
        success = true
    end

    local result, data = mb:read_holding(address, 1020, 2, 1000)
    if result == OK then
        telemetry["partial_vapor_pressure"] = tofloat(data) / 1000 -- from hPa to bar
        success = true
    end

    local result, data = mb:read_holding(address, 1022, 2, 1000)
    if result == OK then
        telemetry["atm_dew_point"] = tofloat(data)
        gas_status = tofloat(data) < -60.5
        telemetry["gas_acceptable"] = gas_status
        if gas_status then
            telemetry["status"] = "ok"
        else
            telemetry["status"] = "warning"
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