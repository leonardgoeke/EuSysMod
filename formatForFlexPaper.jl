
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

anyM.graInfo.names["spaceHeat"] = "space heat"
anyM.graInfo.names["processHeat_low"] = "process heat - low"
anyM.graInfo.names["processHeat_medium"] = "process heat - medium"
anyM.graInfo.names["processHeat_high"] = "process heat - high"

anyM.graInfo.names["synthLiquid"] = "synthetic oil"
anyM.graInfo.names["jetFuel"] = "jet fuel"

anyM.graInfo.names["diesel"] = "gasoline/diesel"
anyM.graInfo.names["gasFuel"] = "gas"
anyM.graInfo.names["crudeOil"] = "crude oil"

anyM.graInfo.names["frtRoadHeavy"] = "heavy road"
anyM.graInfo.names["frtRoadLight"] = "light road"
anyM.graInfo.names["frtRail"] = "rail freight"
anyM.graInfo.names["psngRail"] = "rail passenger"
anyM.graInfo.names["psngRoadPrvt"] = "private road"
anyM.graInfo.names["psngRoadPub"] = "public road"


#endregion

#region # * technology names

anyM.graInfo.names["ePsngRail"] = "electric, rail passenger"
anyM.graInfo.names["eFrtRail"] = "electric, rail, freight"

anyM.graInfo.names["dieselPsngRail"] = "diesel, rail passenger"
anyM.graInfo.names["dieselFrtRail"] = "diesel, rail freight"

anyM.graInfo.names["fcPsngRail"] = "fc, rail passenger"
anyM.graInfo.names["fcFrtRail"] = "fc, rail freight"

anyM.graInfo.names["fcPsngRoadPub"] = "fuel-cell, public road"
anyM.graInfo.names["dieselPsngRoadPub"] = "ice, public road"
anyM.graInfo.names["bevPsngRoadPub"] = "bev, public road"

anyM.graInfo.names["fcFrtRoadHeavy"] = "fuel-cell, heavy road"
anyM.graInfo.names["dieselFrtRoadHeavy"] = "ice, heavy road"
anyM.graInfo.names["oberFrtRoadHeavy"] = "overhead, heavy road"
anyM.graInfo.names["bevFrtRoadHeavy"] = "bev, heavy road"

anyM.graInfo.names["cngPsngRoadPrvt"] = "cng, private road"
anyM.graInfo.names["dieselPsngRoadPrvt"] = "ice, private road"
anyM.graInfo.names["fcevPsngRoadPrvt"] = "fc, private road"
anyM.graInfo.names["bevPsngRoadPrvt"] = "bev, private road"

anyM.graInfo.names["bevFrtRoadLight"] = "bev, light road"
anyM.graInfo.names["dieselFrtRoadLight"] = "ice, private road"
anyM.graInfo.names["fcFrtRoadLight"] = "fc, private road"

anyM.graInfo.names["pitThermalStorage"] = "pit thermal storage"
anyM.graInfo.names["largeWaterTank"] = "water tank storage"

anyM.graInfo.names["thermal"] = "coal retrofit"
anyM.graInfo.names["solidBioPlantDh"] = "dh plant, solid bm"
anyM.graInfo.names["nonSolidBioPlantDh"] = "dh plant, non-solid bm"
anyM.graInfo.names["bioGasEngineDh"] = "dh engine, biogas"
anyM.graInfo.names["gasEngineDh"] = "dh engine, gas"

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
anyM.graInfo.names["bioBoilerProLow"] = "low temp. boiler, solid bm"

anyM.graInfo.names["sofc"] = "solid oxide fc"
anyM.graInfo.names["soElectrolysis"] = "solid oxide electrolysis"
anyM.graInfo.names["methanePyrolysis"] = "pyrolysis"
anyM.graInfo.names["directAirCapture"] = "direct air capture"

anyM.graInfo.names["ccgtH2BackProMed"] = "medium temp. ccgt back, H2"
anyM.graInfo.names["ccgtGasBackProMed"] = "medium temp. ccgt back, gas"
anyM.graInfo.names["oilPlantProMed"] = "medium temp. plant, oil"
anyM.graInfo.names["bioGasEngineProMed"] = "medium temp. engine, biogas"
anyM.graInfo.names["engineMed"] = "medium temp. engine, gas"

anyM.graInfo.names["ccgtH2BackProLow"] = "low temp. ccgt back, H2"
anyM.graInfo.names["ccgtGasBackProLow"] = "low temp. ccgt back, gas"
anyM.graInfo.names["oilPlantProLow"] = "low temp. plant, oil"
anyM.graInfo.names["bioGasEngineProLow"] = "low temp. engine, biogas"
anyM.graInfo.names["gasEngineProLow"] = "low temp. engine, gas"

