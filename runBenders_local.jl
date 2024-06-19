using Gurobi, AnyMOD, CSV, YAML

dir_str = "" 

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 1 # currently 1 for future and 2 for historic
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
    t_int = parse(Int,ARGS[2]) # number of threads
end

h = string(par_df[id_int,:h])
spa = string(par_df[id_int,:spatialScope])
scr = string(par_df[id_int,:scr])
frsLvl = par_df[id_int,:foresight]

wrkCnt = par_df[id_int,:workerCnt]
rngVio = par_df[id_int,:rngVio]
trust = par_df[id_int,:trust]
accuracy = par_df[id_int,:accuracy]

#region # * options for algorithm

# ! options for general algorithm

if rngVio == 0
	rngVio_ntup = (stab = 1e4, cut = 1e1, fix = 1e2)
elseif rngVio == 1
	rngVio_ntup = (stab = 1e2, cut = 1e1, fix = 1e2)
elseif rngVio == 2
	rngVio_ntup = (stab = 1e4, cut = 1e1, fix = 1e3)
elseif rngVio == 3
	rngVio_ntup = (stab = 1e4, cut = 1e1, fix = 1e4)
elseif rngVio == 4
	rngVio_ntup = (stab = 1e4, cut = 1e2, fix = 1e2)
elseif rngVio == 5
	rngVio_ntup = (stab = 1e4, cut = 1e3, fix = 1e2)
end

if accuracy == 0
	inAcc_sym = :none
elseif accuracy == 1
	inAcc_sym = :lin
elseif accuracy == 2
	inAcc_sym = :exp
elseif accuracy == 3
	inAcc_sym = :log
end

# target gap, inaccurate cuts options, number of iteration after unused cut is deleted, valid inequalities, number of iterations report is written, time-limit for algorithm, distributed computing?, number of threads, optimizer
algSetup_obj = algSetup(0.005, 20, (bal = false, st = false), 10, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = inAcc_sym, crs = false))

res_ntup = (general = (:summary, :exchange, :cost), carrierTs = (:electricity, :h2), storage = (write = true, agg = true), duals = (:enBal, :excRestr, :stBal))

# ! options for stabilization

if trust == 0
	methKey_str = "qtr_4"
elseif trust == 1
	methKey_str = "qtr_5"
elseif trust == 2
	methKey_str = "qtr_8"
elseif trust == 3
	methKey_str = "box_3"
end

# write tuple for stabilization
stabMap_dic = YAML.load_file(dir_str * "stabMap.yaml")
if methKey_str in keys(stabMap_dic)
	meth_tup = tuple(map(x -> Symbol(x[1]) => (; (Symbol(k) => v for (k, v) in x[2])...), collect(stabMap_dic[methKey_str]))...)
else
	meth_tup = tuple()
end

iniStab_ntup = (setup = :reduced, det = false) # options to initialize stabilization, :none for first input will skip stabilization, other values control input folders, second input determines, if heuristic model is solved stochastically or not

stabSetup_obj = stabSetup(meth_tup, 0.0, iniStab_ntup)


# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings
name_str = "c2e_" * h * "_" * spa * "_" * scr * "_1_" * string(rngVio) * "_" * string(frsLvl) * "frs" * "_" * string(trust) * "trust" * "_" * string(accuracy) * "acc"
# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = frsLvl, supTsLvl = 2, repTsLvl = 4, shortExp = 10) 

# ! input folders
inDir_arr = [dir_str * "basis", dir_str * "spatialScope/" * spa, dir_str * "timeSeries/" * h * "hours_" * spa * "_" * scr]

if stabSetup_obj.ini.setup in (:none,:full) 
	heuInDir_arr = inDir_arr
elseif stabSetup_obj.ini.setup == :reduced
	heuInDir_arr =  [dir_str * "basis", dir_str * "spatialScope/" * spa, dir_str * "timeSeries/96hours_" * spa * "_" * scr]
end 

inputFolder_ntup = (in = inDir_arr, heu = heuInDir_arr, results = dir_str * "results")

# ! scaling settings

scale_dic = Dict{Symbol,NamedTuple}()

