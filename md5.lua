-- MD5 hash function in ComputerCraft (Unsafe, for educational/legacy uses only)
-- By Anavrins
-- For help and details, you can DM me on Discord (Anavrins#4600)
-- MIT License
-- Pastebin: https://pastebin.com/6PVSRckQ
-- Last updated: March 27 2020
 
local mod32 = 2^32
local bor = bit32.bor
local band = bit32.band
local bnot = bit32.bnot
local bxor = bit32.bxor
local blshift = bit32.lshift
local upack = unpack
 
local function lrotate(int, by)
    local s = int/(2^(32-by))
    local f = s%1
    return (s-f)+f*mod32
end
local function brshift(int, by)
    local s = int / (2^by)
    return s-s%1
end
 
local s = {
     7, 12, 17, 22,
     5,  9, 14, 20,
     4, 11, 16, 23,
     6, 10, 15, 21,
}
 
local K = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
}
 
local H = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476}
 
local function counter(incr)
    local t1, t2 = 0, 0
    if 0xFFFFFFFF - t1 < incr then
        t2 = t2 + 1
        t1 = incr - (0xFFFFFFFF - t1) - 1       
    else t1 = t1 + incr
    end
    return t2, t1
end
 
local function LE_toInt(bs, i)
    return (bs[i] or 0) + blshift((bs[i+1] or 0), 8) + blshift((bs[i+2] or 0), 16) + blshift((bs[i+3] or 0), 24)
end
 
local function preprocess(data)
    local len = #data
    local proc = {}
    data[#data+1] = 0x80
    while #data%64~=56 do data[#data+1] = 0 end
    local blocks = math.ceil(#data/64)
    for i = 1, blocks do
        proc[i] = {}
        for j = 1, 16 do
            proc[i][j] = LE_toInt(data, 1+((i-1)*64)+((j-1)*4))
        end
    end
    proc[blocks][16], proc[blocks][15] = counter(len*8)
    return proc
end
 
local function digestblock(m, C)
    local a, b, c, d = upack(C)
    for j = 0, 63 do
        local f, g, r = 0, j, brshift(j, 4)
        if r == 0 then
            f = bor(band(b, c), band(bnot(b), d))
        elseif r == 1 then
            f = bor(band(d, b), band(bnot(d), c))
            g = (5*j+1)%16
        elseif r == 2 then
            f = bxor(b, c, d)
            g = (3*j+5)%16
        elseif r == 3 then
            f = bxor(c, bor(b, bnot(d)))
            g = (7*j)%16
        end
        local dTemp = d
        a, b, c, d = dTemp, (b+lrotate((a + f + K[j+1] + m[g+1])%mod32, s[bor(blshift(r, 2), band(j, 3))+1]))%mod32, b, c
    end
    C[1] = (C[1] + a)%mod32
    C[2] = (C[2] + b)%mod32
    C[3] = (C[3] + c)%mod32
    C[4] = (C[4] + d)%mod32
    return C
end
 
local mt = {
    __tostring = function(a) return string.char(unpack(a)) end,
    __index = {
        toHex = function(self, s) return ("%02x"):rep(#self):format(unpack(self)) end,
        isEqual = function(self, t)
            if type(t) ~= "table" then return false end
            if #self ~= #t then return false end
            local ret = 0
            for i = 1, #self do
                ret = bor(ret, bxor(self[i], t[i]))
            end
            return ret == 0
        end
    }
}
 
local function toBytes(t, n)
    local b = {}
    for i = 1, n do
        b[(i-1)*4+1] = band(t[i], 0xFF)
        b[(i-1)*4+2] = band(brshift(t[i], 8), 0xFF)
        b[(i-1)*4+3] = band(brshift(t[i], 16), 0xFF)
        b[(i-1)*4+4] = band(brshift(t[i], 24), 0xFF)
    end
    return setmetatable(b, mt)
end
 
function digest(data)
    data = data or ""
    data = type(data) == "string" and {data:byte(1,-1)} or data
 
    data = preprocess(data)
    local C = {upack(H)}
    for i = 1, #data do C = digestblock(data[i], C) end
    return toBytes(C, 4)
end
 
return {
    digest = digest,
}