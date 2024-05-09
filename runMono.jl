using AnyMOD, Gurobi, CSV
using CairoMakie, Colors, Random

b = "C:/Git/EuSysMod/"

include(b * "functions.jl")
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

resData_df = DataFrame(case = Symbol[], variable = String[], value = Float64[])

# ! full stochastic model

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = h * scr, supTsLvl = 1, reportLvl = 2);
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);

optimize!(anyM.optModel)

anyM.graInfo.colors["h2"] = anyM.graInfo.colors["hydrogen"]
plotSankeyDiagram(anyM, dropDown = (:timestep, :scenario), fontSize = 16, digVal = 0)

append!(resData_df,getAggRes(anyM, :all))

# ! solve for each scenario seperately

allScr_arr = filter(x -> x != :none, Symbol.(getfield.(collect(values(anyM.sets[:scr].nodes)),:val)))
for specScr in allScr_arr
    println(specScr)
    
    @suppress begin
        anyM = anyModel(input_arr, resultDir_str, objName = h * scr * string(specScr), supTsLvl = 1, reportLvl = 2, forceScr = specScr);
        createOptModel!(anyM)
        setObjective!(:cost,anyM)
        
        set_optimizer(anyM.optModel, Gurobi.Optimizer)
        set_optimizer_attribute(anyM.optModel, "Method", 2);
        set_optimizer_attribute(anyM.optModel, "Crossover", 0);
        set_optimizer_attribute(anyM.optModel, "Threads",t_int);
        
        optimize!(anyM.optModel)
        append!(resData_df,getAggRes(anyM, specScr))
    end

end

CSV.write(b * "results/" * h * scr * "_resData.csv",resData_df)