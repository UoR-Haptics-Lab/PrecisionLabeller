%% FeaturesHandler.m
% Type  : Utility Class (Handles features)
% Hardcoded to tailor to DataLabellingTool Properties
% Inherit from DataLabellingTool to overwrite properties
classdef FeaturesHandler < DataLabellingTool
    methods (Static)
        %% Arguments: selector(caller)
        %
        %  Function : select 2 points (A, B) from available plots
        %             add A and B as a field in caller.Plots to pass data
        function selector(caller)
            % Create two points on the current plot
            a = drawpoint();
            b = drawpoint();
            
            % Call function to synchronize points across all plots
            copyPoints(a, b);

            function copyPoints(a, b)
                % Get the name of the current plot
                currentPlot = a.Parent.Title.String;
                plotNames = fieldnames(caller.Plots);

                % Store selectors and set up listeners for the current plot
                caller.Plots.(currentPlot).Selector.A = a;
                caller.Plots.(currentPlot).Selector.B = b;
                caller.Plots.(currentPlot).listener{2} = addlistener(a, "MovingROI", @(src, evt)updatePoint(src, evt, "A", plotNames));
                caller.Plots.(currentPlot).listener{3} = addlistener(b, "MovingROI", @(src, evt)updatePoint(src, evt, "B", plotNames));
                
                % Create the initial region for the current plot
                caller.Plots.(currentPlot).Selector.Region = xregion(a.Position(1), b.Position(1), 'FaceAlpha', 0.6);

                % Get time information for syncing across plots
                syncFile = caller.Plots.(currentPlot).Handle.Name;
                timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
                timeA = caller.Sensors.(syncFile).(timeCol)(round(a.Position(1)));
                timeB = caller.Sensors.(syncFile).(timeCol)(round(b.Position(1)));

                % Loop through other plots and synchronize points and regions
                for i = 1:numel(plotNames)
                    % Skip the current plot
                    if strcmp(plotNames{i}, currentPlot)
                        continue;
                    end

                    % Get time information for other plots
                    syncFile = caller.Plots.(plotNames{i}).Handle.Name;
                    timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
                    localTime = caller.Sensors.(syncFile).(timeCol);
                    [~, xPosA] = min(abs(localTime - timeA));
                    [~, xPosB] = min(abs(localTime - timeB));

                    % Draw synchronized points in other plots
                    caller.Plots.(plotNames{i}).Selector.A = drawpoint(caller.Plots.(plotNames{i}).Handle.CurrentAxes, ...
                        'Position', [xPosA a.Position(2)]);
                    caller.Plots.(plotNames{i}).Selector.B = drawpoint(caller.Plots.(plotNames{i}).Handle.CurrentAxes, ...
                        'Position', [xPosB b.Position(2)]);
                    
                    % Create region in other plots
                    caller.Plots.(plotNames{i}).Selector.Region = xregion(xPosA, xPosB, 'FaceAlpha', 0.6);

                    % Add listeners for points in other plots
                    caller.Plots.(plotNames{i}).listener{2} = addlistener(caller.Plots.(plotNames{i}).Selector.A, "MovingROI", @(src, evt)updatePoint(src, evt, "A", plotNames));
                    caller.Plots.(plotNames{i}).listener{3} = addlistener(caller.Plots.(plotNames{i}).Selector.B, "MovingROI", @(src, evt)updatePoint(src, evt, "B", plotNames));
                end
            end

            % Function to update points and regions across all plots
            function updatePoint(point, ~, pointID, plotNames)
                % Get the current plot and its sync file
                currentPlot = point.Parent.Title.String;
                syncFile = caller.Plots.(currentPlot).Handle.Name;
                timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
                localTime = caller.Sensors.(syncFile).(timeCol)(round(point.Position(1)));

                % Update the synchronized points and regions across all plots
                for j = 1:numel(plotNames)
                    % Get time information for the other plot
                    syncFile = caller.Plots.(plotNames{j}).Handle.Name;
                    timeCol = caller.Sensors.(syncFile).Properties.DimensionNames{1};
                    localTimeInOtherPlot = caller.Sensors.(syncFile).(timeCol);
                    [~, posX] = min(abs(localTimeInOtherPlot - localTime));

                    % Update the position of the corresponding point
                    if ~strcmp(plotNames{j}, currentPlot)
                        caller.Plots.(plotNames{j}).Selector.(pointID).Position(1) = posX;
                        caller.Plots.(plotNames{j}).Selector.(pointID).Position(2) = point.Position(2);
                    end

                    % Delete the previous region if it exists
                    if isfield(caller.Plots.(plotNames{j}).Selector, 'Region')
                        delete(caller.Plots.(plotNames{j}).Selector.Region);
                    end

                    % Ensure the two points (A and B) are updated before recreating the region
                    posA = caller.Plots.(plotNames{j}).Selector.A.Position(1);
                    posB = caller.Plots.(plotNames{j}).Selector.B.Position(1);

                    % Recreate the region between the two points
                    caller.Plots.(plotNames{j}).Selector.Region = xregion(caller.Plots.(plotNames{j}).Handle.CurrentAxes, posA, posB, 'FaceAlpha', 0.6);
                end
            end
        end

        %% Arguments: deselector(caller)
        %
        %  Function : removes point A and B, also removes the fields
        function deselector(caller)
            plotNames = fieldnames(caller.Plots);
            for i=1:numel(plotNames) % For all plots, delete all selector and regions
                delete(caller.Plots.(plotNames{i}).Selector.A);
                delete(caller.Plots.(plotNames{i}).Selector.B);
                delete(caller.Plots.(plotNames{i}).Selector.Region);
            end
        end
    end
end
