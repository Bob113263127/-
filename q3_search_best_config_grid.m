function best = q3_search_best_config_grid(zone, data, opt)
best = [];
for P = opt.search.P_kW
    for E = opt.search.E_kWh
        if ~q3_is_feasible_pair(P, E, opt), continue; end
        cfg = q3_evaluate_config(zone, data, P, E);
        if isempty(best) || cfg.annual_cost < best.annual_cost, best = cfg; end
    end
end
if isempty(best), best = q3_make_penalty_cfg(0, 0); end
end
