classdef TSeries < handle
% MIT - Moment-In-Time class for DataEcon date representation

    properties (Access = public)
        start        % DataEcon MIT instance
        values       % Vector of values
    end

    methods
        function obj = TSeries(varargin)

            if nargin == 0
                obj.start = MIT(DAEC.enums.frequency_t.freq_none, 1);
                obj.values = [];
                return; % Empty TSeries
            end

            % TODO: error messages?

            if nargin == 2
                obj.start = varargin{1};
                obj.values = varargin{2}(:);
            else
                error(sprintf('Invalid number of input arguments'))
            end
        end


    end

    

end