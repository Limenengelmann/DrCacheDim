
function printMat(M)
    for i = 1, #M do
        for j = 1, #M[1] do
            io.write(M[i][j], " ")
        end
        print("\n")
    end
end

function minmax(A)
    min = A[1]
    max = A[1]
    for i = 1, #A do
        min = math.min(min, A[i])
        max = math.max(max, A[i])
    end
    --print(min, max)
    return max - min
end

function stddev(A)
    mean = 0
    window = 1000
    n = #A
    s = 1
    if n > window then
        s = n - window
    end
    for i = s+1, n do
        mean = mean + A[i] / (n-s)
    end
    var = 0
    for i = s+1, n do
        dev = A[i] - mean
        var = var + dev*dev / (n-s)
    end
    return math.sqrt(var)
end

function binCount(A, window)
    t = {}
    c = 0
    n = #A
    s = 1
    if n > window then
        s = n - window
    end
    for i = s+1, n do
        a = A[i]
        if t[a] == nil then
            t[a] = 1
            c = c + 1
        end
    end
    return c 
end

-- check aliasing pattern of matrix multiplications
function initColMajor(n, s, offs)
    M = {}
    for i = 1, n do
        M[i] = {}
        for j = 1, n do
            ii = i-1
            jj = j-1
            -- 8 entries = 1 cache line (8 * 8B)
            M[i][j] = (ii + jj*n) // 8 + offs
        end
    end
    return M
end

function initRowMajor(n, s, offs)
    M = {}
    for i = 1, n do
        M[i] = {}
        for j = 1, n do
            ii = i-1
            jj = j-1
            -- 8 entries = 1 cache line (8 * 8B)
            M[i][j] = (ii*n + jj) // 8 + offs
        end
    end
    return M
end


local bins = {}
for i=1,100 do
    bins[i] = math.floor(math.random()*5000 + 1)
end

local n = 128
local sets = math.pow(2, 15 - 6)

--n = 16
--sets = n * n / 8 -- keep ratio of lines per matrix the same

--A = initRowMajor(128, sets)
local A = initRowMajor(n, sets, 0)
local B = initColMajor(n, sets, A[n][n]+1)
local C = initRowMajor(n, sets, B[n][n]+1)

local aliases = {}
for i=1, sets do
    aliases[i] = 0
end
local watchset = {}
local x = 1

function run(i, j, k)
    local a = A[i][k]
    local b = B[k][j]
    local c = C[i][j]

    for _, y in pairs{a, b, c} do
        if y % sets == 0 then
            watchset[#watchset + 1] = y
            --print(x, a, stddev(watchset))
            --print(x, y, stddev(watchset))
            --bc = binCount(watchset, 7) + binCount(watchset, 70) + binCount(watchset, 700)
            --print(x, bc / 3)
            local bc = 0
            local count = 0
            --for i = 50,500,50 do
            --for i = 10,500,50 do
            --for _, i in pairs{10,20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 300, 400, 500, 600, 700, 800, 900, 1000} do
            --for i = 4,500,50 do
            for _, i in pairs(bins) do
                bc = bc + binCount(watchset, i)
                count = count + 1
            end
            --bc = bc + binCount(watchset, 6)
            --count = 1
            print(x, bc/count)
            x = x + 1
        end
    end

    --a = a % sets + 1
    --b = b % sets + 1
    --c = c % sets + 1

    -- C(i, j) = A(i, k) * B(k, j)
    --aliases[a] = aliases[a] + 1
    --aliases[b] = aliases[b] + 1
    --aliases[c] = aliases[c] + 1
    --printMat({aliases})
    --local y = minmax(aliases)
    --local y = stddev(aliases)
    --print(x, a, b, c)
    --x = x + 1
    --print(x, a)
    --print(x+1, b)
    --print(x+2, c)
    --x = x + 3
end

if arg[1] == "ijk" then
    for i=1, n do for j=1, n do for k=1, n do 
        run(i, j, k)
    end end end
elseif arg[1] == "jik" then
    for j=1, n do for i=1, n do for k=1, n do 
        run(i, j, k)
    end end end
elseif arg[1] == "ikj" then
    for i=1, n do for k=1, n do for j=1, n do 
        run(i, j, k)
    end end end
elseif arg[1] == "kij" then
    for k=1, n do for i=1, n do for j=1, n do 
        run(i, j, k)
    end end end
elseif arg[1] == "jki" then
    for j=1, n do for k=1, n do for i=1, n do 
        run(i, j, k)
    end end end
elseif arg[1] == "kji" then
    for k=1, n do for j=1, n do for i=1, n do 
        run(i, j, k)
    end end end
end

--printMat(A)
--print()
--printMat(B)
--print()
--printMat(C)
--print(sets)
