
function generateScrInfo(checkDet_boo::Bool, scenario::String, setupDir_str::String)

    # create scenario and quarter array
    if checkDet_boo # case of single year
        scrQrt_arr = map(x -> (scenario, "ini" * (x < 10 ? "0" : "") * string(x)), 1:12)
        # create scenario folder
        scrFolDir_str = setupDir_str * "scenarioSetup/"
        scrDir_str = scrFolDir_str * "/" * scenario
        if !isdir(scrFolDir_str) mkdir(scrFolDir_str) end
        if !isdir(scrDir_str)
            mkdir(scrDir_str)
            CSV.write(scrDir_str * "/set_scenario.csv", DataFrame(scenario = [scenario]))
        end	
    else
        scrDir_str = setupDir_str * "scenarioSetup/" * scenario * "_" * "month"
        scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(scrDir_str * "/par_scrProb.csv", DataFrame))))
    end

    return scrQrt_arr, scrDir_str
end