using AnyMOD, Gurobi, CSV, Base.Threads

method = ARGS[1]
resHeu = parse(Int,ARGS[2])
resMod = parse(Int,ARGS[3])
t_int = parse(Int,ARGS[4])
b = ""

# ! set options paramters

reso_tup = (heu = resHeu, mod = resMod) 

# options of solution algorithm
solOpt_tup = (gap = 0.05, alg = :benders, heu = Symbol(method), linPar = (thrsAbs = 0.001, thrsRel = 0.02), quadPar = (startRad = 1e-2, lowRad = 1e-5 , shrThrs = 0.001, extThrs = 0.001))

# options for model creation
suffix_str = "_" * method * "_" * string(resHeu) * "_" * string(resMod)
temp_dir = b * "tempFix" * suffix_str
inDir_arr = [[b * "_basis",b * "_test",b * "timeSeries/" * string(x) * "days_2010"] for x in [reso_tup.heu, reso_tup.mod]] # input directories
modOpt_tup = (supTsLvl = 2, shortExp = 5, opt = Gurobi.Optimizer, suffix = suffix_str, resultDir = b * "results", heuIn = inDir_arr[1], modIn = inDir_arr[2])

sub_tup = ((1,0),(2,0),(3,0),(4,0),(5,0),(6,0),(7,0)) # structure of subproblems, indicating the year (first integer) and the scenario (second integer)

report_m = anyModel(String[],modOpt_tup.resultDir, objName = "decomposition" * modOpt_tup.suffix) # creates empty model just for reporting

#region # * solve heuristic models and write results 

if solOpt_tup.heu != :none
	# ! heuristic solve for re-scaled and compressed time-series
	produceMessage(report_m.options,report_m.report, 1," - Started heuristic pre-solve", testErr = false, printErr = false)
	heu_m, heuSca_obj = heuristicSolve(modOpt_tup,1.0,t_int)
	~, heuCom_obj = heuristicSolve(modOpt_tup,365/reso_tup.heu,t_int)
	
	# ! write fixes to files and limits to dictionary
	fix_dic, lim_dic, cntHeu_arr = evaluateHeu(heu_m,heuSca_obj,heuCom_obj,solOpt_tup.linPar) # get fixed and limited variables
	feasFix_dic = @suppress getFeasResult(modOpt_tup,fix_dic,lim_dic,t_int) # ensure feasiblity with fixed variables
	produceMessage(report_m.options,report_m.report, 1," - Heuristic found $(cntHeu_arr[1]) fixed variables and $(cntHeu_arr[2]) limited variables", testErr = false, printErr = false)
	
	# ! write fixed variable values to files
	rm(temp_dir; force = true, recursive = true)
	mkdir(temp_dir) # create directory for fixing files
	parFix_dic = defineParameter(heu_m.options,heu_m.report) # stores parameter info for fixing

	# loop over variables
	for sys in (:tech,:exc), sSym in keys(fix_dic[sys]), varSym in keys(fix_dic[sys][sSym])
		fix_df = feasFix_dic[sys][sSym][varSym] |> (w -> innerjoin(w,select(fix_dic[sys][sSym][varSym],Not([:value])), on = intersect(intCol(w,:dir),intCol(fix_dic[sys][sSym][varSym],:dir))))
		# create file name
		par_sym = Symbol(varSym,:Fix)
		fileName_str = temp_dir * "/par_Fix" * string(makeUp(sys)) * "_" * string(sSym) * "_" * string(varSym)
		# correct values for scaling factor
		fix_df[!,:value] = fix_df[!,:value] .* getfield(heu_m.options.scaFac,occursin("exp",string(varSym)) ? :insCapa : :capa)
		# correct values by adding residual capacities
		if occursin("capa",string(varSym))
			resVal_df = copy(getfield(heu_m.parts,sys)[sSym].var[varSym])
			resVal_df[!,:resi] = map(x -> x.constant, resVal_df[!,:var])
			fix_df = innerjoin(fix_df,select(resVal_df,Not([:var])), on = intCol(fix_df,:dir))
			fix_df[!,:value] = fix_df[!,:value] .+ fix_df[!,:resi]
			select!(fix_df,Not([:resi]))	
		end
		# writes parameter file
		writeParameterFile!(heu_m,fix_df,par_sym,parFix_dic[par_sym],fileName_str)
	end	
end

#endregion

#region # * create top and sublevel problems 
produceMessage(report_m.options,report_m.report, 1," - Create top model and sub models", testErr = false, printErr = false)

# ! create top level problem
inputDir_arr = solOpt_tup.heu != :none ? vcat(modOpt_tup.modIn,[temp_dir]) : modOpt_tup.modIn

top_m = anyModel(inputDir_arr,modOpt_tup.resultDir, objName = "topModel" * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, reportLvl = 1, holdFixed = true, checkRng = true)
top_m.subPro = tuple(0,0)
@suppress prepareMod!(top_m,modOpt_tup.opt,t_int)

# ! create sub level problems (geht parallel!)

