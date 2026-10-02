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
    local table = frame:addTable({
        -- scrollble = true,
        -- scrollbar = "auto",
        width = basalt.fill(),
        height = basalt.fill(),
        columns = { 
            { title = "Name" },
            { title = "Fill", width = 5 }
        }
    })

    table:sortBy(1, false)
    local update_item_table = function() 
        table:clearData()
        local data = vault_state:get()
        if not data then return end

        for name, value in pairs(vault_state:get()) do
            local sname = "??"
            if type(name) == "number" then
                sname = tostring(name)
            else
                sname = name
            end

            local percent = ""
            if value.meta.max_stacks then
                percent = tostring(math.floor(value.slots_used / value.meta.max_stacks * 100))
            end

            table:addRow({sname, percent})
        end
    end
    local unsubscribe = vault_state:subscribe(update_item_table, true)
    
    table:onSelect(function(self, index, row)
        push_page(make_vault_inspector(row[1]), row[1])
    end)

    return function()
        unsubscribe()
    end
end

function item_manage_menu(vault_name, item_name, item_hash)
    return function(frame)
        local item = basalt.computed(function()
            local vault = vault_state:get()[vault_name]
            if not vault then return nil end
            local item = vault.items[item_hash]
            return item
        end)
        local prev_max = item:get().count
        local max_amount = basalt.computed(function()
            if item then 
                return item:get().count 
            else 
                return prev_max 
            end 
        end)
        
        local send_amount = basalt.state(1)
        local a = frame:addColumn({
            width = basalt.fill(),
            height = basalt.fill()
        })

        a:addLabel({
            text = max_amount:map(function(v) if v then return tostring(v) else return "??" end end)
        })

        local text_input = basalt.state("1")
        local input a:addInput({
            width = basalt.fill(),
            height = 1,
            text = tostring(send_amount:get())
        })
        :bind("text", text_input)
        :onChange(function(self)
            local v = tonumber(text_input)
            if v then send_amount:set(sent_amount) end
        end)
        local slider = a:addSlider({
            width = basalt.fill(),
            min = 0,
            max = max_amount,
            value = 1
        })
        :bind("value", send_amount)

        local button = a:addButton({
            text = basalt.computed(function()
                return "Send " .. send_amount:get() 
            end)
        })
        :onClick(function(self, button, x, y)

            pop_page()
        end)
        

    end
end

function make_vault_inspector(vault_name)
    return function (frame)
        local a = frame:addColumn({
            width = basalt.fill(),
            height = basalt.fill(),
        })
        local aa = frame:addRow({
            width = basalt.fill(),
            height = 1,
        })

        local is_online = function()
            return vault_state:get()[vault_name]
        end       
        local online = aa:addLabel({
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
            widh
        })
        local send = aa:addButton({
            height = 1,
            padding = 0,
            text = "Send"
        })

        local item_table = a:addTable({
            width = basalt.fill(),
            height = basalt.fill(),
            columns = {
                {title = "Display"},
                {title = "Count", minWidth = 6, width = 6},
                {title = "Hash", width = 0, visible = false},
            },
        })
        item_table:sortBy(2, false)
        local update_item_table = function() 
            item_table:clearData()
            local data = vault_state:get()[vault_name]
            if not data then return end
            for hash, item in pairs(data.items) do
                item_table:addRow({item.displayName, item.count, hash})
            end
        end
        local unsubscribe_update_table = vault_state:subscribe(update_item_table, true)

        send:onClick(function(self, button, x, y)
            local selected = item_table:getSelectedRow()
            push_page(item_manage_menu(vault_name, selected[1], selected[3]), selected[1])
        end)

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