
#region # * colors

anyM.graInfo.colors["capturedCO2"] = (0.0,  0.0, 0.0)
anyM.graInfo.colors["h2"] = (0.329, 0.447, 0.827)

anyM.graInfo.colors["rawBiogas"] = (0.682, 0.898, 0.443)
anyM.graInfo.colors["solidBiomass"] = (0.682, 0.898, 0.443)
anyM.graInfo.colors["nonSolidBiomass"] =  (0.682, 0.898, 0.443)
anyM.graInfo.colors["otherBiomass"] = (0.682, 0.898, 0.443)

anyM.graInfo.colors["spaceHeat"] = (1.0, 0.4549019607843137, 0.5215686274509804)
anyM.graInfo.colors["processHeat_low"] = (0.6823529411764706, 0.07058823529411765, 0.22745098039215686)
anyM.graInfo.colors["processHeat_medium"] = (0.6823529411764706, 0.07058823529411765, 0.22745098039215686)
anyM.graInfo.colors["processHeat_high"] = (0.6823529411764706, 0.07058823529411765, 0.22745098039215686)

anyM.graInfo.colors["jetFuel"] = (0.235, 0.506, 0.325)
anyM.graInfo.colors["crudeOil"] = (0.33725490196078434, 0.3411764705882353, 0.3254901960784314)
anyM.graInfo.colors["diesel"] = (0.33725490196078434, 0.3411764705882353, 0.3254901960784314)
anyM.graInfo.colors["gasoline"] = (0.33725490196078434, 0.3411764705882353, 0.3254901960784314)

anyM.graInfo.colors["synthGas"] = (0.235, 0.506, 0.325)
anyM.graInfo.colors["naturalGas"] = (1.0,  0.416, 0.212)
anyM.graInfo.colors["gasFuel"] = (1.0,  0.416, 0.212)

