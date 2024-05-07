using AnyMOD, Gurobi, CSV, YAML, Base.Threads, Dates
include("functions.jl")
#region # * set and write algorithm options

methKey_str = ARGS[1]

# write tuples for stabilization
stabMap_dic = YAML.load_file("stabMap.yaml")
if methKey_str in keys(stabMap_dic)
	meth_tup = tuple(map(x -> Symbol(x[1]) => (; (Symbol(k) => v for (k, v) in x[2])...), collect(stabMap_dic[methKey_str]))...)
else
	meth_tup = tuple()
end

swt_ntup = (itr = 6, avgImp = 0.2, itrAvg = 4)

srsThr = parse(Float64,ARGS[2]) # threshold for serious step
iniStab = parse(Int,ARGS[3]) # initialize stabilization


# range and interpolation method for convergence criteria of subproblems
convSub = parse(Int,ARGS[4])
if convSub == 0
	conSub = (rng = [1e-8,1e-8], int = :lin, crs = true)
elseif convSub == 1
	conSub = (rng = [1e-8,1e-8], int = :lin, crs = false)
elseif convSub == 2
	conSub = (rng = [1e-2,1e-8], int = :lin, crs = false)
elseif convSub == 3
	conSub = (rng = [1e-2,1e-8], int = :exp, crs = false)
elseif convSub == 4
	conSub = (rng = [1e-2,1e-8], int = :log, crs = false)
end

# other settings
gap = 0.002 # optimality gap
useVI = (bal = parse(Bool,ARGS[5]), st = false) # use vaild inequalities

delCut = 20 # number of iterations since cut creation or last binding before cut is deleted

weight_ntup = (capa = 1.0, capaStSize = 1e-1, stLvl = 1e-2)  # weight of variables in stabilization (-> small value for variables with large numbers to equalize)
solOpt = (dbInf = true, numFoc = 3, addVio = 1e6) # options for solving top problem
frs = parse(Int,ARGS[6]) # level of foresight

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)

if parse(Bool,ARGS[7])
	nearOptOpj_tup = ("tradeOffWind_1" => (:min,((0.0,(variable = :capaConv, system = :onshore)),(1.0,(variable = :capaConv, system = :offshore)))),
						"tradeOffWind_2" => (:min,((0.25,(variable = :capaConv, system = :onshore)),(0.75,(variable = :capaConv, system = :offshore)))),
							"tradeOffWind_3" => (:min,((0.5,(variable = :capaConv, system = :onshore)),(0.5,(variable = :capaConv, system = :offshore)))),
								"tradeOffWind_4" => (:min,((0.75,(variable = :capaConv, system = :onshore)),(0.25,(variable = :capaConv, system = :offshore)))),
									"tradeOffWind_5" => (:min,((1.0,(variable = :capaConv, system = :onshore)),(0.0,(variable = :capaConv, system = :offshore)))))

	nearOpt_ntup = (cutThres = 0.1, lssThres = 0.05, optThres = 0.05, feasGap = 0.0001, cutDel = 20, obj = nearOptOpj_tup)
else
	nearOpt_ntup = tuple()
end

reportFreq = 50 # number of iterations report files are written
timeLim = parse(Float64,ARGS[8])  # set a time-limti in minuts for the algorithm

#endregion

#region # * set and write model options

res = 8760 # temporal resolution
scr = parse(Int,ARGS[9]) # number of scenarios
# computational resources
ram = parse(Int,ARGS[10])
t_int = parse(Int,ARGS[11])
dir_str = ""

if !isempty(nearOpt_ntup) && any(getindex.(meth_tup,1) .!= :qtr) error("Near-optimal can only be paired with quadratic stabilization!") end

# ! intermediate definitions of parameters

suffix_str = "_method_" * string(methKey_str) * "_srs_" * string(srsThr) * "_ini_" * string(iniStab) * "_conv_" * string(convSub) * "_vi_" * string(ARGS[5]) * "_scr" * string(scr) # suffix for result files

dir_str = "" # folder with data files
inDir_arr = [dir_str * "_basis",dir_str * "_full",dir_str * "timeSeries/" * string(res) * "hours_s" * string(scr)] # input directory

if iniStab in (0,1)
	heuInDir_arr = inDir_arr
elseif iniStab == 2
	heuInDir_arr =  [dir_str * "_basis",dir_str * "_heu",dir_str * "timeSeries/" * string(res) * "hours_s" * string(scr)]
end 

coefRngHeu_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))
coefRngTop_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))
coefRngSub_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))

