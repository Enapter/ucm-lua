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

enapter = cloud.new("o2ucv", "v1")
mb = modbus.new(9600, 8, "N", 1)
address = 254

function tofloat(register)
    local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
    return string.unpack(">f", raw_str)
end

function point_unit_decode(register1, register2)
    local raw_str = string.pack("BB", register2[1]>>8, register2[1]&0xff)

    local point = string.unpack(">I1", string.sub(raw_str,1,1))
    point = math.floor(point / 16)

    return register1[1] / 10^point
end

function relay_check(register)
    local relay1 = (register[1]&2^2 ~= 0)
    local relay2 = (register[1]&2^10 ~= 0)
    return relay1, relay2
end

function registration()
    enapter:send_registration({ vendor = "Sfere", model = "uCv" })
end

function metrics()
    local telemetry = {}
    local success = false

    local result1, data1 = mb:read_holding(address, 1, 1, 1000)
    local result2, data2 = mb:read_holding(address, 2, 1, 1000)
    if (result1 == OK) and (result2 == OK) then
        telemetry["o2_concentration"] = point_unit_decode(data1, data2) 
        success = true
    end

    local errors = {}
    local result, data = mb:read_holding(address, 50, 1, 1000)
    if result == OK then
        if data[1]&2^9 ~= 0  then
            table.insert(errors, "measure_overload") 
        end
        if data[1]&2^8 ~= 0  then
            table.insert(errors, "sensor_break")
        end
        if data[1]&2^6 ~= 0  then
            table.insert(errors, "measure_overrange")
        end
        if data[1]&2^5 ~= 0  then
            table.insert(errors, "cjc_error")
        end
        if data[1]&2^2 ~= 0  then
            table.insert(errors, "calibration_error")
        end
        if data[1]&2^1 ~= 0  then
            table.insert(errors, "offset_error")
        end
        if data[1]&2^0 ~= 0  then
            table.insert(errors, "programming_error")
        end
        telemetry["errors"] = table.unpack(errors)
        success = true
    end

    local result1, data1 = mb:read_holding(address, 99, 1, 1000)
    local result2, data2 = mb:read_holding(address, 100, 1, 1000)
    local gas_acceptable = true
    if (result1 == OK) and (result2 == OK) then
        relay1, relay2 = relay_check(data1)
        relay3, relay4 = relay_check(data2)

        if relay1 or relay2 or relay3 or relay4 then
            gas_acceptable = false
            telemetry["gas_acceptable"] = false
        else
            gas_acceptable = true
            telemetry["gas_acceptable"] = true
        end

        telemetry["relay1"] = relay1
        telemetry["relay2"] = relay2
        telemetry["relay3"] = relay3
        telemetry["relay4"] = relay4

        if #errors ~= 0 then
            telemetry["status"] = "error"
        elseif not gas_acceptable then
            telemetry["status"] = "warning"
        else
            telemetry["status"] = "ok"
        end

        success = true
    end

    if success then
        enapter:send_telemetry(telemetry)
    else
        enapter:send_telemetry({ error = modbus.err_to_str(result) })
    end
end

scheduler.add(10000, registration)
scheduler.add(1000, metrics)