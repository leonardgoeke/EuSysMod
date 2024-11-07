using CSV, DataFrames


dir_str = "C:/Users/pacop/Desktop/git/EuSysMOD/inputFiles/timeSeries/country_672h_month/"




# rename general folders
for i in 1:9
    mv(joinpath(dir_str,"general_ini" * string(i)),joinpath(dir_str,"general_ini0" * string(i)))
end

# rename scenario subfolders
for f in filter(x -> occursin("scr",x), readdir(dir_str))
    for i in 1:9
        mv(joinpath(dir_str,f,"ini" * string(i)), joinpath(dir_str,f,"ini0" * string(i)))
    end
end

# rename files
for f1 in filter(x -> occursin("scr",x), readdir(dir_str))
    for i in 1:9
        for f2 in readdir(joinpath(dir_str, f1, "ini0" * string(i)))
            f_str = joinpath(dir_str, f1, "ini0" * string(i),f2)
            mv(f_str,replace(f_str, "_ini" * string(i) * ".csv" => "_ini0" * string(i) * ".csv"))
        end
    end
end

# convert files for conversion
for f1 in filter(x -> occursin("scr", x), readdir(dir_str))
    for f2 in readdir(dir_str * f1)
        for t in ("chargingProfileBevFrtRoadHeavy", "chargingProfileBevFrtRoadLight", "chargingProfileBevPsngRoadPrvt","chargingProfileBevPsngRoadPub")
            dirLocal_str = dir_str * f1 * "/" * f2 * "/par_" * t * "_" * f1 * "_" * f2 * ".csv"
            data_df = CSV.read(dirLocal_str, DataFrame)
            data_df[!,:parameter] .= "avaConv"
            CSV.write(dirLocal_str, data_df)
        end
    end
end