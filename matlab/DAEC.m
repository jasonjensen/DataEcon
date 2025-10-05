classdef DAEC < handle

    methods (Static, Access=private)
        function inst = instance()
            persistent instance_;    % the singleton instance
            if isempty(instance_) || ~isvalid(instance_)
                instance_ = DAEC();
            end
            inst = instance_;
        end
    end
    
    properties
        libname
        debug_
    end

    properties (Constant)
        enums = daecenums(); % daecenums()
        daec_to_iris_freq = get_daec_to_iris_freq_map();
        iris_to_daec_freq = get_iris_to_daec_freq_map();
    end

    methods (Access=private)
        % private constructor, so it doesn't get called willy-nilly
        function inst = DAEC()
            inst.libname = '';
            switch computer
                case {'PCWIN', 'PCWIN64'}
                    inst.libname = 'libdaec';
                case {'GLNX86', 'GLNXA64'}
                    inst.libname = 'libdaec';
            end
            inst.debug_ = false;
        end
    end

    methods (Static)

        function daec = load(daecroot)
            arguments
                daecroot {mustBeFolder} = '.';
            end
            % nothing to do if library is already loaded
            daec = DAEC.instance;
            if libisloaded(daec.libname)
                return
            end
            % find the library and load it
            hpath = fullfile('..','include', 'daec.h');
            switch computer()
                case {'PCWIN', 'PCWIN64'}
                    libpath = fullfile('..', 'bin', 'libdaec.dll');
                case {'GLNX86', 'GLNXA64'}
                    libpath = fullfile('..', 'lib', 'libdaec.so');
                otherwise
                    error('DataEcon not supported on your platform.');
            end
            % capture output args to suppress warnings
            [~,~] = loadlibrary(libpath, hpath, 'alias', 'libdaec');
            % [~,~] = loadlibrary(libpath, hpath, mfilename='daecinfo');
            if not(strcmp(daec.enums.version, DAEC.version))
                warning('Incompatible DAEC version.')
            end
        end

        function unload()
            libname = DAEC.instance.libname;
            if libisloaded(libname)
                unloadlibrary(libname)
            end
        end

        function tf = isloaded()
            tf = libisloaded(DAEC.instance.libname);
        end

        function oldval = debug(tf)
            inst = DAEC.instance;
            oldval = inst.debug_;
            if exist('tf', 'var') == false
                inst.debug_ = true;
            else
                inst.debug_ = tf;
            end
        end
    end

    methods (Static)
        function ver = version()
            ver = calllib(DAEC.instance.libname, 'de_version');
        end

        function de = open(varargin)
            de = DEFile(varargin{:});
        end

        function max_axes = max_axes()
            max_axes = calllib(DAEC.instance.libname, 'de_max_axes');
        end
    end

    methods (Static)
        % https://www.mathworks.com/help/matlab/call-c-library-functions.html
        % https://www.mathworks.com/help/matlab/matlab_external/passing-arguments-to-shared-library-functions.html

        function varargout = check_call(func, varargin)
            varargout = cell(1, nargout);
            [status, varargout{:}] = DAEC.call(func, varargin{:});
            DAEC.check(status);
        end

        function varargout = call(func, varargin)
            inst = DAEC.instance;
            varargout = cell(1, nargout);
            [varargout{:}] = calllib(inst.libname, func, varargin{:});           
        end

        function varargout = call_shim(func, varargin)
            inst = DAEC.instance;
            varargout = cell(1, nargout);
            [varargout{:}] = calllib(inst.shimname, func, varargin{:});           
        end

        function check(status)
            if (exist('status', 'var') > 0) && (status == 0)
                return
            end
            msg = repmat(' ', 1, 512);
            if DAEC.instance.debug_
                [status, msg] = calllib(DAEC.instance.libname, 'de_error_source', msg, numel(msg)-1);
            else
                [status, msg] = calllib(DAEC.instance.libname, 'de_error', msg, numel(msg)-1);
            end
            if status ~= 0
                error(msg);
            end
        end
    end

    methods (Static) % write helpers
        function [type, freq, val_ptr, nbytes] = prepare_scalar(value)
            nvals = numel(value);
            freq = DAEC.enums.frequency_t.freq_none;
            nbytes = nvals * 8;
            type = 0;
            if isfield(DAEC.enums.type_t_by_matlab_class, class(value))
                type = DAEC.enums.type_t_by_matlab_class.(class(value));
            end
            switch type
                case 1 % integer
                    val_ptr = libpointer('int64Ptr', int64(value));
                case 2 % unsigned int
                    val_ptr = libpointer('int64Ptr', int64(value));
                case 3 % date
                    if isa(value, 'datetime')
                        freq = DAEC.enums.frequency_t.freq_daily;
                        [year, month, day] = ymd(value);
                        date_ptr = libpointer('int64Ptr', int64(0));
                        val_ptr = DAEC.check_call('de_pack_calendar_date', freq, int32(year), uint32(month), uint32(day), date_ptr);
                    else
                        % DEDate array - extract frequency and values
                        freq = value(1).frequency;
                        if nvals == 1
                            vals = int64(value.value);
                        else
                            % Preallocate and extract values efficiently
                            vals = zeros(size(value), 'int64');
                            for i = 1:numel(value)
                                vals(i) = value(i).value;
                            end
                        end
                        val_ptr = libpointer('int64Ptr', vals);
                    end
                case 4 % double
                    if isreal(value)
                        val_ptr = libpointer('doublePtr', double(value));
                    else
                        type = DAEC.enums.type_t.type_complex;
                        convertedValue = complex(double(real(value)), double(imag(value)));
                        val_ptr = libpointer('doublePtr', [real(convertedValue), imag(convertedValue)]);
                        nbytes = nvals* 16;
                    end
                case 6 % string
                    char_val = char(value);
                    % Ensure null termination
                    if isempty(char_val) || char_val(end) ~= char(0)
                        char_val = [char_val, char(0)];
                    end
                    val_ptr = libpointer('cstring', char_val);
                    nbytes = length(char_val);
                    % todo: vector of strings?
                otherwise
                    if isfloat(value) && isscalar(value)
                        type = 4;
                        val_ptr = libpointer('doublePtr', double(value));
                    else
                        error('Unsupported value type %s', value)
                    end
            end
        end

        function packed_names = pack_column_names(names)
            if isempty(names)
                packed_names = '';
                return;
            end
            
            % Convert to cell array of chars for consistency
            packed_names = strjoin(names, char(10));  % char(10) = '\n'
        end

        function daec_date = daec_from_iris_date(iris_freq, iris_start)
            freq = DAEC.iris_to_daec_freq(double(iris_freq));
            
            if ismember(freq, [DAEC.enums.frequency_t.freq_weekly_sun, DAEC.enums.frequency_t.freq_daily])
                daec_date = DEDate(freq, iris_start.datetime);
            elseif freq == DAEC.enums.frequency_t.freq_monthly
                daec_date = DEDate(freq, double(iris_start));
            elseif freq == DAEC.enums.frequency_t.freq_quarterly_mar
                daec_date = DEDate(freq, double(iris_start));
            elseif freq == DAEC.enums.frequency_t.freq_yearly_dec
                daec_date = DEDate(freq, double(iris_start));
            else
                % fallback
                daec_date = DEDate(freq, iris_start.datetime)
            end
        end
    end

    methods (Static) % read helpers
        function data = extract_array_data(val_ptr, eltype, data_shape)
            numel = prod(data_shape);
            switch eltype
                case DAEC.enums.type_t.type_float
                    data = zeros(data_shape, 'double');
                    data_ptr = libpointer('doublePtr', data);
                    [~, data] = DAEC.call('get_double_array_from_voidptr', val_ptr, numel, data_ptr);
                    data = double(data);
                    if length(data_shape) > 2
                        data = reshape(data, data_shape);
                    end
                case DAEC.enums.type_t.type_signed
                    data = zeros(data_shape, 'int64');
                    data_ptr = libpointer('int64Ptr', data);
                    [~, data] = DAEC.call('get_int64_array_from_voidptr', val_ptr, numel, data_ptr);
                    data = int64(data);
                case DAEC.enums.type_t.type_date
                    data = zeros(data_shape, 'int64');
                    data_ptr = libpointer('int64Ptr', data);
                    [~, data] = DAEC.call('get_int64_array_from_voidptr', val_ptr, numel, data_ptr);
                    data = int64(data);
                case DAEC.enums.type_t.type_unsigned
                    data = zeros(data_shape, 'uint64');
                    data_ptr = libpointer('uint64Ptr', data);
                    [~, data] = DAEC.call('get_uint64_array_from_voidptr', val_ptr, numel, data_ptr);
                    data = uint64(data);
                case DAEC.enums.type_t.type_string
                    error("Reading a vector/matrix of strings is not supported...")
                case DAEC.enums.type_t.type_complex
                    adjusted_data_shape = data_shape;
                    adjusted_data_shape(end) = data_shape(end)*2;
                    parted_data = zeros(adjusted_data_shape, 'double');
                    data_ptr = libpointer('doublePtr', parted_data);
                    [~, parted_data] = DAEC.call('get_double_array_from_voidptr', val_ptr, numel*2, data_ptr);
                    parted_data = double(parted_data);
                    if length(data_shape) > 2
                        parted_data = reshape(parted_data, adjusted_data_shape);
                    end
                    real_idx = repmat({':'}, 1, length(data_shape));
                    imag_idx = repmat({':'}, 1, length(data_shape));
                    real_idx{end} = 1:data_shape(end); 
                    imag_idx{end} = (data_shape(end)+1):(data_shape(end) * 2); 
                    data = complex(parted_data(real_idx{:}), parted_data(imag_idx{:}));
                otherwise
                    error(sprintf('unsupported array type %s', eltype))
            end
        end

        function colnames = unpack_column_names(names, ncols)
            
            colnames = {};
            
            if isempty(names) || ncols == 0
                return;
            end
            
            % Split on newline characters (Julia convention)
            if contains(names, char(10))
                colnames = strsplit(names, char(10), 'CollapseDelimiters', false);
            else
                colnames = {names};
            end                
        end

        function data = to_date_array(data, elfreq, data_shape)
            % Preallocate DEDate array with same shape as data
            date_array(numel(data)) = DEDate();
            date_array = reshape(date_array, data_shape);

            % Populate with DEDate objects using vectorized approach
            for i = 1:numel(data)
                date_array(i) = DEDate(elfreq, data(i));
            end

            data = date_array;
        end

        function iris_tseries = make_iris_tseries(axes, data)
            if numel(axes) == 1
                iris_freq = DAEC.daec_to_iris_freq(axes.frequency);
                start_date = DAEC.iris_date(iris_freq, axes);
                end_date = start_date + (axes.length - 1);
                iris_tseries = tseries(start_date:end_date, data);
            else
                iris_freq = DAEC.daec_to_iris_freq(axes(1).frequency);
                start_date = DAEC.iris_date(iris_freq, axes(1));
                end_date = start_date + (axes(1).length - 1);
                iris_tseries = tseries(start_date:end_date, data);
                iris_tseries.Comment = axes(2).names;
            end
        end

        function iris_date_obj = iris_date(iris_freq, axis)
            daec_start = axis.first;
            switch iris_freq
                case 1 % yearly
                    iris_date_obj = yy(daec_start);
                case 4 % quarterly
                    mod = rem(daec_start, 4);
                    iris_date_obj = qq((daec_start-mod)/4, mod+1);
                case 12 % monthly
                    mod = rem(daec_start, 12);
                    iris_date_obj = mm((daec_start-mod)/12, mod+1);
                case 52 % weekly
                    year_ptr = libpointer('int32Ptr', 0);
                    month_ptr = libpointer('uint32Ptr', 0);
                    day_ptr = libpointer('uint32Ptr', 0);
                    [year, month, day] = DAEC.check_call('de_unpack_calendar_date', axis.frequency, axis.first, year_ptr, month_ptr, day_ptr);
                    iris_date_obj = ww(double(year), double(month), double(day));
                case 365 % daily
                    year_ptr = libpointer('int32Ptr', 0);
                    month_ptr = libpointer('uint32Ptr', 0);
                    day_ptr = libpointer('uint32Ptr', 0);
                    [year, month, day] = DAEC.check_call('de_unpack_calendar_date', axis.frequency, axis.first, year_ptr, month_ptr, day_ptr);
                    iris_date_obj = dd(double(year), double(month), double(day));
                otherwise
                    error(sprintf('No IRIS conversion available for frequency %s', axis.frequency))
            end
        end

    end



end