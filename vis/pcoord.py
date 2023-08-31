#!/usr/bin/python
import plotly
import plotly.express as px
import plotly.graph_objects as go
import yaml
from yaml import CLoader as Loader, CDumper as Dumper
import pandas as pd
pd.options.mode.chained_assignment = None  # default='warn'
import numpy as np
import random
import glob
import sys
from math import log
import os.path

#fig = px.bar(x=["a", "b", "c"], y=[1, 3, 2])
#fig.write_html('first_figure.html', auto_open=True)

proot="/home/elimtob/Workspace/drcachedim"

#fglob=f"{proot}/results/keep/imagick_r_1000.yml"
#fglob=f"{proot}/results/keep/cachetest_1000.yml"
#fglob=f"{proot}/results/xz_r-res-7-7-16-5-28.yml"
#fglob=f"{proot}/results/imagick_r-res.yml"
#fglob=f"{proot}/results/imagick_r-max_cost-4144497-7-12-13-36-20.yml"
fglob=f"{proot}/results/imagick_r-char-7-24-2-35-32.yml"
if len(sys.argv) > 1:
    fglob = sys.argv[1]

plot_name = "pcoord.pdf"
if len(sys.argv) > 2:
    plot_name = sys.argv[2]
plot_name = f"{proot}/plots/{plot_name}"

title = "TODO: title"
if len(sys.argv) > 3:
    title = sys.argv[3]

top = 10
if len(sys.argv) > 4:
    top = int(sys.argv[4])

#Load
sweeps = []
for fname in glob.glob(fglob):
    with open(fname, 'r') as file:
        sweep = pd.json_normalize(yaml.load(file, Loader=Loader))
        #sweep = pd.json_normalize(yaml.safe_load(file))
        sweeps.append(sweep)
        #plot_name = f"{proot}/plots/"+os.path.splitext(os.path.basename(fname))[0] + ".png"

df = pd.concat(sweeps)

s0 = "L1I.cfg.size"
a0 = "L1I.cfg.assoc"
m0 = "L1I.stats.Misses"
mr0 = "L1I.stats.Miss rate"

s1 = "L1D.cfg.size"
a1 = "L1D.cfg.assoc"
m1 = "L1D.stats.Misses"
mr1 = "L1D.stats.Miss rate"

s2 = "L2.cfg.size"
a2 = "L2.cfg.assoc"
m2 = "L2.stats.Misses"
mr2 = "L2.stats.Miss rate"

s3 = "L3.cfg.size"
a3 = "L3.cfg.assoc"
m3 = "L3.stats.Misses"
mr3 = "L3.stats.Miss rate"

Labels = {
        s1 : "size1",
        a1 : "assoc1",
        m1 : "miss1",
        mr1 : "mr1",

        s2 : "size2",
        a2 : "assoc2",
        m2 : "miss2",
        mr2 : "mr2",

        s3 : "size3",
        a3 : "assoc3",
        m3 : "miss3",
        mr3 : "mr3",

        "COST": "COST",
        "MAT": "MAT",
        "VAL": "VAL",
        "CSCALE": "COST SCALE",
        "PI": "PI"
}

D = [
        #m1, m2, m3, "MAT",
        #"CSCALE",
        s1, a1,
        #"MAT",
        s2, a2,
        #"MAT",
        s3, a3,
        #"MAT",
        #"COST",
        "PI",
        #"VAL",
]

color_key = "PI"
#color_key = "MAT"
#color_key = "CSCALE"

numeric_keys = [m1,m2,m3,s0,a0,s1,a1,s2,a2,s3,a3,"MAT","COST","VAL", "CSCALE", "LAMBDA", "PI"]
df[numeric_keys] = df[numeric_keys].apply(pd.to_numeric)
#print(df[D])

# drop penalized sims, value from $Aux::BIG_VAL
ind = df["VAL"].lt(1.0e31)
df = df[ind]

df = df.sort_values(by="VAL")
#df = df.sort_values(by="PI")
df = df.drop_duplicates(subset=[s0,a0,s1,a1,s2,a2,s3,a3,"COST", "CSCALE", "LAMBDA"])

