
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

b = "C:/Users/pacop/Desktop/work/git/TheModel/" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/96hours_2008"]
resultDir_str = b * "results"

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "TheModel", supTsLvl = 2, reportLvl = 2, shortExp = 10, emissionLoss = false)
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
optimize!(anyM.optModel)

reportResults(:summary,anyM)
reportResults(:exchange,anyM)