function result = q3_optimize_storage(data, opt)
%Q3_OPTIMIZE_STORAGE Q3 storage sizing with ACO + dispatch optimization.
%
% Outer optimization: ant colony optimization (ACO) for storage size (P,E).
% Inner optimization: linprog hourly dispatch; fallback to rule-based dispatch.

if nargin < 1 || isempty(data)
    warning('q3_optimize_storage:autoDemo', 'No data provided, running run_q3_example().');
    result = run_q3_example();
    return;
end
if nargin < 2 || ~isstruct(opt)
    opt = struct();
end

opt = fill_default_opt(opt);
validate_data(data);
data = sanitize_data(data);
data = fill_default_data(data);

nZone = numel(data.load_kW);
result = struct();
result.zone = repmat(struct(), nZone, 1);

for i = 1:nZone
    zone.name = zone_name(i);
    zone.load = data.load_kW{i}(:);
    zone.wind = data.wind_avail_kW{i}(:);
    zone.solar = data.solar_avail_kW{i}(:);

    base = evaluate_config(zone, data, opt.baseP_kW, opt.baseE_kWh);

    if strcmpi(opt.method, 'aco')
        best = search_best_config_aco(zone, data, opt);
    else
        best = search_best_config_grid(zone, data, opt);
    end

    improve.annual_cost_drop = base.annual_cost - best.annual_cost;
    improve.cost_drop_pct = improve.annual_cost_drop / max(base.annual_cost, eps);
    improve.annual_grid_energy_drop_kWh = base.annual_grid_energy_kWh - best.annual_grid_energy_kWh;
    improve.annual_curtail_drop_kWh = base.annual_curtail_energy_kWh - best.annual_curtail_energy_kWh;

    result.zone(i).name = zone.name;
    result.zone(i).base = base;
    result.zone(i).best = best;
    result.zone(i).improve = improve;
end

result.summary = build_summary(result.zone);
end

function best = search_best_config_aco(zone, data, opt)
Pset = opt.search.P_kW(:)';
Eset = opt.search.E_kWh(:)';

if isempty(Pset) || isempty(Eset)
    error('ACO candidate set is empty: check opt.search.P_kW / opt.search.E_kWh');
end

nP = numel(Pset);
nE = numel(Eset);

tauP = ones(1, nP);
tauE = ones(1, nE);
etaP = 1 ./ (1 + Pset);
etaE = 1 ./ (1 + Eset);

globalBest = [];
cache = containers.Map('KeyType', 'char', 'ValueType', 'any');

for it = 1:opt.aco.iterMax
    antRes = repmat(struct('idxP', 1, 'idxE', 1, 'cfg', []), opt.aco.nAnt, 1);

    for k = 1:opt.aco.nAnt
        idxP = sample_index((tauP .^ opt.aco.alpha) .* (etaP .^ opt.aco.beta));
        idxE = sample_index((tauE .^ opt.aco.alpha) .* (etaE .^ opt.aco.beta));

        P = Pset(idxP);
        E = Eset(idxE);

        if ~is_feasible_pair(P, E, opt)
            cfg = make_penalty_cfg(P, E);
        else
            key = sprintf('%.6f_%.6f', P, E);
            if isKey(cache, key)
                cfg = cache(key);
            else
                cfg = evaluate_config(zone, data, P, E);
                cache(key) = cfg;
            end
        end

        antRes(k).idxP = idxP;
        antRes(k).idxE = idxE;
        antRes(k).cfg = cfg;

        if isempty(globalBest) || cfg.annual_cost < globalBest.annual_cost
            globalBest = cfg;
        end
    end

    tauP = (1 - opt.aco.rho) .* tauP;
    tauE = (1 - opt.aco.rho) .* tauE;

    costs = zeros(opt.aco.nAnt, 1);
    for k = 1:opt.aco.nAnt
        costs(k) = antRes(k).cfg.annual_cost;
    end

    [~, order] = sort(costs, 'ascend');
    eliteN = max(1, round(opt.aco.eliteRatio * opt.aco.nAnt));

    for j = 1:eliteN
        k = order(j);
        delta = opt.aco.Q / max(antRes(k).cfg.annual_cost, 1);
        tauP(antRes(k).idxP) = tauP(antRes(k).idxP) + delta;
        tauE(antRes(k).idxE) = tauE(antRes(k).idxE) + delta;
    end

    [idxPg, idxEg] = find_index(Pset, Eset, globalBest.P_kW, globalBest.E_kWh);
    if idxPg > 0 && idxEg > 0
        tauP(idxPg) = tauP(idxPg) + opt.aco.globalBoost;
        tauE(idxEg) = tauE(idxEg) + opt.aco.globalBoost;
    end
