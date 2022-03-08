
# ! import AnyMOD and packages

b = "C:/Users/pacop/.julia/dev/AnyMOD.jl/"

using Base.Threads, CSV, Dates, LinearAlgebra, Requires, YAML
using MathOptInterface, Reexport, Statistics, PyCall, SparseArrays
using DataFrames, JuMP, Suppressor

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
h_heu = "96"
ee = "_lowWindPot"
grid = "_gridExp"
t_int = 2


using Gurobi, CSV, Statistics

# ! dump for specific test code

b = "C:/Users/pacop/Desktop/work/git/TheModel/" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/96hours_2008_only2050", b * "_gridExp", b * "_lowWindPot" ]
resultDir_str = b * "results"

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "TheModel", supTsLvl = 2, reportLvl = 2, shortExp = 5, emissionLoss = false)
createOptModel!(anyM)
setObjective!(:cost,anyM)


set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
optimize!(anyM.optModel)

writeModulation(aggRelCol_dic,anyM)

reportResults(:summary,anyM, addRep = (:capaConvOut,))
reportResults(:exchange,anyM)
reportResults(:cost,anyM)



reportTimeSeries(:electricity,anyM)
reportTimeSeries(:spaceHeat,anyM)
reportTimeSeries(:districtHeat,anyM)


plotEnergyFlow(:graph,anyM, plotSize= (25.57,14.95), wrtYML = true, wrtGEXF = true)


# all
plotGraphYML(resultDir_str * "/powerAll.yml"; plotSize = (25.57,14.95), fontSize = 16)
plotGraphYML(resultDir_str * "/spaceAndDistrictHeat.yml"; plotSize = (25.57,14.95), fontSize = 16)

plotGraphYML(resultDir_str * "/processHeat.yml"; plotSize = (25.57,14.95), fontSize = 16)
plotGraphYML(resultDir_str * "/all.yml"; plotSize = (25.57,14.95), fontSize = 16)
plotGraphYML(resultDir_str * "/transport.yml"; plotSize = (25.57,14.95), fontSize = 16)
plotGraphYML(resultDir_str * "/powerToX.yml"; plotSize = (25.57,14.95), fontSize = 16)


tSym = :pvOpenspace_b
tInt = sysInt(tSym,anyM.sets[:Te])
part = anyM.parts.tech[tSym]
prepTech_dic = prepSys_dic[:Te][tSym]