scaFacHeu_tup = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
scaFacTop_tup = (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
scaFacSub_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e1, dispSt = 1e3, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)

# ! general input parameters

opt_obj = Gurobi.Optimizer # solver option

# options for different models
optMod_dic = Dict{Symbol,NamedTuple}()

# options for model generation 
optMod_dic[:heu] =  (inputDir = inDir_arr, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngHeu_tup, scaFac = scaFacHeu_tup)
optMod_dic[:top] =  (inputDir = inDir_arr, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngTop_tup, scaFac = scaFacTop_tup)
optMod_dic[:sub] =  (inputDir = inDir_arr, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngSub_tup, scaFac = scaFacSub_tup)

#endregion

#region # * initialize distributed computing

# add workers to job
nb_workers = scr * (frs == 3 ? 4 : 1)
@static if Sys.islinux()
	# MatheClusterManagers is an altered version of https://github.com/JuliaParallel/ClusterManagers.jl by https://github.com/mariok90 to run on the cluster of TU Berlin
	using MatheClusterManagers
	qsub(nb_workers, timelimit=345600, ram=ram, mp = t_int)
	#addprocs_slurm(nb_workers; kwargs...)
else
    addprocs(nb_workers; exeflags="--project=.")
end

using Distributed
@everywhere using AnyMOD, CSV, ParallelDataTransfer, Distributed, Gurobi
opt_obj = Gurobi.Optimizer # solver option

# function to run sub-problems
function runAllSub(sub_tup::Tuple, capaData_obj::resData,sol_sym::Symbol,optTol_fl::Float64,crs::Bool=false,wrtRes::Bool=false)
	solvedFut_dic = Dict{Int, Future}()
	for j in 1:length(sub_tup)
		solvedFut_dic[j] = @spawnat j+1 runSubDis(copy(capaData_obj),sol_sym,optTol_fl,crs,wrtRes)
	end
	return solvedFut_dic
end

# function to get results of sub-problems
function getSubResults!(cutData_dic::Dict{Tuple{Int64,Int64},resData}, sub_tup::Tuple, solvedFut_dic::Dict{Int, Future})
	runTime_arr = Millisecond[]
	for (k,v) in solvedFut_dic
		t_fl, cutData_dic[sub_tup[k]] = fetch(v)
		push!(runTime_arr, t_fl)
	end
	return runTime_arr
end

#endregion

#region # * create top and sub-problems 

report_m = @suppress anyModel(String[],optMod_dic[:heu].resultDir, objName = "decomposition" * optMod_dic[:heu].suffix) # creates empty model just for reporting

# ! start creating top-problem
modOpt_tup = optMod_dic[:top]
top_m = @suppress anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, lvlFrs = frs, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1, createVI = useVI)
sub_tup = tuple([(x.Ts_dis,x.scr) for x in eachrow(top_m.parts.obj.par[:scrProb].data)]...) # get all time-step/scenario combinations

# ! create sub-problems
modOptSub_tup = optMod_dic[:sub]
passobj(1, workers(), [:modOptSub_tup, :sub_tup, :frs, :solOpt, :t_int])
produceMessageShort(" - Start creating sub-problems",report_m)

subTasks_arr = map(workers()) do w
	t = @async @everywhere w begin
		# create sub-problem
		function buildSub(id)
			sub_m = @suppress anyModel(modOptSub_tup.inputDir, modOptSub_tup.resultDir, objName = "subModel_" * string(myid()-1) * modOptSub_tup.suffix, lvlFrs = frs, supTsLvl = modOptSub_tup.supTsLvl,  dbInf = solOpt.dbInf, shortExp = modOptSub_tup.shortExp, coefRng = modOptSub_tup.coefRng, scaFac = modOptSub_tup.scaFac, reportLvl = 1)
			sub_m.subPro = sub_tup[id]
			prepareMod!(sub_m, Gurobi.Optimizer, t_int)
			return sub_m
		end
		const SUB_M = @suppress buildSub(myid() - 1)

		# define function to run sub-problem
		function runSubDis(capaData_obj::resData,sol_sym::Symbol,optTol_fl::Float64,crs::Bool,wrtRes::Bool)
			start_time = now()
			result_obj = @suppress runSub(SUB_M, capaData_obj,sol_sym,optTol_fl,crs,wrtRes)
			elapsed_time = now() - start_time
			println("$(Dates.toms(elapsed_time) / Dates.toms(Second(1))) seconds for $(SUB_M.subPro[1])")
			return elapsed_time, result_obj
		end

		return nothing
	end

	return w => t
