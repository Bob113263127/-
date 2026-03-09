function q3_validate_scalar(S, fieldName, displayName)
if ~isfield(S, fieldName), error('Missing field %s', displayName); end
v = S.(fieldName);
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
    error('Field %s must be finite numeric scalar', displayName);
end
end
