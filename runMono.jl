using Gurobi, AnyMOD, CSV, Statistics

#region # * define inputs

dir_str = ""
modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 2
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope
scenario = string(par_df[id_int,:scenario]) # scenario case
techs = string(par_df[id_int,:techs]) # available technologies
security = string(par_df[id_int,:security]) # security settings
inOos = string(par_df[id_int,:inputOutOfSample]) # capacity folder for out-of-sample testing

name_str = convert(String,par_df[id_int,:name])
checkDet_boo = scenario in "scr" .* string.(1982:2016)

# create scenario and quarter array
if checkDet_boo # case of single year
	scrQrt_arr = map(x -> (scenario, "ini" * (x < 10 ? "0" : "") * string(x)), 1:12)
	# create scenario folder
	scrFolDir_str = setupDir_str * "scenarioSetup/"  * spaSco
	scrDir_str = scrFolDir_str * "/" * scenario
	if !isdir(scrFolDir_str) mkdir(scrFolDir_str) end
	if !isdir(scrDir_str)
		mkdir(scrDir_str)
		CSV.write(scrDir_str * "/set_scenario.csv", DataFrame(scenario = [scenario]))
	end	
else
	scrDir_str = setupDir_str * "scenarioSetup/"  * spaSco * "/" * scenario * "_" * "month"
	scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(scrDir_str * "/par_scrProb.csv", DataFrame))))
end

# define in- and output folders
resultDir_str = dir_str * "results"

# input folders
# ! input folders
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "securitySetup/" * security, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/preselected_" * techs, setupDir_str * "resolution/default_country", scrDir_str, modDir_str * "timeSeries/country_" * time * "_month/general"]
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/general_" * x), unique(getindex.(scrQrt_arr,2)))
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * "month/" * x[1] * "/" * x[2]), scrQrt_arr)

if inOos != "missing"
	push!(inDir_arr, dir_str * "inputOutOfSample/" * inOos)
end

restDir!(dir_str * "results/" * name_str)

#endregion

#region # * create and solve model

anyM = anyModel(inDir_arr, dir_str * "results/" * name_str, objName = name_str, supTsLvl = 2, repTsLvl = 4, frsLvl = checkDet_boo ? 0 : 3, shortExp = 5, emissionLoss = false, holdFixed = true);

createOptModel!(anyM)
setObjective!(:cost, anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "NumericFocus", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads", t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary, anyM, addObjName = true)
reportResults(:cost, anyM, addObjName = true)
reportResults(:exchange, anyM, addObjName = true)

#endregion

#region # * write input for out-of-sample testing

if inOos == "missing"
    # create directory
    outDir_str = dir_str * "inputOutOfSample/" * name_str * "/"
    restDir!(outDir_str)

    parDef_dic = defineParameter(anyM.options, anyM.report)

    # write capacity values
    for sys in (:tech, :exc)
        part_dic = getfield(anyM.parts, sys)
        for sSym in keys(part_dic)
            for capaSym in filter(x -> any(occursin.(["capa","exp"], string(x))), keys(part_dic[sSym].var))
                # get value capacity variable
                var_df = copy(part_dic[sSym].var[capaSym])
                var_df[!,:value] = value.(var_df[!,:var])
                select!(var_df, Not([:var]))
                # write parameter fle
                par_sym = Symbol(capaSym,"Fix")
                writeParameterFile!(anyM, var_df, par_sym, parDef_dic[par_sym], outDir_str * "par_" * string(sSym,"_",capaSym))
            end
        end
    end
end

#endregion