end


lvl_df = convM.parts.tech[t_sym].var[:stLvl] 
lvl_df[!,:value] .= value.(lvl_df[!,:var])
return select(lvl_df,Not([:var]))

# ! finish creating top-problem
top_m.subPro = tuple(0,0)
@suppress prepareMod!(top_m,opt_obj,t_int)

# create separate variables for costs of subproblems and aggregate them (cannot be part of model creation, because requires information about subproblems) 
top_m.parts.obj.var[:cut] = map(y -> map(x -> y == 1 ? sub_tup[x][1] : sub_tup[x][2], 1:length(sub_tup)),1:2) |> (z -> createVar(DataFrame(Ts_dis = z[1], scr = z[2]),"subCut",NaN,top_m.optModel,top_m.lock,top_m.sets, scaFac = 1e2))
push!(top_m.parts.obj.cns[:objEqn], (name = :aggCut, cns = @constraint(top_m.optModel, sum(top_m.parts.obj.var[:cut][!,:var]) == filter(x -> x.name == :benders,top_m.parts.obj.var[:objVar])[1,:var])))

# wait for all sub-problems to be created
subTasks_arr = getindex.(values(subTasks_arr), 2)
if all(istaskdone.(subTasks_arr))
	produceMessageShort(" - All sub-problems are ready",report_m)
else
	produceMessageShort(" - Waiting for sub-problems to be ready",report_m)
	wait.(subTasks_arr)
	produceMessageShort(" - Sub-problems ready",report_m)
end

produceMessage(report_m.options,report_m.report, 1," - Created top-problem and sub-problems", testErr = false, printErr = false)

# initialize loop variables
itrReport_df = DataFrame(i = Int[], lowCost = Float64[], bestObj = Float64[], gap = Float64[], curCost = Float64[], time_ges = Float64[], time_top = Float64[], timeMax_sub = Float64[], timeSum_sub = Float64[])
nearOpt_df = DataFrame(i = Int[], timestep = String[], region = String[], system = String[], id = String[], capacity_variable = Symbol[], capacity_value = Float64[], cost = Float64[], lss = Float64[])

#endregion

#region # * add stabilization methods
cutData_dic = Dict{Tuple{Int64,Int64},resData}()

if !isempty(meth_tup)
	
	# ! get starting solution with heuristic solve or generic
	if iniStab != 0
		produceMessage(report_m.options,report_m.report, 1," - Started heuristic pre-solve for starting solution", testErr = false, printErr = false)
		heu_m, startSol_obj =  @suppress heuristicSolve(optMod_dic[:heu],1.0,t_int,opt_obj,rtrnMod = true,solDet = true,fltSt = true);
		lowBd_fl = iniStab == 2 ? 0.0 : value(heu_m.parts.obj.var[:objVar][1,:var])
	else
		@suppress optimize!(top_m.optModel)
		startSol_obj = resData()
		startSol_obj.objVal = value(top_m.parts.obj.var[:objVar][1,:var])
		startSol_obj.capa, startSol_obj.stLvl = writeResult(top_m,[:capa,:exp,:mustCapa,:mustExp,:stLvl])
		lowBd_fl = startSol_obj.objVal
	end

	# initialize iteration variables
	push!(itrReport_df, (i = 0, lowCost = 0, bestObj = Inf, gap = 1.0, curCost = Inf, time_ges = Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60, time_top = 0, timeMax_sub = 0, timeSum_sub = 0))

	# ! solve sub-problems with capacity of heuristic solution to use for creation of cuts in first iteration and to compute corresponding objective value
	solvedFut_dic = @suppress runAllSub(sub_tup, startSol_obj,:barrier,1e-8)
	timeSub = getSubResults!(cutData_dic, sub_tup, solvedFut_dic)
	startSol_obj.objVal = startSol_obj.objVal + sum(map(x -> x.objVal, values(cutData_dic)))

	# write results for first iteration
	timeSubMax_fl = Dates.toms(typeof(timeSub) <: Vector ? maximum(timeSub) : timeSub) / Dates.toms(Second(1))
	timeSubSum_fl = Dates.toms(typeof(timeSub) <: Vector ? sum(timeSub) : timeSub) / Dates.toms(Second(1))
	push!(itrReport_df, (i = 1, lowCost = lowBd_fl, bestObj = startSol_obj.objVal, gap = 1 - lowBd_fl/startSol_obj.objVal, curCost = startSol_obj.objVal, time_ges = Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60, time_top = 0, timeMax_sub = timeSubMax_fl/60, timeSum_sub = timeSubSum_fl/60))
	iIni_fl = 2
	
	# ! initialize stabilization
	stab_obj, eleNum_int = stabObj(meth_tup,swt_ntup,weight_ntup,startSol_obj,lowBd_fl,top_m)
	centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,solOpt.addVio,top_m,report_m)
	produceMessage(report_m.options,report_m.report, 1," - Initialized stabilization with $eleNum_int variables", testErr = false, printErr = false)
