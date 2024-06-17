using Gurobi, AnyMOD, CSV

b = ""

par_df = CSV.read(b * "settings.csv",DataFrame)

if isempty(ARGS)
    id_int = 1 # currently 1 for future and 2 for historic
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
    t_int = parse(Int,ARGS[2]) # number of threads
end

h = string(par_df[id_int,:h])
spa = string(par_df[id_int,:spatialScope])
scr = string(par_df[id_int,:scr])
frsLvl = par_df[id_int,:foresight]

input_arr = [b * "basis", b * "spatialScope/" * spa, b * "timeSeries/" * h * "hours_" * spa * "_" * scr]
resultDir_str = b * "results"

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "mono_" * h * "_" * spa * "_" * scr, frsLvl = frsLvl, supTsLvl = 2, shortExp = 10, reportLvl = 2, repTsLvl = 4);
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);

optimize!(anyM.optModel)

reportTimeSeries(:electricity, anyM)
reportTimeSeries(:h2, anyM)
reportResults(:summary, anyM)
reportResults(:cost, anyM)

reportStorageLevel(anyM)