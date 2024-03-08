
using AnyMOD, Gurobi

dir_str = "C:/Users/lgoeke/OneDrive - ETH Zurich/Desktop/Git/EuSysMod/"

# ! input folders
dir_str = b
scr_int = 2 # number of scenarios
res_int = 96

inDir_arr = [dir_str * "_basis",dir_str * "_full",dir_str * "timeSeries/" * string(res_int) * "hours_s" * string(scr_int), dir_str * "timeSeries/" * string(res_int) * "hours_det"] # input directory
# ! test cost optimization
cost_m = @suppress anyModel(inDir_arr, dir_str * "/results", objName = "costOptimization", lvlFrs = 0, supTsLvl = 1, shortExp = 10)
createOptModel!(cost_m)
setObjective!(:cost, cost_m)

set_optimizer(cost_m.optModel, Gurobi.Optimizer)
set_optimizer_attribute(cost_m.optModel, "Crossover", 0);
optimize!(cost_m.optModel)