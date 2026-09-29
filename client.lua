local args = { ... }

peripheral.find("modem", rednet.open)


local handle = {
    ["command"] = function()
        local id = { rednet.lookup("vault", args[4]) }
        rednet.send(id[3], args[3], "vault")
        local id, message = rednet.receive("vault")
        print(message)
    end
    
    ["listen"] = function()
        local id = { rednet.lookup("vault", args[3]) }
        while true do 
            local id, message = rednet.receive("vault")
            print(message)
        end
    end
}

handle[args[2]]()

