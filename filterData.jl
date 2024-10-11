using CSV, DataFrames

dir_str = "timeSeries/"

inFolder_str = "greenfield_ESCU_country_96h"
outFolder_str = "country_96h"

scr_arr = string.(1982:2016)

allFile_arr = readdir(dir_str * inFolder_str)



# ! loop over years to create seperate folder

for scr in scr_arr

    relFile1_arr = filter(x -> occursin("scr", x) && occursin(scr, x), allFile_arr)
    mkdir(dir_str * outFolder_str * "/scr" * scr)

    for frs in ("ini1","ini2","ini3","ini4")
        wrtDir_str = dir_str * outFolder_str * "/scr" * scr * "/" * frs
        relFile2_arr = filter(x -> occursin(frs, x), relFile1_arr)
        mkdir(wrtDir_str)

        foreach(x -> mv(dir_str * inFolder_str * "/" * x,wrtDir_str * "/" * x), relFile2_arr)

    end
 
end


# ! correct column names
relTech_arr = ["runOfRiver", "windOffshore", "windOnshore", "reservoirInflow", "openPumpedStorageInflow", "solarAva"]


for scr in scr_arr

    for frs in ("ini1","ini2","ini3","ini4")

        for x in relTech_arr
            wrtDir_str = dir_str * outFolder_str * "/scr" * scr * "/" * frs
            ts_df = CSV.read(wrtDir_str * "/par_" * x * "_scr" * scr * "_" * frs * ".csv", DataFrame)
            
            CSV.write(wrtDir_str * "/par_" * x * "_scr" * scr * "_" * frs * ".csv", rename(ts_df,:region_2 => :region_3))
        end
    end

end
