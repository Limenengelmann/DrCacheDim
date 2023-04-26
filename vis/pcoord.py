import plotly.express as px
import yaml
import pandas as pd

#fig = px.bar(x=["a", "b", "c"], y=[1, 3, 2])
#fig.write_html('first_figure.html', auto_open=True)


fname="../results/imagick_r_sim_117911.yml"

with open(fname, 'r') as file:
    sweep = pd.json_normalize(yaml.safe_load(file))

df = sweep
print(df)
#exit(0)

L = {
        "L1d ways": "L1D.cfg.assoc",
        "L1d size": "L1D.cfg.size",
        "L2 ways" : "L2.cfg.assoc",
        "L2 size" : "L2.cfg.size",
        "L3 ways" : "L3.cfg.assoc",
        "L3 size" : "L3.cfg.size",
        "AMAT"    : "AMAT",
}

D = [
        "L1D.cfg.assoc",
        "L1D.cfg.size",
        "L2.cfg.assoc",
        "L2.cfg.size",
        "L3.cfg.assoc",
        "L3.cfg.size",
        "AMAT",
]

fig = px.parallel_coordinates(df, color="L1D.cfg.assoc", dimensions=D, labels=L,
                             color_continuous_scale=px.colors.diverging.Tealrose,
                             color_continuous_midpoint=4)
fig.show()
