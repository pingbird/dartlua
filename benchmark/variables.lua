local x = 0

local a, b, c, d

;(function()
    a = function(i)
        x = (x + i) / 2
    end
    ;(function()
        b = function(i)
            x = (x + i) / 3
        end
        ;(function()
            c = function(i)
                x = (x + i) / 4
            end
            ;(function()
                d = function(i)
                    x = (x + i) / 5
                end
            end)()
        end)()
    end)()
end)()

function step()
    for i = 1, 1000 do
        a(i)
        b(i)
        c(i)
        d(i)
    end
end

if not test then -- Running vanilla lua or LuaJIT
    local count = 4096

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