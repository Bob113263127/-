function q3_validate_price(S, fieldName, displayName)
if ~isfield(S, fieldName), error('Missing field %s', displayName); end
v = S.(fieldName);
if ~isnumeric(v) || isempty(v) || any(~isfinite(v(:))) || any(v(:) <= 0)
    error('Field %s must be positive finite numeric (scalar/vector)', displayName);
end
end
