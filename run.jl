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

obj_str = space * "_" * time * "_" * scenario * "_testing"
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


for x in keys(benders_obj.sub)
    println(x)
    optimize!(benders_obj.sub[x].optModel)
    #compute_conflict!(benders_obj.sub[x].optModel)
    println(value(sum(benders_obj.sub[x].parts.obj.var[:objVar][!,:var])))
    printIIS(benders_obj.sub[x])
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
