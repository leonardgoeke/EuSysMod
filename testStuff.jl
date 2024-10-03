

import AnyMOD.prepareTechs!, AnyMOD.addRetrofitting!, AnyMOD.addInsCapa!, AnyMOD.removeFixed!, AnyMOD.distributedMapping!
import AnyMOD.cnsCont, AnyMOD.prepareExc!, AnyMOD.getAncestors, AnyMOD.getNodesLvl, AnyMOD.graInfo, AnyMOD.addRetrofitting!, AnyMOD.addInsCapa!, 		AnyMOD.removeFixed!, AnyMOD.getElapsed, AnyMOD.getDescendants

import AnyMOD.sysInt, AnyMOD.createFullString, AnyMOD.presetDispatchParameter!, AnyMOD.createExpCap!, AnyMOD.createCapaCns!, AnyMOD.createOprVarCns!
import AnyMOD.computeDesFac!, AnyMOD.prepareMustOut!, AnyMOD.createCapaRestrMap!, AnyMOD.createDispVar!

import AnyMOD.collectKeys, AnyMOD.createConvBal, AnyMOD.orderDim
import AnyMOD.createTech!, AnyMOD.createRetroConst!, AnyMOD.createCns, AnyMOD.createExc!
import AnyMOD.createTradeVarCns!
import AnyMOD.getTechEnerBal, AnyMOD.filterCarrier, AnyMOD.aggUniVar
import AnyMOD.cnsCont, AnyMOD.createPotDisp, AnyMOD.matchSetParameter, AnyMOD.getUpBound, AnyMOD.orderDf
import AnyMOD.namesSym, AnyMOD.aggCol!, AnyMOD.capaSizeSeasonInter


# ? Object creation
dir_str = "C:/Git/EuSysMod/"

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
inDir_arr = [dir_str * "_basis", dir_str * "spatialScope/" * spaSco, dir_str * "heatSector/fixed_country", dir_str * "resolution/default_country", scrDir_str, dir_str * "timeSeries/country_" * time * "/general"]
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/general_" * x), ("ini1","ini2","ini3","ini4"))
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/" * x[1] * "/" * x[2]), scrQrt_arr)

#region # * create and solve model

anyM = anyModel(inDir_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 3, frsLvl = 3, shortExp = 5, emissionLoss = false, holdFixed = true);

filter(x -> x.Ts_dis == 6, propPar_df)

# ! scr stuff

allScr_arr = filter(x -> x != 0, getfield.(collect(values(anyM.sets[:scr].nodes)), :idx))
prop_df = flatten(flatten(DataFrame(Ts_dis  = [getfield.(getNodesLvl(anyM.sets[:Ts], lvl_int == 0 ? anyM.supTs.lvl : lvl_int), :idx)], scr = [allScr_arr]), :Ts_dis), :scr)

# assigns probabilities defined as parameters
if :scrProb in collectKeys(keys(anyM.parts.obj.par))
    prop_df = matchSetParameter(prop_df, anyM.parts.obj.par[:scrProb], anyM.sets)
else
    propPar_df = filter(x -> false, prop_df)
    propPar_df[!,:val] = Float64[]
    # compute default values in other cases
    prop_df = antijoin(prop_df, propPar_df, on = [:scr, :Ts_dis])
    prop_df[!,:val] .= 1/length(allScr_arr)
end

# controls sum of probabilities
control_df = combine(groupby(prop_df, [:Ts_dis]), :val => (x -> sum(x)) => :val)
sca_dic = Dict(control_df[!,:Ts_dis] .=> control_df[!,:val])

for x in eachrow(filter(x -> abs(x.val - 1.0) > 1e-8, control_df))
    push!(anyM.report, (2, "scenario", "probability", "for timestep '$(createFullString(x.Ts_dis, anyM.sets[:Ts]))' scenario probabilities do not sum up to 1.0, values were adjusted accordingly"))
end
prop_df[!,:val] .= map(x -> x.val/sca_dic[x.Ts_dis], eachrow(prop_df))

# creates final assignments
filter!(x -> x.val != 0.0, prop_df)

tsToScr_dic = Dict(y => sort(filter(x -> x.Ts_dis == y, prop_df)[!,:scr]) for y in unique(prop_df[!,:Ts_dis]))
tsScrToProp_dic = Dict((x.Ts_dis, x.scr) => x.val for x in eachrow(prop_df))
# create parameter object if not existing yet
if !(:scrProb in keys(anyM.parts.obj.par)) 
    parDef_ntup = (dim = (:Ts_dis, :scr), problem = :both, defVal = nothing, herit = (:scr => :up, :Ts_dis => :up, :Ts_dis => :avg_any), part = :obj)
    anyM.parts.obj.par[:scrProb] = ParElement(DataFrame(), parDef_ntup, :scrProb, anyM.report)
end
anyM.parts.obj.par[:scrProb].data = prop_df

# re-defines into a deterministic model for the most likely scenario or specified scenario
if !isnothing(anyM.options.forceScr)
    # identify relevant scenario
    if anyM.options.forceScr == Symbol()
        avgPropScr_arr = collect(keys(tsScrToProp_dic)) |> (u -> map(z -> (z, maximum(map(y -> tsScrToProp_dic[y], filter(x -> x[2] == z, u)))), unique(getindex.(u, 2))))
        propScr_int = maximum(getindex.(avgPropScr_arr, 2)) |> (u -> filter(x -> x[2] == u, avgPropScr_arr)[1][1])
    else
        propScr_int = sysInt(anyM.options.forceScr, anyM.sets[:scr])
    end
    # adjust elements to solve deterministic for one scenario
    relTs_arr = unique(prop_df[!,:Ts_dis])
    tsScrToProp_dic = Dict((x, propScr_int) => 1.0 for x in relTs_arr)
    tsToScr_dic = Dict(x => [propScr_int] for x in relTs_arr)
end

# check if there are multiple foresight periods 
if lvl_int != 0 && length(getNodesLvl(anyM.sets[:Ts], anyM.supTs.lvl)) == length(getNodesLvl(anyM.sets[:Ts], lvl_int)) && anyM.subPro != (0,0)
    for x in anyM.supTs.step
        if length(getDescendants(x, anyM.sets[:Ts], false, lvl_int)) == 1
            push!(anyM.report, (3, "scenario", "foresight", "for superordinate dispatch timestep '$(createFullString(x, anyM.sets[:Ts]))', there is only a single foresight step, this is not supported"))
        end
    end
end