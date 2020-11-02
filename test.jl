using AnyMOD

model_object = anyModel("basis","basis")

model_object.graInfo.colors["heatLow"] = (230/255,79/255,100/255)
model_object.graInfo.colors["heatMedium"] = (174/255,18/255,58/255)
model_object.graInfo.colors["heatHigh"] = (153/255,0/255,0/255)

model_object.graInfo.colors["localHeat"] = (255/255,116/255,133/255)
model_object.graInfo.colors["districtHeat"] = (196/255,45/255,74/255)

model_object.graInfo.colors["oil"] = (58/255,59/255,56/255)
model_object.graInfo.colors["synthOil"] = (0.235, 0.506, 0.325)
model_object.graInfo.colors["naturalOil"] = (86/255,87/255,83/255)

model_object.graInfo.colors["hydrogenGrid"] = (0.329, 0.447, 0.827)
model_object.graInfo.colors["hydrogenResi"] = (111/255,249/255,255/255)
model_object.graInfo.colors["hydrogenInd"] = (111/255,249/255,255/255)

model_object.graInfo.colors["mobility_passenger"] = (111/255,200/255,182/255)


model_object.graInfo.names["heatLow"] = "residental heat"
model_object.graInfo.names["localHeat"] = "local heat"

model_object.graInfo.names["localHeatCon"] = "local heating access"
model_object.graInfo.names["districtHeatCon_resi"] = "district heating access"

model_object.graInfo.names["heatPump_local"] = "heat-pump, local heating"
model_object.graInfo.names["heatPump_district"] = "heat-pump, district heating"
model_object.graInfo.names["heatPump_resi"] = "heat-pump, residental"

model_object.graInfo.names["fuelCell_local"] = "fuel cell, local heating"
model_object.graInfo.names["fuelCell_district"] = "fuel cell, district heating"
model_object.graInfo.names["fuelCell_resi"] = "fuel cell, residental"

model_object.graInfo.names["blockHeatingGas_local"] = "block heating, local"
model_object.graInfo.names["gasBoiler_resi"] = "gas boiler, residental"

model_object.graInfo.names["ccgtH2_district"] = "closed-cycle hydrogen"
model_object.graInfo.names["geothermal_district"] = "geothermal"




moveNode!(model_object, [("geothermal",[0.03,-0.04]),])

plotEnergyFlow(:graph,model_object, plotSize = (12.0,8.0), scaDist = 0.5, initTemp = 5.0, maxIter = 5000, replot = false)

