# write storage levels
function writeStLvl(tSym_arr::Array{Symbol,1},anyM::anyModel)
    lvl_df = DataFrame(Ts_dis = Int[], Te = Int[], scr = Int[],  value  = Float64[])
    for tSym in tSym_arr
        stLvl_df = combine(x -> (value = sum(value.(x.var)),), groupby(anyM.parts.tech[tSym].var[:stLvl],[:Ts_dis,:Te,:scr]))
        append!(lvl_df,stLvl_df)
    end
    return lvl_df
end

# write dual values
function writeDuals(relBal_ntup::NamedTuple,anyM::anyModel)
    
    allDual_df = DataFrame(Ts_dis = Int[], scr = Int[],  bal  = String[], cat = String[], value = Float64[])
    # add dual for energy balance
    for x in keys(anyM.parts.bal.cns)
        car_str = lowercase(replace(string(x),"enBal" => ""))
        if Symbol(car_str) in relBal_ntup.enBal
            cns_df = copy(anyM.parts.bal.cns[x])
            cns_df[!,:dual] = dual.(cns_df[!,:cns])
            cns_df = combine(x -> (value = sum(x.dual),),groupby(cns_df,[:Ts_dis,:scr]))
            cns_df[!,:bal] .= "enBal"
            cns_df[!,:cat] .= car_str
            append!(allDual_df,cns_df)
        end
    end

    # add dual for storage balance
    for x in keys(anyM.parts.tech)
        if x in relBal_ntup.stBal && :stBal in keys(anyM.parts.tech[x].cns)
            cns_df = copy(anyM.parts.tech[x].cns[:stBal])
            cns_df[!,:dual] = dual.(cns_df[!,:cns])
            cns_df = combine(x -> (value = sum(x.dual),),groupby(cns_df,[:Ts_dis,:scr]))
            cns_df[!,:bal] .= "stBal"
            cns_df[!,:cat] .= string(x)
            append!(allDual_df,cns_df)
        end
    end

    # add dual for exchange restriction
    for x in keys(anyM.parts.exc)
        if x in relBal_ntup.excRestr && :excRestr in keys(anyM.parts.exc[x].cns)
            cns_df = copy(anyM.parts.exc[x].cns[:excRestr])
            cns_df[!,:dual] = dual.(cns_df[!,:cns])
            cns_df = combine(x -> (value = sum(x.dual),),groupby(cns_df,[:Ts_dis,:scr]))
            cns_df[!,:bal] .= "excRestr"
            cns_df[!,:cat] .= string(x)
            append!(allDual_df,cns_df)
        end
    end

    return allDual_df
end