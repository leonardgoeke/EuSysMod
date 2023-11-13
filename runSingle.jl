import Pkg; Pkg.activate(".")
# Pkg.instantiate()
# ! import AnyMOD and packages

using AnyMOD, Gurobi, CSV
include("functions.jl")

scr = parse(Int,ARGS[1])
scrSing = Symbol(ARGS[2])
t_int = parse(Int,ARGS[3])

scrSing = :scr2003 # 2003

b = "" # add the model dir here
input_arr = [b * "_basis",b * "_full",b * "timeSeries/8760hours_s" * string(scr)]
resultDir_str = b * "results"

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "conv_s" * string(scr) * "_" * string(scrSing) * "_noH2Imp", forceScr = scrSing,supTsLvl = 1, reportLvl = 2, shortExp = 10, checkRng = (print = true, all = true), coefRng = (mat = (1e-2,1e3), rhs = (1e0,1e3)), scaFac =  (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3))

createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);

optimize!(anyM.optModel)

reportResults(:cost,anyM)
reportResults(:summary,anyM)
reportResults(:exchange,anyM)

reportTimeSeries(:electricity,anyM)

# return storage levels
lvl_df = writeStLvl([:h2Cavern,:reservoir,:pumpedStorage,:redoxBattery,:lithiumBattery],anyM)
printObject(lvl_df,anyM,fileName = "stLvl")

# write duals
relBal_ntup = (enBal = (:electricity,), stBal = (:h2Cavern,:reservoir), excRestr = (:hvac,:hvdc))
dual_df = writeDuals(relBal_ntup,anyM)
printObject(dual_df,anyM,fileName = "dual")


b = "" # add the model dir here
scrSing = :scr1983