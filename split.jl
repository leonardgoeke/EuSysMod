using CSV, DataFrames

dir_str = "timeSeries/"




    fore_tup = ("ini01","ini02","ini03","ini04","ini05","ini06","ini07","ini08","ini09","ini10","ini11","ini12") 


    for t in ["8760"]

        if t == "672" && fore_str == "3month" continue end

       
        #region # used to reorganize folder, AFTER creating time-series with seperate scripts
        # TODO might be outdated since name "ini1" was reworked to "ini01" and so on
      
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
        mv(dir_str * inFolder_str * "/par_potentialPvInd.csv", wrtDir_str * "/par_potentialPvInd.csv")
        mv(dir_str * inFolder_str * "/par_potentialPvOpenspace.csv", wrtDir_str * "/par_potentialPvOpenspace.csv")
        
        # ! delete time-series folder
        rm(dir_str * inFolder_str, recursive = true)

        #endregion 

        #=
        #region # fix for foresight names ("ini01" instead of "ini1") transport (having avaStIn instead of avaConv)
      
        locDir_str = dir_str * "/country_" * t * "h_" * fore_str * "/"

        # ! fix for transport and ini01

        # rename general folders
        for i in 1:4
            mv(joinpath(locDir_str,"general_ini" * string(i)),joinpath(locDir_str,"general_ini0" * string(i)))
        end

        # rename scenario subfolders
        for f in filter(x -> occursin("scr",x), readdir(locDir_str))
            for i in 1:4
                mv(joinpath(locDir_str,f,"ini" * string(i)), joinpath(locDir_str,f,"ini0" * string(i)))
            end
        end

        # rename files
        for f1 in filter(x -> occursin("scr",x), readdir(locDir_str))
            for i in 1:4
                for f2 in readdir(joinpath(locDir_str, f1, "ini0" * string(i)))
                    f_str = joinpath(locDir_str, f1, "ini0" * string(i),f2)
                    mv(f_str,replace(f_str, "_ini" * string(i) * ".csv" => "_ini0" * string(i) * ".csv"))
                end
            end
        end

        # convert files for conversion
        for f1 in filter(x -> occursin("scr", x), readdir(locDir_str))
            for f2 in readdir(locDir_str * f1)
                for t in ("chargingProfileBevFrtRoadHeavy", "chargingProfileBevFrtRoadLight", "chargingProfileBevPsngRoadPrvt","chargingProfileBevPsngRoadPub")
                    dirLocal_str = locDir_str * f1 * "/" * f2 * "/par_" * t * "_" * f1 * "_" * f2 * ".csv"
                    data_df = CSV.read(dirLocal_str, DataFrame)
                    data_df[!,:parameter] .= "avaConv"
                    CSV.write(dirLocal_str, data_df)
                end
            end
        end
        =#
        #endregion

    end

