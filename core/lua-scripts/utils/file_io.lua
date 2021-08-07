function read_file(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

function iter_lines(text)
    return text:gmatch("([^\r\n]+)\r?\n")
end
