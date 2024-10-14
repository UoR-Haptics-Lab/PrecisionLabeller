%% DatalabellingTool.m
% Type               : Main Class (Central controller of tool)
% Singleton Design   : Does not create new instances when calling constructor
% Facade Design      : Covers complicated logic in main class

% Included subclasses:
%   FileHandler.m
%   SensorManager.m
%   PlotManager.m
%   LabelHandler.m
%   ErrorHandler.m
%   VLC.m

% All Publicly Accessible Methods
%   init()
%   loadFiles(obj, filePath)
%   import(obj, varargin)
%   savePreset(obj, fileName)
%   addSensors(obj, varargin)
%   removeSensors(obj, sensorName)
%   plot(obj, plotName, sensorName, col)
%   removePlot(obj, plotName)
%   newLabelFile(obj)
%   loadLabelFile(obj, fileName)
%   saveLabelFile(obj)
%   play(obj, fileName)
%   quit(obj)
%   select(obj)
%   deselect(obj)
%   edit(obj)
%   exportFeatures(obj)

% Use 'd = DataLabellingTool.init' to instantiate
% DataLabellingTool() constructor is restricted to prevent new instance
classdef DataLabellingTool < handle
    %% Public properties, Not writable by users
    properties (SetAccess = protected, SetObservable = true) % Oberservable for listeners
        DefaultFilePath char      = ""           % Default .ini file path
        FilePaths       struct    = struct()     % Struct for all file paths referenced in default.ini
        Files           struct    = struct()     % Data loaded from DataPath
        LabelFolderPath char      = ""           % Label folder path
        LoadedVersion   char      = ""           % Current loaded label version
        SaveFileName    char      = "SaveFile" % Label Save File Name (Format: FILENAME_DD-MM-YYYY_HH-MM-SS.mat)
        Sensors         struct    = struct()     % Imported Sensor Files
        Plots           struct    = struct()     % All current plots from this instance
    end
    % Public but hidden
    properties (Hidden)
        vlc             VLC                      % VLC object to connect to local VLC
    end

    %% Protected Properties, Not writable nor readable to users
    %                            writable and readable to subclasses
    properties (Access = protected, SetObservable = true)   % Oberservable for listeners
        Time            double    = 0            % Current video time from VLC (default 0 if no VLC)
        Thread          timer                    % Timer function to update obj.Time
        GroundTruth     struct    = struct()     % Temp variable for saving label version
        Flag            logical   = false        % Flag for Thread status  (1: Running, 0: Stopped)
        EditFlag        logical   = false        % Flag for Editing status (1: Start edit, 0: Stop edit)
    end
    
    %% Protected Properties, Not writable nor readable to users
    %  Transient to exclude from saving in .mat
    properties (Access = protected, Transient = true)
        Listeners       cell      = {}           % Observers for callback from different changes
    end

    %% (Private) Constructor
    methods (Access = private)
        % Restricts creating new instance
        function obj = DataLabellingTool()
            % Set default Thread as timer function
            obj.Thread = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode','drop', ...
                'Period', 0.05, ...
                'TimerFcn', @(~, ~)update(obj), ...
                'Name', 'UpdateVideoTime');
            % Fixed rate timer calls obj.update every 0.01s
            % Name:     UpdateVideoTime
            % Function: Fetch current VLC video time in SECONDS if VLC
            %           avaiable. Defaults to 0s if no connection.
        end
    end

    %% (Static) Instantiator
    methods (Static)
        %% Usage   : init()
        %
        % Function : Allows creating singleton instance 
        %            without calling constructor
        function obj = init()
             persistent uniqueInstance % Current instance
             % IF no instance has been created
             if isempty(uniqueInstance) || ~isvalid(uniqueInstance)
                obj = DataLabellingTool(); % Output new instantiated instance
                uniqueInstance = obj;      % Store new instance as current instance
             % ELSE create new instance
             else
                obj = uniqueInstance;  % Return current instance
             end                           
        end
    end

    %% (Public) Methods
    methods
        %% Usage(2): loadFiles()             default Input: "default.ini"
        %          : loadFiles(filePath)
        %
        % Function : load files from type .ini or .mat
        %            Parse a .ini and load corresponding filepaths
        %            Load a .mat and load corresponding variables
        function loadFiles(obj, filePath)
            arguments (Input)
                obj      {mustBeA(obj,"DataLabellingTool")}
                filePath {mustBeFile} = "default.ini" % Default filepath as "default.ini"
            end
            % Clean current listeners
            if ~isempty(obj.Listeners); cellfun(@delete,obj.Listeners); end
            
            % Return newly constructed obj
            loadedObj = FileHandler.importFiles(filePath, obj.Files); % Calling FileHandler
            % Overwrite current properties
            obj.DefaultFilePath = loadedObj.DefaultFilePath;
            obj.FilePaths       = loadedObj.FilePaths;
            obj.Files           = loadedObj.Files;
            obj.LabelFolderPath = loadedObj.LabelFolderPath;
            obj.SaveFileName    = loadedObj.SaveFileName;
            obj.Sensors         = loadedObj.Sensors;
            obj.Plots           = loadedObj.Plots;
            obj.GroundTruth     = loadedObj.GroundTruth;
            % Declare new listeners for newly constructed properties
            obj.Listeners{1}    = addlistener(obj, 'LoadedVersion','PostSet', @(~, ~)PlotManager.updateLabel(obj));
            obj.Listeners{2}    = addlistener(obj, 'Time','PostSet', @(~, ~)PlotManager.updateIndicator(obj, obj.Time));
            
            % Display current obj
            disp(obj);
        end
        
        %% Usage   : import()
        %
        % Function : import specified files in respective place according
        %            to the file type
        function import(obj, varargin)
            [fileName, dir] = uigetfile("*", 'MultiSelect', 'on');
            if ~iscell(fileName)
                filePath = fullfile(dir, fileName);
                try name = varargin{1}; catch; name = ""; end
                obj.Files = FileHandler.categorise(filePath, name, obj.Files);
                return
            end

            for i=1:numel(fileName)
                if iscell(fileName); filePath = fullfile(dir, fileName{i}); end

                try name = varargin{1}; catch; name = ""; end
                obj.Files = FileHandler.categorise(filePath, name, obj.Files);
            end
        end

        %% Usage(2): savePreset()          default Input: "preload"
        %          : savePreset(fileName)
        %
        % Function : saves current instance properties in given fileName
        %            saves file as 'CURRENT_FOLDER/FILENAME_dd-MM-yyyy_HH-mm-ss.mat'
        function savePreset(obj, fileName)
            arguments
                obj      {mustBeA(obj,"DataLabellingTool")}
                fileName string = "preload" % Default file Name as "preload"
            end
            FileHandler.saveFile(obj, obj, fileName); % Calling File Handler
        end
       
        %% Usage(5): addSensors()           default Input: ALL SensorFiles
        %            addSensors(sensorFile)
        %            addSensors(sensorFile, newSensorName)
        %            addSensors(sensorFile, sensorFileName, newSensorName)
        %            addSensors(sensorFile, sensorFileName, newSensorName, columnsInFile)
        %
        % Function : add a new sensor to struct from specified columns of SensorFiles
        %            defaults to adding all SensorFiles as individual sensors
        %            if no input is given
        function addSensors(obj, varargin)
            obj.Sensors = SensorManager.addSensors(obj.Sensors, obj.Files.SensorFiles, varargin{:});
            disp("Current Sensors:"); % Display new struct
            disp(obj.Sensors);
        end

        %% Usage   : changeTimeRow()
        %
        % Function : changes time row for selected sensor
        function changeTimeRow(obj, sensorName, newCol)
            SensorManager.changeTimeRow(obj, sensorName, newCol); % Calling SensorManager
        end

        %% Usage   : changeSaveName()
        %
        % Function : changes save file name of tool
        function changeSaveName(obj)
            fprintf("\nCurrent Save File Name: %s\n", obj.SaveFileName)
            saveName = input("Enter New Save Name: ","s");
            
            if ~isvarname(saveName)
                ErrorHandler.raiseError("InvalidFileName", "DataLabellingTool", saveName).throw;
                return;
            end

            obj.SaveFileName = saveName;
            disp(obj);
        end

        %% Usage   : removeSensors(sensorName)
        %
        % Function : removes a sensor from Sensor struct
        %            returns new Sensors struct
        function removeSensors(obj, sensorName)
            arguments
                obj        {mustBeA(obj,"DataLabellingTool")}
                sensorName {mustBeText}
            end
            obj.Sensors = SensorManager.removeSensors(obj.Sensors,sensorName); % Calling SensorManager
            disp("Current Sensors:"); % Display new struct
            disp(obj.Sensors);
        end
        
        %% Usage   : plot(plotName, sensorName, columns)
        %            (Note: columns in 'Sensors' to be plotted)
        %
        % Function : plot in a new figure with specified column in sensors
        %            initiate all required data in a plot
        %            including userdata, listeners, callback functions
        function plot(obj, plotName, sensorName, col)
            arguments
                obj        {mustBeA(obj,"DataLabellingTool")}
                plotName   {mustBeValidVariableName}
                sensorName {mustBeValidVariableName}
                col        double
            end

            % Add plot from PlotManager
            PlotManager.addPlot(obj, plotName, sensorName, col); % Calling PlotManager

            % Display new plot struct
            disp("Current Plots:");
            disp(obj.Plots);
        end
        
        %% Usage    : removePlot(plotName)
        %
        %  Function : removes specified plot
        %             return new struct
        function removePlot(obj, plotName)
            arguments
                obj      {mustBeA(obj,"DataLabellingTool")}
                plotName {mustBeValidVariableName}
            end
            PlotManager.removePlot(obj,plotName); % Calling PlotManager
            disp("Current Plots:");
            disp(obj.Plots);
        end

        %% Usage    : newLabelFile()
        %
        %  Function : creates a new ground truth file
        %             for starting up the first time
        function newLabelFile(obj)
            arguments
                obj {mustBeA(obj,"DataLabellingTool")}
            end
            FileHandler.newLabelFile(obj); % Calling FileHandler
        end

        %% Usage    : loadLabelFile(fileName)
        %
        %  Function : loads an available .mat label file
        %             overwrites current ground truth
        function loadLabelFile(obj, fileName)
            arguments
                obj      {mustBeA(obj,"DataLabellingTool")}
                fileName string
            end
            filePath          = fullfile(obj.LabelFolderPath,append(fileName,'.mat'));
            % Calling ErrorHandler if not a valid file
            if ~isfile(filePath); ErrorHandler.raiseError("InvalidFile", "DataLabellingTool", filePath).throwAsCaller; return; end
            FileHandler.loadLabel(obj, filePath);
        end

        %% Usage    : saveLabelFile()
        %
        %  Function : save the instantaneous ground truth into a .mat file
        function saveLabelFile(obj)
            arguments
                obj {mustBeA(obj,"DataLabellingTool")}
            end
            FileHandler.saveFile(obj, obj.GroundTruth, obj.SaveFileName, obj.LabelFolderPath); % Calling FileHandler
        end

        %% Usage    : play(fileName)
        %
        %  Function : plays the specified video file
        function play(obj, fileName)
            arguments
                obj     {mustBeA(obj,"DataLabellingTool")}
                fileName string
            end
            % File not found, Throw error
            if ~isfield(obj.Files.VideoFiles, fileName); ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "Files.VideoFiles", fileName, fieldnames(obj.Files.VideoFiles)).throwAsCaller; return; end
            
            % File found
            filePath   = obj.Files.VideoFiles.(fileName);
            obj.vlc    = VLC;
            obj.vlc.play(filePath);
            
            % Find offset
            currentPlots = obj.Plots;
            plotNames = fieldnames(currentPlots);
            % Loop overplots
            for i=1:numel(plotNames)
                % If offset is named VIDEONAME_PLOTNAME, 
                % then offset is assigned to current PLOTNAME plot
                % iterate to next plot
                if isfield(obj.Files.Offset,append(fileName, '_', currentPlots.(plotNames{i}).Handle.Name))
                    currentPlots.(plotNames{i}).Handle.UserData(3) = str2double(obj.Files.Offset.(append(fileName,'_',currentPlots.(plotNames{i}).Handle.Name)));
                    continue
                end
                
                % If offset is named VIDEONAME, 
                % then offset is assigned to current plot
                % iterate to next plot
                if isfield(obj.Files.Offset, fileName)
                    currentPlots.(plotNames{i}).Handle.UserData(3) = str2double(obj.Files.Offset.(fileName));
                    continue
                end
                
                % No offset configured, default to 0
                currentPlots.(plotNames{i}).Handle.UserData(3) = 0;
            end

            % Calls thread to start or stop thread
            obj.thread;
        end

        %% Usage    : quit()
        %
        %  Function : deletes DataLabellingTool
        %             close all plots
        %             deletes all added timers
        %             deletes all variables in base workspace that points to DataLabellingTool
        function quit(obj)
            delete(obj.Thread);
            % Delete Plots
            evalin('base', 'close all');
            % Delete timers
            try evalin('base', "stop(timerfind('Name','UpdateVideoTime'))"); catch; end
            evalin('base', "delete(timerfind('Name','UpdateVideoTime'))");
            % Delete DataLabellingTool
            delete(obj);
            var = evalin('base', 'who');
            for i = 1:numel(var)
                class = evalin('base', sprintf('whos(''%s'').class', var{i}));
                if strcmp(class, "DataLabellingTool")
                    evalin('base', sprintf('clear %s', var{i}));
                    fprintf('Variable "%s" pointing at DataLabellingTool is deleted.\n', var{i});
                end
            end
            disp('DataLabellingTool has been deleted.');
        end

        %% Usage    : select()
        %
        %  Function : prompts user to create two roi points on all current plots
        %             syncs position of roi points across all current plots
        %             also highlights region between roi points with gray
        %             to indicate selection
        function select(obj)
            obj.EditFlag = false;
            try obj.deselect; catch; end % deselect() if roi points already exist
            if numel(fieldnames(obj.Plots)) == 0; return; end % exit if no available plots
            FeaturesHandler.selector(obj); % Calling FeaturesHandler
        end

        %% Usage    : deselect()
        %
        %  Function : removes all roi points from available plots
        function deselect(obj)
            FeaturesHandler.deselector(obj); % Calling FeaturesHandler
        end

        %% Usage    : edit()
        %
        %  Function : manual labelling tool
        %             prompt for label and change region between two roi
        %             points to given label
        function edit(obj)
            obj.EditFlag = false;
            class = input("Enter Class: "); % Prompt for label
            LabelHandler.manualEdit(obj, class); % Calling LabelHandler
        end

        %% Usage    : exportFeatures()
        %
        %  Function : export all sensors in DataLabellingTool.Sensors
        %             to base workspace as a variable
        %             exported sensors does not affect imported files
        function exportFeatures(obj)
            sensors = fieldnames(obj.Sensors);
            for i=1:numel(sensors) % For all sensors, save file to base workspace
                FileHandler.saveFile(obj, obj.Sensors.(sensors{i}), sensors{i}); % Calling FileHandler
                assignin('base', sensors{i}, obj.Sensors.(sensors{i})); % Export to base workspace
            end
        end
    end
    
    methods (Access = protected)
        %% Arguments: thread()
        %
        %  Function : governs the thread
        %             start thread if theres a plot
        %             stop plot if thread is running
        %             link plots if there are more than one plot
        %             doesn't run on a listener, runs as a single-shot
        %             function
        function thread(obj)
            plotStruct = obj.Plots;
            plotName   = fieldnames(obj.Plots);
            % No plots and running thread
            if (numel(plotName) < 1) && obj.Flag
                stop(obj.Thread)
                obj.Flag = false; % flag stopped thread
                return
            end
            
            % Stopped thread
            if ~obj.Flag
                start(obj.Thread);
                obj.Flag = true; % flag started thread
            end
            
            % More than 1 plot
            if (numel(plotName) > 1)
                % Create array of axes object
                axes = zeros(numel(plotName),1);
                for i=1:numel(plotName)
                    currentPlot = plotStruct.(plotName{i});
                    % Add axes of plots to axes array
                    axes(i) = currentPlot.Handle.CurrentAxes;
                end
                % Link all axes from array
                linkaxes(axes,'x');
            end
        end
        
        %% Arguments: update()
        %
        %  Function : the TimerFcn governed by the thread
        %             Does nothing if vlc is off
        %             Double check if vlc is connected, do nothing if not
        %             Updates current video time and store into the Time property
        function update(obj)
            if isempty(obj.vlc); return; end % Skip if no video
            try if isempty(obj.vlc.Current); return; end; catch; return; end % Double check skip if no video
            videoTimeSec = obj.vlc.Current.Position / 1e6;
            if obj.Time == videoTimeSec; return; end % Skip if same video time
            obj.Time = videoTimeSec;
        end
    end
end