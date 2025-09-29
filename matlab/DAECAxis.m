classdef DAECAxis < handle
% MIT - Moment-In-Time class for DataEcon date representation

    properties (Access = public)
        ax_type {mustBeInteger, mustBeNonnegative} = DAEC.enums.axis_type_t.axis_plain
        frequency {mustBeInteger, mustBeNonnegative} = DAEC.enums.frequency_t.freq_none
        length {mustBeInteger, mustBeNonnegative} = 1
        first  {mustBeInteger} = 1
        names  = {}
    end

    methods
        function obj = DAECAxis(varargin)
            if nargin == 4
                obj.ax_type = varargin{1};
                obj.frequency = varargin{2};
                obj.length = varargin{3};
                if obj.ax_type == DAEC.enums.axis_type_t.axis_names
                    obj.names = varargin{4};
                else
                    obj.first = varargin{4};
                end
            elseif nargin == 2
                if isa(varargin{1}, 'MIT')
                    obj.ax_type = DAEC.enums.axis_type_t.axis_range;
                    obj.frequency = varargin{1}.frequency;
                    obj.first = varargin{1}.value;
                    obj.length = varargin{2};
                end
            elseif nargin == 1
                if isa(varargin{1}, 'struct')
                    obj.ax_type = DAEC.enums.axis_type_t.(varargin{1}.ax_type);
                    obj.frequency = DAEC.enums.frequency_t.(varargin{1}.frequency);
                    obj.first = varargin{1}.first;
                    obj.length = varargin{1}.length;
                    obj.names = DAEC.unpack_column_names(varargin{1}.names, varargin{1}.length);
                elseif isa(varargin{1}, 'cell')
                    obj.ax_type = DAEC.enums.axis_type_t.axis_names;
                    obj.frequency = DAEC.enums.frequency_t.freq_none;
                    obj.first = 0;
                    obj.length = numel(varargin{1});
                    obj.names = varargin{1};
                else
                    error('Invalid input.')
                end
            else
                error('Invalid number of input arguments')
            end
        end

       
    end

    

end