scale_dic[:rng] = (mat = (1e-2,1e4), rhs = (1e-2,1e2))

scale_dic[:facHeu] = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
scale_dic[:facTop] = (capa = 1e2, capaStSize = 1e1, insCapa = 1e2, dispConv = 1e3, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
scale_dic[:facSub] = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e1, dispSt = 1e3, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)

#endregion

#region # * prepare iteration

# initialize distributed computing
if algSetup_obj.dist
	addprocs(SlurmManager(; launch_timeout = 300), exeflags="--heap-size-hint=30G", nodes=1, ntasks=1, ntasks_per_node=1, cpus_per_task=4, mem_per_cpu="8G", time=4380) # add all available nodes
	rmprocs(wrkCnt + 2) # remove one node again for main process
	@everywhere begin
		using Gurobi, AnyMOD
		runSubDist(w_int::Int64, resData_obj::resData, rngVio_fl::Float64, sol_sym::Symbol, optTol_fl::Float64=1e-8, crsOver_boo::Bool=false, resultOpt_tup::NamedTuple=NamedTuple()) = Distributed.@spawnat w_int runSub(resData_obj, rngVio_fl, sol_sym, optTol_fl, crsOver_boo, resultOpt_tup)
		getComVarDist(w_int::Int64) = Distributed.@spawnat w_int getComVar()
	end
	passobj(1, workers(), [:info_ntup, :inputFolder_ntup, :scale_dic, :algSetup_obj])
else
	runSubDist = x -> nothing
	getComVarDist = x -> nothing
end
# create benders object
benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, nearOptSetup_obj)

#endregion

#region # * iteration algorithm

while true

	produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Started iteration $(benders_obj.itr.cnt.i)", testErr = false, printErr = false)

	#region # * solve top-problem and (start) sub-problems

	str_time = now()
	resData_obj, stabVar_obj = @suppress runTop(benders_obj); 
	elpTop_time = now() - str_time

	# start solving sub-problems
	cutData_dic = Dict{Tuple{Int64,Int64},resData}()
	timeSub_dic = Dict{Tuple{Int64,Int64},Millisecond}()
	lss_dic = Dict{Tuple{Int64,Int64},Float64}()
	numFoc_dic = Dict{Tuple{Int64,Int64},Int64}()

	acc_fl = getConvTol(benders_obj.itr.gap, benders_obj.algOpt.gap, benders_obj.algOpt.conSub)

	if benders_obj.algOpt.dist futData_dic = Dict{Tuple{Int64,Int64},Future}() end
	for (id,s) in enumerate(collect(keys(benders_obj.sub)))
		if benders_obj.algOpt.dist # distributed case
			futData_dic[s] = runSubDist(id + 1, copy(resData_obj), benders_obj.algOpt.rngVio.fix, :barrier, acc_fl)
		else # non-distributed case
			cutData_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] = runSub(benders_obj.sub[s], copy(resData_obj), benders_obj.algOpt.rngVio.fix, :barrier, acc_fl)
		end
	end

	# top-problem without stabilization
	if !isnothing(benders_obj.stab) @suppress runTopWithoutStab!(benders_obj, stabVar_obj) end

	# get results of sub-problems
	if benders_obj.algOpt.dist
		wait.(collect(values(futData_dic)))
		for s in collect(keys(benders_obj.sub))
			cutData_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] = fetch(futData_dic[s])
		end
	end
	
	#endregion

	#region # * analyse results and update refinements

	# update results and stabilization
	updateIteration!(benders_obj, cutData_dic, resData_obj, stabVar_obj)

	# report on iteration
	reportBenders!(benders_obj, resData_obj, elpTop_time, timeSub_dic, lss_dic, numFoc_dic)

	# check convergence and finish
	rtn_boo = checkConvergence(benders_obj, lss_dic)
	
	#endregion

	if rtn_boo break end
	benders_obj.itr.cnt.i = benders_obj.itr.cnt.i + 1

end

#endregion

#region # * write results

produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
writeBendersResults!(benders_obj, runSubDist, res_ntup)

#endregion