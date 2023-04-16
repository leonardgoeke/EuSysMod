using AnyMOD, Gurobi, CSV, Statistics

function filterDE!(feasFixSol_dic::Dict{Symbol, Dict{Symbol, Dict{Symbol, DataFrame}}},mod_m::anyModel)
    de_arr = getfield.(filter(x -> occursin("de",x.val) || occursin("DE",x.val), collect(values(mod_m.sets[:R].nodes))),:idx)
    for sys in (:tech,:exc)
        for sSym in keys(feasFixSol_dic[sys])
            for x in keys(feasFixSol_dic[sys][sSym])
                feasFixSol_dic[sys][sSym][x] = filter(x -> sys == :tech ? !(x.R_exp in de_arr) : !(x.R_from in de_arr && x.R_to in de_arr), feasFixSol_dic[sys][sSym][x])
            end
        end
    end
end

# ! string here define scenario, overwrite ARGS with respective values for hard-coding scenarios according to comments
h = ARGS[1] # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760
h_heu = ARGS[2] # resolution of time-series for pre-screening, can be 96, 1752, 4392, or 8760
trn = ARGS[3] # scenario for transport in germany
t_int = parse(Int,ARGS[4]) # number of threads

engScr = occursin("mix",trn) ? "mix" : "improve"

obj_str = h * "hours_" * h_heu * "hoursHeu_" * trn
temp_dir = "tempFix_" * obj_str # directory for temporary folder

if isdir(temp_dir) rm(temp_dir, recursive = true) end
mkdir(temp_dir)

inputMod_arr = ["_basis","transportScr/" * trn,"timeSeries/" * h * "hours_2008_only2040",temp_dir]
inputWrtEU_arr = ["_basis","transportScr/" * trn,"timeSeries/" * h * "hours_2008_only2040",temp_dir]
inputHeu_arr = ["_basis","transportScr/" * trn,"timeSeries/" * h_heu * "hours_2008_only2040"]

# add folder to fix eu to reference results
if !occursin("reference",trn)
    push!(inputMod_arr, "fixEU_" * engScr * "_" * h)
    push!(inputHeu_arr, "fixEU_" * engScr * "_" * h)
end
resultDir_str = "results"

#region # * perform heuristic solve

coefRngHeuSca_tup = (mat = (1e-2,1e4), rhs = (1e0,1e5))
scaFacHeuSca_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e3, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)

optMod_dic = Dict{Symbol,NamedTuple}()
optMod_dic[:heuSca] =  (inputDir = inputHeu_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)
optMod_dic[:feas] 	=  (inputDir = inputMod_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)
optMod_dic[:wrtEU] 	=  (inputDir = inputWrtEU_arr, resultDir = resultDir_str, suffix = obj_str, supTsLvl = 2, shortExp = 5, coefRng = coefRngHeuSca_tup, scaFac = scaFacHeuSca_tup)

# heuristic presolved not needed if only results for germany are computed anyway
if occursin("reference",trn)
    heu_m, heuSca_obj = @suppress heuristicSolve(optMod_dic[:heuSca],1.0,t_int,Gurobi.Optimizer,fltSt = false);
    ~, heuCom_obj = @suppress heuristicSolve(optMod_dic[:heuSca],8760/parse(Int,h_heu),t_int,Gurobi.Optimizer,fltSt = false)
    # ! write fixes to files and limits to dictionary
    fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m,heuSca_obj,heuCom_obj,(thrsAbs = 0.001, thrsRel = 0.05),true) # get fixed and limited variables
    feasFix_dic = getFeasResult(optMod_dic[:feas],fix_dic,lim_dic,t_int,0.001,Gurobi.Optimizer) # ensure feasiblity with fixed variables
    # filter results for rest of EU and write to folder
    filterDE!(feasFix_dic,heu_m)
    writeFixToFiles(fix_dic,feasFix_dic,temp_dir,heu_m; skipMustSt = false)
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

checkIIS(anyM)

#endregion

#region # * write results

reportResults(:summary,anyM, addRep = (:capaConvOut,), addObjName = true)
reportResults(:exchange,anyM, addObjName = true)
reportResults(:cost,anyM, addObjName = true)

reportTimeSeries(:electricity,anyM)

# write fix for europe fo file

if occursin("reference",trn)
   
    # get feasible capacity solutions
    capaRes_dic = writeResult(anyM,[:capa,:exp,:mustCapa,:mustExp],rmvFix = true, fltSt = false)
    feasFixSol_dic = getFeasResult(optMod_dic[:wrtEU],capaRes_dic,Dict{Symbol,Dict{Symbol,Dict{Symbol,DataFrame}}}(),t_int,0.001,Gurobi.Optimizer)

    # filter results for rest of EU and write to folder
    filterDE!(feasFixSol_dic,anyM)
    writeFixToFiles(feasFixSol_dic,feasFixSol_dic,"fixEU_" * engScr * "_" * h,anyM, skipMustSt = false)

    # move fix from heuristic solution to same folder
    cp(temp_dir,"fixEU_" * engScr * "_" * h * "/heuristicFix")
end

rm(temp_dir, recursive = true)

#endregion