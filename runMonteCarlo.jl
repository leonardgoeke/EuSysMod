
using Gurobi, AnyMOD, CSV

dir_str = "C:/Users/pacop/Downloads/EuSysMOD/inputMonteCarlo/"

par_df = CSV.read(dir_str * "settings_benders.csv", DataFrame)

if isempty(ARGS)
    id_int = 1
    t_int = 4
else
    id_int = parse(Int,ARGS[1])
end

time = string(par_df[id_int,:time]) # temporal resolution
spaSco = string(par_df[id_int,:spatialScope]) # spatial scope
scenario = string(par_df[id_int,:scenario]) # scenario case
foresight = string(par_df[id_int,:foresight]) # foresight

# keep these? only relevant to read right folder
solve = par_df[id_int,:solve]
cutDel = par_df[id_int,:cutDel]
trust = par_df[id_int,:trust]
dnsThrs = par_df[id_int,:dnsThrs]
t_int = 4

#region # * setup input folders and data

name_str = time * "_" * spaSco * "_" * scenario * "_" * foresight * "_" * string(trust) * "trust_" * string(cutDel) * "cutDel_" * string(dnsThrs) * "dnsThrs_" * solve

# problem settings
rngTar_tup = (mat = (1e-2,1e5), rhs = (1e-2,1e2))
scal_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e2, dispSt = 1e3, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)
info_ntup = (name = name_str, frsLvl = 3, supTsLvl = 2, repTsLvl = 3, shortExp = 5) 

modDir_str = dir_str * "inputFiles/"
setupDir_str = dir_str *  "modelSetup/"
monteDir_str = dir_str * "inputMonteCarlo/" * name_str

# define input folder
inDir_arr = [modDir_str * "basis", modDir_str * "infeasParameter/onlyMonteCarlo",
                setupDir_str * "techSetup/endogenous_heat", setupDir_str * "resolution/default_country", setupDir_str * "spatialScope/" * spaSco,
                    monteDir_str * "/storageFixes", monteDir_str * "/capacityFixes", monteDir_str * "/dualValues"]

# add starting levels of storage
startLvl_dic = Dict{Symbol,DataFrame}()
for file in readdir(monteDir_str * "/startingLvl")
    startLvl_dic[Symbol(split(file,"_")[2])] = CSV.read(monteDir_str * "/startingLvl/" * file,DataFrame)
end

#endregion

#region # * loop over random time periods

steps_int = 1
ini_int = 1
year_int = 1982

# create folder for scenario definition
if !isdir(setupDir_str * "scenarioSetup/scr" * string(year_int)) 
    mkdir(setupDir_str * "scenarioSetup/scr" * string(year_int))
    CSV.write(setupDir_str * "scenarioSetup/scr" * string(year_int) * "/set_scenario.csv", DataFrame(scenario = ["scr" * string(year_int)]))
end

tsFold_str = modDir_str * "timeSeries/country" * "_" * time * "_" * foresight * "/"
tsDir_arr = [setupDir_str * "scenarioSetup/scr" * string(year_int),  tsFold_str * "general", tsFold_str * "general_ini" * string(ini_int), tsFold_str * "scr" * string(year_int) * "/ini" * string(ini_int)]

# create problem
sub_m = anyModel(vcat(inDir_arr, tsDir_arr), dir_str * "results", objName = "subModel", frsLvl = info_ntup.frsLvl, repTsLvl = info_ntup.repTsLvl, supTsLvl = info_ntup.supTsLvl, shortExp = info_ntup.shortExp, coefRng = rngTar_tup, scaFac = scal_tup, holdFixed = true, monteCarlo = true);
delete!(sub_m.parts.lim.par, :emissionUp)

# enforce sub-problem settings
allFrs_arr = sort(getfield.(getNodesLvl(sub_m.sets[:Ts], info_ntup.frsLvl), :idx))
sub_m.subPro = tuple(allFrs_arr[ini_int], 1)

# create sup-problem including fix for starting levels
prepareMod!(sub_m, Gurobi.Optimizer, t_int)
startLvl_dic = fixStartingLevels!(sub_m, startLvl_dic, steps_int)

# solve 
optimize!(sub_m.optModel)

# write results (emissions, costs, lss, storage level)
reportResults(:summary, sub_m)
reportResults(:cost, sub_m)

sub_m.parts.tech[:oilStorage].cns[:stBal]
sub_m.parts.tech[:gasStorage].var[:stLvl]

