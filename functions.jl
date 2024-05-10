# write storage levels
function writeStLvl(tSym_arr::Array{Symbol,1},anyM::anyModel)
    lvl_df = DataFrame(Ts_dis = Int[], Te = Int[], scr = Int[],  value  = Float64[])
    for tSym in tSym_arr
        stLvl_df = combine(x -> (value = sum(value.(x.var)),), groupby(anyM.parts.tech[tSym].var[:stLvl],[:Ts_dis,:Te,:scr]))
        append!(lvl_df,stLvl_df)
    end
    return lvl_df
end

# write dual values
function writeDuals(relBal_ntup::NamedTuple,anyM::anyModel)
    
    allDual_df = DataFrame(Ts_dis = Int[], scr = Int[],  bal  = String[], cat = String[], value = Float64[])
    # add dual for energy balance
    for x in keys(anyM.parts.bal.cns)
        car_str = lowercase(replace(string(x),"enBal" => ""))
        if Symbol(car_str) in relBal_ntup.enBal
            cns_df = copy(anyM.parts.bal.cns[x])
            cns_df[!,:dual] = dual.(cns_df[!,:cns])
            cns_df = combine(x -> (value = sum(x.dual),),groupby(cns_df,[:Ts_dis,:scr]))
            cns_df[!,:bal] .= "enBal"
            cns_df[!,:cat] .= car_str
            append!(allDual_df,cns_df)
        end
    end

    # add dual for storage balance
    for x in keys(anyM.parts.tech)
        if x in relBal_ntup.stBal && :stBal in keys(anyM.parts.tech[x].cns)
            cns_df = copy(anyM.parts.tech[x].cns[:stBal])
            cns_df[!,:dual] = dual.(cns_df[!,:cns])
            cns_df = combine(x -> (value = sum(x.dual),),groupby(cns_df,[:Ts_dis,:scr]))
            cns_df[!,:bal] .= "stBal"
            cns_df[!,:cat] .= string(x)
            append!(allDual_df,cns_df)
        end
    end

    # add dual for exchange restriction
    for x in keys(anyM.parts.exc)
        if x in relBal_ntup.excRestr && :excRestr in keys(anyM.parts.exc[x].cns)
            cns_df = copy(anyM.parts.exc[x].cns[:excRestr])
            cns_df[!,:dual] = dual.(cns_df[!,:cns])
            cns_df = combine(x -> (value = sum(x.dual),),groupby(cns_df,[:Ts_dis,:scr]))
            cns_df[!,:bal] .= "excRestr"
            cns_df[!,:cat] .= string(x)
            append!(allDual_df,cns_df)
        end
    end

    return allDual_df
end

# write aggregated results for radar plot
function getAggRes(anyM::anyModel, nameCol_sym::Symbol)
    conv_dic = Dict("wind" => 1.0,"solar" => 1.0,"ocgt" => 0.415)
    grid_arr = ("h2grid","powerGrid") 

    # filter conversion capacities
    sum_df = reportResults(:summary, anyM, rtnOpt = (:csvDf,))
    sum_df[!,:technology] .= replace.(getindex.(split.(sum_df[!,:technology],"<"),1)," " => "")

    # aggergate and correct capacities
    conv_df = combine(x -> (value = sum(x.value),),groupby(filter!(x -> x.variable == :capaConv && x.technology in collect(keys(conv_dic)), sum_df),[:technology]))
    conv_df[!,:value] .= map(x -> conv_dic[x.technology] * x.value, eachrow(conv_df))

    # filter grid capacities
    exc_df = filter(x -> x.variable == :expExc, reportResults(:exchange, anyM, rtnOpt = (:csvDf,)))
    exc_df[!,:exchange] .= replace.(getindex.(split.(exc_df[!,:exchange],"<"),1)," " => "")
    exc_df = combine(x -> (value = sum(x.value),),groupby(exc_df,[:exchange]))

    allRes_df = vcat(rename(conv_df,:technology => :variable),rename(exc_df,:exchange => :variable))
    allRes_df[!,:case] .= nameCol_sym

    return allRes_df
end

