local md5 = require("md5")

-- TODO: change to new format in example_inventory

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

sp.process_inventory = function(table, tempid, item_table)
    out = {
        meta = {},
        items = {},
        slots_used = 0,
    }

    for i, item in ipairs(table) do
        -- renamed
        if item.name == "minecraft:stick" then
            local k, v = item.displayName:match("(%w+)=(%w+)")
            if k then
                out.meta[k] = v
            end
        end 
        item.meta_item = true

        local hash = sp.hash_item(item)
        out.items[hash] = item.count
        local item_store = item_table[hash]
        if not item_store then
            -- this does technically refererence, but this is ok because our item source
            -- is temporary
            item_table[hash] = item
            item_store = item_table[hash]
            item_store.sources_id = {}
            item_store.count = 0
        end
        item_store.sources_id[tempid] = item.count
        item_store.count = item_store.count + item.count

        out.slots_used = out.slots_used + math.ceil(item.count / value.maxCount)
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
    local out = { nodes = {}, items = {} }
    local node_names = {}
    -- use parallel to do this a lot faster, in chunks of 32
    -- stock tickers take around a tick to report their stock at minimum, this queues 
    -- them to happen a lot faster
    for i = 1, #tickers, 32 do
        local funcs = {}
        for j = 1, math.min(#tickers - i + 1, 32) do
            value = tickers[j + i - 1]
            funcs[j] = function() 
                local inv = sp.process_inventory(tickers[i + j - 1].stock(true), i + j - 1, out.items)
                -- modify based on user function
                inv.meta.name, inv = sp.overlay.modify_inventory(inv.meta.name, inv)
                
                if not inv.meta.name then
                    -- use tempid as name if none provided
                    inv.meta.name = tostring(i + j - 1)
                end
                node_names[j + i - 1] = inv.meta.name


                -- save to out
                out.nodes[inv.meta.name] = inv
        end
    end
    parallel.waitForAll(table.unpack(funcs))

    -- re-specify item back referecnes to not use temp ids 
    for i, item in out.items do
        item.sources = {}
        for id, count in item.sources_id do
            item.sources[node_names[item.sources_id]] = count
        end
        item.sources_id = nil
    end

    -- calculate pools
    -- pools = { <pool_name> = { <inv1>, <inv2> } }
    local pools = {}
    for key, inv in pairs(out) do
        local pool = inv.meta.pool
        if pool then
            if not pools[pool] then pools[pool] = {} end
            local a = pools[pool]
                a[#a + 1] = k
            end
        end
    end
    

    return out
    -- apply settings overlay
end

return sp