# EuSysMod

EuSysMod is a multi-year European energy system capacity-expansion model built on the [AnyMOD.jl](https://github.com/leonardgoeke/AnyMOD.jl) modeling framework, using [JuMP](https://jump.dev/) to set up and solve the underlying optimization problem. It supports a monolithic formulation (`runMono.jl`) and a Benders-decomposition formulation (`runBenders.jl` / `runBenders_local.jl`) for large-scale, multi-country, multi-year investment planning.

## 1. System requirements

**Operating systems tested**
- Windows 10 / 11 (local/desktop use)
- Linux (HPC cluster jobs via SLURM)

**Software dependencies and tested versions**
- [Julia](https://julialang.org/) 1.12.5
- Julia dependencies are pinned in [`Manifest.toml`](Manifest.toml) via [`Project.toml`](Project.toml):
- [Gurobi] any version, but requires a license (a free [academic license](https://www.gurobi.com/academia/) is sufficient). In `runMono.jl`, it can be swapped for a free, open-source alternative such as [`HiGHS`](https://github.com/jump-dev/HiGHS.jl) — see [Instructions for use]

**Hardware**
- The demo below (`runMono.jl`, default settings) runs on a normal desktop/laptop.
- Reproducing the full-scale, multi-country, 8760-hour scenarios a HPC cluster, using up to 33 nodes with 14 cores and 4–8 GB RAM per node.

## 2. Installation guide

1. Install Julia (tested with 1.12.5). The scripts default to Gurobi 12.0.1 as the solver, which requires a license (a free academic license is available) — install it and make sure the `GUROBI_HOME` environment variable points to your Gurobi install directory (e.g. `C:\gurobi1201\win64`) so `Gurobi.jl` can find it. If you'd rather avoid installing a licensed solver, see the note on using `HiGHS` instead under [Instructions for use](#4-instructions-for-use).
2. Clone the repository and check out the `multiYearPaper` tag:
   ```powershell
   git clone https://github.com/leonardgoeke/EuSysMod.git
   cd EuSysMod
   git checkout multiYearPaper
   ```
3. From the repository root, instantiate the pinned Julia environment:
   ```powershell
   julia --project=. -e "using Pkg; Pkg.instantiate()"
   ```
   This downloads and precompiles `AnyMOD.jl` (from its `multiYearPaper` tag) and all other dependencies listed above, using the exact versions recorded in `Manifest.toml`.

**Typical install time:** approximately 15 minutes on a normal desktop computer with a broadband internet connection (excluding installing Julia and Gurobi themselves).

## 3. Demo

**Instructions to run on data**

The repository ships with the full input dataset used for the manuscript under [`inputFiles/`](inputFiles/) and [`modelSetup/`](modelSetup/). For a quick demo, run the model with no command-line argument — this automatically selects a small, fast example case (row 16, `test`, in [`settings.csv`](settings.csv): all countries, a reduced 672-hour year, the `inter_all` technology portfolio, and the `10Flex20Price` fuel-import case):

```powershell
julia --project=. runMono.jl
```

> **Tests should be run with `runMono.jl`**, not `runBenders.jl`/`runBenders_local.jl`. The Benders scripts are for large-scale, distributed HPC runs and are not intended as the quick demo/test path.

**Expected output**
- The solver's log printed to the terminal, ending in an optimal solution status and objective value.
- A new `results/test/` folder containing CSV result files (e.g. summary, cost, exchange, and storage-level results) written by the model's built-in reporting functions.

**Expected run time:** approximately 15 minutes on a normal desktop computer.