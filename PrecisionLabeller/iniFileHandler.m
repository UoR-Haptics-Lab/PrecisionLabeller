classdef iniFileHandler < handle
    properties (SetObservable = true, SetAccess = private)
        Path                    % default.ini file path
        DataPaths               % Struct for all file paths referenced in default.ini
        Data                    % Data loaded from DataPath
        Offset                  % Offset (dataTime = videoTime + offset)
        VLC                     % VLC Object
        SaveName = ''           % File name for label save files
        LatestVersion           % Latest save file filepath
        LoadedVersion           % Version loaded to workspace
        GroundTruth             % Global Ground Truth for all data
        ClassList               % Class List
        yClassList = 0          % Class List Size
        maxSize = 0
        videoDuration
    end

    methods
        %% Constructor (feeds VLC object, default Filepath)
        function obj = iniFileHandler(filePath, v)
            obj.Path = filePath;
            obj.VLC = v;
            obj.VLC.clear;

            % Check if default file is in .ini
            if ~obj.checkFile(filePath, '.ini', 'DEFAULT')
                return
            end

            % Creates struct according to the .ini
            obj.readIni(filePath);

            % Load label file
            % Skip if inaccessible label version file
            if ~isfile(obj.LatestVersion); return; end

            labelFile = load(obj.LatestVersion);
            obj.LoadedVersion = obj.LatestVersion;
            obj.GroundTruth = labelFile.groundTruth;
        end
        
        %% Load DATA, VIDEO files
        function loadFiles(obj)
            % Initiate struct to store imported data
            obj.Data = struct();
            sections = fieldnames(obj.DataPaths);

            % Import data according to filePaths
            for i = 1:numel(sections)
                % All filePaths within iniFileHandler.DataPaths.(section)
                filePathList = fields(obj.DataPaths.(sections{i}));
                for j = 1:numel(filePathList)
                    filePath = obj.DataPaths.(sections{i}).(filePathList{j});
                    
                    % Check files types (.csv, .mp4)
                    % Skip empty filePaths
                    if isempty(filePath)
                        continue;
                    end
                    
                    % SENSOR files in .csv format
                    if strcmpi(sections{i}, 'SensorFiles')
                        if obj.checkFile(filePath, '.csv', 'SENSOR')
                            obj.Data.(sections{i}).(filePathList{j}) = readtable(filePath);
                            continue;
                        end
                    end
                    
                    % VIDEO files in .mp4 format
                    if strcmpi(sections{i}, 'VideoFiles')
                        if obj.checkFile(filePath, '.mp4', 'VIDEO')
                            obj.VLC.add(filePath);
                            obj.VLC.pause;
                            obj.Data.(sections{i}).(filePathList{j}) = filePath;
                        end
                    end
                    
                    % Offset
                    if strcmpi(sections{i}, 'Offset')
                        % Skip if offset is NaN
                        offset = str2double(obj.DataPaths.Offset.VideoOffset);
                        if isnan(offset)
                            obj.fetchWarning(4, obj.DataPaths.Offset.VideoOffset);
                            continue;
                        end
                        % Store offset value to iniFileHandler.Offset
                        obj.Offset = offset;
                        continue;
                    end
                end
            end
        end
        
        %% Create first label version files
        function newLabelFile(obj)
            sections = fieldnames(obj.Data.SensorFiles);
            tmpMaxSize = 0;
            
            % Find largest dataset height
            for i=1:(numel(sections))                
                tmpSize = height(obj.Data.SensorFiles.(sections{i}));
                if tmpMaxSize > tmpSize
                    continue;
                end
                tmpMaxSize = tmpSize;
            end
            obj.maxSize = tmpMaxSize;

            % Generate uniform values
            videoEndTime = obj.VLC.Current.Length/1e6;                              % video length
            obj.videoDuration = linspace(-obj.Offset, videoEndTime, obj.maxSize)';            % fine video length, size of max dataset height
            Label = zeros(obj.maxSize,1);                                           % Generate initial Null labels

            obj.GroundTruth = table();                                              % iniFileHandler.GroundTruth initiate table
            obj.GroundTruth = addvars(obj.GroundTruth, obj.videoDuration, Label);   % Add Video Duration and Label to iniFileHandler.GroundTruth
            obj.GroundTruth = renamevars(obj.GroundTruth, 'Var1','Time');           % Rename as Time, Label
            obj.GroundTruth = renamevars(obj.GroundTruth, 'Var2','Label');
            disp(obj.GroundTruth);                                                  % Show generate label file
            
            % Save created table, set created version as loaded version
            obj.saveLabelFile();
            obj.LoadedVersion = obj.LatestVersion;
        end

        %% Save new label version files
        function saveLabelFile(obj)
            labelFolder = obj.DataPaths.LabelFolder.LabelFolder;
            % if save folder is present
            if isfolder(labelFolder)
                % if there is no save file name
                if isempty(obj.SaveName)
                    obj.changeSaveName();
                end
                
                % if there is save file name
                time = datetime("now");                                 
                time.Format = ('dd-MM-yyyy_hh-mm-ss');                  % Add datetime to file name
                % Rename save file
                fileName = append(obj.SaveName, '_', char(time), '.mat');
                fileName = fullfile(labelFolder, fileName);
                groundTruth = obj.GroundTruth;
                save(fileName, 'groundTruth');      
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            else
                error('Please select a LABEL folder before saving a file!');
            end
        end
        
        %% Load save label version files
        function loadLabelFile(obj)
           % Imported label folderPath
            labelFolder = obj.DataPaths.LabelFolder.LabelFolder;
            if ~isfolder(labelFolder)
                obj.fetchWarning(3,labelFolder);
                return
            end
            
            % Prompt select label file within label folder, save path
            path = fullfile(labelFolder,'*.mat');
            labelFile = uigetfile(path);
            filePath = fullfile(labelFolder,labelFile);

            % Check if file is valid
            if ~isfile(filePath)
                obj.fetchWarning(1, filePath);
            end
            
            % Load label file
            newFile = load(filePath);
            obj.GroundTruth = newFile.groundTruth;
            obj.LoadedVersion = filePath;
        end
            
        %% Change save name
        function changeSaveName(obj)
            try obj.VLC.pause; catch 
            end
            % Prompt for file name
            input = string(inputdlg('Enter your LABEL file name:', 'Label File Save Name', [1 40]));
            % Check for illegal file char
            if isempty(regexp(input, '[/\\*:;?"<>|]', 'once'))
                obj.SaveName = input;
            else
                error('Error creating label file: Invalid file name!');
            end
        end

        %% Update labels
        function updateLabel(obj, idxRef, idxNow, class)
            if any(obj.GroundTruth.Label(idxRef:idxNow) ~= class)
                obj.GroundTruth.Label(idxRef:idxNow) = class;
            end
        end

        %% Change ClassList
        function changeClassList(obj, classList)
            if iscell(classList)
                obj.ClassList = classList;
                obj.yClassList = 1:size(classList,2);
            end
        end
        
        %% Get latest label version file
        function version = get.LatestVersion(obj)
            % Imported label folderPath
            labelFolder = obj.DataPaths.LabelFolder.LabelFolder;
            if ~isfolder(labelFolder)
                obj.fetchWarning(3,labelFolder);
                version = '';
                return
            end

            fileList = dir(labelFolder);
            % Remove '.' and '..' which are the current and parent directory
            fileList = fileList(~ismember({fileList.name}, {'.', '..'}));
            % Extract modification dates
            modDates = [fileList.datenum];
            % Find index of the most recent file
            [~, idx] = max(modDates);                            
            % Get most recent file
            mostRecentFile = fileList(idx);
            % Get full path to the most recent file
            mostRecentFilePath = fullfile(labelFolder, mostRecentFile.name);
    
            if ~isfolder(mostRecentFilePath)
                version = mostRecentFilePath;
            end

        end
    end

    methods (Access = private)
        %% Check if given file is given format
        function supported = checkFile(obj, filePath, format, type)
            % Check if file is available
            if ~isfile(filePath)
                supported = false;
                obj.fetchWarning(1, filePath); % Warning: File Not Accessible
                return;
            end
            
            % Extract file parts for format check
            [~, ~, ext] = fileparts(filePath);

            % Check if file is said format
            if ~strcmpi(ext, format)
                supported = false;
                obj.fetchWarning(2, filePath, format, type) % Warning: File is not in said format!
                return;
            end
            
            % If file is of said format
            supported = true;
        end
        
        %% Read .ini and store as struct
        function readIni(obj, filePath)
            obj.DataPaths = struct();       % Initiate struct for import data
            fileID = fopen(filePath, 'r');
            
            % Read every line of ini file
            currentSection = 'Null';
            while ~feof(fileID)
                line = strtrim(fgetl(fileID)); % Remove lead/trailing whitespaces
                % Empty lines
                if isempty(line)               
                   continue;
                end
                % '#' comment lines
                if (line(1) == '#')
                    continue;
                end
                
                % '[' ']' Section indicator
                if startsWith(line, '[') && endsWith(line, ']')
                    % Extract section name
                    currentSection = strtrim(line(2:end-1));
                    % Process ClassList separately
                    if strcmpi(currentSection, 'ClassList')
                        continue;
                    end
                    % Create field for new section
                    obj.DataPaths.(currentSection) = struct();
                end
                
                % Fields Key-value pairs
                if contains(line, '=')
                    valueIdx = strfind(line, '=');                % Separator '=' index
                    key = strtrim(line(1:valueIdx(1)-1));         % Extract Key, string before '='
                    value = strtrim(line(valueIdx(1)+1:end));     % Extract Value, string after '='
                    % Process ClassList separately as 1D cells
                    if strcmpi(currentSection, 'ClassList')
                        obj.ClassList{str2double(key)} = value;
                        obj.yClassList = 1:size(obj.ClassList,2);
                        continue;
                    end
                    value = erase(value,'"');                     % Erase " to clean up filePaths
                    obj.DataPaths.(currentSection).(key) = value; % Assign Key-Value pairs
                end
            end
            fclose(fileID);
        end

        % Display Warnings
        function fetchWarning(~, code, varargin)
            switch code
                case 1  % (1, filePath)
                    warning("File not accessible! (Error Code 1)\n(Imported File Path: %s)\n", varargin{1});
                case 2 % (2, filePath, format, type)
                    warning("Imported %s file is not in %s format! (Error Code 2)\n(Imported File Path: %s)\n", varargin{3}, varargin{2}, varargin{1});
                case 3 % (3, folderPath)
                    warning("Imported LABEL folder is not accessible! (Error Code 3)\n(Imported Folder Path: %s)\n", varargin{1});
                case 4 % (4, offset)
                    warning("Imported Offset is NaN! (Error Code 4)\n(Imported Offset: %s)\n", varargin{1});
                otherwise
                    return
            end
        end
    end
end
