function generateScrInfo(checkDet_boo::Bool, scenario::String, setupDir_str::String, scope::String)

    # create scenario and quarter array
    if checkDet_boo # case of single year
        scrQrt_arr = [scenario]
        # create scenario folder
        scrFolDir_str = setupDir_str * "scenarios/"  * scope
        scrDir_str = scrFolDir_str * "/" * scenario
        if !isdir(scrFolDir_str) mkdir(scrFolDir_str) end
        if !isdir(scrDir_str)
            mkdir(scrDir_str)
            CSV.write(scrDir_str * "/set_scenario.csv", DataFrame(scenario = [scenario]))
        end	
    else
        scrDir_str = setupDir_str * "scenarios/"  * scope * "/" * scenario
        scrQrt_arr = CSV.read(scrDir_str * "/set_scenario.csv", DataFrame)[!,:scenario]
    end

    return scrQrt_arr, scrDir_str
end