sub_dic = Dict{Tuple{Int,Int},anyModel}()
sub_lock = ReentrantLock()

for (id,x) in enumerate(sub_tup)
	# create sub problem
	s = anyModel(inputDir_arr,modOpt_tup.resultDir, objName = "subModel_" * string(id) * modOpt_tup.suffix, supTsLvl = modOpt_tup.supTsLvl, shortExp = modOpt_tup.shortExp, reportLvl = 1, holdFixed = true)
	s.subPro = x
	prepareMod!(s,modOpt_tup.opt,t_int)
	sub_dic[x] = s
end

# create seperate variables for costs of subproblems and aggregate them (cannot be part of model creation, because requires information about subproblems) 
top_m.parts.obj.var[:cut] = map(y -> map(x -> y == 1 ? top_m.supTs.step[x] : sub_tup[x][2], 1:length(sub_tup)),1:2) |> (z -> createVar(DataFrame(Ts_disSup = z[1], scr = z[2]),"subCut",NaN,top_m.optModel,top_m.lock,top_m.sets, scaFac = 1e2))
push!(top_m.parts.obj.cns[:objEqn], (name = :aggCut, group = :benders, cns = @constraint(top_m.optModel, sum(top_m.parts.obj.var[:cut][!,:var]) == filter(x -> x.name == :benders,top_m.parts.obj.var[:objVar])[1,:var])))

#endregion

#region # * add linear and quadratic trust region

currentBest_fl = 0.0

if solOpt_tup.heu != :none
	produceMessage(report_m.options,report_m.report, 1," - Create cuts from heuristic solution", testErr = false, printErr = false)
	# ! create cuts from heuristic solutions  
	for z in [heuCom_obj,heuSca_obj]
		# run subproblems and get cut info
		cutData_dic = Dict{Tuple{Int64,Int64},bendersData}()
		@threads for x in collect(sub_tup)
			dual_etr = runSubLevel(sub_dic[x],copy(z))
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
		# add cuts to top problem	
		addCuts!(top_m,cutData_dic,0)
	end
	
	# ! add linear trust region
	if solOpt_tup.heu != :onlyFix addLinearTrust!(top_m,lim_dic) end

	produceMessage(report_m.options,report_m.report, 1," - Enforced linear trust region", testErr = false, printErr = false)

	# ! add quadratic trust region
	if solOpt_tup.heu != :noQtr
		qctVar_dic = getQtrVar(top_m,heuSca_obj) # get variables for quadratic trust region
		trustReg_obj, eleNum_int = quadTrust(qctVar_dic,solOpt_tup.quadPar)
		trustReg_obj.cns, trustReg_obj.coef = centerQuadTrust(trustReg_obj.var,top_m,trustReg_obj.rad);
		trustReg_obj.objVal = Inf
		produceMessage(report_m.options,report_m.report, 1," - Initialized quadratic trust region with $eleNum_int variables", testErr = false, printErr = false)
	end
end

#endregion

#region # * run benders iteration

# initialize loop variables
itrReport_df = DataFrame(i = Int[], low = Float64[], best = Float64[], gap = Float64[], solCur = Float64[], time = Float64[])
capaReport_df = DataFrame(Ts_expSup = Int[], Ts_disSup= Int[], R_exp= Int[], Te= Int[], id = Int[], scr = Int[], i = Int[], variable = String[], value = Float64[], dual = Float64[]) 

gap_fl = 1.0
i = 1
cutData_dic = Dict{Tuple{Int64,Int64},bendersData}()
currentBest_fl = Inf

