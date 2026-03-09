function result = q3_optimize_storage(data, opt)
%Q3_OPTIMIZE_STORAGE Q3 storage sizing via ACO + dispatch.
if nargin < 1 || isempty(data)
    disp('No data provided, running run_q3_example().');
    result = run_q3_example();
    return;
end
if nargin < 2 || ~isstruct(opt), opt = struct(); end

opt = q3_fill_default_opt(opt);
q3_validate_data(data);
data = q3_sanitize_data(data);
data = q3_fill_default_data(data);
data.warn = opt.warn;

nZone = numel(data.load_kW);
result.zone = repmat(struct(), nZone, 1);
for i = 1:nZone
    zone = q3_make_zone(data, i);
    base = q3_evaluate_config(zone, data, opt.baseP_kW, opt.baseE_kWh);
    if strcmpi(opt.method, 'aco')
        best = q3_search_best_config_aco(zone, data, opt);
    else
        best = q3_search_best_config_grid(zone, data, opt);
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
result.summary = q3_build_summary(result.zone);
end
