using Gurobi, AnyMOD, CSV, YAML
include("functions.jl")

dir_str = "C:/Git/climate2energy/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 45 # or 16
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

lowLimStab = string(par_df[id_int,:lowLimStab]) |> (x -> x == "Inf" ? Inf : parse(Float64,x))
weigthStab = string(par_df[id_int,:weigthStab]) 
viStorage = par_df[id_int,:viStorage] == "TRUE"
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
if cutDel in ("10cnt_1thres", "50cnt_05thres", "noCutDel")
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
subOpt_tup = (rng = [1e-2, 1e-8], int = :none, crs = true, meth = :barrier, timeLim = 30.0, dbInf = true, threads = t_int, check = false)
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

# weight of variables in stabilization
if weigthStab == "noStLvl"
	w_tup = (capa = 1e0, capaStSize = 1e0, stLvl = 0.0, lim = 1e0)
elseif weigthStab == "withStLvl"
	w_tup = (capa = 1e0, capaStSize = 1e0, stLvl = 1e0, lim = 1e0)
end

# method, threshold serious step, initialization, minimum value, solve frequency without stabilization, weights in stabilization (in additon to scaling of base problem)
stabSetup_obj = stabSetup(meth_tup, 0.0, :reduced, - lowLimStab, (upper = 13, inter = :log, sub = 10.0), repVio = true, weight = w_tup)

# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = foresight, supTsLvl = 2, repTsLvl = 4, shortExp = 5, infeasTop = infeasTop != "none") 

# ! input folders
inDir_arr = [dir_str * "basis", dir_str * "spatialScope/" * spaSco,  dir_str * "infeasTop/" * infeasTop, scrDir_str, dir_str * "timeSeries/" * case * "_" * time * "h/general"]
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

# create benders object
benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, res_ntup);

#endregion

#region # * iteration algorithm

allRes_df = runIteration!(benders_obj, runSubDist)

#endregion

#region # * write results

#produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
#writeBendersResults!(benders_obj, runSubDist, getSubStringDist)

#endregion

import AnyMOD.interItrPar, AnyMOD.trackCuts!, AnyMOD.removeStab!

allRes_df = DataFrame(i = Int[], Ts_expSup = Int[], Ts_disSup = Int[], Ts_dis = Int[], R_dis = Int[], R_exp = Int[], R_from = Int[], R_to = Int[], C = Int[], Te = Int[], Exc = Int[], M = Int[], scr = Int[], id = Int[], sub = Tuple[], variable = Symbol[], value = Float64[])


while true

	produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Started iteration $(benders_obj.itr.cnt.i)", testErr = false, printErr = false)

	#region # * solve top-problem and (start) sub-problems
	str_time = now()
	resData_obj, stLvl_dic = runTop(benders_obj);
	trackCuts!(benders_obj)
	elpTop_time = now() - str_time

	# start solving sub-problems
	cutData_dic = Dict{Tuple{Int64,Int64},resData}()
	timeSub_dic = Dict{Tuple{Int64,Int64},Millisecond}()
	lss_dic = Dict{Tuple{Int64,Int64},Float64}()
	numFoc_dic = Dict{Tuple{Int64,Int64},Int64}()

	acc_fl = interItrPar(benders_obj.itr.gap, benders_obj.algOpt.gap, benders_obj.algOpt.sub.rng, benders_obj.algOpt.sub.int)

	if benders_obj.algOpt.dist futData_dic = Dict{Tuple{Int64,Int64},Future}() end
	for (id,s) in enumerate(sort(collect(keys(benders_obj.sub))))
		println(s)
		if benders_obj.algOpt.dist # distributed case
			futData_dic[s] = runSubDist(id + 1, copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, benders_obj.algOpt.sub.timeLim, acc_fl, benders_obj.algOpt.sub.crs, benders_obj.algOpt.sub.check)
		else # non-distributed case
			cutData_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] = runSubMW(benders_obj.sub[s], benders_obj, copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, benders_obj.algOpt.sub.timeLim, acc_fl, benders_obj.algOpt.sub.crs, benders_obj.algOpt.sub.check)
		end
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
	srsStep_boo = updateIteration!(benders_obj, cutData_dic, resData_obj, curRes_dic, stLvl_dic)
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

# TODOerror on capaStOut, problem with infeas


# ! test runSubMW

