import Pkg; Pkg.activate(".")
# Pkg.instantiate()
#using AnyMOD, Gurobi, CSV, Base.Threads

b = "C:/Felix Data/PhD/Benders Paper/2nd revision/git/AnyMOD.jl/"

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

#region # * set and write algorithm options withVI_normalStab

suffix_str = "withVI_weightStab1Num1Lvl_onlyRes_minSpillAllDisMitCrt_iniStab"

# defines stabilization options
#meth_tup = (:qtr => (start = 5e-2, low = 1e-6,  thr = 7.5e-4, fac = 2.0),)
meth_tup = (:prx => (start = 1.0, a = 4., min = 0.001, ),)
#meth_tup = (:lvl => (la = 0.5,mu_max=1.0),)
#meth_tup = (:box => (low = 0.05, up = 0.05, minUp = 0.5),)
swt_ntup = (itr = 6, avgImp = 0.2, itrAvg = 4)
#meth_tup = tuple()

weight_ntup = (capa = 1.0, capaStSize = 1e-1, stLvl = 1e-2) # weight of variables in stabilization (-> small value for variables with large numbers to equalize)
iniStab = true # initialize stabilization
srsThr = 0.0 # threshold for serious step
solOpt = (dbInf = true, numFoc = 1, addVio = 1e4) # options for solving top problem

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptOpj_tup = ("tradeOffWind_1" => (:min,((0.0,(variable = :capaConv, system = :onshore)),(1.0,(variable = :capaConv, system = :offshore)))),
					"tradeOffWind_2" => (:min,((0.25,(variable = :capaConv, system = :onshore)),(0.75,(variable = :capaConv, system = :offshore)))))

#nearOpt_ntup = (cutThres = 0.1, lssThres = 0.05, optThres = 0.05, feasGap = 0.0001, cutDel = 20, obj = nearOptOpj_tup)
nearOpt_ntup = tuple()

gap = 0.001
conSub = (rng = [1e-3,1e-8], int = :log) # range and interpolation method for convergence criteria of subproblems
useVI = (bal = false, st = true) # use vaild inequalities
delCut = 20 # number of iterations since cut creation or last binding before cut is deleted

reportFreq = 100 # number of iterations report files are written

#endregion

#region # * set and write model options

res = 96 # temporal resolution
frs = 2 # level of foresight
scr = 2 # number of scenarios
t_int = 4
dir_str = "C:/Felix Data/PhD/Benders Paper/2nd revision/git/EuSysMod/"

if !isempty(nearOpt_ntup) && any(getindex.(meth_tup,1) .!= :qtr) error("Near-optimal can only be paired with quadratic stabilization!") end

# ! intermediate definitions of parameters

#suffix_str = "_" * string(method) * "_" * string(res) * "_s" * string(scr) * "_rad" * string(rad) * "_shr" * string(shr) * "_with" * (useVI.bal ? "" : "outVI")* "VIBal_with" * (useVI.st ? "" : "out") * "VISt"
inDir_arr = [dir_str * "_basis",dir_str * "timeSeries/" * string(res) * "hours_det",dir_str * "timeSeries/" * string(res) * "hours_s" * string(scr) * "_stoch"] # input directory

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

report_m = @suppress anyModel(String[],optMod_dic[:heu].resultDir, objName = "decomposition" * optMod_dic[:heu].suffix) # creates empty model just for reporting

#region # * create top and sub-problems 

# ! create top-problem

modOpt_tup = optMod_dic[:top]

top_m = @suppress anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, lvlFrs = frs, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1, createVI = useVI)

sub_tup = tuple([(x.Ts_dis,x.scr) for x in eachrow(top_m.parts.obj.par[:scrProb].data)]...) # get all time-step/scenario combinations

top_m.subPro = tuple(0,0)
@suppress prepareMod!(top_m,opt_obj,t_int)

# ! create sub-problems

modOptSub_tup = optMod_dic[:sub]

sub_dic = Dict{Tuple{Int,Int},anyModel}()

for (id,x) in enumerate(sub_tup)
	# create sub-problem
	s = @suppress anyModel(modOptSub_tup.inputDir, modOptSub_tup.resultDir, objName = "subModel_" * string(id) * modOptSub_tup.suffix, lvlFrs = frs, supTsLvl = modOptSub_tup.supTsLvl, shortExp = modOptSub_tup.shortExp, coefRng = modOptSub_tup.coefRng, scaFac = modOptSub_tup.scaFac, dbInf = solOpt.dbInf, reportLvl = 1)
	s.subPro = x
	@suppress prepareMod!(s,opt_obj,t_int)
	set_optimizer_attribute(s.optModel, "Threads", t_int)
	sub_dic[x] = s
