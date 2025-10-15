using Gurobi, AnyMOD, CSV, YAML

dir_str = "C:/Git/climate2energy/"
include(dir_str * "functions.jl")

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 31 # or 16
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
case = convert(String,par_df[id_int,:case]) # future or historic data
spaSco = convert(String,par_df[id_int,:spatialScope]) # spatial scope
scr = convert(String,par_df[id_int,:scenario]) # scenario case
foresight = par_df[id_int,:foresight] # scenario case

# extract benders settings
optTolStab = par_df[id_int,:optTolStab]
cutDel = string(par_df[id_int,:cutDel])
infeasTop = par_df[id_int,:infeasTop]
wrkCnt = par_df[id_int,:workerCnt]
t_int = par_df[id_int,:threads]
ram = par_df[id_int,:ram]
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]

name_str = convert(String,par_df[id_int,:name])

# create files determining scenario setup
checkDet_boo = scr in "scr" .* string.(case == "fut" ? (2080:2099) : (1995:2014))  
scrQrt_arr, scrDir_str = generateScrInfo(checkDet_boo, scr, dir_str, case)

#region # * options for algorithm

# ! options for general algorithm

# range violations
rngTar_tup = (mat = (1e-2, 1e5), rhs = (1e-2, 1e2))
rngVio_ntup = (stab = 2e2, cut = 1e2, fix = 1e1)

# method for cut management
if cutDel in ("10cnt_1thres", "50cnt_05thres", "100cnt_05thres","noCutDel")
	if cutDel == "10cnt_1thres"
		del_int = 25
		del_fl = 1.0
	elseif cutDel == "50cnt_05thres"
		del_int = 50
		del_fl = 0.5
	elseif cutDel == "100cnt_05thres"
		del_int = 200
		del_fl = 0.5
	elseif cutDel == "noCutDel"
		del_int = 10000
		del_fl = 0.5
	end
	cutMgm_tup = (meth = :slack, opt = (cnt = del_int, thres = del_fl), freq = 1, report = false)
end

if cutDel in ("red1","red05")
	if cutDel == "red1"
		cutMgm_tup = (meth = :redundant, opt = (startFac = 1.0, endFac = 1.0, inter = :lin), freq = 1, report = false)
	elseif cutDel == "red05"
		cutMgm_tup = (meth = :redundant, opt = (startFac = 0.5, endFac = 0.5, inter = :lin), freq = 1, report = false)
	end
end

# tolerance stabilized problem, convergence
tolStab_arr = [optTolStab, optTolStab]
interStab_sym = :log
# tolerance stabilized problem, quadratic convergence
tolStabQ_arr = [optTolStab, optTolStab]
interStabQ_sym = :log

# tolerance stabilized problem, feasibility
tolStabFeas_arr = [1e-6, 1e-6]
interStabFeas_sym = :log
# tolerance without stabilization
tolNoStab_arr = [1e-6, 1e-6]
interNoStab_sym = :lin

# solver options for sub and top problem
subOpt_tup = (rng = [1e-2, 1e-8], int = :none, crs = false, meth = :barrier, timeLim = 30.0, dbInf = true, threads = t_int, check = false)
topOpt_tup = (numFoc = [0,2,3], dnsThrs = dnsThrs, crs = false, stabTol = (interStab_sym, tolStab_arr), stabTolQ = (interStabQ_sym, tolStabQ_arr), stabTolFeas = (interStabFeas_sym, tolStabFeas_arr), noStabTol =  (interNoStab_sym, tolNoStab_arr), stabMeth = 2, noStabMeth = 2, threads = t_int, check = false)

# optimimality gap, cut management, valid inequalities, reporting frequency, time limit, distributed computing, optimizer
algSetup_obj = algSetup(0.001, cutMgm_tup, (bal = false, st = true), 2, 7200.0, false, Gurobi.Optimizer, rngVio_ntup, subOpt_tup, topOpt_tup)
res_ntup = (general = (:summary, :exchange, :cost), carrierTs = (:electricity, :h2), storage = (write = true, agg = true), duals = (:enBal, :excRestr, :stBal))

# ! options for stabilization

# write tuple for stabilization
stabMap_dic = YAML.load_file(dir_str * "stabMap.yaml")
if trust in keys(stabMap_dic)
	meth_tup = tuple(map(x -> Symbol(x[1]) => (; (Symbol(k) => v for (k, v) in x[2])...), collect(stabMap_dic[trust]))...)
else
	meth_tup = tuple()
end

# method, threshold serious step, initialization, minimum value, solve frequency without stabilization, weights in stabilization (in additon to scaling of base problem)
stabSetup_obj = stabSetup(meth_tup, 0.0, :none, 0.1, (upper = 13, inter = :log, sub = 10.0), repVio = true, weight = (capa = 1e0, capaStSize = 1e0, stLvl = 1e0, lim = 1e0))

# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = foresight, supTsLvl = 2, repTsLvl = 4, shortExp = 5, infeasTop = infeasTop != "none") 

# ! input folders
inDir_arr = [dir_str * "basis", dir_str * "spatialScope/" * spaSco, dir_str * "infeasTop/" * infeasTop, scrDir_str, dir_str * "timeSeries/" * case * "_" * time * "h/general"]
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/" * case * "_" * time * "h/" * x[1] * "/" * x[2]), scrQrt_arr)

