if settings.startup[Settings.labsAbsorbPollution].value
then
    local absorbPerSecond = { pollution = 0.01 }
    data.raw.tile["lab-dark-1"].absorptions_per_second = absorbPerSecond
    data.raw.tile["lab-dark-2"].absorptions_per_second = absorbPerSecond
end
