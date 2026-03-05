function out = elec_cup_A_storage_verification(cfg)
%ELEC_CUP_A_STORAGE_VERIFICATION 示例验证函数（可直接被 run_elec_cup_soc_plot 调用）
% 说明：
% - 支持 cfg.useExcel=false
% - 返回包含 time/soc 的结构体，便于 SOC 绘图脚本直接解析
% - 当无输出调用时，会把结果写入 base workspace 的 out 变量
%
% 用法：
%   out = elec_cup_A_storage_verification(struct('useExcel', false));
%   elec_cup_A_storage_verification(struct('useExcel', false));

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'useExcel')
    cfg.useExcel = false;
end

if cfg.useExcel
    warning('cfg.useExcel=true 时，此示例函数不会读取 Excel，仍使用内置示例数据。');
end

% 构造可复现的示例 SOC 数据（0~1）
t = (0:1:120).';
out = struct();
out.time = t;
out.soc = max(0, min(1, 0.92 - 0.0035 * t + 0.02 * sin(t / 9)));
out.pack(1).t = t;
out.pack(1).SOC = max(0, min(1, 0.90 - 0.0030 * t + 0.015 * sin(t / 11)));
out.pack(2).t = t;
out.pack(2).SOC = max(0, min(1, 0.88 - 0.0040 * t + 0.010 * cos(t / 10)));
out.meta.source = 'mock_verification';
out.meta.useExcel = cfg.useExcel;
out.meta.note = 'This is a placeholder implementation.';

% 若用户不接收输出，则兼容写入 base workspace
if nargout == 0
    assignin('base', 'out', out);
end
end
