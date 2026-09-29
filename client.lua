local args = { ... }

rednet.open(peripheral.find("modem"))


local handle = {
    ["ping"] = function()
        local id = { rednet.lookup("vault", args[2]) }
        rednet.send(id[1], "ping", "vault")
        local id, message rednet.recieve("vault")
        print(message)
    end
}

if args[1] then
    if handle[args[1]] then
        handle[args[1]]()
    end
end