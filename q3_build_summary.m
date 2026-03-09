function summary = q3_build_summary(zones)
n = numel(zones);
name = cell(n,1); baseCost = zeros(n,1); bestCost = zeros(n,1);
bestP = zeros(n,1); bestE = zeros(n,1); improvePct = zeros(n,1);
for i = 1:n
    name{i} = zones(i).name;
    baseCost(i) = zones(i).base.annual_cost; bestCost(i) = zones(i).best.annual_cost;
    bestP(i) = zones(i).best.P_kW; bestE(i) = zones(i).best.E_kWh;
    improvePct(i) = zones(i).improve.cost_drop_pct * 100;
end
summary = table(name, baseCost, bestCost, bestP, bestE, improvePct, ...
    'VariableNames', {'zone','baseAnnualCost','bestAnnualCost','bestP_kW','bestE_kWh','costDropPct'});
end
