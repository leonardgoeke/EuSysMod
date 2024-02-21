using AnyMOD, Gurobi, CSV, Statistics

b = ""

if isempty(ARGS)
    id_int = 2 # id of scenario in corresponding settings.csv
    t_int = 4 # number of threads
else
    id_int = parse(Int,ARGS[1]) # id of scenario in corresponding settings.csv
    t_int = parse(Int,ARGS[2]) # number of threads
end

par_df = CSV.read(b * "settings.csv",DataFrame)


h = string(par_df[id_int,:h]) # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
h_heu = string(par_df[id_int,:h_heu]) # resolution of time-series for pre-screening, can be 96, 1752, 4392, or 8760
nuExt_arr = par_df[id_int,:nuExt] |> (x -> ismissing(x) ? String[] : collect(split(x,", "))) # array of cases for non-existing technologies
nuCost_str = par_df[id_int,:nuCost] # cost case
nuY_str = string(par_df[id_int,:nuYear]) # lifetime case

obj_str = h * "_hours_" * h_heu * "_hoursHeu_" * nuCost_str * "_nuCost_" * join(nuExt_arr,"") * "_nuExt_"* nuY_str * "nuYear"
temp_dir = b * "tempFix_" * obj_str # directory for temporary folder
desFac_dir = b * "desFac_" * obj_str # directory for design factors


if isdir(temp_dir) rm(temp_dir, recursive = true) end
mkdir(x)

inputDes_arr = [b * "_basis", b * "timeSeries/8760hours_2008", b * "nuCost/" * nuCost_str, b * "nuYear/" * nuY_str, map(x -> b * "nuExt/" * x, nuExt_arr)...]
inputHeu_arr = [b * "_basis", b * "timeSeries/" * h_heu * "hours_2008",desFac_dir, b * "nuCost/" * nuCost_str, b * "nuYear/" * nuY_str, map(x -> b * "nuExt/" * x, nuExt_arr)...]
inputMod_arr = [b * "_basis", b * "timeSeries/" * h * "hours_2008",desFac_dir,temp_dir, b * "nuCost/" * nuCost_str, b * "nuYear/" * nuY_str, map(x -> b * "nuExt/" * x, nuExt_arr)...]

resultDir_str = b * "results"

#region # * compute design factors heuristic solve

if false

anyM = anyModel(inputDes_arr,resultDir_str, objName = "designFactors_" * obj_str, supTsLvl = 2, shortExp = 5, redStep = 1.0, emissionLoss = false, holdFixed = true, onlyDesFac = true)
createOptModel!(anyM);
exportDesignFactors!(anyM,desFac_dir,false)

end

#endregion

#region # * perform heuristic solve

coefRngHeuSca_tup = (mat = (1e-2,1e4), rhs = (1e0,1e5))
scaFacHeuSca_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e3, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)

optMod_dic = Dict{Symbol,NamedTuple}()
optMod_dic[:heuSca] =  (inputDir = inputHeu_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)
optMod_dic[:top] 	=  (inputDir = inputMod_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)

heu_m, heuSca_obj = @suppress heuristicSolve(optMod_dic[:heuSca],1.0,t_int,Gurobi.Optimizer);
~, heuCom_obj = @suppress heuristicSolve(optMod_dic[:heuSca],8760/parse(Int,h_heu),t_int,Gurobi.Optimizer)
# ! write fixes to files and limits to dictionary
fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m,heuSca_obj,heuCom_obj,(thrsAbs = 0.001, thrsRel = 0.05),false) # get fixed and limited variables
feasFix_tup = getFeasResult(optMod_dic[:top],fix_dic,lim_dic,t_int,0.001,Gurobi.Optimizer) # ensure feasiblity with fixed variables
# ! write fixed variable values to files
writeFixToFiles(fix_dic,feasFix_tup[1],temp_dir,heu_m; skipMustSt = true)

heu_m = nothing

#endregion

#region # * create and solve main model

anyM = anyModel(inputMod_arr,resultDir_str, objName = obj_str, supTsLvl = 2, shortExp = 5, redStep = 1.0, emissionLoss = false, holdFixed = true)

createOptModel!(anyM)
setObjective!(:cost,anyM)

set_optimizer(anyM.optModel, Gurobi.Optimizer)
set_optimizer_attribute(anyM.optModel, "Method", 2);
set_optimizer_attribute(anyM.optModel, "Crossover", 0);
set_optimizer_attribute(anyM.optModel, "Threads",t_int);
set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5);

optimize!(anyM.optModel)

checkIIS(anyM)

#endregion

#region # * write results

reportResults(:summary,anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:exchange,anyM, addObjName = true)
reportResults(:cost,anyM, addObjName = true)

reportTimeSeries(:electricity,anyM)

#endregion






