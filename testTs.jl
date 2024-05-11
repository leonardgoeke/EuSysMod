using AnyMOD, Gurobi, CSV

b = "C:/Git/EuSysMod/"

par_df = CSV.read(b * "settings.csv",DataFrame)

if isempty(ARGS)
    id_int = 2 # currently 1 for future and 2 for historic
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
    t_int = parse(Int,ARGS[2]) # number of threads
end

h = string(par_df[id_int,:h])
scr = string(par_df[id_int,:scr])

input_arr = [b * "basis",b * "timeSeries/" * h * "hours_" * string(scr)]
resultDir_str = b * "results"

# ! full stochastic model

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = h * scr, supTsLvl = 1, reportLvl = 2, repTsLvl = 4, forceScr = :scr2003);
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);

optimize!(anyM.optModel)

plotSankeyDiagram(anyM, dropDown = (:timestep, :scenario), fontSize = 16, digVal = 0)
reportResults(:summary, anyM, expVal = true)
reportResults(:cost, anyM)
reportResults(:exchange, anyM, expVal = true)

reportTimeSeries(:h2,anyM)

