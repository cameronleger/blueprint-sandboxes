if settings.startup[Settings.labsAbsorbPollution].value
then
    local absorbPerSecond = 0.01
    data.raw.tile["lab-dark-1"].pollution_absorption_per_second = absorbPerSecond
    data.raw.tile["lab-dark-2"].pollution_absorption_per_second = absorbPerSecond
end