while true

	global i = i
	global allLimit_df = allLimit_df

	produceMessage(report_m.options,report_m.report, 1," - Started iteration $i", testErr = false, printErr = false)

	#region # * solve top level problem 

	startTop = now()
	capaData_obj, expTrust_dic, objTopTrust_fl, lowLimTrust_fl = @suppress runTopLevel(top_m,cutData_dic,i)
	timeTop = now() - startTop

	#endregion
	
	#region # * solve of sublevel problems	

	startSub = now()
	for x in collect(sub_tup)
		dual_etr = @suppress runSubLevel(sub_dic[x],copy(capaData_obj))
		cutData_dic[x] = dual_etr
	end
	timeSub = now() - startSub

	#endregion

	#region # * compute bounds and adjust quadratic trust region

	if solOpt_tup.heu != :noQtr && solOpt_tup.heu != :none 
		# run top-problem without trust region to obtain lower limits
		objTop_fl, lowLim_fl = runTopWithoutQuadTrust(top_m,trustReg_obj)
		# adjust trust region
		objSub_fl = sum(map(x -> x.objVal, values(cutData_dic))) # summed objective of sub-problems # ! hier warten auf subprobleme
		# write current best solution
		global currentBest_fl = min(objTopTrust_fl + objSub_fl,trustReg_obj.objVal)

		#region # * track binding cuts and limits

		# add information on binding cuts
		top_m.parts.obj.cns[:bendersCuts][!,:actItr] .= map(x -> dual(x.cns) != 0.0 ? vcat(x.actItr,[i]) : x.actItr, eachrow(top_m.parts.obj.cns[:bendersCuts]))
		# write info on cuts to csv add info on biggest number of iteration the cuts was inactive before it was used again
		writeCut_df = copy(select(top_m.parts.obj.cns[:bendersCuts],Not([:cns])))
		writeCut_df[!,:maxGap] = map(x -> size(x,1) < 2 ? 0 : maximum(x[2:end] .- x[1:end-1]), writeCut_df[!,:actItr])
		writeCut_df[!,:firstBind] = map(x -> isempty(x.actItr) ? 0 : x.actItr[1] - x.i, eachrow(writeCut_df))
		CSV.write(modOpt_tup.resultDir * "/cutTracking_$(replace(top_m.options.objName,"topModel" => "")).csv",  writeCut_df)

		# track binding limits
		for sys in (:tech,:exc)
			part_dic = getfield(top_m.parts,sys)
			for sSym in keys(part_dic)
				for limCns in filter(x -> any(occursin.(["BendersUp","BendersLow"],string(x))), keys(part_dic[sSym].cns))
					# detect binding constraints
					lim_df = copy(select(part_dic[sSym].cns[limCns],Not([:fac,:cns])))
					lim_df[!,:limCns] .= occursin("BendersUp",string(limCns)) ? :Low : :Up
					lim_df[!,:act] = map(x -> dual(x) != 0.0, part_dic[sSym].cns[limCns][!,:cns])
					# merge info into dataframe for all limits
					joinLim_df = innerjoin(lim_df,allLimit_df,on = intCol(lim_df,[:limCns,:dir]))
					joinLim_df[!,:actItr] = map(x -> x.act ? vcat(x.actItr,[i]) : x.actItr,eachrow(joinLim_df))
					joinLim_df[!,:actBestItr] = map(x -> x.act && (objTopTrust_fl + objSub_fl == currentBest_fl) ? vcat(x.actBestItr,[i]) : x.actBestItr,eachrow(joinLim_df))
					global allLimit_df = vcat(antijoin(allLimit_df, select(joinLim_df,Not([:act])), on = intCol(joinLim_df,[:limCns,:dir])),select(joinLim_df,Not([:act])))
				end
			end
		end
		CSV.write(modOpt_tup.resultDir * "/limitTracking_$(replace(top_m.options.objName,"topModel" => "")).csv",  allLimit_df)
		#endregion
	else
		lowLim_fl = lowLimTrust_fl # without quad trust region, lower limit corresponds result of standard top problem
		objSub_fl = sum(map(x -> x.objVal, values(cutData_dic))) # summed objective of sub-problems # ! hier warten auf subprobleme
		global currentBest_fl = (objSub_fl + objTopTrust_fl) < currentBest_fl ? (objSub_fl + objTopTrust_fl) : currentBest_fl
	end

	#endregion

	#region # * reporting on results and convergence check
	
	global gap_fl = 1 - lowLim_fl/currentBest_fl
	produceMessage(report_m.options,report_m.report, 1," - Lower: $(round(lowLim_fl, sigdigits = 8)), Upper: $(round(currentBest_fl, sigdigits = 8)), gap: $(round(gap_fl, sigdigits = 4))", testErr = false, printErr = false)
	produceMessage(report_m.options,report_m.report, 1," - Time for top: $(Dates.toms(timeTop) / Dates.toms(Second(1))) Time for sub: $(Dates.toms(timeSub) / Dates.toms(Second(1)))", testErr = false, printErr = false)
	
	# write to reporting files
	push!(itrReport_df, (i = i, low = lowLim_fl, best = currentBest_fl, gap = gap_fl, solCur = objTopTrust_fl + objSub_fl, time = Dates.value(floor(now() - report_m.options.startTime,Dates.Second(1)))/60))
	CSV.write(modOpt_tup.resultDir * "/iterationBenders$(replace(top_m.options.objName,"topModel" => "")).csv",  itrReport_df)

	if (1- lowLim_fl/currentBest_fl) < solOpt_tup.gap
		produceMessage(report_m.options,report_m.report, 1," - Finished iteration!", testErr = false, printErr = false)
		break
	elseif solOpt_tup.heu != :noQtr && solOpt_tup.heu != :none # adjust trust region in case algorithm has not converged yet
		global trustReg_obj = adjustQuadTrust(top_m,expTrust_dic,trustReg_obj,objSub_fl,objTopTrust_fl,lowLim_fl,lowLimTrust_fl,report_m)
	end

	global i = i +1

	#endregion
	
end

#endregion

#region # * write final results and clean up

# run top problem with optimal values fixed
top_m = computeFeas(top_m,trustReg_obj.var)
foreach(x -> reportResults(x,top_m), [:summary,:cost])
	
# obtain capacities
capaData_obj = bendersData()
capaData_obj.capa = writeResult(top_m,[:capa],true)

# run sub problems with optimal values fixed
for x in collect(sub_tup)
	runSubLevel(sub_dic[x],copy(capaData_obj),true)
end

rm(temp_dir; force = true, recursive = true) # remove temporal files again

#endregion