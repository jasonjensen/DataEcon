classdef DEFile < handle

    properties
        ptr (1,1) {mustBeA(ptr, 'lib.pointer')} = libpointer('voidPtrPtr')
        fname {mustBeTextScalar} = ''
        memory (1,1) {mustBeNumericOrLogical} = false
        readonly (1,1) {mustBeNumericOrLogical} = false 
    end

    methods (Static)
        function de = DEFile(path, o)
            arguments
                path {mustBeTextScalar} = ''
                o.readonly = false
                o.memory = false
                o.truncate = false
            end
            if isa(path, 'string')
                path = char(path)
            end
            ptr = libpointer('voidPtrPtr', 0);
            if o.memory
                DAEC.check_call('de_open_memory', ptr);
            elseif o.readonly
                DAEC.check_call('de_open_readonly', path, ptr);
            else
                DAEC.check_call('de_open', path, ptr);
                if o.truncate
                    DAEC.check_call('de_truncate', ptr);
                end
            end
            de.ptr = ptr;
            de.fname = path;
            de.memory = o.memory;
            de.readonly = o.readonly;
        end
    end

    methods % daec files

        function tf = isopen(de)
            tf = isvalid(de) && not(de.ptr.isNull);
        end

        function de = truncate(de)
            [~] = DAEC.check_call('de_truncate', de.ptr);
        end

        function de = close(de)
            [~] = DAEC.check_call('de_close', de.ptr);
            de.ptr = libpointer('voidPtrPtr');
        end

        function delete(de)
            close(de);
        end

    end

    methods % catalogs

        function id = find_object(de, pid, name)
            if nargin == 2
                name = pid;
                pid = 0;
            end
            [~, ~, id] = DAEC.check_call('de_find_object', de.ptr, pid, name, -1);
        end

        function attr = get_all_attributes(de, id, delim)
            if nargin < 3
                % If any attribute name or value contains the delimiter there 
                % will be trouble. Caller can override as necessary. 
                delim = '||';  % default delimiter. 
            end
            pn = lib.pointer('stringPtrPtr', {''}); % pointer to names
            pv = lib.pointer('stringPtrPtr', {''}); % pointer to values
            num = lib.pointer('longPtr', -1);
            DAEC.check_call('de_get_all_attributes', de.ptr, id, delim, num, pn, pv);
            names = split(pn.Value{1}, delim);
            assert(numel(names) == num.Value, 'Inconsistent number of names')
            values = split(pv.Value{1}, delim);
            assert(numel(values) == num.Value, 'Inconsistent number of values')
            if all(cellfun(@isvarname, names), 'all')
                nv = [names(:) values(:)]';
                attr = struct(nv{:});
            else
                attr = containers.Map(names, values);
            end
        end

        function list = list_catalog(de, id)
            OK = DAEC.enums.status_t.DE_SUCCESS;
            DONE = DAEC.enums.status_t.DE_NO_OBJ;
            search = lib.pointer('voidPtrPtr', 0);
            DAEC.check_call('de_list_catalog', de.ptr, id, search);
            list = struct;
            num = 1;
            po = lib.pointer('object_tPtr', struct);
            try
                while true
                    status = DAEC.call('de_next_object', search, po);
                    if status == OK
                        list(num).id = po.Value.id;
                        list(num).pid = po.Value.pid;
                        list(num).obj_class = po.Value.obj_class;
                        list(num).obj_type = po.Value.obj_type;
                        list(num).name = po.Value.name;
                        num = num + 1;
                    elseif status == DONE
                        break
                    else
                        DAEC.check(status);
                    end
                end
            catch exception
                DAEC.check_call('de_finalize_search', search);
                rethrow(exception);
            end
            DAEC.check_call('de_finalize_search', search);
        end

        function id = new_catalog(de, pid, name)
            if nargin == 1
                pid = 0;
            end
            [~, ~, id] = DAEC.check_call('de_new_catalog', de.ptr, pid, name, -1);
        end

        function sz = catalog_size(de, pid)
            if nargin == 1
                pid = 0;
            end
            [~, sz] = DAEC.check_call('de_catalog_size', de.ptr, pid, -1);
        end

        function obj = read(de, pid, name)
            if nargin == 2
                name = pid;
                pid = 0;
            end
            id = find_object(de, pid, name);
            obj = read_id(de, id);
        end

        function obj = read_id(de, id)
            if nargin == 1
                id = 0;
            end
            % de_load_object(voidPtr, int64, object_tPtr)
            objectStruct = libstruct('object_t');
            objectStruct.obj_type = int32(0);
            objectStruct.obj_class = int32(0);
            objectPtr = libpointer('object_t', objectStruct);
            [~, obj_t] = DAEC.check_call('de_load_object', de.ptr, id, objectPtr);
            % now get the value
            switch DAEC.enums.class_t.(obj_t.obj_class)
                case DAEC.enums.class_t.class_scalar
                    obj = retrieve_scalar(de, obj_t);
                otherwise
                    error('unknown object class')
            end           
        end

        function val = retrieve_scalar(de, obj_t)
            scalarStruct = libstruct('scalar_t');
            scalarStruct.object = obj_t;
            scalarPtr = libpointer('scalar_t', scalarStruct);
            [~, scalar_t] = DAEC.check_call('de_load_scalar', de.ptr, obj_t.id, scalarPtr);

            switch DAEC.enums.type_t.(obj_t.obj_type)
                case DAEC.enums.type_t.type_float
                    val = DAEC.call('get_double_from_voidptr', scalar_t.value);
                case DAEC.enums.type_t.type_signed
                    val = int64(DAEC.call('get_int64_from_voidptr', scalar_t.value));
                case DAEC.enums.type_t.type_unsigned
                    val = int64(DAEC.call('get_uint64_from_voidptr', scalar_t.value));
                case DAEC.enums.type_t.type_string
                    val = DAEC.call('get_string_from_voidptr', scalar_t.value);
                    if isempty(val)
                        val = '';
                    else
                        val = char(val);  % Convert to MATLAB string
                        % Clean up any null terminators
                        null_idx = find(val == 0, 1);
                        if ~isempty(null_idx)
                            val = val(1:null_idx-1);
                        end
                    end
                case DAEC.enums.type_t.type_complex
                    real_part = DAEC.call('get_complex_real_from_voidptr', scalar_t.value);
                    imag_part = DAEC.call('get_complex_imag_from_voidptr', scalar_t.value);
                    val = complex(real_part, imag_part);
                otherwise
                    error(sprintf('unsupported scalar type %s', obj_t.obj_type))
            end
        end
    end

end