end

best = globalBest;
if isempty(best) || ~isfinite(best.annual_cost)
    best = search_best_config_grid(zone, data, opt);
end
end

function best = search_best_config_grid(zone, data, opt)
best = [];
for P = opt.search.P_kW
    for E = opt.search.E_kWh
        if ~is_feasible_pair(P, E, opt)
            continue;
        end
        cfg = evaluate_config(zone, data, P, E);
        if isempty(best) || cfg.annual_cost < best.annual_cost
            best = cfg;
        end
    end
end

if isempty(best)
    best = make_penalty_cfg(0, 0);
end
end

function tf = is_feasible_pair(P, E, opt)
if P == 0 && E == 0
    tf = true;
    return;
end
if P <= 0 || E <= 0
    tf = false;
    return;
end
h = E / P;
tf = (h >= opt.minHours) && (h <= opt.maxHours);
end

function idx = sample_index(weights)
w = weights(:);
w(~isfinite(w) | w < 0) = 0;
s = sum(w);
if s <= 0
    idx = randi(numel(w));
    return;
end
p = w / s;
c = cumsum(p);
r = rand();
idx = find(c >= r, 1, 'first');
if isempty(idx)
    idx = numel(w);
end
end

function [idxP, idxE] = find_index(Pset, Eset, P, E)
idxP = find(abs(Pset - P) < 1e-9, 1, 'first');
idxE = find(abs(Eset - E) < 1e-9, 1, 'first');
if isempty(idxP)
    idxP = -1;
end
if isempty(idxE)
    idxE = -1;
end
end

function cfg = make_penalty_cfg(P, E)
cfg = struct();
cfg.P_kW = P;
cfg.E_kWh = E;
cfg.annual_capex = inf;
cfg.annual_energy_cost = inf;
cfg.annual_cost = inf;
cfg.annual_grid_energy_kWh = inf;
cfg.annual_curtail_energy_kWh = inf;
cfg.annual_wind_used_kWh = 0;
cfg.annual_solar_used_kWh = 0;
cfg.annual_charge_kWh = 0;
cfg.annual_discharge_kWh = 0;
cfg.sample_soc = [];
end

function m = evaluate_config(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load);
dt = data.dt_h;

if Pmax_kW == 0 || Emax_kWh == 0
    pch = zeros(T, 1);
    pdis = zeros(T, 1);
    e = zeros(T, 1);
    [flowDay, energyDay] = calc_energy_flow(zone, pch, pdis, dt);
    ann_capex = 0;
    soc = zeros(T, 1);
else
    [pch, pdis, e] = optimize_dispatch_lp(zone, data, Pmax_kW, Emax_kWh);
    [flowDay, energyDay] = calc_energy_flow(zone, pch, pdis, dt);
    ann_capex = annualized_capex(data, Pmax_kW, Emax_kWh);
    soc = e / Emax_kWh;
end

gridPriceVec = get_grid_price_vector(data, T);
gridCostDay = sum(flowDay.grid .* gridPriceVec) * dt;

k = data.days_per_year;
energyYear.grid_kWh = energyDay.grid_kWh * k;
energyYear.curtail_kWh = energyDay.curtail_kWh * k;
energyYear.wind_used_kWh = energyDay.wind_used_kWh * k;
energyYear.solar_used_kWh = energyDay.solar_used_kWh * k;
energyYear.charge_kWh = energyDay.charge_kWh * k;
energyYear.discharge_kWh = energyDay.discharge_kWh * k;

energy_cost = energyYear.wind_used_kWh * data.price.wind_yuan_kWh + ...
              energyYear.solar_used_kWh * data.price.solar_yuan_kWh + ...
              gridCostDay * k;

m = struct();
m.P_kW = Pmax_kW;
m.E_kWh = Emax_kWh;
m.annual_capex = ann_capex;
m.annual_energy_cost = energy_cost;
m.annual_cost = ann_capex + energy_cost;
m.annual_grid_energy_kWh = energyYear.grid_kWh;
m.annual_curtail_energy_kWh = energyYear.curtail_kWh;
m.annual_wind_used_kWh = energyYear.wind_used_kWh;
m.annual_solar_used_kWh = energyYear.solar_used_kWh;
m.annual_charge_kWh = energyYear.charge_kWh;
m.annual_discharge_kWh = energyYear.discharge_kWh;
m.sample_soc = soc;
end

