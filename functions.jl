function generateScrInfo(checkDet_boo::Bool, scenario::String, setupDir_str::String, scope::String)

    frs_arr = ["m01", "m02", "m03", "m04", "m05", "m06", "m07", "m08", "m09", "m10", "m11", "m12"]

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
        if isfile(scrDir_str * "/par_scrProb.csv")
            scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(filter(x -> x.value != 0.0, CSV.read(scrDir_str * "/par_scrProb.csv", DataFrame))))
        else
            scr_arr = CSV.read(scrDir_str * "/set_scenario.csv", DataFrame)[!,:scenario]
            scrQrt_arr = vcat(map(x -> map(y -> (x,y), frs_arr), scr_arr)...)
        end 
    end

    return scrQrt_arr, scrDir_str, (ts = Dict(x => [x] for x in unique(getindex.(scrQrt_arr,2))), scr = Dict(x => [x] for x in unique(getindex.(scrQrt_arr,1))))
end