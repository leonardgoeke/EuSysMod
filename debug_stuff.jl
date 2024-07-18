genSetup_ntup = info_ntup
algOpt_obj = algSetup_obj

sub_m = anyModel(inputFolder_ntup.in, inputFolder_ntup.results, checkRng = (print = true, all = false), objName = "subModel_" * string(id) * "_" * genSetup_ntup.name, frsLvl = genSetup_ntup.frsLvl, repTsLvl = genSetup_ntup.repTsLvl, supTsLvl = genSetup_ntup.supTsLvl, shortExp = genSetup_ntup.shortExp, coefRng = scale_dic[:rng], scaFac = scale_dic[:facSub], dbInf = algOpt_obj.solOpt.dbInf, reportLvl = 1)
sub_m.subPro = (3,1)

anyM = sub_m

# ! model stuff
if (anyM.options.createVI.bal || anyM.options.createVI.st)  && anyM.subPro != tuple(0,0)
    push!(anyM.report,(3, "scenario", "", "valid inequalities are only supported for the investment part of a decomposed problem"))
    errorTest(anyM.report, anyM.options) 
end

#region # * prepare dimensions of investment related variables
parDef_dic = defineParameter(anyM.options, anyM.report)

# ! gets dictionary with dimensions of expansion, retrofitting, and capacity variables
tsYear_dic = Dict(zip(anyM.supTs.step, collect(0:anyM.options.shortExp:(length(anyM.supTs.step)-1)*anyM.options.shortExp)))
prepSys_dic = Dict(sys => Dict{Symbol,Dict{Symbol,NamedTuple}}() for sys in (:Te,:Exc))
prepareTechs!(collect(keys(anyM.parts.tech)), prepSys_dic[:Te], tsYear_dic, anyM)
prepareExc!(collect(keys(anyM.parts.exc)), prepSys_dic[:Exc], tsYear_dic, anyM)

allCapaDf_dic = addRetrofitting!(prepSys_dic, anyM)
addInsCapa!(prepSys_dic, anyM) # add entries for installed capacities
removeFixed!(prepSys_dic, allCapaDf_dic, anyM) # remove entries were capacities are fixed to zero

# ! remove unrequired elements in case of distributed model creation
if !isempty(anyM.subPro) && !anyM.options.createVI.bal distributedMapping!(anyM, prepSys_dic) end

# abort if there is already an error
if any(getindex.(anyM.report, 1) .== 3) print(getElapsed(anyM.options.startTime)); errorTest(anyM.report, anyM.options) end

# remove systems without any potential capacity variables and reports this for exchange
for excSym in setdiff(collect(keys(anyM.parts.exc)), collect(keys(prepSys_dic[:Exc])))
    push!(anyM.report, (2, "exchange mapping", string(excSym), "to allow for exchange between regions, residual capacities of any value (even zero) must be defined between them, but none were found"))
end

foreach(x -> delete!(anyM.parts.tech, x), setdiff(collect(keys(anyM.parts.tech)), collect(keys(prepSys_dic[:Te]))))
foreach(x -> delete!(anyM.parts.exc, x), setdiff(collect(keys(anyM.parts.exc)), collect(keys(prepSys_dic[:Exc]))))
anyM.graInfo = graInfo(anyM) # re-create graph object, because objects might have been removed
#endregion

#region # * create technology related variables and constraints

# creates dictionary that assigns combination of superordinate dispatch timestep and dispatch level to dispatch timesteps
allTrackStDis_arr = anyM.parts.tech |> (z -> filter(y -> !isnothing(y), map(x -> z[x].stTrack, collect(keys(anyM.parts.tech)))))
allLvlTsDis_arr = convert(Vector{Int64}, unique(vcat(getfield.(values(anyM.cInfo), :tsDis), allTrackStDis_arr)))
ts_dic = Dict((x[1], x[2]) => anyM.sets[:Ts].nodes[x[1]].lvl == x[2] ? [x[1]] : getDescendants(x[1], anyM.sets[:Ts], false, x[2]) for x in Iterators.product(anyM.supTs.step, allLvlTsDis_arr))
foreach(x -> ts_dic[(x, anyM.supTs.lvl)] = [x], anyM.supTs.step)

# creates dictionary that assigns superordinate dispatch time-step to each dispatch time-step
yTs_dic = Dict{Int,Int}()
for x in collect(ts_dic), y in x[2] yTs_dic[y] = x[1][1] end

# creates dictionary that assigns combination of expansion region and dispatch level to dispatch region
allLvlR_arr = union(getindex.(getfield.(getfield.(values(anyM.parts.tech), :balLvl), :exp), 2), map(x -> x.rDis, values(anyM.cInfo)))
if anyM.options.createVI.bal push!(allLvlR_arr, 0) end