function [pch, pdis, e] = optimize_dispatch_lp(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load);
dt = data.dt_h;
etaCh = data.storage.eta_ch;
etaDis = data.storage.eta_dis;

n = 3 * T;
idx_ch = 1:T;
idx_dis = T + 1:2 * T;
idx_e = 2 * T + 1:3 * T;

gridPriceVec = get_grid_price_vector(data, T);
f = zeros(n, 1);
f(idx_ch) = gridPriceVec * dt;
f(idx_dis) = -gridPriceVec * dt;

lb = zeros(n, 1);
ub = inf(n, 1);
ub(idx_ch) = Pmax_kW;
ub(idx_dis) = Pmax_kW;

Emin = data.storage.soc_min * Emax_kWh;
Emax = data.storage.soc_max * Emax_kWh;
lb(idx_e) = Emin;
ub(idx_e) = Emax;

Aeq = zeros(T + 2, n);
beq = zeros(T + 2, 1);
for t = 1:T
    Aeq(t, idx_e(t)) = 1;
    if t > 1
        Aeq(t, idx_e(t - 1)) = -1;
    end
    Aeq(t, idx_ch(t)) = -etaCh * dt;
    Aeq(t, idx_dis(t)) = (1 / etaDis) * dt;
end
Aeq(T + 1, idx_e(1)) = 1;
beq(T + 1) = data.storage.soc0 * Emax_kWh;
Aeq(T + 2, idx_e(T)) = 1;
beq(T + 2) = data.storage.soc0 * Emax_kWh;

A = zeros(2 * T, n);
b = zeros(2 * T, 1);
netLoad = zone.load - zone.wind - zone.solar;
for t = 1:T
    A(t, idx_dis(t)) = 1;
    A(t, idx_ch(t)) = -1;
    b(t) = netLoad(t);
end

renewSurplus = max(0, zone.wind + zone.solar - zone.load);
for t = 1:T
    A(T + t, idx_ch(t)) = 1;
    b(T + t) = renewSurplus(t);
end

if any(~isfinite(f)) || any(~isfinite(A(:))) || any(~isfinite(b)) || any(~isfinite(Aeq(:))) || any(~isfinite(beq)) || any(~isfinite(lb)) || any(~isfinite(ub))
    error('linprog input contains NaN/Inf; please check data.');
end

hasLinprog = (exist('linprog', 'file') == 2) || (exist('linprog', 'builtin') == 5);
if hasLinprog
    try
        if exist('optimoptions', 'file') == 2 || exist('optimoptions', 'builtin') == 5
            opts = optimoptions('linprog', 'Display', 'none');
            [x, ~, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, opts);
        else
            [x, ~, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub);
        end

        if exitflag > 0 && all(isfinite(x))
            pch = x(idx_ch);
            pdis = x(idx_dis);
            e = x(idx_e);
            return;
        end
        warning('linprog did not converge; switching to rule-based dispatch.');
    catch ME
        warning('q3_optimize_storage:linprogFallback', 'linprog failed, switching to rule-based dispatch: %s', ME.message);
    end
else
    warning('linprog not detected; switching to rule-based dispatch.');
end

[pch, pdis, e] = optimize_dispatch_rule_based(zone, data, Pmax_kW, Emax_kWh);
end

function [pch, pdis, e] = optimize_dispatch_rule_based(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load);
dt = data.dt_h;
etaCh = data.storage.eta_ch;
etaDis = data.storage.eta_dis;

Emin = data.storage.soc_min * Emax_kWh;
Emax = data.storage.soc_max * Emax_kWh;
e = zeros(T, 1);
pch = zeros(T, 1);
pdis = zeros(T, 1);
ePrev = data.storage.soc0 * Emax_kWh;

