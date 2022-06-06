
# ! import AnyMOD and packages

using AnyMOD, Gurobi

b = "C:/Users/pacop/Desktop/work/git/TheModel/" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/8760hours_det",b * "timeSeries/test"]
resultDir_str = b * "results"


# infeas tritt nicht auf, wenn parameter für speicher h2 entfernt!?


# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "TheModel", supTsLvl = 1, reportLvl = 2, shortExp = 10, coefRng = (mat = (1e-2,1e4), rhs = (1e0,1e4)), scaFac = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0))
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "BarHomogeneous", 1);
set_optimizer_attribute(anyM.optModel, "NumericFocus", 3);
#@constraint(anyM.optModel, anyM.parts.obj.var[:obj][1,:var] >= 0)
optimize!(anyM.optModel)

reportResults(:cost,anyM)

printIIS(anyM)

reportResults(:cost,anyM)
reportResults(:summary,anyM)
reportResults(:exchange,anyM)

reportResults(:cost,anyM)

bla = anyM.parts.tech[:h2StorageTank].cns[:stBal]


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