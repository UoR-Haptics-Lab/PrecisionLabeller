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
        function obj = importFiles(filePath)
            [~,~,ext] = fileparts(filePath); % Extract file type
          
            % Processing .ini files
            if strcmp(ext, '.ini')
                % Empty fields : DefaultFilePath, SaveFileName, Sensors, Plots
                obj.DefaultFilePath = filePath; obj.SaveFileName = ""; obj.Sensors = struct(); obj.Plots = struct();
                
                % Loaded fields:LabelFolderPath, FilePaths, LoadedVersion, GroundTruth, Files
                %   Import filepaths parsing .ini file
                [obj.LabelFolderPath, obj.FilePaths, tmpData] = FileHandler.importIniPaths(filePath);
                %   Load ground truth from parsed folderpath
                [obj.LoadedVersion, obj.GroundTruth]          = FileHandler.loadLatestLabel(obj.LabelFolderPath);
                %   Load files from parsed filepaths
                obj.Files                                     = FileHandler.loadFiles(obj.FilePaths, tmpData);
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
        
        %% Arguments: importIniPaths(filePath)
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
        function [LabelFolderPath, FilePaths, tmpData] = importIniPaths(filePath)
            tmpData      = struct();             % tmp struct
            fileID       = fopen(filePath, 'r'); % fileID of input filepath
            videoFileIdx = 0;                    % Idx to scan for Offset data
            
            % List of sections allowed
            validSections = {'SensorFiles', 'VideoFiles', 'LabelFolder', 'ClassList'};

            % Read every line of the ini file
            while ~feof(fileID)
                line = strtrim(fgetl(fileID));
                % Check for comment headers, skip loop
                if isempty(line) || startsWith(line, '#'); continue; end

                % Check for section headers, Check for section name
                if startsWith(line, '[') && endsWith(line, ']')
                    currentSection = strtrim(line(2:end-1)); % Store current section
                    % If not valid section, current section = 'NULL', contiue next line
                    if ~ismember(currentSection, validSections); currentSection = 'NULL'; continue; end
                    % If [LabelFolder], contiue next line
                    if strcmp(currentSection, 'LabelFolder'); continue; end
                    % If [ClassList], create hashmap, contiue next line
                    if strcmp(currentSection, 'ClassList'); tmpData.(currentSection) = containers.Map; continue; end
                    % If [SensorFiles] or [VideoFiles], create section field with struct, contiue next line
                    tmpData.(currentSection) = struct(); continue;
                end
                
                % Check for Key-Value pairs, Skip for 'NULL' sections
                if contains(line, '=') && ~strcmp(currentSection, 'NULL')
                    valueIdx = strfind(line, '=');                           % Find '=' position
                    key      = strtrim(line(1:valueIdx(1)-1));               % Parse Key before '='
                    value    = strtrim(erase(line(valueIdx(1)+1:end), '"')); % Parse Value after '='
                    
                    % Process 'VideoFiles' Offset
                    if strcmp(currentSection, 'VideoFiles')
                        % If Not first file, Key same as previous Key,Value is numeric
                        if videoFileIdx > 0 && strcmp(currentVideo, key) && isnumeric(str2double(value))
                            % Set Key name is 'KEY_Offset', Assign offset value
                            tmpData.VideoFiles.(append(key,'_Offset')) = str2double(value);
                            videoFileIdx                               = videoFileIdx + 1; % Update index
                            continue;
                        end
                        videoFileIdx = videoFileIdx + 1; % Update index as well, if nothing happens
                        currentVideo = key;              % Update 'previous' key
                    end
                
                    % Process 'LabelFolder' 
                    if strcmp(currentSection,'LabelFolder'); LabelFolderPath = value; continue; end
                
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
        
        %% Arguments: loadLatestLabel(LabelFolderPath)
        %
        %  Function : Find latest file in label folder
        %             Load found latest file
        %
        %  Output   : LoadedVersion, GroundTruth
        function [LoadedVersion, GroundTruth] = loadLatestLabel(LabelFolderPath)
            fileList = dir(LabelFolderPath);
            % Remove '.' and '..' which are the current and parent directory
            fileList = fileList(~ismember({fileList.name}, {'.', '..'}));
            % Skip empty file list
            if isempty(fileList); GroundTruth = timetable(); LoadedVersion = ""; return; end
            
            
            modDates           = [fileList.datenum];  % Extract modification dates
            [~, idx]           = max(modDates);       % Find index of the most recent file
            mostRecentFile     = fileList(idx);       % Get most recent file
            mostRecentFilePath = fullfile(LabelFolderPath, mostRecentFile.name);
            
            % If Not a folder, load file, store ground truth
            if ~isfolder(mostRecentFilePath)
                tmp = load(mostRecentFilePath, 'variable');
                
                if ~istimetable(tmp.variable)   % Not Timetable
                    GroundTruth = timetable();  % Return empty
                else                            % Is Timetable
                    GroundTruth = tmp.variable; % Return loaded
                end

                LoadedVersion = mostRecentFilePath;
                disp("Current Loaded Version: ");
                disp(LoadedVersion)
            end
        end

        %% Arguments: loadFiles(filePath)
        %
        %  Function : fetch parsed filepaths
        %             load available filepaths
        %
        %  Output   : Files (SensorFiles, VideoFiles, ClassList)
        function Files = loadFiles(FilePaths, tmpData)
            % section is [SensorFiles], [VideoFiles]
            section = fieldnames(FilePaths);
            % Loop over each section
            for i = 1:numel(section)
                sectionStruct = FilePaths.(section{i});    % struct of section
                subFields     = fieldnames(sectionStruct); % fieldnames of struct
                
                % Loop over each struct
                for j = 1:numel(subFields)
                    fieldName = subFields{j};
                    filePath = sectionStruct.(fieldName);
                    if contains(fieldName,'Offset'); continue; end
                    % Call the categorisation function
                    categorise(filePath, fieldName, section{i});
                end
            end
            
            % Nested function to categorise files based on their extensions
            % (Private)
            function categorise(filePath, fieldName, field)
                sensorFileTypes = {'.csv', '.xlsx', '.mat'};
                videoFileTypes = {'.mp4', '.MP4'};
                % Skip empty file paths
                if isempty(filePath); return; end
                % If not file/not accessible, throw error
                if ~isfile(filePath)
                    ErrorHandler.raiseError('InvalidFile', 'FileHandler', filePath).throwAsCaller;
                end
                % Get file extension of file
                [~, ~, ext] = fileparts(filePath);
                
                % Check if the file is a sensor file (.csv, .xlsx)
                if strcmp(field, "SensorFiles")
                    if ismember(ext, sensorFileTypes)
                        disp(['Sensor file detected: ', filePath]);
                        if strcmpi(ext, '.mat'); tmpData.SensorFiles.(fieldName) = load(filePath);
                        else; tmpData.SensorFiles.(fieldName) = readtable(filePath, 'VariableNamingRule', 'preserve');
                        end
                    else % Not of type, throw error
                        ErrorHandler.raiseError('InvalidType','FileHandler:SensorFiles', sensorFileTypes, filePath).throwAsCaller;
                    end
                end

                % Check if the file is a video file (.mp4, .MP4)
                if strcmp(field, "VideoFiles") 
                    if ismember(ext, videoFileTypes)
                        disp(['Video file detected: ', filePath]);
                        tmpData.VideoFiles.(fieldName) = filePath;  % Store the video file path
                        return;
                    else % Not of type, throw error
                        ErrorHandler.raiseError('InvalidType','FileHandler:VideoFiles', videoFileTypes, filePath).throwAsCaller;
                    end
                end
            end
        
            % Return modified tmpData structure
            Files = tmpData;
        end
        
        %% Arguments: newLabelFile(caller)
        %
        %  Function : Generates new label file
        %             Find Largest Sensor size
        %             Create a timetable of found size
        %               (Label:0, Class:'Undefined')
        %             Save new label file, Output new timetable
        %             Update loaded version
        function newLabelFile(caller)
            sensors = fieldnames(caller.Sensors);
            maxSize = 0;
            
            % Find largest dataset height
            for i=1:(numel(sensors))            
                tmpSize = height(caller.Sensors.(sensors{i}));
                if maxSize > tmpSize % Skip if size is less than max
                    continue;
                end
                % Save current size as max size if larger than max
                maxSize = tmpSize;
                timeCol = caller.Sensors.(sensors{i}).Properties.DimensionNames{1};
                maxTime = caller.Sensors.(sensors{i}).(timeCol)(maxSize);
            end

            % Generate uniform values
            Time = linspace(0, maxTime, maxSize)';
            Label = zeros(maxSize,1); % Generate initial Null labels
            Class = repmat("Undefined",maxSize,1);
            % Create a new timetable
            groundTruth = timetable(Label, Class, 'RowTimes', Time);
            % Save new label file
            FileHandler.saveFile(caller, groundTruth, caller.SaveFileName, caller.LabelFolderPath);
            % Set new file as loaded version
            caller.GroundTruth = groundTruth;
            caller.LoadedVersion = fullfile(caller.LabelFolderPath,caller.SaveFileName);
        end
        
        %% Arguments: saveFile(caller, variable, fileName)
        %             saveFile(caller, variable, fileName, folderPath)
        %
        %  Function : Saves given variable in a .mat file
        %             Tests if caller.saveName is empty, prompts new file name
        function saveFile(caller, variable, varargin)
            time        = datetime("now");                                 
            time.Format = ('dd-MM-yyyy_HH-mm-ss');
            switch numel(varargin)
                case 1 % (caller, variable, folderPath)
                    filePath = append(varargin{1},'_',char(time)); % 'FILENAME_dd-MM-yyyy_HH-mm-ss'
                case 2 % (caller, variable, caller.saveName, folderPath)
                    if ~strcmp(varargin{1},"")
                        % 'FOLDER/FILENAME_dd-MM-yyyy_HH-mm-ss'
                        filePath            = fullfile(varargin{2},append(varargin{1}, '_', char(time)));
                    else
                        % 'FOLDER/FILENAME_dd-MM-yyyy_HH-mm-ss'
                        fileName            = input("Enter File Name: ",'s');
                        caller.SaveFileName = fileName;
                        filePath            = fullfile(varargin{2},append(fileName, '_', char(time)));
                    end
                otherwise
            end
            save(filePath,'variable');
            fprintf('Saved File Path: %s\n',filePath);
        end
    end
end