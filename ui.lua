local basalt = require("basalt")
local sp = require("stock_processing")

local main = basalt.getMainFrame()

function add_vault_display(frame)
    local scroll = frame:addColumn({
        scrollble = true,
        scrollbar = "auto",
        width = basalt.fill(),
        height = basalt.fill()
    })
    
    local stocks = sp.process_all()
    for name, value in pairs(stocks) do
        local row = flex:addFrame({
            height = 1
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