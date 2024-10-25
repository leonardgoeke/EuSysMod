using Gurobi, AnyMOD, CSV, YAML

dir_str = ""

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
foresight = string(par_df[id_int,:foresight]) # foresight
solve = par_df[id_int,:solve]

# extract benders settings
wrkCnt = par_df[id_int,:workerCnt]
cutDel = par_df[id_int,:cutDel]
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]

name_str = time * "_" * spaSco * "_" * scenario * "_" * foresight * "_" * string(trust) * "trust_" * string(cutDel) * "cutDel_" * string(dnsThrs) * "dnsThrs_" * solve

# create scenario and quarter array
scrDir_str = dir_str * "scenarioSetup/" * scenario * "_" * foresight
scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(scrDir_str * "/par_scrProb.csv", DataFrame))))

#region # * options for algorithm

# ! options for general algorithm

rngVio_ntup = (stab = 1e2, cut = 1e4, fix = 1e4)
rngTar_tup = (mat = (1e-2,1e5), rhs = (1e-2,1e2))

# target gap, inaccurate cuts options, number of iteration after unused cut is deleted, valid inequalities, number of iterations report is written, time-limit for algorithm, distributed computing?, number of threads, optimizer
if occursin("lvl",trust)
	numFoc_arr = [0,0]
else
	numFoc_arr = [0,3]
end

if solve == "crsAllNoLim"
	algSetup_obj = algSetup(0.05, cutDel, (bal = false, st = true), 2, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = true, meth = :barrier, timeLim = 0.0, dbInf = true), (numFoc = numFoc_arr, dnsThrs = dnsThrs, crs = true))
elseif solve == "crsAll5Lim"
	algSetup_obj = algSetup(0.05, cutDel, (bal = false, st = true), 2, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = true, meth = :barrier, timeLim = 0.01, dbInf = true), (numFoc = numFoc_arr, dnsThrs = dnsThrs, crs = true))
elseif solve == "crsTop5Lim"
	algSetup_obj = algSetup(0.05, cutDel, (bal = false, st = true), 2, 4320.0, false, t_int, Gurobi.Optimizer, rngVio_ntup, (rng = [1e-2, 1e-8], int = :none, crs = false, meth = :barrier, timeLim = 5.0, dbInf = true), (numFoc = numFoc_arr, dnsThrs = dnsThrs, crs = true))
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

stabSetup_obj = stabSetup(meth_tup, 0.0, :reduced) # :none for last argument will skip initialization, other names just used for setting input folder below


# ! options for near optimal

# defines objectives for near-optimal (can only take top-problem variables, must specify a variable)
nearOptSetup_obj = nothing # cost threshold to keep solution, lls threshold to keep solution, epsilon for near-optimal, cut deletion

#endregion

#region # * options for problem

# ! general problem settings

# name, temporal resolution, level of foresight, superordinate dispatch level, length of steps between investment years
info_ntup = (name = name_str, frsLvl = 3, supTsLvl = 2, repTsLvl = 3, shortExp = 5) 

# ! input folders
if foresight == "month"
	fore_tup = tuple(map(x -> "ini" * string(x), 1:12)...)
elseif foresight == "3month"
	fore_tup = tuple(map(x -> "ini" * string(x), 1:4)...)
end

inDir_arr = [dir_str * "_basis", dir_str * "spatialScope/" * spaSco, dir_str * "sectorCoupling/fixed_country", dir_str * "resolution/default_country", scrDir_str, dir_str * "timeSeries/country_" * time * "_" * foresight * "/general"]
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "_" * foresight * "/general_" * x), fore_tup)
foreach(x -> push!(inDir_arr, dir_str * "timeSeries/country" * "_" * time * "_" * foresight * "/" * x[1] * "/" * x[2]), scrQrt_arr)

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
	addprocs(8)
	#addprocs(SlurmManager(; launch_timeout = 300), exeflags="--heap-size-hint=60G", nodes=1, ntasks=1, ntasks_per_node=1, cpus_per_task=8, mem_per_cpu="8G", time=4380) # add all available nodes
	#rmprocs(wrkCnt + 2) # remove one node again for main process
	@everywhere begin
		using Gurobi, AnyMOD
		runSubDist(w_int::Int64, resData_obj::resData, rngVio_fl::Float64, sol_sym::Symbol, optTol_fl::Float64=1e-8, crsOver_boo::Bool=false, resultOpt_tup::NamedTuple=NamedTuple()) = Distributed.@spawnat w_int runSub(resData_obj, rngVio_fl, sol_sym, optTol_fl, crsOver_boo, resultOpt_tup)
		getComVarDist(w_int::Int64) = Distributed.@spawnat w_int getComVar()
		getSubStringDist(w_int::Int64, res_sym::Symbol) = Distributed.@spawnat w_int getSubString(res_sym)
	end
	passobj(1, workers(), [:info_ntup, :inputFolder_ntup, :scale_dic, :algSetup_obj])
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

#endregion

#region # * compute dual variables for monte carlo analysis

outDir_str = dir_str * "inputMonteCarlo/fixes/" * name_str * "/"

writeVariableFix!(benders_obj, outDir_str)
editTopForDuals!(benders_obj, inputFolder_ntup, info_ntup, stabSetup_obj, scale_dic, algSetup_obj, outDir_str, runSubDist)
runIteration!(benders_obj, runSubDist)

#endregion

# TODO next: extract and write duals, how storage levels -> write montecarlo part 

removeStab!(benders_obj)
optimize!(benders_obj.top.optModel)



for x in filter(x -> occursin("Benders",string(x)), keys(benders_obj.top.parts.lim.cns))
	var_df = copy(benders_obj.top.parts.lim.cns[x])
	var_df[!,:dual] = dual.(var_df[!,:cns])
end

var_df = copy(benders_obj.top.parts.tech[:gasStorage].cns[:expcStLvl])
var_df[!,:dual] = dual.(var_df[!,:cns])
select!(var_df,Not([:cns]))

var_df[1,:cns]