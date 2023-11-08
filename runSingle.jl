import Pkg; Pkg.activate(".")
# Pkg.instantiate()
# ! import AnyMOD and packages

using AnyMOD, Gurobi

scr = parse(Int,ARGS[1])
scrSing = parse(Symbol,ARGS[2])
t_int = parse(Int,ARGS[3])


b = "" # add the model dir here
input_arr = [b * "_basis",b * "_full",b * "timeSeries/8760hours_det",b * "timeSeries/8760hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"

# create and solve model
convM = anyModel(input_arr, resultDir_str, objName = "conv_s" * string(scr), forceScr = scrSing,supTsLvl = 1, reportLvl = 2, shortExp = 10, checkRng = (print = true, all = true), coefRng = (mat = (1e-2,1e3), rhs = (1e0,1e3)), scaFac =  (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3))

createOptModel!(convM)
setObjective!(:cost,convM)

set_optimizer(convM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(convM.optModel, "Method", 2);
set_optimizer_attribute(convM.optModel, "Crossover", 0);
set_optimizer_attribute(convM.optModel, "Threads",t_int);

optimize!(convM.optModel)

reportResults(:cost,convM)
reportResults(:summary,convM)
reportResults(:exchange,convM)

reportTimeSeries(:electricity,convM)

# write storage levels
for tSym in (:h2Cavern,:reservoir,:pumpedStorage,:redoxBattery,:lithiumBattery)
	stLvl_df = combine(x -> (lvl = sum(value.(x.var)),), groupby(convM.parts.tech[tSym].var[:stLvl],[:Ts_dis,:scr]))
	stLvl_df = unstack(sort(unique(stLvl_df),:Ts_dis),:scr,:lvl)
	CSV.write(resultDir_str * "/stLvl_" * string(tSym) * "_" * string(scrSing) * ".csv",stLvl_df)
end
