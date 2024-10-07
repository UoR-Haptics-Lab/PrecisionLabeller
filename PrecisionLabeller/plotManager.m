%% PlotManager.m
% Type  : Utility Class (Handles plot related services)
% Hardcoded to tailor to DataLabellingTool Properties
classdef PlotManager < DataLabellingTool
    methods (Static)
        %% Arguments: addPlot(caller, plotName, sensorName, columns)
        %
        %  Function : plot new figure with given columns in sensor file
        %             initialises plot properties
        function addPlot(caller, plotName, sensorName, col)
            currentStruct = caller.Plots;
            % Skip plot already exist, delete, re-initiate with new input
            if isfield(currentStruct, plotName)
                close(caller.Plots.(plotName).Handle);
                pause(1); % wait for plot to close
            end
            
            %%% Creating New Field
            % Count existing figures
            figureNum                       = numel(fieldnames(caller.Plots));
            % Construct new field
            currentStruct.(plotName)        = struct;
            % Create new figure with number 1 higher than current count
            currentStruct.(plotName).Handle = figure(figureNum+1);
            
            %%% Plotting new plot with data
            % Find variable names of given columns
            plotCol = caller.Sensors.(sensorName).Properties.VariableNames(col);
            for i=1:numel(plotCol) % Loop all specified columns
                plot(caller.Sensors.(sensorName).(plotCol{i})); % Plot specified column
                % Hold after plotting first data
                % To automatic clean up plotted data (if any)
                if i == 1; hold on; end
            end
            % GroundTruth
            if any(strcmp('Label',caller.GroundTruth.Properties.VariableNames))
                % Only plot if label column is found in groundtruth
                currentStruct.(plotName).GroundTruth = plot(caller.GroundTruth.Label);
            else
                currentStruct.(plotName).GroundTruth = plot(1:10);
            end; hold off;

            %%% Initialise all required properties
            % Indicator
            currentStruct.(plotName).Indicator = xline(0, ...
                                                    'DisplayName','Indicator', ...      % Handle name
                                                    'Label',"00:00:00", ...             % Video time label
                                                    'LabelOrientation','horizontal' ... % Display as horizontal
                                                );

            % Handle Properties
            currentStruct.(plotName).Handle.Name        = sensorName;   % PlotName as sync file name
            currentStruct.(plotName).Handle.Units       = "normalized"; % normalised units to calculate mouse position
            currentStruct.(plotName).Handle.UserData(1) = false;        % Mouse pressed (true: pressed, false: released)
            currentStruct.(plotName).Handle.UserData(2) = 1;            % Calculated data point from axis and mouse pos
            
            % Indicator Properties
            currentStruct.(plotName).Indicator.UserData(1) = 0; % Prev datapoint
            currentStruct.(plotName).Indicator.UserData(2) = 1; % Current datapoint
            currentStruct.(plotName).Indicator.UserData(3) = 0; % Selected Class

            % KeyPressFcns
            % For Labelling
            currentStruct.(plotName).Handle.KeyPressFcn           = @(~,event)LabelHandler.changeClass(caller, caller.Files.ClassList, event.Key, currentStruct.(plotName).Indicator, sensorName);
            % For Seeking
            currentStruct.(plotName).Handle.WindowButtonDownFcn   = @(src,~)PlotManager.mouseDownCallback(caller, src);
            currentStruct.(plotName).Handle.WindowButtonUpFcn     = @(src,~)PlotManager.mouseUpCallback(src);
            currentStruct.(plotName).Handle.WindowButtonMotionFcn = @(src,~)PlotManager.mouseMotionCallback(caller, src);
            % For Deleting
            currentStruct.(plotName).Handle.DeleteFcn             = @(~,~)removePlot(caller,plotName);

            % General plot properties
            title(plotName);
            % Legend
            legendEntries = [plotCol, {'GroundTruth'}]; % Set last data as groundtruth label
            legend(legendEntries);
            % Y-axis sort (Classlist is a hashmap)
            keys          = caller.Files.ClassList.keys;
            values        = caller.Files.ClassList.values;
            [~, sortIdx]  = sort(str2double(keys));
            yticks(sort(cellfun(@str2double, caller.Files.ClassList.keys)));
            yticklabels(values(sortIdx));
            
            % Return configured plot struct
            caller.Plots = currentStruct;
        end
        
        %% Arguments: removePlot(caller, plotName)
        %
        %  Function : removes specified plot
        function removePlot(caller, plotName)
            % Remove field
            caller.Plots = rmfield(caller.Plots,plotName);
            caller.thread; % Calling caller to determine run or stop thread
        end
        
        %% Arguments: zoomPanFixPlot(caller, Handle, plotName)
        %
        %  Function : fixes 
        function zoomPanFixPlot(caller, Handle, plotName)
            % Store graph current mode information to field 'hManager'
            hManager = uigetmodemanager(Handle); % uigetmodemanager is an undocumented method
            caller.Plots.(plotName).hManager = hManager;
            % Add listener to monitor mode changes and restore KeyPressFcn
            caller.Plots.(plotName).listener = addlistener(hManager, 'CurrentMode', 'PostSet', @(~, ~)updateKeyPressFcn());

            function updateKeyPressFcn()
                % Function to monitor and fix mode changes affecting KeyPressFcn
                warning('off', 'MATLAB:modes:mode:InvalidPropertySet');
                if ~isempty(hManager.CurrentMode)
                    % Disable window listeners that interfere with KeyPressFcn
                    [hManager.WindowListenerHandles.Enabled] = deal(false);
                    
                    % Restore the KeyPressFcn for the plot
                    Handle.KeyPressFcn{3} = @(~,event)LabelHandler.changeClass(caller, caller.Files.ClassList, event.Key, caller.Plots.(plotName).Indicator, Handle.Name);
                end
            end
        end

        %% Arguments: updateIndicator(caller, videoTime)
        %
        %  Function : updateIndicator UserData
        %             Position indicator according to synced file
        %             Calls update Label to update ground truth 
        %             if user is editing
        function updateIndicator(caller, videoTime)
            % Disable annoying warning
            % The warning happens sometimes because the
            % plot is being deleted or video is being stopped
            % so the indicator is gone, we cannot write data onto the
            % indicator, but matlab doesnt know its being deleted
            % rather than detecting if a plot is being deleted, 
            % it is easier to turn the warning off
            warning('off', 'MATLAB:callback:PropertyEventError');
            
            % Declare variables
            plotStruct = caller.Plots;
            plots = fieldnames(plotStruct);
            if numel(plots) == 0; return; end % Do nothing if no plots
            
            % Calculate times
            approxDataTime   = videoTime + caller.Offset;
            videoTime        = seconds(videoTime);
            videoTime.Format = ('hh:mm:ss.SSS');

            % For all plots, update indicator properties
            for i=1:numel(plots)
                % If edit mode is off, set indicator prev position to NaN
                if ~caller.EditFlag; plotStruct.(plots{i}).Indicator.UserData(1) = NaN; end
                
                % Declare local variables
                sensorName     = plotStruct.(plots{i}).Handle.Name;
                timeCol        = caller.Sensors.(sensorName).Properties.DimensionNames{1};
                dataTime       = seconds(caller.Sensors.(sensorName).(timeCol));
                [~, dataPoint] = min(abs(approxDataTime - dataTime));
                
                % Write new properties
                plotStruct.(plots{i}).Indicator.Value       = dataPoint;
                plotStruct.(plots{i}).Indicator.Label       = string(videoTime);
                plotStruct.(plots{i}).Indicator.UserData(2) = dataPoint;
                drawnow limitrate;
            end
            % If edit mode is off, stop here
            if ~caller.EditFlag; return; end
            % indicator UserData(3) is selected Class (i.e. class 1,2,3...7 so on)
            PlotManager.updateLabel(caller, caller.Plots, plotStruct.(plots{i}).Indicator.UserData(3));
        end

        %% Arguments: updateLabel(caller, Plots)
        %             updateLabel(caller, Plots, class)
        %
        %  Function : update label in plots
        %             updates whole plot if theres a new label file loaded
        %             updates section of plot if user is editing
        %             varargin to determine edit mode or not
        function updateLabel(caller, Plots, varargin)
            plot = fieldnames(Plots);
            for i=1:numel(plot)
                % Not edit mode, edit full plot
                if numel(varargin) < 1
                    % Overwrite entire current GroundTruth plot
                    % NOTE: This should be written dynamically to plot
                    %       according to the sync file, so it matches with
                    %       the time in the file and not restricted to the
                    %       groundtruth time.
                    %       Should be implemented in a later version, not a
                    %       concern for now.
                    caller.Plots.(plot{i}).GroundTruth.YData = newTT.Label;
                    drawnow limitrate;
                    return
                end
                
                % Edit mode, edit local section
                % Do nothing if rewinding
                if Plots.(plot{i}).Indicator.UserData(2) < Plots.(plot{i}).Indicator.UserData(1); return; end
                % Declare sync range as past to now
                syncRange = Plots.(plot{i}).Indicator.UserData(1):Plots.(plot{i}).Indicator.UserData(2);
                % Skip if invalid sync range
                if syncRange(1) == 0; return; end

                % Overwrite classes in sync range to a new class
                Plots.(plot{i}).GroundTruth.YData(syncRange) = varargin{1};
                
                % Declare local variables
                syncFile = Plots.(plot{i}).Handle.Name;
                timeCol  = caller.Sensors.(syncFile).Properties.DimensionNames{1};
                syncTime = caller.Sensors.(syncFile).(timeCol);
    
                % Find time min max from sync file
                % Fetch actual time from file using index position
                timeMin  = syncTime(Plots.(plot{i}).Indicator.UserData(1));
                timeMax  = syncTime(Plots.(plot{i}).Indicator.UserData(2));
                
                % Calculate nearest neighbor in label
                [~,idxRef1] = min(abs(caller.GroundTruth.Time - timeMin));
                [~,idxRef2] = min(abs(caller.GroundTruth.Time - timeMax));
                
                % Plotting classes according to sync file times and not
                % according to 
                caller.GroundTruth.Label(idxRef1:idxRef2) = varargin{1};
                drawnow limitrate;
            end
        end

        %% Arguments: mouseDownCallback(caller, handle)
        %             (LEFT CLICK)
        %
        %  Function : calculate relative mouse position in figure
        %             calculate data point from mouse position
        %             
        function mouseDownCallback(caller, handle)
            % Do nothing if vlc is not on
            if isempty(caller.vlc); return; end
            % Double check if vlc is connected, do nothing if not
            try isempty(caller.vlc.Current); catch; return; end
            mousePos = get(handle, 'CurrentPoint');      % Get mouse pos in figure
            axPos = get(handle.CurrentAxes, 'Position'); % Get axis pos in figure
            % If mouse is out of plot area, say mouse is not clicked
            if ~(mousePos(1) >= axPos(1) && mousePos(1) <= axPos(3) && mousePos(2) >= axPos(2) && mousePos(2) <= axPos(4))
                handle.UserData(1) = false;
                return
            end

            %%% UserData, if mouse is in plot area
            % Mouse down event
            handle.UserData(1) = true;
            % Calculate data point from mouse pos
            dataPoint = PlotManager.dataPointfromMousePos(handle);
            % If data point out of bounds, do nothing
            if (dataPoint < 1) || (dataPoint > height(caller.Sensors.(handle.Name))); return; end
            % else, that is your data point the mouse is at
            handle.UserData(2) = dataPoint;
            
            %%% Seek to valid data point in video
            PlotManager.seekVideo(caller, handle.Name, dataPoint);
        end

        %% Arguments: mouseUpCallback(handle)
        %             (LEFT CLICK)
        %
        %  Function : say mouse is released
        function mouseUpCallback(handle)
            % UserData(1): true if mouse pressed, false if mouse released
            handle.UserData(1) = false;
        end

        %% Arguments: mouseMotionCallback(caller, handle)
        %             (LEFT CLICK)
        %
        %  Function : say mouse is released
        function mouseMotionCallback(caller, handle)
            % Skip if mouse is released
            if ~handle.UserData(1); return; end
            % Skip if vlc is not on
            if isempty(caller.vlc); return; end
            % Double check if vlc is connected, do nothing if not
            try isempty(caller.vlc.Current); catch; return; end

            % Calculate data point from mouse pos
            dataPoint = PlotManager.dataPointfromMousePos(handle);
            % Skip if mouse is out of bounds in x-axis
            % Continue reading if mouse is only out of y-axis bounds
            if (dataPoint < 1) || (dataPoint > height(caller.Sensors.(handle.Name))); return; end
            handle.UserData(2) = dataPoint; % Store new dataPoint
            
            % Seek to valid datapoint
            PlotManager.seekVideo(caller, handle.Name, dataPoint);
        end

        %% Arguments: dataPointfromMousePos(handle)
        %             (LEFT CLICK)
        %
        %  Function : returns possible datapoint the mouse is touching
        %             NOTE: There must be a better way to write this
        %             I should only check for mouse position in one
        %             function instead of checking outside and inside the function
        %             again and again. but it works. its ok, fix it in a later
        %             version.
        function dataPoint = dataPointfromMousePos(handle)
            % Get the current mouse position in figure units (normalized)
            mousePos = get(handle, 'CurrentPoint');
            
            % Convert the mouse position to the normalized position within the axes
            axPos = get(handle.CurrentAxes, 'Position');
            % If mouse pos not out of bounds in x-axis
            if ~(mousePos(1) >= axPos(1) && mousePos(1) <= axPos(3))
                dataPoint = handle.UserData(2);
                return
            end

            % Calculate the X data range and normalized X position
            xLimits   = get(handle.CurrentAxes, 'XLim');
            normX     = (mousePos(1) - axPos(1)) / axPos(3);

            % Calculate the actual X data value on the normalized position
            dataPoint = normX * (xLimits(2) - xLimits(1)) + xLimits(1);
        end

        %% Arguments: seekVideo(caller, sensorName, dataPoint)
        %
        %  Function : seeks video according to data point in vlc
        function seekVideo(caller, sensorName, dataPoint)
            % Find time column in sync file
            timeCol    = caller.Sensors.(sensorName).Properties.DimensionNames{1};
            % Calculate approx video time from data time in sync file using offset
            videoTime  = seconds(caller.Sensors.(sensorName).(timeCol)(round(dataPoint))) - caller.Offset;
            % Call vlc to seek to approx video time
            caller.vlc.seek(videoTime);
        end
    end
end