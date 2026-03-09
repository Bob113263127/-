function c = q3_annualized_capex(data, P_kW, E_kWh)
capex = P_kW * data.storage.capexP_yuan_kW + E_kWh * data.storage.capexE_yuan_kWh;
c = capex / data.storage.life_year;
end