#Some "enhancements"
SIZES = [s0,s1,s2,s3]
WAYS = [a0,a1,a2,a3]
OBJEC = ["COST", "MAT", "VAL", "PI"]
df_top = df
#Limit plot to top 10 
if top > 0:
    df_top = df.iloc[0:top]

# add additional lines to simulate thickness
def thick(df, delta, width, K):
    # shift down, then add steady increments
    df_ = df.copy()
    df_[K] = df_[K] - (width-1)/2 * delta[K]

    new_dfs = [df_,]
    for w in range(1, width):
        #df__ = df_.copy()
        new_dfs.append(df_[K] + w * delta[K])
    return pd.concat(new_dfs, ignore_index=True)

# add optimum multiple times to hack line width
df_opt = df_top.iloc[0]
delta = {}
perc = 0.001
for d in list(df_top):
    if d in SIZES:
        v = np.sort(pd.unique(df[d]))   # jitter based on global range
        delta[d] = (v[-1]-v[0])*perc
        jitter = (v[-1]-v[0])*0.01
        df_top[[d]] = df_top[[d]].apply(lambda x: x+(random.random()-0.5)*jitter, axis=1)
    if d in OBJEC:
        v = np.sort(pd.unique(df_top[d])) # jitter based on local range
        delta[d] = (v[-1]-v[0])*perc
        jitter = (v[-1]-v[0])*0.01
        df_top[[d]] = df_top[[d]].apply(lambda x: x+(random.random()-0.5)*jitter, axis=1)
    if d in WAYS:
        v = np.sort(pd.unique(df[d]))   # jitter based on global range
        delta[d] = (v[-1]-v[0])*perc
        jitter = (v[-1]-v[0])*0.01
        #delta[d] = 0.1    # absolute value of jitter to add
        #delta[d] = (v[-1]-v[0])*0.01
        df_top[[d]] = df_top[[d]].apply(lambda x: x+(random.random()-0.5)*jitter, axis=1)

L = len(df_top)
#df_top.reset_index(inplace=True)
#print("Len : ", L)
new_dfs = [df_top]
for i in range(L):
    #for w in range(int(np.round((L/2**i))+10)):
    for w in range(int(np.round(1.5*(L-i) + 5))):
        pass
        new_dfs.append(thick(df_top.iloc[[i]], pd.Series(delta), w, SIZES + OBJEC + WAYS))
        #df_top.loc[-i*L-j] = np.copy(df_top.iloc[i])
        #df_top.reset_index(inplace=True)
# add slight jitter to sizes, so the lines don't overlap too much

#df_top = thick(df_top, pd.Series(delta), 5, SIZES + OBJEC + WAYS)
df_top = pd.concat(new_dfs, ignore_index=True)

#jitter = 2    # percentage of jitter to add
#df_top[SIZES] = df_top[SIZES].apply(lambda x: x+(random.random()-0.5)*x*jitter/100, axis=1)
#jitter = 0.15    # absolute value of jitter to add
#df_top[SIZES] = df_top[SIZES].apply(lambda x: x+(random.random()-0.5)*jitter, axis=1)
#jitter = 0.15    # absolute value of jitter to add
#df_top[OBJEC] = df_top[OBJEC].apply(lambda x: x+(random.random()-0.5)*jitter, axis=1)
#jitter = 0.15    # absolute value of jitter to add
#df_top[WAYS] = df_top[WAYS].apply(lambda x: x+(random.random()-0.5)*jitter, axis=1)
# negate MAT, VAL and COST column, so that it also aligns properly with the sizes etc (Large size -> Small MAT -> Large -MAT)
# should make the graph easier to read, since the lines should become more horizontal
#df_top[OBJEC] = df_top[OBJEC] * -1

print(df_top)
#df_top = df_top.sample(frac=1)

