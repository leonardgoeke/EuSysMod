using AnyMOD, Gurobi

h = ARGS[1]
sca = ARGS[2]
threads = ARGS[3]

anyM = anyModel(["_basis","_full","timeSeries/" * h * "hours_2010_only2020"],"results", objName = h * "hours" * sca, supTsLvl = 2, shortExp = 5, redStep = (sca == "scale" ? 1.0 : 365/parse(Int, d)), checkRng = true)

createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",tryparse(Int,threads));
set_optimizer_attribute(anyM.optModel, "BarOrder", 1);

optimize!(anyM.optModel)

printIIS(anyM)

reportResults(:summary,anyM)
reportResults(:exchange,anyM)
reportResults(:cost,anyM)