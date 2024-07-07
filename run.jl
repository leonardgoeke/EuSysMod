using AnyMOD, Gurobi, CSV, Statistics

b = "C:/Users/pacop/Desktop/git/EuSysMOD/"

par_df = CSV.read(b * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int, ARGS[1])
    t_int = parse(Int, ARGS[2]) # number of threads
end

space = string(par_df[id_int,:space]) # spatial resolution 
time = string(par_df[id_int,:time]) # temporal resolution
scenario = string(par_df[id_int,:scenario]) # scenario case

obj_str = space * "_" * time * "_testing"
inputMod_arr = [b * "_basis", b * "timeSeries/" * space * "_" * time * "_" * scenario]
resultDir_str = b * "results"


#region # * create and solve model

anyM = anyModel(inputMod_arr, resultDir_str, objName = obj_str, supTsLvl = 2, repTsLvl = 3, frsLvl = 3, shortExp = 5, emissionLoss = false, holdFixed = true);

createOptModel!(anyM)
setObjective!(:cost, anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads", t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary, anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:cost, anyM, addObjName = true)
reportResults(:exchange, anyM, addObjName = true)

plotSankeyDiagram(anyM, dropDown = (:timestep,), ymlFilter = b * "all.yml")
reportTimeSeries(:electricity, anyM)

#endregion

tSym = :reservoir
tInt = sysInt(tSym, anyM.sets[:Te])
part =  anyM.parts.tech[tSym]

printObject(part.var[:stLvl], anyM)


# get variables for current storage level
cns_df = rename(part.var[:stLvl], :var => :stLvl)

# filter cases where storage level variable just exists to formulate balance
if anyM.scr.frsLvl != 0 
    filter!(x -> getAncestors(x.Ts_dis, anyM.sets[:Ts], :int, anyM.scr.frsLvl)[end] in keys(anyM.scr.scr), cns_df)
end
cnsDim_arr = filter(x -> x != :Ts_disSup, intCol(cns_df))

# join variables for previous storage level
tsChildren_dic = Dict((x,y) => getDescendants(x, anyM.sets[:Ts], false, y) for x in getfield.(getNodesLvl(anyM.sets[:Ts], part.stCyc == -1 ? anyM.scr.frsLvl : part.stCyc), :idx), y in unique(map(x -> getfield(anyM.sets[:Ts].nodes[x], :lvl), cns_df[!,:Ts_dis])))
filter!(x -> !isempty(x[2]), tsChildren_dic)
firstLastTs_dic::Dict{Int,Int} = Dict(minimum(tsChildren_dic[z]) => maximum(tsChildren_dic[z]) for z in keys(tsChildren_dic))
firstTs_arr = collect(keys(firstLastTs_dic))

cns_df[!,:Ts_disPrev] = map(x -> x in firstTs_arr ? firstLastTs_dic[x] : x - 1, cns_df[!,:Ts_dis])
cns_df = rename(joinMissing(cns_df, part.var[:stLvl], intCol(part.var[:stLvl]) |> (x -> Pair.(replace(x, :Ts_dis => :Ts_disPrev), x)), :left, Dict(:var => AffExpr())), :var => :stLvlPrev)


# filter storage variables not enforcing a balance in case of interdependent subperiods (variables only exist to enforce right value at the start of the next period, occurs if number of scenarios varies)
if anyM.scr.frsLvl != 0 filter!(x -> x.scr in anyM.scr.scr[getAncestors(x.Ts_dis, anyM.sets[:Ts], :int, anyM.scr.frsLvl)[end]], cns_df) end


stLvlInter_df = part.var[:stLvlInter]
stLvlInter_df[!,:Ts_dis] =  map(x -> maximum(getDescendants(x.Ts_dis, anyM.sets[:Ts], false, anyM.cInfo[x.C].tsDis)), eachrow(stLvlInter_df))

cns_df



# determines dimensions for aggregating dispatch variables
agg_arr = filter(x -> !(x in (:M, :Te)) && (part.type == :emerging || x != :Ts_expSup), cnsDim_arr)

# obtain all different carriers of level variable and create array to store the respective level constraint data
uniId_arr = map(x -> (x.C, x.id), eachrow(unique(cns_df[!,[:C,:id]])))
cCns_arr = Array{DataFrame}(undef, length(uniId_arr))

for (idx,bal) in enumerate(uniId_arr)

    # get constraints relevant for carrier and find rows where mode is specified
    cnsC_df = filter(x -> x.C == bal[1] && x.id == bal[2], cns_df)
    sort!(cnsC_df, orderDim(intCol(cnsC_df)))

    m_arr = findall(0 .!= cnsC_df[!,:M])
    noM_arr = setdiff(1:size(cnsC_df, 1), m_arr)

    if part.type == :emerging
        srcRes_ntup = anyM.cInfo[bal[1]] |> (x -> (Ts_expSup = anyM.supTs.lvl, Ts_dis = x.tsDis, R_dis = x.rDis, C = anyM.sets[:C].nodes[bal[1]].lvl, M = 1))
    else
        srcRes_ntup = anyM.cInfo[bal[1]] |> (x -> (Ts_dis = x.tsDis, R_dis = x.rDis, C = anyM.sets[:C].nodes[bal[1]].lvl, M = 1))
    end

    # ! join in and out dispatch variables and adds efficiency to them (hence efficiency can be specific for different carriers that are stored in and out)
    for typ in (:in,:out)
        typVar_df = copy(cns_df[!,cnsDim_arr])
        # create array of all dispatch variables
        allType_arr = intersect(keys(part.carrier), typ == :in ? (:stExtIn, :stIntIn) : (:stExtOut, :stIntOut))
        
        # aborts if no variables on respective side exist
        if isempty(allType_arr)
            cnsC_df[!,typ] .= AffExpr() 
            continue
        end

        effPar_sym = typ == :in ? :effStIn : :effStOut
        # adds dispatch variables
        typExpr_arr = map(allType_arr) do va
            typVar_df = filter(x -> x.C == bal[1], part.par[effPar_sym].data) |> (x -> innerjoin(part.var[va], x; on = intCol(x)))
            if typ == :in
                typVar_df[!,:var] = typVar_df[!,:var] .* typVar_df[!,:val]
            else
                typVar_df[!,:var] = typVar_df[!,:var] ./ typVar_df[!,:val]
            end
            return typVar_df[!,Not(:val)]
        end

        # adds dispatch variable to constraint dataframe, mode dependant and non-mode dependant balances have to be aggregated separately and timesteps only need aggregration if resolution for storage level differs
        dispVar_df = vcat(typExpr_arr...)
        dispVar_df[!,:var] = dispVar_df[!,:var] .* getEnergyFacSt(dispVar_df[!,:Ts_dis], dispVar_df[!,:Ts_disSup], part.stCyc >= anyM.options.repTsLvl, anyM.supTs)
        
        cnsC_df[!,typ] .= AffExpr()
        if isempty(dispVar_df) continue end

        mAgg_tup = isnothing(part.stTrack) ?  (M = 1,) : (M = 1, Ts_dis = anyM.sets[:Ts].nodes[cnsC_df[1,:Ts_dis]].lvl)
        noMAgg_tup = isnothing(part.stTrack) ?  (M = 1,) : (M = 1, Ts_dis = anyM.sets[:Ts].nodes[cnsC_df[1,:Ts_dis]].lvl)
        cnsC_df[m_arr,typ] = aggUniVar(dispVar_df, select(cnsC_df[m_arr,:], intCol(cnsC_df)), [:M, agg_arr...], mAgg_tup, anyM.sets)
        cnsC_df[noM_arr,typ] = aggUniVar(dispVar_df, select(cnsC_df[noM_arr,:], intCol(cnsC_df)), [:M, agg_arr...], noMAgg_tup, anyM.sets)			
    end

    # ! adds further parameters that depend on the carrier specified in storage level (superordinate or the same as dispatch carriers)
    sca_arr = getEnergyFacSt(cnsC_df[!,:Ts_dis], cnsC_df[!,:Ts_disSup], part.stCyc >= anyM.options.repTsLvl, anyM.supTs)

    # add discharge parameter, if defined
    if :stDis in keys(part.par)
        cnsC_df = matchSetParameter(cnsC_df, part.par[:stDis], anyM.sets, defVal = 0.0)
        cnsC_df[!,:stDis] =   (1 .- cnsC_df[!,:val]) .^ sca_arr
        select!(cnsC_df, Not(:val))
    else
        cnsC_df[!,:stDis] .= 1.0
    end

    # add inflow parameter, if defined
    if :stInflow in keys(part.par)
        cnsC_df = matchSetParameter(cnsC_df, part.par[:stInflow], anyM.sets, newCol = :stInflow, defVal = 0.0)
        cnsC_df[!,:stInflow] = cnsC_df[!,:stInflow] .* sca_arr
        if !isempty(part.modes)
            cnsC_df[!,:stInflow] = cnsC_df[!,:stInflow] ./ length(part.modes)
        end
    else
        cnsC_df[!,:stInflow] .= 0.0
    end

    # add infeasibility variables for reduced foresight with cutting plane algorithm
    if anyM.scr.frsLvl != 0 && !isempty(anyM.subPro) && anyM.scr.frsLvl > part.stCyc && :costStLvlLss in keys(anyM.parts.cost.par)
        # get time-steps at end of foresight period
        endTs_df = combine(x -> (Ts_dis = maximum(x.Ts_dis),), groupby(cnsC_df, filter(x -> !(x in (:Ts_dis, :Ts_disPrev)), intCol(cnsC_df))))
        # add times-steps at start of foresight period, if option is set
        if anyM.options.dbInf
            startTs_df = combine(x -> (Ts_dis = minimum(x.Ts_dis),), groupby(cnsC_df, filter(x -> !(x in (:Ts_dis, :Ts_disPrev)), intCol(cnsC_df))))
            endTs_df = vcat(startTs_df, endTs_df)
        end
        
        matchTs_df = select(matchSetParameter(endTs_df, anyM.parts.cost.par[:costStLvlLss], anyM.sets), Not([:val]))
        if !isempty(matchTs_df)
            # on net-increase
            part.var[:stLvlInfeasIn] = createVar(matchTs_df, "stLvlInfeasIn", getUpBound(matchTs_df, anyM.options.bound.disp, anyM.supTs, anyM.sets[:Ts]), anyM.optModel, anyM.lock, anyM.sets)
            bothInf_df = copy(part.var[:stLvlInfeasIn])
            # on net-decrease, only needed for output if storage balance is an equality constraint
            if part.balSign.st != :ineq
                part.var[:stLvlInfeasOut] = createVar(matchTs_df, "stLvlInfeasOut", getUpBound(matchTs_df, anyM.options.bound.disp, anyM.supTs, anyM.sets[:Ts]), anyM.optModel, anyM.lock, anyM.sets)
                if :stLvlInfeasIn in keys(part.var)
                    bothInf_df[!,:var] .= bothInf_df[!,:var] .- part.var[:stLvlInfeasOut][!,:var]
                else
                    bothInf_df = copy(part.var[:stLvlInfeasOut])
                    bothInf_df[!,:var] .= -1 .* bothInf_df[!,:var]
                end
            end 
            # add expression to constraint, if any infeasibility variables exist
            if :stLvlInfeasIn in keys(part.var) || :stLvlInfeasOut in keys(part.var)
                cnsC_df = joinMissing(cnsC_df, rename(bothInf_df, :var => :infeas), intCol(bothInf_df), :left, Dict(:infeas => AffExpr()))
                cnsC_df[!,:stInflow] .= cnsC_df[!,:stInflow] .+ cnsC_df[!,:infeas]
                select!(cnsC_df, Not([:infeas]))
            end
        end
    end

    # ! create final equation	
    cnsC_df[!,:cnsExpr] = @expression(anyM.optModel, cnsC_df[!,:stLvlPrev] .* cnsC_df[!,:stDis] .+ cnsC_df[!,:stInflow] .+ cnsC_df[!,:in] .- cnsC_df[!,:out] .- cnsC_df[!,:stLvl])
    cCns_arr[idx] = cnsC_df
end