for t = 1:T
    surplus = max(0, zone.wind(t) + zone.solar(t) - zone.load(t));
    deficit = max(0, zone.load(t) - zone.wind(t) - zone.solar(t));

    maxChByPower = Pmax_kW;
    maxChByEnergy = max(0, (Emax - ePrev) / max(etaCh * dt, eps));
    pch(t) = min([surplus, maxChByPower, maxChByEnergy]);

    maxDisByPower = Pmax_kW;
    maxDisByEnergy = max(0, (ePrev - Emin) * etaDis / max(dt, eps));
    pdis(t) = min([deficit, maxDisByPower, maxDisByEnergy]);

    eNow = ePrev + etaCh * pch(t) * dt - (pdis(t) / max(etaDis, eps)) * dt;
    eNow = min(max(eNow, Emin), Emax);
    e(t) = eNow;
    ePrev = eNow;
end
end

function [flow, energy] = calc_energy_flow(zone, pch, pdis, dt)
net_after_storage = zone.load - zone.wind - zone.solar + pch - pdis;
grid = max(0, net_after_storage);
renew_used = zone.load + pch - pdis - grid;
renew_used = max(0, renew_used);
available = zone.wind + zone.solar;
curtail = max(0, available - renew_used);

ratio_w = zeros(size(available));
mask = available > 1e-9;
ratio_w(mask) = zone.wind(mask) ./ available(mask);
wind_used = renew_used .* ratio_w;
solar_used = renew_used - wind_used;

energy.grid_kWh = sum(grid) * dt;
energy.curtail_kWh = sum(curtail) * dt;
energy.wind_used_kWh = sum(wind_used) * dt;
energy.solar_used_kWh = sum(solar_used) * dt;
energy.charge_kWh = sum(pch) * dt;
energy.discharge_kWh = sum(pdis) * dt;

flow.grid = grid;
flow.curtail = curtail;
end

function c = annualized_capex(data, P_kW, E_kWh)
capex = P_kW * data.storage.capexP_yuan_kW + ...
        E_kWh * data.storage.capexE_yuan_kWh;
c = capex / data.storage.life_year;
end

function summary = build_summary(zones)
n = numel(zones);
name = strings(n, 1);
baseCost = zeros(n, 1);
bestCost = zeros(n, 1);
bestP = zeros(n, 1);
bestE = zeros(n, 1);
improvePct = zeros(n, 1);
for i = 1:n
    name(i) = zones(i).name;
    baseCost(i) = zones(i).base.annual_cost;
    bestCost(i) = zones(i).best.annual_cost;
    bestP(i) = zones(i).best.P_kW;
    bestE(i) = zones(i).best.E_kWh;
    improvePct(i) = zones(i).improve.cost_drop_pct * 100;
end
summary = table(name, baseCost, bestCost, bestP, bestE, improvePct, ...
    'VariableNames', {'zone', 'baseAnnualCost', 'bestAnnualCost', 'bestP_kW', 'bestE_kWh', 'costDropPct'});
end

function data = fill_default_data(data)
if ~isfield(data, 'days_per_year') || isempty(data.days_per_year)
    data.days_per_year = 365;
end
end

function validate_data(data)
required = {'dt_h', 'load_kW', 'wind_avail_kW', 'solar_avail_kW', 'price', 'storage'};
for i = 1:numel(required)
    if ~isfield(data, required{i})
        error('Missing field data.%s', required{i});
    end
end

n = numel(data.load_kW);
if numel(data.wind_avail_kW) ~= n || numel(data.solar_avail_kW) ~= n
    error('load/wind/solar zone counts are inconsistent');
end

for i = 1:n
    L = numel(data.load_kW{i});
    if numel(data.wind_avail_kW{i}) ~= L || numel(data.solar_avail_kW{i}) ~= L
        error('Zone %d has inconsistent load/wind/solar vector lengths', i);
    end
end

validateattributes(data.dt_h, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, mfilename, 'data.dt_h');
validate_scalar_field(data.price, 'wind_yuan_kWh', 'data.price.wind_yuan_kWh');
validate_scalar_field(data.price, 'solar_yuan_kWh', 'data.price.solar_yuan_kWh');
validate_price_field(data.price, 'grid_yuan_kWh', 'data.price.grid_yuan_kWh');

validate_scalar_field(data.storage, 'capexP_yuan_kW', 'data.storage.capexP_yuan_kW');
validate_scalar_field(data.storage, 'capexE_yuan_kWh', 'data.storage.capexE_yuan_kWh');
validate_scalar_field(data.storage, 'life_year', 'data.storage.life_year');
validate_scalar_field(data.storage, 'eta_ch', 'data.storage.eta_ch');
validate_scalar_field(data.storage, 'eta_dis', 'data.storage.eta_dis');
validate_scalar_field(data.storage, 'soc_min', 'data.storage.soc_min');
validate_scalar_field(data.storage, 'soc_max', 'data.storage.soc_max');
validate_scalar_field(data.storage, 'soc0', 'data.storage.soc0');

