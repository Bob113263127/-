function [Aeq, beq] = q3_dispatch_eq(T, n, idx_ch, idx_dis, idx_e, etaCh, etaDis, dt, data, Emax_kWh)
Aeq = zeros(T+2, n); beq = zeros(T+2,1);
for t = 1:T
    Aeq(t, idx_e(t)) = 1;
    if t > 1, Aeq(t, idx_e(t-1)) = -1; end
    Aeq(t, idx_ch(t)) = -etaCh * dt; Aeq(t, idx_dis(t)) = (1/etaDis) * dt;
end
Aeq(T+1, idx_e(1)) = 1; beq(T+1) = data.storage.soc0 * Emax_kWh;
Aeq(T+2, idx_e(T)) = 1; beq(T+2) = data.storage.soc0 * Emax_kWh;
end
