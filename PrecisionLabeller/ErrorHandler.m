%% ErrorHandler.m
% Type  : Utility Class (Handles error)
% Hardcoded to tailor to DataLabellingTool Properties
% Uses MException class to throw errors
classdef ErrorHandler < MException
    %% Constructor for error object
    % local initialisation only
    methods (Access=private)
        function obj = ErrorHandler()
        end
    end

    methods (Static)
        %% Arguments: raiseError(errorID, caller, varargin)
        %             varargin depends on errorID
        %
        %  Function : creates an error object to throw
        %             customised msgs and errorID combined with caller
        function error = raiseError(errorID, caller, varargin)
            % creates ticket "CALLER:ERRORID"
            callerErrorID = append(caller,":",errorID);
            switch errorID
                case 'InvalidFile' % raiseError("InvalidFile", caller, filePath)
                    msg = sprintf( ...
                        ['\nError: %s\n' ...
                        'The specified file is not accessible.\n' ...
                        '(File Path: %s)'], callerErrorID, varargin{1});

                case 'InvalidFolder' % raiseError("InvalidFolder", caller, folderPath)
                msg = sprintf( ...
                    ['\nError: %s\n' ...
                    'The specified folder is not accessible.\n' ...
                    '(Folder Path: %s)'], callerErrorID, varargin{1});

                case 'InvalidType' % raiseError("InvalidType", caller, fileType(s), filePath)
                    fileTypes = varargin{1}{1};
                    for i=1:(numel(varargin{1})-1)
                        fileTypes = append(fileTypes, ", ",varargin{1}{i+1});
                    end
                    msg = sprintf( ...
                        ['\nError: %s\n' ...
                        'The specified file is not of expected type (%s).\n' ...
                        '(File Path: %s)'], callerErrorID, fileTypes, varargin{2});
                
                case 'InvalidFileName' % raiseError("InvalidFileName", caller, fileName)
                msg = sprintf( ...
                    ['\nError: %s\n' ...
                    'The given file name is invalid.\n' ...
                    '(Given File Name: %s)'], callerErrorID, varargin{1});

                case 'InvalidClass' % raiseError("InvalidClass", caller, classNum, label, section)
                    msg = sprintf( ...
                        ['\nError: %s\n' ...
                        'The class number for labelling is invalid.\n' ...
                        '(Class: %s (Should be a number) for "%s" in [%s])'], callerErrorID, varargin{1}, varargin{2}, varargin{3});
                
                case 'InvalidKey' % raiseError("InvalidKey", caller, key, section)
                    msg = sprintf( ...
                        ['\nError: %s\n' ...
                        'The variable name is invalid.\n' ...
                        '(Variable Key: %s in [%s])'], callerErrorID, varargin{1}, varargin{2});
                
                case 'InvalidField' % raiseError("InvalidField", caller, fieldName, givenField, availableField(s))
                     msg = sprintf( ...
                    ['\nError: %s\n' ...
                    'The specified field is not in DataLabellingTool %s structure.\n' ...
                    '(Requested Field: "%s" in %s)\n' ...
                    '\nPlease choose from the available fields:\n'], callerErrorID, varargin{1}, varargin{2}, varargin{1});
                    for i = 1:length(varargin{3})
                        msg = append(msg, sprintf('   %s\n', varargin{3}{i}));
                    end

                case 'TooManyArguments' % raiseError("TooManyArguments", caller, arguments)
                    args = varargin{1}; % set first argument as initial msg
                    for i = 1:numel(varargin) % add new arguments
                        args = append(args, sprintf('%s', ',', varargin{i}));
                    end
                    msg = sprintf( ...
                        ['\nError: %s\n' ...
                        'Too many arguments for addSensors().\n' ...
                        '(Input: %s)'], callerErrorID, args);

                case 'NoGroundTruthLoaded' % raiseError("NoGroundTruthLoaded", caller)
                    msg = sprintf( ...
                        ['\nError: %s\n' ...
                        'No ground truth timetable is loaded at the moment.\n' ...
                        'Please load a valid ground truth file or create a new one.'], callerErrorID);
                otherwise
            end
            % Create error object from errorID and msg
            error = MException(callerErrorID, msg);
        end
    end
end
