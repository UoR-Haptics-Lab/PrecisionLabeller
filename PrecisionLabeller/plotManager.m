classdef plotManager < handle
    properties (SetAccess = private)
        Plots = struct()            % Plots struct to store all plots
        Classes                     % Global classHandler object                          [same for all classes]
    end

    properties (Access = public)
        VLC                         % Global VLC object                                   [same for all classes]
        default                     % Globa default (iniFileHandler object)               [same for all classes]
        Listener                    % Listens to loaded global ground truth from default (iniFileHandler object)
        Thread                      % 0.05 period timer to update indicator in background. It does not interfere with main command window
        Flag = false                % Status Flag for edit control; true indicates editMode on; false indicates editMode off
    end

    methods
        %% Constructor; feeds global VLC, global Offset, global iniFileHandler object
        function obj = plotManager(v, default)
            obj.Classes = classHandler(v, default);
            obj.VLC = v;
            obj.default = default;
            % Listening iniFileHandler.LoadedVersion() on postset
            % Calls plotManager.updateGraph()
            obj.Listener = addlistener( ...
                obj.default,'LoadedVersion', ...
                'PostSet' ...
                ,@(src, event)obj.updateGraph ...
                );
            % Thread to update video time index (IdxNow) on all sensor timelines
            % Updates graph and overwrite ground truth if EditMode is on
            obj.Thread = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode','drop', ...
                'Period', 0.05, ...
                'TimerFcn', @(src, event)obj.update, ...
                'ErrorFcn', @(src, event)obj.reloadEdit, ...
                'Name', 'LabelTool' ...
                );
        end
        %% Plot Control (addPlot, removePlot)
        % Plot new plots (plotName, syncTimeline (XData, YData, X1Data, X2Data, ..., XnData, YnData))
        % syncFile is the sensor timeline the plots are synced to
        function addPlot(obj, plotName, syncFile, varargin)
            % Extract x y from varargin; 
            % varargin = XData, YData, X1Data, X2Data, ..., XnData, YnData
            XData = varargin(1:2:end);
            YData = varargin(2:2:end);
            
            % Store new figure plot handle as 'Handle' field in struct (plotManager.Plots.(plotName))
            obj.Plots.(plotName).Handle = figure();

            % Call newly stored figure for plot
            figure(obj.Plots.(plotName).Handle); 
            hold on;

            % Plot all x y data onto current figure
            for i = 1:numel(XData); plot(XData{i}, YData{i}); end

            % Plot ground truth according to the first XData length
            % Store ground truth plot handle as 'GroundTruth' field in struct (plotManager.Plots.(plotName))
            obj.Plots.(plotName).GroundTruth = plot(obj.default.GroundTruth.Time, obj.default.GroundTruth.Label);
            
            % Store syncTime as 'syncTime' field in struct
            obj.Plots.(plotName).syncFile = string(syncFile);
            
            % Instantiate indicator for current plot
            % Store indicator instance line handle as 'Indicator' field in struct (plotManager.Plots.(plotName))
            obj.Plots.(plotName).Indicator = indicator(obj.VLC, obj.default, syncFile);
            pause(2); % In case indicator not completely instantiated
            obj.Plots.(plotName).Indicator.start;
             % Known Issue: Indicator does not update immediately while video is playing
             % Symptom: indicator updates only when user is interacting with plot
             % Solution: Restart Matlab, no other solutions available yet
            
            % Set current plot title to plotname
            title(plotName);
            % Set current plot y-axis to class names
            set(obj.Plots.(plotName).Handle.CurrentAxes, 'YTick', obj.default.yClassList, 'YTickLabel', obj.default.ClassList);
            % Set current plot WindowKeyPressFcn for class change in editMode
            set(obj.Plots.(plotName).Handle, 'WindowKeyPressFcn', @(src, event)obj.Classes.changeClass(event, obj.Flag));
            obj.zoomPanFixPlot(obj.Plots.(plotName).Handle, plotName); % Automatic WindowKeyPressFcn Mode Fix

            hold off;
        end
        
        % Remove instantiated plots
        function removePlot(obj, plotName)
            % Skip for invalid plotName
            if ~isfield(obj.Plots, plotName)
                return
            end
            % Remove plot completely
            delete(obj.Plots.(plotName).Handle);
            obj.Plots = rmfield(obj.Plots, plotName);
        end
        
        %% Edit Mode Control (startEdit, stopEdit, reloadEdit)
        % Start Edit Mode
        function startEdit(obj)
            if ~obj.Flag
                obj.Flag = true;
                start(obj.Thread);
            end
            obj.Classes.CurrentClass = NaN;
            obj.Classes.IdxRef = NaN;
            obj.Classes.EditMode = 'On';
            disp(obj.Classes);
        end
    
        % Stop Edit Mode
        function stopEdit(obj)
            % Skip all if Edit Mode is off
            if ~obj.Flag
                disp(obj.Classes);
                return; 
            end
            % Stop Edit Mode
            obj.VLC.pause;
            obj.Flag = false;
            stop(obj.Thread)
            obj.Classes.EditMode = 'Off';
            disp(obj.Classes);
        end

        % Reload Edit Mode
        function reloadEdit(obj)
            obj.Flag = false;
            obj.Classes.EditMode = 'Off';
            
            % Re-declare Thread property
            delete(obj.Thread);
            obj.Thread = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode','drop', ...
                'Period', 0.1, ...
                'TimerFcn', @(src, event)obj.update, ...
                'ErrorFcn', @(src, event)obj.reloadEdit, ...
                'Name', 'LabelTool');
            start(obj.Thread);

            obj.startEdit;
        end
    end
        methods (Access = private)
        %% Plot Fix method
        % When using Matlab graph functions (i.e. zooming), 
        % Matlab changes the graph's current mode 
        % which changes its KeyPressFcn and WindowKeyPressFcn.
        % This removes any preset KeyPressFcn and needs to be set again
        % Edit Mode works by retrieving keyboard stroke on graphs
        % We need this fix method to reset our KeyPressFcn and 
        % connect keyboard strokes to classHandler.changClass() again
        function zoomPanFixPlot(obj, Handle, plotName)
            % Store graph current mode information to field 'hManager'
            obj.Plots.(plotName).hManager = uigetmodemanager(Handle); % uigetmodemanager is an undocumented method
            
            % Store new listener to field 'Listener'
            % Listening hManager.CurrentMode on postset.
            % Calls MonitorModeChange
            obj.Plots.(plotName).Listener = addlistener(obj.Plots.(plotName).hManager,'CurrentMode','PostSet',@MonitorModeChange);

            % Based on the solution described by Yair Altman at
            % https://undocumentedmatlab.com/articles/enabling-user-callbacks-during-zoom-pan
            % The below method is adapted from his approach.

            function MonitorModeChange(varargin) % Nested function to retain arguments from zoomPanFixPlot
                warning('off','MATLAB:modes:mode:InvalidPropertySet')
                if ~isempty(obj.Plots.(plotName).hManager.CurrentMode)
                    switch obj.Plots.(plotName).hManager.CurrentMode.Name
                        case 'Exploration.Brushing'
                            disp('Brushing on')
                            [obj.Plots.(plotName).hManager.WindowListenerHandles.Enabled] = deal(false);
                            Handle.KeyPressFcn{3} = @(src, event)obj.Classes.changeClass(event, obj.Flag);
                        case 'Exploration.Pan'
                            [obj.Plots.(plotName).hManager.WindowListenerHandles.Enabled] = deal(false);
                            Handle.KeyPressFcn{3} = @(src, event)obj.Classes.changeClass(event, obj.Flag);
                        case 'Exploration.Zoom'
                            [obj.Plots.(plotName).hManager.WindowListenerHandles.Enabled] = deal(false);
                            Handle.KeyPressFcn{3} = @(src, event)obj.Classes.changeClass(event, obj.Flag);
                        case 'Exploration.Datacursor'
                            [obj.Plots.(plotName).hManager.WindowListenerHandles.Enabled] = deal(false);
                            Handle.KeyPressFcn{3} = @(src, event)obj.Classes.changeClass(event, obj.Flag);
                        otherwise
                    end
                end
            end
        end

        % TimerFcn, period: 0.05
        % Updates video time idx on all sensor timelines
        % Updates ground truth if EditMode is on
        function update(obj)
            % if VLC not available
            currentDataTime = 0 + obj.default.Offset;

            % Current data time (s) = current video time (μs) + offset (s)
            if ~isempty(obj.VLC.Current)
                currentDataTime = obj.VLC.Current.Position / 1e6 + obj.default.Offset;
            end

            % Update current video time in hh:mm:ss format
            obj.Classes.CurrentVideoTime = seconds(currentDataTime - obj.default.Offset);
            obj.Classes.CurrentVideoTime.Format = ('hh:mm:ss');
            
            % Reference to data points
            [~, idxNow] = min(abs(obj.default.GroundTruth.Time - currentDataTime));
            obj.Classes.IdxNow = idxNow;

            plots = fieldnames(obj.Plots);
            for i = 1:numel(plots)
                syncFile = obj.Plots.(plots{i}).syncFile;
                [~, idx] = min(abs(obj.default.Data.SensorFiles.(syncFile).Time_s_ - currentDataTime));
                obj.Classes.IdxList.(syncFile).IdxNow = idx;
            end

            % Skip all if EditMode is off
            if ~obj.Flag; return; end

            % Edit ground truth if current time after reference time
            if ((obj.Classes.IdxRef > obj.Classes.IdxNow) || isnan(obj.Classes.IdxRef)); return; end
            
            % Update global ground truth stored in iniFileHandler object
            obj.default.updateLabel(obj.Classes.IdxRef, obj.Classes.IdxNow, obj.Classes.CurrentClass);
            
            % Update ground truth plots
            plots = fieldnames(obj.Plots);
            for i = 1:numel(plots)
                syncFile = obj.Plots.(plots{i}).syncFile;
                syncRange = obj.Classes.IdxList.(syncFile).IdxRef:obj.Classes.IdxList.(syncFile).IdxNow;
                obj.Plots.(plots{i}).GroundTruth.YData(syncRange) = obj.Classes.CurrentClass;
                drawnow limitrate;
            end
        end
        
        % Separate function for Updating whole ground truth overlay
        function updateGraph(obj)
            plots = fieldnames(obj.Plots);
            for i = 1:numel(plots)
                figure(obj.Plots.(plots{i}).Handle)
                obj.Plots.(plots{i}).GroundTruth.XData = obj.default.GroundTruth.Time;
                obj.Plots.(plots{i}).GroundTruth.YData = obj.default.GroundTruth.Label;

                drawnow limitrate;
                obj.Plots.(plots{i}).Indicator.reload;
            end
        end
    end
end