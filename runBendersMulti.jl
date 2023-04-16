using AnyMOD, Gurobi, CSV, Base.Threads

method = Symbol(ARGS[1])
scr = parse(Int,ARGS[2])
rad = parse(Float64,ARGS[3])
shr = parse(Float64,ARGS[4])
ram = parse(Int,ARGS[5])
t_int = parse(Int,ARGS[6])

res = 8760
dir_str = ""

#region # * set and write options

# ! intermediate definitions of parameters

suffix_str = "_" * string(method) * "_" * string(res) * "_s" * string(scr) * "_rad" * string(rad) * "_shr" * string(shr)

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

# options of solution algorithm
solOpt_tup = (gap = 0.002, delCut = 20, quadPar = (startRad = rad, lowRad = 1e-6, shrThrs = shr, shrFac = 0.05))

# options for different models
optMod_dic = Dict{Symbol,NamedTuple}()

# options for model generation 
optMod_dic[:heu] =  (inputDir = inDir_str, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngHeu_tup, scaFac = scaFacHeu_tup)
optMod_dic[:top] =  (inputDir = inDir_str, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngTop_tup, scaFac = scaFacTop_tup)
optMod_dic[:sub] =  (inputDir = inDir_str, resultDir = dir_str * "results", suffix = suffix_str, supTsLvl = 1, shortExp = 10, coefRng = coefRngSub_tup, scaFac = scaFacSub_tup)

#endregion

#region # * initialize workers

using Distributed, MatheClusterManagers # MatheClusterManagers is an altered version of https://github.com/JuliaParallel/ClusterManagers.jl by https://github.com/mariok90 to run on the cluster of TU Berlinn

# add workers to job
nb_workers = scr * 2
@static if Sys.islinux()
    using MatheClusterManagers
    qrsh(nb_workers, timelimit=345600, ram=ram, mp = t_int)
else
    addprocs(nb_workers; exeflags="--project=.")
end

@everywhere using AnyMOD, CSV, ParallelDataTransfer, Distributed, Gurobi
opt_obj = Gurobi.Optimizer # solver option

#endregion

#region # * define functions for distributed

# ! run all sub-problems when running code distributed
function runAllSub(sub_tup::Tuple, capaData_obj::resData,sol::Symbol,wrtRes::Bool=false)
	solvedFut_dic = Dict{Int, Future}()
	for j in 1:length(sub_tup)
		solvedFut_dic[j] = @spawnat j+1 runSubDis(copy(capaData_obj),sol,wrtRes)
	end
	return solvedFut_dic
end

# ! get results of all sub-problems when running code distributed
function getSubResults(cutData_dic::Dict{Tuple{Int64,Int64},resData}, sub_tup::Tuple, solvedFut_dic::Dict{Int, Future})
	runTime_arr = []
	for (k,v) in solvedFut_dic
		t_fl, cutData_dic[sub_tup[k]] = fetch(v)
		push!(runTime_arr, t_fl)
	end
	return maximum(runTime_arr)
end

#endregion


report_m = @suppress anyModel(String[],optMod_dic[:heu].resultDir, objName = "decomposition" * optMod_dic[:heu].suffix) # creates empty model just for reporting

#region # * create top and sub-problems 

produceMessage(report_m.options,report_m.report, 1," - Create top model and sub models", testErr = false, printErr = false)

modOptSub_tup = optMod_dic[:sub]

# ! create sub-problems
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
		function runSubDis(capaData_obj::resData,sol::Symbol,wrtRes::Bool)
			start_time = now()
			result_obj = runSub(SUB_M, capaData_obj,sol,wrtRes)
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
top_m = anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1)
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

#region # * add quadratic trust region
cutData_dic = Dict{Tuple{Int64,Int64},resData}()

