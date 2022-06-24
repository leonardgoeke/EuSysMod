
# ! import AnyMOD and packages

using AnyMOD, Gurobi


# ! define in- and output folders
b = "" # add the model dir here
inputInvest_arr = [b * "_basis",b * "timeSeries/8760hours_det",b * "timeSeries/8760hours_s2_stoch"]
inputTest_arr = [b * "_basis",b * "timeSeries/8760hours_det",b * "timeSeries/8760hours_s4_stoch"]
resultDir_str = b * "results"
fixDir_str = b * "fixResult"

coefRng_tup = (mat = (1e-2,1e3), rhs = (1e0,1e3))
scaFac_tup = (capa = 1e2, capaStSize = 1e3, insCapa = 1e1, dispConv = 0.4e1, dispSt = 1e1, dispExc = 1e2, dispTrd = 1e3, costDisp = 1e1, costCapa = 1e2, obj = 1e0)

# ! create and solve investment model
# model creation
inv_m = anyModel(inputInvest_arr, resultDir_str, objName = "conv_s2", supTsLvl = 1,reportLvl = 2, shortExp = 10, coefRng = coefRng_tup, scaFac = scaFac_tup)
createOptModel!(inv_m)
setObjective!(:cost,inv_m)

# solve process
set_optimizer(inv_m.optModel, Gurobi.Optimizer)
set_optimizer_attribute(inv_m.optModel, "Method", 2);
set_optimizer_attribute(inv_m.optModel, "Crossover", 0);
optimize!(inv_m.optModel)

# write results to file
invRes_obj = bendersData()
invRes_obj.objVal = 0.0
invRes_obj.capa = writeResult(inv_m,[:capa,:exp,:mustCapa,:mustExp])

# ! test results of investment model

# writes results of investment model to files avoiding infeasbilites in the investment part 
optTest_tup =  (inputDir = inputTest_arr, resultDir = resultDir_str, suffix = "test_s4", supTsLvl = 1, shortExp = 10, coefRng = coefRng_tup, scaFac = scaFac_tup)
feasFix_dic = getFeasResult(optTest_tup,invRes_obj.capa,Dict{Symbol,Dict{Symbol,Dict{Symbol,DataFrame}}}(),4,0.001,Gurobi.Optimizer) # ensure feasiblity of invesment with fixed variables
writeFixToFiles(invRes_obj.capa,feasFix_dic,fixDir_str,inv_m) # write fixed variable values to files

# create and solve test model
test_m = anyModel(vcat(inputTest_arr,[fixDir_str]), resultDir_str, objName = "conv_s4", supTsLvl = 1,reportLvl = 2, shortExp = 10, coefRng = coefRng_tup, scaFac = scaFac_tup)
createOptModel!(test_m)
setObjective!(:cost,test_m)

set_optimizer(test_m.optModel, Gurobi.Optimizer)
set_optimizer_attribute(test_m.optModel, "Method", 2);
set_optimizer_attribute(test_m.optModel, "Crossover", 0);
optimize!(test_m.optModel)

reportResults(:cost,test_m)
reportResults(:summary,test_m)
reportResults(:exchange,test_m)