anyM.graInfo.colors["frtRoadHeavy"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["frtRoadLight"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["frtRail"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["psngRail"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["psngRoadPrvt"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)
anyM.graInfo.colors["psngRoadPub"] = (0.43529411764705883, 0.7843137254901961, 0.7137254901960784)

#endregion

#region # * carrier names

anyM.graInfo.names["capturedCO2"] = "carbon"
anyM.graInfo.names["h2"] = "H2"

anyM.graInfo.names["solidBiomass"] = "solid biomass"
anyM.graInfo.names["rawBiogas"] =  "raw biogas"
anyM.graInfo.names["nonSolidBiomass"] = "non-solid biomass"
anyM.graInfo.names["otherBiomass"] = "other biomass"

anyM.graInfo.names["spaceHeat"] = "space heat"
anyM.graInfo.names["processHeat_low"] = "process heat - low"
anyM.graInfo.names["processHeat_medium"] = "process heat - medium"
anyM.graInfo.names["processHeat_high"] = "process heat - high"

anyM.graInfo.names["synthLiquid"] = "synthetic oil"
anyM.graInfo.names["jetFuel"] = "jet fuel"

anyM.graInfo.names["gasFuel"] = "gas"
anyM.graInfo.names["crudeOil"] = "crude oil"
anyM.graInfo.names["refinedOil"] = "refined oil"

anyM.graInfo.names["frtRoadHeavy"] = "heavy road"
anyM.graInfo.names["frtRoadLight"] = "light road"
anyM.graInfo.names["frtRail"] = "rail freight"
anyM.graInfo.names["psngRail"] = "rail passenger"
anyM.graInfo.names["psngRoadPrvt"] = "private road"
anyM.graInfo.names["psngRoadPub"] = "public road"




#endregion

#region # * technology names


anyM.graInfo.names["lithiumBattery"] = "lithium battery"
anyM.graInfo.names["redoxBattery"] = "redox battery"

anyM.graInfo.names["ePsngRail"] = "electric, rail passenger"
anyM.graInfo.names["eFrtRail"] = "electric, rail, freight"

anyM.graInfo.names["dieselPsngRail"] = "diesel, rail passenger"
anyM.graInfo.names["dieselFrtRail"] = "diesel, rail freight"

anyM.graInfo.names["fcPsngRail"] = "FC, rail passenger"
anyM.graInfo.names["fcFrtRail"] = "FC, rail freight"

anyM.graInfo.names["fcPsngRoadPub"] = "FC, public road"
anyM.graInfo.names["dieselPsngRoadPub"] = "ICE, public road"
anyM.graInfo.names["bevPsngRoadPub"] = "BEV, public road"

anyM.graInfo.names["fcFrtRoadHeavy"] = "FC, heavy road"
anyM.graInfo.names["dieselFrtRoadHeavy"] = "ICE, heavy road"
anyM.graInfo.names["oberFrtRoadHeavy"] = "overhead, heavy road"
anyM.graInfo.names["bevFrtRoadHeavy"] = "BEV, heavy road"

anyM.graInfo.names["cngPsngRoadPrvt"] = "CNG, private road"
anyM.graInfo.names["ottoPsngRoadPrvt"] = "ICE, private road"
anyM.graInfo.names["fcevPsngRoadPrvt"] = "FC, private road"
anyM.graInfo.names["bevPsngRoadPrvt"] = "BEV, private road"

anyM.graInfo.names["bevFrtRoadLight"] = "BEV, light road"
anyM.graInfo.names["dieselFrtRoadLight"] = "ICE, light road"
anyM.graInfo.names["fcFrtRoadLight"] = "FC, light road"

anyM.graInfo.names["pitThermalStorage"] = "pit thermal storage"
anyM.graInfo.names["largeWaterTank"] = "water tank storage"

anyM.graInfo.names["thermal"] = "coal retrofit"
anyM.graInfo.names["solidBioPlantDh"] = "DH plant, solid BM"
anyM.graInfo.names["nonSolidBioPlantDh"] = "DH plant, non-solid BM"
anyM.graInfo.names["bioGasEngineDh"] = "DH engine, biogas"
anyM.graInfo.names["gasEngineDh"] = "DH engine, gas"

anyM.graInfo.names["gasBoilerProHigh"] = "high temp. boiler, gas"
anyM.graInfo.names["h2BoilerProHigh"] = "high temp. boiler, H2"
anyM.graInfo.names["oilBoilerProHigh"] = "high temp. boiler, oil"
anyM.graInfo.names["eBoilerProHigh"] = "high temp. boiler, electric"

anyM.graInfo.names["gasBoilerProMed"] = "medium temp. boiler, gas"
anyM.graInfo.names["h2BoilerProMed"] = "medium temp. boiler, H2"
anyM.graInfo.names["oilBoilerProMed"] = "medium temp. boiler, oil"
anyM.graInfo.names["eBoilerProMed"] = "medium temp. boiler, electric"
anyM.graInfo.names["bioBoilerProMed"] = "medium temp. boiler, raw biogas"

anyM.graInfo.names["gasBoilerProLow"] = "low temp. boiler, gas"
anyM.graInfo.names["h2BoilerProLow"] = "low temp. boiler, H2"
anyM.graInfo.names["oilBoilerProLow"] = "low temp. boiler, oil"
anyM.graInfo.names["eBoilerProLow"] = "low temp. boiler, electric"
anyM.graInfo.names["bioBoilerProLow"] = "low temp. boiler, solid BM"

anyM.graInfo.names["sofc"] = "solid oxide FC"
anyM.graInfo.names["soElectrolysis"] = "solid oxide electrolysis"
anyM.graInfo.names["methanePyrolysis"] = "methane pyrolysis"
anyM.graInfo.names["directAirCapture"] = "direct air capture"

anyM.graInfo.names["ccgtH2BackProMed"] = "medium temp. CCGT back, H2"
anyM.graInfo.names["ccgtGasBackProMed"] = "medium temp. CCGT back, gas"
anyM.graInfo.names["oilPlantProMed"] = "medium temp. plant, oil"
anyM.graInfo.names["bioGasEngineProMed"] = "medium temp. engine, biogas"
anyM.graInfo.names["engineMed"] = "medium temp. engine, gas"

anyM.graInfo.names["ccgtH2BackProLow"] = "low temp. CCGT back, H2"
anyM.graInfo.names["ccgtGasBackProLow"] = "low temp. CCGT back, gas"
anyM.graInfo.names["oilPlantProLow"] = "low temp. plant, oil"
anyM.graInfo.names["bioGasEngineProLow"] = "low temp. engine, biogas"
anyM.graInfo.names["gasEngineProLow"] = "low temp. engine, gas"

anyM.graInfo.names["nonSolidBioPlantProLow"] = "low temp. plant, non-solid BM"
anyM.graInfo.names["solidBioPlantProLow"] = "low temp. plant, solid BM"

anyM.graInfo.names["districtHeatPro"] = "DH substation"
anyM.graInfo.names["heatpumpPro"] = "HP"


anyM.graInfo.names["nonSolidBioBoilerDh"] = "DH boiler, non-solid BM"
anyM.graInfo.names["solidBioBoilerDh"] = "DH boiler, solid BM"
anyM.graInfo.names["h2BoilerDh"] = "DH boiler, H2"
anyM.graInfo.names["eBoilerDh"] = "DH boiler, electric"
anyM.graInfo.names["gasBoilerDh"] = "DH boiler, gas"

anyM.graInfo.names["pemElectrolysis"] = "pem electrolysis"
anyM.graInfo.names["alkElectrolysis"] = "alkali electrolysis"
anyM.graInfo.names["gasification"] = "gasification"

anyM.graInfo.names["heatpumpGroundSpace"] = "ground HP"
anyM.graInfo.names["heatpumpAirSpace"] = "air HP"

anyM.graInfo.names["heatpumpAirDh"] = "DH air HP"

anyM.graInfo.names["districtHeatSpace"] = "district heating"
anyM.graInfo.names["solarThermalResi_a"] = "thermal solar"
anyM.graInfo.names["gasBoilerSpace"] = "space boiler, gas"
anyM.graInfo.names["bioBoilerSpace"] = "space boiler, solid BM"
anyM.graInfo.names["resistiveHeatSpace"] = "resistive heating"

anyM.graInfo.names["ccgtH2Extract"] = "CCGT extract, H2"
anyM.graInfo.names["ccgtGasExtract"] = "CCGT extract, gas"
anyM.graInfo.names["ccgtH2BackDh"] = "CCGT back, H2"
anyM.graInfo.names["ccgtGasBackDh"] = "CCGT back, gas"
anyM.graInfo.names["ocgtH2Chp"] = "OCGT CHP, H2"
anyM.graInfo.names["ocgtGasChp"] = "OCGT CHP, gas"

anyM.graInfo.names["pumpedStorage"] = "pumped storage"

anyM.graInfo.names["runOfRiver"] = "run-of-river"

anyM.graInfo.names["dieselEngine"] = "engine, oil"
anyM.graInfo.names["gasEngine"] = "engine, gas"
anyM.graInfo.names["ocgtGas"] = "OCGT, gas"
anyM.graInfo.names["ocgtH2"] = "OCGT, H2"

anyM.graInfo.names["pefc"] = "pem FC"


anyM.graInfo.names["biogasPlant"] = "biogas plant"
anyM.graInfo.names["biogasUpgrading"] = "biogas upgrading"
anyM.graInfo.names["gasification"] = "gasification"
anyM.graInfo.names["hydropyrolysis"] = "hydropyrolysis"
anyM.graInfo.names["alkElectrolysis"] = "alkali electrolysis"
anyM.graInfo.names["pemElectrolysis"] = "pem electrolysis"
anyM.graInfo.names["soElectrolysis"] = "solid oxide electrolysis"

anyM.graInfo.names["h2ToCrudeOil"] = "H2 to crude oil"
anyM.graInfo.names["h2StorageCavern"] = "H2 storage cavern"
anyM.graInfo.names["h2StorageTank"] = "H2 storage tank"
anyM.graInfo.names["gasStorage"] = "gas storage cavern"

anyM.graInfo.names["bioMethanation"] = "biogas methanation"

anyM.graInfo.names["h2ToDiesel"] = "H2 to gasoline"
anyM.graInfo.names["h2ToJetFuel"] = "H2 to jet fuel"
anyM.graInfo.names["refinery"] = "refinery"

anyM.graInfo.names["nuclearPower"] = "nuclear"

#endregion


