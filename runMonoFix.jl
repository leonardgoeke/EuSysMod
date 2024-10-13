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
scenario = string(par_df[id_int,:scenario]) # scenario case

obj_str = time * "_" * spaSco * "_" * scenario

# create scenario and quarter array
scrDir_str = dir_str * "scenarioSetup/" * scenario
scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(dir_str * "scenarioSetup/" * scenario * "/par_scrProb.csv", DataFrame))))

# define in- and output folders
resultDir_str = dir_str * "results"

# input folders
inDir_arr = [dir_str * "_basis", dir_str * "spatialScope/" * spaSco, dir_str * "sectorCoupling/fixed_country", dir_str * "resolution/default_country", scrDir_str, dir_str * "timeSeries/country_" * time * "/general"]
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/general_" * x), ("ini1","ini2","ini3","ini4"))
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/" * x[1] * "/" * x[2]), scrQrt_arr)

#region # * create and solve model


anyM = anyModel(inDir_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 3, frsLvl = 3, shortExp = 5, emissionLoss = false, holdFixed = true);

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

plotSankeyDiagram(anyM, dropDown = tuple(:timestep,), ymlFilter = dir_str * "sankeyYaml/electricity.yml")

#endregion

# ! write storage values for plotting levels

reportStorageLevel(anyM)
import AnyMOD.intCol, AnyMOD.getTsFrs

for x in intersect(keys(anyM.parts.tech), (:h2StorageCavern, :pumpedStorageOpen, :reservoir, :gasStorage, :oilStorage))

    if :stInterIn in keys(anyM.parts.tech[x].var)
        printObject(anyM.parts.tech[x].var[:stInterIn], anyM, fileName = "stInterIn_" * string(x))
        printObject(anyM.parts.tech[x].var[:stInterOut], anyM, fileName = "stInterOut_" * string(x))
    
        # reserve part
        gasDelta_df = rename(anyM.parts.tech[x].var[:stInterIn],:var => :in) |> (x -> innerjoin(x,anyM.parts.tech[:gasStorage].var[:stInterOut], on = intCol(x)))
        gasDelta_df[!,:delta] .= value.(gasDelta_df[!,:in]) .- value.(gasDelta_df[!,:var])

        # seasonal part
        gasLvl_df = sort(anyM.parts.tech[:gasStorage].var[:stLvl], :Ts_dis)
        gasLvl_df[!,:value] = value.(gasLvl_df[!,:var])
        gasLvl_df[!,:Ts_frs] = map(x -> x[end], getTsFrs(gasLvl_df[!,:Ts_dis], anyM.sets[:Ts], anyM.scr.frsLvl))


        # make a random process
        scr_arr = unique(gasLvl_df[!,:scr])
        frs_arr = sort(unique(gasLvl_df[!,:Ts_frs]))

        level_df = DataFrame(run = Int[], y = Int[], Ts_dis = Int[], season = Float64[], delta = Float64[])
        for r in 1:20
            for y in 1:5
                for f in frs_arr
                    scr_int = rand(scr_arr)
                    lvlGas_df = filter(x -> x.Ts_frs == f && x.scr == scr_int, gasLvl_df)[!,[:Ts_dis,:value]]
                    lvlGas_df = innerjoin(lvlGas_df, select(filter(x -> x.scr == scr_int, gasDelta_df),[:Ts_dis, :delta]), on = :Ts_dis)
                    append!(level_df, DataFrame(run = r, y = y, Ts_dis = lvlGas_df[!,:Ts_dis], season = lvlGas_df[!,:value], delta = lvlGas_df[!,:delta]))
                end
            end
        end

        levelAgg_df = DataFrame(run = Int[], step = Int[], value = Float64[])

        for g in groupby(level_df, [:run])
            len_int = length(g[!,:delta])
            delta_arr = g[!,:season] .+ map(x ->g[1:x,:delta], len_int)
            append!(levelAgg_df, DataFrame(run = fill(g[1,:run], len_int), step = 1:len_int, value = delta_arr))
        end

        CSV.write(resultDir_str * "/rndLevel_" * string(x) * "_" * obj_str * ".csv", levelAgg_df)
    end
end