function gridPriceVec = q3_get_grid_price_vector(data, T)
if isscalar(data.price.grid_yuan_kWh)
    gridPriceVec = data.price.grid_yuan_kWh * ones(T, 1);
else
    gridPriceVec = data.price.grid_yuan_kWh(:);
    if numel(gridPriceVec) ~= T
        error('data.price.grid_yuan_kWh vector length must equal T=%d', T);
    end
end
end
