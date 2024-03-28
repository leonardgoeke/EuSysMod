

using AnyMOD, Gurobi

b = "C:/Users/pacop/Desktop/git/EuSysMod/"

inDir_arr = [dir_str * "_basis", dir_str * "_full", dir_str * "timeSeries/" * string(res_int) * "hours_s" * string(scr_int), dir_str * "timeSeries/" * string(res_int) * "hours_det"]

# get optimal costs
cost_m = anyModel(inDir_arr, b* "results", objName = "testCost", supTsLvl = 1, reportLvl = 2, shortExp = 10, coefRng =  (mat = (1e-3,1e5), rhs = (1e-1,1e5)), scaFac = (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3))
createOptModel!(cost_m)
setObjective!(:cost, cost_m)

set_optimizer(cost_m.optModel, Gurobi.Optimizer)
optimize!(cost_m.optModel)


wind_m = anyModel(inDir_arr, b* "results", objName = "testWind", supTsLvl = 1, reportLvl = 2, shortExp = 10, coefRng =  (mat = (1e-3,1e5), rhs = (1e-1,1e5)), scaFac = (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3))
createOptModel!(wind_m)

# set new objective and optimize
setObjective!((:cost => (fac = 0.0, flt = x -> true), :capaConv => (fac = 1.0, flt = x -> x.Te == 20),), wind_m)
# set upper limit on costs
@constraint(wind_m.optModel, costLim, wind_m.parts.obj.var[:objVar][1,:var] <= 1.05 * value(cost_m.parts.obj.var[:objVar][1,:var]))

set_optimizer(wind_m.optModel, Gurobi.Optimizer)
optimize!(wind_m.optModel)

objective_value(wind_m.optModel)
getAllVariables(:capaConv, wind_m, filterFunc = x -> x.Te == 20)

reportResults(:summary, wind_m)
reportResults(:cost, wind_m)