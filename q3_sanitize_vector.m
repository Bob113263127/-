function x = q3_sanitize_vector(x, name)
x = x(:);
if ~isnumeric(x), error('Field %s must be numeric vector', name); end
bad = ~isfinite(x);
if any(bad)
    good = find(~bad);
    if isempty(good)
        error('Field %s is all NaN/Inf', name);
    elseif numel(good) == 1
        x(bad) = x(good(1));
    else
        x(bad) = interp1(good, x(good), find(bad), 'linear', 'extrap');
    end
end
x(x < 0) = 0;
end
