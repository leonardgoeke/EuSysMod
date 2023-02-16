using AnyMOD, Gurobi, CSV, Statistics

# ! string here define scenario, overwrite ARGS with respective values for hard-coding scenarios according to comments
h = ARGS[1] # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
scr = ARGS[2]
t_int = parse(Int,ARGS[3]) # number of threads

input_arr = ["_basis",scr,"timeSeries/" * h * "hours_2008"]
resultDir_str = "results"

anyM = anyModel(input_arr, resultDir_str, objName = "pathway_h" * h * "_" * scr, supTsLvl = 2, reportLvl = 2, shortExp = 5, emissionLoss = false)
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);
optimize!(anyM.optModel)

reportResults(:summary,anyM)

#endregion






