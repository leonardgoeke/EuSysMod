using AnyMOD, Gurobi, CSV, Statistics


# ! string here define scenario, overwrite ARGS with respective values for hard-coding scenarios according to comments
h = "96" # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
grid = "_gridExp" # scenario for grid expansion, can be "_gridExp" and "_noGridExp"
t_int = 4 # number of threads

# Number of Scenario:
i=3

obj_str = h * "hours_" * "hoursHeu" * grid
resultDir_str = "results"

inputMod_arr = ["_basis",grid,"timeSeries/" * h * "hours_2008_only2040","Scenario/Scenario_$i"]


#region # * create and solve main model

anyM = anyModel(inputMod_arr,resultDir_str, objName = "Scenario_$i", supTsLvl = 2, shortExp =5, redStep = 1.0, emissionLoss = false, holdFixed = true)



createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

#checkIIS(anyM)

#endregion

#region # * write results

reportResults(:summary,anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:exchange,anyM, addObjName = true)
reportResults(:cost,anyM, addObjName = true)
#endregion


printObject(anyM.parts.bal.cns[:capaBal],anyM)
