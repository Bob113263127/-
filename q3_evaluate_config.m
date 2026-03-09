function m = q3_evaluate_config(zone, data, Pmax_kW, Emax_kWh)
T = numel(zone.load); dt = data.dt_h;
if Pmax_kW == 0 || Emax_kWh == 0
    pch = zeros(T,1); pdis = zeros(T,1); e = zeros(T,1);
    [flowDay, energyDay] = q3_calc_energy_flow(zone, pch, pdis, dt);
    ann_capex = 0; soc = zeros(T,1);
else
    [pch, pdis, e] = q3_optimize_dispatch_lp(zone, data, Pmax_kW, Emax_kWh);
    [flowDay, energyDay] = q3_calc_energy_flow(zone, pch, pdis, dt);
    ann_capex = q3_annualized_capex(data, Pmax_kW, Emax_kWh); soc = e / Emax_kWh;
end
priceVec = q3_get_grid_price_vector(data, T);
gridCostDay = sum(flowDay.grid .* priceVec) * dt; k = data.days_per_year;
energyYear.grid_kWh = energyDay.grid_kWh * k;
energyYear.curtail_kWh = energyDay.curtail_kWh * k;
energyYear.wind_used_kWh = energyDay.wind_used_kWh * k;
energyYear.solar_used_kWh = energyDay.solar_used_kWh * k;
energyYear.charge_kWh = energyDay.charge_kWh * k;
energyYear.discharge_kWh = energyDay.discharge_kWh * k;
energy_cost = energyYear.wind_used_kWh * data.price.wind_yuan_kWh + ...
              energyYear.solar_used_kWh * data.price.solar_yuan_kWh + gridCostDay * k;
m.P_kW = Pmax_kW; m.E_kWh = Emax_kWh;
m.annual_capex = ann_capex; m.annual_energy_cost = energy_cost; m.annual_cost = ann_capex + energy_cost;
m.annual_grid_energy_kWh = energyYear.grid_kWh; m.annual_curtail_energy_kWh = energyYear.curtail_kWh;
m.annual_wind_used_kWh = energyYear.wind_used_kWh; m.annual_solar_used_kWh = energyYear.solar_used_kWh;
m.annual_charge_kWh = energyYear.charge_kWh; m.annual_discharge_kWh = energyYear.discharge_kWh; m.sample_soc = soc;
end
