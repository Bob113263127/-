function result = run_q3_example()
%RUN_Q3_EXAMPLE 使用内置模拟数据运行第三问优化（不读取Excel）。
% 调用方式：result = run_q3_example();

clc;

% 题面装机参数（kW）
cap.A.pv = 750; cap.A.wind = 0;
cap.B.pv = 0;   cap.B.wind = 1000;
cap.C.pv = 600; cap.C.wind = 500;

% ==== 1) 生成可运行的模拟数据 ====
data = make_synthetic_data(cap);
fprintf('使用内置模拟数据运行（不依赖附件）。\n');

% ==== 2) 算法参数 ====
opt = struct();
opt.method = 'aco';
opt.baseP_kW = 50;
opt.baseE_kWh = 100;
opt.search.P_kW = 0:10:250;
opt.search.E_kWh = 0:20:800;
opt.minHours = 0.5;
opt.maxHours = 10;
opt.aco.nAnt = 28;
opt.aco.iterMax = 50;
opt.aco.alpha = 1.0;
opt.aco.beta = 2.0;
opt.aco.rho = 0.25;
opt.aco.Q = 5e4;
opt.aco.eliteRatio = 0.25;
opt.aco.globalBoost = 20;

% ==== 3) 运行优化 ====
result = q3_optimize_storage(data, opt);

disp('===== 第三问汇总结果 =====');
disp(result.summary);

for i = 1:numel(result.zone)
    z = result.zone(i);
    fprintf('\n[%s]\n', z.name);
    fprintf('基线(50kW/100kWh)年总成本: %.2f 元\n', z.base.annual_cost);
    fprintf('最优方案: P=%.0f kW, E=%.0f kWh\n', z.best.P_kW, z.best.E_kWh);
    fprintf('最优年总成本: %.2f 元\n', z.best.annual_cost);
    fprintf('降本比例: %.2f%%\n', 100*z.improve.cost_drop_pct);
end

end

function data = make_synthetic_data(cap)
T = 24;
t = (0:T-1)';

% 负荷：早晚峰、白天谷（单位kW）
A_load = 500 + 120*sin(2*pi*(t-7)/24) + 60*(t>=18 & t<=22);
B_load = 620 + 140*sin(2*pi*(t-8)/24) + 70*(t>=19 & t<=23);
C_load = 700 + 160*sin(2*pi*(t-9)/24) + 90*(t>=18 & t<=23);

% 可再生归一化曲线：光伏白天出力、风电全天波动
solar_norm = max(0, sin(pi*(t-6)/12));
wind_norm = 0.45 + 0.2*sin(2*pi*(t+3)/24);
wind_norm = max(0, min(1, wind_norm));

Aw = wind_norm * cap.A.wind;  Ap = solar_norm * cap.A.pv;
Bw = wind_norm * cap.B.wind;  Bp = solar_norm * cap.B.pv;
Cw = wind_norm * cap.C.wind;  Cp = solar_norm * cap.C.pv;

data = struct();
data.dt_h = 1;
data.days_per_year = 365;
data.load_kW = {A_load(:), B_load(:), C_load(:)};
data.wind_avail_kW = {Aw(:), Bw(:), Cw(:)};
data.solar_avail_kW = {Ap(:), Bp(:), Cp(:)};

% 成本参数（可按题面再调）
data.price.wind_yuan_kWh = 0.5;
data.price.solar_yuan_kWh = 0.4;
data.price.grid_yuan_kWh = 1.0;

data.storage.capexP_yuan_kW = 800;
data.storage.capexE_yuan_kWh = 1800;
data.storage.life_year = 10;
data.storage.eta_ch = 0.95;
data.storage.eta_dis = 0.95;
data.storage.soc_min = 0.10;
data.storage.soc_max = 0.90;
data.storage.soc0 = 0.50;
end
