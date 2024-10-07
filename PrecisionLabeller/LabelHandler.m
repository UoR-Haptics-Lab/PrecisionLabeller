%% LabelHandler.m
% Type  : Utility Class (Handles labelling related services)
% Hardcoded to tailor to DataLabellingTool Properties
classdef LabelHandler < DataLabellingTool
    methods (Static)
        %% Arguments: changeClass(caller, labels, key, indicatorHandle, syncFile)
        %
        %  Function : add new sensors to given sensor struct
        %             allows option to define sensor names, select sensor file, and pick columns
        function changeClass(caller, labels, key, indicatorHandle, syncFile)
            % Throw error if initial no ground truth
            if isempty(caller.GroundTruth); ErrorHandler.raiseError("NoGroundTruthLoaded", "LabelHandler").throwAsCaller; end % Calling ErrorHandler
            
            % 'o' keyboard for start editing
            if strcmpi(key,'o'); caller.EditFlag = true; end
            % 'p' keyboard for stop editing
            if strcmpi(key,'p'); caller.EditFlag = false; end

            % Skip all if edit mode is off
            if ~caller.EditFlag; return; end
            % If prev indicator position is larger than now
            % Set now to previous location
            if indicatorHandle.UserData(2) < indicatorHandle.UserData(1)
                indicatorHandle.UserData(1) = indicatorHandle.UserData(2);
            end

            % Speed-tapping labelling system
            % Written by David Chui very proudly
            % might not even be used but its cool and it works
            % the revert to previous is a little buggy just becuaes the
            % indicator is moving fast and it records both values at different
            % instantaneous times

            % Window time to record keypress 
            window = milliseconds(200);

            % All persistent variables to remember what key was pressed
            persistent future;      % the time to stop recording keypress
            persistent keys;        % keys you pressed
            persistent value;       % data point of current indicator recorded
            persistent idx;         % data point of ground truth recorded
            persistent prevLabel;   % previous class number
            persistent prevClass;   % previous class label
            now = datetime;         % declare "NOW" time
            
            % if no future time, or future is empty, set future as now + window
            if isempty(future) || strcmpi(future, ""); future = now + window; end
            % if empty class number, default as a "" string but not empty
            if isempty(keys); keys = ""; end
            % if value is empty, store current data point to value
            if isempty(value); value = indicatorHandle.Value; end
            % If you are within the window time, i.e. before future
            % add the keys you pressed into an array
            % stitch (append()) to create a number
            if now < future
                keys = append(keys, key);
            end
            
            % If you are out of window, set everything back to default
            if now > future
                future = now + window;
                keys = "";
                keys = append(keys, key);
                value = indicatorHandle.Value;
                idx = [];
            end
            
            % If the key you created is not a valid class number
            % then whatever the previous class and label are
            % will be the current input class and label
            if ~isKey(caller.Files.ClassList,keys)
                caller.GroundTruth.Label(idx) = prevLabel;
                caller.GroundTruth.Class(idx) = prevClass;
                disp(caller.GroundTruth(idx,:))
                return
            end

            % Everything goes right
            % you may be out or inside of window
            % but the key is valid
            % set value to current data point
            if value <= 0; value = indicatorHandle.Value; end
            % Find time columns
            timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
            % Find actual time value
            time = caller.Sensors.(syncFile).(timeCol)(value);
            % Calculate nearest neighbor ground truth time
            [~,idx] = min(abs(caller.GroundTruth.Time - time));
            % Record successful overwrite
            prevLabel = caller.GroundTruth.Label(idx);
            prevClass = caller.GroundTruth.Class(idx);
            
            % Overwrite plots
            plots = fieldnames(caller.Plots);
            for i=1:numel(plots)
                % Find sync file
                syncFile = caller.Plots.(plots{i}).Handle.Name;
                % Find time column in sync file
                timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
                % Declare column as a variable, for ease
                syncTime = caller.Sensors.(syncFile).(timeCol);
                % Find nearest time from the file the indicator is in
                % to the file of another plot
                [~,idxRef] = min(abs(syncTime - time));
                % Store this datapoint to the other plot's indicator
                caller.Plots.(plots{i}).Indicator.UserData(1) = idxRef;
                % Also store the label that I have overwritten
                caller.Plots.(plots{i}).Indicator.UserData(3) = keys;
                % It will update for all available plots in Plots struct
            end
            
            % Overwrite global ground truth file
            caller.GroundTruth.Label(idx) = str2double(keys);            
            caller.GroundTruth.Class(idx) = labels(keys);

            % Save instantaneous ground truth file
            FileHandler.saveFile(caller, caller.GroundTruth, caller.SaveFileName, caller.LabelFolderPath); % Calling FileHandler
            % display overwritten row
            disp(caller.GroundTruth(idx,:));
        end

        function edit()

        end
    end
end