end

# create separate variables for costs of subproblems and aggregate them (cannot be part of model creation, because requires information about subproblems) 
top_m.parts.obj.var[:cut] = map(y -> map(x -> y == 1 ? sub_tup[x][1] : sub_tup[x][2], 1:length(sub_tup)),1:2) |> (z -> createVar(DataFrame(Ts_dis = z[1], scr = z[2]),"subCut",NaN,top_m.optModel,top_m.lock,top_m.sets, scaFac = 1e2))
push!(top_m.parts.obj.cns[:objEqn], (name = :aggCut, cns = @constraint(top_m.optModel, sum(top_m.parts.obj.var[:cut][!,:var]) == filter(x -> x.name == :benders,top_m.parts.obj.var[:objVar])[1,:var])))

produceMessage(report_m.options,report_m.report, 1," - Created top-problem and sub-problems", testErr = false, printErr = false)

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
		startSol_obj.capa, startSol_obj.stLvl = writeResult(top_m,[:capa,:exp,:mustCapa,:mustExp,:stLvl])
		lowBd_fl = startSol_obj.objVal
	end
	# ! solve sub-problems with capacity of heuristic solution to use for creation of cuts in first iteration and to compute corresponding objective value
	for x in collect(sub_tup)
		dual_etr = @suppress runSub(sub_dic[x],copy(startSol_obj),:barrier)
		cutData_dic[x] = dual_etr
	end
	startSol_obj.objVal = startSol_obj.objVal + sum(map(x -> x.objVal, values(cutData_dic)))
	
	# ! initialize stabilization
	stab_obj, eleNum_int = stabObj(meth_tup,swt_ntup,weight_ntup,startSol_obj,lowBd_fl,top_m)
	centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,solOpt.addVio,top_m,report_m)
	produceMessage(report_m.options,report_m.report, 1," - Initialized stabilization with $eleNum_int variables", testErr = false, printErr = false)
else
	stab_obj = nothing
end

#endregion

#region # * benders iteration

# initialize loop variables
itrReport_df = DataFrame(i = Int[], lowCost = Float64[], bestObj = Float64[], gap = Float64[], curCost = Float64[], time_ges = Float64[], time_top = Float64[], time_sub = Float64[])

nameStab_dic = Dict(:lvl => "level bundle",:qtr => "quadratic trust-region", :prx => "proximal bundle", :box => "box-step method")

# initialize reporting
if top_m.options.lvlFrs != 0
	stReport_df = DataFrame(i = Int[], timestep_superordinate_expansion = String[], timestep_superordinate_dispatch = String[], timestep_dispatch = String[], region_dispatch = String[], carrier = String[],
			technology = String[], mode = String[], scenario = String[], id = String[], value = Float64[])
end

if !isempty(meth_tup)
	itrReport_df[!,:actMethod] = Symbol[]
	foreach(x -> itrReport_df[!,Symbol("dynPar_",x)] = Union{Float64,Vector{Float64}}[], stab_obj.method)
end

if !isempty(nearOpt_ntup)
	nearOpt_df = DataFrame(i = Int[], timestep = String[], region = String[], system = String[], id = String[], capacity_variable = Symbol[], capacity_value = Float64[], cost = Float64[], lss = Float64[])
	itrReport_df[!,:objective] = String[]
	nOpt_int = 0
end

# initialize best solution
best_obj = !isempty(meth_tup) ? startSol_obj : resData()

# initialize loop variables
i = 1
gap_fl = 1.0
minStep_fl = 0.0
nOpt_int = 0
costOpt_fl = Inf
nearOptObj_fl = Inf
null_step_count = 0
serious_step_count = 0
	
