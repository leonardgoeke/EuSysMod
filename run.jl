using Gurobi, AnyMOD, CSV, Statistics

b = "C:/Git/EuSysMod/"

par_df = CSV.read(b * "settings_nonDistr.csv", DataFrame)

if isempty(ARGS)
    id_int = 2
    t_int = 4
else
    id_int = parse(Int, ARGS[1])
    t_int = parse(Int, ARGS[2]) # number of threads
end

space = string(par_df[id_int,:space]) # spatial resolution 
time = string(par_df[id_int,:time]) # temporal resolution
res = string(par_df[id_int,:resolution]) # resolution
scenario = string(par_df[id_int,:scenario]) # scenario case

obj_str = space * "_" * time * "_" * res * "_" * scenario

# create scenario array and create temp folder with file
if occursin("-", scenario)
    scr_arr = split(scenario, "-") |> (x -> string.(parse.(Int, x[1]):parse(Int, x[2])))
else
    scr_arr = split(scenario, ",") |> x -> string.(x)
end

scrDir_str = b * "temp/" * obj_str
if isdir(scrDir_str) rm(scrDir_str, recursive = true) end
mkdir(scrDir_str)
CSV.write(scrDir_str * "/set_scenario.csv", DataFrame(scenario = "scr" .* scr_arr))

# define in- and output folders
resultDir_str = b * "results"

inputMod_arr = [b * "_basis", b * "resolution/" * res, scrDir_str, b * "timeSeries/" * space * "_" * time * "/general"]
foreach(x -> push!(inputMod_arr, b * "timeSeries/" * space * "_" * time * "/general_" * x), ("ini1","ini2","ini3","ini4"))
foreach(x -> push!(inputMod_arr, b * "timeSeries/" * space * "_" * time * "/scr" * x), scr_arr)

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

#region # * write capacity as fixed parameters 

res_dic, ~, ~ = writeResult(anyM, [:capa, :exp, :mustCapa, :mustExp], fltSt = false)

coefRng_tup = (mat = (1e-2, 1e4), rhs = (1e0, 1e5))
scaFac_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e3, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
modOpt_tup = (inputDir = filter(x -> !occursin("timeSeries",x), inputMod_arr), resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRng_tup, scaFac = scaFac_tup)

feasFix_dic = getFeasResult(modOpt_tup, res_dic, Dict{Symbol,Dict{Symbol,Dict{Symbol,DataFrame}}}() , t_int, 0.001, Gurobi.Optimizer, roundDown = 5)[1]


writeFixToFiles(res_dic, feasFix_dic, resultDir_str * "/capacityFix_" * obj_str, anyM)

#endregion

# TODO only write capa -> new script to run in monte carlo way