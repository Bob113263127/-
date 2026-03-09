function q3_emit_warning(data, msg)
if ~isfield(data, 'warn') || ~isstruct(data.warn), return; end
if ~isfield(data.warn, 'enable') || ~data.warn.enable, return; end
persistent warningCache;
if isempty(warningCache)
    warningCache = containers.Map('KeyType', 'char', 'ValueType', 'double');
end
if ~isfield(data.warn, 'once') || ~data.warn.once
    warning('q3_optimize_storage:dispatchFallback', '%s', msg); return;
end
if ~isKey(warningCache, msg)
    warningCache(msg) = 1; warning('q3_optimize_storage:dispatchFallback', '%s', msg);
end
end