# iteration algorithm
while i<100#true

	produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

	#region # * solve top-problem 

	startTop = now()
	resData_obj, stabVar_obj, topCost_fl, estCost_fl, level_dual = @suppress runTop(top_m,cutData_dic,stab_obj,solOpt.numFoc,i); 
	timeTop = now() - startTop

	# get objective value for near-optimal
	if nOpt_int != 0 nearOptObj_fl = objective_value(top_m.optModel) end

	#endregion
	
	#region # * solve of sub-problems  
	startSub = now()
	last_cutData_dic = !isempty(meth_tup) ? cutData_dic : nothing
	for x in collect(sub_tup)
		dual_etr = runSub(sub_dic[x],copy(resData_obj),:barrier,nOpt_int == 0 ? getConvTol(gap_fl,gap,conSub) : conSub.rng[2])
		cutData_dic[x] = dual_etr
	end
	timeSub = now() - startSub

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
		
		# adjust center of stabilization 
		adjCtr_boo = false
		if best_obj.objVal < stab_obj.objVal - srsThr * expStep_fl
			stab_obj.var = filterStabVar(stabVar_obj.capa,stabVar_obj.stLvl,stab_obj.weight,top_m)
			stab_obj.objVal = best_obj.objVal
			adjCtr_boo = true
			produceMessage(report_m.options,report_m.report, 1," - Updated reference point for stabilization!", testErr = false, printErr = false)
		end

		null_step_count = adjCtr_boo ? 0 : null_step_count + 1
		serious_step_count = adjCtr_boo ? serious_step_count + 1 : 0

		# solve problem without stabilization method
		topCostNoStab_fl, estCostNoStab_fl = @suppress runTopWithoutStab(top_m,stab_obj)

		# adjust dynamic parameters of stabilization
		foreach(i -> adjustDynPar!(stab_obj,top_m,i,adjCtr_boo,serious_step_count,null_step_count,level_dual,estCostNoStab_fl,estCost_fl,best_obj.objVal,currentCost,nOpt_int != 0,report_m), 1:length(stab_obj.method))

		estCost_fl = estCostNoStab_fl # set lower limit for convergence check to lower limit without trust region
	end

	#endregion

	#region # * report on iteration

	# computes optimality gap for cost minimization and feasibility gap for near-optimal
	gap_fl = nOpt_int > 0 ? abs(best_obj.objVal / costOpt_fl) : (1 - estCost_fl/best_obj.objVal)

	timeTop_fl = Dates.toms(timeTop) / Dates.toms(Second(1))
	timeSub_fl = Dates.toms(timeSub) / Dates.toms(Second(1))
	if nOpt_int == 0
		produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(estCost_fl, sigdigits = 8)), Upper: $(round(best_obj.objVal, sigdigits = 8)), Optimality gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
	else
		produceMessage(report_m.options,report_m.report, 1," - Objective: $(nearOpt_ntup.obj[nOpt_int][1]), Objective value: $(round(nearOptObj_fl, sigdigits = 8)), Feasibility gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
	end
	produceMessage(report_m.options,report_m.report, 1," - Time for top: $timeTop_fl Time for sub: $timeSub_fl", testErr = false, printErr = false)

	# write to reporting files
	etr_arr = Pair{Symbol,Any}[:i => i, :lowCost => estCost_fl, :bestObj => nOpt_int == 0 ? best_obj.objVal : nearOptObj_fl, :gap => gap_fl, :curCost => topCost_fl + subCost_fl,
					:time_ges => Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60, :time_top => timeTop_fl/60, :time_sub => timeSub_fl/60]
	
	if !isempty(meth_tup) # add info about stabilization
		push!(etr_arr, :actMethod => stab_obj.method[stab_obj.actMet])	
		append!(etr_arr, map(x -> Symbol("dynPar_",stab_obj.method[x]) => isa(stab_obj.dynPar[x],Dict) ? [stab_obj.dynPar[x][j] for j in keys(stab_obj.dynPar[x])] : stab_obj.dynPar[x], 1:length(stab_obj.method)))
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
	if gap_fl < gap
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
				gap = nearOpt_ntup.feasGap
			end
			# reset iteration variables
			gap_fl = gap 
			nearOptObj_fl = Inf
			best_obj.objVal = Inf
			if !isempty(meth_tup) # reset current best tracking for stabilization
				stab_obj.objVal = Inf
				stab_obj.dynPar = writeStabOpt(meth_tup,estCost_fl,best_obj.objVal)[3]
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

	#endregion

	i = i + 1
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
@suppress computeFeas(top_m,best_obj.capa,1e-5,wrtRes_boo = true)

# run top-problem and sub-problems with optimal values fixed
for x in collect(sub_tup)
	runSub(sub_dic[x],copy(best_obj),:barrier,1e-8,true)
end

#endregion