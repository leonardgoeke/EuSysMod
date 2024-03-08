
using AnyMOD, Gurobi

dir_str = "C:/Users/pacop/Desktop/git/EuSysMod/"

# ! input folders
dir_str = b
scr_int = 2 # number of scenarios
res_int = 96

inDir_arr = [dir_str * "_basis",dir_str * "_full",dir_str * "timeSeries/" * string(res_int) * "hours_s" * string(scr_int)] # input directory

# ! test cost optimization
cost_m = @suppress anyModel(inDir_arr, dir_str * "/results", objName = "costOptimization", lvlFrs = 0, supTsLvl = 1, shortExp = 10)
createOptModel!(cost_m)
setObjective!(:cost, cost_m)

set_optimizer(cost_m.optModel, Gurobi.Optimizer)
set_optimizer_attribute(cost_m.optModel, "Crossover", 0);
optimize!(cost_m.optModel)

# ! test wind optimization
wind_m = @suppress anyModel(inDir_arr, dir_str * "/results", objName = "costOptimization", lvlFrs = 0, supTsLvl = 1, shortExp = 10)
createOptModel!(wind_m)

@objective(wind_m.optModel,  ) 

cost_expr = sum(filter(x -> x.name in (:cost, :benders), wind_m.parts.obj.var[:objVar])[!,:var])
nearOpt_eqn = @constraint(wind_m.optModel, 48422.28066972606 * (1 + nearOpt_ntup.optThres)  >= cost_expr)


set_optimizer(wind_m.optModel, Gurobi.Optimizer)
set_optimizer_attribute(wind_m.optModel, "Crossover", 0);
optimize!(wind_m.optModel)



obj_arr = Pair[]
for obj in nearOpt_ntup.obj[nOpt_int][2][2]
    # build filter function
    flt_tup = obj[2]
    te_boo = !(flt_tup.variable in (:capaExc, :expExc))
    exp_boo = flt_tup.variable in (:expConv, :expStIn, :expStOut, :expStSize, :expExc)
    flt_func = x -> (:system in keys(flt_tup) ? ((te_boo ? x.Te : x.Exc) in getDescFromName(flt_tup.system, wind_m.sets[(te_boo ? :Te : :Exc)])) : true) && (:region in keys(flt_tup) ? (x.R_exp in getDescFromName(flt_tup.region, wind_m.sets[:R])) : true) && (:region_from in keys(flt_tup) ? (x.R_from in getDescFromName(flt_tup.region_from, wind_m.sets[:R])) : true) && (:region_to in keys(flt_tup) ? (x.R_to in getDescFromName(flt_tup.region_to, wind_m.sets[:R])) : true) && (:timestep in keys(flt_tup) ? ((exp_boo ? x.Ts_exp : x.Ts_expSup) in getDescFromName(flt_tup.timestep, wind_m.sets[:Ts])) : true)
    # write description of objective
    push!(obj_arr, (flt_tup.variable => (fac = obj[1], flt = flt_func)))
end
# change objective according to near-optimal
objFunc_tup = tuple(vcat([:cost => (fac = 0.0, flt = x -> true)], obj_arr)...)
setObjective!(objFunc_tup, wind_m, nearOpt_ntup.obj[nOpt_int][2][1] == :min)