# function for radar plot (from https://discourse.julialang.org/t/radar-plot-in-plots-jl-or-makie-jl/88576/7)
function radarplot(ax::Axis, v; p_grid = maximum(v) * (1.0:5.0) / 5.0, title = "", labels = eachindex(v), labelsize = 14, legendsize = 12, points=true, maxValStr = String[], col = (0.4,0.4,0.4),spokeswidth= 1.5, spokescolor=:salmon, fillalpha=0.2, linewidth=1.5)
    # horizintal and vertical text alignment:
    justifyme(θ) = (0≤θ<π/2 || 3π/2<θ≤2π) ? :left : (π/2<θ<3π/2) ? :right : :center
    justifymeV(θ) = π/4≤θ≤3π/4 ? :bottom : 5π/4<θ≤7π/4 ? :top : :center
        
    # Axis attributes
    ax.xgridvisible = false
    ax.ygridvisible = false
    ax.xminorgridvisible = false
    ax.yminorgridvisible = false
    ax.leftspinevisible = false
    ax.rightspinevisible = false
    ax.bottomspinevisible = false
    ax.topspinevisible = false
    ax.xminorticksvisible = false
    ax.yminorticksvisible = false
    ax.xticksvisible = false
    ax.yticksvisible = false
    ax.xticklabelsvisible = false
    ax.yticklabelsvisible = false
    ax.aspect = DataAspect()
    ax.title = title
    #
    l = length(v)
    rad = (0:(l-1)) * 2π / l
    # Point coordinates
    x = v .* cos.(rad)
    y = v .* sin.(rad)
    if p_grid != 0
        # Coordinates for radial grid
        xa = maximum(p_grid) * cos.(rad) * 1.1
        ya = maximum(p_grid) * sin.(rad) * 1.1
        # Coordinates for polar grid text
        radC = (rad[Int(round(l / 2))] + rad[1 + Int(round(l / 2))]) / 2.0
        xc = p_grid * cos(radC)
        yc = p_grid * sin(radC)
        for i in p_grid
            poly!(ax, Circle(Point2f(0, 0), i), color = :transparent, strokewidth=1, strokecolor=ax.xgridcolor)
        end
        if !isempty(maxValStr)
            for i in eachindex(rad)
                println((cos(rad[i]),sin(rad[i]),labels[i]))
                text!(ax, cos(rad[i]), sin(rad[i]), text= maxValStr[i], fontsize = legendsize, align = (cos(rad[i]) > 0 ? :right : :left, :bottom), color=ax.xlabelcolor)
            end
        end
        arrows!(ax, zeros(l), zeros(l), xa, ya, color=ax.xgridcolor, linestyle=:solid, arrowhead=' ')
        if length(labels) == l
            for i in eachindex(rad)
                text!(ax, xa[i], ya[i], text=string(labels[i]), fontsize = labelsize, markerspace = :data, align = (justifyme(rad[i]), justifymeV(rad[i])), color=ax.xlabelcolor)
            end
        elseif length(labels) > 1
            printstyled("WARNING! Labels omitted:  they don't match with the points ($(length(labels)) vs $l).\n", bold=true, color=:yellow)
        end
    end
    pp = poly!(ax, [(x[i], y[i]) for i in eachindex(x)], strokecolor=RGB{Float32}(col[1], col[2], col[3]))
    cc = to_value(pp.color)
    m_color = RGBA{Float32}(col[1], col[2], col[3], fillalpha)
    s_color = RGB{Float32}(col[1], col[2], col[3])
    pp.color = m_color
    pp.strokecolor = s_color
    pp.strokewidth= linewidth
    arrows!(ax, zeros(l), zeros(l), x, y, color=spokescolor, linewidth=spokeswidth, arrowhead=' ')
    if points
        scatter!(ax, x, y)
    end
    ax
end

#=
# get results
reportResults(:summary, anyM, expVal = true)
reportResults(:cost, anyM)
reportResults(:exchange, anyM, expVal = true)
plotSankeyDiagram(anyM, dropDown = (:timestep, :scenario))

# return storage levels
lvl_df = writeStLvl([:h2Cavern,:reservoir,:pumpedStorage,:redoxBattery,:lithiumBattery],anyM)
printObject(lvl_df,anyM,fileName = "stLvl")

# write duals
relBal_ntup = (enBal = (:electricity,), stBal = (:h2Cavern,:reservoir), excRestr = (:hvac,:hvdc))
dual_df = writeDuals(relBal_ntup,anyM)
printObject(dual_df,anyM,fileName = "dual")
=#