heuDir_arr = [dir_str * "basis", dir_str * "spatialScope/" * spaSco, dir_str * "infeasTop/" * infeasTop, scrDir_str, dir_str * "timeSeries/" * case * "_" * "672h/general"]
foreach(x -> push!(heuDir_arr, dir_str * "timeSeries/" * case * "_" * "672h/"  * x[1] * "/" * x[2]), scrQrt_arr)

# ! result folders
resultDir_str = dir_str * "results/" * name_str

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
scale_dic[:facTop] = (capa = 1e4, capaStSize = 1e4, insCapa = 1e4, dispConv = 1e3, dispSt = 1e4, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)	

#endregion

#region # * prepare iteration

# initialize distributed computing
if algSetup_obj.dist
	addprocs(wrkCnt) # add all available nodes
	rmprocs(wrkCnt + 2) # remove one node again for main process
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

#=
# create benders object
benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, res_ntup);

#endregion


#region # * iteration algorithm

allRes_df = runIteration!(benders_obj, runSubDist)

#endregion

#region # * write results

produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
writeBendersResults!(benders_obj, runSubDist, getSubStringDist)

#endregion
=#

# ! run iteration

import AnyMOD.reportComplVar!, AnyMOD.interItrPar, AnyMOD.trackCuts!, AnyMOD.removeStab!

benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, res_ntup);
allRes_df = DataFrame(i = Int[], Ts_expSup = Int[], Ts_disSup = Int[], Ts_dis = Int[], R_dis = Int[], R_exp = Int[], R_from = Int[], R_to = Int[], C = Int[], Te = Int[], Exc = Int[], M = Int[], scr = Int[], id = Int[], sub = Tuple[], variable = Symbol[], value = Float64[])

while true

	produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Started iteration $(benders_obj.itr.cnt.i)", testErr = false, printErr = false)

	#region # * solve top-problem and (start) sub-problems
	str_time = now()
	resData_obj, stLvl_dic = runTop(benders_obj);
	trackCuts!(benders_obj)
	elpTop_time = now() - str_time

	# start solving sub-problems
	cutDataPrimal_dic = Dict{Tuple{Int64,Int64},resData}()
	cutDataDual_dic = Dict{Tuple{Int64,Int64},resData}()
	timeSub_dic = Dict{Tuple{Int64,Int64},Millisecond}()
	lss_dic = Dict{Tuple{Int64,Int64},Float64}()
	numFoc_dic = Dict{Tuple{Int64,Int64},Int64}()

	acc_fl = interItrPar(benders_obj.itr.gap, benders_obj.algOpt.gap, benders_obj.algOpt.sub.rng, benders_obj.algOpt.sub.int)

	if benders_obj.algOpt.dist futData_dic = Dict{Tuple{Int64,Int64},Future}() end
	for (id,s) in enumerate(sort(collect(keys(benders_obj.sub))))
		println(s)
		cutDataPrimal_dic[s], cutDataDual_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] = runSubMW(benders_obj.sub[s], benders_obj, copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, benders_obj.algOpt.sub.timeLim, acc_fl, benders_obj.algOpt.sub.crs, benders_obj.algOpt.sub.check)
	end

	# save current results
	curRes_dic = Dict(x => reportResults(x, benders_obj.top, rtnOpt = (:csvDf,), rmvZero = false) for x in benders_obj.report.res.general)

	# top-problem without stabilization
	strNoStab_time = now()
	if !isnothing(benders_obj.stab) 
		# remove stabilization from top problem (to be added again at the end of iteration)
		removeStab!(benders_obj)
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
	srsStep_boo = updateIteration!(benders_obj, cutDataPrimal_dic, resData_obj, curRes_dic, stLvl_dic, cutDataDual_dic)
	# report on iteration
	reportBenders!(benders_obj, resData_obj, elpTop_time, elpNoStab_time, timeSub_dic, lss_dic, numFoc_dic)

	# check convergence and finish
	rtn_boo = checkConvergence(benders_obj, lss_dic)
	
	# track capacity over iterations if activated
	if benders_obj.trackCapa reportComplVar!(allRes_df, resData_obj, benders_obj.itr.cnt.i) end

	#endregion

	benders_obj.itr.cnt.i = benders_obj.itr.cnt.i + 1
	if rtn_boo break end
	
end

benders_obj.itr.best.var.capa[:tech][:h2Cavern]

# ! run MW method
sub_m = benders_obj.sub[(2,1)] 
resData_obj 
rngVio_fl = benders_obj.algOpt.rngVio.fix 
sol_sym = benders_obj.algOpt.sub.meth
timeLim_fl = benders_obj.algOpt.sub.timeLim
optTol_fl =1e-8
crsOver_boo = true
check_boo = false
resultOpt = NamedTuple()

import AnyMOD.filterResData

# ! code, ZFW 67831.1388013352
# debug -> warum entsprechen cut werte nicht meinen erwartungen?
# clean code: check ToDos, solver and alg settings -> start tests
# 6) make parallel -> idea solve MW problem parallel to top with timelimit of last run top
# 7) variationen: test single solve method 