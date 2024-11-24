using Gurobi, AnyMOD, CSV, Statistics

dir_str = "C:/Git/EuSysMod/"

par_df = CSV.read(dir_str * "settings_benders.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int, ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
techs = string(par_df[id_int,:techs]) # available technologies
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope
scenario = string(par_df[id_int,:scenario]) # scenario case
foresight = string(par_df[id_int,:foresight]) # foresight
t_int = par_df[id_int,:threads]

obj_str = convert(String,par_df[id_int,:name])

modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

# create scenario and quarter array
scrDir_str = setupDir_str * "scenarioSetup/" * scenario * "_" * foresight
scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(scrDir_str * "/par_scrProb.csv", DataFrame))))

# define in- and output folders
resultDir_str = dir_str * "results"

# input folders
unique(getindex.(scrQrt_arr,2))
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/preselected_" * techs, setupDir_str * "resolution/default_country", scrDir_str, modDir_str * "timeSeries/country_" * time * "_" * foresight * "/general"]
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * foresight * "/general_" * x), unique(getindex.(scrQrt_arr,2)))
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * foresight * "/" * x[1] * "/" * x[2]), scrQrt_arr)


#region # * create and solve model

anyM = anyModel(inDir_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 4, frsLvl = 3, shortExp = 5, emissionLoss = false, holdFixed = true);


plotSankeyDiagram(anyM, ymlFilter  = "C:/Git/EuSysMod/sankeyYaml/simplify_stuttgart.yml", dataIn = "C:/Users/lgoeke/Downloads/2024-11-02 STRise/extreme/worstCase.csv")
