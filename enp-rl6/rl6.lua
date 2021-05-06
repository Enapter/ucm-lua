-- Copyright 2021 Enapter

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Set default values for relays during first run (Open)
for relay = 1,6,1 do
    relay_status, result = storage.read("r"..tostring(relay))
    if result ~= 0 then
        enapter.log("Writing default value 0 for r" .. relay)
        storage.write("r"..tostring(relay), "Open")
    end
end

-- Set default behaviour on connection lost during first run: 
-- Respect - respect the state (default) 
-- Close - all closed,
-- Open - all open
on_disconnect, result = storage.read("on_disconnect")
if result ~= 0 or
    on_disconnect ~= "Open" or 
        on_disconnect ~= "Close" or
            on_disconnect ~= "Respect" then
                storage.write("on_disconnect", "Respect")
end

function restore_state ()
    enapter.log("Restore relay state")
    for relay = 1,6,1 do
        relay_status, result = storage.read("r"..tostring(relay))
        if result == 0 then
            if relay_status == "Close" then 
                if rl6.close(relay) then
                    enapter.log("Relay " .. tostring(relay) .. " close" )
                end
            else
                if rl6.open(relay) then
                    enapter.log("Relay " .. tostring(relay) .. " open" )
                end
            end
        end
    end
end

-- Set default behaviour on boot: 
-- Respect - respect the state, 
-- Close - all closed, 
-- Open - all open (default)
on_boot, result = storage.read("on_boot")
if  result ~= 0 or 
    on_boot ~= "Open" or
        on_boot ~= "Close" or 
            on_boot ~= "Respect" then
                storage.write("on_boot", "Open")
                enapter.log("Can't read on_boot state. Open all relays and set on_boot to Open.")
                rl6.open_all()
else
    if on_boot == "Respect" then 
        enapter.log("Restore last relays state on boot")
        restore_state()
    elseif on_boot == "Close" then
        enapter.log("Close all relays on boot")
        rl6.close_all()
    elseif on_boot == "Open" then
        enapter.log("Open all relays on boot")
        rl6.open_all()
    end
end

cloud.on_connection_status_changed (function (status)
    if status then 
        restore_state()
    else 
        on_disconnect, result = storage.read("on_disconnect")
        if result == 0 then
            if on_disconnect == "Open" then 
                rl6.open_all()
            elseif on_disconnect == "Close" then
                rl6.close_all()
            elseif on_disconnect == "Respect" then
            end
        else
            rl6.open_all()
        end
    end
end)

function registration()
    enapter:send_registration({ vendor = "Enapter", model = "ENP-RL6" })
end

function telemetry()
    local telemetry = {}

    telemetry["r1"] = rl6.get(1)
    telemetry["r2"] = rl6.get(2)
    telemetry["r3"] = rl6.get(3)
    telemetry["r4"] = rl6.get(4)
    telemetry["r5"] = rl6.get(5)
    telemetry["r6"] = rl6.get(6)
    
    data, result = storage.read("on_boot")
    if result then telemetry["on_boot"] = data end

    data, result = storage.read("on_disconnect")
    if result then telemetry["on_disconnect"] = data end

    enapter:send_telemetry(telemetry)
end

enapter.register_command_handler("open", function (ctx, args)
    if args and args["id"] ~= nil then 
        id = math.floor(args["id"])
        enapter.log("Received open command for relay " .. id)
        if rl6.get(id) == true then
          local result = rl6.open(id) 
          if result == 0 then
              storage.write("r"..tostring(id), "0")
              enapter.log("Relay " .. id .. " opened")
          else
              enapter.log("Error opening relay " .. id)
              ctx.error(cloud.err_to_str(result))
          end
        end
    else
        enapter.log("Wrong arguments for open relay command")
        ctx.error("Wrong arguments for open relay command")
    end  
end)

enapter.register_command_handler("close", function (ctx, args)
    if args and args["id"] ~= nil then 
        id = math.floor(args["id"])
        enapter.log("Received close command for relay " .. id)
        if rl6.get(id) == false then 
          local result = rl6.close(id)
          if result == 0 then
            storage.write("r"..tostring(id), "1")
            enapter.log("Relay " .. id .. " closed")
          else
            enapter.log("Error closing relay " .. id)
            ctx.error(cloud.err_to_str(result))
          end
        end
    else
        enapter.log("Wrong arguments for close relay command")
        ctx.error("Wrong arguments for close relay command")
    end 
end)

enapter.register_command_handler("impulse", function (ctx, args)
    if args and args["id"] ~= nil and args["time"] ~= nil then 
        id = math.floor(args["id"])
        period = math.floor(args["time"])
        enapter.log("Received impulse command for relay " .. id .. " period " .. period .. " ms")
        local result = rl6.impulse(id, period)
        if result == 0 then
            enapter.log("Relay " .. id .. " impulsed for period " .. period .. " ms")
        else
            enapter.log("Error impulsing relay " .. id .. " for period " .. period .. " ms")
            ctx.error(err_to_str(result))
        end
    else
        enapter.log("Wrong arguments for impulse relay command")
        ctx.error("Wrong arguments for impulse relay command")
    end 
end)

enapter.register_command_handler("toggle", function (ctx, args)
    if args and args["id"] ~= nil then 
        id = math.floor(args["id"])
        enapter.log("Received toggle command for relay " .. id)
        if rl6.get(id) == true then 
            local result = rl6.open(id)
            if result == 0 then
                storage.write("r"..tostring(id), "0")
                enapter.log("Relay " .. id .. " opened")
            else
                enapter.log("Error toggle/open relay " .. id)
                ctx.error(err_to_str(result))
            end
        else
            local result = rl6.close(id)
            if result == 0 then
                storage.write("r"..tostring(id), "1")
                enapter.log("Relay " .. id .. " closed")
            else
                enapter.log("Error toggle/close relay " .. id)
                ctx.error(err_to_str(result))
            end
        end
    else
        enapter.log("Wrong arguments for open relay command")
        ctx.error("Wrong arguments for toggle relay command")
    end  
end)

enapter.register_command_handler("set", function (ctx, args)
    if args then
        param = args["param"]
        value = args["value"]
        if param == "on_boot" then
            storage.write("on_boot", value)
            enapter.log("Set on_boot to " .. value)
            ctx.log("Set on_boot to " .. value)
        end
        if param == "on_disconnect" then
            storage.write("on_disconnect", value)
            enapter.log("Set on_disconnect to " .. value)
            ctx.log("Set on_disconnect to " .. value)
        end
    else
        enapter.log("Wrong arguments for set command")
        ctx.error("Wrong arguments for set command")
    end 
end)

scheduler.add(10000, registration)
scheduler.add(1000, telemetry)