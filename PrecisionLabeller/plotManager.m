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
            %%% Local variables
            currentPlot = struct;
            sensor   = caller.Sensors.(sensorName);
            caller.EditFlag = false;

            % Count existing figures
            figureNum = numel(fieldnames(caller.Plots)) + 1;

            % Plot in existing figure if plotName already exist
            if isfield(caller.Plots, plotName)
                figureNum = caller.Plots.(plotName).Handle.Number;
            end

            % Create new figure with number 1 higher than current count
            currentPlot.Handle = figure(figureNum);
            
            %%% Plotting new plot with data
            % Find variable names of given columns
            plotCol = sensor.Properties.VariableNames(col);
            
            for i=1:numel(plotCol) % Loop all specified columns
                plot(sensor.(plotCol{i})); % Plot specified column
                if i==1; hold on; end
            end

            % GroundTruth
            % Only plot if label column is found in groundtruth
            currentPlot.GroundTruth = plot(sensor.Label);
            hold off;

            %%% Initialise all required properties
            % Handle Properties
            try [~,fileName,~] = fileparts(caller.vlc.Current.Meta.Filename); catch; fileName = ""; end

            % default offset
            offset = 0;
            % offset type 1 (VIDEONAME_SENSORNAME)
            if isfield(caller.Files.Offset,append(fileName, '_', sensorName))
                offset = str2double(caller.Files.Offset.(append(fileName, '_', sensorName)));
            end
            % offset type 2 (VIDEONAME)
            if isfield(caller.Files.Offset, fileName)
                offset = str2double(caller.Files.Offset.(fileName));
            end
            % offset type 3 (VIDEONAME_SENSORFILENAME)
            if numel(varargin) > 0
                if isfield(caller.Files.Offset, varargin{1})
                    offset = str2double(caller.Files.Offset.(append(fileName, '_', varargin{1})));
                end
            end

            currentPlot.Handle.Name        = sensorName;   % PlotName as sync file name
            currentPlot.Handle.Units       = "normalized"; % Normalised units to calculate mouse position
            currentPlot.Handle.UserData(1) = false;        % Mouse pressed (true: pressed, false: released)
            currentPlot.Handle.UserData(2) = 1;            % Calculated data point from axis and mouse pos
            currentPlot.Handle.UserData(3) = offset;       % Offset from video time

            % Indicator Properties
            currentPlot.Indicator               = xline(0, ...
                                                    'DisplayName','Indicator', ...      % Handle name
                                                    'Label',"00:00:00", ...             % Video time label
                                                    'LabelOrientation','horizontal' ... % Display as horizontal
                                                );
            currentPlot.Indicator.HitTest       = "off";     % Disable contact with mouse
            currentPlot.Indicator.PickableParts = "none";    % Disable contact with mouse
            currentPlot.Indicator.UserData(1)   = NaN;       % Prev datapoint
            currentPlot.Indicator.UserData(2)   = 1;         % Current datapoint
            currentPlot.Indicator.UserData(3)   = 0;         % Selected Class

            % Selector Properties
            currentPlot.Selector.A      = {};  % Point A selection
            currentPlot.Selector.B      = {};  % Point B selection
            currentPlot.Selector.Region = {};  % Region between point A and B

            %%% KeyPressFcns
            % For Labelling
            currentPlot.Handle.KeyPressFcn           = @(~,event)LabelHandler.changeClass(caller, event.Key);
            % For Seeking
            currentPlot.Handle.WindowButtonDownFcn   = @(src,~)PlotManager.mouseDownCallback(caller, src, currentPlot.Indicator);
            currentPlot.Handle.WindowButtonUpFcn     = @(src,~)PlotManager.mouseUpCallback(src);
            currentPlot.Handle.WindowButtonMotionFcn = @(src,~)PlotManager.mouseMotionCallback(caller, src, currentPlot.Indicator);
            % For Deleting
            currentPlot.Handle.DeleteFcn             = @(~,~)removePlot(caller,plotName);
            % Add zoom pan fix to initialised plot
            % This is needed for labelling system

            % When user pans, zooms, or use the annoying gui buttons,
            % matlab changes its mode and locks all pre-configured
            % KeyPressFcn. Now we want to edit the labels even if the mode has changed. 
            % So I have written this function to overwrite matlab's original local lock. 
            % Every time the figure sees our user using a new mode of
            % the figure, we revert the KeyPressFcn to what was set.
            PlotManager.zoomPanFixPlot(caller, currentPlot.Handle, plotName);

            %%% General plot properties
            title(plotName);
            % Legend
            legendEntries = [plotCol, {'GroundTruth'}]; % Set last data as groundtruth label
            legend(legendEntries);
            % Y-axis sort (Classlist is a hashmap)
            keys          = caller.Files.ClassList.keys;
            values        = caller.Files.ClassList.values;
            [~, sortIdx]  = sort(str2double(keys));
            % Convert keys into doubles individually, and sort them
            % We need to use cellfunc so they are not combined into 1 number 
            yticks(sort(cellfun(@str2double, caller.Files.ClassList.keys)));
            % Put sorted values as y-axis label
            yticklabels(values(sortIdx));
            
            % Return configured plot struct to main caller
            caller.Plots.(plotName) = currentPlot;
            % Calling thread function control timerFcn and linking axes            
            caller.thread;
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

            % Nested function to pass inputs, so I dont have to pass it again
            function updateKeyPressFcn()
                % Turn off warning telling me invalid property, 
                % I think this happens when you change the mode too fast and
                % the lock comes back before it finished restoring the KeyPressFcn.
                warning('off', 'MATLAB:modes:mode:InvalidPropertySet');

                % Based on the solution described by Yair Altman at
                % https://undocumentedmatlab.com/articles/enabling-user-callbacks-during-zoom-pan
                % The below method is adapted from his approach.

                if ~isempty(hManager.CurrentMode)
                    % Disable window listener handle that interferes with KeyPressFcn
                    [hManager.WindowListenerHandles.Enabled] = deal(false);
                    % Restore the KeyPressFcn for the plot
                    Handle.KeyPressFcn{3} = @(~,event)LabelHandler.changeClass(caller, event.Key);
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
            % Disable warning
            % The warning happens sometimes because the
            % plot is being deleted or vlc is being disconnected
            % so the indicator is gone, we cannot read/write data onto the
            % indicator, but matlab doesnt know its being deleted
            % rather than detecting if a plot is being deleted, 
            % it is easier to turn the warning off
            warning('off', 'MATLAB:callback:PropertyEventError');

            % Declare variables
            plotStruct = caller.Plots;
            plotNames = fieldnames(plotStruct);
            if numel(plotNames) == 0; return; end % Do nothing if no plots

            % For all plots, update indicator properties
            for i=1:numel(plotNames)
                % Declare local variables
                currentPlot = plotStruct.(plotNames{i});
                sensorName  = currentPlot.Handle.Name;
                sensor      = caller.Sensors.(sensorName);
                timeCol     = sensor.Properties.DimensionNames{1};
                dataTime    = sensor.(timeCol);

                % Calculate times
                % Data Time = Video Time - Offset
                % UserData(3) from fig handle holds our offset
                approxDataTime       = videoTime - currentPlot.Handle.UserData(3);
                videoTimeNorm        = seconds(videoTime);
                videoTimeNorm.Format = ('hh:mm:ss.SSS');
                
                % Calculate actual data point with nearest neightbor method
                [~, dataPoint] = min(abs(seconds(dataTime) - approxDataTime));
                
                % Write new properties
                currentPlot.Indicator.Label       = string(videoTimeNorm);
                currentPlot.Indicator.UserData(2) = dataPoint;
                if ~currentPlot.Handle.UserData(1); currentPlot.Indicator.Value = dataPoint; end
                
                % If edit mode is off, stop here
                if ~caller.EditFlag; continue; end
                % % indicator UserData(3) is selected Class (i.e. class 1,2,3...7 so on)
                LabelHandler.updateLabel(caller, sensorName, currentPlot.Indicator.UserData);
                PlotManager.updateLabel(caller);
            end
        end

        %% Arguments: updateLabel(caller)
        %             updateLabel(caller, class)
        %
        %  Function : update label in plots
        %             updates whole plot if theres a new label file loaded
        %             updates section of plot if user is editing
        %             varargin to determine edit mode or not
        function updateLabel(caller, varargin)
            plotStruct = caller.Plots;
            plotNames  = fieldnames(plotStruct);

            for i=1:numel(plotNames)
                % Declare local variables
                syncFile = plotStruct.(plotNames{i}).Handle.Name;
                
                if numel(varargin) < 1
                    A = plotStruct.(plotNames{i}).Indicator.UserData(1);
                    B = plotStruct.(plotNames{i}).Indicator.UserData(2);
                else
                    A = 1;
                    B = height(caller.Sensors.(syncFile));
                end
                
                % Do nothing if rewinding
                if B < A; continue; end

                % Declare sync range as past to now
                syncRange = A:B;
                    
                 % Skip if invalid sync range
                if syncRange(1) == 0; continue; end
                
                % Overwrite classes in sync range to a new class
                plotStruct.(plotNames{i}).GroundTruth.YData(syncRange) = caller.Sensors.(syncFile).Label(syncRange);
            end
        end

        %% Arguments: mouseDownCallback(caller, handle)
        %             (LEFT CLICK)
        %
        %  Function : calculate relative mouse position in figure
        %             calculate data point from mouse position
        %             
        function mouseDownCallback(caller, handle, indicator)
            % Do nothing if vlc is not on
            if isempty(caller.vlc); return; end
            % Double check if vlc is connected, do nothing if not
            try isempty(caller.vlc.Current); catch; return; end
            mousePos = get(handle, 'CurrentPoint');      % Get mouse pos in figure
            axPos    = get(handle.CurrentAxes, 'Position'); % Get axis pos in figure

            % If mouse is out of plot area, say mouse is not clicked
            if ~(mousePos(1) >= axPos(1) && mousePos(1) <= axPos(3) && mousePos(2) >= axPos(2) && mousePos(2) <= axPos(4))
                handle.UserData(1) = false;
                return
            end

            %%% UserData, if mouse is in plot area
            % Mouse down event
            handle.UserData(1) = true;
            % Calculate data point from mouse pos
            dataPoint       = PlotManager.dataPointfromMousePos(handle);
            indicator.Value = dataPoint;
            % If data point out of bounds, do nothing
            if (dataPoint < 1) || (dataPoint > height(caller.Sensors.(handle.Name))); return; end
            % else, that is your data point the mouse is at
            handle.UserData(2) = dataPoint;
            
            %%% Seek to valid data point in video
            PlotManager.seekVideo(caller, handle.Name, dataPoint, handle.UserData(3));
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
        %  Function : 
        function mouseMotionCallback(caller, handle, indicator)
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
            indicator.Value = dataPoint;
            % Seek to valid datapoint
            PlotManager.seekVideo(caller, handle.Name, dataPoint, handle.UserData(3));
        end

        %% Arguments: dataPointfromMousePos(handle)
        %             (LEFT CLICK)
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