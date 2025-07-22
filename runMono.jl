using Gurobi, AnyMOD, CSV, Statistics
include("functions.jl")

#region # * define inputs

dir_str = ""
modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 28
    t_int = 14
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
scenario = convert(String,par_df[id_int,:scenario]) # scenario case
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

#region # * create and solve model

anyM = anyModel(inDir_arr, resultDir_str, objName = name_str, supTsLvl = 2, repTsLvl = 4, frsLvl = checkDet_boo ? 0 : 3, shortExp = 5, emissionLoss = false, holdFixed = true);

createOptModel!(anyM)
setObjective!(:cost, anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads", t_int);
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);
set_optimizer_attribute(anyM.optModel, "NumericFocus", 2);

optimize!(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary, anyM, addObjName = true)
reportResults(:cost, anyM, addObjName = true)
reportResults(:exchange, anyM, addObjName = true)
reportStorageLevel(anyM)
reportTimeSeries(:electricity, anyM)

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
            for capaSym in filter(x -> any(occursin.(["capa","exp"], string(x))) && !any(occursin.(["Inter","Season"], string(x))), keys(part_dic[sSym].var))
                # get value capacity variable
                var_df = copy(part_dic[sSym].var[capaSym])
                var_df[!,:value] = map(x -> x < 1e-5 ? 0.0 : x, value.(var_df[!,:var]))
                select!(var_df, Not([:var]))
                # add potentially missing dir column
                if sys == :exc
                    if part_dic[sSym].dir && !(:dir in AnyMOD.namesSym(var_df))
                        var_df[!, :dir] .= true
                    end
                end
                # write parameter file
                par_sym = Symbol(capaSym, "Fix")
                writeParameterFile!(anyM, var_df, par_sym, parDef_dic[par_sym], outDir_str * "par_" * string(sSym,"_",capaSym))
            end
        end
    end
end

#endregion
