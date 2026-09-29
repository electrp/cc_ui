local basalt = require("basalt")
local sp = require("stock_processing")

local main = basalt.getMainFrame()

function add_vault_display(frame)
    local scroll = frame:addScrollFrame({})
    scroll:fillParent()
    

    local acc = 1
    local stocks = sp.process_all()
    for name, value in pairs(stocks) do
        local frame = frame:addFrame()
        local button = frame:addButton({
            height = 1,
            width = scroll.width - 4,
            y = acc
        })
        acc = acc + 1
        if type(name) == "number" then
            button:setText("LOST: " .. tostring(name))
        else
            button:setText(name)
        end
    end
end

add_vault_display(main)

basalt.run()