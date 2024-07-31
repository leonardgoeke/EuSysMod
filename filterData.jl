

dir_str = "C:/Git/EuSysMOD/timeSeries/"

inFolder_str = "cluster_96h_allScr"
outFolder_str = "cluster_96h"

allFile_arr = readdir(dir_str * inFolder_str)

scr_arr = string.(1982:2016)

# loop over years to create seperate folder

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