allRExp_arr = union([getfield.(getNodesLvl(anyM.sets[:R], x), :idx) for x in allLvlR_arr]...)
r_dic = Dict((x[1], x[2]) => (anyM.sets[:R].nodes[x[1]].lvl <= x[2] ? getDescendants(x[1], anyM.sets[:R], false, x[2]) : getAncestors(x[1], anyM.sets[:R], :int, x[2])[end]) |> (z -> typeof(z) <: Array ? z : [z]) for x in Iterators.product(allRExp_arr, allLvlR_arr))

produceMessage(anyM.options, anyM.report, 3," - Determined dimension of expansion and capacity variables for technologies")

# constraints for technologies are prepared in threaded loop and stored in an array of dictionaries
techSym_arr = collect(keys(anyM.parts.tech))	
techCnsDic_arr = Array{Dict{Symbol,cnsCont}}(undef, length(techSym_arr))
tech_itr = collect(enumerate(techSym_arr))


tSym = :gasStorage
tInt = sysInt(tSym, anyM.sets[:Te])
part = anyM.parts.tech[tSym]
prepTech_dic =  prepSys_dic[:Te][tSym]

# ! tech creation

cns_dic = Dict{Symbol,cnsCont}()
newHerit_dic = Dict(:lowest => (:Ts_dis => :avg_any, :R_dis => :avg_any), :reference => (:Ts_dis => :up, :R_dis => :up), :minGen => (:Ts_dis => :up, :R_dis => :up), :minUse => (:Ts_dis => :up, :R_dis => :up))  # inheritance rules after presetting
ratioVar_dic = Dict(:StIn => ("StIn" => "Conv"), :StOut => ("StOut" => "StIn"), :StSize => ("StSize" => "StIn")) # assignment of tech types for ratios stuff

tech_str = createFullString(tInt, anyM.sets[:Te])
# presets all dispatch parameter and obtains mode-dependant variables
modeDep_dic = presetDispatchParameter!(part, prepTech_dic, parDef_dic, newHerit_dic, ts_dic, r_dic, anyM)

# create investment variables and constraints
if part.type != :unrestricted
    # creates capacity, expansion, and retrofitting variables
    createExpCap!(part, prepTech_dic, anyM, ratioVar_dic)
    
    # create expansion constraints
    if isempty(anyM.subPro) || anyM.subPro == (0,0)
        # connect capacity and expansion variables
        createCapaCns!(part, anyM.sets, cns_dic, anyM.optModel, anyM.options.holdFixed)
        # control operated capacity variables
        if part.decomm != :none createOprVarCns!(part, cns_dic, anyM) end
        # control capacity for interannual storage
        if :capaStSize in keys(part.var) && part.stCyc == -1 capaSizeSeasonInter(part, cns_dic, anyM) end
    end
end

