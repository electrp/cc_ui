local args = { ... }

peripheral.find("modem", rednet.open)

local function parse(v)
    if type(v) == "string" then
        return v
    else
        return textutils.serialize(v, {compact = false})
    end
end

local handle = {
    ["command"] = function()
        local id = { rednet.lookup("vault", args[3]) }
        rednet.send(id[1], args[2], "vault")
        local id, message = rednet.receive("vault")
        print(parse(message))
    end,
    
    ["listen"] = function()
        local id = { rednet.lookup("vault", args[2]) }
        while true do 
            local id, message = rednet.receive("vault")
            print(parse(message))
        end
    end,
}

handle[args[1]]()

