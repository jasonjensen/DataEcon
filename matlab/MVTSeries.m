classdef MVTSeries < handle
% MIT - Moment-In-Time class for DataEcon date representation

    properties (Access = public)
        start        % DataEcon MIT instance
        values       % Vector of values
        names        % Cellarray of column names
    end

    methods
        function obj = MVTSeries(varargin)

            if nargin == 0
                obj.start = MIT(DAEC.enums.frequency_t.freq_none, 1);
                obj.values = [];
                obj.names = {};
                return; % Empty TSeries
            end

            % TODO: error messages?

            if nargin == 3
                obj.start = varargin{1};
                obj.names = varargin{2};
                obj.values = varargin{3};
            else
                error(sprintf('Invalid number of input arguments'))
            end
        end


    end

    

end