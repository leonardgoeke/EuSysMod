import Pkg; Pkg.activate(".")
# Pkg.instantiate()
using AnyMOD, Gurobi, CSV, Base.Threads

b = "C:/Users/lgoeke/git/AnyMOD.jl/"

using Base.Threads, CSV, Dates, LinearAlgebra, Requires, YAML
using MathOptInterface, Reexport, Statistics, SparseArrays, CategoricalArrays
using DataFrames, JuMP, Suppressor
using DelimitedFiles

include(b* "src/objects.jl")
include(b* "src/tools.jl")
include(b* "src/modelCreation.jl")
include(b* "src/decomposition.jl")

include(b* "src/optModel/technology.jl")
include(b* "src/optModel/exchange.jl")
include(b* "src/optModel/system.jl")
include(b* "src/optModel/cost.jl")
include(b* "src/optModel/other.jl")
include(b* "src/optModel/objective.jl")

include(b* "src/dataHandling/mapping.jl")
include(b* "src/dataHandling/parameter.jl")
include(b* "src/dataHandling/readIn.jl")
include(b* "src/dataHandling/tree.jl")
include(b* "src/dataHandling/util.jl")

include(b* "src/dataHandling/gurobiTools.jl")


meth_tup = (:qtr => (start = 5e-2, low = 1e-6,  thr = 7.5e-4, fac = 2.0),)
#meth_tup = (:prx => (start = 0.5, max = 5e0, fac = 2.0),)
#meth_tup = (:lvl => (la = 0.5,),:qtr => (start = 5e-2, low = 1e-6,  thr = 7.5e-4, fac = 2.0))
#meth_tup = tuple()
#meth_tup = (:box => (low = 0.05, up = 0.05, minUp = 0.5),)
swt_ntup = (itr = 6, avgImp = 0.2, itrAvg = 4)

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptOpj_tup = ("tradeOffWind_1" => (:min,((0.0,(variable = :capaConv, system = :onshore)),(1.0,(variable = :capaConv, system = :offshore)))),
					"tradeOffWind_2" => (:min,((0.25,(variable = :capaConv, system = :onshore)),(0.75,(variable = :capaConv, system = :offshore)))))

nearOpt_ntup = (cutThres = 0.1, lssThres = 0.05, optThres = 0.05, feasGap = 0.0001, cutDel = 20, obj = nearOptOpj_tup)
#nearOpt_ntup = tuple()

iniStab = false # initialize stabilizatio
srsThr = 0.0 # threshold for serious step
linStab = (rel = 0.5, abs = 5.0)

suffix_str = "nearOpt_focus2_noChangeCuts"

gap = 0.001
conSub = (rng = [1e-2,1e-8], int = :log) # range and interpolation method for convergence criteria of subproblems
useVI = false # use vaild inequalities
delCut = 20 # number of iterations since cut creation or last binding before cut is deleted

res = 96
scr = 2
t_int = 4
dir_str = "C:/Users/lgoeke/git/EuSysMod/"

#region # * set and write options

if !isempty(nearOpt_ntup) && any(getindex.(meth_tup,1) .!= :qtr) error("Near-optimal can only be paired with quadratic stabilization!") end

# ! intermediate definitions of parameters

#suffix_str = "_" * string(method) * "_" * string(res) * "_s" * string(scr) * "_rad" * string(rad) * "_shr" * string(shr) * "_" * (useVI ? "withVI" : "withoutVI") * "_noBuy"
inDir_str = [dir_str * "_basis",dir_str * "timeSeries/" * string(res) * "hours_det",dir_str * "timeSeries/" * string(res) * "hours_s" * string(scr) * "_stoch"] # input directory

coefRngHeu_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))
coefRngTop_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))
coefRngSub_tup = (mat = (1e-3,1e5), rhs = (1e-1,1e5))

scaFacHeu_tup = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
scaFacTop_tup = (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
scaFacSub_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e1, dispSt = 1e2, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)

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

report_m = @suppress anyModel(String[],optMod_dic[:heu].resultDir, objName = "decomposition" * optMod_dic[:heu].suffix) # creates empty model just for reporting

#region # * create top and sub-problems 
produceMessage(report_m.options,report_m.report, 1," - Create top model and sub models", testErr = false, printErr = false)

# ! create top-problem

modOpt_tup = optMod_dic[:top]
top_m = anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1, createVI = useVI)
top_m.subPro = tuple(0,0)
prepareMod!(top_m,opt_obj,t_int)

# ! create sub-problems

modOptSub_tup = optMod_dic[:sub]

sub_dic = Dict{Tuple{Int,Int},anyModel}()

for (id,x) in enumerate(sub_tup)
	# create sub-problem
	s = anyModel(modOptSub_tup.inputDir, modOptSub_tup.resultDir, objName = "subModel_" * string(id) * modOptSub_tup.suffix, supTsLvl = modOptSub_tup.supTsLvl, shortExp = modOptSub_tup.shortExp, coefRng = modOptSub_tup.coefRng, scaFac = modOptSub_tup.scaFac, reportLvl = 1)
	s.subPro = x
	prepareMod!(s,opt_obj,t_int)
	set_optimizer_attribute(s.optModel, "Threads", t_int)
	sub_dic[x] = s
