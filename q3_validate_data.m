function q3_validate_data(data)
req = {'dt_h','load_kW','wind_avail_kW','solar_avail_kW','price','storage'};
for i = 1:numel(req)
    if ~isfield(data, req{i}), error('Missing field data.%s', req{i}); end
end
n = numel(data.load_kW);
if numel(data.wind_avail_kW) ~= n || numel(data.solar_avail_kW) ~= n
    error('load/wind/solar zone counts are inconsistent');
end
for i = 1:n
    L = numel(data.load_kW{i});
    if numel(data.wind_avail_kW{i}) ~= L || numel(data.solar_avail_kW{i}) ~= L
        error('Zone %d load/wind/solar lengths inconsistent', i);
    end
end
validateattributes(data.dt_h, {'numeric'}, {'scalar','real','finite','positive'});
q3_validate_scalar(data.price, 'wind_yuan_kWh', 'data.price.wind_yuan_kWh');
q3_validate_scalar(data.price, 'solar_yuan_kWh', 'data.price.solar_yuan_kWh');
q3_validate_price(data.price, 'grid_yuan_kWh', 'data.price.grid_yuan_kWh');
q3_validate_scalar(data.storage, 'capexP_yuan_kW', 'data.storage.capexP_yuan_kW');
q3_validate_scalar(data.storage, 'capexE_yuan_kWh', 'data.storage.capexE_yuan_kWh');
q3_validate_scalar(data.storage, 'life_year', 'data.storage.life_year');
q3_validate_scalar(data.storage, 'eta_ch', 'data.storage.eta_ch');
q3_validate_scalar(data.storage, 'eta_dis', 'data.storage.eta_dis');
q3_validate_scalar(data.storage, 'soc_min', 'data.storage.soc_min');
q3_validate_scalar(data.storage, 'soc_max', 'data.storage.soc_max');
q3_validate_scalar(data.storage, 'soc0', 'data.storage.soc0');
if data.storage.soc_min >= data.storage.soc_max, error('soc_min must be < soc_max'); end
if data.storage.soc0 < data.storage.soc_min || data.storage.soc0 > data.storage.soc_max
    error('soc0 must be in [soc_min, soc_max]');
end
if data.storage.eta_ch <= 0 || data.storage.eta_dis <= 0
    error('eta_ch and eta_dis must be positive');
end
end
