function q3_assert_finite_lp(f, A, b, Aeq, beq, lb, ub)
if any(~isfinite(f)) || any(~isfinite(A(:))) || any(~isfinite(b)) || ...
   any(~isfinite(Aeq(:))) || any(~isfinite(beq)) || any(~isfinite(lb)) || any(~isfinite(ub))
    error('linprog input contains NaN/Inf; please check data.');
end
end
