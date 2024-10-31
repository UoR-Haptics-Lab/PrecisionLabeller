%% PlotManager.m
% Type  : Utility Class (Handles plot related services)
% Hardcoded to tailor to DataLabellingTool Properties
classdef PlotManager < DataLabellingTool
    methods (Static)
        %% Arguments: addPlot(caller, plotName, sensorName, col, sensorFileName)
        %
        %  Function : plot new figure with given columns in sensor file
        %             initialises plot properties
        function addPlot(caller, plotName, sensorName, col, varargin)
            % Declare local variables
            currentPlot = struct;
            sensor   = caller.Sensors.(sensorName);
            caller.EditFlag = false;
            
            %%% Choosing figure
            % Count existing figures
            % Create new figure with one number higher than current count
            figureNum = numel(fieldnames(caller.Plots)) + 1;

            % Check if plot name already exist with isfield()
            % If already exist, grab figure number
            if isfield(caller.Plots, plotName)
                figureNum = caller.Plots.(plotName).Handle.Number;
            end
            
            % Create new figure with one number higher than current count
            currentPlot.Handle = figure(figureNum);

            %%% Plotting on chosen figure
            % Find variable names of given columns
            plotCol = sensor.Properties.VariableNames(col);
            
            % For all specified columns, plot
            for i=1:numel(plotCol)
                plot(sensor.(plotCol{i})); % Plot specified column
                % Turn on hold at i=1
                if i==1; hold on; end
            end

            % GroundTruth
            % Plot label column in current plot
            % Set handle to currentPlot.GroundTruth
            currentPlot.GroundTruth = plot(sensor.Label);
            hold off;

            %%% Initialise all required properties
            % General Properties
            currentPlot.Handle.Name        = sensorName;   % PlotName as sync file name
            currentPlot.Handle.Units       = "normalized"; % Normalised units to calculate mouse position
            currentPlot.Handle.UserData(1) = false;        % Mouse pressed (true: pressed, false: released)
            currentPlot.Handle.UserData(2) = 1;            % Calculated data point from axis and mouse pos
            
            % Indicator Properties
            currentPlot.Indicator               = xline(0, ...
                                                    'DisplayName','Indicator', ...      % Handle name
                                                    'Label',"00:00:00", ...             % Video time label
                                                    'LabelOrientation','horizontal' ... % Display as horizontal
                                                );
            currentPlot.Indicator.HitTest       = "off";   % Disable contact with mouse
            currentPlot.Indicator.PickableParts = "none";  % Disable contact with mouse
            currentPlot.Indicator.UserData(1)   = NaN;     % Prev datapoint
            currentPlot.Indicator.UserData(2)   = 1;       % Current datapoint
            currentPlot.Indicator.UserData(3)   = 0;       % Selected Class

            % Selector Properties
            currentPlot.Selector.A      = {};  % Point A selection
            currentPlot.Selector.B      = {};  % Point B selection
            currentPlot.Selector.Region = {};  % Region between point A and B
            % Putting plotName to CurrentAxes UserData
            % So that the ROI point has access to plotName
            % Then FeaturesHandler will have access to the plots
            currentPlot.Handle.CurrentAxes.UserData{1} = plotName;

            %%% KeyPressFcns
            % For Labelling
            currentPlot.Handle.KeyPressFcn           = @(~,event)LabelHandler.changeClass(caller, event.Key);
            
            % For Seeking
            currentPlot.Handle.WindowButtonDownFcn   = @(src,~)PlotManager.mouseDownCallback(caller, src, currentPlot.Indicator);
            currentPlot.Handle.WindowButtonUpFcn     = @(src,~)PlotManager.mouseUpCallback(src);
            currentPlot.Handle.WindowButtonMotionFcn = @(src,~)PlotManager.mouseMotionCallback(caller, src, currentPlot.Indicator);
            
            % For Deleting
            currentPlot.Handle.DeleteFcn             = @(~,~)removePlot(caller,plotName);

            % For fixing plot modes (needed for the real-time labelling system)
            % When user pans, zooms, or use the gui buttons,
            % matlab changes the figure's mode and locks all pre-configured
            % KeyPressFcn.

            % Ideally, we are able to edit the labels even if the mode has changed. 
            % With this lock, we cannot.

            % So I have written this function to overwrite matlab's original local lock. 
            % Every time the figure sees our user using a new mode of
            % the figure, we revert the KeyPressFcn to what was set.
            PlotManager.zoomPanFixPlot(caller, currentPlot.Handle, plotName);

            %%% Display Settings
            % Title
            title(strrep(plotName, '_','\_'));

            % Legend
            legendEntries = [plotCol, {'GroundTruth'}]; % Set last data as groundtruth label
            legend(legendEntries);
            
            % Y-axis displaying ClassList
            keys          = caller.Files.ClassList.keys;
            values        = caller.Files.ClassList.values;
            [~, sortIdx]  = sort(str2double(keys));
            % For all keys (class numbers) within ClassList, convert to doubles
            % Sort all converted keys (class numbers)
            % Set y-axis tick according to the sorted keys (class numbers)
            yticks(sort(cellfun(@str2double, caller.Files.ClassList.keys)));
            % Set y-axis labels on ticks according to the class values (class name)
            yticklabels(values(sortIdx));
            % The y-axis should show the class name at the value of class number
            
            % Return constructed plot back to DataLabellingTool
            caller.Plots.(plotName) = currentPlot;
            
            % thread to control timerFcn and linking axes
            caller.thread; % Calling DataLabellingTool
        end

        %% Arguments: removePlot(caller, plotName)
        %
        %  Function : removes specified plot
        function removePlot(caller, plotName)
            % Remove field
            caller.Plots = rmfield(caller.Plots,plotName);
            % Calling thread function control timerFcn and linking axes
            caller.thread;
        end

        %% Arguments: zoomPanFixPlot(caller, Handle, plotName)
        %
        %  Function : fixes KeyPressFcn when user changes figure mode
        %             This is for the labelling system
        function zoomPanFixPlot(caller, Handle, plotName)
            % Store graph current mode information to the field 'hManager'
            hManager = uigetmodemanager(Handle); % uigetmodemanager is an undocumented method
            caller.Plots.(plotName).hManager = hManager;
            % Add listener to monitor mode changes and restore KeyPressFcn
            caller.Plots.(plotName).listener{1} = addlistener(hManager, 'CurrentMode', 'PostSet', @(~, ~)updateKeyPressFcn());

            % Nested function to pass inputs
            function updateKeyPressFcn()
                % Turn off warning of invalid property, 
                % The possible cause might be the mode is changed too fast
                % Not fully tested, uncertain cause of warning
                % But does not interfere with overall tool function
                warning('off', 'MATLAB:modes:mode:InvalidPropertySet');

                % Based on solution described by Yair Altman at
                % https://undocumentedmatlab.com/articles/enabling-user-callbacks-during-zoom-pan
                % The below method is adapted from his approach.

                % Check for current mode change with isempty()
                if ~isempty(hManager.CurrentMode)
                    % Disable window listener handle that interferes with KeyPressFcn
                    [hManager.WindowListenerHandles.Enabled] = deal(false);
                    % Restore the KeyPressFcn for the plot
                    % Setting thrid cell with previously assigned functions
                    % 3rd cell so that it does not interfere with MatLab
                    % built-in mode functions
                    Handle.KeyPressFcn{3} = @(~,event)LabelHandler.changeClass(caller, event.Key);
                end
            end
        end

        %% Arguments: updateIndicator(caller, videoTime)
        %
        %  Function : updates the Indicator's UserData
        %             and updates the Indicator's position
        %             Calls updateLabel to update ground truth 
        %             if user is editing
        function updateIndicator(caller, videoTime)
            % Disable warning
            % The possible is plot plot is being deleted or vlc is being disconnected
            % so the indicator is gone, we cannot read/write data onto the
            % indicator, but at the instant the indicator still exist
            % Not fully test, uncertain cause of warning
            % But does not interfere with overall tool function
            warning('off', 'MATLAB:callback:PropertyEventError');
            % Declare variables
            plotStruct = caller.Plots;
            plotNames = fieldnames(plotStruct);

            % If no available plots, do nothing
            if numel(plotNames) == 0; return; end

            % For all plots, update indicator properties
            for i=1:numel(plotNames)
                %%% Declare local variables
                currentPlot = plotStruct.(plotNames{i});
                sensorName  = currentPlot.Handle.Name;
                sensor      = caller.Sensors.(sensorName);
                timeCol     = sensor.Properties.DimensionNames{1};
                dataTime    = sensor.(timeCol);

                %%% Calculate times
                % Data Time = Video Time - Offset
                % Sensor's UserData{2} is their respective offset
                approxDataTime       = videoTime - sensor.Properties.UserData{2};
                videoTimeNorm        = seconds(videoTime);
                videoTimeNorm.Format = ('hh:mm:ss.SSS');
                
                % Calculate actual data point with nearest neighbour method
                [~, dataPoint] = min(abs(seconds(dataTime) - approxDataTime));
                
                %%% Write new properties
                currentPlot.Indicator.Label       = string(videoTimeNorm);
                % Overwrite Indicator.UserData(2) (current data point) to new calculated point
                currentPlot.Indicator.UserData(2) = dataPoint; % Overwrite data
                % If NOT Handler.UserData(1) (Mouse is released), change indicator value
                if ~currentPlot.Handle.UserData(1); currentPlot.Indicator.Value = dataPoint; end
                
                % If edit mode is off, stop here
                if ~caller.EditFlag; continue; end
                % Indicator UserData(3) is selected Class (i.e. class 1,2,3..)
                LabelHandler.updateLabel(caller, sensorName, currentPlot.Indicator.UserData); % Calling LabelHandler
                PlotManager.updateLabel(caller); % update label display in plots
            end
        end

        %% Arguments: updateLabel(caller)
        %             updateLabel(caller, class)
        %
        %  Function : update label in plots
        %             updates whole plot if theres a new label file loaded
        %             updates section of plot if user is editing
        %             varargin to determine edit mode or not
        function updateLabel(caller, editFull)
            arguments
                caller
                editFull boolean = 0 % Indicating edit whole plot, or only specified section
            end
            % Declare local variables
            plotStruct = caller.Plots;
            plotNames  = fieldnames(plotStruct);

            % For all plots, update label plot
            for i=1:numel(plotNames)
                % Declare local variables
                syncFile = plotStruct.(plotNames{i}).Handle.Name;
                
                % If editFull is false, range is set by indicator values
                if editFull == 0
                    past = plotStruct.(plotNames{i}).Indicator.UserData(1);
                    now  = plotStruct.(plotNames{i}).Indicator.UserData(2);
                end

                % If editFull is true, range is set by size of sensor file
                if editFull == 1
                    past = 1;
                    now = height(caller.Sensors.(syncFile));
                end
                
                % If rewinding, do nothing
                if now < past; continue; end

                % Declare sync range as past to now
                syncRange = past:now;
                    
                 % Skip if invalid sync range
                if syncRange(1) == 0; continue; end
                
                % Overwrite classes in sync range to a new class
                plotStruct.(plotNames{i}).GroundTruth.YData(syncRange) = caller.Sensors.(syncFile).Label(syncRange);
            end
        end

        %% Arguments: mouseDownCallback(caller, handle)
        %             (LEFT CLICK DOWN)
        %
        %  Function : set mouse has clicked down
        %             calculate relative mouse position in figure
        %             calculate data point from mouse position
        function mouseDownCallback(caller, handle, indicator)
            % If VLC is off, skip
            if isempty(caller.vlc); return; end
            % Double check if video is nothing playing, skip
            try isempty(caller.vlc.Current); catch; return; end

            % Get Positions
            mousePos = get(handle, 'CurrentPoint');         % Get mouse pos in figure
            axPos    = get(handle.CurrentAxes, 'Position'); % Get axis pos in figure

            % If mouse is out of plot area, mouse click is not registered
            if ~(mousePos(1) >= axPos(1) && mousePos(1) <= axPos(3) && mousePos(2) >= axPos(2) && mousePos(2) <= axPos(4))
                handle.UserData(1) = false;
                return
            end

            %%% UserData, if mouse is in plot area
            % Mouse down event to true
            handle.UserData(1) = true;
            % Calculate data point from mouse pos
            dataPoint       = PlotManager.dataPointfromMousePos(handle);
            indicator.Value = dataPoint;
            % If data point is out of bounds, do nothing
            if (dataPoint < 1) || (dataPoint > height(caller.Sensors.(handle.Name))); return; end
            % else, that is your data point (where the mouse is)
            handle.UserData(2) = dataPoint;
            
            %%% Seek to valid time in video
            % Sensor UserData{2} holds offset
            PlotManager.seekVideo(caller, handle.Name, dataPoint, caller.Sensors.(handle.Name).Properties.UserData{2});
        end

        %% Arguments: mouseMotionCallback(caller, handle)
        %             (LEFT CLICK HOLD)
        %
        %  Function : move indicator to mouse position, if left mouse is held down
        %             update indicator properties
        function mouseMotionCallback(caller, handle, indicator)
            % Skip if mouse is released
            if ~handle.UserData(1); return; end
            % Skip if vlc is not on
            if isempty(caller.vlc); return; end
            % Double check if video is playing
            % If not, do nothing
            try isempty(caller.vlc.Current); catch; return; end

            % Calculate data point from mouse pos
            dataPoint = PlotManager.dataPointfromMousePos(handle);
            % If data point is out of bounds, do nothing
            if (dataPoint < 1) || (dataPoint > height(caller.Sensors.(handle.Name))); return; end
            % else, that is your data point (where the mouse is)
            handle.UserData(2) = dataPoint;
            % put indicator to wherever the mouse is
            indicator.Value = dataPoint;

            %%% Seek to valid time in video
            % Sensor UserData{2} holds offset
            PlotManager.seekVideo(caller, handle.Name, dataPoint, caller.Sensors.(handle.Name).Properties.UserData{2});
        end

        %% Arguments: mouseUpCallback(handle)
        %             (LEFT CLICK UP)
        %
        %  Function : set mouse has released
        function mouseUpCallback(handle)
            % UserData(1): true if mouse pressed, false if mouse released
            handle.UserData(1) = false;
        end

        %% Arguments: dataPointfromMousePos(handle)
        %
        %  Function : returns possible datapoint the mouse is touching
        %             NOTE: There must be a better way to write this
        %             I should only check for mouse position in one
        %             function instead of checking it from different functions
        %             again and again. but it works. its ok, fix it in a later
        %             version.
        function dataPoint = dataPointfromMousePos(handle)
            % Get the current mouse position in figure units (normalized)
            mousePos = get(handle, 'CurrentPoint');
            
            % Convert the mouse position to the normalized position within the axes
            axPos = get(handle.CurrentAxes, 'Position');
            % If mouse pos is NOT out of x-axis bounds
            if ~(mousePos(1) >= axPos(1) && mousePos(1) <= axPos(3))
                dataPoint = handle.UserData(2);
                return
            end

            % Calculate the X data range and normalised X position
            xLimits   = get(handle.CurrentAxes, 'XLim');
            normX     = (mousePos(1) - axPos(1)) / axPos(3);
            % normalised means reperesent points as precentages in decimals

            % Calculate the actual X data value on the normalised position (percentages)
            dataPoint = normX * (xLimits(2) - xLimits(1)) + xLimits(1);
            % dataPoint = percentage * range + lowerLimit
        end

        %% Arguments: seekVideo(caller, sensorName, dataPoint)
        %
        %  Function : seeks video according to data point in vlc
        function seekVideo(caller, sensorName, dataPoint, offset)
            % Find time column in sync file
            timeCol    = caller.Sensors.(sensorName).Properties.DimensionNames{1};
            % Calculate approx video time from data time in sync file using offset
            videoTime  = seconds(caller.Sensors.(sensorName).(timeCol)(round(dataPoint))) + offset;
            % Call vlc to seek to approx video time
            caller.vlc.seek(videoTime);
        end
    end
end