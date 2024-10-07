%% SensorManager.m
% Type  : Utility Class (Handles sensor related services)
% Hardcoded to tailor to DataLabellingTool Properties
classdef SensorManager
    methods (Static)
        %% Arguments: addSensors(currentStruct, sensorFile)
        %             addSensors(currentStruct, sensorFile, sensorFileName)
        %             addSensors(currentStruct, sensorFile, sensorFileName, newSensorName)
        %             addSensors(currentStruct, sensorFile, sensorFileName, newSensorName, columnsInFile)
        %  Function : add new sensors to given sensor struct
        %             allows option to define sensor names, select sensor file, and pick columns
        function newStruct = addSensors(currentStruct, sensorFile, varargin)
            arguments (Output)
                newStruct struct
            end
            switch numel(varargin)
                case 0 % addSensors(currentStruct, sensorFile)
                    fields = fieldnames(sensorFile); % Find available sensorFiles
                    for i=1:numel(fields)
                        currentStruct.(fields{i}) = sensorFile.(fields{i});                     % Copy to new struct
                        currentStruct.(fields{i}) = convertTimeCol(currentStruct.(fields{i}));  % Find time column automatically
                    end
                
                case 1 % addSensors(currentStruct, sensorFile, sensorFileName)
                    currentStruct.(varargin{1}) = sensorFile.(varargin{1});                     % Copy selected file to new struct
                    currentStruct.(varargin{1}) = convertTimeCol(currentStruct.(varargin{1}));  % Find time column automatically
                
                case 2 % addSensors(currentStruct, sensorFile, sensorFileName, newSensorName)
                    if ~isfield(sensorFile,string((varargin{1}))); ErrorHandler.raiseError('InvalidField','SensorManager', varargin{1}, fieldnames(sensorFile)); end
                    currentStruct.(varargin{2}) = sensorFile.(varargin{1});                     % Copy selected file to new struct with new name
                    currentStruct.(varargin{2}) = convertTimeCol(currentStruct.(varargin{2}));  % Find time column automatically
                
                case 3 % addSensors(currentStruct, sensorFile, sensorFileName, newSensorName, columnsInFile)
                    currentStruct.(varargin{2}) = table(); % Create new table
                    for i=1:numel(varargin{3}) % Loop all selected columns
                        % Copy selected columns in selected file to new struct with new name
                        currentStruct.(varargin{2}) = [currentStruct.(varargin{2}) sensorFile.(varargin{1})(:,varargin{3}(i))];
                    end
                    % Find time column automatically
                    currentStruct.(varargin{2}) = convertTimeCol(currentStruct.(varargin{2}));
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

                % Mean of gradient is used for comparison
                % Make an array of gradients' mean
                gradients           = table2array(varfun(@(x)mean(gradient(x)),dataTable));
                % Find idx of maximum gradient mean
                idx                 = gradients == max(gradients);
                % Find column name of the column index
                colName             = dataTable.Properties.VariableNames{idx};
                % Convert the column to a duration type
                dataTable.(colName) = seconds(dataTable{:,idx});
                % Return new timetable
                newTimeTable        = table2timetable(dataTable,'RowTimes',colName);
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
    end
end