function result = q3_optimize_storage(data, opt)
%Q3_OPTIMIZE_STORAGE 电工杯A题第三问：储能功率/容量优化与50kW/100kWh基线对比
%
% 核心功能
% 1) 每个园区独立优化储能功率P与容量E；
% 2) 对比固定方案(50kW/100kWh)与最优方案；
% 3) 输出成本、购电、弃电等指标。
%
% 注意
% - 输入时序可为“典型日24点”；函数可通过 data.days_per_year 折算成年化电量与电费。
% - 成本目标：年化总成本 = 年化储能投资 + 年化购电成本。

if nargin < 2 || ~isstruct(opt), opt = struct(); end
opt = fill_default_opt(opt);
validate_data(data);

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
    best = search_best_config(zone, data, opt);

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

function best = search_best_config(zone, data, opt)
best = [];
for P = opt.search.P_kW
    for E = opt.search.E_kWh
        if P == 0 && E == 0
            cfg = evaluate_config(zone, data, P, E);
        else
            if P <= 0 || E <= 0
                continue;
            end
            h = E / P;
            if h < opt.minHours || h > opt.maxHours
                continue;
            end
            cfg = evaluate_config(zone, data, P, E);
        end

        if isempty(best) || cfg.annual_cost < best.annual_cost
            best = cfg;
        end
    end
end
end

function m = evaluate_config(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load);
dt = data.dt_h;

if Pmax_kW == 0 || Emax_kWh == 0
    pch = zeros(T,1); pdis = zeros(T,1); e = zeros(T,1);
    [~, energyDay] = calc_energy_flow(zone, pch, pdis, dt);
    ann_capex = 0;
    soc = zeros(T,1);
else
    [pch, pdis, e] = optimize_dispatch_lp(zone, data, Pmax_kW, Emax_kWh);
    [~, energyDay] = calc_energy_flow(zone, pch, pdis, dt);
    ann_capex = annualized_capex(data, Pmax_kW, Emax_kWh);
    soc = e / Emax_kWh;
end

% 典型日折算年值
k = data.days_per_year;
energyYear.grid_kWh = energyDay.grid_kWh * k;
energyYear.curtail_kWh = energyDay.curtail_kWh * k;
energyYear.wind_used_kWh = energyDay.wind_used_kWh * k;
energyYear.solar_used_kWh = energyDay.solar_used_kWh * k;
energyYear.charge_kWh = energyDay.charge_kWh * k;
energyYear.discharge_kWh = energyDay.discharge_kWh * k;

energy_cost = energyYear.wind_used_kWh * data.price.wind_yuan_kWh + ...
              energyYear.solar_used_kWh * data.price.solar_yuan_kWh + ...
              energyYear.grid_kWh * data.price.grid_yuan_kWh;

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

n = 3*T;
idx_ch = 1:T;
idx_dis = T+1:2*T;
idx_e = 2*T+1:3*T;

f = zeros(n,1);
f(idx_ch) = data.price.grid_yuan_kWh * dt;
f(idx_dis) = -data.price.grid_yuan_kWh * dt;

lb = zeros(n,1);
ub = inf(n,1);
ub(idx_ch) = Pmax_kW;
ub(idx_dis) = Pmax_kW;

Emin = data.storage.soc_min * Emax_kWh;
Emax = data.storage.soc_max * Emax_kWh;
lb(idx_e) = Emin;
ub(idx_e) = Emax;

Aeq = zeros(T+2, n);
beq = zeros(T+2, 1);
for t = 1:T
    Aeq(t, idx_e(t)) = 1;
    if t > 1
        Aeq(t, idx_e(t-1)) = -1;
    end
    Aeq(t, idx_ch(t)) = -etaCh * dt;
    Aeq(t, idx_dis(t)) = (1/etaDis) * dt;
end
Aeq(T+1, idx_e(1)) = 1;
beq(T+1) = data.storage.soc0 * Emax_kWh;
% 日循环约束：期末SOC回到初值，避免“偷放电”
Aeq(T+2, idx_e(T)) = 1;
beq(T+2) = data.storage.soc0 * Emax_kWh;

A = zeros(2*T, n);
b = zeros(2*T, 1);

% 主网功率 >=0: pdis - pch <= load - wind - solar
netLoad = zone.load - zone.wind - zone.solar;
for t = 1:T
    A(t, idx_dis(t)) = 1;
    A(t, idx_ch(t)) = -1;
    b(t) = netLoad(t);
end

% 充电只允许吃“富余可再生”：pch <= max(0, wind+solar-load)
renewSurplus = max(0, zone.wind + zone.solar - zone.load);
for t = 1:T
    A(T+t, idx_ch(t)) = 1;
    b(T+t) = renewSurplus(t);
end

opts = optimoptions('linprog', 'Display', 'none');
[x, ~, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, opts);
if exitflag <= 0
    error('linprog 未收敛，请检查数据与约束。');
end

pch = x(idx_ch);
pdis = x(idx_dis);
e = x(idx_e);
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
name = strings(n,1);
baseCost = zeros(n,1);
bestCost = zeros(n,1);
bestP = zeros(n,1);
bestE = zeros(n,1);
improvePct = zeros(n,1);
for i = 1:n
    name(i) = zones(i).name;
    baseCost(i) = zones(i).base.annual_cost;
    bestCost(i) = zones(i).best.annual_cost;
    bestP(i) = zones(i).best.P_kW;
    bestE(i) = zones(i).best.E_kWh;
    improvePct(i) = zones(i).improve.cost_drop_pct * 100;
end
summary = table(name, baseCost, bestCost, bestP, bestE, improvePct, ...
    'VariableNames', {'zone','baseAnnualCost','bestAnnualCost','bestP_kW','bestE_kWh','costDropPct'});
end

function data = fill_default_data(data)
if ~isfield(data, 'days_per_year') || isempty(data.days_per_year)
    data.days_per_year = 365;
end
end

function validate_data(data)
required = {'dt_h','load_kW','wind_avail_kW','solar_avail_kW','price','storage'};
for i = 1:numel(required)
    if ~isfield(data, required{i})
        error('缺少字段 data.%s', required{i});
    end
end
n = numel(data.load_kW);
if numel(data.wind_avail_kW) ~= n || numel(data.solar_avail_kW) ~= n
    error('load/wind/solar 的园区数量不一致');
end
for i = 1:n
    L = numel(data.load_kW{i});
    if numel(data.wind_avail_kW{i}) ~= L || numel(data.solar_avail_kW{i}) ~= L
        error('第%d个园区的负荷与风光序列长度不一致', i);
    end
end
end

function opt = fill_default_opt(opt)
if ~isfield(opt, 'baseP_kW'), opt.baseP_kW = 50; end
if ~isfield(opt, 'baseE_kWh'), opt.baseE_kWh = 100; end
if ~isfield(opt, 'search'), opt.search = struct(); end
if ~isfield(opt.search, 'P_kW'), opt.search.P_kW = 0:5:200; end
if ~isfield(opt.search, 'E_kWh'), opt.search.E_kWh = 0:10:500; end
if ~isfield(opt, 'maxHours'), opt.maxHours = 8; end
if ~isfield(opt, 'minHours'), opt.minHours = 0.5; end
end

function n = zone_name(i)
n = sprintf('Zone-%d', i);
end
