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

input_arr = [b * "_basis",b * "timeSeries/" * h * "hours_2008"]
resultDir_str = b * "results"

anyM = anyModel(input_arr, resultDir_str, objName = "TheModel", supTsLvl = 2, reportLvl = 2, shortExp = 5, emissionLoss = false)
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
optimize!(anyM.optModel)

computeResults("aggBenchmark.yml",model = anyM, outputDir = "results/")

reportResults(:summary,anyM)

printIIS(anyM)

printDuals(vcat(anyM.parts.bal.cns[:enBalH2],anyM.parts.bal.cns[:enBalGasFuel],anyM.parts.bal.cns[:enBalNaturalGas]),anyM)
printObject(anyM.parts.tech[:directAirCapture].cns[:convBal],anyM)

anyM.parts.tech[:avaAndNaviTech]

inDir = input_arr
outDir = resultDir_str

objName = ""

csvDelim = ","
interCapa = :linear
supTsLvl = 2
shortExp = 5
redStep = 1.0
holdFixed = false
emissionLoss = true
forceScr = nothing
reportLvl = 2
errCheckLvl = 1
errWrtLvl = 1
coefRng = (mat = (1e-2,1e4), rhs = (1e-2,1e2))
scaFac = (capa = 1e2,  capaStSize = 1e2, insCapa = 1e1,dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
bound = (capa = NaN, disp = NaN, obj = NaN)
avaMin = 0.01
checkRng = (print = false, all = true)