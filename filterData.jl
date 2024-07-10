

dir_str = "C:/Git/EuSysMOD/timeSeries/cluster_96h_4Scr/"

allFile_arr = readdir(dir_str)

scr_arr = ["1982", "1983", "1984", "1985"]

delFile_arr = filter(x -> !(!occursin("scr", x) || any(occursin.(scr_arr, x))), allFile_arr)

# delete filtered files
for file_str in delFile_arr
    rm(dir_str * file_str)
end
