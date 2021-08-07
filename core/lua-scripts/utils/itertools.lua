-- Iterator function
-- https://www.lua.org/pil/7.1.html
function iter(t)
    local i = 0
    local n = #t
    return function()
        i = i + 1
        if i <= n then
            return t[i]
        end
    end
end

function slice_table(source_table, start_idx, end_idx)
    start_idx = start_idx or 1
    end_idx = end_idx or #source_table
    local dest_table = {}
    for idx, item in ipairs(source_table) do
        if idx >= start_idx and idx <= end_idx then
            dest_table[#dest_table + 1] = item
        end
    end
    return dest_table
end