s = (2,1)
sub_m = benders_obj.sub[s]
rngVio_fl = benders_obj.algOpt.rngVio.fix
sol_sym = benders_obj.algOpt.sub.meth 
timeLim_fl = benders_obj.algOpt.sub.timeLim
optTol_fl = acc_fl
crsOver_boo = benders_obj.algOpt.sub.crs
check_boo = benders_obj.algOpt.sub.check
resultOpt = NamedTuple()


	str_time = now()

	#region # * fix complicating variables

	# fixing capacity
	for sys in (:tech, :exc)
		part_dic = getfield(sub_m.parts, sys)
		for sSym in keys(resData_obj.capa[sys])
			for capaSym in sort(filter(x -> occursin("capa", lowercase(string(x))), collect(keys(resData_obj.capa[sys][sSym]))), rev = true)
				# filter capacity data for respective year
				filter!(x -> x.Ts_disSup == sub_m.supTs.step[1], resData_obj.capa[sys][sSym][capaSym])
				# removes entry from capacity data, if capacity does not exist in respective year, otherwise fix to value
				if !(sSym in keys(part_dic)) || !(capaSym in keys(part_dic[sSym].var)) || isempty(resData_obj.capa[sys][sSym][capaSym])
					delete!(resData_obj.capa[sys][sSym], capaSym)
				else
					cnsName_str = string(sys, "_", sSym, "_", capaSym)
					resData_obj.capa[sys][sSym][capaSym] = limitVar!(resData_obj.capa[sys][sSym][capaSym], part_dic[sSym].var[capaSym], capaSym, part_dic[sSym], rngVio_fl, sub_m, :Fix, cnsName_str)
				end
			end
			# remove system if no capacities exist
			removeEmptyDic!(resData_obj.capa[sys], sSym)
		end
	end

	# fixing storage levels
	if !isempty(resData_obj.stLvl)
		for sSym in keys(resData_obj.stLvl)
			if sSym in keys(sub_m.parts.tech)
				part_obj = sub_m.parts.tech[sSym]
				for stType in keys(resData_obj.stLvl[sSym])
					cnsName_str = string(sSym, "_", stType)
					fix_df = select(filter(x -> stType == :stLvl ? true : x.scr == sub_m.subPro[2], resData_obj.stLvl[sSym][stType]), Not([:scr]))
					resData_obj.stLvl[sSym][stType] = limitVar!(fix_df, select(part_obj.var[stType], Not([:scr])), stType, part_obj, rngVio_fl, sub_m, :Fix, cnsName_str)
					removeEmptyDic!(resData_obj.stLvl[sSym], stType)
				end
				# remove system if no storage level exists
				removeEmptyDic!(resData_obj.stLvl, sSym)
			end
		end
	end

	# fixing limiting variables
	if !isempty(resData_obj.lim)
		for limSym in keys(resData_obj.lim)
			lim_df = select(filter(x -> x.sub == sub_m.subPro, resData_obj.lim[limSym]), Not([:sub]))
			if !isempty(lim_df)
				cnsName_str = string(limSym)
				resData_obj.lim[limSym] = limitVar!(lim_df, sub_m.parts.lim.var[limSym], limSym, sub_m.parts.lim, rngVio_fl, sub_m, :Fix, cnsName_str)
				# remove system if no storage level exists
				removeEmptyDic!(resData_obj.lim, limSym)
			end
		end
	end
	
	#endregion

	#region # * solve problem

	# set optimizer attributes and solves
	@suppress begin
		if sol_sym == :barrier
			set_optimizer_attribute(sub_m.optModel, "Method", 2)
			set_optimizer_attribute(sub_m.optModel, "Crossover", crsOver_boo ? 1 : 0)
			set_optimizer_attribute(sub_m.optModel, "BarOrder", 1)
			set_optimizer_attribute(sub_m.optModel, "BarConvTol", optTol_fl)
		elseif sol_sym == :simplex
			set_optimizer_attribute(sub_m.optModel, "Method", 1)
			set_optimizer_attribute(sub_m.optModel, "OptimalityTol", optTol_fl)
			set_optimizer_attribute(sub_m.optModel, "Presolve", 2)
		end
        if timeLim_fl != 0.0 set_optimizer_attribute(sub_m.optModel, "TimeLimit", timeLim_fl * 60) end # in seconds
	end

	# increase numeric focus if model did not solve
	set_optimizer_attribute(sub_m.optModel, "Crossover", 1) # TODO have have to be remove later?
	numFoc_int = solveModel!(sub_m, sub_m.optModel, [0,3], check_boo, check_boo)

	# write results into files (only used once optimum is obtained)
	writeAllResults!(sub_m, resultOpt, false)

	#endregion

    # get dual problem
    dual_optM = dualize(sub_m.optModel; dual_names = DualNames("dual_", ""))
    
    # set objective value as constraint to ensure optimum
    oldObj_expr = objective_function(dual_optM) 
    @constraint(dual_optM, objective_function(dual_optM) == objective_value(sub_m.optModel)*0.999)

    # create expression of dual variables
    coreVar_expr = createDualCoreExp(sub_m, dual_optM, benders_obj.itr.best.var, 0.01)

    scaObj_fl = sub_m.options.scaFac.obj
    
    # enforce new objective
    noDual_arr = filter(x -> !occursin("dual", string(x[1])), collect(oldObj_expr.terms))
    set_objective_function(dual_optM, coreVar_expr / scaObj_fl + sum(map(x -> x[1] * x[2], noDual_arr)))

    set_optimizer(dual_optM, Gurobi.Optimizer)
    set_optimizer_attribute(dual_optM, "Method", 2)
    set_optimizer_attribute(dual_optM, "Crossover", 1)
    set_optimizer_attribute(dual_optM, "NumericFocus", 2)
    
    # solve dual model
    set_optimizer(dual_optM, Gurobi.Optimizer)
    optimize!(dual_optM)
    compute_conflict!(dual_optM)
    
    #region # * extract results
    
    if termination_status(sub_m.optModel) in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)
        
        # get objective value
        resData_obj.objVal = value(sum(sub_m.parts.obj.var[:objVar][!,:var]))
    
        # get duals on capacity
        for sys in (:tech, :exc)
            part_dic = getfield(sub_m.parts, sys)
            for sSym in keys(resData_obj.capa[sys])
                for capaSym in filter(x -> occursin("capa", lowercase(string(x))), collect(keys(resData_obj.capa[sys][sSym])))			
                    # get and join corresponding capacity constraint
                    cns_df = part_dic[sSym].cns[Symbol(capaSym,:BendersFix)]
                    res_df = innerjoin(resData_obj.capa[sys][sSym][capaSym], cns_df, on = intCol(cns_df,:dir))
                    # get scaling factor  
                    scaCapa_fl = getfield(sub_m.options.scaFac, occursin("StSize", string(capaSym)) ? :capaStSize : :capa)
                    # extract value of dual variable
                    res_df[!,:dualVar] = map(x -> dual_optM.obj_dict[Symbol(:dual_,name(x),"_1")], res_df[!,:cns])
                    res_df[!,:dual] = value.(res_df[!,:dualVar]) .* res_df[!,:fac] .* scaObj_fl ./ scaCapa_fl
                    resData_obj.capa[sys][sSym][capaSym] = select(res_df,Not([:fac,:cns,:dualVar]))
                    removeEmptyDic!(resData_obj.capa[sys][sSym], capaSym)
                end
                # remove system if no capacities exist (again necessary because dual can be zero)
                removeEmptyDic!(resData_obj.capa[sys], sSym)
            end
        end
    
        # get duals on storage levels
        if !isempty(resData_obj.stLvl)
            for sSym in keys(resData_obj.stLvl)
                if sSym in keys(sub_m.parts.tech)
                    part_obj = sub_m.parts.tech[sSym]
                    for stType in keys(resData_obj.stLvl[sSym])
                        # get and join corresponding storage level
                        cns_df = part_obj.cns[Symbol(stType,:BendersFix)]
                        res_df = innerjoin(resData_obj.stLvl[sSym][stType], cns_df, on = intCol(cns_df,:dir))
                        # extract value of dual variable
                        res_df[!,:dualVar] = map(x -> dual_optM.obj_dict[Symbol(:dual_,name(x),"_1")], res_df[!,:cns])
                        res_df[!,:dual] = value.(res_df[!,:dualVar]) .* res_df[!,:fac] .* scaObj_fl ./ sub_m.options.scaFac.dispSt
                        resData_obj.stLvl[sSym][stType] = select(res_df, Not([:fac,:cns,:dualVar]))
                        removeEmptyDic!(resData_obj.stLvl[sSym], stType)
                    end
                    removeEmptyDic!(resData_obj.stLvl, sSym)
                end
            end
        end
    
        # get duals on limits
        if !isempty(resData_obj.lim)
            for limSym in keys(resData_obj.lim)
                # get and join corresponding limit
                cns_df = sub_m.parts.lim.cns[Symbol(limSym,:BendersFix)]
                res_df = innerjoin(resData_obj.lim[limSym], cns_df, on = intCol(cns_df,[:Up,:Low,:Fix]))
                # extract value of dual variable
                res_df[!,:dualVar] = map(x -> dual_optM.obj_dict[Symbol(:dual_,name(x),"_1")], res_df[!,:cns])
                res_df[!,:dual] = value.(res_df[!,:dualVar])  .* res_df[!,:fac] .* scaObj_fl ./ sub_m.options.scaFac.dispConv
                resData_obj.lim[limSym] = select(res_df, Not([:fac,:cns,:dualVar]))
                removeEmptyDic!(resData_obj.lim, limSym)
            end
        end
    
        # probability weighted loss-of-load
        lssProb_df = matchSetParameter(sub_m.parts.bal.var[:lss], sub_m.parts.obj.par[:scrProb], sub_m.sets)
        lss_fl = sum(lssProb_df[!,:val] .* value.(lssProb_df[!,:var]))
    
    else
        lss_fl = 0.0
    end
    


