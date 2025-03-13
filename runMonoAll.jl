using AnyMOD, Gurobi, CSV

include("functions.jl")

dir_str = "" 
par_df = CSV.read(dir_str * "settings.csv",DataFrame)

if isempty(ARGS)
    id_int = 7 # currently 1 for future and 2 for historic
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
    t_int = parse(Int,ARGS[2]) # number of threads
end

h = string(par_df[id_int,:time])
spa = convert(String, par_df[id_int,:spatialScope])
sco = convert(String, par_df[id_int,:case])
scr = convert(String, par_df[id_int,:scenario])
frs = par_df[id_int,:foresight]

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = convert(String,par_df[id_int,:spatialScope]) # spatial scope
case = convert(String,par_df[id_int,:case]) # future or historic data
scr = convert(String,par_df[id_int,:scenario]) # scenario case
foresight = par_df[id_int,:foresight] # scenario case

# determine scenario inputs
checkDet_boo = scr in "scr" .* string.(case == "fut" ? (2080:2099) : (1995:2014))  
scr_arr, ~ = generateScrInfo(checkDet_boo, scr, dir_str, case)

for s in unique(getindex.(scr_arr, 1))

    #region # define inputs
    ~, scrDir_str = generateScrInfo(true, convert(String,s), dir_str, case)

    # define input and output folder
    input_arr = [dir_str * "basis", dir_str * "spatialScope/" * spaSco, scrDir_str, dir_str * "timeSeries/" * case * "_" * time * "h/general"]
    foreach(x -> push!(input_arr, dir_str * "timeSeries/" * case * "_" * time * "h/" * x), [s])
    resultDir_str = dir_str * "results"

    name_str = "mono_" * time * "_" * spaSco * "_" * case * "_" * s * "_" * string(foresight)

    #endregion

    #region # solve model

    # create and solve model
    anyM = anyModel(input_arr, resultDir_str, objName = name_str, frsLvl = foresight, supTsLvl = 2, shortExp = 10, reportLvl = 2, repTsLvl = 4);
    createOptModel!(anyM)
    setObjective!(:cost,anyM)

    set_optimizer(anyM.optModel, Gurobi.Optimizer)
    set_optimizer_attribute(anyM.optModel, "Method", 2);
    set_optimizer_attribute(anyM.optModel, "Crossover", 0);
    set_optimizer_attribute(anyM.optModel, "Threads",t_int);

    optimize!(anyM.optModel)

    reportResults(:summary, anyM)
    reportResults(:exchange, anyM)
    reportResults(:cost, anyM)

    #endregion

end 