end

# create seperate variables for costs of subproblems and aggregate them (cannot be part of model creation, because requires information about subproblems) 
top_m.parts.obj.var[:cut] = map(y -> map(x -> y == 1 ? top_m.supTs.step[sub_tup[x][1]] : sub_tup[x][2], 1:length(sub_tup)),1:2) |> (z -> createVar(DataFrame(Ts_disSup = z[1], scr = z[2]),"subCut",NaN,top_m.optModel,top_m.lock,top_m.sets, scaFac = 1e2))
push!(top_m.parts.obj.cns[:objEqn], (name = :aggCut, cns = @constraint(top_m.optModel, sum(top_m.parts.obj.var[:cut][!,:var]) == filter(x -> x.name == :benders,top_m.parts.obj.var[:objVar])[1,:var])))

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
		reportResults(:summary,top_m)
		startSol_obj = resData()
		startSol_obj.objVal = value(top_m.parts.obj.var[:objVar][1,:var])
		startSol_obj.capa = writeResult(top_m,[:capa,:exp,:mustCapa,:mustExp])
		lowBd_fl = startSol_obj.objVal
	end
	# ! solve sub-problems with capacity of heuristic solution to use for creation of cuts in first iteration and to compute corresponding objective value
	for x in collect(sub_tup)
		dual_etr = @suppress runSub(sub_dic[x],copy(startSol_obj),:barrier)
		cutData_dic[x] = dual_etr
	end
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
itrReport_df = DataFrame(i = Int[], lowCost = Float64[], bestObj = Float64[], gap = Float64[], curCost = Float64[], time_ges = Float64[], time_top = Float64[], time_sub = Float64[])

if !isempty(meth_tup)
	itrReport_df[!,:actMethod] = Symbol[]
	foreach(x -> itrReport_df[!,Symbol("dynPar_",x)] = Float64[], stab_obj.method)
end

if !isempty(nearOpt_ntup)
	nearOpt_df = DataFrame(iteration = Int[], timestep = String[], region = String[], system = String[], id = String[], capacity_variable = Symbol[], capacity_value = Float64[], cost = Float64[], lss = Float64[])
	itrReport_df[!,:objective] = String[]
	nOpt_int = 0
end

nameStab_dic = Dict(:lvl => "level bundle",:qtr => "quadratic trust-region", :prx => "proximal bundle", :box => "box-step method")