# create dispatch variables and constraints
if !isempty(part.var) || part.type == :unrestricted 

    # prepare must-run related parameters
    if :mustOut in keys(part.par)
        if part.type == :unrestricted
            push!(anyM.report, (3, "must output", "", "must-run parameter for technology '$(tech_str)' ignored, because technology is unrestricted,"))
        else
            if !(:desFac in keys(part.par)) && !isempty(anyM.subPro) && anyM.subPro != (0,0)
                push!(anyM.report, (2, "must output", "", "technology '$(tech_str)' has must-run, but no pre-defined design factor, also the model has reduced foresight and is created distributed, as a result, design factors only reflect operation within the foresight period"))
            end
            computeDesFac!(part, yTs_dic, anyM)
            prepareMustOut!(part, modeDep_dic, cns_dic, anyM)
        end
    end

    # already return if purpose was only computation of design factors
    if anyM.options.onlyDesFac return cns_dic end

    # map required capacity constraints
    if part.type != :unrestricted 
        rmvOutC_arr = createCapaRestrMap!(part, anyM)
        # adjust tracking level of storage
        if !isnothing(part.stTrack)
            stSizeRow_arr = findall(map(x -> occursin("stSize", x), part.capaRestr[!,:cnstrType]))
            part.capaRestr[stSizeRow_arr,:lvlTs] .= part.stTrack
        end
    end
        
    produceMessage(anyM.options, anyM.report, 3, " - Created all variables and prepared all constraints related to expansion and capacity for technology $(tech_str)")

    # create dispatch variables and constraints
    if isempty(anyM.subPro) || anyM.subPro != (0,0) || anyM.options.createVI.bal || anyM.scr.frsLvl != 0 || part.stCyc == -1
        
        createDispVar!(part, modeDep_dic, ts_dic, r_dic, prepTech_dic, anyM)
        produceMessage(anyM.options, anyM.report, 3, " - Created all dispatch variables for technology $(tech_str)")

        if anyM.subPro != (0,0) || anyM.options.createVI.bal
            # create conversion balance for conversion technologies
            if keys(part.carrier) |> (x -> any(map(y -> y in x, (:use, :stIntOut))) && any(map(y -> y in x, (:gen, :stIntIn)))) && (:capaConv in keys(part.var) || part.type == :unrestricted) && part.balSign.conv != :none
                cns_dic[:convBal] = createConvBal(part, anyM)
                produceMessage(anyM.options, anyM.report, 3, " - Prepared conversion balance for technology $(tech_str)")
            end

            # create storage balance for storage technologies
            if :stLvl in keys(part.var) && part.balSign.st != :none && !anyM.options.createVI.bal
                cns_dic[:stBal] = createStBal(part, anyM)
                produceMessage(anyM.options, anyM.report, 3, " - Prepared storage balance for technology $(tech_str)")
            # only create storage inflows as generation for valid inequalities
            elseif :stInflow in keys(part.par) && anyM.options.createVI.bal 
                inPar_df = rename(copy(part.par[:stInflow].data), :Ts_expSup => :Ts_disSup)
                inPar_df[!,:Ts_expSup] = inPar_df[!,:Ts_disSup]
                inPar_df[!,:Ts_disSup] .= inPar_df[!,:Ts_dis]
                inPar_df[!,:val] = inPar_df[!,:val] .* getEnergyFac(inPar_df[!,:Ts_dis], anyM.supTs)
                inPar_df[!,:R_dis] .= 0
                inPar_df[!,:M] .= 0
                part.var[:gen] = combine(x -> (var = AffExpr(sum(x.val)),), groupby(inPar_df, filter(x -> x != :id, intCol(inPar_df))))
            end
        end

        # create capacity restrictions
        sizeRestr_boo = (anyM.scr.frsLvl != 0 && :stLvl in keys(part.var) && anyM.subPro == (0,0))
        if part.type != :unrestricted && (anyM.subPro != (0,0) || anyM.options.createVI.bal || sizeRestr_boo)
            if sizeRestr_boo filter!(x -> occursin("stSize", x.cnstrType), part.capaRestr) end
            createCapaRestr!(part, ts_dic, r_dic, cns_dic, anyM, yTs_dic, rmvOutC_arr)
        end

        # enforce achievable storage levels
        if anyM.options.createVI.st && (anyM.scr.frsLvl != 0 || part.stCyc == -1) && anyM.subPro == (0,0) && :stLvl in keys(part.var) cns_dic = createStVI(part, ts_dic, r_dic, cns_dic, anyM) end

        # additional constraints for interannual stochastic storage 
        if part.stCyc == -1
            if (isempty(anyM.subPro) || anyM.subPro != (0,0)) 
                cns_dic = enforceStDelta(part, cns_dic, anyM) 
            elseif (isempty(anyM.subPro) || anyM.subPro == (0,0)) 
                cns_dic = stochStRestr(part, cns_dic, anyM)
                cns_dic = enforceStExpc(part, cns_dic, anyM)
            end
        end

        produceMessage(anyM.options, anyM.report, 3, " - Prepared capacity restrictions for technology $(tech_str)")
    end

    # create ratio constraints
    createRatioCns!(part, cns_dic, r_dic, anyM)

    # all constraints are scaled and then written into their respective array position
    foreach(x -> scaleCnsExpr!(x[2].data, anyM.options.coefRng, anyM.options.checkRng), collect(cns_dic))

    produceMessage(anyM.options, anyM.report, 2, " - Created all variables and prepared constraints for technology $(tech_str)")

end



function printIIS(anyM::anyModel)

    # computes iis
    compute_conflict!(anyM.optModel)

    if MOI.get(anyM.optModel, MOI.ConflictStatus()) != MOI.ConflictStatusCode(3) return end
    # loops over constraint tables to find constraints within iis
    allCns_pair = vcat(collect.(vcat(anyM.parts.obj.cns, anyM.parts.bal.cns, anyM.parts.cost.cns, anyM.parts.lim.cns, map(x -> x.cns, values(anyM.parts.exc))..., map(x -> x.cns, values(anyM.parts.tech))...))...)

    for cns in allCns_pair
        if cns[1] == :objEqn continue end

        allConstr_arr = findall(map(x -> MOI.ConflictParticipationStatusCode(0) != MOI.get(anyM.optModel.moi_backend, MOI.ConstraintConflictStatus(), x.index), cns[2][!,:cns]))
        # prints constraints within iis
        if !isempty(allConstr_arr)
            println("$(length(allConstr_arr)) of IIS in $(cns[1]) constraints.")
            colSet_dic = Dict(x => Symbol(split(string(x), "_")[1]) for x in intCol(cns[2]))
            for iisConstr in allConstr_arr
                row = cns[2][iisConstr,:]
                dimStr_arr = map(x -> row[x] == 0 ?  "" : x == :id ? string(row[x]) : string(x, ": ", join(getUniName(row[x], anyM.sets[colSet_dic[x]]), " < ")), collect(keys(colSet_dic)))
                println("$(join(filter(x -> x != "", dimStr_arr), ", ")), constraint: $(row[:cns])")
            end
        end
    end
end

printIIS(benders_obj.sub[(3,1)])
import AnyMOD.getUniName

benders_obj.top.parts.tech[:pumpedStorageClosed].cns