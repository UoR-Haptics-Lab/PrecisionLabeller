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

% Use 'd = DataLabellingTool.init' to instantiate
% DataLabellingTool() constructor is restricted to prevent new instance
classdef DataLabellingTool < handle
    %% Public properties, Not writable by users
    properties (SetAccess = protected, SetObservable = true) % Oberservable for listeners
        DefaultFilePath char      = ""          % Default .ini file path
        FilePaths       struct    = struct()    % Struct for all file paths referenced in default.ini
        Files           struct    = struct()    % Data loaded from DataPath
        LabelFolderPath char      = ""          % Label folder path
        LoadedVersion   char      = ""          % Current loaded label version
        SaveFileName    char      = ""          % Label Save File Name (Format: FILENAME_DD-MM-YYYY_HH-MM-SS.mat)
        GroundTruth     timetable = timetable() % Current loaded label version timetable
        Sensors         struct    = struct()    % Imported Sensor Files
        Plots           struct    = struct()    % All current plots from this instance
    end
    
    %% Protected Properties, Not writable nor readable to users
    %                            writable and readable to subclasses
    properties (Access = protected, SetObservable = true)   % Oberservable for listeners
        Time            double    = 0            % Current video time from VLC (default 0 if no VLC)
        vlc             VLC                      % VLC object to connect to local VLC
        Thread          timer                    % Timer function to update obj.Time
        Offset          double    = 0            % Offset for video-data time conversion
        Flag            logical   = false        % Flag for Thread status  (1: Running, 0: Stopped)
        EditFlag        logical   = false        % Flag for Editing status (1: Start edit, 0: Stop edit)
    end
    
    %% Protected Properties, Not writable nor readable to users
    %  Transient to exclude from saving in .mat
    properties (Access = public, Transient = true)
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
                'Period', 0.2, ...
                'TimerFcn', @(~,~)obj.update, ...
                'Name', 'UpdateVideoTime');
            % Fixed rate timer calls obj.update every 0.1s
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
            loadedObj = FileHandler.importFiles(filePath); % Calling FileHandler
            % Overwrite current properties
            obj.DefaultFilePath = loadedObj.DefaultFilePath;
            obj.FilePaths       = loadedObj.FilePaths;
            obj.Files           = loadedObj.Files;
            obj.LabelFolderPath = loadedObj.LabelFolderPath;
            obj.LoadedVersion   = loadedObj.LoadedVersion;
            obj.SaveFileName    = loadedObj.SaveFileName;
            obj.GroundTruth     = loadedObj.GroundTruth;
            obj.Sensors         = loadedObj.Sensors;
            obj.Plots           = loadedObj.Plots;
            % Declare new listeners for newly constructed properties
            obj.Listeners{1}    = addlistener(obj, 'LoadedVersion','PostSet', @(~, ~)PlotManager.updateLabel(obj, obj.Plots));
            obj.Listeners{2}    = addlistener(obj, 'Time','PostSet', @(~, ~)PlotManager.updateIndicator(obj, obj.Time));
            obj.Listeners{3}    = addlistener(obj, 'Plots','PostSet', @(~,~)obj.thread);
            % Display current obj
            disp(obj);
        end
        
        %% Usage(2): savePreset()            default Input: "preload"
        %          : savePreset(fileName)
        %
        % Function : saves current instance properties in given fileName
        %           saves file as 'FILENAME_dd-MM-yyyy_HH-mm-ss.mat'
        function savePreset(obj, fileName)
            arguments
                obj      {mustBeA(obj,"DataLabellingTool")}
                fileName string = "preload" % Default file Name as "preload"
            end
            FileHandler.saveFile(obj, obj, fileName); % Calling File Handler
        end
       
        %% Usage(2): addSensors(currentStruct, sensorFile)  default Input: ALL SensorFiles
        %            addSensors(currentStruct, sensorFile, sensorFileName)
        %            addSensors(currentStruct, sensorFile, sensorFileName, newSensorName)
        %            addSensors(currentStruct, sensorFile, sensorFileName, newSensorName, columnsInFile)
        %
        % Function : saves current instance properties in given fileName
        %            saves file as 'FILENAME_dd-MM-yyyy_HH-mm-ss.mat'
        function addSensors(obj, varargin)
            obj.Sensors = SensorManager.addSensors(obj.Sensors, obj.Files.SensorFiles, varargin{:});
            disp("Current Sensors:");
            disp(obj.Sensors);
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
            % Display new struct
            disp("Current Sensors:");
            disp(obj.Sensors);
        end
        
        %% Usage   : plot(plotName, sensorName, columns)
        %            Note: columns in sensor timetable to be plotted
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
            % Add zoom pan fix to initialised plot
            PlotManager.zoomPanFixPlot(obj, obj.Plots.(plotName).Handle, plotName); % Calling PlotManager
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
            filePath          = fullfile(obj.LabelFolderPath,fileName);
            % Calling ErrorHandler if not a valid file
            if ~isfile(filePath); ErrorHandler.raiseError("InvalidFile", "DataLabellingTool", filePath).throwAsCaller; return; end
            tmp               = load(filePath,'variable');
            obj.GroundTruth   = tmp.variable;
            obj.LoadedVersion = filePath;
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
            if ~isfield(obj.Files.VideoFiles, fileName); ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "Files.VideoFiles", fileName, fieldnames(obj.Files.VideoFiles)).throwAsCaller; return; end
            filePath   = obj.Files.VideoFiles.(fileName);
            obj.vlc    = VLC;
            obj.vlc.play(filePath);
            % Finds offset
            if isfield(obj.Files.VideoFiles, append(fileName,'_Offset'))
                obj.Offset = obj.Files.VideoFiles.(append(fileName,'_Offset'));
            end
            % Calls thread to start thread
            obj.thread;
        end

        %% Usage    : quit()
        %
        %  Function : deletes DataLabellingTool
        %             close all plots
        %             deletes all timers
        %             deletes all variables in base workspace that points to DataLabellingTool
        function quit(obj)
            delete(obj.Thread);
            evalin('base', 'close all');
            evalin('base', 'delete(timerfindall)');
            delete(obj);
            var = evalin('base', 'who');
            for i = 1:numel(var)
                class = evalin('base', sprintf('whos(''%s'').class', var{i}));
                if strcmp(class, "DataLabellingTool")
                    evalin('base', sprintf('clear %s', var{i}));
                    return
                end
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
            plot = fieldnames(obj.Plots);
            % No plots and running thread
            if (numel(plot) < 1) && obj.Flag
                stop(obj.Thread)
                obj.Flag = 0; % flag stopped thread
                return
            end
            
            % Stopped thread
            if ~obj.Flag
                start(obj.Thread);
                obj.Flag = 1; % flag started thread
            end
            
            % More than 1 plot
            if (numel(plot) > 1)
                % Create array of axes object
                axes = zeros(numel(plot),1);
                for i=1:numel(plot)
                    % Add axes of plots to axes array
                     axes(i) = obj.Plots.(plot{i}).Handle.CurrentAxes;
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
            if isempty(obj.vlc); return; end
            try if isempty(obj.vlc.Current); return; end; catch; return; end
            obj.Time = obj.vlc.Current.Position/1e6;
        end
    end
end