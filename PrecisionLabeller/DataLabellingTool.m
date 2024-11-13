%% DatalabellingTool.m
% Written by David Chui
% Version == 1.4.0

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
%% Instantiator
%   init()

%% Deconstructor
%   quit(obj)

%% Files
%   loadFiles(obj, filePath)
%   import(obj, varargin)
%   removeFiles(obj, fileName)
%   savePreset(obj, fileName)

%% Sensors
%   addSensors(obj, varargin)
%   removeSensors(obj, sensorName)
%   changeTimeRow(obj, sensorName, newCol)

%% Change Properties
%   changeSaveName(obj)
%   changeLabelFolder(obj)

%% Offset
%   changeOffset(obj, videoName, offset, varargin)
%   removeOffset(obj, name)

%% ClassList
%   changeClassList(obj, key, value)
%   removeClassList(obj, key)

%% Plots
%   plot(obj, plotName, sensorName, col)
%   removePlot(obj, plotName)

%% Label Files
%   newLabelFile(obj)
%   loadLabelFile(obj, fileName)
%   saveLabelFile(obj)

%% Videos
%   play(obj, fileName)
%   syncVideo(obj, fileName)

%% Features
%   select(obj)
%   deselect(obj)
%   edit(obj)
%   exportFeatures(obj)

