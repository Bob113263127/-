function result = run_q3_example()
% RUN_Q3_EXAMPLE Run Q3 storage optimization with built-in 24h data.

clc;

% Installed capacities (kW)
cap.A.pv = 750; cap.A.wind = 0;
cap.B.pv = 0;   cap.B.wind = 1000;
cap.C.pv = 600; cap.C.wind = 500;

% 1) Build demo data
data = make_synthetic_data(cap);
fprintf('Running with built-in demo data (no Excel needed).\n');

% 2) Algorithm options (ACO)
opt = struct();
opt.method = 'aco';
opt.baseP_kW = 50;
opt.baseE_kWh = 100;
opt.search.P_kW = 10:10:250;
opt.search.E_kWh = 20:20:800;
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

% 3) Solve
result = q3_optimize_storage(data, opt);

disp('===== Q3 Summary =====');
disp(result.summary);

for i = 1:numel(result.zone)
    z = result.zone(i);
    fprintf('\n[%s]\n', z.name);
    fprintf('Base annual total cost (50kW/100kWh): %.2f CNY\n', z.base.annual_cost);
    fprintf('Best config: P=%.0f kW, E=%.0f kWh\n', z.best.P_kW, z.best.E_kWh);
    fprintf('Best annual total cost: %.2f CNY\n', z.best.annual_cost);
    fprintf('Cost reduction: %.2f%%\n', 100 * z.improve.cost_drop_pct);
end

end

function data = make_synthetic_data(cap)
% 24h load and renewable p.u. profiles provided by user

A_load = [275 275 277 310 310 293 293 380 375 281 447 447 447 405 404 403 268 313 287 288 284 287 277 275]';
B_load = [241 253 329 315 290 270 307 354 264 315 313 291 360 369 389 419 412 291 379 303 331 306 285 324]';
C_load = [302 292 307 293 271 252 283 223 292 283 287 362 446 504 455 506 283 311 418 223 229 361 302 291]';

A_pv_pu = [0 0 0 0 0 0 0 0.0058 0.3026 0.6020 0.7711 0.8555 0.8531 0.7842 0.6437 0.4242 0.0619 0 0 0 0 0 0 0]';
B_wind_pu = [0.2301 0.3828 0.2968 0.4444 0.5029 0.3609 0.2402 0.0473 0.1538 0.1068 0.0518 0.2169 0.3546 0.2194 0.1110 0.2186 0.3779 0.3421 0.5008 0.4646 0.2197 0.1783 0.1535 0]';
C_pv_pu = [0 0 0 0 0 0 0 0.0105 0.3280 0.6314 0.7936 0.8925 0.8999 0.8221 0.6667 0.4275 0.0216 0 0 0 0 0 0 0]';
C_wind_pu = [0.1464 0.2175 0.3959 0.1831 0.4716 0.6215 0.2946 0.1214 0.0250 0.3023 0.0196 0.1224 0.3335 0.2653 0.1220 0.1633 0.2645 0.3408 0.3183 0.3299 0.1703 0.1655 0.1897 0.2323]';

Aw = zeros(24,1);
Ap = A_pv_pu * cap.A.pv;
Bw = B_wind_pu * cap.B.wind;
Bp = zeros(24,1);
Cw = C_wind_pu * cap.C.wind;
Cp = C_pv_pu * cap.C.pv;

data = struct();
data.dt_h = 1;
data.days_per_year = 365;
data.load_kW = {A_load, B_load, C_load};
data.wind_avail_kW = {Aw, Bw, Cw};
data.solar_avail_kW = {Ap, Bp, Cp};

% Price assumptions
data.price.wind_yuan_kWh = 0.5;
data.price.solar_yuan_kWh = 0.4;
price = 0.85 * ones(24,1);
price(1:6) = 0.55;
price(12:16) = 0.55;
price(19:22) = 1.25;
data.price.grid_yuan_kWh = price;

% Storage assumptions
data.storage.capexP_yuan_kW = 650;
data.storage.capexE_yuan_kWh = 1200;
data.storage.life_year = 10;
data.storage.eta_ch = 0.95;
data.storage.eta_dis = 0.95;
data.storage.soc_min = 0.10;
data.storage.soc_max = 0.90;
data.storage.soc0 = 0.50;
end
