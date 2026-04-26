
function generateScrInfo(checkDet_boo::Bool, scenario::String, setupDir_str::String, spLen_str::Union{AbstractString, String})

    if spLen_str == "6month"
        ts_dic = Dict("ini01" => ["ini01","ini02","ini03","ini04","ini05","ini06"], "ini02" => ["ini07","ini08","ini09","ini10","ini11","ini12"])
    elseif spLen_str == "2month"
        ts_dic = Dict("ini01" => ["ini01","ini02"], "ini02" => ["ini03","ini04"], "ini03" => ["ini05","ini06"], "ini04" => ["ini07","ini08"], "ini05" => ["ini09","ini10"], "ini06" => ["ini11","ini12"])
    elseif spLen_str == "month"
        ts_dic = Dict("ini01" => ["ini01"], "ini02" => ["ini02"], "ini03" => ["ini03"], "ini04" => ["ini04"], "ini05" => ["ini05"], "ini06" => ["ini06"], "ini07" => ["ini07"], "ini08" => ["ini08"], "ini09" => ["ini09"], "ini10" => ["ini10"], "ini11" => ["ini11"], "ini12" => ["ini12"])
    elseif spLen_str == "year"
        ts_dic = Dict("ini01" => ["ini01","ini02","ini03","ini04","ini05","ini06","ini07","ini08","ini09","ini10","ini11","ini12"])
    end

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
        scrDir_str = setupDir_str * "scenarioSetup/" * scenario * "_" * spLen_str

        relScrData_df = filter(x -> x.value != 0.0, CSV.read(scrDir_str * "/par_scrProb.csv", DataFrame))

        # extend for resolutions other than one month (still folder structure for time-series still assumes months)
        relScrData_df[!,:timestep_3] = map(x -> ts_dic[string(x.timestep_3)], eachrow(relScrData_df))
        relScrData_df = flatten(relScrData_df, :timestep_3)

        scrQrt_arr = map(x -> (x.scenario, x.timestep_3), eachrow(relScrData_df))
    end

    return scrQrt_arr, scrDir_str, (ts = ts_dic, scr = Dict(x => [x] for x in unique(getindex.(scrQrt_arr,1))))
end