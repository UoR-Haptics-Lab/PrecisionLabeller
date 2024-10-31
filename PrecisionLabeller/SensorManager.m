%% SensorManager.m
% Type  : Utility Class (Handles sensor related services)
% Hardcoded to tailor to DataLabellingTool Properties
classdef SensorManager < DataLabellingTool
    methods (Static)
        %% Arguments: addSensors(currentStruct, sensorFile)
        %             addSensors(currentStruct, sensorFile, sensorFileName)
        %             addSensors(currentStruct, sensorFile, sensorFileName, newSensorName)
        %             addSensors(currentStruct, sensorFile, sensorFileName, newSensorName, columnsInFile)
        %  Function : add new sensors to given sensor struct
        %             allows option to define sensor names, select sensor file, and pick columns
        function newStruct = addSensors(currentStruct, sensorFiles, varargin)
            switch numel(varargin)
                case 0 % addSensors(currentStruct, sensorFiles)
                    sensor = fieldnames(sensorFiles); % Find available sensorFiles
                    for i=1:numel(sensor)
                        sensorFileName = sensor{i};
                        currentStruct.(sensorFileName) = sensorFiles.(sensorFileName);                     % Copy to new struct
                        currentStruct.(sensorFileName) = convertTimeCol(currentStruct.(sensorFileName));   % Find time column automatically
                        currentStruct.(sensorFileName).Properties.UserData{1} = sensorFileName;
                        currentStruct.(sensorFileName).Properties.UserData{2} = 0;
                        currentStruct.(sensorFileName).Label = zeros(height(currentStruct.(sensorFileName)), 1);
                        currentStruct.(sensorFileName).Class = repmat("Undefined", height(currentStruct.(sensorFileName)), 1);
                    end
                
                case 1 % addSensors(currentStruct, sensorFiles, sensorFileName)
                    sensorFileName = varargin{1};
                    currentStruct.(sensorFileName) = sensorFiles.(sensorFileName);                     % Copy selected file to new struct
                    currentStruct.(sensorFileName) = convertTimeCol(currentStruct.(sensorFileName));   % Find time column automatically
                    currentStruct.(sensorFileName).Properties.UserData{1} = sensorFileName;
                    currentStruct.(sensorFileName).Properties.UserData{2} = sensorFileName;
                    currentStruct.(sensorFileName).Label = zeros(height(currentStruct.(sensorFileName)), 1);
                    currentStruct.(sensorFileName).Class = repmat("Undefined", height(currentStruct.(sensorFileName)), 1);
                
                case 2 % addSensors(currentStruct, sensorFiles, sensorFileName, newSensorName)
                    sensorFileName = varargin{1};
                    if ~isfield(sensorFiles,string((sensorFileName))); ErrorHandler.raiseError('InvalidField','SensorManager', varargin{1}, fieldnames(sensorFiles)); end

                    newSensorName = varargin{2};
                    currentStruct.(newSensorName) = sensorFiles.(sensorFileName);                   % Copy selected file to new struct with new name
                    currentStruct.(newSensorName) = convertTimeCol(currentStruct.(newSensorName));  % Find time column automatically
                    currentStruct.(newSensorName).Properties.UserData{1} = sensorFileName;
                    currentStruct.(newSensorName).Properties.UserData{2} = sensorFileName;
                    currentStruct.(newSensorName).Label = zeros(height(currentStruct.(newSensorName)), 1);
                    currentStruct.(newSensorName).Class = repmat("Undefined", height(currentStruct.(newSensorName)), 1);
                
                case 3 % addSensors(currentStruct, sensorFiles, sensorFileName, newSensorName, columnsInFile)
                    sensorFileName = varargin{1};
                    if ~isfield(sensorFiles,string((sensorFileName))); ErrorHandler.raiseError('InvalidField','SensorManager', varargin{1}, fieldnames(sensorFiles)); end

                    newSensorName = varargin{2};
                    columnsInFile = varargin{3};
                    currentStruct.(newSensorName) = table(); % Create new table
                    for i=1:numel(columnsInFile) % Loop all selected columns
                        % Copy selected columns in selected file to new struct with new name
                        currentStruct.(newSensorName) = [currentStruct.(newSensorName) sensorFiles.(sensorFileName)(:,columnsInFile(i))];
                    end
                    % Find time column automatically
                    currentStruct.(newSensorName) = convertTimeCol(currentStruct.(newSensorName));
                    currentStruct.(newSensorName).Properties.UserData{1} = sensorFileName;
                    currentStruct.(newSensorName).Properties.UserData{2} = sensorFileName;
                    currentStruct.(newSensorName).Label = zeros(height(currentStruct.(newSensorName)), 1);
                    currentStruct.(newSensorName).Class = repmat("Undefined", height(currentStruct.(newSensorName)), 1);
                otherwise
                    currentStruct = struct; % Debug output
            end
            newStruct = currentStruct;
            
            % Nested function to find possible time column
            function newTimeTable = convertTimeCol(dataTable)
                % Return original table
                if isempty(dataTable); newTimeTable = dataTable; return; end
                % Time is monotonically increasing, they should have the
                % maximum gradient comparing to any other data streams
                % So here the time column is the column with maximum
                % gradient
                tmp = SensorManager.normaliseTable(dataTable);
                % Mean of gradient is used for comparison
                % Make an array of gradients' mean
                gradients               = table2array(varfun(@(x)mean(gradient(x)), tmp));
                % Find idx of maximum gradient mean
                idx                     = gradients == max(gradients);
                % Find column name of the column index
                colName                 = tmp.Properties.VariableNames{idx};
                % Convert the column to a duration type
                tmp.(colName)     = seconds(tmp{:,idx});
                % Return new timetable
                newTimeTable            = table2timetable(tmp,'RowTimes',colName);
            end
        end

        %% Arguments: normaliseTable(dataTable)
        %
        %  Function : convert duration columns into double
        function newTable = normaliseTable(dataTable)
            % Declare local variables
            newTable = table();
            columns = fieldnames(dataTable);
            % For all columns, find columns of duration
            for i=1:numel(columns)
                if strcmp(columns{i}, 'Properties'); continue; end % skip 'Properties'
                if strcmp(columns{i}, 'Row'); continue; end        % skip 'Row'
                if strcmp(columns{i}, 'Variables'); continue; end  % skip 'Variables'
                % Check if column is duration with isduration()
                if isduration(dataTable.(columns{i}))
                    % convert duration to double with seconds()
                    tmp = seconds((dataTable.(columns{i})));
                    newTable.(columns{i}) = tmp;
                    continue;
                end
                newTable.(columns{i}) = dataTable.(columns{i});
            end
        end
        
        %% Arguments: removeSensors(currentStruct, sensorName)
        %
        %  Function : remove a sensor from given sensor struct
        %             returns new sensor struct
        function newStruct = removeSensors(currentStruct, sensorName)
            arguments (Output)
                newStruct struct
            end
            % If fileName is "ALL", remove all sensors, return empty struct
            if strcmpi(sensorName.upper,"ALL"); newStruct = struct(); return; end
            % If fieldName is not a field, throw error
            if ~isfield(currentStruct, sensorName)
                ErrorHandler.raiseError("InvalidField", "SensorManager", "Sensors", sensorName, fieldnames(currentStruct)).throwAsCaller;
            end
            % Return new struct with removed sensor
            newStruct = rmfield(currentStruct,sensorName);
        end
        
        %% Arguments: syncVideo(caller, sensorStruct, videoFileName)
        %
        %  Function : syncs all sensors to specified video
        function syncVideo(caller, sensorStruct, videoFileName)
            % Declare local variables
            sensors = fieldnames(sensorStruct);
            offset  = 0; % default offset

            % For all sensors, check for dedicated offset of video
            for i=1:numel(sensors)
                % Declare local variable
                syncedFile = sensorStruct.(sensors{i}).Properties.UserData{1};

                % Find Offset with isfield()
                % offset type 1 (VIDEONAME)
                if isfield(caller.Files.Offset, videoFileName)
                    offset = caller.Files.Offset.(videoFileName);
                end
                % offset type 2 (VIDEONAME_SENSORNAME)
                if isfield(caller.Files.Offset, append(videoFileName, '_', syncedFile))
                    offset = caller.Files.Offset.(append(videoFileName, '_', syncedFile));
                end

                % Change current offset to new found offset
                caller.Sensors.(sensors{i}).Properties.UserData{2} = offset;

                % Debug message
                fprintf("[NOTE: Offset = VideoTime - DataTime]\n\n" + ...
                    "Offset: %d for %s (According to Video File '%s')\n", ...
                    offset, sensors{i}, videoFileName);
            end
        end

        %% Arguments: changeTimeRow(caller, sensorName, newCol)
        %
        %  Function : change time column to specified column
        function changeTimeRow(caller, sensorName, newCol)
            % Declare local variable
            sensor = caller.Sensors.(sensorName);
            timeCol = sensor.Properties.DimensionNames{1};

            % If specified column is current time column, display, skip
            if strcmp(timeCol, newCol); disp(sensor(1:2,:)); return; end

            % If specified column is not a duration, convert to duration
            if ~isduration(sensor.(newCol))
                sensor.(newCol) = seconds(sensor.(newCol));
            end
            % Convert current time column to double with seconds()
            tmp = seconds(sensor.(timeCol));

            % Exchange columns new -> old; old -> new
            sensor.(timeCol) = sensor.(newCol);
            sensor.(newCol) = tmp;

            % Rename exchaned columns
            sensor = renamevars(sensor, newCol, 'tmp');
            sensor.Properties.DimensionNames = {char(newCol), 'Variables'};
            sensor = renamevars(sensor, 'tmp', timeCol);
            caller.Sensors.(sensorName) = sensor;

            % Debug display
            disp(sensor(1:2,:));
        end
    end
end