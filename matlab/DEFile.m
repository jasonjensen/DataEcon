classdef DEFile < handle

    properties
        de (1,1) {mustBeA(de, 'lib.pointer')} = libpointer('voidPtrPtr')
        fname {mustBeTextScalar} = ''
        memory (1,1) {mustBeNumericOrLogical} = false
        readonly (1,1) {mustBeNumericOrLogical} = false 
    end

    methods (Static)
        function obj = DEFile(path, o)
            arguments
                path {mustBeTextScalar} = ''
                o.readonly = false
                o.memory = false
                o.truncate = false
            end
            inst = libpointer('voidPtrPtr', 0);
            if o.memory
                DAEC.check_call('de_open_memory', inst);
            elseif o.readonly
                DAEC.check_call('de_open_readonly', path, inst);
            else
                DAEC.check_call('de_open', path, inst);
                if o.truncate
                    DAEC.check_call('de_truncate', inst);
                end
            end
            obj.de = inst;
            obj.fname = path;
            obj.memory = o.memory;
            obj.readonly = o.readonly;
        end
    end

    methods

        function tf = isopen(obj)
            tf = isvalid(obj) && not(obj.de.isNull);
        end

        function obj = close(obj)
            DAEC.check_call('de_close', obj.de);
            obj.de = libpointer('voidPtrPtr');
        end

        function delete(obj)
            close(obj);
        end

    end


% de = libpointer('voidPtrPtr', 0);
% ret = calllib(libdaec, 'de_open', 'mat.daec', de);


end