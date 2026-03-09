function tf = q3_is_feasible_pair(P, E, opt)
if P == 0 && E == 0, tf = true; return; end
if P <= 0 || E <= 0, tf = false; return; end
h = E / P; tf = (h >= opt.minHours) && (h <= opt.maxHours);
end