else
	stab_obj = nothing
	push!(itrReport_df, (i = 0, lowCost = 0, bestObj = Inf, gap = 1.0, curCost = Inf, time_ges = Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60, time_top = 0, timeMax_sub = 0, timeSum_sub = 0))
	iIni_fl = 0
end

#endregion

#region # * benders iteration

nameStab_dic = Dict(:lvl1 => "level bundle",:lvl2 => "level bundle",:qtr => "quadratic trust-region", :prx => "proximal bundle", :box => "box-step method")

# initialize reporting
if top_m.options.lvlFrs != 0
	stReport_df = DataFrame(i = Int[], timestep_superordinate_expansion = String[], timestep_superordinate_dispatch = String[], timestep_dispatch = String[], region_dispatch = String[], carrier = String[],
			technology = String[], mode = String[], scenario = String[], id = String[], value = Float64[])
end

if !isempty(meth_tup)
	itrReport_df[!,:actMethod] = fill(Symbol(),size(itrReport_df,1))
	foreach(x -> itrReport_df[!,Symbol("dynPar_",x)] = Union{Float64,Vector{Float64}}[fill(Float64[],size(itrReport_df,1))...], stab_obj.method)
end

if !isempty(nearOpt_ntup)
	itrReport_df[!,:objective] = fill("",size(itrReport_df,1))
	nOpt_int = 0
end

# initialize best solution
best_obj = !isempty(meth_tup) ? startSol_obj : resData()

