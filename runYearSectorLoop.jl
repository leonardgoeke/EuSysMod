using Gurobi, AnyMOD, CSV, Statistics

dir_str = ""

par_df = CSV.read(dir_str * "settings_benders.csv", DataFrame)

if isempty(ARGS)
    id_int = 3
else
    id_int = parse(Int, ARGS[1])
end

t_int = 8
time = string(par_df[id_int,:time]) # temporal resolution
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope

ini_arr = ["ini01", "ini02", "ini03", "ini04", "ini05", "ini06", "ini07", "ini08", "ini09", "ini10", "ini11", "ini12"]

for year in "scr" .* string.(collect(1982:1986))
    obj_str = time * "_" * spaSco * "_" * year

    # define in- and output folders
    resultDir_str = dir_str * "results/deteministic"
    modDir_str = dir_str * "inputFiles/"
    setupDir_str = dir_str *  "modelSetup/"

    # create scenario folder
    scrDir_str = setupDir_str * "scenarioSetup/" * year
    if !isdir(scrDir_str)
        mkdir(scrDir_str)
        CSV.write(scrDir_str * "/set_scenario.csv", DataFrame(scenario = [year]))
    end

    # input folders
    inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", scrDir_str, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/allEndogenous", setupDir_str * "resolution/default_country", modDir_str * "timeSeries/country_" * time * "_month/general"]
    foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/general_" * x), ini_arr)
    foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/" * year * "/" * x), ini_arr)

    #region # * create and solve model

    anyM = anyModel(inDir_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 4, frsLvl = 0, shortExp = 5, emissionLoss = false, holdFixed = true);

    createOptModel!(anyM)
    setObjective!(:cost, anyM)

    set_optimizer(anyM.optModel, Gurobi.Optimizer)
    set_optimizer_attribute(anyM.optModel, "Method", 2);
    set_optimizer_attribute(anyM.optModel, "NumericFocus", 0);
    set_optimizer_attribute(anyM.optModel, "Crossover", 0);
    set_optimizer_attribute(anyM.optModel, "Threads", t_int);
    set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

    optimize!(anyM.optModel)

    #endregion

    #region # * write results

    reportResults(:summary, anyM, addObjName = true)
    reportResults(:cost, anyM, addObjName = true)
    reportResults(:exchange, anyM, addObjName = true)

    reportTimeSeries(:electricity, anyM)

    #endregion

end