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
objective_value(anyM.optModel)

#endregion

#region # * write results

reportResults(:summary, anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:cost, anyM, addObjName = true)
reportResults(:exchange, anyM, addObjName = true)

reportTimeSeries(:electricity, anyM)

#endregion

# ! write solution into benders object as best

# get results and write to object
resData_obj = resData()
resData_obj.capa, resData_obj.stLvl, resData_obj.lim = writeResult(anyM, [:capa, :mustCapa, :stLvl, :lim]; rmvFix = true, fltSt = false)
benders_obj.itr.best.capa, benders_obj.itr.best.stLvl, benders_obj.itr.best.lim = map(x -> getfield(resData_obj,x), [:capa, :stLvl, :lim])

# manually compute emissions
em_df = getAllVariables(:emission, anyM)
em_df[!,:value] = value.(em_df[!,:var])
em_df[!,:sub] .= map(x -> (getAncestors(x.Ts_dis, anyM.sets[:Ts], :int, 3)[end], x.scr), eachrow(em_df))
em_df = combine(x -> (sub = x.sub[1],value = sum(x.value),), groupby(em_df, :sub))

foreach(x -> em_df[!,x] .= 0, [:Ts_expSup, :Ts_dis, :R_dis, :C, :Te, :Exc, :M, :scr, :id ])
benders_obj.itr.best.lim[:emissionBendersCom] = em_df

# filter non-relevant storage
for x in keys(benders_obj.itr.best.stLvl)
    if anyM.parts.tech[x].stCyc > 2
        delete!(benders_obj.itr.best.stLvl, x)
    end
end



# ! test writing of heuristc solution

heu_m = anyM

# write results to benders object
heuData_obj = resData()
heuData_obj.objVal = sum(map(z -> sum(value.(heu_m.parts.cost.var[z][!, :var])), collect(filter(x -> any(occursin.(["costExp", "costOpr", "costMissCapa", "costRetro"], string(x))), keys(heu_m.parts.cost.var)))))
heuData_obj.capa, ~ = writeResult(heu_m, [:capa, :exp, :mustCapa, :mustExp], fltSt = true)

heuData_obj.capa[:tech][:onshore_a][:capaConv]