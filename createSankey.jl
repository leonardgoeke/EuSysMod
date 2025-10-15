using Gurobi, AnyMOD, CSV, Statistics
include("functions.jl")

#region # * define inputs

dir_str = "C:/Git/EuSysMod/"
modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

id_int = 12 # 12 -> inter_all, 13 -> noInter_all

time = "672h"
scenario = convert(String,par_df[id_int,:scenario]) # scenario case
reso = string(par_df[id_int,:resolution]) # spatial resolution
techs = string(par_df[id_int,:techCase]) # available technologies
imp = string(par_df[id_int,:importCase]) # fuel import setup 

reso = string(par_df[id_int,:resolution]) # spatial resolution
security = string(par_df[id_int,:security]) # security settings
inOos = string(par_df[id_int,:inputOutOfSample]) # capacity folder for out-of-sample testing
infeasTop = par_df[id_int,:infeasTop] 

t_int = par_df[id_int,:threads]

name_str = convert(String,par_df[id_int,:name])
checkDet_boo = scenario in "scr" .* string.(1982:2016)

# create scenario and quarter array
scrQrt_arr, scrDir_str = generateScrInfo(checkDet_boo, scenario, setupDir_str)

# define in- and output folders
resultDir_str = dir_str * "results"

# input folders
# ! input folders
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "infeasTop/" * infeasTop, setupDir_str * "securitySetup/" * security, setupDir_str * "techSetup/" * techs, setupDir_str * "importCase/" * imp, setupDir_str * "resolution/" * reso, scrDir_str, modDir_str * "timeSeries/country_" * time * "_month/general"]
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/general_" * x), unique(getindex.(scrQrt_arr,2)))
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * "month/" * x[1] * "/" * x[2]), scrQrt_arr)


if inOos != "missing"
	push!(inDir_arr, dir_str * "inputOutOfSample/" * inOos)
end

resultDir_str = dir_str * "results/" * (checkDet_boo ? "deterministic" : name_str)
if !checkDet_boo restDir!(resultDir_str) end

#endregion


# create model object
anyM = anyModel(inDir_arr, resultDir_str, objName = name_str, supTsLvl = 2, repTsLvl = 4, frsLvl = checkDet_boo ? 0 : 3, shortExp = 5, emissionLoss = false, holdFixed = true);

# create sankey diagram

file_str = "H:/2025_03_26 Grafiken and Ergebnisse ESCU/fullResults/inter_all_total32_ext8_reference/results_summary_inter_all_total32_ext8_reference.csv"
#file_str = "H:/2025_03_26 Grafiken and Ergebnisse ESCU/fullResults/noInter_all_total32_ext8_reference/results_summary_noInter_all_total32_ext8_reference.csv"


#scrCases = ["worstCase" => ("scr1985", "scr2006", "scr2005", "scr1984","scr2004", "scr2007", "scr1995", "scr1995", "scr2000", "scr2012", "scr1985", "scr2004"),
#				"bestCase" => ("scr1984","scr1995","scr2006","scr2001","scr1987","scr1998","scr1999","scr2005","scr2012","scr1990","scr1991","scr1999")]

#plotSankeyDiagram(anyM, name = "all", dropDown = (:scenario,), dataIn = file_str, scrCases = scrCases, ymlFilter = dir_str * "sankeyYaml/all_moreAgg.yml")
#plotSankeyDiagram(anyM, name = "electricity", dropDown = (:scenario,), dataIn = file_str, scrCases = scrCases, ymlFilter = dir_str * "sankeyYaml/electricity_moreAgg.yml")


plotSankeyDiagram(anyM, name = "all", dropDown = (:scenario,), dataIn = file_str, minVal = 1.0, ymlFilter = dir_str * "sankeyYaml/all_moreAgg.yml")
#plotSankeyDiagram(anyM, name = "onlyElec", dropDown = (:scenario,), dataIn = file_str, minVal = 1.0, ymlFilter = dir_str * "sankeyYaml/electricity_moreAgg.yml")