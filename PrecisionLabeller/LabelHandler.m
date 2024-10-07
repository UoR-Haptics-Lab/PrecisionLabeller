%% LabelHandler.m
% Type  : Utility Class (Handles labelling related services)
% Hardcoded to tailor to DataLabellingTool Properties
classdef LabelHandler < DataLabellingTool
    methods (Static)
        %% Arguments: changeClass(caller, labels, key, indicatorHandle, syncFile)
        %
        %  Function : add new sensors to given sensor struct
        %             allows option to define sensor names, select sensor file, and pick columns
        function changeClass(caller, key)
            % 'o' keyboard for start editing
            if strcmpi(key,'o')
                caller.EditFlag = true;
                disp("Real-time Edit Mode: ON")
                return
            end

            % 'p' keyboard for stop editing
            if strcmpi(key,'p')
                caller.EditFlag = false;
                disp("Real-time Edit Mode: OFF");
                return
            end

            % not valid labelling class, skip all
            if isnan(str2double(key)); return; end

            % Define local variables
            plotStruct = caller.Plots;
            plotNames = fieldnames(plotStruct);

            % Loop plots
            for i=1:numel(plotNames)
                currentPlot      = plotStruct.(plotNames{i});
                currentIndicator = currentPlot.Indicator;
                
                % If edit mode off, remove 'past' time memory
                if ~caller.EditFlag; currentIndicator.UserData(1) = NaN; continue; end

                % If edit mode is on
                % 'future' time is new 'past' time
                currentIndicator.UserData(1) = currentIndicator.UserData(2);
                % store prev labelling class
                currentIndicator.UserData(3) = str2double(key);
                
                % Find sensor name, and write label to sensor timetable
                sensorName = currentPlot.Handle.Name;
                LabelHandler.updateLabel(caller, sensorName, currentIndicator.UserData);
                disp(caller.Sensors.(sensorName)(currentIndicator.UserData(2), end-1:end));
            end
            % save current edit
            FileHandler.saveFile(caller, caller.GroundTruth, caller.SaveFileName, caller.LabelFolderPath);
        end

        %% Arguments: updateLabel(caller, sensorName, indicatorUserData)
        %
        %  Function : updates label and class column in sensor timetables
        function updateLabel(caller, sensorName, indicatorUserData)
            persistent pastTime;
            persistent nowTime;
    
            % Available sensors
            sensorList = fieldnames(caller.Sensors);
            
            % Index and class information
            past = indicatorUserData(1);
            now  = indicatorUserData(2);
            key  = indicatorUserData(3);
    
            % Find sensor time according to index from sensors
            sensorRef = caller.Sensors.(sensorName);
            timeCol   = sensorRef.Properties.DimensionNames{1};
            pastTime  = seconds(sensorRef.(timeCol)(past));
            nowTime   = seconds(sensorRef.(timeCol)(now));
            
            % If current time is before recorded time, skip
            if now < past; return; end
            % If class is NaN, skip
            if isnan(key); return; else; key = string(key); end
            % If class is not a label in given ClassList, skip
            if ~isKey(caller.Files.ClassList, key); return; end

            % Loop over sensors
            for i=1:numel(sensorList)
                currentSensor = caller.Sensors.(sensorList{i});
                timeCol = currentSensor.Properties.DimensionNames{1};
                
                % If current plot is selected plot, range is recorded idx to current idx
                if strcmpi(sensorList{1},sensorName)
                    range = past:now;
                else
                    % If current plot is other plots, 
                    % find closest possible recorded time and current time
                    [~,newPast] = min(abs(seconds(currentSensor.(timeCol)) - pastTime));
                    [~,newNow] = min(abs(seconds(currentSensor.(timeCol)) - nowTime));
                    % There is a fundamental error with this finding time logic.
                    % It assumes all sensors have the same offset and that
                    % they start at the same exact time.
                    % We need to change how one sensor relates to another
                    % through by applying an offset before calculating
                    % the nearest-neighbor time.
                    range = newPast:newNow;
                end
                
                % Add current sensor to ground truth struct for saving
                caller.GroundTruth.(sensorList{i}) = caller.Sensors.(sensorList{i})(:,end-1:end);
                % Change labels of current sensor
                caller.Sensors.(sensorList{i}).Label(range) = key;
                caller.Sensors.(sensorList{i}).Class(range) = caller.Files.ClassList(key);
            end
        end

        %% Arguments: manualEdit(caller, key)
        %
        %  Function : manually edit the region between selection pts
        function manualEdit(caller, key)
            if ~isKey(caller.Files.ClassList, string(key)); return; end
            % Declare local variables
            plotStruct = caller.Plots;
            plotNames = fieldnames(caller.Plots);
            firstPlot = plotStruct.(plotNames{1});
            sensorName = firstPlot.Handle.Name;
            sensorList = fieldnames(caller.Sensors);

            % Find sync file
            syncFile = firstPlot.Handle.Name;
            % Find time column in sync file
            timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
            % Declare column as a variable, for ease
            syncTime = caller.Sensors.(syncFile).(timeCol);
            
            % Positions of roi points
            posA = round(firstPlot.Selector.A.Position(1));
            posB = round(firstPlot.Selector.B.Position(1));

            for i=1:numel(sensorList)
                
                currentSensor = caller.Sensors.(sensorList{i});
                timeCol = currentSensor.Properties.DimensionNames{1};
                
                if strcmpi(sensorList{i},sensorName)
                    % If current plot is selected plot, range is same
                    range = round(min(posA,posB):max(posA,posB));
                else
                    % If current plot is another plot, find time with
                    % nearest-neighbor
                    [~,newA] = min(abs(seconds(currentSensor.(timeCol)) - seconds(syncTime(posA))));
                    [~,newB] = min(abs(seconds(currentSensor.(timeCol)) - seconds(syncTime(posB))));
                    % Again, logic error, we cannot assume they start at
                    % the same time and have the same offset
                    range = newA:newB;
                end
                % Change labels in given region
                caller.Sensors.(sensorList{i}).Label(range) = key;
                caller.Sensors.(sensorList{i}).Class(range) = caller.Files.ClassList(string(key));
                % Update GroundTruth file
                caller.GroundTruth.(sensorList{i}) = caller.Sensors.(sensorList{i})(:,end-1:end);
                % Update Label in plots
                PlotManager.updateLabel(caller, 1);
                disp(caller.Sensors.(sensorList{i})(range(1), end-1:end));
            end
            % Save snapshot of current sensors with labels
            FileHandler.saveFile(caller, caller.GroundTruth, caller.SaveFileName, caller.LabelFolderPath);
        end
    end
end