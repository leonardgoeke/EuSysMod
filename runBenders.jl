#using AnyMOD, Gurobi, CSV, Base.Threads

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


include(b* "src/decomposition_new.jl")

#meth_dic = Dict(:qtr => (start = 5e-2, low = 1e-6,  thr = 7.5e-4, fac = 2.0),)
#meth_dic = Dict(:prx => (start = 1e-4, low = 1e-8, ov = 0.9, fac = 2.0),)
meth_dic = Dict(:lvl => (la = 0.5,),:qtr => (start = 5e-2, low = 1e-6,  thr = 7.5e-4, fac = 2.0))
swt_ntup = (itr = 5,avgImp = 0.2, itrAvg = 5)

iniStab = false
useVI = false # use vaild inequalities
gap = 0.01
delCut = 1000 # number of iterations since cut creation or last binding before cut is deleted

res = 96
scr = 2
t_int = 4
dir_str = "C:/Users/lgoeke/git/EuSysMod/"

#region # * set and write options

# ! intermediate definitions of parameters

suffix_str = "test"
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

report_m = @suppress anyModel(String[],optMod_dic[:heu].resultDir, objName = "decomposition" * optMod_dic[:heu].suffix) # creates empty model just for reporting

#region # * create top and sub-problems 
produceMessage(report_m.options,report_m.report, 1," - Create top model and sub models", testErr = false, printErr = false)

# ! create top-problem

modOpt_tup = optMod_dic[:top]
top_m = anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1, createVI = useVI)
top_m.subPro = tuple(0,0)
prepareMod!(top_m,opt_obj,t_int)

# ! create sub-problems

modOpt_tup = optMod_dic[:sub]

sub_dic = Dict{Tuple{Int,Int},anyModel}()

for (id,x) in enumerate(sub_tup)
	# create sub-problem
	s = anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "subModel_" * string(id) * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1)
	s.subPro = x
	prepareMod!(s,opt_obj,t_int)
	set_optimizer_attribute(s.optModel, "Threads", t_int)
	sub_dic[x] = s
end

# create seperate variables for costs of subproblems and aggregate them (cannot be part of model creation, because requires information about subproblems) 
top_m.parts.obj.var[:cut] = map(y -> map(x -> y == 1 ? top_m.supTs.step[sub_tup[x][1]] : sub_tup[x][2], 1:length(sub_tup)),1:2) |> (z -> createVar(DataFrame(Ts_disSup = z[1], scr = z[2]),"subCut",NaN,top_m.optModel,top_m.lock,top_m.sets, scaFac = 1e2))
push!(top_m.parts.obj.cns[:objEqn], (name = :aggCut, cns = @constraint(top_m.optModel, sum(top_m.parts.obj.var[:cut][!,:var]) == filter(x -> x.name == :benders,top_m.parts.obj.var[:objVar])[1,:var])))

#endregion

#region # * do first solve without trust-region or cuts from heuristic solution
cutData_dic = Dict{Tuple{Int64,Int64},resData}()
subRes_dic = Dict(x => Array{resData,1}() for x in collect(sub_tup))

capaData_obj, ~, ~, ~ = @suppress runTop(top_m,cutData_dic,0);

for x in collect(sub_tup)
	dual_etr = @suppress runSub(sub_dic[x],copy(capaData_obj),:barrier)
	push!(subRes_dic[x],dual_etr)
end

#endregion

#region # * add stabilization method

if !isempty(meth_dic)
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
	for x in collect(sub_tup)
		dual_etr = @suppress runSub(sub_dic[x],copy(startSol_obj),:barrier)
		push!(subRes_dic[x],dual_etr)
		cutData_dic[x] = dual_etr
	end
	startSol_obj.objVal = startSol_obj.objVal + sum(map(x -> x.objVal, values(cutData_dic)))
	
	# ! initialize stabilization
	stab_obj, eleNum_int = stabObj(meth_dic,swt_ntup,startSol_obj.objVal,lowBd_fl,startSol_obj.capa,top_m)
	centerStab!(stab_obj.method[stab_obj.actMet],stab_obj,top_m)
	produceMessage(report_m.options,report_m.report, 1," - Initialized stabilization with $eleNum_int variables", testErr = false, printErr = false)
end

#endregion

#region # * run benders iteration

# initialize loop variables
itrReport_df = DataFrame(i = Int[], low = Float64[], best = Float64[], gap = Float64[], solCur = Float64[], stabMeth = Int[], time = Float64[])
nameStab_dic = Dict(:lvl => "level bundle",:qtr => "quadratic trust-region", :prx => "proximal bundle")

