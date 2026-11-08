"""Style biểu đồ dùng chung (matplotlib)."""
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

PALETTE = [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728",
    "#9467bd", "#8c564b", "#17becf", "#bcbd22",
]


def setup():
    plt.rcParams.update({
        "figure.dpi": 120,
        "savefig.dpi": 150,
        "font.size": 11,
        "axes.grid": True,
        "grid.alpha": 0.3,
        "axes.titlesize": 12,
        "axes.labelsize": 11,
        "figure.autolayout": True,
    })


def save(fig, path):
    fig.tight_layout()
    fig.savefig(path)
    print(f"  saved: {path}")


setup()
