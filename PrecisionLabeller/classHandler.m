classdef classHandler < handle
    properties
        CurrentClass = 0         % Current Selected Class
        IdxNow                   % Current video time index
        IdxRef                   % Reference video time index
        CurrentVideoTime = ''    % Current Video Time in hh:mm:ss
        EditMode = 'Off'         % Real time ground truth edit mode, On indicates overwriting on; Off indicates overwritting off
        IdxList = struct()       % List of IdxNow and IdxRef of all sensor data; in the form of a struct
    end

    properties (Access = private)
        VLC                      % global VLC Object     [same for all classes]
        default                  % global iniFileHandler object [same for all classes]
    end

    methods
        %% Constructor (feeds global VLC, global default)
        function obj = classHandler(v, default)
            obj.default = default;
            obj.VLC = v;
            % Create IdxNow and IdxRef for all imported sensorfiles
            % IdxNow: Index that corresponds to current data time
            % IdxRef: Index that corresponds to previous data time
            sensorFiles = fieldnames(obj.default.Data.SensorFiles);
            for i = 1:numel(sensorFiles)
                obj.IdxList.(sensorFiles{i}).IdxNow = NaN;
                obj.IdxList.(sensorFiles{i}).IdxRef = NaN;
            end
        end

        %% Change Overwriting class by keyboard stroke
        % Called by KeyPressFcn
        function changeClass(obj, event, Flag)
            % Update class based on key press
            % Skip all if invalid key
            key = str2double(event.Key);
            if isnan(key) || key <= 0 || key >= max(obj.default.yClassList); return; end
            
            % Assign to classHandler.CurrentClass
            obj.CurrentClass = key;

            % Get current video position and find closest index
            % if VLC not available
            referenceDataTime = 0 + obj.default.Offset;

            if ~isempty(obj.VLC.Current) % Fetch video instantaneous time
                referenceDataTime = obj.VLC.Current.Position / 1e6 + obj.default.Offset; % Calculate approx. data time
            end
            
            % Find index on sensor time by minimal difference with approx data time
            [~, idxRef] = min(abs(obj.default.GroundTruth.Time - referenceDataTime));
            obj.IdxRef = idxRef;

            disp(obj);

            sensorFiles = fieldnames(obj.default.Data.SensorFiles);
            for i = 1:numel(sensorFiles)
                [~, idx] = min(abs(obj.default.Data.SensorFiles.(sensorFiles{i}).Time_s_ - referenceDataTime));
                obj.IdxList.(sensorFiles{i}).IdxRef = idx;
                fprintf('SensorFile%i Index Now: %i\n', i, obj.IdxList.(sensorFiles{i}).IdxNow);
                fprintf('SensorFile%i Index Ref: %i\n\n', i, obj.IdxList.(sensorFiles{i}).IdxRef);
            end

            if Flag
                obj.default.saveLabelFile;
            end
        end
    end
end
