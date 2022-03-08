using AnyMOD, Gurobi, CSV, Statistics

h = ARGS[1]
h_heu = ARGS[2]
ee = ARGS[3]
grid = ARGS[4]
t_int = ARGS[5]

include("techMapping.jl")

function writeModulation(aggRelCol_dic::Dict{Symbol, Array{Pair}},anyM::anyModel)
   

    allHour_df = DataFrame(hour = collect(1:24))
    allMonth_df = DataFrame(month = collect(1:12))
   
    for c in (:electricity,:districtHeat)

        # get time-series data
        timeSeries_df = reportTimeSeries(c,anyM, rtnOpt = (:rawDf,))
        relCol_arr = filter(x -> !(x in ("Ts_disSup","Ts_dis","R_dis")), names(timeSeries_df))
        foreach(x -> replace!(timeSeries_df[!,x], missing => 0), relCol_arr);

        # map time-steps to month and hour
        allTsDis_arr = sort(unique(timeSeries_df[!,:Ts_dis]))
        timeSeries_df[!,:tsIdx] = map(x -> findall(x .== allTsDis_arr)[1],timeSeries_df[!,:Ts_dis])
        scaCar_int = Int(round(8760/length(allTsDis_arr),digits = 0))
        timeSeries_df[!,:hour] = replace(Int.(floor.(timeSeries_df[!,:tsIdx] .* scaCar_int .% 24)),0 => 24)
        timeSeries_df[!,:month] = map(x -> ceil(x ./ (length(allTsDis_arr)/12)), timeSeries_df[!,:tsIdx])

        # aggregate monthly values
        monthTimeSeries_gdf = groupby(select(timeSeries_df,Not([:Ts_disSup,:Ts_dis,:R_dis,:hour])),[:month])
        month_df = vcat(map(monthTimeSeries_gdf) do x
            out_df = DataFrame(month = x.month[1])
            foreach(y -> out_df[y] = mean(x[y])/scaCar_int,relCol_arr)
            return out_df
        end...)

        # aggregate hourly values
        hourTimeSeries_gdf = groupby(select(timeSeries_df,Not([:Ts_disSup,:Ts_dis,:R_dis,:month])),[:hour])
        hour_df = vcat(map(hourTimeSeries_gdf) do x
            out_df = DataFrame(hour = x.hour[1])
            foreach(y -> out_df[y] = mean(x[y])/scaCar_int,relCol_arr)
            return out_df
        end...)
        
        # aggregate according to defined categories
        for cat in aggRelCol_dic[c]
            month_df[!,cat[1]] .= 0.0
            hour_df[!,cat[1]] .= 0.0

            if !isempty(intersect(names(month_df),cat[2]))
                for y in 1:size(month_df,1)
                    month_df[y,cat[1]] = sum(map(x -> month_df[y,x],intersect(names(month_df),cat[2])))
                end
                select!(month_df,Not(intersect(names(month_df),cat[2])))
            end

            if !isempty(intersect(names(hour_df),cat[2]))
                for y in 1:size(hour_df,1)
                    hour_df[y,cat[1]] = sum(map(x -> hour_df[y,x],intersect(names(hour_df),cat[2])))     
                end
                select!(hour_df,Not(intersect(names(hour_df),cat[2])))
            end

        end

        # sort and remove extra columns
        sort!(month_df,:month)
        sort!(hour_df,:hour)
        select!(month_df,vcat(["month"],intersect(names(month_df),getindex.(aggRelCol_dic[c],1))))
        select!(hour_df,vcat(["hour"],intersect(names(hour_df),getindex.(aggRelCol_dic[c],1))))

        # extend values to all hours
        expHour_dic = Dict(x => collect(x:(x+scaCar_int-1)) for x in hour_df[!,:hour])
        hour_df[!,:hour] = map(x -> expHour_dic[x],hour_df[!,:hour])
        hour_df = flatten(hour_df,:hour)

        allHour_df = hcat(allHour_df,select(hour_df,Not([:hour])))
        allMonth_df = hcat(allMonth_df,select(month_df,Not([:month])))
    end

    # filter columns with small values
    select!(allMonth_df ,Not(filter(x -> x != "month" && abs(sum(allMonth_df[!,x])) < 1.0, names(allMonth_df))))
    select!(allHour_df ,Not(filter(x -> x != "hour" && abs(sum(allHour_df[!,x])) < 1.0, names(allHour_df))))
    
    # write profile
    CSV.write("$(anyM.options.outDir)/results_yearlyProfile_$(anyM.options.outStamp).csv", allMonth_df)
    CSV.write("$(anyM.options.outDir)/results_dailyProfile_$(anyM.options.outStamp).csv", allHour_df)

    # compute and write modulation
    for col in filter(x -> x != "month", names(allMonth_df)) allMonth_df[!,col] = mean(allMonth_df[!,col]) |> (x -> abs.(allMonth_df[!,col]) .- abs(x)) end
    for col in filter(x -> x != "hour", names(allHour_df)) allHour_df[!,col] = mean(allHour_df[!,col]) |> (x -> abs.(allHour_df[!,col]) .- abs(x)) end

    CSV.write("$(anyM.options.outDir)/results_yearlyModulation_$(anyM.options.outStamp).csv", allMonth_df)
    CSV.write("$(anyM.options.outDir)/results_dailyModulation_$(anyM.options.outStamp).csv", allHour_df)

end


obj_str = h * "hours" * ee * grid
temp_dir = "tempFix" * obj_str # directory for temporary folder

inputMod_arr = ["_basis",ee,grid,"timeSeries/" * h * "hours_2008_only2050",temp_dir]
inputHeu_arr = ["_basis",ee,grid,"timeSeries/" * h_heu * "hours_2008_only2050"]
resultDir_str = "results"

#region # * perform heuristic solve

coefRngHeuSca_tup = (mat = (1e-2,1e4), rhs = (1e0,1e5))
scaFacHeuSca_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e3, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)

optMod_dic = Dict{Symbol,NamedTuple}()
optMod_dic[:heuSca] =  (inputDir = inputHeu_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)
optMod_dic[:top] 	=  (inputDir = inputMod_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)

heu_m, heuSca_obj = @suppress heuristicSolve(optMod_dic[:heuSca],1.0,t_int,Gurobi.Optimizer);
~, heuCom_obj = @suppress heuristicSolve(optMod_dic[:heuSca],365/parse(Int,h_heu),t_int,Gurobi.Optimizer)
# ! write fixes to files and limits to dictionary
fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m,heuSca_obj,heuCom_obj,(thrsAbs = 0.05, thrsRel = 0.05)) # get fixed and limited variables
feasFix_dic = getFeasResult(optMod_dic[:top],fix_dic,lim_dic,t_int,0.05,Gurobi.Optimizer) # ensure feasiblity with fixed variables
# ! write fixed variable values to files
writeFixToFiles(fix_dic,feasFix_dic,temp_dir,heu_m)
heu_m = nothing

#endregion

#region # * create and solve main model

anyM = anyModel(inputMod_arr,resultDir_str, objName = obj_str, supTsLvl = 2, shortExp = 5, redStep = 1.0, emissionLoss = false, holdFixed = true)

createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",tryparse(Int,t_int));
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary,anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:exchange,anyM, addObjName = true)
reportResults(:cost,anyM, addObjName = true)

writeModulation(aggRelCol_dic,anyM)

reportTimeSeries(:electricity,anyM)
reportTimeSeries(:spaceHeat,anyM)
reportTimeSeries(:districtHeat,anyM)

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

#endregion







