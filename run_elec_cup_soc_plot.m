%% run_elec_cup_soc_plot.m
% 功能：
% 1) 调用 elec_cup_A_storage_verification(cfg)
% 2) 固定 cfg.useExcel = false
% 3) 自动提取并绘制 SOC 曲线

clear; clc;

cfg = struct();
cfg.useExcel = false;

out = callVerification(cfg);
[socList, timeList, nameList] = extractSocSeries(out);

if isempty(socList)
    error(['未找到 SOC 数据。请检查 elec_cup_A_storage_verification 的输出结构，' ...
           '并在 extractSocSeries 中补充字段映射。']);
end

figure('Name', 'SOC Curves', 'Color', 'w');
hold on; grid on; box on;

xLabelText = 'Sample Index';
for i = 1:numel(socList)
    soc = socList{i};
    t = timeList{i};
    if isempty(t)
        t = (1:numel(soc)).';
    else
        xLabelText = 'Time';
    end
    plot(t, soc, 'LineWidth', 1.5, 'DisplayName', nameList{i});
end

xlabel(xLabelText);
ylabel('SOC');
title('SOC Curves (cfg.useExcel = false)');
legend('Location', 'best');

%% ================= Local Functions =================
function out = callVerification(cfg)
fn = 'elec_cup_A_storage_verification';

if exist(fn, 'file') ~= 2
    error('未找到 %s.m，请确认该函数已加入 MATLAB 路径。', fn);
end

% 优先按“有返回值”的形式调用
try
    out = feval(fn, cfg);
    return;
catch ME
    if ~contains(string(ME.message), "Too many output arguments")
        rethrow(ME);
    end
end

% 若函数无返回值，尝试从 base workspace 获取常见结果变量
feval(fn, cfg);
candidates = {'out', 'result', 'results', 'data'};
for i = 1:numel(candidates)
    if evalin('base', sprintf("exist('%s','var')", candidates{i}))
        out = evalin('base', candidates{i});
        return;
    end
end

error(['函数执行成功但未获取到输出。' ...
       '请让函数返回结果，或在 base workspace 中写入 out/result/results/data。']);
end

function [socList, timeList, nameList] = extractSocSeries(out)
socList = {};
timeList = {};
nameList = {};

% 情况1：直接是数值向量
if isnumeric(out) && isvector(out)
    socList{1} = out(:);
    timeList{1} = [];
    nameList{1} = 'SOC';
    return;
end

% 情况2：table/timetable
if istable(out) || istimetable(out)
    [socList, timeList, nameList] = fromTable(out, 'output');
    return;
end

% 情况3：struct（递归搜索）
if isstruct(out)
    [socList, timeList, nameList] = fromStruct(out, 'output');
end
end

function [socList, timeList, nameList] = fromStruct(s, rootName)
socList = {};
timeList = {};
nameList = {};

if numel(s) > 1
    for k = 1:numel(s)
        [a, b, c] = fromStruct(s(k), sprintf('%s(%d)', rootName, k));
        socList = [socList, a]; %#ok<AGROW>
        timeList = [timeList, b]; %#ok<AGROW>
        nameList = [nameList, c]; %#ok<AGROW>
    end
    return;
end

fns = fieldnames(s);
socField = findField(fns, {'soc', 'SOC', 'Soc'});
timeField = findField(fns, {'time', 'Time', 't', 'T'});

if ~isempty(socField)
    soc = s.(socField);
    if isnumeric(soc) && isvector(soc)
        socList{end+1} = soc(:); %#ok<AGROW>
        if ~isempty(timeField)
            t = s.(timeField);
            if isnumeric(t) && isvector(t) && numel(t) == numel(soc)
                timeList{end+1} = t(:); %#ok<AGROW>
            else
                timeList{end+1} = []; %#ok<AGROW>
            end
        else
            timeList{end+1} = []; %#ok<AGROW>
        end
        nameList{end+1} = sprintf('%s.%s', rootName, socField); %#ok<AGROW>
    end
end

for i = 1:numel(fns)
    v = s.(fns{i});
    path = sprintf('%s.%s', rootName, fns{i});
    if isstruct(v)
        [a, b, c] = fromStruct(v, path);
        socList = [socList, a]; %#ok<AGROW>
        timeList = [timeList, b]; %#ok<AGROW>
        nameList = [nameList, c]; %#ok<AGROW>
    elseif istable(v) || istimetable(v)
        [a, b, c] = fromTable(v, path);
        socList = [socList, a]; %#ok<AGROW>
        timeList = [timeList, b]; %#ok<AGROW>
        nameList = [nameList, c]; %#ok<AGROW>
    end
end
end

function [socList, timeList, nameList] = fromTable(tb, rootName)
socList = {};
timeList = {};
nameList = {};

vars = tb.Properties.VariableNames;
socVar = findField(vars, {'soc', 'SOC', 'Soc'});
timeVar = findField(vars, {'time', 'Time', 't', 'T'});
if isempty(socVar)
    return;
end

soc = tb.(socVar);
if ~isnumeric(soc)
    return;
end

if isvector(soc)
    socList{1} = soc(:);
    if ~isempty(timeVar)
        t = tb.(timeVar);
        if isnumeric(t) && isvector(t) && numel(t) == numel(soc)
            timeList{1} = t(:);
        else
            timeList{1} = [];
        end
    else
        timeList{1} = [];
    end
    nameList{1} = sprintf('%s.%s', rootName, socVar);
end
end

function matched = findField(names, candidates)
matched = '';
for i = 1:numel(candidates)
    idx = find(strcmp(names, candidates{i}), 1);
    if ~isempty(idx)
        matched = names{idx};
        return;
    end
end
for i = 1:numel(candidates)
    idx = find(strcmpi(names, candidates{i}), 1);
    if ~isempty(idx)
        matched = names{idx};
        return;
    end
end
end
