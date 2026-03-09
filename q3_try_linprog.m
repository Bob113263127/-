function [ok, pch, pdis, e] = q3_try_linprog(f, A, b, Aeq, beq, lb, ub, idx_ch, idx_dis, idx_e)
ok = false; pch = []; pdis = []; e = [];
try
    if exist('optimoptions', 'file') == 2 || exist('optimoptions', 'builtin') == 5
        opts = optimoptions('linprog', 'Display', 'none');
        [x, ~, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, opts);
    else
        [x, ~, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub);
    end
    if exitflag > 0 && all(isfinite(x))
        pch = x(idx_ch); pdis = x(idx_dis); e = x(idx_e); ok = true;
    end
catch
    ok = false;
end
end
