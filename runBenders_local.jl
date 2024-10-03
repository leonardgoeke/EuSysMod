using Gurobi, AnyMOD, CSV, YAML, SlurmClusterManager

dir_str = "C:/Git/EuSysMod/"

par_df = CSV.read(dir_str * "settings_benders.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
    t_int = parse(Int,ARGS[2]) # number of threads
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope
scenario = string(par_df[id_int,:scenario]) # scenario case
solve = par_df[id_int,:solve]

# extract benders settings

wrkCnt = par_df[id_int,:workerCnt]
cutDel = par_df[id_int,:cutDel]
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]

name_str = time * "_" * spaSco * "_" * scenario * "_" * string(trust) * "trust_" * string(cutDel) * "cutDel_" * string(dnsThrs) * "dnsThrs_" * solve

# create scenario and quarter array
scrDir_str = dir_str * "scenarioSetup/" * scenario
scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(dir_str * "scenarioSetup/" * scenario * "/par_scrProb.csv", DataFrame))))

#region # * options for algorithm

# ! options for general algorithm

rngVio_ntup = (stab = 1e2, cut = 1e4, fix = 1e4)
rngTar_tup = (mat = (1e-2,1e5), rhs = (1e-2,1e2))

# target gap, inaccurate cuts options, number of iteration after unused cut is deleted, valid inequalities, number of iterations report is written, time-limit for algorithm, distributed computing?, number of threads, optimizer
if solve == "crsAllNoLim"
	algSetup_obj = algSetup(0.005, cutDel, (bal = false, st = true), 2, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = true, meth = :barrier, timeLim = 0.0, dbInf = true), (numFoc = 3, dnsThrs = dnsThrs, crs = true))
elseif solve == "crsAll5Lim"
	algSetup_obj = algSetup(0.005, cutDel, (bal = false, st = true), 2, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = true, meth = :barrier, timeLim = 0.01, dbInf = true), (numFoc = 3, dnsThrs = dnsThrs, crs = true))
elseif solve == "crsTop5Lim"
	algSetup_obj = algSetup(0.005, cutDel, (bal = false, st = true), 2, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = false, meth = :barrier, timeLim = 5.0, dbInf = true), (numFoc = 3, dnsThrs = dnsThrs, crs = true))
end

res_ntup = (general = (:summary, :exchange, :cost), carrierTs = (:electricity, :h2), storage = (write = true, agg = true), duals = (:enBal, :excRestr, :stBal))

# ! options for stabilization

# write tuple for stabilization
stabMap_dic = YAML.load_file(dir_str * "stabMap.yaml")
if trust in keys(stabMap_dic)
	meth_tup = tuple(map(x -> Symbol(x[1]) => (; (Symbol(k) => v for (k, v) in x[2])...), collect(stabMap_dic[trust]))...)
else
	meth_tup = tuple()
end

iniStab_ntup = (setup = :reduced, det = true) # options to initialize stabilization, :none for first input will skip stabilization, other values control input folders, second input determines, if heuristic model is solved stochastically or not

stabSetup_obj = stabSetup(meth_tup, 0.0, iniStab_ntup)


# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = 3, supTsLvl = 2, repTsLvl = 3, shortExp = 5) 

# ! input folders
inDir_arr = [dir_str * "_basis", dir_str * "spatialScope/" * spaSco, dir_str * "heatSector/fixed_country", dir_str * "resolution/default_country", scrDir_str, dir_str * "timeSeries/country_" * time * "/general"]
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/general_" * x), ("ini1","ini2","ini3","ini4"))
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "/" * x[1] * "/" * x[2]), scrQrt_arr)

inputFolder_ntup = (in = inDir_arr, heu = inDir_arr, results = dir_str * "results")

# ! scaling settings
scale_dic = Dict{Symbol,NamedTuple}()

scale_dic[:rng] = rngTar_tup
scale_dic[:facHeu] = (capa = 1e2, capaStSize = 1e2, insCapa = 1e1, dispConv = 1e1, dispSt = 1e2, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)
scale_dic[:facTop] = (capa = 1e2, capaStSize = 1e3, insCapa = 1e2, dispConv = 1e1, dispSt = 1e2, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
scale_dic[:facSub] = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e2, dispSt = 1e3, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)

#endregion

#region # * prepare iteration


# initialize distributed computing
if algSetup_obj.dist
	addprocs(SlurmManager(; launch_timeout = 300), exeflags="--heap-size-hint=60G", nodes=1, ntasks=1, ntasks_per_node=1, cpus_per_task=8, mem_per_cpu="8G", time=4380) # add all available nodes
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
benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, res_ntup, nearOptSetup_obj);

#endregion

#region # * iteration algorithm
while true

	produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Started iteration $(benders_obj.itr.cnt.i)", testErr = false, printErr = false)

	#region # * solve top-problem and (start) sub-problems
	str_time = now()
	resData_obj, stabVar_obj = runTop(benders_obj);   
	elpTop_time = now() - str_time

	# start solving sub-problems
	cutData_dic = Dict{Tuple{Int64,Int64},resData}()
	timeSub_dic = Dict{Tuple{Int64,Int64},Millisecond}()
	lss_dic = Dict{Tuple{Int64,Int64},Float64}()
	numFoc_dic = Dict{Tuple{Int64,Int64},Int64}()

	acc_fl = getConvTol(benders_obj.itr.gap, benders_obj.algOpt.gap, benders_obj.algOpt.sub)

	if benders_obj.algOpt.dist futData_dic = Dict{Tuple{Int64,Int64},Future}() end
	for (id,s) in enumerate(sort(collect(keys(benders_obj.sub))))
		if benders_obj.algOpt.dist # distributed case
			futData_dic[s] = runSubDist(id + 1, copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, acc_fl, benders_obj.algOpt.sub.crs)
		else # non-distributed case @suppress 
			cutData_dic[s], timeSub_dic[s], lss_dic[s], numFoc_dic[s] =runSub(benders_obj.sub[s], copy(resData_obj), benders_obj.algOpt.rngVio.fix, benders_obj.algOpt.sub.meth, acc_fl, benders_obj.algOpt.sub.crs)
		end
	end

	# top-problem without stabilization
	if !isnothing(benders_obj.stab) runTopWithoutStab!(benders_obj, stabVar_obj) end

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
	updateIteration!(benders_obj, cutData_dic, resData_obj, stabVar_obj)
	# report on iteration
	reportBenders!(benders_obj, resData_obj, elpTop_time, timeSub_dic, lss_dic, numFoc_dic)

	# check convergence and finish
	rtn_boo = checkConvergence(benders_obj, lss_dic)
	
	#endregion
	benders_obj.itr.cnt.i = benders_obj.itr.cnt.i + 1
	if rtn_boo break end
	
end
#region # * write results

produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
writeBendersResults!(benders_obj, runSubDist, res_ntup)

#endregion