import plotly.express as px
import glob
import sys
import pandas as pd
import numpy as np
from math import log
import yaml
from yaml import CLoader as Loader, CDumper as Dumper
import plotly.graph_objects as go
import plotly.io as pio
pio.kaleido.scope.mathjax = None

proot="/home/elimtob/Workspace/drcachedim"

#fglob=f"{proot}/results/keep/imagick_r_1000.yml"
#fglob=f"{proot}/results/keep/cachetest_1000.yml"
fglob=f"{proot}/results/matmul_kji-brutef-7-14-8-54-15.yml"
fglob=f"{proot}/results/matmul_ref-brutef-7-13-18-40-51.yml"
fglob=f"{proot}/results/xz_r-res-7-7-16-5-28.yml"
fglob=f"{proot}/results/xz_r-brutef-7-14-9-6-27.yml"
fglob=f"{proot}/results/imagick_r-max_cost-4144497-7-12-13-36-20.yml"
fglob=f"{proot}/results/imagick_r-res.yml"
fglob=f"{proot}/results/imagick_r-char-7-24-2-35-32.yml"


if len(sys.argv) > 1:
    fglob = sys.argv[1]

plot_name = "2dplot.pdf"
if len(sys.argv) > 2:
    plot_name = sys.argv[2]
plot_name = f"{proot}/plots/{plot_name}"

title = "TODO: title"
if len(sys.argv) > 3:
    title = sys.argv[3]


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
mr0 = "L1I.stats.Miss rate",

s1 = "L1D.cfg.size"
a1 = "L1D.cfg.assoc"
m1 = "L1D.stats.Misses"
mr1 = "L1D.stats.Miss rate"

s2 = "L2.cfg.size"
a2 = "L2.cfg.assoc"
m2 = "L2.stats.Misses"
mr2 = "L2.stats.Miss rate",

s3 = "L3.cfg.size"
a3 = "L3.cfg.assoc"
m3 = "L3.stats.Misses"
mr3 = "L3.stats.Miss rate",

numeric_keys = [m1,m2,m3,s0,a0,s1,a1,s2,a2,s3,a3,"MAT","COST","VAL"]
df[numeric_keys] = df[numeric_keys].apply(pd.to_numeric)

# drop penalized sims, value from $Aux::BIG_VAL
pen_ind = df["VAL"].lt(1.0e31)
df = df[pen_ind]

#lam = 0.5
#df["VAL"] = (1-lam)*df["MAT"] + lam*cscale*df["COST"]

max_val = max(df["VAL"])
i_opt = np.argmin(df["VAL"])
Hopt = df.iloc[i_opt]

#df["VAL"] = df["VAL"]/max_val
#df["VAL"] = df["VAL"].apply(np.exp)
#df["MAT"] = df["MAT"].apply(np.log10)

x = "COST"
y = "MAT"
color = "VAL"
#fig = px.scatter(df, x="COST", y="MAT", color="MPC")
fig = px.scatter(df, x=x, y=y, color=color,
        hover_data=[s0,a0,s1,a1,s2,a2,s3,a3,"MAT", "COST", "VAL"],
        color_continuous_scale="Portland",
        )

# Highlight optimum
fig.add_trace(
    go.Scatter(
        x=[Hopt[x]],
        y=[Hopt[y]],
        mode="markers+text",
        marker=dict(
            color="red",
            size=10,
            #symbol="star",
            #line=dict(width=2, color="black"),
        ),
        text="optimum",
        textposition='bottom center',
        showlegend=False,
    )
)

fig.update_layout(
    legend=dict(
        x=-0.1,
        y=-0.1,
        traceorder="normal",
        font=dict(
            family="sans-serif",
            size=17,
            #color="black"
        ),
    )
)

#fig = px.scatter_matrix( df, dimensions=[s1,s2,s3], color="VAL",)
#fig.update_traces(diagonal_visible=False)
fig.update_layout(font_size=14) # global font size
fig.update_layout(title=dict(text=title, x=0.5, xanchor="center"))
#fig.write_image("test.png", scale=2.5)
fig.write_image(plot_name)
print(f"Plot saved as {plot_name}")
fig.show()
