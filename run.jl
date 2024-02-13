using Gurobi, CSV, Statistics
using AnyMOD


# ! string here define scenario, overwrite ARGS with respective values for hard-coding scenarios according to comments
if isempty(ARGS)
    h = "96"
    h_heu = "96"
    scen_number = 9
    t_int = 8
    @info "No arguments provided, default values used." h h_heu scen_number t_int
else    
    h = ARGS[1]#ARGS[1] # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
    h_heu = ARGS[2]#ARGS[2] # resolution of time-series for pre-screening, can be 96, 1752, 4392, or 8760
    scen_number = parse(Int,ARGS[3])
    t_int = parse(Int,ARGS[4]) # number of threads
    @info "Arguments applied" h h_heu scen_number t_int
end

nuc_scen_cost = ["FOAK",
    "NOAK_mean",
    "NOAK_min"]

nuc_scen_ava =["LWR_HTR",
    "LWR_HTR_SFR",
    "LWR_HTR_SMR",
    "LWR_HTR_SMR_SFR",
    "LWR_SFR",
    "LWR_SFR_SMR",
    "LWR_SMR",
    "No_Nuc"]

nuC = nuc_scen_cost[div(scen_number,8,RoundUp)] #ARGS[3] # scenario for nuclear cost
avaNo = scen_number-(div(scen_number,8,RoundUp)-1)*length(nuc_scen_ava)
nuAva = nuc_scen_ava[avaNo]
 #ARGS[3] # scenario for nuclear cost
#nuC = "nucChp_allTec_NOAK"
nuY = "40"#ARGS[4] # scenario for nuclear lifetime


obj_str = h * "hours_" * h_heu * "hoursHeu_" * nuC * "nuCost_" * nuAva * "NuAva_"* nuY * "nuYear"
temp_dir = "tempFix_" * obj_str # directory for temporary folder

if isdir(temp_dir) rm(temp_dir, recursive = true) end
mkdir(temp_dir)

inputMod_arr = ["_basis","nuCost/" * nuC, "nuAva/" * nuAva, "nuYear/" * nuY,"timeSeries/" * h * "hours_2008_only2040",temp_dir]
inputHeu_arr = ["_basis","nuCost/" * nuC, "nuAva/" * nuAva, "nuYear/" * nuY,"timeSeries/" * h_heu * "hours_2008_only2040"]
resultDir_str = mkpath("results")

#region # * perform heuristic solve

coefRngHeuSca_tup = (mat = (1e-2,1e4), rhs = (1e0,1e5))
scaFacHeuSca_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e3, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)

optMod_dic = Dict{Symbol,NamedTuple}()
optMod_dic[:heuSca] =  (inputDir = inputHeu_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)
optMod_dic[:top] 	=  (inputDir = inputMod_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)


 if h_heu != "8760"

     heu_m, heuSca_obj = @suppress heuristicSolve(optMod_dic[:heuSca],1.0,t_int,Gurobi.Optimizer);
     ~, heuCom_obj = @suppress heuristicSolve(optMod_dic[:heuSca],8760/parse(Int,h_heu),t_int,Gurobi.Optimizer)
     # ! write fixes to files and limits to dictionary
     fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m,heuSca_obj,heuCom_obj,(thrsAbs = 0.001, thrsRel = 0.05),true) # get fixed and limited variables
     feasFix_dic = getFeasResult(optMod_dic[:top],fix_dic,lim_dic,t_int,0.001,Gurobi.Optimizer) # ensure feasiblity with fixed variables
     # ! write fixed variable values to files
     writeFixToFiles(fix_dic,feasFix_dic,temp_dir,heu_m; skipMustSt = true)

     if isfile(temp_dir * "/par_FixTech_nuclearPower_expConv.csv") rm(temp_dir * "/par_FixTech_nuclearPower_expConv.csv") end
     if isfile(temp_dir * "/par_FixTech_nuclearPower_capaConv.csv") rm(temp_dir * "/par_FixTech_nuclearPower_capaConv.csv") end

     heu_m = nothing

 end

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
#checkIIS(anyM)

#endregion

#region # * write results

reportResults(:summary,anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:exchange,anyM, addObjName = true)
reportResults(:cost,anyM, addObjName = true)

reportTimeSeries(:electricity,anyM)



#endregion