using Gurobi, AnyMOD, CSV, Statistics

dir_str = "C:/Users/pacop/Desktop/git/EuSysMOD/"

par_df = CSV.read(dir_str * "settings_benders.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int, ARGS[1])
    t_int = parse(Int, ARGS[2]) # number of threads
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope

for year in "scr" .* string.(collect(1982:2016))

    println(year)
    obj_str = time * "_" * spaSco * "_" * year

    # define in- and output folders
    resultDir_str = dir_str * "results/sectorCoupling"

    # create scenario folder
    scrDir_str = "scenarioSetup/" * year
    if !isdir(dir_str * scrDir_str)
        mkdir(dir_str * scrDir_str)
        CSV.write(dir_str * scrDir_str * "/set_scenario.csv", DataFrame(scenario = [year]))
    end

    # input folders
    inDir_arr = [dir_str * "_basis", dir_str * scrDir_str, dir_str * "spatialScope/" * spaSco, dir_str * "sectorCoupling/endogenous_heatAndTransport", dir_str * "resolution/default_country", dir_str * "timeSeries/country_" * time * "/general"]

    foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/general_" * x), ("ini1","ini2","ini3","ini4"))
    foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/" * year * "/" * x), ("ini1","ini2","ini3","ini4"))

    #region # * create and solve model

    anyM = anyModel(inDir_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 3, frsLvl = 0, shortExp = 5, emissionLoss = false, holdFixed = true);

    createOptModel!(anyM)
    setObjective!(:cost, anyM)

    set_optimizer(anyM.optModel, Gurobi.Optimizer)
    set_optimizer_attribute(anyM.optModel, "Method", 2);
    set_optimizer_attribute(anyM.optModel, "NumericFocus", 0);
    set_optimizer_attribute(anyM.optModel, "Crossover", 0);
    set_optimizer_attribute(anyM.optModel, "Threads", t_int);
    set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

    optimize!(anyM.optModel)
    objective_value(anyM.optModel)

    #endregion

    #region # * write results

    reportResults(:summary, anyM, addObjName = true)
    reportResults(:cost, anyM, addObjName = true)
    reportResults(:exchange, anyM, addObjName = true)

    reportTimeSeries(:electricity, anyM)

    #endregion

end

printObject(anyM.parts.tech[:oilStorage].cns[:stBal], anyM)
reportStorageLevel(anyM)

anyM.parts.tech[:oilStorage].cns[:stBal]