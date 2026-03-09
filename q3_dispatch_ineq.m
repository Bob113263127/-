function [A, b] = q3_dispatch_ineq(zone, T, n, idx_ch, idx_dis)
A = zeros(2*T, n); b = zeros(2*T,1);
netLoad = zone.load - zone.wind - zone.solar;
for t = 1:T
    A(t, idx_dis(t)) = 1; A(t, idx_ch(t)) = -1; b(t) = netLoad(t);
end
renewSurplus = max(0, zone.wind + zone.solar - zone.load);
for t = 1:T
    A(T+t, idx_ch(t)) = 1; b(T+t) = renewSurplus(t);
end
end
