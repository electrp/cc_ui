local md5 = require("md5")

local sp = {
}

if not fs.exists("stock_modifier.lua") then
    local f = fs.open("stock_modifier.lua", "w")
    f.write(
[[
local mod = {}

mod.modify_inventory = function(name, inv)
    return name, inv
end

return mod
]]
    )
    f.close()
end
sp.overlay = dofile("stock_modifier.lua")

local metadata_options = { 
    ["Pool"] = {data = "pool"},
    ["Max Stacks"] = {data = "max_stacks"}
}

local default_metadata = {
    pool = nil,
    max_stacks = nil,
    exists = true
}

sp.hash_item = function(item)
    -- We erase but save the count
    local count = item.count
    item.count = nil
    -- This seems really slow to reserialize this, but its easy 
    local item_string = textutils.serialize(item)
    local hash = md5.digest(item_string)
    -- reapply count
    item.count = count
    return hash
end

sp.process_inventory = function(table)
    out = {
        meta = {},
        items = {}
    }

    for i, value in ipairs(table) do
        -- renamed
        if value.name == "minecraft:stick" then
            local k, v = value.displayName:match("(%w+)=(%w+)")
            if k then
                out.meta[k] = v
            end
        end 
        value.meta_item = true

        local hash = sp.hash_item(value)
        out.items[hash] = value
    end
    
    return out
end

sp.process_inventory_string = function(response_string)
    return sp.process_inventory(textutils.unserializeJson(response_string))
end


-- todo later
-- sp.make_inventory_pool= function(inventories)
-- --     if #list == 1 then
-- --         return sp.process_inventory(list[1])
-- --     elseif #list < 1 then
-- --         return {}
-- --     end

-- --     local out = sp.process_inventory(list[1])
-- --     out.metas[1] = out.meta
-- --     out.meta = nil

-- --     for i=2, #list do
-- --         local p = sp.process_inventory(list[i])
-- --         out.metas[i] = p.metas

-- --         for hash, item in p do
-- --             local s_item = out[hash]
-- --             if s_item ~= nil then
-- --                 s_item.count = s_item.count + item.count
-- --             else
-- --                 out[hash] = item
-- --             end
-- --         end
-- --     end

-- --     return out

--     for hash, v
-- end


sp.process_all = function()
    local tickers = { peripheral.find("Create_StockTicker") } 
    local out = {}
    -- use parallel to do this a lot faster, in chunks of 32
    -- stock tickers take around a tick to report their stock at minimum, this queues 
    -- them to happen a lot faster
    for i = 1, #tickers, 32 do
        local funcs = {}
        for j = 1, math.min(#tickers - i + 1, 32) do
            value = tickers[j + i - 1]
            funcs[j] = function() 
                local inv = sp.process_inventory(tickers[i + j - 1].stock(true))
                inv.meta.name, inv = sp.overlay.modify_inventory(inv.meta.name, inv)
                if inv and inv.meta and inv.meta.name then
                    out[inv.meta.name] = inv
                else
                    out[i + j - 1] = inv
                end
            end
        end
        parallel.waitForAll(table.unpack(funcs))
    end
    return out
    -- apply settings overlay
end

return sp