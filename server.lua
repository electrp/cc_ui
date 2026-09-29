local basalt = require("basalt")
local sp = require("stock_processing")


local config = {
    -- generate a random hostname if ones not set
    hostname = tostring(math.random(999999)),
    pulse_timer = 15, -- in seconds
}
local stock_data = {}

-- safety to ensure we aren't hosting
rednet.unhost()

function read_config()
    if fs.exists("vault.cfg") then
        local f = fs.open("vault.cfg", "r")
        config = textutils.deserializeJSON(f.readAll())
        f.close()
    end
end

function save_config()
    f.open("vault.cfg", "w")
    f.write(textutils.serializeJSON(config))
    f.close()
end

function start()
    read_config()

    local success, result = pcall(function() 
        rednet.host("vault", config.hostname)
    end)
    if not success then
        print("Hostname is already in use. Please choose another one in \"vault.cfg\"!")
        os.exit(1)
    end
    
    stock_data = sp.process_all()
    os.startTimer(config.pulse_timer)
end

local handle_command = {
    ["ping"] = function(client) 
        rednet.send(client, "pong", "vault")
    end,

    ["vault state"] = function(client)
        rednet.send(client, stock_data, "vault")
    end
}

function stop()
    save_config()
end

start()
print("Vault online. Hosting under \"" .. config.hostname .. "\"!")

while true do 
    local event, p1, p2, p3, p4 = os.pullEvent()
    if event == "timer" then
        stock_data = sp.process_all()
        rednet.broadcast("vault tick", "vault")
        os.startTimer(config.pulse_timer)
    elseif event == "rednet_message" and p3 == "vault" then
        sender = p1
        message = p2
        local handler = handle_command[message]
        if handler == nil then
            rednet.send(client, "unknown command", "vault")
        end
        handler(sender)
    end
end
