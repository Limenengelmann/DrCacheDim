import sqlite3
import matplotlib.pyplot as plt

db_path="/home/elimtob/traces/lat_tcp_2023-2-3_11:39/decoded_2023-2-3_13:11/lat_tcp.db"
db_path="/home/elimtob/traces/lbm_r_2023-02-14_16:55/decoded_2023-02-14_17:03/lat_tcp.db"
db_path="/home/elimtob/traces/lbm_r_2023-02-16_00:04/decoded_2023-02-16_00:07/lbm_r-10.db"

fname=db_path.split("/")[-1]


con = sqlite3.connect(db_path)
cur = con.cursor()

a = {}
count = 0

for row in cur.execute("SELECT ca from dxhist;"):
    count = count + 1
    if count % 100000 == 0:
        print(f"Processing row {count} in {fname}\r", end="")
    if row in a:
        a[row] = a[row]+1
    else:
        a[row] = 1
    #print(a[row])

print(f"Processed {count} rows in total. Sorting before plot...")
b = list(sorted(a.values(), reverse=True))

fig, ax = plt.subplots()
ax.semilogy(b)
#plt.hist(b, 100)
plt.show()
plt.savefig(f"plots/hist-{fname}.png")
