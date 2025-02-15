using Gurobi, AnyMOD, CSV, YAML
include("functions.jl")

dir_str = "C:/Users/pacop/Desktop/git/EuSysMod/"
modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = convert(String,par_df[id_int,:spatialScope]) # spatial scope
scenario = convert(String,par_df[id_int,:scenario]) # scenario case
techs = string(par_df[id_int,:techs]) # available technologies
reso = string(par_df[id_int,:resolution]) # spatial resolution
security = string(par_df[id_int,:security]) # security settings
inOos = string(par_df[id_int,:inputOutOfSample]) # capacity folder for out-of-sample testing

# extract benders settings
solve = par_df[id_int,:solve]
wrkCnt = par_df[id_int,:workerCnt]
t_int = par_df[id_int,:threads]
ram = par_df[id_int,:ram]
cutDel = string(par_df[id_int,:cutDel])
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]

name_str = convert(String,par_df[id_int,:name])
checkDet_boo = scenario in "scr" .* string.(1982:2016)

# create files determining scenario setup
scrQrt_arr, scrDir_str = generateScrInfo(checkDet_boo, scenario, setupDir_str, spaSco)
scrQrtHeu_arr, scrDirHeu_str = generateScrInfo(false, "total12_ext0", setupDir_str, spaSco)

#region # * options for algorithm

if cutDel == "50cnt_0.1thres_noStab1"
	del_int = 50
	del_fl = 0.1
	noStab_tup = (upper = 70, inter = :log, sub = 10.0)
elseif cutDel == "50cnt_0.5thres_noStab1"
	del_int = 50
	del_fl = 0.5
	noStab_tup = (upper = 70, inter = :log, sub = 10.0)
elseif cutDel == "50cnt_1thres_noStab1"
	del_int = 50
	del_fl = 0.5
	noStab_tup = (upper = 70, inter = :log, sub = 10.0)
elseif cutDel == "30cnt_0.1thres_noStab1"
	del_int = 30
	del_fl = 0.1
	noStab_tup = (upper = 70, inter = :log, sub = 10.0)
elseif cutDel == "30cnt_0.5thres_noStab1"
	del_int = 30
	del_fl = 0.5
	noStab_tup = (upper = 70, inter = :log, sub = 10.0)
elseif cutDel == "30cnt_1thres_noStab1"
	del_int = 30
	del_fl = 0.5
	noStab_tup = (upper = 70, inter = :log, sub = 10.0)
elseif cutDel == "50cnt_0.1thres_noStab2"
	del_int = 50
	del_fl = 0.1
	noStab_tup = (upper = 1, inter = :log, sub = 1.0)
elseif cutDel == "50cnt_0.5thres_noStab2"
	del_int = 50
	del_fl = 0.5
	noStab_tup = (upper = 1, inter = :log, sub = 1.0)
elseif cutDel == "50cnt_1thres_noStab2"
	del_int = 50
	del_fl = 0.5
	noStab_tup = (upper = 1, inter = :log, sub = 1.0)
elseif cutDel == "30cnt_0.1thres_noStab2"
	del_int = 30
	del_fl = 0.1
	noStab_tup = (upper = 1, inter = :log, sub = 1.0)
elseif cutDel == "30cnt_0.5thres_noStab2"
	del_int = 30
	del_fl = 0.5
	noStab_tup = (upper = 1, inter = :log, sub = 1.0)
elseif cutDel == "30cnt_1thres_noStab2"
	del_int = 30
	del_fl = 0.5
	noStab_tup = (upper = 1, inter = :log, sub = 1.0)
end


# ! options for general algorithm
rngTar_tup = (mat = (1e-2, 1e4), rhs = (1e-2, 1e2))
rngVio_ntup = (stab = 2e1, cut = 1e0, fix = 1e2)

# tolerance stabilized problem, feasibility
tolStab_arr = [1e-6, 1e-6]
interStab_sym = :lin

# tolerance stabilized problem, quadratic convergence
tolStabQ_arr = [1e-6, 1e-6]
interStabQ_sym = :lin

# tolerance without stabilization
tolNoStab_arr = [1e-6, 1e-6]
interNoStab_sym = :none

# target gap, inaccurate cuts options, number of iteration after unused cut is deleted, valid inequalities, number of iterations report is written, time-limit for algorithm, distributed computing?, number of threads, optimizer, solver settings sub and top
algSetup_obj = algSetup(0.01, (cnt = del_int, thres = del_fl), (bal = false, st = true), 2, 7200.0, false, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = false, meth = :barrier, timeLim = 20.0, dbInf = true, threads = t_int, check = false), (numFoc = [0,2,3], dnsThrs = dnsThrs, crs = true, stabTol = (interStab_sym, tolStab_arr), stabTolQ = (interStabQ_sym, tolStabQ_arr), noStabTol =  (interNoStab_sym, tolNoStab_arr), stabMeth = 2, noStabMeth = 2, threads = t_int, check = false))