% Use 'd = DataLabellingTool.init' to instantiate
% DataLabellingTool() constructor is restricted to prevent new instance
classdef DataLabellingTool < handle
    %% Public properties, Not writable by users
    properties (SetAccess = protected, SetObservable = true) % Oberservable for listeners
        Version         char      = "1.4.1"
        DefaultFilePath char      = ""           % Default .ini file path
        FilePaths       struct    = struct()     % Struct for all file paths referenced in default.ini
        Files           struct    = struct()     % Data loaded from DataPath
        LabelFolderPath char      = ""           % Label folder path
        LoadedVersion   char      = ""           % Current loaded label version
        SaveFileName    char      = "SaveFile"   % Label Save File Name (Format: FILENAME_DD-MM-YYYY_HH-MM-SS.mat)
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
    % Listeners are declared from 'd.init'
    properties (Access = protected, Transient = true)
        Listeners                            % Observers for callback from different changes
    end

    %% (Private) Constructor
    methods (Access = private)
        % Restricts creating new instance
        function obj = DataLabellingTool()
            % Declare listeners for this new obj
            obj.Listeners{1} = addlistener(obj, 'LoadedVersion','PostSet', @(~, ~)PlotManager.updateLabel(obj, 1));
            obj.Listeners{2} = addlistener(obj, 'Time','PostSet', @(~, ~)PlotManager.updateIndicator(obj, obj.Time));
            % Set default Thread as timer function
            obj.Thread = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode','drop', ...
                'Period', 0.05, ...
                'TimerFcn', @(~, ~)update(obj), ...
                'Name', 'UpdateVideoTime');
            % Fixed rate timer calls obj.update every 0.05s
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
            
            % Create new instance if none is created
            % Check if instance already exist
            if isempty(uniqueInstance) || ~isvalid(uniqueInstance)
                % If no instance was available
                obj = DataLabellingTool(); % Instantiate DataLabellingTool
                uniqueInstance = obj;      % Store new instance as current instance
                return
            end
            obj = uniqueInstance;  % Return current instance
        end
    end

    %% (Public) Methods
    methods
        %% Usage    : quit()
        %
        %  Function : deletes DataLabellingTool (Deconstructor)
        %             close all plots
        %             deletes all added timers
        %             deletes all variables in base workspace that points to DataLabellingTool
        function quit(obj)
            % Delete Plots
            evalin('base', 'close all');
            pause(1);   % Wait for plots to close
            
            % Delete timer objects
            % Try stop timers, if available
            try evalin('base', "stop(timerfind('Name','UpdateVideoTime'))"); catch; end
            evalin('base', "delete(timerfind('Name','UpdateVideoTime'))");
            
            % Delete DataLabellingTool
            delete(obj);
            % Delete variables that point to DataLabellingTool
            var = evalin('base', 'who');
            % For all related variables, delete
            for i = 1:numel(var)
                % Find related variables
                class = evalin('base', sprintf('whos(''%s'').class', var{i}));
                % If related to DataLabellingTool, delete
                if strcmp(class, "DataLabellingTool")
                    % Delete variable by "clear [VAR]"
                    evalin('base', sprintf('clear %s', var{i}));
                    
                    % Debug message
                    fprintf('Variable "%s" pointing at DataLabellingTool is deleted.\n', var{i});
                end
            end
            
            % Debug message
            disp('DataLabellingTool has been deleted.');
        end

        %% Usage(2): loadFiles()             default Input: "default.ini"
        %          : loadFiles(filePath)
        %
        % Function : load files from type .ini or .mat
        %            Parse an .ini and load corresponding filepaths
        %            Load a .mat and load corresponding variables
        function loadFiles(obj, filePath)
            % Argument validation to set default
            arguments (Input)
                obj      {mustBeA(obj,"DataLabellingTool")}
                filePath {mustBeFile} = "default.ini" % Default filepath as "default.ini"
            end            
            % Return newly constructed obj
            loadedObj = FileHandler.importFiles(obj, filePath, obj.Files); % Calling FileHandler
            % Overwrite current properties
            obj.DefaultFilePath = loadedObj.DefaultFilePath;
            obj.FilePaths       = loadedObj.FilePaths;
            obj.Files           = loadedObj.Files;
            obj.LabelFolderPath = loadedObj.LabelFolderPath;
            obj.SaveFileName    = loadedObj.SaveFileName;
            obj.Sensors         = loadedObj.Sensors;
            obj.Plots           = loadedObj.Plots;
            obj.GroundTruth     = loadedObj.GroundTruth;
            % Debug display
            disp(obj);
        end
        
        %% Usage(2): import()       default: prompts file path through gui
        %            import(filePaths)
        %
        % Function : import specified files into respective fields according
        %            to the file type
        function import(obj, varargin)
            % varargin is used, for if the user wants to import multiple file paths.
            
            % Check for input type
            % No specified file path, open GUI
            if numel(varargin) == 0
                [fileName, dir] = uigetfile({'*.csv; *.xlsx; *.mat; *.mp4; *.MP4'}, 'MultiSelect', 'on');
                disp(fileName)
                % fileName is a string if single selected
                % fileName becomes a cell() if multiselected
                % dir is a string, 
                % NOTE: this folder path should apply to all files since uigetfile only allows selecting within same folder.
            % Received specified file paths
            else
                dir = "";
                fileName = varargin;
                % fileName is a cell(), even if there's only 1 input
                % dir is nothing, it depends on user input (varargin)
            end
            
            % Single File Import (from uigetfile)
            if ~iscell(fileName)
                filePath = fullfile(dir, fileName); % Create full file path
                obj.Files = FileHandler.categorise(filePath, "", obj.Files); % Calling FileHandler
                return
            end
            
            % Multiple File Import (from uigetfile or varargin)
            % For all input file paths, let FileHandler handle it
            for i=1:numel(fileName)
                filePath = fullfile(dir, fileName{i}); % Create full file path
                obj.Files = FileHandler.categorise(filePath, fileName{i}, obj.Files); % Calling FileHandler
            end
        end
        
        %% Usage   : removeFiles(fileName)
        %
        % Function : remove specified imported files from DataLabellingTool
        function removeFiles(obj, fileName)
            % Declare all fieldnames
            fields = fieldnames(obj.Files); % It's a cell()
            
            % For all fields in d.Files, search for given fileName, remove first found
            for i=1:numel(fields)
                % Found field matching fileName
                if isfield(obj.Files.(fields{i}), fileName)
                    % Remove field by rmfield()
                    obj.Files.(fields{i}) = rmfield(obj.Files.(fields{i}), fileName);
                    
                    % Debug messages
                    fprintf("Current %s: \n", fields{i});
                    disp(obj.Files.(fields{i}));
                    return % Stop search
                end
            end

            % File name not found, throw error
            ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "Files", fileName, [fieldnames(obj.Files.SensorFiles) fieldnames(obj.Files.VideoFiles)]).throw;
        end

        %% Usage(2): savePreset()          default Input: "preload"
        %          : savePreset(fileName)
        %
        % Function : saves current instance properties in given fileName
        %            saves file as 'CURRENT_FOLDER/FILENAME_dd-MM-yyyy_HH-mm-ss.mat'
        function savePreset(obj, fileName)
            % Argument validation to set default
            arguments
                obj      {mustBeA(obj,"DataLabellingTool")}
                fileName string = "preload" % Default file Name as "preload"
            end
            FileHandler.saveFile(obj, obj, fileName); % Calling File Handler
        end
       
        %% Usage(5): addSensors()           default Input: ALL SensorFiles
        %            addSensors(sensorFileName)
        %            addSensors(sensorFileName, newSensorName)
        %            addSensors(sensorFileName, newSensorName, columnsInFile)
        %
        % Function : add a new sensor to struct from specified columns of SensorFiles
        %            defaults to adding all SensorFiles as individual sensors
        %            if no input is given
        function addSensors(obj, varargin)
            obj.Sensors = SensorManager.addSensors(obj.Sensors, obj.Files.SensorFiles, varargin{:}); % Calling SensorManager
            
            % Debug display
            disp("Current Sensors:");
            disp(obj.Sensors);
            
            % Check if there are VideoFiles
            % if Not, skip
            if ~isfield(obj.Files, "VideoFiles"); return; end
            if isempty(fieldnames(obj.Files.VideoFiles)); return; end
            
            % Sync offsets to respective sensors according to 1st Imported Video
            % Get the first video file name
            firstVideoFile = fieldnames(obj.Files.VideoFiles);
            SensorManager.syncVideo(obj, obj.Sensors, firstVideoFile{1}); % Calling SensorManager
            
            % Debug message
            fprintf("All Sensors are now synced to Video File '%s'.\n", firstVideoFile{1});
        end

        %% Usage   : removeSensors(sensorName)
        %
        % Function : removes a sensor from Sensor struct
        %            returns new Sensors struct
        function removeSensors(obj, sensorName)
            % Argument Validation to check for valid sensorName
            arguments
                obj        {mustBeA(obj,"DataLabellingTool")}
                sensorName {mustBeText}
            end
            obj.Sensors = SensorManager.removeSensors(obj.Sensors,sensorName); % Calling SensorManager
            
            % Debug display
            disp("Current Sensors:");
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
            % Debug message
            fprintf("\nCurrent Save File Name: %s\n", obj.SaveFileName)

            % Prompt for new name, check for validity by isvarname
            saveName = input("Enter New Save Name: ","s");
            % Not a valid variable name, throw error
            if ~isvarname(saveName)
                ErrorHandler.raiseError("InvalidFileName", "DataLabellingTool", saveName).throw;
                return;
            end
            % A valid name, change current save name
            obj.SaveFileName = saveName;
            
            % Debug display 
            disp(obj);
        end

        %% Usage   : changeLabelFolder()
        %
        % Function : change label (output) folder of tool
        function changeLabelFolder(obj)
            % Debug message
            fprintf("\nCurrent Save File Folder: %s\n", obj.LabelFolderPath)

            % Prompt for new folder, check validity by isfolder()
            folderPath = input("Enter New Folder Path: ","s");
            % Not a valid folder path, throw error
            if ~isfolder(folderPath)
                ErrorHandler.raiseError("InvalidFolder", "DataLabellingTool", folderPath).throw;
                return;
            end
            % Valid folder path, change current folder path
            obj.LabelFolderPath = folderPath;

            % Debug display
            disp(obj);
        end

        %% Usage   : changeOffset(videoName, varargin)
        %
        % Function : change offset for specific video
        function changeOffset(obj, videoName, offset, varargin)
            % Argument Validation to check input argument type
            arguments
                obj       {mustBeA(obj,"DataLabellingTool")}
                videoName string
                offset    double
            end
            % Repeating validation for varargin
            arguments (Repeating)
                varargin % SensorName, only 1 input is allowed
            end
            sensorName = varargin; % For readability

            % Check for valid imported video file name by isfield()
            % Not a valid video, throw error
            if ~isfield(obj.Files.VideoFiles, videoName)
                ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "VideoFiles", videoName, fieldnames(obj.Files.VideoFiles)).throw;
                return;
            end
            
            % Check if only 1 input is given
            % Check for valid imported sensor file name by isfield()
            if numel(sensorName) == 1
                % Not a valid sensor, throw error
                if ~isfield(obj.Files.SensorFiles, sensorName{1})
                    ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "SensorFiles", sensorName{1}, fieldnames(obj.Files.SensorFiles)).throw;
                    return;
                end
                
                % Valid sensor (and video), set offset in d.Files.Offset as 
                % VIDEONAME_SENSORNAME = offset
                obj.Files.Offset.(append(videoName, '_', varargin{1})) = offset;

                % Debug message
                fprintf("\nCurrent Offsets: \n")
                disp(obj.Files.Offset); % display

                % Sync video to all sensors after changing
                obj.syncVideo(videoName);
                return
            end

            % No input sensor name is given, change offset directly
            % VIDEONAME = offset
            obj.Files.Offset.(videoName) = offset;

            % Debug message
            fprintf("\nCurrent Offsets: \n")
            disp(obj.Files.Offset); % display

            % Sync video to all sensors after changing
            obj.syncVideo(videoName);
        end

        %% Usage   : removeOffset(name)
        %
        % Function : removes an offset from Offset struct
        function removeOffset(obj, name)
            % Check if input name is valid offset field by isfield()
            % Not a valid offset field, throw error
            if ~isfield(obj.Files.Offset, name)
                ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "Offset", name, fieldnames(obj.Files.Offset)).throw;
                return;
            end

            % Valid field, remove field by rmfield()
            obj.Files.Offset = rmfield(obj.Files.Offset, name);
            
            % Debug message
            fprintf("\nCurrent Offsets: \n")
            disp(obj.Files.Offset); % display
        end

        function changeClassList(obj, key, value)
            % Argument Validation to check for input type
            arguments
                obj
                key   {mustBeNumeric}
                value string
            end
            % Check if ClassList has initiated
            % if Not, create field
            if ~isfield(obj.Files, "ClassList")
                obj.Files.ClassList = containers.Map;
            end
            
            % Add given input to ClassList
            obj.Files.ClassList(string(key)) = value;
            
            % Debug message
            fprintf("Current ClassList: \n");
            disp(obj.Files.ClassList.keys);   % display
            disp(obj.Files.ClassList.values); % display
        end

        function removeClassList(obj, key)
            % Argument validation on key, numeric
            arguments
                obj
                key   {mustBeNumeric}
            end
            obj.Files.ClassList = remove(obj.Files.ClassList, string(key));

            % Debug message
            fprintf("Current ClassList: \n");
            disp(obj.Files.ClassList.keys);   % display
            disp(obj.Files.ClassList.values); % display
        end
        %% Usage   : plot(plotName, sensorName, columns)
        %            (Note: columns in 'Sensors' to be plotted)
        %
        % Function : plot in a new figure with specified column in sensors
        %            initiate all required data in a plot
        %            including userdata, listeners, callback functions
        function plot(obj, plotName, sensorName, col)
            % Argument Validation to check for input names
            arguments
                obj        {mustBeA(obj,"DataLabellingTool")}
                plotName   {mustBeValidVariableName}
                sensorName {mustBeValidVariableName}
                col
            end
            PlotManager.addPlot(obj, plotName, sensorName, col); % Calling PlotManager

            % Debug display
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

            % Debug display
            disp("Current Plots:");
            disp(obj.Plots);
        end

        %% Usage    : newLabelFile()
        %
        %  Function : creates a new ground truth file
        %             for starting up the first time
        function newLabelFile(obj)
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
            % Declare full file path
            filePath = fullfile(obj.LabelFolderPath,append(fileName,'.mat'));

            % Check for valid file path with isfile()
            % If not a valid file path, throw error
            if ~isfile(filePath)
                ErrorHandler.raiseError("InvalidFile", "DataLabellingTool", filePath).throwAsCaller
                return
            end

            FileHandler.loadLabel(obj, filePath); % Calling FileHandler
        end

        %% Usage    : saveLabelFile()
        %
        %  Function : save the instantaneous ground truth into a .mat file
        function saveLabelFile(obj)
            FileHandler.saveFile(obj, obj.GroundTruth, obj.SaveFileName, obj.LabelFolderPath); % Calling FileHandler
        end

        %% Usage    : play(fileName)
        %
        %  Function : plays the specified video file
        function play(obj, fileName)
            % Argument Validation to check for file name type
            arguments
                obj     {mustBeA(obj,"DataLabellingTool")}
                fileName string
            end
            % Check for valid imported video file by isfield()
            % Not a valid video, throw error
            if ~isfield(obj.Files.VideoFiles, fileName)
                ErrorHandler.raiseError("InvalidField", "DataLabellingTool", "Files.VideoFiles", fileName, fieldnames(obj.Files.VideoFiles)).throwAsCaller
                return
            end
            
            % Valid video, play video path with VLC
            filePath = obj.Files.VideoFiles.(fileName);
            obj.vlc = VLC;
            obj.vlc.play(filePath);
            
            % Calling thread to start or stop thread
            obj.thread;
        end

        %% Usage   : syncVideo()
        %
        % Function : syncs all sensors to specified video
        function syncVideo(obj, fileName)
            SensorManager.syncVideo(obj, obj.Sensors, fileName); % Calling SensorManager
            
            % Debug message
            fprintf("All Sensors are now synced to Video File '%s'.\n", fileName);
        end

        %% Usage    : select()
        %
        %  Function : prompts user to create two roi points on all current plots
        %             syncs position of roi points across all current plots
        %             also highlights region between roi points with gray
        %             to indicate selection
        function select(obj)
            % Stop real-time editing
            obj.EditFlag = false;
            % Try deselect ROI points if available, else do nothing
            try obj.deselect; catch; end
            % If no available plots, do nothing
            if numel(fieldnames(obj.Plots)) == 0; return; end

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
            % Stop real-time editing
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
            % Get all sensor names
            sensors = fieldnames(obj.Sensors);
            % For all sensors, save file to base workspace
            for i=1:numel(sensors)
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
            % Declare local variables
            plotStruct = obj.Plots;
            plotName   = fieldnames(obj.Plots);

            % Check for conditions
            % CASE 1: No plots and running thread
            if (numel(plotName) < 1) && obj.Flag
                stop(obj.Thread)
                obj.Flag = false; % flag stopped thread
                return
            end
            
            % CASE 2: Stopped thread
            if ~obj.Flag
                start(obj.Thread);
                obj.Flag = true; % flag started thread
            end
            % CASE 2 EXTEND: If more than 1 plot available
            if (numel(plotName) > 1)
                % Create array of axes object
                axes = zeros(numel(plotName),1);
                % For all plots, add CurrentAxes to axes array
                for i=1:numel(plotName)
                    % Add axes of plots to axes array
                    axes(i) = plotStruct.(plotName{i}).Handle.CurrentAxes;
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
            % If no video, do nothing
            if isempty(obj.vlc); return; end
             % Double check If no video playing, do nothing
            try if isempty(obj.vlc.Current); return; end; catch; return; end

            % Video available, fetch current time
            % divide by 1e6 because it is in microseconds
            videoTimeSec = obj.vlc.Current.Position / 1e6;
            % If video time has not changed, do nothing
            if obj.Time == videoTimeSec; return; end
            
            % If video time changed, change d.Time
            obj.Time = videoTimeSec;
            % obj.Time decides the when the indicator updates
        end
    end
end