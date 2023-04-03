local lsqlite3 = require("lsqlite3")

local dbfile = "/home/elimtob/Workspace/mymemtrace/traces/imagick_r-test.db"
local db = lsqlite3.open(dbfile) or os.exit(1)

local rows = 0
for r in db:rows("SELECT SUM(REFS) from ROW_COUNT") do rows = r[1] end
print("Rows: " .. rows)

local hist   = {}
local max    = 0
local kmin   = 0
local count  = 0
local gcount = 0
local cl
hist[0] = math.maxinteger
for r in db:rows("SELECT ADDR, ADDR >> 6 FROM MEMREFS") do
    cl = r[2]
    local v = hist[cl]
    if not v then
        count = count + 1
        v = 0
    end
    v = v + 1
    hist[cl] = v
    if v > max        then max = v end
    if v < hist[kmin] then kmin = cl end
    gcount = gcount + 1
    if (gcount % 10000 == 0) then
        io.write("max = " .. max .. ", min = " .. hist[kmin] .. ", " .. gcount / rows * 100 .. "% done, .. v = " .. v .. ", cl = ".. cl .. "\r")
    end
end
print()
print("Max = " .. max .. ", Min = " .. (hist[kmin] or "nil") .. ", Total = " .. count )
db:close()
