function [pch, pdis, e] = q3_optimize_dispatch_rule_based(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load); dt = data.dt_h; etaCh = data.storage.eta_ch; etaDis = data.storage.eta_dis;
Emin = data.storage.soc_min * Emax_kWh; Emax = data.storage.soc_max * Emax_kWh;
e = zeros(T,1); pch = zeros(T,1); pdis = zeros(T,1); ePrev = data.storage.soc0 * Emax_kWh;
for t = 1:T
    surplus = max(0, zone.wind(t) + zone.solar(t) - zone.load(t));
    deficit = max(0, zone.load(t) - zone.wind(t) - zone.solar(t));
    pch(t) = min([surplus, Pmax_kW, max(0, (Emax - ePrev) / max(etaCh * dt, eps))]);
    pdis(t) = min([deficit, Pmax_kW, max(0, (ePrev - Emin) * etaDis / max(dt, eps))]);
    eNow = ePrev + etaCh * pch(t) * dt - (pdis(t) / max(etaDis, eps)) * dt;
    e(t) = min(max(eNow, Emin), Emax); ePrev = e(t);
end
end