if data.storage.soc_min >= data.storage.soc_max
    error('storage.soc_min must be smaller than storage.soc_max');
end
if data.storage.soc0 < data.storage.soc_min || data.storage.soc0 > data.storage.soc_max
    error('storage.soc0 must be inside [soc_min, soc_max]');
end
if data.storage.eta_ch <= 0 || data.storage.eta_dis <= 0
    error('storage.eta_ch and storage.eta_dis must be positive');
end
end

function validate_scalar_field(S, fieldName, displayName)
if ~isfield(S, fieldName)
    error('Missing field %s', displayName);
end
v = S.(fieldName);
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
    error('Field %s must be a finite numeric scalar', displayName);
end
end

function validate_price_field(S, fieldName, displayName)
if ~isfield(S, fieldName)
    error('Missing field %s', displayName);
end
v = S.(fieldName);
if ~isnumeric(v) || isempty(v) || any(~isfinite(v(:))) || any(v(:) <= 0)
    error('Field %s must be positive finite numeric (scalar or vector)', displayName);
end
end

function data = sanitize_data(data)
for i = 1:numel(data.load_kW)
    data.load_kW{i} = sanitize_vector(data.load_kW{i}, sprintf('load_kW{%d}', i));
    data.wind_avail_kW{i} = sanitize_vector(data.wind_avail_kW{i}, sprintf('wind_avail_kW{%d}', i));
    data.solar_avail_kW{i} = sanitize_vector(data.solar_avail_kW{i}, sprintf('solar_avail_kW{%d}', i));
end
end

function x = sanitize_vector(x, name)
x = x(:);
if ~isnumeric(x)
    error('Field %s must be numeric vector', name);
end
bad = ~isfinite(x);
if any(bad)
    good = find(~bad);
    if isempty(good)
        error('Field %s is all NaN/Inf; cannot optimize', name);
    elseif numel(good) == 1
        x(bad) = x(good(1));
    else
        x(bad) = interp1(good, x(good), find(bad), 'linear', 'extrap');
    end
end
x(x < 0) = 0;
end

function gridPriceVec = get_grid_price_vector(data, T)
if isscalar(data.price.grid_yuan_kWh)
    gridPriceVec = data.price.grid_yuan_kWh * ones(T, 1);
else
    gridPriceVec = data.price.grid_yuan_kWh(:);
    if numel(gridPriceVec) ~= T
        error('data.price.grid_yuan_kWh vector length must equal T=%d', T);
    end
end
end

function opt = fill_default_opt(opt)
if ~isfield(opt, 'method'), opt.method = 'aco'; end
if ~isfield(opt, 'baseP_kW'), opt.baseP_kW = 50; end
if ~isfield(opt, 'baseE_kWh'), opt.baseE_kWh = 100; end
if ~isfield(opt, 'search'), opt.search = struct(); end
if ~isfield(opt.search, 'P_kW'), opt.search.P_kW = 0:5:200; end
if ~isfield(opt.search, 'E_kWh'), opt.search.E_kWh = 0:10:500; end
if ~isfield(opt, 'maxHours'), opt.maxHours = 8; end
if ~isfield(opt, 'minHours'), opt.minHours = 0.5; end
if ~isfield(opt, 'aco'), opt.aco = struct(); end
if ~isfield(opt.aco, 'nAnt'), opt.aco.nAnt = 24; end
if ~isfield(opt.aco, 'iterMax'), opt.aco.iterMax = 45; end
if ~isfield(opt.aco, 'alpha'), opt.aco.alpha = 1.0; end
if ~isfield(opt.aco, 'beta'), opt.aco.beta = 2.0; end
if ~isfield(opt.aco, 'rho'), opt.aco.rho = 0.25; end
if ~isfield(opt.aco, 'Q'), opt.aco.Q = 5e4; end
if ~isfield(opt.aco, 'eliteRatio'), opt.aco.eliteRatio = 0.25; end
if ~isfield(opt.aco, 'globalBoost'), opt.aco.globalBoost = 20; end
end

function n = zone_name(i)
n = sprintf('Zone-%d', i);
end