# initialize loop variables
let i = iIni_fl, gap_fl = 1.0, minStep_fl = 0.0, nOpt_int = 0, costOpt_fl = Inf, nearOptObj_fl = Inf, cntNull_int = 0, cntSrs_int = 0, gapTar_fl = gap, lssOpt_fl = Inf
		
	# iteration algorithm
	while true

		produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

		#region # * solve top-problem(s) and sub-problems

		startTop = now()
		resData_obj, stabVar_obj, topCost_fl, estCost_fl, levelDual_fl = @suppress runTop(top_m,cutData_dic,stab_obj,solOpt.numFoc,i); 
		timeTop = now() - startTop

		# get objective value for near-optimal
		if nOpt_int != 0 nearOptObj_fl = objective_value(top_m.optModel) end

		# start sub-problems
		solvedFut_dic = @suppress runAllSub(sub_tup, resData_obj,:barrier,getConvTol(gap_fl,gapTar_fl,conSub),conSub.crs)

		# solve problem without stabilization method
		if !isempty(meth_tup) topCostNoStab_fl, estCostNoStab_fl = @suppress runTopWithoutStab(top_m,stab_obj) end
		
		# if method is prx2, recorf the current cutData_dic
		prevCutData_dic = !isempty(meth_tup) && stab_obj.method[stab_obj.actMet] == :prx2 ? copy(cutData_dic) : nothing

		# get result of sub-problem
		timeSub = getSubResults!(cutData_dic, sub_tup, solvedFut_dic)

		#endregion

		#region # * check results

		# ! updates current best
		expStep_fl = nOpt_int == 0 ? (best_obj.objVal - estCost_fl) : 0.0 # expected step size
		subCost_fl = sum(map(x -> x.objVal, values(cutData_dic))) # objective of sub-problems
		currentCost = topCost_fl + subCost_fl

		if (nOpt_int == 0 ? (topCost_fl + subCost_fl) : (subCost_fl - (estCost_fl - topCost_fl))) < best_obj.objVal
			best_obj.objVal = nOpt_int == 0 ? (topCost_fl + subCost_fl) : (subCost_fl - (estCost_fl - topCost_fl)) # store current best value
			best_obj.capa, best_obj.stLvl = writeResult(top_m,[:capa,:exp,:mustCapa,:stLvl]; rmvFix = true)		
		end

		# reporting on current results
		if top_m.options.lvlFrs != 0 && i%reportFreq == 0 
			stReport_df = writeStLvlRes(top_m,sub_dic,sub_tup,i,stReport_df) 
		end
		
		if !isempty(nearOpt_ntup) nearOpt_df, lss_fl = writeCapaRes(top_m,sub_dic,sub_tup,nearOpt_df,i,nOpt_int,nearOpt_ntup,topCost_fl,subCost_fl,costOpt_fl,lssOpt_fl) end

		#endregion

		#region # * adjust refinements
		
		# ! delete cuts that not were binding for the defined number of iterations
		deleteCuts!(top_m, nOpt_int == 0 ? delCut : nearOpt_ntup.cutDel,i)
		
		# ! adapt center and parameter for stabilization
		if !isempty(meth_tup)
			
			# determine serious step 
			adjCtr_boo = false
			if best_obj.objVal < stab_obj.objVal - srsThr * expStep_fl
				adjCtr_boo = true
			end

			# initialize counters
			cntNull_int = adjCtr_boo ? 0 : cntNull_int + 1
			cntSrs_int = adjCtr_boo ? cntSrs_int + 1 : 0

			# adjust dynamic parameters of stabilization
			prx2Aux_fl = stab_obj.method[stab_obj.actMet] == :prx2 ? computePrx2Aux(cutData_dic,prevCutData_dic) : nothing
			foreach(i -> adjustDynPar!(stab_obj,top_m,i,adjCtr_boo,cntSrs_int,cntNull_int,levelDual_fl,prx2Aux_fl,estCostNoStab_fl,estCost_fl,best_obj.objVal,currentCost,nOpt_int != 0,report_m), 1:length(stab_obj.method))

			# update center of stabilisation
			if adjCtr_boo
				stab_obj.var = filterStabVar(stabVar_obj.capa,stabVar_obj.stLvl,stab_obj.weight,top_m)
				stab_obj.objVal = best_obj.objVal
				produceMessage(report_m.options,report_m.report, 1," - Updated reference point for stabilization!", testErr = false, printErr = false)
			end

			estCost_fl = estCostNoStab_fl # set lower limit for convergence check to lower limit without trust region
		end

		#endregion

		#region # * report on iteration

		# computes optimality gap for cost minimization and feasibility gap for near-optimal
		gap_fl = nOpt_int > 0 ? abs(best_obj.objVal / costOpt_fl) : (1 - estCost_fl/best_obj.objVal)

		timeTop_fl = Dates.toms(timeTop) / Dates.toms(Second(1))
		timeSubMax_fl = Dates.toms(typeof(timeSub) <: Vector ? maximum(timeSub) : timeSub) / Dates.toms(Second(1))
		timeSubSum_fl = Dates.toms(typeof(timeSub) <: Vector ? sum(timeSub) : timeSub) / Dates.toms(Second(1))
		
		if nOpt_int == 0
			produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(estCost_fl, sigdigits = 8)), Upper: $(round(best_obj.objVal, sigdigits = 8)), Optimality gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		else
			produceMessage(report_m.options,report_m.report, 1," - Objective: $(nearOpt_ntup.obj[nOpt_int][1]), Objective value: $(round(nearOptObj_fl, sigdigits = 8)), Feasibility gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		end
		produceMessage(report_m.options,report_m.report, 1," - Time for top: $timeTop_fl Time for sub: $timeSubMax_fl", testErr = false, printErr = false)

		# write to reporting files
		etr_arr = Pair{Symbol,Any}[:i => i, :lowCost => estCost_fl, :bestObj => nOpt_int == 0 ? best_obj.objVal : nearOptObj_fl, :gap => gap_fl, :curCost => topCost_fl + subCost_fl,
						:time_ges => Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60, :time_top => timeTop_fl/60, :timeMax_sub => timeSubMax_fl/60, :timeSum_sub => timeSubSum_fl/60]
		
		if !isempty(meth_tup) # add info about stabilization
			push!(etr_arr, :actMethod => stab_obj.method[stab_obj.actMet])	
			append!(etr_arr, map(x -> Symbol("dynPar_",stab_obj.method[x]) => isa(stab_obj.dynPar[x],Dict) ? [round(stab_obj.dynPar[x][j], sigdigits = 2) for j in keys(stab_obj.dynPar[x])] : stab_obj.dynPar[x], 1:length(stab_obj.method)))
		end

		# add info about near-optimal
		if !isempty(nearOpt_ntup)
			push!(etr_arr,:objective => nOpt_int > 0 ? nearOpt_ntup.obj[nOpt_int][1] : "cost") 
		end

		push!(itrReport_df, (;zip(getindex.(etr_arr,1), getindex.(etr_arr,2))...))
		if i%reportFreq == 0 
			CSV.write(modOpt_tup.resultDir * "/iterationCuttingPlane_$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)
			if !isempty(nearOpt_ntup) CSV.write(modOpt_tup.resultDir * "/nearOptSol_$(replace(top_m.options.objName,"topModel" => "")).csv",  nearOpt_df) end
		end
		
		#endregion
		
		#region # * check convergence and adapt stabilization	
		
		# check for termination
		if gap_fl < gapTar_fl
			if !isempty(nearOpt_ntup) && nOpt_int < length(nearOpt_ntup.obj)
				# switch from cost minimization to near-optimal
				if nOpt_int == 0
					# get characteristics of optimal solution
					costOpt_fl = best_obj.objVal
					lssOpt_fl = lss_fl
					# filter near-optimal solution already obtained
					nearOpt_df[!,:thrs] .= 1 .- best_obj.objVal ./ nearOpt_df[!,:cost]
					filter!(x -> x.thrs <= nearOpt_ntup.cutThres && x.lss <= lssOpt_fl * (1 + nearOpt_ntup.lssThres), nearOpt_df)
					# adjust gap
					gapTar_fl = nearOpt_ntup.feasGap
				end
				# reset iteration variables
				gap_fl = gapTar_fl 
				nearOptObj_fl = Inf
				best_obj.objVal = Inf
				if !isempty(meth_tup) # reset current best tracking for stabilization
					stab_obj.objVal = Inf
					stab_obj.dynPar = writeStabOpt(meth_tup,estCost_fl,best_obj.objVal,top_m)[3]
				end 
				nOpt_int = nOpt_int + 1 # update near-opt counter
				# adapt the objective and constraint to near-optimal
				adaptNearOpt!(top_m,nearOpt_ntup,costOpt_fl,nOpt_int)
				produceMessage(report_m.options,report_m.report, 1," - Switched to near-optimal for $(nearOpt_ntup.obj[nOpt_int][1])", testErr = false, printErr = false)
			else
				produceMessage(report_m.options,report_m.report, 1," - Finished iteration!", testErr = false, printErr = false)
				break
			end
		end

		# switch and update quadratic stabilization method
		if !isempty(meth_tup)
			# switch stabilization method
			if !isempty(stab_obj.ruleSw) && i > stab_obj.ruleSw.itr && length(stab_obj.method) > 1
				min_boo = itrReport_df[i - stab_obj.ruleSw.itr,:actMethod] == stab_obj.method[stab_obj.actMet] # check if method as been used for the minimum number of iterations 
				pro_boo = itrReport_df[(i - min(i,stab_obj.ruleSw.itrAvg) + 1):end,:gap] |> (x -> (x[1]/x[end])^(1/(length(x) -1)) - 1 < stab_obj.ruleSw.avgImp) # check if progress in last iterations is below threshold
				if min_boo && pro_boo
					stab_obj.actMet = stab_obj.actMet + 1 |> (x -> length(stab_obj.method) < x ? 1 : x)
					produceMessage(report_m.options,report_m.report, 1," - Switched stabilization to $(nameStab_dic[stab_obj.method[stab_obj.actMet]]) method!", testErr = false, printErr = false)
				end
			end

			# update stabilization method
			centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,solOpt.addVio,top_m,report_m)
		end

		if Dates.value(floor(now() - report_m.options.startTime,Dates.Minute(1))) > timeLim
			produceMessage(report_m.options,report_m.report, 1," - Aborted due to time-limit!", testErr = false, printErr = false)
			break
		end

		#endregion

		i = i + 1
	end

end

#endregion

#region # * write results

# write dataframe for reporting on iteration
itrReport_df[!,:case] .= suffix_str
CSV.write(modOpt_tup.resultDir * "/iterationCuttingPlane_$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)

if !isempty(nearOpt_ntup)
	CSV.write(modOpt_tup.resultDir * "/nearOptSol_$(replace(top_m.options.objName,"topModel" => "")).csv",  nearOpt_df)
end

# run top-problem with optimal values fixed
@suppress computeFeas(top_m,best_obj.capa,1e-5,wrtRes = true)

# run top-problem and sub-problems with optimal values fixed
solvedFut_dic = @suppress runAllSub(sub_tup, best_obj,:barrier,1e-8,false,true)
wait.(values(solvedFut_dic))

#endregion



