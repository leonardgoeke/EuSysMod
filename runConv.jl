import Pkg; Pkg.activate(".")
# Pkg.instantiate()
# ! import AnyMOD and packages

using AnyMOD, Gurobi

scr = parse(Int,ARGS[1])
t_int = parse(Int,ARGS[2])

b = "" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/8760hours_det",b * "timeSeries/8760hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"

scr = 2
t_int = 4
b = "" # add the model dir here
input_arr = [b * "_basis",b * "timeSeries/96hours_det",b * "timeSeries/96hours_s" * string(scr) * "_stoch"]
resultDir_str = b * "results"

# create and solve model
anyM = anyModel(input_arr, resultDir_str, objName = "conv_s" * string(scr), lvlFrs = 2, supTsLvl = 1, reportLvl = 2, shortExp = 10, checkRng = (print = true, all = true), coefRng = (mat = (1e-2,1e3), rhs = (1e0,1e3)), scaFac =  (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3))
createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);

optimize!(anyM.optModel)

reportResults(:cost,anyM)
reportResults(:summary,anyM)
reportResults(:exchange,anyM)

printObject(anyM.parts.tech[:pumpedStorage].cns[:stBal],anyM)
allSt_df = DataFrame(timestep_superordinate_expansion = String[], timestep_superordinate_dispatch = String[], timestep_dispatch = String[], region_dispatch = String[], carrier = String[],
            technology = String[], mode = String[], scenario = String[], id = String[], variable = Float64[])


for x in [:h2Cavern,:pumpedStorage,:reservoir]
    data_df = printObject(anyM.parts.tech[x].var[:stLvl],anyM,rtnDf = (:csvDf,))
    append!(allSt_df,data_df)
end

CSV.write("test.csv",allSt_df)
# objective mit unterschieden cyclic: 5.11182075e+01

# compute near optimal solution
costOpt_fl = objective_value(anyM.optModel)*1.05*1e3


obj_tup = (:cost => (fac = 0.0,flt = x -> true),:capaExc => (fac = 1.0, flt = x -> x.R_from == 3 && x.Exc == sysInt(:hvac,anyM.sets[:Exc])))
@suppress setObjective!(obj_tup,anyM,true)

# delete old restriction to near optimum
if :nearOpt in keys(anyM.parts.obj.cns) delete(anyM.optModel,anyM.parts.obj.cns[:nearOpt][1,:cns]) end

# restrict system costs to near-optimum
cost_expr = sum(filter(x -> x.name in (:cost,:benders), anyM.parts.obj.var[:objVar])[!,:var])
nearOpt_eqn = @constraint(anyM.optModel, costOpt_fl  >= cost_expr)
anyM.parts.obj.cns[:nearOpt] = DataFrame(cns = nearOpt_eqn)

optimize!(anyM.optModel)

nearOpt_fl = objective_value(anyM.optModel)