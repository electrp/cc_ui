local basalt = require("basalt")
local sp = require("stock_processing")

local main = basalt.getMainFrame()

function add_vault_display(frame)
    local scroll = frame:addFrame({
        scrollable = true,
        scrollbar = "auto"
    })
    scroll:fillParent()
    local flex = scroll:addFlex({
        direction = "row"
    })
    
    local stocks = sp.process_all()
    for name, value in pairs(stocks) do
        local row = flex:addRow({
            height = 1,
            width = basalt.fill(),
            gap = 1,
        })
        local button = row:addButton({
            height = 1,
            width = basalt.fill()
        })
        local percent = row:addLabel({
            width = 4
            height = 1
            text = "50"
        })
        if type(name) == "number" then
            button:setText("LOST: " .. tostring(name))
        else
            button:setText(name)
        end
    end
end

add_vault_display(main)

basalt.run()