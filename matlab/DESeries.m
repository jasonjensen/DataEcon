classdef DESeries < handle
% DESeries - Time series class for DataEcon

    properties (Access = public)
        axis {mustBeA(axis, 'DEAxis')} = DEAxis(0,0,0,0)
        value {mustBeA(value, ["double", "int64", "uint64", "logical", "MIT"])} = []
    end

    properties (Dependent)
        naxes = numel(obj.axis)
        eltype = DAEC.enums.type_t_by_matlab_class.(class(obj.value))
        elfreq
    end

    methods
        function obj = DESeries(varargin)

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

        function disp(obj)
            naxes = numel(obj.axis);

            % Case 1: All axes are plain - just display the array
            all_plain = true;
            for i = 1:naxes
                if obj.axis(i).ax_type ~= DAEC.enums.axis_type_t.axis_plain
                    all_plain = false;
                    break;
                end
            end

            if all_plain
                disp(obj.value);
                return;
            end

            % Case 2: Single axis_range - univariate time series
            if naxes == 1 && obj.axis(1).ax_type == DAEC.enums.axis_type_t.axis_range
                fprintf('\n');
                for i = 1:obj.axis(1).length
                    date = DEDate(obj.axis(1).frequency, obj.axis(1).first + i - 1);
                    fprintf('  %s    %g\n', format(date), obj.value(i));
                end
                fprintf('\n');
                return;
            end

            % Case 3: Two axes - first is axis_range, second is axis_names - multivariate time series
            if naxes == 2 && ...
               obj.axis(1).ax_type == DAEC.enums.axis_type_t.axis_range && ...
               obj.axis(2).ax_type == DAEC.enums.axis_type_t.axis_names

                % Create table with dates in first column and variable names across top
                dates = cell(obj.axis(1).length, 1);
                for i = 1:obj.axis(1).length
                    date = DEDate(obj.axis(1).frequency, obj.axis(1).first + i - 1);
                    dates{i} = format(date);
                end

                % Create table
                T = array2table(obj.value, 'VariableNames', obj.axis(2).names, 'RowNames', dates);
                disp(T);
                return;
            end

            % Default: for other cases not yet handled, just show the value
            fprintf('\nDESeries with %d axes (display not fully implemented for this configuration)\n', naxes);
            disp(obj.value);
        end

    end
end