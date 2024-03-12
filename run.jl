using AnyMOD, Gurobi, CSV, Statistics

# For example 2
# ! string here define scenario, overwrite ARGS with respective values for hard-coding scenarios according to comments
h = "96" # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
h_heu = "96" # resolution of time-series for pre-screening, can be 96, 1752, 4392, or 8760
grid = "_gridExp" # scenario for grid expansion, can be "_gridExp" and "_noGridExp"
bevScr = "0" # number of scenario for bev
t_int = 4 # number of threads
#$$$


obj_str = h * "hours_" * h_heu * "hoursHeu" * grid * "_Scenario" * bevScr  

temp_dir = "tempFix_" * obj_str # directory for temporary folder

if isdir(temp_dir)
    rm(temp_dir, recursive=true)
end
mkdir(temp_dir)

# !!! Insert input data of bev scenarios
inputMod_arr = ["_basis", grid, "timeSeries/" * h * "hours_2008_only2040", "_bevScenario/costData_Scr"* bevScr, "_bevScenario/timeSeries_"*h* "_Scr"* bevScr , temp_dir]
inputHeu_arr = ["_basis", grid, "timeSeries/" * h_heu * "hours_2008_only2040", "_bevScenario/costData_Scr" * bevScr, "_bevScenario/timeSeries_"*h_heu *"_Scr"* bevScr ]
resultDir_str = "results"




#region # * perform heuristic solve

coefRngHeuSca_tup = (mat=(1e-2, 1e4), rhs=(1e0, 1e5))
scaFacHeuSca_tup = (capa=1e0, capaStSize=1e2, insCapa=1e1, dispConv=1e1, dispSt=1e3, dispExc=1e3, dispTrd=1e3, costDisp=1e1, costCapa=1e2, obj=1e0)

optMod_dic = Dict{Symbol,NamedTuple}()
optMod_dic[:heuSca] = (inputDir=inputHeu_arr, resultDir=resultDir_str, suffix=obj_str, supTsLvl=2, shortExp=5, coefRng=coefRngHeuSca_tup, scaFac=scaFacHeuSca_tup)
optMod_dic[:top] = (inputDir=inputMod_arr, resultDir=resultDir_str, suffix=obj_str, supTsLvl=2, shortExp=5, coefRng=coefRngHeuSca_tup, scaFac=scaFacHeuSca_tup)

heu_m, heuSca_obj = @suppress heuristicSolve(optMod_dic[:heuSca], 1.0, t_int, Gurobi.Optimizer);
~, heuCom_obj = @suppress heuristicSolve(optMod_dic[:heuSca], 8760 / parse(Int, h_heu), t_int, Gurobi.Optimizer)
# ! write fixes to files and limits to dictionary
fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m, heuSca_obj, heuCom_obj, (thrsAbs=0.001, thrsRel=0.05), true) # get fixed and limited variables
feasFix_dic, ~ = getFeasResult(optMod_dic[:top], fix_dic, lim_dic, t_int, 0.001, Gurobi.Optimizer) # ensure feasiblity with fixed variables
# ! write fixed variable values to files
writeFixToFiles(fix_dic, feasFix_dic, temp_dir, heu_m; skipMustSt=true)

heu_m = nothing

#endregion

#region # * create and solve main model

anyM = anyModel(inputMod_arr, resultDir_str, objName=obj_str, supTsLvl=2, shortExp=5, redStep=1.0, emissionLoss=false, holdFixed=true)

createOptModel!(anyM)
setObjective!(:cost, anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads", t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

checkIIS(anyM)

#endregion

#region # * write results

reportResults(:summary, anyM, addRep=(:capaConvOut,), addObjName=true)
reportResults(:exchange, anyM, addObjName=true)
reportResults(:cost, anyM, addObjName=true)

reportTimeSeries(:electricity, anyM)

#endregion
# test






