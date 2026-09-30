local basalt = require("basalt")
local sp = require("stock_processing")

config = {
    -- Time before a request is retried
    retry_timer = 3,
    hostname = nil
}

function read_config()
    if fs.exists("vault_ui.cfg") then
        local f = fs.open("vault_ui.cfg", "r")
        config = textutils.unserializeJSON(f.readAll())
        f.close()
    end
end

function save_config()
    f = fs.open("vault_ui.cfg", "w")
    f.write(textutils.serializeJSON(config))
    f.close()
end

read_config()
peripheral.find("modem", rednet.open)

local main = basalt.getMainFrame()

-- states
local navigation = basalt.state({})
local connection_status = basalt.state("...")
local connection_status_color = basalt.state(colors.gray)

-- page nav logic
local content_frame
function push_page(frame_function, title)
    local n = navigation:get()
    if #n > 0 then
        n[#n].frame.visible = false
    end
    local outer = content_frame:addFrame({
        width = basalt.fill(),
        height = basalt.fill()
    })
    frame_function(outer)
    n[#n+ 1] = { title = title, frame = outer}
    navigation:set(n)
end
function pop_page()
    local n = navigation:get()
    if #n <= 1 then
        return
    end
    n[#n].frame.visible = false
    n[#n] = nil
    n[#n].frame.visible = true
    navigation:set(n)
end

function add_vault_display(frame)
    local scroll = frame:addColumn({
        scrollble = true,
        scrollbar = "auto",
        width = basalt.fill(),
        height = basalt.fill()
    })
    
    local stocks = sp.process_all()
    for name, value in pairs(stocks) do
        local row = scroll:addRow({
            height = 1
        })
        local button = row:addButton({
            height = 1,
            width = basalt.fill(),
            justification = "left"
        })
        local percent = row:addLabel({
            width = 2,
            height = 1,
            text = "50",
            justification = "center"
        })
        if type(name) == "number" then
            button:setText("LOST: " .. tostring(name))
        else
            button:setText(name)
        end
    end
end

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

function set_hostname(hostname)
    config.hostname = hostname
    connected_computer = nil
    save_config()
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

function make_connection_dialog(frame)
    local a = frame:addColumn({
        width = basalt.fill(),
        height = 2,
    })
    a:addLabel({
        text = "Server Hostname"
    })
    local b = a:addRow({
        width = basalt.fill(),
        height = 1
    })

    -- Connection dialog
    local input = b:addInput({
        width = basalt.fill(),
        height = 1,
        text = config.hostname
    }):onEnter(function(self)
        set_hostname(self.text)
    end)
    b:addButton({
        text = "Connect",
        width = 7,
        height = 1
    }):onClick(function(self, mb, x, y)
        set_hostname(input.text)
    end)
end

function make_home(frame)
    local v = frame:addColumn({height = basalt.fill(), width = basalt.fill()})
    make_connection_dialog(v)
    v:addButton({ text = "Vault Display" , width = basalt.fill(), height = basalt.auto() })
    v:addButton({ text = "Vault Display" , width = basalt.fill(), height = basalt.auto() })
    v:addButton({ text = "Vault Display" , width = basalt.fill(), height = basalt.auto() })
    v:addButton({ text = "Vault Display" , width = basalt.fill(), height = basalt.auto() })
end


-- Main program structure
local a = main:addColumn({
    width = basalt.fill(),
    height = basalt.fill(),
})

local aa = a:addColumn({
    width = basalt.fill(),
    height = basalt.fill(),
})

local navigator = aa:addLabel({
    width = basalt.fill(),
    height = basalt.auto(),
    text = navigation:map(function(value)
        out = ""
        for i = 1, #value do
            out = out .. "> " .. value[i].title .. " " 
        end
        return out
    end)
})
navigator:onClick(function(self, mouseButton, x, y)
    pop_page()
end)

content_frame = aa:addFrame({
    width = basalt.fill(),
    height = basalt.fill()
})

push_page(make_home, "Home")

-- whole bottom bar
local bottom = a:addRow({
    width = basalt.fill(),
    height = 1,
})
-- just customizable statuses
local status = bottom:addRow({
    width = basalt.fill()
})

-- connection indicator
local connected_computer = nil
local pulse_timer = nil

local connection_indicator = status:addLabel({
    text = connection_status:map(function(value) return value end),
    width = 3,
    background = connection_status_color:map(function(value) return value end),
    align = "center",
})

-- settings
bottom:addButton({
    text = "@",
    width = 1,
    height = 1,
    align = "right",
    background = colors.blue
})

-- update connection


-- add_vault_display(main)

basalt.run()