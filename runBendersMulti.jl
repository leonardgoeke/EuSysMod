using AnyMOD, Gurobi, CSV, Base.Threads

#region # * specify setting

# ! settings for stabilization

# stabilization method
method = parse(Int,ARGS[1])
if method == 0 
	meth_tup = tuple()
elseif method == 1
	meth_tup = (:prx => (start = 1.0, low = 0.0, fac = 2.0),)
elseif method == 2
	meth_tup = (:lvl => (la = 0.5,),)
elseif method == 3
	meth_tup = (:qtr => (start = 1e-2, low = 1e-6,  thr = 5e-4, fac = 2.0),)
end

# rules for switching between stabilization methods
switch = parse(Int,ARGS[2])
if switch == 1
	swt_ntup = (itr = 6, avgImp = 0.2, itrAvg = 4)
end

# initialization for method
iniStab = parse(Bool,ARGS[3])

# ! settings for other refinements

# range and interpolation method for convergence criteria of subproblems
convSub = Symbol(ARGS[4])
if convSub == :none
	conSub = (rng = [1e-8,1e-8], int = :lin)
else
	conSub = (rng = [1e-2,1e-8], int = convSub)
end

# use of vaild inequalities
useVI = parse(Bool,ARGS[5])

# ! additional settings

# number of scenarios
scr = parse(Int,ARGS[6])

# computational resources
ram = parse(Int,ARGS[7])
t_int = parse(Int,ARGS[8])

# fixed settings
srsThr = 0.0 # threshold for serious step
dir_str = "" # folder with data files
res = 8760 # temporal resolution
gap = 0.01 # optimality gap
delCut = 20 # number of iterations since cut creation or last binding before cut is deleted

suffix_str = "_method_" * string(method) * "_switch_" * string(switch) * "_ini_" * string(iniStab) * "_conv_" * string(convSub) * "_vi_" * string(useVI) * "_scr" * string(scr) # suffix for result files

#endregion

#region # * write inputs for model objects

# ! intermediate definitions of parameters

#suffix_str = "_" * string(method) * "_" * string(res) * "_s" * string(scr) * "_rad" * string(rad) * "_shr" * string(shr) * "_" * (useVI ? "withVI" : "withoutVI") * "_noBuy"
inDir_str = [dir_str * "_basis",dir_str * "timeSeries/" * string(res) * "hours_det",dir_str * "timeSeries/" * string(res) * "hours_s" * string(scr) * "_stoch"] # input directory

coefRngHeu_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))
coefRngTop_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))
coefRngSub_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))

scaFacHeu_tup = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
scaFacTop_tup = (capa = 1e0, capaStSize = 1e1, insCapa = 1e0, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
scaFacSub_tup = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e2, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)

# ! general input parameters

opt_obj = Gurobi.Optimizer # solver option

# structure of subproblems, indicating the year (first integer) and the scenario (second integer)
sub_tup = tuple(collect((x,y) for x in 1:2, y in 1:scr)...)

# options for different models
optMod_dic = Dict{Symbol,NamedTuple}()

# options for model generation 
optMod_dic[:heu] =  (inputDir = inDir_str, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngHeu_tup, scaFac = scaFacHeu_tup)
optMod_dic[:top] =  (inputDir = inDir_str, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngTop_tup, scaFac = scaFacTop_tup)
optMod_dic[:sub] =  (inputDir = inDir_str, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngSub_tup, scaFac = scaFacSub_tup)

#endregion

#region # * initialize distributed computing

 

# add workers to job
nb_workers = scr * 2
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
function runAllSub(sub_tup::Tuple, capaData_obj::resData,sol_sym::Symbol,optTol_fl::Float64,wrtRes::Bool=false)
	solvedFut_dic = Dict{Int, Future}()
	for j in 1:length(sub_tup)
		solvedFut_dic[j] = @spawnat j+1 runSubDis(copy(capaData_obj),sol_sym,optTol_fl,wrtRes)
	end
	return solvedFut_dic
end

# function to get results of sub-problems
function getSubResults!(cutData_dic::Dict{Tuple{Int64,Int64},resData}, sub_tup::Tuple, solvedFut_dic::Dict{Int, Future})
	runTime_arr = []
	for (k,v) in solvedFut_dic
		t_fl, cutData_dic[sub_tup[k]] = fetch(v)
		push!(runTime_arr, t_fl)
	end
	return maximum(runTime_arr)
end

#endregion

#region # * create top and sub-problems 
report_m = @suppress anyModel(String[],optMod_dic[:heu].resultDir, objName = "decomposition" * optMod_dic[:heu].suffix) # creates empty model just for reporting

