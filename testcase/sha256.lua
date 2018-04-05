if not bit and not bit32 then
    bit = require("bit")
end

bit = bit or bit32

local function chars2num(txt)
    return (txt:byte(1) * 16777216) + (txt:byte(2) * 65536) + (txt:byte(3) * 256) + txt:byte(4)
end

local function limit(num)
    return bit.band(num)
end

local z = 0 -- curb your linter errors
local _hex = {[z] = "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

bit.tohex = bit.tohex or function(n)
    local o = ""
    local x = limit(n)
    for i = 0, 3 do
        o = _hex[math.floor(x / 16) % 16] .. _hex[x % 16] .. o
        x = math.floor(x / 256)
    end
    return o
end

local function num2chars(num, l)
    local out = ""
    for l1=1, l or 4 do
        out = string.char(math.floor(num / (256 ^ (l1 - 1))) % 256) .. out
    end
    return out
end

do
    local bxor = bit.bxor
    local ror = bit.rrotate or bit.ror
    local rshift = bit.rshift

    function sha256(txt)
        local ha = {
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        }

        local len = #txt

        txt = txt .. "\128" .. ("\0"):rep(64 - ((len + 9) % 64)) .. num2chars(8 * len, 8)

        local w = {}

        for chunkind = 1, #txt, 64 do
            for i = 16, 63 do
                assert(bxor == bit.bxor)
                local s0 = bxor(0)
            end
        end

        return "hi"
    end
end

print(sha256("potato"))