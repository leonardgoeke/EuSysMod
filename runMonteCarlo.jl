using Gurobi, AnyMOD, CSV

dir_str = "C:/Git/EuSysMod/"
rngYear_arr = collect(1982:2016)

par_df = CSV.read(dir_str * "settings_benders.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope
scenario = string(par_df[id_int,:scenario]) # scenario case
techs = string(par_df[id_int,:techs]) # available technologies
foresight = string(par_df[id_int,:foresight]) # foresight

# keep these? only relevant to read right folder
solve = par_df[id_int,:solve]
cutDel = par_df[id_int,:cutDel]
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]
t_int = 4

#region # * setup input folders and data

name_str = convert(String,par_df[id_int,:name])
frs_dic = Dict("month" => 12, "3month" => 4)

# problem settings
lowLimDual = 0.05
rngTar_tup = (mat = (1e-2,1e5), rhs = (1e-2,1e2))
scal_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e2, dispSt = 1e3, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)
info_ntup = (name = name_str, frsLvl = 3, supTsLvl = 2, repTsLvl = 4, shortExp = 5) 

modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"
monteDir_str = dir_str * "inputMonteCarlo/" * name_str
resultDir_str = dir_str * "results/" * name_str * "/" * "monteCarlo"
restDir!(resultDir_str) 


# define input folder
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter/onlyMonteCarlo",
                setupDir_str * "techSetup/preselected_" * techs, setupDir_str * "resolution/default_country", setupDir_str * "spatialScope/" * spaSco,
                    monteDir_str * "/storageFixes", monteDir_str * "/capacityFixes", monteDir_str * "/dualValues"]

# add starting levels of storage
startLvl_dic = Dict{Symbol,DataFrame}()
for file in readdir(monteDir_str * "/startingLvl")
    startLvl_dic[Symbol(split(file,"_")[2])] = CSV.read(monteDir_str * "/startingLvl/" * file,DataFrame)
end

#endregion

scr_dic = Dict(parse(Int, x[end-1:end]) => getindex.(filter(y -> y[2] == x,scrQrt_arr ),1) for x in unique(getindex.(scrQrt_arr,2)))

#region # * perform monte carlo analysis

allLvl_df = DataFrame(timestep_dispatch = String[], region_dispatch = String[], technology = String[], scenario = String[], value = Float64[], step = Int64[])
allSum_df = DataFrame(region_dispatch = String[], technology = String[], carrier = String[], scenario = String[], timestep_foresight = String[], id = String[], variable = Symbol[], value = Float64[], step = Int64[])
allCost_df = DataFrame(region = String[], region_from = String[], region_to = String[], technology = String[], exchange = String[], carrier = String[], variable = Symbol[], value = Float64[], step = Int64[])
step_int = 1

while step_int <= 120
    
    ini_int = step_int % frs_dic[foresight] |> (x -> x == 0 ? frs_dic[foresight] : x)

    # select random year/scenario
    #year_int = rand(rngYear_arr)
    year_int = replace(rand(scr_dic[ini_int]),"scr" => "")
    
    println("Run step ", step_int, " with data for year ", year_int)

    # create folder for scenario definition
    restDir!(setupDir_str * "scenarioSetup/scr" * string(year_int))
    CSV.write(setupDir_str * "scenarioSetup/scr" * string(year_int) * "/set_scenario.csv", DataFrame(scenario = ["scr" * string(year_int)]))

    # define input folders
    tsFold_str = modDir_str * "timeSeries/country" * "_" * time * "_" * foresight * "/"
    tsDir_arr = [setupDir_str * "scenarioSetup/scr" * string(year_int),  tsFold_str * "general", tsFold_str * "general_ini" * (ini_int <= 9 ? "0" : "") * string(ini_int), tsFold_str * "scr" * string(year_int) * "/ini" * (ini_int <= 9 ? "0" : "") * string(ini_int)]

    # run monte-carlo step
    sub_m, startLvl_dic = @suppress runMonteCarloStep!(vcat(inDir_arr, tsDir_arr), startLvl_dic, step_int, ini_int, resultDir_str, t_int, info_ntup, rngTar_tup, scal_tup);

    # write aggregated dispatch results
    sum_df = select(filter(x -> x.scenario != "none", reportResults(:summary, sub_m, addObjName = false, rtnOpt = (:csvDf,))), Not([:timestep_superordinate_dispatch]))
    sum_df[!,:step] .= step_int
    append!(allSum_df, sum_df)

    cost_df = select(reportResults(:cost, sub_m, addObjName = false, rtnOpt = (:csvDf,)), Not([:timestep_superordinate_dispatch]))
    cost_df[!,:step] .= step_int
    append!(allCost_df, cost_df)

    # write storage levels
    lvl_df = select(reportStorageLevel(sub_m, false, (:df,)),Not([:timestep_superordinate_expansion,:timestep_superordinate_dispatch,:carrier,:mode,:id]))
    lvl_df = filter(x -> occursin(sub_m.sets[:Ts].nodes[sub_m.subPro[1]].val, x.timestep_dispatch), lvl_df)
    lvl_df[!,:step] .= step_int
    append!(allLvl_df, lvl_df)

    step_int = step_int + 1

end

#endregion

#region # * write results_

CSV.write(dir_str * "results/" * name_str * "/results_storageLvl_" * name_str * "_monteCarlo.csv", allLvl_df)
CSV.write(dir_str * "results/" * name_str * "/results_summary_" * name_str * "_monteCarlo.csv", allSum_df)
CSV.write(dir_str * "results/" * name_str * "/results_cost_" * name_str * "_monteCarlo.csv", allCost_df)

#endregion


# ! debug
# ! code untere grenze auf duals
# ! run tests: anderes mit DAC, höherer wert lss, mehr regionen