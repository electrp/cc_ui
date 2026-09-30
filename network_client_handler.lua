-- networking
local network_queue = {
    first = 0,
    last = -1,
    co = nil
}
function network_queue.push(self, fn)
    self[network_queue.last + 1] = fn
    self.last = self.last + 1
    if not co or coroutine.status(co) == "dead" then
        basalt.schedule(function()
            self:continue()
        end)
    end
end
function network_queue:continue()
    if self.first <= self.last then
        self[self.first]()
        self.first = self.first + 1
    end
end
function try_connect()
    network_queue:push(function()
        connected_computer = rednet.lookup("vault", config.hostname) 
        if connected_computer then
            connection_status:set("...")
            connection_status_color:set(colors.green)
        else
            connection_status:set("!!!")
            connection_status_color:set(colors.red)
        end
    end)
end
function set_hostname(hostname)
    config.hostname = hostname
    connected_computer = nil
    save_config()
    try_connect()
end


-- new
require("basalt")

local network_handler = {
    id = nil
    hostname = nil

    connected = basalt.state(false)
    index = 0
    pulse_timer = nil
}
function network_handler:start(hostname)
    local connection_index = self.index + 1
    self.index = connection_index

    self.hostname:set(hostname)
    id = rednet.lookup("vault", hostname)
    connected.set(id ~= nil)

    return true
end