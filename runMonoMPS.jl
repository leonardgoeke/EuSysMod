using Gurobi, AnyMOD, CSV, Statistics
include("functions.jl")

#region # * define inputs

dir_str = ""
modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 7
    t_int = 8
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = convert(String,par_df[id_int,:spatialScope]) # spatial scope
scenario = convert(String,par_df[id_int,:scenario]) # scenario case
techs = string(par_df[id_int,:techCase]) # available technologies
imp = string(par_df[id_int,:importCase]) # fuel import setup 
reso = string(par_df[id_int,:resolution]) # spatial resolution
security = string(par_df[id_int,:security]) # security settings
inOos = string(par_df[id_int,:inputOutOfSample]) # capacity folder for out-of-sample testing

t_int = par_df[id_int,:threads]

name_str = convert(String,par_df[id_int,:name])
checkDet_boo = scenario in "scr" .* string.(1982:2016)

# create scenario and quarter array
scrQrt_arr, scrDir_str = generateScrInfo(checkDet_boo, scenario, setupDir_str, spaSco)

# define in- and output folders
resultDir_str = dir_str * "results"

# input folders
# ! input folders
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "securitySetup/" * security, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/" * spaSco * "/" * techs, setupDir_str * "importCase/" * spaSco * "/" * imp, setupDir_str * "resolution/" * reso, scrDir_str, modDir_str * "timeSeries/country_" * time * "_month/general"]
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/general_" * x), unique(getindex.(scrQrt_arr,2)))
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * "month/" * x[1] * "/" * x[2]), scrQrt_arr)

if inOos != "missing"
	push!(inDir_arr, dir_str * "inputOutOfSample/" * inOos)
end

resultDir_str = dir_str * "results/" * (checkDet_boo ? "deterministic" : name_str)
if !checkDet_boo restDir!(resultDir_str) end

#endregion

#region # * create and solve model

anyM = anyModel(inDir_arr, resultDir_str, objName = name_str, supTsLvl = 2, repTsLvl = 4, frsLvl = checkDet_boo ? 0 : 3, shortExp = 5, emissionLoss = false, holdFixed = true);

createOptModel!(anyM)
setObjective!(:cost, anyM)

write_to_file(anyM.optModel, name_str * ".mps")


#endregion

