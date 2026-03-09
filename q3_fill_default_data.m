function data = q3_fill_default_data(data)
if ~isfield(data, 'days_per_year') || isempty(data.days_per_year)
    data.days_per_year = 365;
end
end
