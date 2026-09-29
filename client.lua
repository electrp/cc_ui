local args = { ... }

peripheral.find("modem", rednet.open)


local id = { rednet.lookup("vault", args[3]) }
rednet.send(id[1], args[2], "vault")
local id, message = rednet.receive("vault")
print(message)

