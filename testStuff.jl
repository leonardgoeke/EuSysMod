anyM = benders_obj.sub[(3,1)]
# ! debug

set_optimizer_attribute(anyM.optModel, "Method", 0)
set_optimizer_attribute(anyM.optModel, "Crossover", 0)
set_optimizer_attribute(anyM.optModel, "BarOrder", 0)
set_optimizer_attribute(anyM.optModel, "NumericFocus", 0)

optimize!(anyM.optModel)

# computes iis
compute_conflict!(anyM.optModel)

if MOI.get(anyM.optModel, MOI.ConflictStatus()) != MOI.ConflictStatusCode(3) return end
# loops over constraint tables to find constraints within iis
allCns_pair = vcat(collect.(vcat(anyM.parts.obj.cns, anyM.parts.bal.cns, anyM.parts.cost.cns, anyM.parts.lim.cns, map(x -> x.cns, values(anyM.parts.exc))..., map(x -> x.cns, values(anyM.parts.tech))...))...)

for cns in allCns_pair
	if cns[1] == :objEqn continue end

	allConstr_arr = findall(map(x -> MOI.ConflictParticipationStatusCode(0) != MOI.get(anyM.optModel.moi_backend, MOI.ConstraintConflictStatus(), x.index), cns[2][!,:cns]))
	# prints constraints within iis
	if !isempty(allConstr_arr)
		println("$(length(allConstr_arr)) of IIS in $(cns[1]) constraints.")
		colSet_dic = Dict(x => Symbol(split(string(x), "_")[1]) for x in intCol(cns[2]))
		for iisConstr in allConstr_arr
			row = cns[2][iisConstr,:]
			dimStr_arr = map(x -> row[x] == 0 ?  "" : x == :id ? string(row[x]) : string(x, ": ", join(getUniName(row[x], anyM.sets[colSet_dic[x]]), " < ")), collect(keys(colSet_dic)))
			println("$(join(filter(x -> x != "", dimStr_arr), ", ")), constraint: $(row[:cns])")
		end
	end
end

import AnyMOD.getUniName


benders_obj.top.parts.tech[:oilBoilerProHigh].cns[:mustCapaConvEq]
benders_obj.top.parts.tech[:oilBoilerProHigh].cns[:capaConv]
benders_obj.top.parts.tech[:oilBoilerProHigh].cns[:mustExpConv]

resData_obj, stabVar_obj = runTop(benders_obj)

resData_obj.capa[:tech][:oilBoilerProHigh][:capaConv]
resData_obj.capa[:tech][:oilBoilerProHigh][:mustCapaConv]

stab_obj = benders_obj.stab
delete(benders_obj.top.optModel, stab_obj.cns)
# double radius of trust-region and enforce again
stab_obj.dynPar[stab_obj.actMet] = max(stab_obj.methodOpt[stab_obj.actMet].low, stab_obj.dynPar[stab_obj.actMet] * stab_obj.methodOpt[stab_obj.actMet].fac)
centerStab!(stab_obj.method[stab_obj.actMet], stab_obj, benders_obj.algOpt.rngVio.stab, benders_obj.top, benders_obj.report.mod)