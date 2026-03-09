function tf = q3_has_linprog()
tf = (exist('linprog', 'file') == 2) || (exist('linprog', 'builtin') == 5);
end
