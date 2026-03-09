function [tauP, tauE] = q3_update_pheromone(tauP, tauE, antRes, opt, Pset, Eset, globalBest)
tauP = (1 - opt.aco.rho) .* tauP; tauE = (1 - opt.aco.rho) .* tauE;
costs = zeros(opt.aco.nAnt, 1);
for k = 1:opt.aco.nAnt, costs(k) = antRes(k).cfg.annual_cost; end
[~, order] = sort(costs, 'ascend');
eliteN = max(1, round(opt.aco.eliteRatio * opt.aco.nAnt));
for j = 1:eliteN
    k = order(j); delta = opt.aco.Q / max(antRes(k).cfg.annual_cost, 1);
    tauP(antRes(k).idxP) = tauP(antRes(k).idxP) + delta;
    tauE(antRes(k).idxE) = tauE(antRes(k).idxE) + delta;
end
[idxPg, idxEg] = q3_find_index(Pset, Eset, globalBest.P_kW, globalBest.E_kWh);
if idxPg > 0 && idxEg > 0
    tauP(idxPg) = tauP(idxPg) + opt.aco.globalBoost;
    tauE(idxEg) = tauE(idxEg) + opt.aco.globalBoost;
end
end
