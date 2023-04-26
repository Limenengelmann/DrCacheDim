import plotly.express as px
import plotly.graph_objects as go
import yaml
import pandas as pd
import glob

#fig = px.bar(x=["a", "b", "c"], y=[1, 3, 2])
#fig.write_html('first_figure.html', auto_open=True)

proot="/home/elimtob/Workspace/mymemtrace"

fglob=f"{proot}/results/imagick_r_sim_*"

sweeps = []
for fname in glob.glob(fglob):
    with open(fname, 'r') as file:
        sweep = pd.json_normalize(yaml.safe_load(file))
        sweeps.append(sweep)

df = pd.concat(sweeps)
print(df)

D = [
        "L1D.cfg.assoc",
        "L1D.cfg.size",
        "L1D.stats.Miss rate",
        "L2.cfg.assoc",
        "L2.cfg.size",
        "L2.stats.Miss rate",
        "L3.cfg.assoc",
        "L3.cfg.size",
        "L3.stats.Miss rate",
        "AMAT",
]

fig = go.Figure(data=
    go.Parcoords(
        line = dict(color = df['AMAT'],
                    #colorscale = [[0,'purple'],[0.5,'lightseagreen'],[1,'gold']]
                    showscale = True,
                    #cmin = 1,
                    #cmax = 16,
        ),
        dimensions = list([
                        dict(
                            label = "L1D ways", values = df['L1D.cfg.assoc'],
                            tickvals = [1,2,4,8,16],
                        ),
                        dict(
                            label = "L1D size", values = df['L1D.cfg.size'],
                        ),
                        dict(
                            label = "L1D MR", values = df['L1D.stats.Miss rate'],
                        ),
                        dict(
                            label = "L2 ways", values = df['L2.cfg.assoc'],
                            tickvals = [1,2,4,8,16],
                        ),
                        dict(
                            label = "L2 size", values = df['L2.cfg.size'],
                        ),
                        dict(
                            label = "L2 MR", values = df['L2.stats.Miss rate'],
                        ),
                        dict(
                            label = "L3 ways", values = df['L3.cfg.assoc'],
                            tickvals = [1,2,4,8,16,32],
                        ),
                        dict(
                            label = "L3 size", values = df['L3.cfg.size'],
                        ),
                        dict(
                            label = "L3 MR", values = df['L3.stats.Miss rate'],
                        ),
                        dict(
                            label = "AMAT", values = df['L3.cfg.size'],
                        ),
        ]),
        unselected = dict(line = dict(opacity = 0.05))
    )
)

#fig = px.parallel_coordinates(df,
#                              #color="L1D.cfg.assoc", 
#                              color="AMAT", 
#                              #color_continuous_scale=px.colors.diverging.Tealrose,
#                              #color_continuous_midpoint=5
#                              dimensions=D, 
#                              #labels=L,
#)

fig.show()
