using AnyMOD, Gurobi, CSV, Statistics

h = "96"     # resolution of time-series for actual solve, can be 96, 1752, 4392, or 8760

for i in 1:3
    # ! string here define scenario, overwrite ARGS with respective values for hard-coding scenarios according to comments
    grid = "_gridExp" # scenario for grid expansion, can be "_gridExp" and "_noGridExp"
    t_int = 4 # number of threads
    obj_str = h * "hours_" * "hoursHeu" * grid

   # inputMod_arr = ["_basis", grid, "timeSeries/" * h * "hours_2008_only2040", "Scenario_" * h * "/Scenario_$i"]

 #   inputMod_arr = ["_basis", grid, "_bevScenario/Scenario_$i/costData", "_bevScenario/timeSeries_Scr$i/" * h]

    inputMod_arr = ["_basis", grid, "timeSeries/" * h * "hours_2008_only2040","_bevScenario/costData_Scr$i", "_bevScenario/timeSeries_96_Scr$i/" ]

    resultDir_str = "results_" * h

    #region # * create and solve main model

    anyM = anyModel(inputMod_arr, resultDir_str, objName="Scenario_$i", supTsLvl=2, shortExp=5, redStep=1.0, emissionLoss=false, holdFixed=true)

    createOptModel!(anyM)
    setObjective!(:cost, anyM)

    set_optimizer(anyM.optModel, Gurobi.Optimizer)
    set_optimizer_attribute(anyM.optModel, "Method", 2)
    set_optimizer_attribute(anyM.optModel, "Crossover", 0)
    set_optimizer_attribute(anyM.optModel, "Threads", t_int)
    set_optimizer_attribute(anyM.optModel, "BarConvTol", 1e-5)

    optimize!(anyM.optModel)

    checkIIS(anyM)

    #endregion

    #region # * write results

    reportResults(:summary, anyM, addRep=(:capaConvOut,), addObjName=true)
    reportResults(:exchange, anyM, addObjName=true)
    reportResults(:cost, anyM, addObjName=true)
    #endregion

end