# ! createDualCoreExp(sub_m::anyModel, dual_optM::Model, best_obj::resData, minVal_fl::Float64)
resData_obj 
best_obj = benders_obj.itr.best.var
minVal_fl = 0.01
	
expExpr_arr = AffExpr[]

# match capacity and storage levels
for sys in (:tech, :exc)
	println(sys)
	part_dic = getfield(sub_m.parts, sys)
	for sSym in keys(part_dic)
		println(sSym)
		for cnsSym in filter(x -> occursin("BendersFix",string(x)), keys(part_dic[sSym].cns))
			println(cnsSym)
			primalCns_df = part_dic[sSym].cns[cnsSym]
			var_sym = Symbol(replace(string(cnsSym),"BendersFix" => ""))
			if var_sym in (:stLvl, :stLvlInter)
				primalCns_df = innerjoin(primalCns_df, best_obj.stLvl[sSym][var_sym], on = intCol(primalCns_df))
			else
				primalCns_df = innerjoin(primalCns_df, best_obj.capa[sys][sSym][var_sym], on = intCol(primalCns_df,:dir))   
			end  
			# correct values with scaling factor # TODO (wrap?)
			mapScaFac_arr = ["stlvl" => :dispSt, "exp" => :insCapa, "stsize" => :capaStSize, "benderscom" => :dispConv]
			scaFac_sym = occursin.(getindex.(mapScaFac_arr,1), lowercase(string(var_sym)))|> (z -> any(z) ? getindex.(mapScaFac_arr,2)[findall(z)[1]] : :capa)
			primalCns_df[!,:value]  = round.(primalCns_df[!,:value] ./ getfield(sub_m.options.scaFac, scaFac_sym), sigdigits = 10)
			# create dual expression
			primalCns_df[!,:dualVar] = map(x -> dual_optM.obj_dict[Symbol(:dual_,name(x),"_1")], primalCns_df[!,:cns])
			push!(expExpr_arr, sum(primalCns_df[!,:dualVar] .* max.(minVal_fl, primalCns_df[!,:value])))
		end
	end
