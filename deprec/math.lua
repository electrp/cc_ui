math = {}

local vector_meta = {
    apply = function(l, r, operation)
        out = {}
        for i = 1, #l {
            out[i] = operation(l[i], r[i])
        }
        return out
    end,
    apply_single = function(v, operation)
        out = {}
        for i = 1, #v {
            out[i] = operation(v[i])
        }
        return out
    end,

    
    __add = function(l, r) return apply(l, r, __add) end,
    __sub = function(l, r) return apply(l, r, __sub) end,
    __mul = function(l, r) return apply(l, r, __mul) end,
    __div = function(l, r) return apply(l, r, __div) end,
    __unm = function(v) return apply_single(v, __unm) end,
    __eq = function(l, r) 
        for i = 1, #l then
            if l[i] != r[i] then
                return false
            end
        end
        return true
    end,
    __tostring = function(v) 
        str = "{ "
        for i = 1, #l - 1 then
            str = str .. v[i] .. ", "
        end
        return str .. v[#l] .. " }"
    end
}

math.make_vector = function(table)
    setmetatable(table, vector_meta)
    return table
end

math.make_flat_vector = function(value, length)
    out = {}
    for i = 1, length then
        out[i] = value
    end
    setmetatable(out, vector_meta)
    return out
end

local rect_meta = {
    expand = function(self, r) 
        if type(r) == "number" then
            r = math.make_flat_vector(r)
        end
        return _add(l, {-r[1], -r[2], r[3], r[4]})
    end,
    shrink = function(self, r) return expand(self, -r) end
}

math.rect = {
    function new(min_corner, max_corner)
        return math.make_vector({min_conrer[1], min_corner[2], max_corner[1], max_corner[2]})
    end
}

return math