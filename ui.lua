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
local connected_computer = basalt.state(nil)
local vault_state = basalt.state({})

-- TODO: Testing remove
local f = fs.open("cc_ui/example_inventory.json", "r")
vault_state:set(textutils.unserializeJSON(f.readAll()))
f.close()

-- handle messages
local message_handle = {
    ["vault state response"] = function(data) 
        vault_state:set(data)
    end,
    ["pulse timer"] = function(data)
        pulse_timer:set(data)
    end,
    ["vault tick"] = function(data)
        rednet.send(connected_computer:get(), "vault state", "vault")
    end
}
basalt.schedule(function()
    while true do
        local event, p1, p2, p3 = os.pullEvent("rednet_message")
        if connected_computer:get() and p1 == connected_computer:get() and p3 == "vault" then
            local message = p2
            if message_handle[message.type] then
                message_handle[message.type](message.data)
            end
        end
    end
end)

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
    local cleanup = frame_function(outer)
    n[#n+ 1] = { title = title, frame = outer, cleanup = cleanup }
    navigation:set(n)
end
function pop_page()
    local n = navigation:get()
    if #n <= 1 then
        return
    end
    n[#n].frame.visible = false
    if n[#n].cleanup then
        n[#n].cleanup()
    end
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
    
    for name, value in pairs(vault_state:get()) do
        local row = scroll:addRow({
            height = 1
        })
        local button = row:addLabel({
            height = 1,
            width = basalt.fill(),
            justification = "left"
        })
        local percent = row:addLabel({
            width = 2,
            height = 1,
            text = "??",
            justification = "center"
        })
        if type(name) == "number" then
            button:setText("UNNAMED " .. tostring(name))
        else
            button:setText(name)
        end

        button:onClick(function()
            push_page(make_vault_inspector(name), name)
        end)
    end
end

function make_vault_inspector(vault_name)
    return function (frame)
        local a = frame:addColumn({
            width = basalt.fill(),
            height = basalt.fill(),
        })
        local is_online = function()
            return vault_state:get()[vault_name]
        end       
        local online = a:addLabel({
            text = basalt.computed(function()
                if is_online() then return "Online"
                else return "Offline"
                end
            end),
            background = basalt.computed(function()
                if is_online() then return colors.green
                else return colors.red
                end
            end),
        })

        local item_table = a:addTable({
            width = basalt.fill(),
            height = basalt.fill(),
            columns = {
                {title = "Display"},
                {title = "Count", minWidth = 6},
            },
        })
        item_table:sortBy(2, false)
        local update_item_table = function() 
            item_table:clearData()
            local data = vault_state:get()[vault_name]
            if not data then return end
            for i, item in ipairs(data) do
                item_table:addRow({item.displayName, item.count})
            end
        end
        local unsubscribe_update_table = vault_state:subscribe(update_item_table, true)
        

        -- cleanup function
        return function()
            unsubscribe_update_table()
        end
    end
end

function try_connect()
    connected_computer:set(rednet.lookup("vault", config.hostname))
end
function set_hostname(hostname)
    config.hostname = hostname
    connected_computer:set(nil)
    save_config()
    try_connect()
    if connected_computer:get() then
        rednet.send(connected_computer:get(), "get pulse timer", "vault")
        rednet.send(connected_computer:get(), "vault state", "vault")
    end
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
    v:addButton({ text = "Vaults" , width = basalt.fill(), height = basalt.auto() })
    :onClick(function(self, button, x, y) 
        push_page(add_vault_display, "Vaults")
    end)
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

-- settings
bottom:addButton({
    text = "@",
    width = 1,
    height = 1,
    align = "right",
    background = basalt.computed(function()
        if connected_computer:get() and vault_state:get() then
            return colors.blue
        else
            return colors.red
        end
    end)
})

-- update connection
basalt.schedule(function()
    try_connect()
end)

-- add_vault_display(main)
basalt.run()