using AnyMOD, Gurobi, CSV, Statistics

function reportProfile(car::Symbol,h::Int,anyM::anyModel)

    # get time-series data
    timeSeries_df = reportTimeSeries(car,anyM, rtnOpt = (:rawDf,))
    relCol_arr = filter(x -> !(x in ("Ts_disSup","Ts_dis","R_dis")), names(timeSeries_df))
    foreach(x -> replace!(timeSeries_df[!,x], missing => 0), relCol_arr);

    # map time-steps to month and hour
    allTsDis_arr = sort(unique(timeSeries_df[!,:Ts_dis]))
    timeSeries_df[!,:tsIdx] = map(x -> findall(x .== allTsDis_arr)[1],timeSeries_df[!,:Ts_dis])
    resHour_int = anyM.supTs.sca[anyM.supTs.step[1],anyM.cInfo[filter(x -> x.val == string(car),collect(values(anyM.sets[:C].nodes)))[1].idx].tsDis] / anyM.supTs.sca[anyM.supTs.step[1],maximum(map(x -> x.tsDis, collect(values(anyM.cInfo))))] # resolution of carrier in hours
    timeSeries_df[!,:hour] = Int.(round.(timeSeries_df[!,:tsIdx] .* resHour_int .% 24, digits = 0))
    timeSeries_df[!,:month] = map(x -> ceil(x .* resHour_int/ (h/12)), timeSeries_df[!,:tsIdx])

    # aggregate monthly values
    monthTimeSeries_gdf = groupby(select(timeSeries_df,Not([:Ts_disSup,:Ts_dis,:R_dis,:hour])),[:month])
    month_df = vcat(map(monthTimeSeries_gdf) do x
        out_df = DataFrame(month = x.month[1])
        foreach(y -> out_df[y] = sum(x[y]),relCol_arr)
        return out_df
    end...)

    CSV.write("$(anyM.options.outDir)/results_yearlyProfile_$(string(car))_$(anyM.options.outStamp).csv", month_df)

    # aggregate hourly values
    hourTimeSeries_gdf = groupby(select(timeSeries_df,Not([:Ts_disSup,:Ts_dis,:R_dis,:month])),[:hour])
    hour_df = vcat(map(hourTimeSeries_gdf) do x
        out_df = DataFrame(hour = x.hour[1])
        foreach(y -> out_df[y] = mean(x[y]),relCol_arr)
        return out_df
    end...)

    CSV.write("$(anyM.options.outDir)/results_dailyProfile_$(string(car))_$(anyM.options.outStamp).csv", hour_df)

end

h = ARGS[1]
sca = ARGS[2]
threads = ARGS[3]

anyM = anyModel(["_basis","_full","timeSeries/" * h * "hours_2008_only2050"],"results", objName = h * "hours_" * sca, supTsLvl = 2, shortExp = 5, redStep = (sca == "scale" ? 1.0 : 8760/parse(Int, h)))

createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",tryparse(Int,threads));
set_optimizer_attribute(anyM.optModel, "BarOrder", 1);

optimize!(anyM.optModel)

reportResults(:summary,anyM, addRep = (:capaConvOut,))
reportResults(:exchange,anyM)
reportResults(:cost,anyM)

reportProfile(:electricity,parse(Int,h),anyM)
reportProfile(:districtHeat,parse(Int,h),anyM)
reportProfile(:h2,parse(Int,h),anyM)

# ! write info on h2 grid for qgis
h2Grid_df = select(filter(x -> x.variable == :capaExc && x.exchange == "h2Grid",reportResults(:exchange,anyM, rtnOpt = (:csvDf,))),Not([:timestep_superordinate_expansion,:carrier,:directed,:variable,:exchange]))
h2Grid_df[!,:edge] = map(x -> join([replace(getindex(split(x[y],"<"),4)," " => "") for y in [:region_from,:region_to]],"-"), eachrow(h2Grid_df))
select!(h2Grid_df,Not([:region_from,:region_to]))
h2Grid_df[!,:timestep_superordinate_dispatch] = replace.(getindex.(split.(h2Grid_df[!,:timestep_superordinate_dispatch],"<"),2)," " => "")
h2Grid_df[!,:value] = map(x -> x < 1e-2 ? 0.0 : x,h2Grid_df[!,:value])
filter!(x -> x.value != 0.0, h2Grid_df)

