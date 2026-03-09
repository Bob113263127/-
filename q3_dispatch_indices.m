function [idx_ch, idx_dis, idx_e, n] = q3_dispatch_indices(T)
n = 3 * T; idx_ch = 1:T; idx_dis = T+1:2*T; idx_e = 2*T+1:3*T;
end
