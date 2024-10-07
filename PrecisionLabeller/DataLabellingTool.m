%% Total Reset
totalReset();

% Initiate VLC
v = VLC();

%% Import default files
default = iniFileHandler('defaultUni.ini', v);
default.loadFiles;

v.play;
pause(1);
v.pause;
pause(1);

% %% Plot from data
plots = plotManager(v, default);

plots.addPlot('Shank', 'SensorFile1', ...
    default.Data.SensorFiles.SensorFile1.Time_s_,default.Data.SensorFiles.SensorFile1.AccelerometerX_g_, ...
    default.Data.SensorFiles.SensorFile1.Time_s_,default.Data.SensorFiles.SensorFile1.AccelerometerY_g_, ...
    default.Data.SensorFiles.SensorFile1.Time_s_,default.Data.SensorFiles.SensorFile1.AccelerometerZ_g_)

pause(1);

plots.addPlot('Thigh', 'SensorFile2', ...
    default.Data.SensorFiles.SensorFile2.Time_s_,default.Data.SensorFiles.SensorFile2.AccelerometerX_g_, ...
    default.Data.SensorFiles.SensorFile2.Time_s_,default.Data.SensorFiles.SensorFile2.AccelerometerY_g_, ...
    default.Data.SensorFiles.SensorFile2.Time_s_,default.Data.SensorFiles.SensorFile2.AccelerometerZ_g_)


pause(1);

% plots.startEdit;