h2Grid_df = unstack(h2Grid_df,:timestep_superordinate_dispatch,:value)

CSV.write(anyM.options.outDir * "/h2Grid_$(anyM.options.outStamp).csv",h2Grid_df)

# ! write info on h2 balance

h2Bal_df = computeResults("h2Bal.yml",anyM, rtnOpt = (:csvDf,))

h2Bal_df = unstack(h2Bal_df,:timestep,:value)
CSV.write(anyM.options.outDir * "/h2Bal_$(anyM.options.outStamp).csv",h2Bal_df)

# ! plot sankey for EU27

#region # * names and colors
anyM.graInfo.colors["capturedCO2"] = (0.0,  0.0, 0.0)
anyM.graInfo.colors["h2"] = (0.329, 0.447, 0.827)

anyM.graInfo.colors["rawBiogas"] = (0.682, 0.898, 0.443)
anyM.graInfo.colors["solidBiomass"] = (0.682, 0.898, 0.443)
anyM.graInfo.colors["nonSolidBiomass"] =  (0.682, 0.898, 0.443)
anyM.graInfo.colors["otherBiomass"] = (0.682, 0.898, 0.443)

anyM.graInfo.colors["spaceHeat"] = (1.0, 0.4549019607843137, 0.5215686274509804)
anyM.graInfo.colors["processHeat_low"] = (0.6823529411764706, 0.07058823529411765, 0.22745098039215686)
anyM.graInfo.colors["processHeat_medium"] = (0.6823529411764706, 0.07058823529411765, 0.22745098039215686)
anyM.graInfo.colors["processHeat_high"] = (0.6823529411764706, 0.07058823529411765, 0.22745098039215686)

anyM.graInfo.colors["jetFuel"] = (0.235, 0.506, 0.325)
anyM.graInfo.colors["crudeOil"] = (0.33725490196078434, 0.3411764705882353, 0.3254901960784314)
anyM.graInfo.colors["diesel"] = (0.33725490196078434, 0.3411764705882353, 0.3254901960784314)
anyM.graInfo.colors["gasoline"] = (0.33725490196078434, 0.3411764705882353, 0.3254901960784314)

anyM.graInfo.colors["synthGas"] = (0.235, 0.506, 0.325)
anyM.graInfo.colors["naturalGas"] = (1.0,  0.416, 0.212)
anyM.graInfo.colors["gasFuel"] = (1.0,  0.416, 0.212)

anyM.graInfo.colors["frtRoadHeavy"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["frtRoadLight"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["frtRail"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["psngRail"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["psngRoadPrvt"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["psngRoadPub"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)

for t in keys(anyM.parts.tech)
    anyM.graInfo.names[string(t)] = ""
end 

anyM.graInfo.names["runOfRiver"] = "run-of-river"
anyM.graInfo.names["reservoir"] = "reservoir"

anyM.graInfo.names["capturedCO2"] = "carbon"
anyM.graInfo.names["h2"] = "H2"

anyM.graInfo.names["solidBiomass"] = "solid biomass"
anyM.graInfo.names["rawBiogas"] =  "raw biogass"
anyM.graInfo.names["nonSolidBiomass"] = "non-solid biomass"

anyM.graInfo.names["spaceHeat"] = "space heat"
anyM.graInfo.names["processHeat_low"] = "process heat - low"
anyM.graInfo.names["processHeat_medium"] = "process heat - medium"
anyM.graInfo.names["processHeat_high"] = "process heat - high"

anyM.graInfo.names["synthLiquid"] = "synthetic oil"
anyM.graInfo.names["jetFuel"] = "jet fuel"

anyM.graInfo.names["gasFuel"] = "gas"

anyM.graInfo.names["frtRoadHeavy"] = "heavy road"
anyM.graInfo.names["frtRoadLight"] = "light road"
anyM.graInfo.names["frtRail"] = "rail"
anyM.graInfo.names["psngRail"] = "rail"
anyM.graInfo.names["psngRoadPrvt"] = "private road"
anyM.graInfo.names["psngRoadPub"] = "public road"


#endregion

rmvStr_tup = ("h2Blend","exchange losses", "trade buy; solid biomass", "trade buy; non-solid biomass")
plotEnergyFlow(:sankey,anyM, dropDown = (:timestep,), rmvNode = rmvStr_tup, minVal = 1.0)





