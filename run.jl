using AnyMOD, Gurobi, CSV, Statistics

b = "C:/Git/EuSysMod/"

par_df = CSV.read(b * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int, ARGS[1])
    t_int = parse(Int, ARGS[2]) # number of threads
end

time = string(par_df[id_int,:time]) # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
space = string(par_df[id_int,:space]) # scenario 

obj_str = time * "_" * space * "_testing"
inputMod_arr = [b * "_basis", b * "timeSeries/" * time * "_" * space]
resultDir_str = b * "results"


#region # * create and solve model

anyM = anyModel(inputMod_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 3, shortExp = 5, emissionLoss = false, holdFixed = true);

createOptModel!(anyM)
setObjective!(:cost, anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads", t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary, anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:cost, anyM, addObjName = true)
reportResults(:exchange, anyM, addObjName = true)

plotSankeyDiagram(anyM, dropDown = (:timestep,), ymlFilter = b * "all.yml")
reportTimeSeries(:electricity, anyM)

#endregion