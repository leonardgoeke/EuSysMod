import Pkg; Pkg.activate(".")
# Pkg.instantiate()
# ! import AnyMOD and packages

using AnyMOD, Gurobi

scr = parse(Int,ARGS[1])
t_int = parse(Int,ARGS[2])

b = "" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/8760hours_det",b * "timeSeries/8760hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"

scr = 2
t_int = 4
b = "" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/96hours_det",b * "timeSeries/96hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"

# create and solve model
convM = anyModel(input_arr, resultDir_str, objName = "conv_s" * string(scr), lvlFrs = 2, supTsLvl = 1, reportLvl = 2, shortExp = 10, checkRng = (print = true, all = true), coefRng = (mat = (1e-2,1e3), rhs = (1e0,1e3)), scaFac =  (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3))
createOptModel!(convM)
setObjective!(:cost,convM)

set_optimizer(convM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(convM.optModel, "Method", 2);
set_optimizer_attribute(convM.optModel, "Crossover", 0);
set_optimizer_attribute(convM.optModel, "Threads",t_int);

optimize!(convM.optModel)

objective_value(convM.optModel)

reportResults(:cost,convM)
reportResults(:summary,convM)
reportResults(:exchange,convM)

convM.parts.tech[:reservoir].balSign