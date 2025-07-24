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
    end

    methods (Access=private)
        % private constructor, so it doesn't get called willy-nilly
        function inst = DAEC()
            inst.libname = '';
            switch computer
                case {'PCWIN', 'PCWIN64'}
                    inst.libname = 'daec';
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
            hpath = fullfile(daecroot, 'include', 'daec.h');
            switch computer()
                case {'PCWIN', 'PCWIN64'}
                    libpath = fullfile(daecroot, 'lib', 'daec.dll');
                case {'GLNX86', 'GLNXA64'}
                    libpath = fullfile(daecroot, 'lib', 'libdaec.so');
                otherwise
                    error('DataEcon not supported on your platform.');
            end
            % capture output args to suppress warnings
            [~,~] = loadlibrary(libpath, hpath); 
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

end