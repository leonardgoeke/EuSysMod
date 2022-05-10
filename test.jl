
# ! import AnyMOD and packages

b = "C:/Users/pacop/.julia/dev/AnyMOD.jl/"

using Base.Threads, CSV, Dates, LinearAlgebra, Requires, YAML
using MathOptInterface, Reexport, Statistics, PyCall, SparseArrays
using DataFrames, JuMP, Suppressor
using DelimitedFiles

pyimport_conda("networkx","networkx")
pyimport_conda("matplotlib.pyplot","matplotlib")
pyimport_conda("plotly","plotly")

include(b* "src/objects.jl")
include(b* "src/tools.jl")
include(b* "src/modelCreation.jl")
include(b* "src/decomposition.jl")

include(b* "src/optModel/technology.jl")
include(b* "src/optModel/exchange.jl")
include(b* "src/optModel/system.jl")
include(b* "src/optModel/cost.jl")
include(b* "src/optModel/other.jl")
include(b* "src/optModel/objective.jl")

include(b* "src/dataHandling/mapping.jl")
include(b* "src/dataHandling/parameter.jl")
include(b* "src/dataHandling/readIn.jl")
include(b* "src/dataHandling/tree.jl")
include(b* "src/dataHandling/util.jl")

include(b* "src/dataHandling/gurobiTools.jl")

h = "96"
ee = "_highPV"
nu = "_lowCost"
t_int = parse(Int,"2")
resultDir_str = "results"


using Gurobi, CSV, Statistics



for ee in ["_highPV","_highWind"], nu in ["_lowCost","_bestEstimate","_highCost"]

    obj_str = h * "hours_" * h_heu * "hoursHeu" * ee * nu
    inputMod_arr = ["_basis",ee,nu,"timeSeries/" * h * "hours_2008_only2040"]

    anyM = anyModel(inputMod_arr,resultDir_str, objName = obj_str, supTsLvl = 2, shortExp = 5, redStep = 1.0, emissionLoss = false, holdFixed = true)

    createOptModel!(anyM)
    setObjective!(:cost,anyM)

    set_optimizer(anyM.optModel, Gurobi.Optimizer)
    set_optimizer_attribute(anyM.optModel, "Method", 2);
    set_optimizer_attribute(anyM.optModel, "Crossover", 0);
    set_optimizer_attribute(anyM.optModel, "Threads",t_int);
    set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

    optimize!(anyM.optModel)

    reportResults(:summary,anyM, addRep = (:capaConvOut,), addObjName = true)
    reportResults(:exchange,anyM, addObjName = true)
    reportResults(:cost,anyM, addObjName = true)

end