if method in (:qtrNoIni,:qtrFixIni,:qtrDynIni)
	# ! get starting solution with heuristic solve or generic
	if method in (:qtrFixIni,:qtrDynIni)
		produceMessage(report_m.options,report_m.report, 1," - Started heuristic pre-solve for starting solution", testErr = false, printErr = false)
		~, heuSol_obj =  @suppress heuristicSolve(optMod_dic[:heu],1.0,t_int,opt_obj,true,true);			
	elseif method == :qtrNoIni
		@suppress optimize!(top_m.optModel)
		heuSol_obj = resData()
		heuSol_obj.objVal = Inf
		heuSol_obj.capa = writeResult(top_m,[:capa,:exp,:mustCapa,:mustExp])
	end
	# !  solve sub-problems with capacity of heuristic solution to use for creation of cuts in first iteration
	solvedFut_dic = runAllSub(sub_tup, copy(heuSol_obj), :barrier)

	for (k,v) in solvedFut_dic
		x = sub_tup[k]
		~, dual_etr = fetch(v)
		# removes entries without dual values
		for sys in [:exc,:tech]
			for sSym in keys(dual_etr.capa[sys])
				for capaSym in keys(dual_etr.capa[sys][sSym])
					if !("dual" in names(dual_etr.capa[sys][sSym][capaSym])) delete!(dual_etr.capa[sys][sSym],capaSym) end
				end
				removeEmptyDic!(dual_etr.capa[sys],sSym)
			end
		end
		cutData_dic[x] = dual_etr
	end

	heuSol_obj.objVal = method == :qtrFixIni ? heuSol_obj.objVal + sum(map(x -> x.objVal, values(cutData_dic))) : Inf
	# ! create quadratic trust region
	trustReg_obj, eleNum_int = quadTrust(heuSol_obj.capa,solOpt_tup.quadPar)
	trustReg_obj.cns = centerQuadTrust(trustReg_obj.var,top_m,trustReg_obj.rad);
	trustReg_obj.objVal = heuSol_obj.objVal
	produceMessage(report_m.options,report_m.report, 1," - Initialized quadratic trust region with $eleNum_int variables", testErr = false, printErr = false)
end

#endregion

#region # * run benders iteration

# initialize loop variables
itrReport_df = DataFrame(i = Int[], low = Float64[], best = Float64[], gap = Float64[], solCur = Float64[], time = Float64[])

let i = 1, gap_fl = 1.0, currentBest_fl = method == :none ? Inf : trustReg_obj.objVal
	while true

		produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

		#region # * solve top-problem and sub-problems

		startTop = now()
		capaData_obj, allVal_dic, objTopTrust_fl, lowLimTrust_fl = @suppress runTop(top_m,cutData_dic,i);
		timeTop = now() - startTop 

		solvedFut_dic = runAllSub(sub_tup, capaData_obj,:barrier)

		#endregion

		#region # * compute bounds and analyze cuts

		if method in (:qtrNoIni,:qtrFixIni,:qtrDynIni) # run top-problem without trust region to obtain lower limits
			objTop_fl, lowLim_fl = @suppress runTopWithoutQuadTrust(top_m,trustReg_obj)
		else # without quad trust region, lower limit corresponds result of unaltered top-problem
			lowLim_fl = lowLimTrust_fl
		end

		# ! delete cuts that not were binding for the defined number of iterations
		deleteCuts!(top_m,solOpt_tup.delCut,i) 

		# ! get objective of sub-problems and current best solution
		timeSub = getSubResults(cutData_dic, sub_tup, solvedFut_dic)
		objSub_fl = sum(map(x -> x.objVal, values(cutData_dic))) # objective of sub-problems
		currentBest_fl = min(objTopTrust_fl + objSub_fl, currentBest_fl) # current best solution

		#endregion

		#region # * result reporting 

		gap_fl = 1 - lowLim_fl/currentBest_fl
		produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(lowLim_fl, sigdigits = 8)), Upper: $(round(currentBest_fl, sigdigits = 8)), gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		produceMessage(report_m.options,report_m.report, 1," - Time for top: $(Dates.toms(timeTop) / Dates.toms(Second(1))) Time for sub: $(Dates.toms(timeSub) / Dates.toms(Second(1)))", testErr = false, printErr = false)
		
		# write to reporting files
		push!(itrReport_df, (i = i, low = lowLim_fl, best = currentBest_fl, gap = gap_fl, solCur = objTopTrust_fl + objSub_fl, time = Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60))
		
		#endregion
		
		#region # * check convergence and adjust limits	
		
		if gap_fl < solOpt_tup.gap
			# ! terminate or adjust quadratic trust region
			produceMessage(report_m.options,report_m.report, 1," - Finished iteration!", testErr = false, printErr = false)
			break
		end

		if method in (:qtrNoIni,:qtrFixIni,:qtrDynIni) # adjust trust region in case algorithm has not converged yet
			global trustReg_obj = adjustQuadTrust(top_m,allVal_dic,trustReg_obj,objSub_fl,objTopTrust_fl,lowLim_fl,lowLimTrust_fl,report_m)
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
capaData_obj.capa = writeResult(top_m,[:capa],true)

# run sub-problems with optimal values fixed
solvedFut_dic = runAllSub(sub_tup, capaData_obj,:simplex,true)
wait.(values(solvedFut_dic))

#endregion