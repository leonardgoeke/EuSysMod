using AnyMOD, Gurobi

d = ARGS[1]
sca = ARGS[2]
threads = ARGS[3]

anyM = anyModel(["_basis","_full","timeSeries/" * d * "days_2010"],"results", objName = d * "days_" * sca, supTsLvl = 2, shortExp = 5, redStep = (sca == "scale" ? 1.0 : 365/parse(Int, d)))

createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",tryparse(Int,threads));
set_optimizer_attribute(anyM.optModel, "BarOrder", 1);

optimize!(anyM.optModel)

reportResults(:summary,anyM)
reportResults(:exchange,anyM)
reportResults(:cost,anyM)