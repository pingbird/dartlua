local x = 0

function step()
    for i = 1, 1000 do
        x = (x + i) / 2
    end
end

if not test then -- Running vanilla lua or LuaJIT
    local count = 16384

    for i = 1, count do
        step()
    end

    local socket = require("socket")
    local t0 = socket.gettime()

    for i = 1, count do
        step()
    end

    local dt = socket.gettime() - t0
    print(math.floor(dt * 1000000))
end