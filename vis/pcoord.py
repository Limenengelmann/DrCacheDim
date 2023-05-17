import plotly.express as px
import plotly.graph_objects as go
import yaml
import pandas as pd
import glob

#fig = px.bar(x=["a", "b", "c"], y=[1, 3, 2])
#fig.write_html('first_figure.html', auto_open=True)

proot="/home/elimtob/Workspace/mymemtrace"

fglob=f"{proot}/results/keep/imagick_r_1000.yml"
#fglob=f"{proot}/results/keep/cachetest_1000.yml"

sweeps = []
for fname in glob.glob(fglob):
    with open(fname, 'r') as file:
        sweep = pd.json_normalize(yaml.safe_load(file))
        sweeps.append(sweep)

df = pd.concat(sweeps)
print(df)

#TODO Miss rate key missing?
s1D = "L1D.cfg.size"
a1D = "L1D.cfg.assoc"
m1D = "L1D.stats.Misses"
mr1D = "L1D.stats.Miss rate"

s1I = "L1I.cfg.size"
a1I = "L1I.cfg.assoc"
m1I = "L1I.stats.Misses"
mr1I = "L1I.stats.Miss rate",

s2 = "L2.cfg.size"
a2 = "L2.cfg.assoc"
m2 = "L2.stats.Misses"
mr2 = "L2.stats.Miss rate",

s3 = "L3.cfg.size"
a3 = "L3.cfg.assoc"
m3 = "L3.stats.Misses"
mr3 = "L3.stats.Miss rate",

D = [
        m1D, m2, m3, "AMAT",
        s1D, a1D,
        s2, a2,
        s3, a3,
        "VAL",
]

dims = []
for d in D:
    dd = dict(values = df[d], label=d)
    if d.endswith("assoc"):
        #dd["tickvals"] = [32,16,8,4,2,1]
        pass
    dims.append(dd)

fig = go.Figure(data=
    go.Parcoords(
        line = dict(color = df['VAL'],
                    #colorscale = [[0,'purple'],[0.5,'lightseagreen'],[1,'gold']]
                    showscale = True,
                    #cmin = 1,
                    #cmax = 16,
        ),
        dimensions = dims,
        unselected = dict(line = dict(opacity = 0.0005))
    )
)

fig.show()
