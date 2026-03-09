function [idxP, idxE] = q3_find_index(Pset, Eset, P, E)
idxP = find(abs(Pset - P) < 1e-9, 1, 'first');
idxE = find(abs(Eset - E) < 1e-9, 1, 'first');
if isempty(idxP), idxP = -1; end
if isempty(idxE), idxE = -1; end
end
