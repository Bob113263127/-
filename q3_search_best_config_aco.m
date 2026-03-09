function best = q3_search_best_config_aco(zone, data, opt)
Pset = opt.search.P_kW(:)'; Eset = opt.search.E_kWh(:)';
if isempty(Pset) || isempty(Eset)
    error('ACO candidate set empty: check opt.search.P_kW / opt.search.E_kWh');
end

tauP = ones(1, numel(Pset)); tauE = ones(1, numel(Eset));
etaP = 1 ./ (1 + Pset); etaE = 1 ./ (1 + Eset);
globalBest = []; cache = containers.Map('KeyType','char','ValueType','any');

for it = 1:opt.aco.iterMax
    antRes = repmat(struct('idxP',1,'idxE',1,'cfg',[]), opt.aco.nAnt, 1);
    for k = 1:opt.aco.nAnt
        idxP = q3_sample_index((tauP.^opt.aco.alpha).*(etaP.^opt.aco.beta));
        idxE = q3_sample_index((tauE.^opt.aco.alpha).*(etaE.^opt.aco.beta));
        P = Pset(idxP); E = Eset(idxE);
        if ~q3_is_feasible_pair(P, E, opt)
            cfg = q3_make_penalty_cfg(P, E);
        else
            key = sprintf('%.6f_%.6f', P, E);
            if isKey(cache, key), cfg = cache(key);
            else, cfg = q3_evaluate_config(zone, data, P, E); cache(key) = cfg; end
        end
        antRes(k).idxP = idxP; antRes(k).idxE = idxE; antRes(k).cfg = cfg;
        if isempty(globalBest) || cfg.annual_cost < globalBest.annual_cost, globalBest = cfg; end
    end
    [tauP, tauE] = q3_update_pheromone(tauP, tauE, antRes, opt, Pset, Eset, globalBest);
end
best = globalBest;
if isempty(best) || ~isfinite(best.annual_cost)
    best = q3_search_best_config_grid(zone, data, opt);
end
end