let i = 1, gap_fl = 1.0, currentBest_fl = !isempty(meth_dic) ? startSol_obj.objVal : Inf
	while true

		produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

		#region # * solve top-problem 

		startTop = now()
		capaData_obj, allVal_dic, objTop_fl, lowLim_fl = @suppress runTop(top_m,cutData_dic,i);
		timeTop = now() - startTop

		#endregion
		
		#region # * solve of sub-problems 

		startSub = now()
		for x in collect(sub_tup)
			dual_etr = @suppress runSub(sub_dic[x],copy(capaData_obj),:barrier)
			cutData_dic[x] = dual_etr
			push!(subRes_dic[x],dual_etr)
		end
		timeSub = now() - startSub

		#endregion

		#region # * adjust refinements

		# ! get objective of sub-problems and current best solution
		objSub_fl = sum(map(x -> x.objVal, values(cutData_dic))) # objective of sub-problems
		currentBest_fl = min(objTop_fl + objSub_fl, currentBest_fl) # current best solution

		# ! delete cuts that not were binding for the defined number of iterations
		deleteCuts!(top_m,delCut,i)

		# ! adapt center and parameter for stabilization
		if !isempty(meth_dic)
			
			# adjust center of stabilization 
			adjCtr_boo = false
			if currentBest_fl < stab_obj.objVal
				stab_obj.var = filterStabVar(allVal_dic,top_m)
				stab_obj.objVal = currentBest_fl
				adjCtr_boo = true
				produceMessage(report_m.options,report_m.report, 1," - Updated reference point for stabilization!", testErr = false, printErr = false)
			end

			# solve problem without stabilization method
			objTopNoStab_fl, lowLimNoStab_fl = @suppress runTopWithoutStab(top_m,stab_obj) # run top without trust region
			
			# adjust dynamic parameter of stabilization TODO wrap into function at a latter point, see what is not method specific
			opt_tup = stab_obj.methodOpt[stab_obj.actMet]
			if stab_obj.method[stab_obj.actMet] == :qtr # adjust radius of quadratic trust-region
				if !adjCtr_boo && abs(1 - lowLimNoStab_fl / lowLim_fl) < opt_tup.thr && stab_obj.dynPar[stab_obj.actMet] > opt_tup.low
					stab_obj.dynPar[stab_obj.actMet] = max(opt_tup.low,stab_obj.dynPar[stab_obj.actMet] / opt_tup.fac)
					produceMessage(report_m.options,report_m.report, 1," - Reduced quadratic trust-region!", testErr = false, printErr = false)	
				end
			elseif stab_obj.method[stab_obj.actMet] == :prx # adjust penalty term
				if stab_obj.objVal * (1 - opt_tup.ov) + objTopNoStab_fl * opt_tup.ov > objTop_fl + objSub_fl
					stab_obj.dynPar[stab_obj.actMet] = max(opt_tup.low,stab_obj.dynPar[stab_obj.actMet] * opt_tup.fac)
					produceMessage(report_m.options,report_m.report, 1," - Increased penalty term of proximal bundle!", testErr = false, printErr = false)
				elseif stab_obj.objVal * opt_tup.ov + objTopNoStab_fl * (1 - opt_tup.ov) < objTop_fl + objSub_fl && stab_obj.dynPar[stab_obj.actMet] > opt_tup.low
					stab_obj.dynPar[stab_obj.actMet] = max(opt_tup.low,stab_obj.dynPar[stab_obj.actMet] / opt_tup.fac)
					produceMessage(report_m.options,report_m.report, 1," - Reduced penalty term of proximal bundle!", testErr = false, printErr = false)
				end
			elseif stab_obj.method[stab_obj.actMet] == :lvl # adjust level
				stab_obj.dynPar[stab_obj.actMet] = (opt_tup.la * lowLimNoStab_fl  + (1 - opt_tup.la) * currentBest_fl) / top_m.options.scaFac.obj
			end
			lowLim_fl = lowLimNoStab_fl # set lower limit for convergence check to lower limit without trust region
		end

		#endregion

		#region # * result reporting 
		gap_fl = 1 - lowLim_fl/currentBest_fl
		produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(lowLim_fl, sigdigits = 8)), Upper: $(round(currentBest_fl, sigdigits = 8)), gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
		produceMessage(report_m.options,report_m.report, 1," - Time for top: $(Dates.toms(timeTop) / Dates.toms(Second(1))) Time for sub: $(Dates.toms(timeSub) / Dates.toms(Second(1)))", testErr = false, printErr = false)
		
		# write to reporting files
		push!(itrReport_df, (i = i, low = lowLim_fl, best = currentBest_fl, gap = gap_fl, solCur = objTop_fl + objSub_fl, stabMeth = isempty(meth_dic) ? 0 : stab_obj.actMet,time = Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60))
		CSV.write(modOpt_tup.resultDir * "/iterationBenders$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)
		
		#endregion
		
		#region # * check convergence and adapt stabilization	
		
		# check for termination
		if gap_fl < gap
			produceMessage(report_m.options,report_m.report, 1," - Finished iteration!", testErr = false, printErr = false)
			break
		end

		# switch and update stabilization method
		if !isempty(meth_dic)
			# switch stabilization method
			if !isempty(stab_obj.ruleSw) && i > stab_obj.ruleSw.itr
				min_boo = itrReport_df[i - stab_obj.ruleSw.itr,:stabMeth] == stab_obj.actMet # check if method as been used for the minimum number of iterations 
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
CSV.write(modOpt_tup.resultDir * "/iterationBenders$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)

#endregion

#region # * write final results and clean up

# run top-problem with optimal values fixed
foreach(x -> reportResults(x,top_m), [:summary,:cost])
	
# obtain capacities
capaData_obj = resData()
capaData_obj.capa = writeResult(top_m,[:capa],true)

# run sub-problems with optimal values fixed
for x in collect(sub_tup)
	runSub(sub_dic[x],copy(capaData_obj),:simplex,true)
end

#endregion


