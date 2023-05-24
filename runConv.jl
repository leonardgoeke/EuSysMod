
# ! import AnyMOD and packages

using AnyMOD, Gurobi

scr = parse(Int,ARGS[1])
t_int = parse(Int,ARGS[2])

b = "" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/8760hours_det",b * "timeSeries/8760hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "conv_s" * string(scr), supTsLvl = 1,reportLvl = 2, shortExp = 10, checkRng = (print = true, all = true), coefRng = (mat = (1e-2,1e3), rhs = (1e0,1e3)), scaFac = (capa = 1e2, capaStSize = 1e3, insCapa = 1e1, dispConv = 0.4e1, dispSt = 1e1, dispExc = 1e2, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0))
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


scr = 2
t_int = 4
b = "" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/96hours_det",b * "timeSeries/96hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"