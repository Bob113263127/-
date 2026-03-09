function [flow, energy] = q3_calc_energy_flow(zone, pch, pdis, dt)
net = zone.load - zone.wind - zone.solar + pch - pdis;
grid = max(0, net);
renew_used = max(0, zone.load + pch - pdis - grid);
avail = zone.wind + zone.solar; curtail = max(0, avail - renew_used);
ratio_w = zeros(size(avail)); mask = avail > 1e-9; ratio_w(mask) = zone.wind(mask) ./ avail(mask);
wind_used = renew_used .* ratio_w; solar_used = renew_used - wind_used;
energy.grid_kWh = sum(grid) * dt; energy.curtail_kWh = sum(curtail) * dt;
energy.wind_used_kWh = sum(wind_used) * dt; energy.solar_used_kWh = sum(solar_used) * dt;
energy.charge_kWh = sum(pch) * dt; energy.discharge_kWh = sum(pdis) * dt;
flow.grid = grid; flow.curtail = curtail;
end
