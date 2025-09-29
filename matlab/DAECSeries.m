classdef DAECSeries < handle
% MIT - Moment-In-Time class for DataEcon date representation

    properties (Access = public)
        axis {mustBeA(axis, 'DAECAxis')} = DAECAxis(0,0,0,0)
        value {mustBeA(value, ["double", "int64", "uint64", "logical", "MIT"])} = []
    end

    properties (Dependent)
        naxes = numel(obj.axis)
        eltype = DAEC.enums.type_t_by_matlab_class.(class(obj.value))
        elfreq
    end

    methods
        function obj = DAECSeries(varargin)

            % Default initialization
            obj.axis = varargin{1};
            obj.value = varargin{2};
            
        end

        function val = get.elfreq(obj)
            if obj.eltype ~= 3
                val = DAEC.enums.frequency_t.freq_none;
            elseif isa(obj.value, 'MIT')
                val = obj.value.frequency;
            elseif isa(obj.value, 'datetime')
                val = DAEC.enums.frequency_t.freq_daily;
            else
                error('Unsupported value property for eltype = 3')
            end      
        end
        
    end
end