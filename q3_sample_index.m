function idx = q3_sample_index(weights)
w = weights(:); w(~isfinite(w) | w < 0) = 0; s = sum(w);
if s <= 0, idx = randi(numel(w)); return; end
c = cumsum(w / s); idx = find(c >= rand(), 1, 'first');
if isempty(idx), idx = numel(w); end
end
