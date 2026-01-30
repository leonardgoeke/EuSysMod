using Gurobi, AnyMOD, CSV, YAML, SlurmClusterManager
include("functions.jl")

dir_str = ""

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 2 # or 16
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

lowLimStab = string(par_df[id_int,:lowLimStab]) |> (x -> x == "Inf" ? - Inf : parse(Float64,x))
weigthStab = string(par_df[id_int,:weigthStab]) 
decomp = par_df[id_int,:decomp]
check_boo = par_df[id_int,:check] == "TRUE"

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
cutMgm_tup = (meth = :slack, opt = (cnt = 10000, thres = 0.5), freq = 1, report = false)

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

# determine presolve option
pre_int = -1

# solver options for sub and top problem
subOpt_tup = (rng = [1e-2, 1e-8], int = :none, crs = false, meth = :barrier, timeLim = 30.0, dbInf = true, threads = t_int, check = check_boo)
topOpt_tup = (numFoc = [0,2,3], dnsThrs = dnsThrs, crs = false, stabTol = (interStab_sym, tolStab_arr), stabTolQ = (interStabQ_sym, tolStabQ_arr), stabTolFeas = (interStabFeas_sym, tolStabFeas_arr), noStabTol =  (interNoStab_sym, tolNoStab_arr), presolve = pre_int, stabMeth = 2, noStabMeth = 2, threads = t_int, check = check_boo)

# optimimality gap, cut management, valid inequalities, reporting frequency, time limit, distributed computing, optimizer
algSetup_obj = algSetup(0.001, cutMgm_tup, (bal = false, st = true), 2, 16000.0, wrkCnt != 1, Gurobi.Optimizer, rngVio_ntup, subOpt_tup, topOpt_tup)
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
elseif weigthStab == "lowStLvl"
	w_tup = (capa = 1e0, capaStSize = 1e0, stLvl = 1e-2, lim = 1e0)
elseif weigthStab == "withStLvl"
	w_tup = (capa = 1e0, capaStSize = 1e0, stLvl = 1e0, lim = 1e0)
end

# method, threshold serious step, initialization, minimum value, solve frequency without stabilization, weights in stabilization (in additon to scaling of base problem)
stabSetup_obj = stabSetup(meth_tup, 0.0, :reduced, lowLimStab, (upper = 13, inter = :log, sub = 10.0), repVio = true, weight = w_tup)

# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = foresight, decompLvl = (foresight != 0 || decomp == "year" ? 0 : 3), supTsLvl = 2, repTsLvl = 4, shortExp = 5, infeasTop = false) 

# ! input folders
inDir_arr = [dir_str * "basis", dir_str * "spatialScope/" * spaSco, scrDir_str, dir_str * "timeSeries/setup/" * time * "h_" * (decomp == "year" ? "month" : decomp)]
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/data/" * case * "_" * time * "h/" * x[1] * "/" * x[2]), scrQrt_arr)

heuDir_arr = [dir_str * "basis", dir_str * "spatialScope/" * spaSco, scrDir_str, dir_str * "timeSeries/setup/672h_" * (decomp == "year" ? "month" : decomp)]
foreach(x -> push!(heuDir_arr, dir_str * "timeSeries/data/" * case * "_" * "672h/"  * x[1] * "/" * x[2]), scrQrt_arr)

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
	addprocs(SlurmManager(; launch_timeout = 300), nodes=1, ntasks=1, ntasks_per_node=1, cpus_per_task=t_int, mem_per_cp = isinteger(ram) ? (string(ram) * "G") : (string(ram*1024) * "M"), time=6000) # add all available nodes
	rmprocs(wrkCnt + 2) # remove one node again for main process
	@everywhere begin
		using Gurobi, AnyMOD
		runSubDist(w_int::Int64, resData_obj::resData, rngVio_fl::Float64, sol_sym::Symbol, timeLim_fl::Float64, optTol_fl::Float64=1e-8, crsOver_boo::Bool=false, check_boo::Bool=false, resultOpt_tup::NamedTuple=NamedTuple()) = Distributed.@spawnat w_int runSub(resData_obj, rngVio_fl, sol_sym, timeLim_fl, optTol_fl, crsOver_boo, check_boo, resultOpt_tup)
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

produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
writeBendersResults!(benders_obj, runSubDist, getSubStringDist)

#endregion
