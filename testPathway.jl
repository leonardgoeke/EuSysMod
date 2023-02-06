b = "C:/Users/pacop/.julia/dev/AnyMOD.jl/"

	
using Base.Threads, CSV, Dates, LinearAlgebra, Requires, YAML
using MathOptInterface, Reexport, Statistics, SparseArrays
using DataFrames, JuMP, Suppressor, Plotly
using DelimitedFiles

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

using Gurobi

h = "96"

b = "" # add the model dir here

input_arr = [b * "_basis",b * "timeSeries/" * h * "hours_2008_only2020"]
resultDir_str = b * "results"

anyM = anyModel(input_arr, resultDir_str, objName = "TheModel", supTsLvl = 2, reportLvl = 2, shortExp = 5, emissionLoss = false)
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
optimize!(anyM.optModel)

computeResults("aggBenchmark.yml",model = anyM, outputDir = "results/")
computeResults("aggAutoGen.yml",model = anyM, outputDir = "results/")

reportResults(:summary,anyM)

printIIS(anyM)

printObject( anyM.parts.lim.cns[:genFix],anyM)

bla_df = DataFrame(a = [1,1,1], b = [2,2,3], c = [1,6,7])

bla_df[!,end-1]