%% FileHandler.m
% Type  : Utility Class (Handles file related services)
% Hardcoded to tailor to DataLabellingTool Properties
% Inherit from DataLabellingTool to overwrite properties
classdef FileHandler < DataLabellingTool
    methods (Static)
        %% Arguments: importFiles(filePath)
        %             (Only .ini or .mat allowed)
        %
        % Function  : Parse .ini, load paths from .ini
        %             Load .mat
        %
        % Output    : struct, format of DataLabellingTool
        function obj = importFiles(filePath, currentData)
            [~, ~, ext] = fileparts(filePath); % Extract file type
          
            % Processing .ini files
            if strcmp(ext, '.ini')
                % Empty fields : DefaultFilePath, SaveFileName, Sensors, Plots
                obj.DefaultFilePath = filePath; 
                obj.SaveFileName    = ""; 
                obj.Sensors         = struct();
                obj.Plots           = struct();
                obj.GroundTruth     = struct();
                
                % Loaded fields:LabelFolderPath, FilePaths, LoadedVersion, Files
                %   Import filepaths parsing .ini file
                [obj.LabelFolderPath, obj.FilePaths, tmpData] = FileHandler.parseIniPaths(filePath, currentData);
                
                %   Load files from parsed filepaths
                obj.Files = FileHandler.loadFiles(obj.FilePaths, tmpData);
                return
            end
            
            % Processing .mat files
            if strcmp(ext, '.mat')
                % Load full struct
                obj = load(filePath,'variable').variable;
                return
            end

            % ERROR: Input file is not .ini or .mat
            ErrorHandler.raiseError('InvalidType',"FileHandler",{".ini",".mat"},which(filePath)).throwAsCaller;
        end
        
        %% Arguments: parseIniPaths(filePath)
        %
        %  Function : Parse .ini, put in sections
        %
        %  Output   : LabelFolder, FilePaths, tmpData
        %             Note: tmpData is temporary Files section. 
        %                   It stores SensorFiles, VideoFiles, and ClassList
        %                   It is now tmp because SensorFiles and VideoFiles are
        %                   not yet loaded in, it cannot be a full files section.
        %                   tmpData will be passed into loadFiles() to load
        %                   SensorFiles and VideoFiles.
        function [LabelFolderPath, FilePaths, tmpData] = parseIniPaths(filePath, currentData)
            disp(currentData)
            fileID  = fopen(filePath, 'r'); % fileID of input filepath
            
            % List of sections allowed
            validSections = {'SensorFiles', 'VideoFiles', 'LabelFolder', 'ClassList', 'Offset'};

            % Read every line of the ini file
            while ~feof(fileID)
                line = strtrim(fgetl(fileID));
                % Check for comment headers, skip loop
                if isempty(line) || startsWith(line, '#'); continue; end

                % Check for section headers, Check for section name
                if startsWith(line, '[') && endsWith(line, ']')
                    currentSection = strtrim(line(2:end-1)); % Store current section
                    
                    % If not valid section, current section = 'NULL', continue next line
                    if ~ismember(currentSection, validSections); currentSection = 'NULL'; continue; end
                    
                    % If [LabelFolder], continue next line
                    if strcmp(currentSection, 'LabelFolder'); continue; end
                    
                    % If [ClassList], create hashmap, continue next line
                    if strcmp(currentSection, 'ClassList'); tmpData.(currentSection) = containers.Map; continue; end
                    
                    % If [SensorFiles] or [VideoFiles], create section field with struct, continue next line
                    tmpData.(currentSection) = struct(); continue;
                end
                
                % Check for Key-Value pairs, Skip for 'NULL' sections
                if contains(line, '=') && ~strcmp(currentSection, 'NULL')
                    valueIdx = strfind(line, '=');                           % Find '=' position
                    key      = strtrim(line(1:valueIdx(1)-1));               % Parse Key before '='
                    value    = strtrim(erase(line(valueIdx(1)+1:end), '"')); % Parse Value after '='
                    
                    % Process 'Offset'
                    if strcmp(currentSection, 'Offset')
                        tmpData.Offset.(key) = value; continue;
                    end
                
                    % Process 'LabelFolder' 
                    if strcmp(currentSection,'LabelFolder')
                        LabelFolderPath = value; continue; 
                    end
                
                    % Process 'ClassList'
                    if strcmp(currentSection, 'ClassList')

                        % If Not a number, throw error
                        if isnan(str2double(key))
                            ErrorHandler.raiseError('InvalidClass', 'FileHandler', key, value, currentSection).throwAsCaller;
                        end

                        % If is number assign class
                        tmpData.ClassList(key) = value; continue;
                    end
                    
                    % Process 'SensorFiles', 'VideoFiles'
                    % If Not a valid variable name, throw error
                    if ~isvarname(key)
                        ErrorHandler.raiseError('InvalidKey', 'FileHandler', key, currentSection).throwAsCaller;
                    end

                    % Assign values to key field
                    FilePaths.(currentSection).(key) = value;
                end
            end
            fclose(fileID);
        end
        
        %% Arguments: loadFiles(filePath)
        %
        %  Function : fetch parsed filepaths
        %             load available filepaths
        %
        %  Output   : Files (SensorFiles, VideoFiles, ClassList)
        function Files = loadFiles(FilePaths, tmpData)
            sections = fieldnames(FilePaths);  % Get section names (e.g., [SensorFiles], [VideoFiles])
        
            % Loop over each section (e.g., SensorFiles, VideoFiles)
            for i = 1:numel(sections)
                sectionStruct = FilePaths.(sections{i});  % Get the struct of the current section
                subFields = fieldnames(sectionStruct);    % Get the subfields (e.g., filenames)
                
                % Loop over each file in the section
                for j = 1:numel(subFields)
                    filePath = sectionStruct.(subFields{j});  % Get the file path
                    tmpData = FileHandler.categorise(filePath, subFields{j}, tmpData);  % Categorize the file
                end
            end
            
            Files = tmpData;  % Return the modified data
        end

            
        %% Arguments: categorise(filePath, name, tmpData)
        %
        %  Function : load filepaths according to their file types
        %             add loaded data into tmpData
        %
        %  Output   : Files (SensorFiles, VideoFiles, ClassList)
        function newData = categorise(filePath, name, tmpData)
            sensorFileTypes = {'.csv', '.xlsx', '.mat'};
            videoFileTypes  = {'.mp4', '.MP4'};
            
            % Skip empty file paths
            if isempty(filePath); return; end
            
            % If not file/not accessible, throw error
            if ~isfile(filePath)
                ErrorHandler.raiseError('InvalidFile', 'FileHandler', filePath).throwAsCaller;
            end

            % Get file extension of file
            [~, ~, ext] = fileparts(filePath);

            if ~ismember(ext, [sensorFileTypes videoFileTypes])
                % Not of expected type, throw error
                ErrorHandler.raiseError('InvalidType','FileHandler:FileImport', [sensorFileTypes videoFileTypes], filePath).throwAsCaller;
            end
            
            % Check if the file is a sensor file (.csv, .xlsx, .mat)
            if ismember(ext, sensorFileTypes)
                disp(['Sensor file detected: ', filePath]);

                if strcmpi(name, "")
                    try
                        name = append("SensorFile", string(numel(fieldnames(tmpData.SensorFiles)) + 1 ));
                    catch
                        name = "SensorFile1";
                    end
                end

                % Process .mat files
                if strcmpi(ext, '.mat')
                    tmp = load(filePath);
                    tmpData.SensorFiles.(name) = tmp.Tbl;
                    disp(tmpData.SensorFiles);
                    newData = tmpData;
                    return
                end

                % Process .csv, .xlsx
                tmpData.SensorFiles.(name) = readtable(filePath, 'VariableNamingRule', 'preserve');
                disp(tmpData.SensorFiles);
                newData = tmpData;
                return;
            end

            % Check if the file is a video file (.mp4, .MP4)
            if ismember(ext, videoFileTypes)
                disp(['Video file detected: ', filePath]);
                
                if strcmpi(name, "")
                    try
                        name = append("VideoFile", string( numel(fieldnames(tmpData.VideoFiles)) + 1 ));
                    catch
                        name = "VideoFile1";
                    end
                end

                % Process VideoFiles
                tmpData.VideoFiles.(name) = filePath;
                disp(tmpData.VideoFiles);
                newData = tmpData;
                return;
            end
        end
        
        %% Arguments: newLabelFile(caller)
        %
        %  Function : creates a clean set of labels for all sensors
        %             overwrites current sensor labels to 'Undefined'
        %             Tests if caller.saveName is empty, prompts new file name
        function newLabelFile(caller)
            sensors     = caller.Sensors;
            sensorNames = fieldnames(caller.Sensors);
            for i=1:numel(sensorNames)
                currentSensor = sensorNames{i};
                sensors.(currentSensor).Label = zeros(height(sensors.(currentSensor)), 1);
                sensors.(currentSensor).Class = repmat("Undefined", height(sensors.(currentSensor)), 1);
            end
        end

        %% Arguments: saveFile(caller, variable, fileName)
        %             saveFile(caller, variable, fileName, folderPath)
        %
        %  Function : Saves given variable in a .mat file
        %             Tests if caller.saveName is empty, prompts new file name
        %
        %  Output   : A save file in 'FILENAME_dd-MM-yyyy_HH-mm-ss'
        %                            'FOLDER/FILENAME_dd-MM-yyyy_HH-mm-ss'
        function saveFile(caller, variable, varargin)
            % Declare local variables
            time        = datetime("now");
            time.Format = ('dd-MM-yyyy_HH-mm-ss');
            
            % Switch number of arguments
            switch numel(varargin)
                case 1 % saveFile(caller, variable, saveName)
                    saveName = varargin{1};
                    % Update path to 'FILENAME_dd-MM-yyyy_HH-mm-ss'
                    filePath = append(saveName, '_', char(time));
                
                case 2 % saveFile(caller, variable, saveName, folderPath)
                    saveName   = varargin{1};
                    folderPath = varargin{2};

                    % if saveName is empty, prompt for new saveName
                    if strcmpi(saveName, "")
                        caller.EditFlag = false;
                        fileName = "saveFile";
                        caller.SaveFileName = fileName{1};
                        saveName = fileName{1};
                    end
                    % Update path to 'FOLDER/FILENAME_dd-MM-yyyy_HH-mm-ss'
                    filePath = fullfile(folderPath, append(saveName, '_', char(time)));
                otherwise
            end
            save(filePath, 'variable');
            fprintf('Saved File Path: %s\n',filePath);
        end

        %% Arguments: loadLabel(caller, filePath)
        % 
        %  Function : loads specified label file to available sensors
        function loadLabel(caller, filePath)
            % Declare local variables
            tmp         = load(filePath, 'variable'); % Load from save
            sensorNames = fieldnames(tmp.variable);   % Get fields from save
            % Loop over fields
            for i=1:numel(sensorNames)
                currentSensor = sensorNames{i};
                
                % if current instance does not include sensor in save, skip field
                if ~isfield(caller.Sensors, currentSensor)
                    warning("[%s] NOT imported, No sensor is named %s in this instance.", currentSensor, currentSensor);
                    continue;
                end
                
                % Overwrite current sensors
                caller.Sensors.(currentSensor).Label = tmp.variable.(currentSensor).Label;
                caller.Sensors.(currentSensor).Class = tmp.variable.(currentSensor).Class;
            end
            
            caller.GroundTruth = tmp.variable;
            % Update loaded version
            caller.LoadedVersion = filePath;
        end
    end
end