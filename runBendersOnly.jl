using AnyMOD, Gurobi, CSV, Base.Threads

method = :qtrNoIni
scr = 2
rad = 5e-2
shr = 1e-3
t_int = 4

res = 8760
dir_str = "C:/Users/pacop/Desktop/work/git/TheModel/"

#region # * set and write options

# ! intermediate definitions of parameters

suffix_str = "_" * string(method) * "_" * string(res) * "_s" * string(scr) * "_rad" * string(rad) * "_shr" * string(shr)
inDir_str = [dir_str * "_basis",dir_str * "timeSeries/" * string(res) * "hours_det",dir_str * "timeSeries/" * string(res) * "hours_s" * string(scr) * "_stoch"] # input directory

#coefRngHeu_tup = (mat = (1e-2,1e4), rhs = (1e0,1e4))
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
solOpt_tup = (gap = 0.002, delCut = 20, quadPar = (startRad = rad, lowRad = 1e-6, shrThrs = shr, shrFac = 0.5))

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
top_m = anyModel(modOpt_tup.inputDir, modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, coefRng = modOpt_tup.coefRng, scaFac = modOpt_tup.scaFac, reportLvl = 1)
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

#region # * add quadratic trust region
cutData_dic = Dict{Tuple{Int64,Int64},bendersData}()

if method in (:qtrNoIni,:qtrFixIni,:qtrDynIni)
	# ! get starting solution with heuristic solve or generic
	if method in (:qtrFixIni,:qtrDynIni)
		produceMessage(report_m.options,report_m.report, 1," - Started heuristic pre-solve for starting solution", testErr = false, printErr = false)
		~, heuSol_obj =  @suppress heuristicSolve(optMod_dic[:heu],1.0,t_int,opt_obj,true,true);			
	elseif method == :qtrNoIni
		@suppress optimize!(top_m.optModel)
		heuSol_obj = bendersData()
		heuSol_obj.objVal = Inf
		heuSol_obj.capa = writeResult(top_m,[:capa,:exp,:mustCapa,:mustExp])
	end
	# !  solve sub-problems with capacity of heuristic solution to use for creation of cuts in first iteration
	for x in collect(sub_tup)
		dual_etr = @suppress runSub(sub_dic[x],copy(heuSol_obj),:barrier)
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

		#region # * solve top-problem @suppress 

		startTop = now()
		capaData_obj, allVal_dic, objTopTrust_fl, lowLimTrust_fl = @suppress runTop(top_m,cutData_dic,i);
		timeTop = now() - startTop

		#endregion
		
		#region # * solve of sub-problems 

		startSub = now()
		for x in collect(sub_tup)
			dual_etr = @suppress runSub(sub_dic[x],copy(capaData_obj),:barrier)
			cutData_dic[x] = dual_etr
		end
		timeSub = now() - startSub

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
capaData_obj = bendersData()
capaData_obj.capa = writeResult(top_m,[:capa],true)

# run sub-problems with optimal values fixed
for x in collect(sub_tup)
	runSub(sub_dic[x],copy(capaData_obj),:simplex,true)
end

#endregion

b = "C:/Users/pacop/.julia/dev/AnyMOD.jl/"

using Base.Threads, CSV, Dates, LinearAlgebra, Requires, YAML
using MathOptInterface, Reexport, Statistics, PyCall, SparseArrays
using DataFrames, JuMP, Suppressor
using DelimitedFiles

pyimport_conda("networkx","networkx")
pyimport_conda("matplotlib.pyplot","matplotlib")
pyimport_conda("plotly","plotly")

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