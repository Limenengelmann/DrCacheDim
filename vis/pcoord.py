import plotly.express as px
import plotly.graph_objects as go
import yaml
import pandas as pd
import glob

#fig = px.bar(x=["a", "b", "c"], y=[1, 3, 2])
#fig.write_html('first_figure.html', auto_open=True)

proot="/home/elimtob/Workspace/mymemtrace"

fglob=f"{proot}/results/keep/imagick_r_test_sim_4000.yml"

sweeps = []
for fname in glob.glob(fglob):
    with open(fname, 'r') as file:
        sweep = pd.json_normalize(yaml.safe_load(file))
        sweeps.append(sweep)

df = pd.concat(sweeps)
print(df)

D = [
        "L1D.cfg.size",
        "L1D.cfg.assoc",
        #"L1D.stats.Miss rate",
        "L1D.stats.Misses",
        "L2.cfg.size",
        "L2.cfg.assoc",
        #"L2.stats.Miss rate",
        "L2.stats.Misses",
        "L3.cfg.size",
        "L3.cfg.assoc",
        #"L3.stats.Miss rate",
        "L3.stats.Misses",
        "AMAT",
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
        line = dict(color = df['AMAT'],
                    #colorscale = [[0,'purple'],[0.5,'lightseagreen'],[1,'gold']]
                    showscale = True,
                    #cmin = 1,
                    #cmax = 16,
        ),
        dimensions = dims,
        unselected = dict(line = dict(opacity = 0.05))
    )
)

fig.show()
