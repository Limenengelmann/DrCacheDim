import sqlite3 as sql
import sys
import os

tracedir="/mnt/extSSD/traces"

for fname in os.listdir(tracedir):
    with sql.connect(os.path.join(tracedir ,fname)) as con:
        print(fname)
        cur = con.cursor()
        res = cur.execute("SELECT * FROM ROW_COUNT")
        print(fname, res.fetchall())


