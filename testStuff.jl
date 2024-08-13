


#region # * checks and initialization

benders_obj = bendersObj()
benders_obj.info = info_ntup
benders_obj.algOpt = algSetup_obj
benders_obj.nearOpt = nearOptObj(0, nearOptSetup_obj)

#endregion

#region # * initialize reporting

# dataframe for reporting during iteration
itrReport_df = DataFrame(i = Int[], lowCost = Float64[], bestObj = Float64[], gap = Float64[], curCost = Float64[], time_ges = Float64[], time_top = Float64[], time_subTot = Float64[], time_sub = Array{Float64,1}[], numFoc = Array{Int,1}[], objName = String[])
nearOpt_df = DataFrame(i = Int[], timestep = String[], region = String[], system = String[], id = String[], variable = Symbol[], value = Float64[], objName = String[])

# empty model just for reporting
report_m = @suppress anyModel(String[], inputFolder_ntup.results, objName = "decomposition" * info_ntup.name) 

# add column for active stabilization method
if !isempty(stabSetup_obj.method)
	itrReport_df[!,:actMethod] = fill(Symbol(), size(itrReport_df, 1))
	foreach(x -> itrReport_df[!,Symbol("dynPar_", x[1])] = Union{Float64,Vector{Float64}}[fill(Float64[], size(itrReport_df, 1))...], stabSetup_obj.method)
	select!(itrReport_df, vcat(filter(x -> x != :objName, namesSym(itrReport_df)), [:objName]))
end

# extend reporting dataframe in case of near-optimal
if !isnothing(nearOptSetup_obj) itrReport_df[!,:objective] = fill("", size(itrReport_df, 1)) end

benders_obj.report = (itr = itrReport_df, nearOpt = nearOpt_df, mod = report_m)
	



top_m = anyModel(inputFolder_ntup.in, inputFolder_ntup.results, objName = "topModel_" * info_ntup.name, checkRng = (print = true, all = false), frsLvl = info_ntup.frsLvl, supTsLvl = info_ntup.supTsLvl, repTsLvl = info_ntup.repTsLvl, shortExp = info_ntup.shortExp, coefRng = scale_dic[:rng], scaFac = scale_dic[:facTop], reportLvl = 1, createVI = algSetup_obj.useVI)
top_m.subPro = tuple(0, 0)
@suppress prepareMod!(top_m, benders_obj.algOpt.opt, benders_obj.algOpt.threads)

optimize!(top_m.optModel)