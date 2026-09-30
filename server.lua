local basalt = require("basalt")
local sp = require("stock_processing")

local server = {}

local config = {
    -- generate a random hostname if ones not set
    hostname = tostring(math.random(999999)),
    pulse_timer = 15, -- in seconds
}

local stock_data = {}
local timer_id = 0

-- safety to ensure we aren't hosting

function read_config()
    if fs.exists("vault.cfg") then
        local f = fs.open("vault.cfg", "r")
        config = textutils.unserializeJSON(f.readAll())
        f.close()
    end
end

function save_config()
    f = fs.open("vault.cfg", "w")
    f.write(textutils.serializeJSON(config))
    f.close()
end

function start()
    peripheral.find("modem", rednet.open)
    rednet.unhost("vault")
    read_config()

    local success, result = pcall(function() 
        rednet.host("vault", config.hostname)
    end)
    if not success then
        print("Hostname is already in use. Please choose another one in \"vault.cfg\"!")
        os.exit(1)
    end
    
    stock_data = sp.process_all()
    timer_id = os.startTimer(config.pulse_timer)
end

local handle_command = {
    ["ping"] = function(client) 
        return {type = "pong"}
    end,

    ["vault state"] = function(client)
       return {type = "vault state response", data = stock_data}
    end,

    ["get pulse timer"] = function(client)
        return {type = "pulse timer", data = config.pulse_timer }
    end
}

function stop()
    save_config()
end

function local_server()
    start()
    print("Vault online. Hosting under \"" .. config.hostname .. "\"!")
    rednet.broadcast({message = "vault online", hostname = config.hostname}, "vault")
    save_config()

    while true do 
        local event, p1, p2, p3, p4 = os.pullEvent()
        if event == "timer" and p1 == timer_id then
            stock_data = sp.process_all()
            rednet.broadcast({type = "vault tick"}, "vault")
            timer_id = os.startTimer(config.pulse_timer)
        elseif event == "rednet_message" and p3 == "vault" then
            sender = p1
            message = p2
            local handler = handle_command[message]
            if handler == nil then
                rednet.send(client, "unknown command", "vault")
            end
            rednet.send(client, handler(sender), "vault")
        end
    end
end