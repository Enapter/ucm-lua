json = require("json")
connection = http.client ({timeout = 10})

temperature = 0
humidity = 0

-- Check README.md
cityid = "YOUR_CITY_ID"
appid = "YOUR_OPENWEATHERMAP_API_KEY"

function weather()
  result, error = connection:get("http://api.openweathermap.org/data/2.5/weather?units=metric&id=" .. cityid .. "&appid=" .. appid)

  if result.code == 200 then
    t = {}
    t = json.decode(result.body)
    enapter.log("Temperature " .. tostring(t["main"]["temp"]))
    enapter.log("Humidity " .. tostring(t["main"]["humidity"]))
    temperature = tonumber(t["main"]["temp"])
    humidity = tonumber(t["main"]["humidity"])
  end
end

function telemetry()
  local telemetry = {}
  
  telemetry["temperature"] = temperature
  telemetry["humidity"] = humidity
  
  if temperature < 3 then
    telemetry["status"] = "Risk of Ice"
  else
    telemetry["status"] = "OK"
  end

  enapter.send_telemetry(telemetry)
end

weather()

-- Send telemetry every 1s
scheduler.add(1000, telemetry)
-- Update weather every 1200s
scheduler.add(1200000, weather)

