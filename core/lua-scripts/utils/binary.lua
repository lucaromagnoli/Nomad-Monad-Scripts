Binary = {}

function Binary:new(bits)
    local o = {
        bits = bits or {}
    }
    setmetatable(o, self)
    self.__index = self
    return o
end


function Binary:__tostring()
    return string.reverse(table.concat(self.bits))
end

function Binary:from_decimal(dec)
    return self:new(dec_to_bin(dec))
end

function Binary:to_decimal(dec)
    return bin_to_dec(self.bits)
end

-- return a table with the indices (1 based) of value 1 bits
-- e.g. [0,1,0,1] -> {2,4}
function Binary:to_bits_indices()
    local indices = {}
    for i, bit in ipairs(self.bits) do
        if bit == 1 then
            indices[#indices + 1] = i
        end
    end
    return indices
end

---@param dec number
---@return table
function dec_to_bin(dec)
    local bits = {}
    while dec > 0 do
        bit = dec % 2
        bits[#bits + 1] = bit
        dec = math.floor(dec / 2)
    end
    return bits
end

---@param bits table
---@return number
function bin_to_dec(bits)
    local buf = 0
    for i=1, #bits do
        if bits[i] == 1 then
            buf = buf + 2^i
        end
    end
    return math.floor(buf)
end
