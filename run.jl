using AnyMOD, Gurobi, CSV, Statistics

h = ARGS[1]
h_heu = ARGS[2]
ee = ARGS[3]
grid = ARGS[4]
t_int = parse(Int,ARGS[5])

obj_str = h * "hours_" * h_heu * "hoursHeu" * ee * grid
temp_dir = "tempFix_" * obj_str # directory for temporary folder

if isdir(temp_dir) rm(temp_dir, recursive = true) end
mkdir(temp_dir)

inputMod_arr = ["_basis",ee,grid,"timeSeries/" * h * "hours_2008_only2050",temp_dir]
inputHeu_arr = ["_basis",ee,grid,"timeSeries/" * h_heu * "hours_2008_only2050"]
resultDir_str = "results"

#region # * perform heuristic solve

coefRngHeuSca_tup = (mat = (1e-2,1e4), rhs = (1e0,1e5))
scaFacHeuSca_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e3, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)

optMod_dic = Dict{Symbol,NamedTuple}()
optMod_dic[:heuSca] =  (inputDir = inputHeu_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)
optMod_dic[:top] 	=  (inputDir = inputMod_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)

heu_m, heuSca_obj = @suppress heuristicSolve(optMod_dic[:heuSca],1.0,t_int,Gurobi.Optimizer);
~, heuCom_obj = @suppress heuristicSolve(optMod_dic[:heuSca],8760/parse(Int,h_heu),t_int,Gurobi.Optimizer)
# ! write fixes to files and limits to dictionary
fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m,heuSca_obj,heuCom_obj,(thrsAbs = 0.001, thrsRel = 0.05)) # get fixed and limited variables
feasFix_dic = getFeasResult(optMod_dic[:top],fix_dic,lim_dic,t_int,0.001,Gurobi.Optimizer) # ensure feasiblity with fixed variables
# ! write fixed variable values to files
writeFixToFiles(fix_dic,feasFix_dic,temp_dir,heu_m; skipMustSt = true)

if isfile(temp_dir * "/par_FixTech_bevFrtRoadLight_expConv.csv") rm(temp_dir * "/par_FixTech_bevFrtRoadLight_expConv.csv") end

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

# ! write info on h2 grid for qgis
h2Grid_df = select(filter(x -> x.variable == :capaExc && x.exchange == "h2Grid",reportResults(:exchange,anyM, rtnOpt = (:csvDf,))),Not([:timestep_superordinate_expansion,:carrier,:directed,:variable,:exchange]))
h2Grid_df[!,:edge] = map(x -> join([replace(getindex(split(x[y],"<"),4)," " => "") for y in [:region_from,:region_to]],"-"), eachrow(h2Grid_df))
select!(h2Grid_df,Not([:region_from,:region_to]))
h2Grid_df[!,:timestep_superordinate_dispatch] = replace.(getindex.(split.(h2Grid_df[!,:timestep_superordinate_dispatch],"<"),2)," " => "")
h2Grid_df[!,:value] = map(x -> x < 1e-2 ? 0.0 : x,h2Grid_df[!,:value])
filter!(x -> x.value != 0.0, h2Grid_df)

h2Grid_df = unstack(h2Grid_df,:timestep_superordinate_dispatch,:value)

CSV.write(anyM.options.outDir * "/h2Grid_$(anyM.options.outStamp).csv",h2Grid_df)

# ! write info on h2 balance

h2Bal_df = computeResults("h2Bal.yml",anyM, rtnOpt = (:csvDf,))

h2Bal_df = unstack(h2Bal_df,:timestep,:value)
CSV.write(anyM.options.outDir * "/h2Bal_$(anyM.options.outStamp).csv",h2Bal_df)

#endregion