res_ntup = (general = (:summary, :exchange, :cost), carrierTs = (:electricity, :h2), storage = (write = true, agg = true), duals = (:enBal, :excRestr, :stBal))

# ! options for stabilization

# write tuple for stabilization
stabMap_dic = YAML.load_file(dir_str * "stabMap.yaml")
if trust in keys(stabMap_dic)
	meth_tup = tuple(map(x -> Symbol(x[1]) => (; (Symbol(k) => v for (k, v) in x[2])...), collect(stabMap_dic[trust]))...)
else
	meth_tup = tuple()
end

stabSetup_obj = stabSetup(meth_tup, 0.0, :reduced, 0.01, noStab_tup, true) # :none for last argument will skip initialization, other names just used for setting input folder below

# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = checkDet_boo ? 0 : 3, supTsLvl = 2, repTsLvl = 4, shortExp = 5) 

# ! input folders
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "securitySetup/" * security, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/" * spaSco * "/" * techs, setupDir_str * "resolution/" * reso, scrDir_str, modDir_str * "timeSeries/country_" * time * "_month/general"]
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/general_" * x), unique(getindex.(scrQrt_arr,2)))
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * "month/" * x[1] * "/" * x[2]), scrQrt_arr)

heuDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "securitySetup/" * security, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/" * spaSco * "/" * techs, setupDir_str * "resolution/" * reso, scrDirHeu_str, modDir_str * "timeSeries/country_672h_month/general"]
foreach(x -> push!(heuDir_arr, modDir_str * "timeSeries/country_672h_month/general_" * x), unique(getindex.(scrQrtHeu_arr,2)))
foreach(x -> push!(heuDir_arr, modDir_str * "timeSeries/country_672h_month/" * x[1] * "/" * x[2]), scrQrtHeu_arr)

if inOos != "missing"
	push!(inDir_arr, dir_str * "inputOutOfSample/" * inOos)
	push!(heuDir_arr, dir_str * "inputOutOfSample/" * inOos)
end

# ! result folders
resultDir_str = dir_str * "results/" * (checkDet_boo ? "deterministic" : name_str)

if !checkDet_boo
	restDir!(resultDir_str) 
	restDir!(resultDir_str * "/sub")
end

# ! final folder setting
inputFolder_ntup = (in = inDir_arr, heu = heuDir_arr, results = resultDir_str)
inputFolderSub_ntup = (in = inDir_arr, heu = heuDir_arr, results = resultDir_str * "/sub")

# ! scaling settings
scale_dic = Dict{Symbol,NamedTuple}()

scale_dic[:rng] = rngTar_tup
scale_dic[:facHeu] = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e2, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
scale_dic[:facSub] = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e2, dispSt = 1e2, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)
scale_dic[:facTop] = (capa = 1e4, capaStSize = 1e4, insCapa = 1e4, dispConv = 1e3, dispSt = 1e4, dispExc = 1e3, dispTrd = 1e2, costDisp = 1e1, costCapa = 1e1, obj = 1e3)	

#endregion

#region # * prepare iteration

# initialize distributed computing
if algSetup_obj.dist
	addprocs(16) # add all available nodes
	@everywhere begin
		using Gurobi, AnyMOD
		runSubDist(w_int::Int64, resData_obj::resData, rngVio_fl::Float64, sol_sym::Symbol, optTol_fl::Float64=1e-8, crsOver_boo::Bool=false, check_boo::Bool=false, resultOpt_tup::NamedTuple=NamedTuple()) = Distributed.@spawnat w_int runSub(resData_obj, rngVio_fl, sol_sym, optTol_fl, crsOver_boo, check_boo, resultOpt_tup)
		getComVarDist(w_int::Int64) = Distributed.@spawnat w_int getComVar()
		getSubStringDist(w_int::Int64, res_sym::Symbol) = Distributed.@spawnat w_int getSubString(res_sym)
	end
	passobj(1, workers(), [:info_ntup, :inputFolderSub_ntup, :scale_dic, :algSetup_obj])
else
	runSubDist = x -> nothing
	getComVarDist = x -> nothing
	getSubStringDist = x -> nothing
end

# create benders object
benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, res_ntup, nearOptSetup_obj);

#endregion

#region # * iteration algorithm

runIteration!(benders_obj, runSubDist)

#endregion

#region # * write results

produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
writeBendersResults!(benders_obj, runSubDist, getSubStringDist)

if inOos == "missing"
	outDir_str = dir_str * "inputOutOfSample/" * name_str * "/"
	writeResultsAsInputs!(benders_obj, outDir_str)
end

#endregion


printObject(benders_obj.top.parts.obj.cns[:bendersCuts], benders_obj.top)

benders_obj.cuts.slack

# ! run iteration
import AnyMOD.deleteCuts!, AnyMOD.interItrPar, AnyMOD.removeStab!


produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Started iteration $(benders_obj.itr.cnt.i)", testErr = false, printErr = false)