end

# match limits
for limSym in filter(x -> occursin("BendersFix",string(x)), keys(sub_m.parts.lim.cns))
	primalCns_df = sub_m.parts.lim.cns[limSym]
	# match constraint with core point
	var_sym = Symbol(replace(string(limSym),"BendersFix" => ""))
	primalCns_df = innerjoin(primalCns_df, filter(x -> x.sub == sub_m.subPro, best_obj.lim[var_sym]), on = intCol(primalCns_df))
	primalCns_df[!,:dualVar] = map(x -> dual_optM.obj_dict[Symbol(:dual_,name(x),"_1")], primalCns_df[!,:cns])
	# correct values with scaling factor # TODO (wrap?)
	mapScaFac_arr = ["stlvl" => :dispSt, "exp" => :insCapa, "stsize" => :capaStSize, "benderscom" => :dispConv]
	scaFac_sym = occursin.(getindex.(mapScaFac_arr,1), lowercase(string(var_sym)))|> (z -> any(z) ? getindex.(mapScaFac_arr,2)[findall(z)[1]] : :capa)
	primalCns_df[!,:value]  = round.(primalCns_df[!,:value] ./ getfield(sub_m.options.scaFac, scaFac_sym), sigdigits = 10)
		# create dual expression
	push!(expExpr_arr, sum(primalCns_df[!,:dualVar] .* max.(minVal_fl, primalCns_df[!,:value])))
end

# ! limitVar

