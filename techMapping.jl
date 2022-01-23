
aggRelCol_dic = Dict{Symbol, Array{Pair}}()

aggRelCol_dic[:electricity] =
["h2, electricity supply (excl. industry)" => ("gen; ccgtH2BackDh","gen; ccgtH2Extract","gen; ocgtH2","gen; ocgtH2Chp"), 
"h2, electricity supply (only industry)" => ("gen; ccgtH2BackProLow", "gen; ccgtH2BackProMed","gen; ccgtGasBackDh"),
"gas, electricity supply (excl. industry)" => ("gen; gasEngine","gen; gasEngineDh","gen; nonSolidBioPlantDh","gen; ccgtGasExtractH2Rdy","gen; ccgtGasExtract","gen; bioGasEngineDh"), 
"gas, electricity supply (only industry)" => ("gen; nonSolidBioPlantProLow","gen; gasEngineProLow","gen; gasEngineProMed","gen; ccgtGasBackProLow","gen; ccgtGasBackProMed","gen; ccgtGasBackDhH2Rdy","gen; bioGasEngineProLow","gen; bioGasEngineProMed","gen; ocgtGas","gen; ocgtGasChp","gen; ocgtGasChpH2Rdy","gen; ocgtGasH2Rdy"),
"wind, electricity supply" => ("gen; offshore_a","gen; offshore_b","gen; onshore_a","gen; onshore_b","gen; onshore_c"),
"pv, electricity supply" => ("gen; pvInd_a","gen; pvInd_b","gen; pvOpenspace_a","gen; pvOpenspace_b","gen; pvOpenspace_c","gen; pvResi_a","gen; pvResi_b"), 
"hydro, electricity supply" => ("stExtOut; pumpedStorage","stExtOut; reservoir"),
"exchange" => ("import",), 
"electrolysis, electricity demand" => ("use; alkElectrolysis","use; pemElectrolysis","use; soElectrolysis"), 
"battery vehicles, electricity demand" => ("use; bevFrtRoadLight","use; bevPsngRoadPrvt","use; bevPsngRoadPub","use; bevFrtRoadHeavy"),
"other transport, electricity demand" => ("use; eFrtRail","use; oberFrtRoadHeavy", "use; ePsngRail"),
"direct-air capture, electricity demand" => ("use; directAirCapture",), 
"electric boiler district heating, electricity demand" => ("use; eBoilerDh",), 
"heatpump district heating, electricity demand" => ("use; heatpumpAirDh",),
"heatpump process heating, electricity demand" => ("use; heatpumpPro",), 
"heatpump space heating, electricity demand" => ("use; heatpumpAirSpace", "use; heatpumpGroundSpace"), 
"resistive space heating, electricity demand" => ("use; resistiveHeatSpace",),
"electric boiler process heating, electricity demand" => ("use; eBoilerProHigh","use; eBoilerProLow","use; eBoilerProMed"), 
"battery storage, electricity supply" => ("stExtOut; lithiumBattery", "stExtOut; redoxBattery"),
"final electricity demand" =>  ("demand",),
"fuel cell, electricity supply" => ("gen; pefc","gen; sofc"),
"biomass, electricity supply" => ("gen; solidBioPlantDh","gen; solidBioPlantProLow"),
"liquifaction, electricity demand" => ("use; liquifaction",)]

aggRelCol_dic[:districtHeat] = 
["gas chp, heat supply" => ("gen; bioGasEngineDh","gen; ccgtGasBackDh","gen; ccgtGasBackDhH2Rdy","gen; ccgtGasExtract","gen; ccgtGasExtractH2Rdy","gen; ocgtGasChp","gen; ocgtGasChpH2Rdy","gen; gasEngineDh"),
"biomass chp, heat supply" => ("gen; nonSolidBioPlantDh","gen; solidBioPlantDh"),
"h2 chp, heat supply" => ("gen; ccgtH2BackDh","gen; ccgtH2Extract","gen; ocgtH2Chp"),
"h2 boiler, heat supply" => ("gen; h2BoilerDh",),
"gas boiler, heat supply" => ("gen; gasBoilerDh",),
"biomass boiler, heat supply" => ("gen; nonSolidBioBoilerDh","gen; solidBioBoilerDh"),
"electric boiler, heat supply" => ("gen; eBoilerDh",),
"heatpump, heat supply" => ("gen; heatpumpAirDh",),
"electrolysis, heat supply" => ("gen; alkElectrolysis","gen; pemElectrolysis"),
"gasification, heat supply" => ("gen; gasification"),
"fuel-cell, heat supply" => ("gen; pefc"),
"water-tank storage, heat supply" => ("stExtOut; largeWaterTank",),
"pit storage, heat supply" => ("stExtOut; pitThermalStorage",),
"pit storage, heat demand" => ("stExtIn; pitThermalStorage",)
]

 



 

 



 
 