dims = []
for d in D:
    dd = dict(
            values = df_top[d], 
            label=Labels[d],
            #tickvals=[df[d]],
            )
    #if d == "MAT":
    #    dd["constraintrange"] = [53.1*1e6, 53.28*1e6]
    # calculate tick values
    if d.endswith("size"):
        v = np.sort(pd.unique(df[d]))
        dd["range"] = [v[0],v[-1]]
        #dd["tickvals"] = v
    if d.endswith("assoc"):
        v = np.sort(pd.unique(df[d]))
        dd["range"] = [v[0],v[-1]]
        #dd["tickvals"] = v
        #if d == a3:
        #    #dd["tickvals"] = [32,16,8,4,2,1]
        #    dd["tickvals"] = [1,2,4,8,16,32]
        #    dd["range"] = [1,32]
        #else:
        #    #dd["tickvals"] = [16,8,4,2,1]
        #    dd["tickvals"] = [1,2,4,8,16]
        #    dd["range"] = [1,16]
    #if d == "COST":
    #    v = np.sort(pd.unique(df_top[d]))
    #    tvals = np.round(np.linspace(v[0], v[-1], 8))
    #    v = v[::-1] # reverse order
    #    dd["range"] = [v[0],v[-1]]
    #    dd["tickvals"] = tvals[::-1]
    #if d == "MAT":
    #    v = np.sort(pd.unique(df_top[d]))
    #    tvals = np.round(np.linspace(v[0], v[-1], 8))
    #    v = v[::-1] # reverse order
    #    dd["range"] = [v[0],v[-1]]
    #    dd["tickvals"] = tvals[::-1]
    #if d == "VAL":
    #    v = np.sort(pd.unique(df_top[d]))
    #    tvals = np.linspace(v[0], v[-1], 8)
    #    v = v[::-1] # reverse order
    #    dd["range"] = [v[0],v[-1]]
    #    dd["tickvals"] = tvals[::-1]
    dims.append(dd)

fig = go.Figure(data=
    go.Parcoords(
        line = dict(color = df_top[color_key],
                    #colorscale=[[0, "darkyellow"],[0.5, "green"],[1, "blue"]],
                    #colorscale="fall",
                    #colorscale="Blackbody",
                    #colorscale="Bluered"  ,
                    #colorscale="Blues"    ,
                    #colorscale="Cividis"  ,
                    #colorscale="Earth"    ,
                    #colorscale="Electric" ,
                    #colorscale="Greens"   ,
                    #colorscale="Greys"    ,
                    #colorscale="Hot"      ,
                    #colorscale="Jet"      ,
                    #colorscale="Picnic"   ,
                    colorscale="Portland" ,
                    #colorscale="Rainbow"  ,
                    #colorscale="RdBu"     ,
                    #colorscale="Reds"     ,
                    #colorscale="Viridis"  ,
                    #colorscale="Plasma"  ,
                    #colorscale="YlGnBu"   ,
                    #colorscale="YlOrRd"   ,
                    showscale = False,
                    #reversescale=True,
                    #cmin = 1,
                    #cmax = 16,
        ),
        dimensions = dims,
        unselected = dict(line = dict(opacity = 0.0005))
    )
)
# magic underscores wowzie we perl'in now
#fig.update_layout(font_size=14) # global font size
fig.update_layout(font_size=30) # global font size
#fig.update_traces(labelfont=dict(size=18), selector=dict(type='parcoords'))
#fig.update_traces(rangefont_size=1, selector=dict(type='parcoords'))
fig.update_traces(rangefont_size=1, selector=dict(type='parcoords'))    # try to hide unnecessary range labels
#fig.update_layout(margin=dict(r=10, l=40, b=10))
#fig.update_layout(margin=dict(l=40, b=10))
fig.update_layout(title=dict(text=title, x=0.5, xanchor="center"))
#fig.update_yaxes(type="log")
#fig.update_layout(paper_bgcolor = "lightgray") #bg color

#fig.show()
#fig.write_image("test.png", width=400, height=400, scale=2)
#fig.write_image(plot_name, scale=2.5)
fig.write_image(plot_name)
print(f"Plot saved as {plot_name}")
