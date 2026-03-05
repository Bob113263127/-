function result = run_q3_example()
%RUN_Q3_EXAMPLE 自动读取“附件1/附件2/附件3”并运行第三问优化。
% 调用方式：result = run_q3_example();

clc;

% 题面装机参数（kW）
cap.A.pv = 750; cap.A.wind = 0;
cap.B.pv = 0;   cap.B.wind = 1000;
cap.C.pv = 600; cap.C.wind = 500;

% ==== 1) 自动读取附件 ====
data = load_q3_data_from_excels(pwd, cap);

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

%% ================= local functions =================
function data = load_q3_data_from_excels(folder, cap)
files = dir(fullfile(folder, '*.xls*'));
if isempty(files)
    error('当前目录未找到 Excel 文件，请把附件1/2/3 放到脚本同目录。');
end

f1 = pick_file(files, {'附件1','负荷'});
f2 = pick_file(files, {'附件2','风光'});
f3 = pick_file(files, {'附件3','12个月'}); %#ok<NASGU>

Tload = readtable(fullfile(folder, f1), 'VariableNamingRule', 'preserve');
Trew = readtable(fullfile(folder, f2), 'VariableNamingRule', 'preserve');

A_load = pick_numeric_col(Tload, {'A','园区A','负荷A','A区'});
B_load = pick_numeric_col(Tload, {'B','园区B','负荷B','B区'});
C_load = pick_numeric_col(Tload, {'C','园区C','负荷C','C区'});

% 附件2一般是归一化出力，若已是kW则 scale=1
Aw_norm = pick_numeric_col(Trew, {'A风','A_wind','A风电','园区A风'} , true);
Ap_norm = pick_numeric_col(Trew, {'A光','A_pv','A光伏','园区A光'} , true);
Bw_norm = pick_numeric_col(Trew, {'B风','B_wind','B风电','园区B风'} , true);
Bp_norm = pick_numeric_col(Trew, {'B光','B_pv','B光伏','园区B光'} , true);
Cw_norm = pick_numeric_col(Trew, {'C风','C_wind','C风电','园区C风'} , true);
Cp_norm = pick_numeric_col(Trew, {'C光','C_pv','C光伏','园区C光'} , true);

% 长度对齐
L = min([numel(A_load), numel(B_load), numel(C_load), ...
         numel(Aw_norm), numel(Ap_norm), numel(Bw_norm), numel(Bp_norm), numel(Cw_norm), numel(Cp_norm)]);
A_load = A_load(1:L); B_load = B_load(1:L); C_load = C_load(1:L);
Aw_norm = Aw_norm(1:L); Ap_norm = Ap_norm(1:L);
Bw_norm = Bw_norm(1:L); Bp_norm = Bp_norm(1:L);
Cw_norm = Cw_norm(1:L); Cp_norm = Cp_norm(1:L);

Aw = scale_series(Aw_norm, cap.A.wind);
Ap = scale_series(Ap_norm, cap.A.pv);
Bw = scale_series(Bw_norm, cap.B.wind);
Bp = scale_series(Bp_norm, cap.B.pv);
Cw = scale_series(Cw_norm, cap.C.wind);
Cp = scale_series(Cp_norm, cap.C.pv);

data = struct();
data.dt_h = 1;
data.days_per_year = infer_days_per_year(L, f3, folder);

data.load_kW = {A_load, B_load, C_load};
data.wind_avail_kW = {Aw, Bw, Cw};
data.solar_avail_kW = {Ap, Bp, Cp};

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

function days = infer_days_per_year(L, f3, folder)
% 默认按典型日*365，若附件3存在且能识别到12个月权重，则按权重总和
if isempty(f3)
    days = 365;
    return;
end
try
    T = readtable(fullfile(folder, f3), 'VariableNamingRule', 'preserve');
    nums = table2array(T(:, varfun(@isnumeric, T, 'OutputFormat','uniform')));
    nums = nums(:);
    nums = nums(isfinite(nums));
    cand = nums(nums >= 1 & nums <= 31);
    if numel(cand) >= 12
        days = sum(cand(1:12));
        if days < 300 || days > 370
            days = 365;
        end
    else
        days = 365;
    end
catch
    days = 365;
end

if L > 24
    % 若已是更长序列，默认不再乘365
    days = 1;
end
end

function out = scale_series(x, capKW)
x = x(:);
mx = max(x);
if mx <= 1.2
    out = x * capKW; % 归一化数据
else
    out = x;         % 已是kW
end
end

function fn = pick_file(files, keys)
fn = '';
for i = 1:numel(files)
    name = files(i).name;
    ok = true;
    for k = 1:numel(keys)
        if ~contains(name, keys{k})
            ok = false; break;
        end
    end
    if ok
        fn = name; return;
    end
end
% 宽松匹配：任一关键词
for i = 1:numel(files)
    name = files(i).name;
    for k = 1:numel(keys)
        if contains(name, keys{k})
            fn = name; return;
        end
    end
end
if ~any(strcmp(keys,'12个月'))
    error('未找到包含关键词 %s 的Excel文件。', strjoin(keys, '/'));
end
end

function x = pick_numeric_col(T, aliases, allowEmpty)
if nargin < 3, allowEmpty = false; end
vars = T.Properties.VariableNames;

bestFallback = [];
bestScore = -inf;

% 先按列名关键字匹配
for i = 1:numel(vars)
    vn = string(vars{i});
    for k = 1:numel(aliases)
        if contains(vn, string(aliases{k}), 'IgnoreCase', true)
            col = to_numeric_column(T.(vars{i}));
            if is_usable_numeric_column(col)
                x = col(:);
                return;
            end
        end
    end
end

% 再按“有效数值比例最高”的列兜底
for i = 1:numel(vars)
    col = to_numeric_column(T.(vars{i}));
    score = numeric_column_score(col);
    if score > bestScore
        bestScore = score;
        bestFallback = col;
    end
end

if is_usable_numeric_column(bestFallback)
    x = bestFallback(:);
    return;
end

if allowEmpty
    x = zeros(height(T),1);
else
    error('未找到可用数值列，别名：%s', strjoin(aliases, ', '));
end
end

function x = to_numeric_column(col)
if isnumeric(col)
    x = double(col);
    return;
end
if iscell(col)
    try
        x = cellfun(@local_str2double, col);
        return;
    catch
        x = [];
        return;
    end
end
if isstring(col) || ischar(col) || iscategorical(col)
    x = str2double(string(col));
    return;
end
x = [];
end


function tf = is_usable_numeric_column(col)
if isempty(col)
    tf = false;
    return;
end
good = isfinite(col);
tf = any(good) && sum(good) >= max(3, ceil(numel(col)*0.2));
end

function score = numeric_column_score(col)
if isempty(col)
    score = -inf;
    return;
end
goodRatio = mean(isfinite(col));
if ~any(isfinite(col))
    score = -inf;
    return;
end
dyn = max(col(isfinite(col))) - min(col(isfinite(col)));
score = goodRatio + 1e-6 * dyn;
end

function v = local_str2double(c)
if isnumeric(c)
    v = double(c);
elseif isstring(c) || ischar(c)
    v = str2double(string(c));
else
    v = NaN;
end
end