anyM.graInfo.names["nonSolidBioPlantProLow"] = "low temp. plant, non-solid bm"
anyM.graInfo.names["solidBioPlantProLow"] = "low temp. plant, solid bm"

anyM.graInfo.names["districtHeatPro"] = "dh substation"
anyM.graInfo.names["heatpumpPro"] = "hp"


anyM.graInfo.names["nonSolidBioBoilerDh"] = "dh boiler, non-solid bm"
anyM.graInfo.names["solidBioBoilerDh"] = "dh boiler, solid bm"
anyM.graInfo.names["h2BoilerDh"] = "dh boiler, H2"
anyM.graInfo.names["eBoilerDh"] = "dh boiler, electric"
anyM.graInfo.names["gasBoilerDh"] = "dh boiler, gas"

anyM.graInfo.names["pemElectrolysis"] = "pem electrolysis"
anyM.graInfo.names["alkElectrolysis"] = "alkali electrolysis"
anyM.graInfo.names["gasification"] = "gasification"

anyM.graInfo.names["heatpumpGroundSpace"] = "ground hp"
anyM.graInfo.names["heatpumpAirSpace"] = "air hp"

anyM.graInfo.names["heatpumpAirDh"] = "dh air hp"

anyM.graInfo.names["districtHeatSpace"] = "district heating"
anyM.graInfo.names["solarThermalResi_a"] = "thermal solar"
anyM.graInfo.names["gasBoilerSpace"] = "space boiler, gas"
anyM.graInfo.names["bioBoilerSpace"] = "space boiler, solid bm"
anyM.graInfo.names["resistiveHeatSpace"] = "resistive heating"

anyM.graInfo.names["ccgtH2Extract"] = "ccgt extract, H2"
anyM.graInfo.names["ccgtGasExtract"] = "ccgt extract, gas"
anyM.graInfo.names["ccgtH2BackDh"] = "ccgt back, H2"
anyM.graInfo.names["ccgtGasBackDh"] = "ccgt back, gas"
anyM.graInfo.names["ocgtH2Chp"] = "ocgt chp, H2"
anyM.graInfo.names["ocgtGasChp"] = "ocgt chp, gas"



anyM.graInfo.names["wind"] = "wind, onshore"
anyM.graInfo.names["runOfRiver"] = "run-of-river"

anyM.graInfo.names["dieselEngine"] = "engine, oil"
anyM.graInfo.names["gasEngine"] = "engine, gas"
anyM.graInfo.names["ocgtGas"] = "ocgt, gas"
anyM.graInfo.names["ocgtH2"] = "ocgt, H2"

anyM.graInfo.names["pefc"] = "fc"

anyM.graInfo.names["solar1"] = "pv, openspace"
anyM.graInfo.names["solar2"] = "pv, rooftop industry"
anyM.graInfo.names["solar3"] = "pv, rooftop residential"
anyM.graInfo.names["wind2"] = "wind, offshore"
anyM.graInfo.names["battery"] = "lithium battery"
anyM.graInfo.names["battery2"] = "redox battery"

anyM.graInfo.names["biogasPlant"] = "biogas plant"
anyM.graInfo.names["biogasUpgrading"] = "biogas upgrading"
anyM.graInfo.names["gasification"] = "gasification"
anyM.graInfo.names["hydropyrolysis"] = ""
anyM.graInfo.names["electrolysis1"] = "alkali electrolysis"
anyM.graInfo.names["electrolysis2"] = "pem electrolysis"
anyM.graInfo.names["electrolysis3"] = "solid oxide electrolysis"

anyM.graInfo.names["h2Storage1"] = "storage cavern"
anyM.graInfo.names["h2Storage2"] = "storage tank"
anyM.graInfo.names["bioMethanation"] = "biogas methanation"
anyM.graInfo.names["methanePyrolysis"] = "methane pyrolysis"

anyM.graInfo.names["h2ToDiesel"] = "H2 to gasoline"
anyM.graInfo.names["h2ToJetFuel"] = "H2 to jet fuel"
anyM.graInfo.names["refinery"] = "refinery"










#endregion



for t in keys(anyM.parts.tech)
    anyM.graInfo.names[string(t)] = ""
end

anyM.graInfo.names["thermal"] = ""
anyM.graInfo.names["h2Storage"] = ""
anyM.graInfo.names["engineMed"] = ""
anyM.graInfo.names["openspace_a"] = ""
anyM.graInfo.names["rooftopInd_a"] = ""
anyM.graInfo.names["wind"] = ""
anyM.graInfo.names["battery"] = ""
