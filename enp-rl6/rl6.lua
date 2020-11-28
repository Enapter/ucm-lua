--[[ 
Copyright 2020 Enapter, Nikolay V. Krasko <nikolay@enapter.com>
Licensed under the Apache License, Version 2.0 (the “License”);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at 
    http://www.apache.org/licenses/LICENSE-2.0 
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
“AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
--]]

enapter = cloud.new("rl6", "v1")

-- set default values for relays 0 (open)
for relay = 1,6,1 do
    result, relay_status = storage.read("r"..tostring(relay))
    if result ~= 0 then
        print ("Writing default value 0 for r",relay)
        storage.write("r"..tostring(relay),"0")
    end
end

-- set default value on connection lost: 3 - respect the state (default), 2 - all closed, 1 - all open
result, on_disconnect = storage.read("on_disconnect")
if result ~= 0 or tonumber(on_disconnect) > 3 then
    storage.write("on_disconnect", "3")
end

function restore_state ()
    print ("Restore relay state")
    for relay = 1,6,1 do
        result, relay_status = storage.read("r"..tostring(relay))
        if result == 0 then
            if relay_status == tostring(1) then 
                if rl6.close(relay) then
                    print ("Relay " .. tostring(relay) .. " close" )
                end
            else
                if rl6.open(relay) then
                    print ("Relay " .. tostring(relay) .. " open" )
                end
            end
        end
    end
end

-- set default value on boot: 3 - respect the state, 2 - all closed, 1 - all open (default)
result, on_boot = storage.read("on_boot")
if result ~= 0 or tonumber(on_boot) > 3 then
    storage.write("on_boot", "1")
    print ("Can't read default on_boot state. Open all relays by default and set on_boot to 1.")
    rl6.set_all(false)
else
    if on_boot == tostring(3) then 
        print ("Restore last relays state on boot")
        restore_state()
    elseif on_boot == tostring(2) then
        print ("Close all relays on boot")
        rl6.set_all(true)
    elseif on_boot == tostring(1) then
        print ("Open all relays on boot")
        rl6.set_all(false)
    end
    
end

cloud.on_status_changed (function (status)
    print ("Connection to Cloud: ", status)

    if status then 
        restore_state()
    else 
        result, on_disconnect = storage.read("on_disconnect")
        if result == 0 then
            if on_disconnect == tostring(1) then 
                print ("Open all relays")
                rl6.set_all(false)
            elseif on_disconnect == tostring(2) then
                print ("Close all relays")
                rl6.set_all(true)
            elseif on_disconnect == tostring(3) then
                print ("Respect last relays state")
            end
        else
            print ("Can't read default settings. Open all relays")
            rl6.set_all(false)
        end
    end
end)

function registration()
    enapter:send_registration({ vendor = "Enapter", model = "ENP-RL6" })
    print ("Time: " .. os.time())
end

function metrics()
    local telemetry = {}
    telemetry["r1"] = rl6.get(1)
    telemetry["r2"] = rl6.get(2)
    telemetry["r3"] = rl6.get(3)
    telemetry["r4"] = rl6.get(4)
    telemetry["r5"] = rl6.get(5)
    telemetry["r6"] = rl6.get(6)
    
    result, data = storage.read("on_boot")
    if result then telemetry["on_boot"] = data end

    result, data = storage.read("on_disconnect")
    if result then telemetry["on_disconnect"] = data end

    enapter:send_telemetry(telemetry)
end

enapter:register_command_handler("open", function (args)
    if args and args["id"] ~= nil then 
        id = math.floor(args["id"])
        print("Received open command for relay " .. id)
        if rl6.get(id) == false then 
            return 0
        else
            if rl6.open(id) == 0 then
                storage.write("r"..tostring(id), "0")
                print("Relay " .. id .. " opened")
                return 0
            else
                print("Error opening relay " .. id)
                return 1
            end
        end
    else
        print("Wrong arguments for open relay command")
        return 1
    end  
end)

enapter:register_command_handler("close", function (args)
    if args and args["id"] ~= nil then 
        id = math.floor(args["id"])
        print("Received close command for relay " .. id)
        if rl6.get(id) == true then 
            return 0
        else
            if rl6.close(id) == 0 then
                storage.write("r"..tostring(id), "1")
                print("Relay " .. id .. " closed")
                return 0
            else
                print("Error closing relay " .. id)
                return 1
            end
        end
    else
        print("Wrong arguments for close relay command")
        return 1
    end 
end)

enapter:register_command_handler("impulse", function (args)
    if args and args["id"] ~= nil and args["time"] ~= nil then 
        id = math.floor(args["id"])
        period = math.floor(args["time"])
        print("Received impulse command for relay " .. id .. " for period " .. period .. " ms")
        if rl6.impulse(id, period) == 0 then
            print("Relay " .. id .. " impulsed for period " .. period .. " ms")
            return 0
        else
            print("Error impulsing relay " .. id .. " for period " .. period .. " ms")
            return 1
        end
    else
        print("Wrong arguments for impulse relay command")
        return 1
    end 
end)


enapter:register_command_handler("set", function (args)
    if args then
        result = 1
        for command, arg in pairs (args) do
            if command == "on_boot" then
                storage.write("on_boot", tostring(arg))
                print ("Set on_boot to " .. tostring(arg))
                result = 0
            end
            if command == "on_disconnect" then
                storage.write("on_disconnect", tostring(arg))
                print ("Set on_disconnect to " .. tostring(arg))
                result = 0
            end
        end
    
        if result ~= 0 then 
            print ("Unkonwn settings")
        end

        return result
    else
        print("Wrong arguments for set command")
        return 1
    end 
end)

scheduler.add(10000, registration)
scheduler.add(1000, metrics)