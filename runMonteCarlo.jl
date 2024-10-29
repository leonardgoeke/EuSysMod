
using Gurobi, AnyMOD

dir_str = "C:/Users/pacop/Desktop/git/EuSysMOD/"

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
solve = par_df[id_int,:solve]
t_int = 4

name_str = time * "_" * spaSco * "_" * scenario * "_" * foresight * "_" * string(trust) * "trust_" * string(cutDel) * "cutDel_" * string(dnsThrs) * "dnsThrs_" * solve

# problem settings
rngTar_tup = (mat = (1e-2,1e5), rhs = (1e-2,1e2))
scal_tup = (capa = 1e0, capaStSize = 1e2, insCapa = 1e0, dispConv = 1e2, dispSt = 1e3, dispExc = 1e1, dispTrd = 1e1, costDisp = 1e0, costCapa = 1e2, obj = 1e1)
info_ntup = (name = name_str, frsLvl = 3, supTsLvl = 2, repTsLvl = 3, shortExp = 5) 

# define input folder
inDir_arr = [dir_str * "_basis", dir_str * "spatialScope/" * spaSco, dir_str * "technologySetup/monteCarlo", dir_str * "resolution/default_country", dir_str * "inputMonteCarlo/fixes/" * name_str]

ini_int = 1
year_int = 1982

# create folder for scenario definition
if !isdir(dir_str * "scenarioSetup/scr" * string(year_int)) 
    mkdir(dir_str * "scenarioSetup/scr" * string(year_int))
    CSV.write(dir_str * "scenarioSetup/scr" * string(year_int) * "/set_scenario.csv", DataFrame(scenario = ["scr" * string(year_int)]))
end


import AnyMOD.getNodesLvl



tsFold_str = "timeSeries/country" * "_" * time * "_" * foresight * "/"
tsDir_arr = [dir_str * "scenarioSetup/scr" * string(year_int), dir_str * tsFold_str * "general", dir_str * tsFold_str * "general_ini" * string(ini_int), dir_str * tsFold_str * "scr" * string(year_int) * "/ini" * string(ini_int)]

# create problem
sub_m = anyModel(vcat(inDir_arr, tsDir_arr), dir_str * "results", objName = "subModel", frsLvl = info_ntup.frsLvl, repTsLvl = info_ntup.repTsLvl, supTsLvl = info_ntup.supTsLvl, shortExp = info_ntup.shortExp, coefRng = rngTar_tup, scaFac = scal_tup, holdFixed = true);

# enforce sub-problem settings
allFrs_arr = sort(getfield.(getNodesLvl(sub_m.sets[:Ts], info_ntup.frsLvl), :idx))
sub_m.subPro = tuple(allFrs_arr[ini_int], 1)
prepareMod!(sub_m, Gurobi.Optimizer, t_int)

