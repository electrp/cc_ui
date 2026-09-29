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

local tabs = main:addTabContrtol({})
local vaults = tabs:addTab("Vaults")
local settings = tabs:addTab("Settings")

-- add_vault_display(main)

basalt.run()