produceMessage(report_m.options,report_m.report, 1," - Create top model and sub models", testErr = false, printErr = false)

# ! create sub-problems
modOptSub_tup = optMod_dic[:sub]
passobj(1, workers(), [:modOptSub_tup, :sub_tup,:t_int])
produceMessageShort(" - Start creating sub-problems",report_m)

subTasks_arr = map(workers()) do w
	t = @async @everywhere w begin
		# create sub-problem
		function buildSub(id)
			sub_m = @suppress anyModel(modOptSub_tup.inputDir, modOptSub_tup.resultDir, objName = "subModel_" * string(myid()-1) * modOptSub_tup.suffix,  supTsLvl = modOptSub_tup.supTsLvl, shortExp = modOptSub_tup.shortExp, coefRng = modOptSub_tup.coefRng, scaFac = modOptSub_tup.scaFac, reportLvl = 1)
			sub_m.subPro = sub_tup[id]
			prepareMod!(sub_m, Gurobi.Optimizer, t_int)
			return sub_m
		end
		const SUB_M = @suppress buildSub(myid() - 1)

		# define function to run sub-problem
		function runSubDis(capaData_obj::resData,sol_sym::Symbol,optTol_fl::Float64,wrtRes::Bool)
			start_time = now()
			result_obj = @suppress runSub(SUB_M, capaData_obj,sol_sym,optTol_fl,wrtRes)
			elapsed_time = now() - start_time
			println("$(Dates.toms(elapsed_time) / Dates.toms(Second(1))) seconds for $(SUB_M.subPro[1])")
			return elapsed_time, result_obj
		end

		return nothing
	end

	return w => t
end

# ! create top-problem

modOpt_tup = optMod_dic[:top]
top_m = anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1, createVI = useVI)
top_m.subPro = tuple(0,0)
prepareMod!(top_m,opt_obj,t_int)

# create seperate variables for costs of subproblems and aggregate them (cannot be part of model creation, because requires information about subproblems) 
top_m.parts.obj.var[:cut] = map(y -> map(x -> y == 1 ? top_m.supTs.step[sub_tup[x][1]] : sub_tup[x][2], 1:length(sub_tup)),1:2) |> (z -> createVar(DataFrame(Ts_disSup = z[1], scr = z[2]),"subCut",NaN,top_m.optModel,top_m.lock,top_m.sets, scaFac = 1e2))
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

#endregion

#region # * add stabilization methods
cutData_dic = Dict{Tuple{Int64,Int64},resData}()
if !isempty(meth_tup)

	# ! get starting solution with heuristic solve or generic
	if iniStab
		produceMessage(report_m.options,report_m.report, 1," - Started heuristic pre-solve for starting solution", testErr = false, printErr = false)
		heu_m, startSol_obj =  @suppress heuristicSolve(optMod_dic[:heu],1.0,t_int,opt_obj,rtrnMod = true,solDet = true,fltSt = true);
		lowBd_fl = value(heu_m.parts.obj.var[:objVar][1,:var])
	else
		@suppress optimize!(top_m.optModel)
		startSol_obj = resData()
		startSol_obj.objVal = value(top_m.parts.obj.var[:objVar][1,:var])
		startSol_obj.capa = writeResult(top_m,[:capa,:exp,:mustCapa,:mustExp])
		lowBd_fl = startSol_obj.objVal
	end
	
	# !  solve sub-problems with capacity of heuristic solution to use for creation of cuts in first iteration and to compute corresponding objective value
	solvedFut_dic = @suppress runAllSub(sub_tup, startSol_obj,:barrier,1e-8)
	getSubResults!(cutData_dic, sub_tup, solvedFut_dic)
	startSol_obj.objVal = startSol_obj.objVal + sum(map(x -> x.objVal, values(cutData_dic)))
	
	# ! initialize stabilization
	stab_obj, eleNum_int = stabObj(meth_tup,swt_ntup,startSol_obj.objVal,lowBd_fl,startSol_obj.capa,top_m)
	centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,top_m)
	produceMessage(report_m.options,report_m.report, 1," - Initialized stabilization with $eleNum_int variables", testErr = false, printErr = false)
else
	stab_obj = nothing
end

#endregion

#region # * run benders iteration

# initialize loop variables
itrReport_df = DataFrame(i = Int[], low = Float64[], best = Float64[], gap = Float64[], solCur = Float64[], time = Float64[])

if !isempty(meth_tup)
	itrReport_df[!,:actMethod] = Symbol[]
	foreach(x -> itrReport_df[!,Symbol("dynPar_",x)] = Float64[], stab_obj.method)
end

nameStab_dic = Dict(:lvl => "level bundle",:qtr => "quadratic trust-region", :prx => "proximal bundle")  