#region # * solve top-problem and (start) sub-problems
str_time = now()
resData_obj, stabVar_obj, stLvl_dic = runTop(benders_obj);
elpTop_time = now() - str_time
println("cuts before removal: ", size(benders_obj.top.parts.obj.cns[:bendersCuts],1))

# start solving sub-problems
cutData_dic = Dict{Tuple{Int64,Int64},resData}()
timeSub_dic = Dict{Tuple{Int64,Int64},Millisecond}()
lss_dic = Dict{Tuple{Int64,Int64},Float64}()
numFoc_dic = Dict{Tuple{Int64,Int64},Int64}()

acc_fl = interItrPar(benders_obj.itr.gap, benders_obj.algOpt.gap, benders_obj.algOpt.sub.rng, benders_obj.algOpt.sub.int)

if benders_obj.algOpt.dist futData_dic = Dict{Tuple{Int64,Int64},Future}() end
for (id,s) in enumerate(sort(collect(keys(benders_obj.sub))))
	if benders_obj.algOpt.dist # distributed case
		futData_dic[s] = runSubDist(id + 1, copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, acc_fl, benders_obj.algOpt.sub.crs, benders_obj.algOpt.sub.check)
	else # non-distributed case
		cutData_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] = runSub(benders_obj.sub[s], copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, acc_fl, benders_obj.algOpt.sub.crs, benders_obj.algOpt.sub.check)
	end
end

# save current results
curRes_dic = Dict(x => reportResults(x, benders_obj.top, rtnOpt = (:csvDf,), rmvZero = false) for x in benders_obj.report.res.general)

# top-problem without stabilization
strNoStab_time = now()
if !isnothing(benders_obj.stab) 
	# check if top problem without stabilization should be solved again 
	if benders_obj.itr.cnt.i >= benders_obj.itr.cnt.nextNoStab || benders_obj.stab.crossNoStab
		runTopWithoutStab!(benders_obj)
		# compute next iteration to solve top problem
		par_ntup = benders_obj.stab.solveNoStab
		gap_fl = 1 - benders_obj.itr.res[:lowLimCost] / benders_obj.itr.res[:curBest]
		waitTopNoStab_int = max(1, Int(floor(interItrPar(gap_fl, benders_obj.algOpt.gap, [par_ntup.upper,1], par_ntup.inter, par_ntup.sub))))
		benders_obj.itr.cnt.nextNoStab = benders_obj.itr.cnt.i + waitTopNoStab_int
		# only report, if problem without stabilization is not solved again in the next iteration
		if waitTopNoStab_int != 1
			produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Solved top problem without stabilization. Next solve in iteration $(benders_obj.itr.cnt.nextNoStab)", testErr = false, printErr = false)
		end
	else
		# use results of last correct solve as lower bound
		benders_obj.itr.res[:lowLimCost] = benders_obj.itr.res[:estTotCostNoStab]
		# remove stabilization
		removeStab!(benders_obj)
	end
end
elpNoStab_time = now() - strNoStab_time

# get results of sub-problems
if benders_obj.algOpt.dist
	wait.(collect(values(futData_dic)))
	for s in sort(collect(keys(benders_obj.sub)))
		cutData_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] = fetch(futData_dic[s])
	end
end

#endregion

#region # * analyse results and update refinements

# update results and stabilization
updateIteration!(benders_obj, cutData_dic, resData_obj, curRes_dic, stabVar_obj, stLvl_dic)
# report on iteration
reportBenders!(benders_obj, resData_obj, elpTop_time, elpNoStab_time, timeSub_dic, lss_dic, numFoc_dic)

# check convergence and finish
rtn_boo = checkConvergence(benders_obj, lss_dic)

# delete cuts that not were binding for the defined number of iterations
deleteCuts!(benders_obj)

#endregion

benders_obj.itr.cnt.i = benders_obj.itr.cnt.i + 1

benders_obj.cuts.all
benders_obj.cuts.active

benders_obj.top.parts.obj.cns[:bendersCuts]



allAct_arr = map(x -> (x.i, x.Ts_dis, x.scr), eachrow(benders_obj.top.parts.obj.cns[:bendersCuts]))
addCuts_arr = filter(x -> !(benders_obj.cuts.all[x][1] in allAct_arr), benders_obj.cuts.active)

# ! bla

stab_obj = benders_obj.stab
allAct_arr = map(x -> (x.i, x.Ts_dis, x.scr), eachrow(benders_obj.top.parts.obj.cns[:bendersCuts]))
addCuts_arr = filter(x -> !(benders_obj.cuts.all[x][1] in allAct_arr), benders_obj.cuts.active)

if !isempty(addCuts_arr) 
	# save values of previous cut for proximal method variation 2
	benders_obj.cuts.prev = !isnothing(stab_obj) && stab_obj.method[stab_obj.actMet] == :prx2 ? copy(addCuts_arr) : Int[]
	# add cuts and reset collecting array
	addCuts!(benders_obj.top, benders_obj.algOpt.rngVio.cut, benders_obj.cuts.all[addCuts_arr], benders_obj.itr.cnt.i) 
end