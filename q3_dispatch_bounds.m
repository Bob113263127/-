function [f, lb, ub] = q3_dispatch_bounds(n, idx_ch, idx_dis, idx_e, gridPriceVec, dt, Pmax_kW, Emax_kWh, data)
f = zeros(n,1); f(idx_ch) = gridPriceVec * dt; f(idx_dis) = -gridPriceVec * dt;
lb = zeros(n,1); ub = inf(n,1); ub(idx_ch) = Pmax_kW; ub(idx_dis) = Pmax_kW;
Emin = data.storage.soc_min * Emax_kWh; Emax = data.storage.soc_max * Emax_kWh;
lb(idx_e) = Emin; ub(idx_e) = Emax;
end