let i = 1, gap = gap, gap_fl = 1.0, currentBest_fl = !isempty(meth_tup) ? startSol_obj.objVal : Inf, minStep_fl = 0.0, nOpt_int = 0, costOpt_fl = Inf, lssOpt_fl = Inf, nearOptObj_fl = Inf
	while true

		produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

		#region # * solve top-problem 

		startTop = now()
		capaData_obj, allVal_dic, topCost_fl, estCost_fl = @suppress runTop(top_m,cutData_dic,stab_obj,i); 
		timeTop = now() - startTop

		# get objective value for near-optimal
		if nOpt_int != 0 nearOptObj_fl = objective_value(top_m.optModel) end

		#endregion
		
		#region # * solve of sub-problems 
		startSub = now()
		for x in collect(sub_tup)
			dual_etr = @suppress runSub(sub_dic[x],copy(capaData_obj),:barrier,nOpt_int == 0 ? getConvTol(gap_fl,gap,conSub) : conSub.rng[2])
			cutData_dic[x] = dual_etr
			
		end
		timeSub = now() - startSub

		#endregion

		#region # * adjust refinements

		# ! get objective of sub-problems, current best solution and current error of cutting plane
		expStep_fl = nOpt_int == 0 ? (currentBest_fl - estCost_fl) : 0.0 # expected step size
		subCost_fl = sum(map(x -> x.objVal, values(cutData_dic))) # objective of sub-problems
		currentBest_fl = min(nOpt_int == 0 ? (topCost_fl + subCost_fl) : (subCost_fl - (estCost_fl - topCost_fl)), currentBest_fl) # current best value

		# ! delete cuts that not were binding for the defined number of iterations
		try
			deleteCuts!(top_m, nOpt_int == 0 ? delCut : nearOpt_ntup.cutDel,i)
		catch
			produceMessage(report_m.options,report_m.report, 1," - Skipped deletion of inactive cuts due to numerical problems", testErr = false, printErr = false)
		end
		
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

			# solve problem without stabilization method
			topCostNoStab_fl, estCostNoStab_fl = @suppress runTopWithoutStab(top_m,stab_obj) # run top without trust region
			
			# adjust dynamic parameters of stabilization
			foreach(i -> adjustDynPar!(stab_obj,top_m,i,adjCtr_boo,estCostNoStab_fl,estCost_fl,currentBest_fl,nOpt_int != 0,report_m), 1:length(stab_obj.method))
	

			estCost_fl = estCostNoStab_fl # set lower limit for convergence check to lower limit without trust region
		end

		#endregion

		#region # * result reporting

		# computes optimality gap for cost minimization and feasibility gap for near-optimal
		gap_fl = nOpt_int > 0 ? abs(currentBest_fl / costOpt_fl) : (1 - estCost_fl/currentBest_fl)

		timeTop_fl = Dates.toms(timeTop) / Dates.toms(Second(1))
		timeSub_fl = Dates.toms(timeSub) / Dates.toms(Second(1))
		if nOpt_int == 0
			produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(estCost_fl, sigdigits = 8)), Upper: $(round(currentBest_fl, sigdigits = 8)), Optimality gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		else
			produceMessage(report_m.options,report_m.report, 1," - Objective: $(nearOpt_ntup.obj[nOpt_int][1]), Objective value: $(round(nearOptObj_fl, sigdigits = 8)), Feasibility gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		end
		produceMessage(report_m.options,report_m.report, 1," - Time for top: $timeTop_fl Time for sub: $timeSub_fl", testErr = false, printErr = false)

		# write to reporting files
		etr_arr = Pair{Symbol,Any}[:i => i, :lowCost => estCost_fl, :bestObj => nOpt_int == 0 ? currentBest_fl : nearOptObj_fl, :gap => gap_fl, :curCost => topCost_fl + subCost_fl,
						:time_ges => Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60, :time_top => timeTop_fl/60, :time_sub => timeSub_fl/60]
		
		if !isempty(meth_tup) # add info about stabilization
			push!(etr_arr, :actMethod => stab_obj.method[stab_obj.actMet])
			append!(etr_arr, map(x -> Symbol("dynPar_",stab_obj.method[x]) => stab_obj.dynPar[x], 1:length(stab_obj.method)))
		end

		# add info about near-optimal
		if !isempty(nearOpt_ntup)
			push!(etr_arr,:objective => nOpt_int > 0 ? nearOpt_ntup.obj[nOpt_int][1] : "cost") 
		end

		push!(itrReport_df, (;zip(getindex.(etr_arr,1), getindex.(etr_arr,2))...))
		CSV.write(modOpt_tup.resultDir * "/iterationCuttingPlane_$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)
		
		# add results for near-optimal solutions
		
		if !isempty(nearOpt_ntup)
			lss_fl = sum(map(x -> sum(value.(sub_dic[x].parts.bal.var[:lss][!,:var])),sub_tup))
			if nOpt_int == 0 || ((topCost_fl + subCost_fl) <= costOpt_fl * (1 + nearOpt_ntup.cutThres) && lss_fl <= lssOpt_fl * (1 + nearOpt_ntup.lssThres))
				newRes_df = getCapaResult(top_m)
				newRes_df[!,:iteration] .= i
				newRes_df[!,:cost] .= topCost_fl + subCost_fl
				newRes_df[!,:lss] .= lss_fl
				if nOpt_int != 0 newRes_df[!,:thrs] .= (topCost_fl + subCost_fl)/costOpt_fl - 1 end
				append!(nearOpt_df,newRes_df)
			end
		end

		#endregion
		
		#region # * check convergence and adapt stabilization	
		
		# check for termination
		if gap_fl < gap
			if !isempty(nearOpt_ntup) && nOpt_int < length(nearOpt_ntup.obj)
				# switch from cost minimization to near-optimal
				if nOpt_int == 0
					# get characteristics of optimal solution
					costOpt_fl = currentBest_fl
					lssOpt_fl = lss_fl
					# filter near-optimal solution already obtained
					nearOpt_df[!,:thrs] .= 1 .- currentBest_fl ./ nearOpt_df[!,:cost]
					filter!(x -> x.thrs <= nearOpt_ntup.cutThres && x.lss <= lssOpt_fl * (1 + nearOpt_ntup.lssThres), nearOpt_df)
					# adjust gap
					gap = nearOpt_ntup.feasGap
				end
				# reset iteration variables
				gap_fl = gap 
				nearOptObj_fl = Inf
				currentBest_fl = Inf
				if !isempty(meth_tup) # reset current best tracking for stabilization
					stab_obj.objVal = Inf
					stab_obj.dynPar = writeStabOpt(meth_tup)[3]
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
			centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,top_m)
		end

		#endregion

		i = i + 1
	end
end

itrReport_df[!,:case] .= suffix_str
CSV.write(modOpt_tup.resultDir * "/iterationCuttingPlane_$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)

if !isempty(nearOpt_ntup)
	CSV.write(modOpt_tup.resultDir * "/nearOptSol_$(replace(top_m.options.objName,"topModel" => "")).csv",  nearOpt_df)
end

#endregion

#region # * write final results and clean up

# run top-problem with optimal values fixed
foreach(x -> reportResults(x,top_m), [:summary,:cost])
	
# obtain capacities
capaData_obj = resData()
capaData_obj.capa = writeResult(top_m,[:capa])

# run sub-problems with optimal values fixed
for x in collect(sub_tup)
	runSub(sub_dic[x],copy(capaData_obj),:barrier,1e-8,true)
end

#endregion



i = 1
gap_fl = 1.0
currentBest_fl = !isempty(meth_tup) ? startSol_obj.objVal : Inf
minStep_fl = 0.0
nOpt_int = 0
costOpt_fl = Inf
nearOptObj_fl = Inf