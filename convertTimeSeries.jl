using CSV, DataFrames

dir_str = "timeSeries/"

fore_tup = tuple(map(x -> "ini" * string(x), 1:12)...)
fore_str = "month"

for t in ["672","2856","8760"]
    inFolder_str = "greenfield_ESCU_country_" * t  * "h_" * fore_str
    outFolder_str = "country_" * t  * "h_" * fore_str

    if isdir(dir_str * outFolder_str) rm(dir_str * outFolder_str, recursive = true) end
    mkdir(dir_str * outFolder_str)

    scr_arr = string.(1982:2016)

    allFile_arr = readdir(dir_str * inFolder_str)

    # ! loop over years to create seperate folder
    for scr in scr_arr

        relFile1_arr = filter(x -> occursin("scr", x) && occursin(scr, x), allFile_arr)
        mkdir(dir_str * outFolder_str * "/scr" * scr)

        for frs in fore_tup
            wrtDir_str = dir_str * outFolder_str * "/scr" * scr * "/" * frs
            relFile2_arr = filter(x -> split(split(x, "_")[end],".")[1] == frs, relFile1_arr)
            mkdir(wrtDir_str)
            foreach(x -> mv(dir_str * inFolder_str * "/" * x, wrtDir_str * "/" * x), relFile2_arr)
        end
    
    end


    # ! filter NaN for offshore
    relTech_arr = ["runOfRiver", "windOffshore", "windOnshore", "reservoirInflow", "openPumpedStorageInflow", "solarAva"]
    for scr in scr_arr
        for frs in fore_tup
            wrtDir_str = dir_str * outFolder_str * "/scr" * scr * "/" * frs
            ts_df = CSV.read(wrtDir_str * "/par_windOffshore_scr" * scr * "_" * frs * ".csv", DataFrame)
            ts_df = filter(x -> !isnan(x.value), ts_df)
            CSV.write(wrtDir_str * "/par_windOffshore_scr" * scr * "_" * frs * ".csv", ts_df)
        end

    end

    # ! move non-scenario files
    allRestFile_arr = readdir(dir_str * inFolder_str)
    for frs in fore_tup
        wrtDir_str = dir_str * outFolder_str * "/general_" * frs
        mkdir(wrtDir_str)
        relFile_arr = filter(x -> !occursin("scr",x) && split(split(x, "_")[end],".")[1] == frs, allRestFile_arr)
        foreach(x -> mv(dir_str * inFolder_str * "/" * x, wrtDir_str * "/" * x), relFile_arr)
    end

    # ! directly move remaing files to general folder
    wrtDir_str = dir_str * outFolder_str * "/general"
    mkdir(wrtDir_str)
    mv(dir_str * inFolder_str * "/set_timestep.csv", wrtDir_str * "/set_timestep.csv")
    mv(dir_str * inFolder_str * "/par_designFactorHeatpumpAirSpace.csv", wrtDir_str * "/par_designFactorHeatpumpAirSpace.csv")
    mv(dir_str * inFolder_str * "/par_designFactorHeatpumpGroundSpace.csv", wrtDir_str * "/par_designFactorHeatpumpGroundSpace.csv")
    mv(dir_str * inFolder_str * "/par_potentialOnshore.csv", wrtDir_str * "/par_potentialOnshore.csv")
    
    # ! delete time-series folder
    rm(dir_str * inFolder_str, recursive = true)
end
