function zone = q3_make_zone(data, i)
zone.name = q3_zone_name(i);
zone.load = data.load_kW{i}(:);
zone.wind = data.wind_avail_kW{i}(:);
zone.solar = data.solar_avail_kW{i}(:);
end
