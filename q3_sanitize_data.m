function data = q3_sanitize_data(data)
for i = 1:numel(data.load_kW)
    data.load_kW{i} = q3_sanitize_vector(data.load_kW{i}, sprintf('load_kW{%d}', i));
    data.wind_avail_kW{i} = q3_sanitize_vector(data.wind_avail_kW{i}, sprintf('wind_avail_kW{%d}', i));
    data.solar_avail_kW{i} = q3_sanitize_vector(data.solar_avail_kW{i}, sprintf('solar_avail_kW{%d}', i));
end
end
