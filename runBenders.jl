using Gurobi, AnyMOD, CSV, YAML, SlurmClusterManager
include("functions.jl")

dir_str = ""
modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"

par_df = CSV.read(dir_str * "settings.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = convert(String,par_df[id_int,:spatialScope]) # spatial scope
scenario = convert(String,par_df[id_int,:scenario]) # scenario case
techs = string(par_df[id_int,:techs]) # available technologies
security = string(par_df[id_int,:security]) # security settings
inOos = string(par_df[id_int,:inputOutOfSample]) # capacity folder for out-of-sample testing

# extract benders settings
solve = par_df[id_int,:solve]
wrkCnt = par_df[id_int,:workerCnt]
t_int = par_df[id_int,:threads]
ram = par_df[id_int,:ram]
cutDel = par_df[id_int,:cutDel]
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]

name_str = convert(String,par_df[id_int,:name])
checkDet_boo = scenario in "scr" .* string.(1982:2016)

# create files determining scenario setup
scrQrt_arr, scrDir_str = generateScrInfo(checkDet_boo, scenario, setupDir_str, spaSco)
scrQrtHeu_arr, scrDirHeu_str = generateScrInfo(false, "total12_ext0", setupDir_str, spaSco)

#region # * options for algorithm

# ! options for general algorithm
rngTar_tup = (mat = (1e-2, 1e5), rhs = (1e-2, 1e2))

# target gap, inaccurate cuts options, number of iteration after unused cut is deleted, valid inequalities, number of iterations report is written, time-limit for algorithm, distributed computing?, number of threads, optimizer, solver settings sub and top
rngVio_ntup = (stab = 2e1, cut = 1e2, fix = 1e2)

algSetup_obj = algSetup(0.01, cutDel, (bal = false, st = true), 2, 7200.0, true, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = false, meth = :barrier, timeLim = 20.0, dbInf = true, check = false), (numFoc = [0,2,3], dnsThrs = dnsThrs, crs = false, qtrTol = 1e-6, feasTol = 1e-6))
res_ntup = (general = (:summary, :exchange, :cost), carrierTs = (:electricity, :h2), storage = (write = true, agg = true), duals = (:enBal, :excRestr, :stBal))

# ! options for stabilization

# write tuple for stabilization
stabMap_dic = YAML.load_file(dir_str * "stabMap.yaml")
if trust in keys(stabMap_dic)
	meth_tup = tuple(map(x -> Symbol(x[1]) => (; (Symbol(k) => v for (k, v) in x[2])...), collect(stabMap_dic[trust]))...)
else
	meth_tup = tuple()
end

stabSetup_obj = stabSetup(meth_tup, 0.0, :reduced, 0.01, (upper = 70, inter = :log, sub = 10.0), true) # :none for last argument will skip initialization, other names just used for setting input folder below

# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = checkDet_boo ? 0 : 3, supTsLvl = 2, repTsLvl = 4, shortExp = 5) 

# ! input folders
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "securitySetup/" * security, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/" * spaSco * "/" * techs, setupDir_str * "resolution/default_country", scrDir_str, modDir_str * "timeSeries/country_" * time * "_month/general"]
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_month/general_" * x), unique(getindex.(scrQrt_arr,2)))
foreach(x -> push!(inDir_arr, modDir_str * "timeSeries/country" * "_" * time * "_" * "month/" * x[1] * "/" * x[2]), scrQrt_arr)

heuDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter", setupDir_str * "securitySetup/" * security, setupDir_str * "spatialScope/" * spaSco, setupDir_str * "techSetup/" * spaSco * "/" * techs, setupDir_str * "resolution/default_country", scrDirHeu_str, modDir_str * "timeSeries/country_672h_month/general"]
foreach(x -> push!(heuDir_arr, modDir_str * "timeSeries/country_672h_month/general_" * x), unique(getindex.(scrQrtHeu_arr,2)))
foreach(x -> push!(heuDir_arr, modDir_str * "timeSeries/country_672h_month/" * x[1] * "/" * x[2]), scrQrtHeu_arr)

if inOos != "missing"
	push!(inDir_arr, dir_str * "inputOutOfSample/" * inOos)
	push!(heuDir_arr, dir_str * "inputOutOfSample/" * inOos)
end

# ! result folders
resultDir_str = dir_str * "results/" * (checkDet_boo ? "deterministic" : name_str)

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

if solve == "scaleA"
	scale_dic[:facTop] = (capa = 1e4, capaStSize = 1e4, insCapa = 1e4, dispConv = 1e3, dispSt = 1e4, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)	
elseif solve == "scaleB"
	scale_dic[:facTop] = (capa = 1e5, capaStSize = 1e5, insCapa = 1e5, dispConv = 1e4, dispSt = 1e5, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
elseif solve == "scaleC"
	scale_dic[:facTop] = (capa = 1e6, capaStSize = 1e6, insCapa = 1e6, dispConv = 1e45, dispSt = 1e6, dispExc = 1e3, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e0, obj = 1e3)
end

#endregion

#region # * prepare iteration

# initialize distributed computing
if algSetup_obj.dist
	addprocs(SlurmManager(; launch_timeout = 300), exeflags="--heap-size-hint=" * string(floor(t_int * ram) - 2 ) * "G", nodes=1, ntasks=1, ntasks_per_node=1, cpus_per_task=t_int, mem_per_cpu= string(ram) * "G", time=6000) # add all available nodes
	# rmprocs(wrkCnt + 2) # remove one node again for main process
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
benders_obj = bendersObj(info_ntup, inputFolder_ntup, scale_dic, algSetup_obj, stabSetup_obj, runSubDist, getComVarDist, res_ntup, nearOptSetup_obj);

#endregion

#region # * iteration algorithm

runIteration!(benders_obj, runSubDist)

#endregion

#region # * write results

produceMessage(benders_obj.report.mod.options, benders_obj.report.mod.report, 1, " - Write results", testErr = false, printErr = false)
writeBendersResults!(benders_obj, runSubDist, getSubStringDist, res_ntup)

if inOos == "missing"
	outDir_str = dir_str * "inputOutOfSample/" * name_str * "/"
	writeResultsAsInputs!(benders_obj, outDir_str)
end

#endregion