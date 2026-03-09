function [pch, pdis, e] = q3_optimize_dispatch_lp(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load); dt = data.dt_h; etaCh = data.storage.eta_ch; etaDis = data.storage.eta_dis;
[idx_ch, idx_dis, idx_e, n] = q3_dispatch_indices(T);
gridPriceVec = q3_get_grid_price_vector(data, T);
[f, lb, ub] = q3_dispatch_bounds(n, idx_ch, idx_dis, idx_e, gridPriceVec, dt, Pmax_kW, Emax_kWh, data);
[Aeq, beq] = q3_dispatch_eq(T, n, idx_ch, idx_dis, idx_e, etaCh, etaDis, dt, data, Emax_kWh);
[A, b] = q3_dispatch_ineq(zone, T, n, idx_ch, idx_dis);
q3_assert_finite_lp(f, A, b, Aeq, beq, lb, ub);

if q3_has_linprog()
    [ok, pch, pdis, e] = q3_try_linprog(f, A, b, Aeq, beq, lb, ub, idx_ch, idx_dis, idx_e);
    if ok, return; end
    q3_emit_warning(data, 'linprog did not converge; switching to rule-based dispatch.');
else
    q3_emit_warning(data, 'linprog not detected; switching to rule-based dispatch.');
end
[pch, pdis, e] = q3_optimize_dispatch_rule_based(zone, data, Pmax_kW, Emax_kWh);
end
