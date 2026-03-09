function cfg = q3_make_penalty_cfg(P, E)
cfg.P_kW = P; cfg.E_kWh = E;
cfg.annual_capex = inf; cfg.annual_energy_cost = inf; cfg.annual_cost = inf;
cfg.annual_grid_energy_kWh = inf; cfg.annual_curtail_energy_kWh = inf;
cfg.annual_wind_used_kWh = 0; cfg.annual_solar_used_kWh = 0;
cfg.annual_charge_kWh = 0; cfg.annual_discharge_kWh = 0; cfg.sample_soc = [];
end
