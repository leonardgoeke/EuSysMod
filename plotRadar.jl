

label_dic =Dict("h2Grid" => "H2 grid","powerGrid" => "power grid","ocgt" => "H2 turbine","solar" => "PV","wind" => "wind")

# ! get relevant data

resDataFut_df = CSV.read(b * "results/169future_resData.csv",DataFrame)
resDataHis_df = CSV.read(b * "results/169historic_resData.csv",DataFrame)

resDataFut_df[!,:data] .= "future"
resDataHis_df[!,:data] .= "historic"

resData_df = vcat(resDataFut_df,resDataHis_df)

maxVal_dic = Dict(x[1,:variable] => split(string(round(maximum(x[!,:value]),digits = 0)),".")[1] * " GW" for x in groupby(resData_df,[:variable]))

# normalize each category to maximum value
nomResAll_df = combine(x -> (data = x.data, case = x.case, variable = x.variable, value = x.value ./ maximum(x.value) ), groupby(resData_df,[:variable]))

# ! compute radar plot for future
for z in [("future",(0.761,0.804,0.957),(0.404,0.510,0.894),0.25),("historic",(0.761,0.804,0.957),(0.404,0.510,0.894),0.25)]

    nomRes_df = filter(x -> x.data == z[1], nomResAll_df)
    sort!(nomRes_df,:variable)

    # get values of stochastic model
    relData_df = filter(x -> x.case in (:all,"all"), nomRes_df)
    ref_arr = relData_df[!,:value]
    labels_arr = map(x -> label_dic[x], relData_df[!,:variable])
    maxValStr_arr = map(x -> maxVal_dic[x], relData_df[!,:variable])

    # initialize radar plot
    fig = Figure()
    ax = Axis(fig[1,1])

    for specScr in unique(filter(x -> !(x in (:all,"all")), nomRes_df[!,:case]))
        val_arr = filter(x -> x.case == specScr, nomRes_df)[!,:value]
        radarplot(ax, val_arr; labels = "", p_grid = 0, spokeswidth = 0, points = false, col = z[2], fillalpha = z[4], linewidth=0.0)
    end

    
    radarplot(ax, ref_arr; labels=labels_arr, maxValStr = maxValStr_arr, col = z[3], p_grid=0.2:0.2:1.0, spokeswidth = 0, labelsize=0.1,  title="", points = false, fillalpha = 0.0, linewidth=2.0)
    
    save(b * "results/radarplot_" * z[1] * ".png",fig)
end