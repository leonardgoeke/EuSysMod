

dir_str = "C:/Users/pacop/Desktop/git/EuSysMOD/timeSeries/cluster_96h_2scr/"

allFile_arr = readdir(dir_str)

delFile_arr = filter(x -> !(occursin("set", x) || occursin("1982", x) || occursin("1983", x)), allFile_arr)

# delete filtered files
for file_str in delFile_arr
    rm(dir_str * file_str)
end


for file_str in allFile_arr
    data_df = CSV.read(dir_str * file_str, DataFrame)
    if !("value" in names(data_df))
        println(file_str)
    end
end