classdef indicator < handle % Indicator object
    properties (SetAccess = private)
        Line                % Indicator line seen on plotted graphs
        SyncFile                    
        Status = 'Paused'   % Current status, either 'Paused' or 'Following', any other status indicates an internal error
    end

    properties (Access = private)
        VLC                 % Global VLC object linking to global VLC   [same for all classes]
        default             % Global iniFileHandler object              [same for all classes]
        Thread              % 0.05 period timer to update indicator in background. It does not interfere with main command window
        Flag = false        % Status Flag for indicator control; true indicates indicator running; false indicates indicator stopped
    end

    methods
        %% Constructor; feeds global VLC, global Offset, global classHandler object
        function obj = indicator(v, default, syncFile)
            obj.VLC = v;
            obj.default = default;
            obj.SyncFile = syncFile;
            obj.Thread = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode','drop', ...
                'Period', 0.1, ...
                'TimerFcn', @(src, event)obj.update, ...
                'ErrorFcn', @(src, event)obj.reload, ...
                'Name', 'Indicator');
        end
        
        %% Indicator Control (start, stop, remove, reload)
        % Start indicator
        function start(obj)
            % Skip all if indicator is running
            if obj.Flag; return; end
            
            obj.Flag = true;
            % Plot indicator; start background thread
            obj.Line = xline(0);    
            start(obj.Thread);
            obj.Line.set('visible', 'on');  % In case indicator is invisible
            obj.Status = 'Following';
        end
        
        % Pause indicator
        function stop(obj)
            % Skip all if indicator is paused
            if ~obj.Flag; return; end

            obj.Flag = false;
            % Remove indicator from plot; stop background thread
            delete(obj.Line);
            stop(obj.Thread);
            obj.Status = 'Paused';
        end

        % Remove indicator
        function remove(obj)
            obj.stop;
            obj.Line.set('visible', 'off'); % Make indicator invisible
        end
        
        % Reload indicator
        function reload(obj)
            obj.stop; % Pause indicator

            % Re-initiate background thread
            delete(obj.Thread);
            obj.Thread = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'BusyMode','drop', ...
                'Period', 0.05, ...
                'TimerFcn', @(src, event)obj.update, ...
                'ErrorFcn', @(src, event)obj.reload, ...
                'Name', 'Indicator');

            obj.start; % Start indicator
        end
    end
    
    methods (Access = private)
        %% Indicator update, controlled by Thread as background task
        function update(obj)
            % Skip all if indicator is paused
            if ~obj.Flag; return; end

            % if VLC not available
            currentDataTime = 0 + obj.default.Offset;

            if ~isempty(obj.VLC.Current)
                currentDataTime = obj.VLC.Current.Position / 1e6 + obj.default.Offset;
            end

            % Update indicator position
            [~, idx] = min(abs(obj.default.Data.SensorFiles.(obj.SyncFile).Time_s_ - currentDataTime));
            obj.Line.Value = obj.default.Data.SensorFiles.(obj.SyncFile).Time_s_(idx);

            % Update indicator label
            time = seconds(currentDataTime - obj.default.Offset);
            time.Format = ('hh:mm:ss');
            time = char(time);
            obj.Line.Label = [' ' time ' '];

            % Update indicator on plot
            drawnow limitrate;
        end
    end
end