let i = 1, gap_fl = 1.0, currentBest_fl = !isempty(meth_tup) ? startSol_obj.objVal : Inf, minStep_fl = 0.0
	while true

		produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

		#region # * solve top-problem and start sub-problems 

		startTop = now()
		capaData_obj, allVal_dic, objTop_fl, lowLim_fl = runTop(top_m,cutData_dic,stab_obj,i); 
		timeTop = now() - startTop

		solvedFut_dic = @suppress runAllSub(sub_tup, capaData_obj,:barrier,getConvTol(gap_fl,gap,conSub))

		#endregion

		#region # * adjust refinements

		# solve problem without stabilization
		if !isempty(meth_tup)
			objTopNoStab_fl, lowLimNoStab_fl = @suppress runTopWithoutStab(top_m,stab_obj) # run top without trust region
		end

		# ! delete cuts that not were binding for the defined number of iterations
		try
			deleteCuts!(top_m,delCut,i)
		catch
			produceMessage(report_m.options,report_m.report, 1," - Skipped deletion of inactive cuts due to numerical problems", testErr = false, printErr = false)
		end

		# ! get objective of sub-problems and current best solution
		timeSub = getSubResults!(cutData_dic, sub_tup, solvedFut_dic)
		expStep_fl = (currentBest_fl - lowLim_fl) # expected step size
		objSub_fl = sum(map(x -> x.objVal, values(cutData_dic))) # objective of sub-problems
		currentBest_fl = min(objTop_fl + objSub_fl, currentBest_fl) # current best solution
		
		# ! adapt center and parameter for stabilization
		if !isempty(meth_tup)
			
			# adjust center of stabilization 
			adjCtr_boo = false
			if currentBest_fl < stab_obj.objVal - srsThr * expStep_fl
				stab_obj.var = filterStabVar(allVal_dic,top_m)
				stab_obj.objVal = currentBest_fl
				adjCtr_boo = true
				produceMessage(report_m.options,report_m.report, 1," - Updated reference point for stabilization!", testErr = false, printErr = false)
			end
			
			# adjust dynamic parameters of stabilization
			foreach(i -> adjustDynPar!(stab_obj,top_m,i,adjCtr_boo,lowLimNoStab_fl,lowLim_fl,currentBest_fl,report_m), 1:length(stab_obj.method))

			lowLim_fl = lowLimNoStab_fl # set lower limit for convergence check to lower limit without trust region
		end

		#endregion

		#region # * result reporting 
		gap_fl = 1 - lowLim_fl/currentBest_fl
		produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(lowLim_fl, sigdigits = 8)), Upper: $(round(currentBest_fl, sigdigits = 8)), gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		produceMessage(report_m.options,report_m.report, 1," - Time for top: $(Dates.toms(timeTop) / Dates.toms(Second(1))) Time for sub: $(Dates.toms(timeSub) / Dates.toms(Second(1)))", testErr = false, printErr = false)
		
		# write to reporting files
		etr_arr = Pair{Symbol,Any}[:i => i, :low => lowLim_fl, :best => currentBest_fl, :gap => gap_fl, :solCur => objTop_fl + objSub_fl,:time => Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60]
		if !isempty(meth_tup) # add info about stabilization
			push!(etr_arr, :actMethod => stab_obj.method[stab_obj.actMet])
			append!(etr_arr, map(x -> Symbol("dynPar_",stab_obj.method[x]) => stab_obj.dynPar[x], 1:length(stab_obj.method)))
		end
		push!(itrReport_df, (;zip(getindex.(etr_arr,1), getindex.(etr_arr,2))...))
		#CSV.write(modOpt_tup.resultDir * "/iterationBenders$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)
		
		#endregion
		
		#region # * check convergence and adapt stabilization	
		
		# check for termination
		if gap_fl < gap
			produceMessage(report_m.options,report_m.report, 1," - Finished iteration!", testErr = false, printErr = false)
			break
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
			centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,top_m)
		end

		#endregion

		i += 1
	end
end

itrReport_df[!,:case] .= suffix_str
CSV.write(modOpt_tup.resultDir * "/iterationBenders$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)

#endregion

#region # * write final results and clean up

# run top-problem with optimal values fixed
foreach(x -> reportResults(x,top_m), [:summary,:cost])
	
# obtain capacities
capaData_obj = resData()
capaData_obj.capa = writeResult(top_m,[:capa])

# run sub-problems with optimal values fixed
solvedFut_dic = @suppress runAllSub(sub_tup, capaData_obj,:barrier,1e-8,true)
wait.(values(solvedFut_dic))

#endregion