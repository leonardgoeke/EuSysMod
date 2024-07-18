using AnyMOD, Gurobi, CSV, Statistics

b = "C:/Git/EuSysMOD/"

par_df = CSV.read(b * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int, ARGS[1])
    t_int = parse(Int, ARGS[2]) # number of threads
end

space = string(par_df[id_int,:space]) # spatial resolution 
time = string(par_df[id_int,:time]) # temporal resolution
scenario = string(par_df[id_int,:scenario]) # scenario case

obj_str = space * "_" * time * "_" * scenario * "_testing"
inputMod_arr = [b * "_basis", b * "timeSeries/" * space * "_" * time * "_" * scenario]
resultDir_str = b * "results"


#region # * create and solve model

anyM = anyModel(inputMod_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 3, frsLvl = 3, shortExp = 5, emissionLoss = false, holdFixed = true);
createOptModel!(anyM)
setObjective!(:cost, anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads", t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)
objective_value(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary, anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:cost, anyM, addObjName = true)
reportResults(:exchange, anyM, addObjName = true)

reportTimeSeries(:electricity, anyM)

#endregion