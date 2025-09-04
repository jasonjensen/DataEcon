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
                DAEC.call_check('de_finalize_search', search);
                rethrow(exception);
            end
            DAEC.call_check('de_finalize_search', search);
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
    end

end