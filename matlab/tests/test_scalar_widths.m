% Reading scalars of every width julia writes.
%
% libdaec stores a scalar as a type (signed, unsigned, float, complex, ...) and
% an opaque blob, so the width is only known from nbytes. DataEcon.jl writes
% Int8/16/32/64, UInt8/16/32/64, Float16/32/64 and ComplexF16/32/64 scalars at
% their own width (and Bool as a 1-byte signed integer). Before this was
% handled, every integer scalar was read as 8 bytes, which over-read the blob
% and returned garbage for anything narrower, and a Float16 or ComplexF16 was
% read as doubles.
%
% Integers come back as int64 or uint64 and floats as double, whatever width
% they were stored in, so a value written by julia reads the same as one written
% from matlab. 16-byte integers (Int128/UInt128) have no matlab type and must
% raise a clear error rather than a wrong value.
%
% As in test_float32, the values are written through the low-level library
% calls, which is the on-disk layout julia produces.

DAEC.load()
test_dir = '';
testFile = fullfile(test_dir, ['test_daec_widths_' num2str(randi(1000)) '.daec'])

enums = DAEC.enums;
S = enums.type_t.type_signed;
U = enums.type_t.type_unsigned;
F = enums.type_t.type_float;
C = enums.type_t.type_complex;

% name, type, blob, expected value
cases = {
    'i8_neg',    S, int8(-100),          int64(-100)
    'i8_bool',   S, int8(1),             int64(1)
    'i16_neg',   S, int16(-30000),       int64(-30000)
    'i32_neg',   S, int32(-2000000000),  int64(-2000000000)
    'i32_max',   S, intmax('int32'),     int64(intmax('int32'))
    'i64_min',   S, intmin('int64'),     intmin('int64')
    'u8_max',    U, intmax('uint8'),     uint64(255)
    'u16_max',   U, intmax('uint16'),    uint64(65535)
    'u32_max',   U, intmax('uint32'),    uint64(intmax('uint32'))
    'u64_max',   U, intmax('uint64'),    intmax('uint64')
    % Float16 bit patterns: 1.5, -2, 65504 (largest half), 2^-24 (smallest
    % subnormal), -0, Inf
    'f16_1p5',   F, uint16(15872),       1.5
    'f16_neg2',  F, uint16(49152),       -2
    'f16_max',   F, uint16(31743),       65504
    'f16_sub',   F, uint16(1),           2^-24
    'f16_negz',  F, uint16(32768),       -0
    'f16_inf',   F, uint16(31744),       Inf
    'f32',       F, single(0.1),         double(single(0.1))
    'f64',       F, 0.1,                 0.1
    % ComplexF16 is a pair of halves: 1.5 - 2i
    'c16',       C, uint16([15872 49152]), complex(1.5, -2)
    'c32',       C, single([1.25 -2.5]), complex(1.25, -2.5)
    'c64',       C, [0.1 -0.2],          complex(0.1, -0.2)
};

de = DEFile(testFile);
de.truncate();
scalars_id = de.new_catalog(0, 'scalars');
for k = 1:size(cases, 1)
    blob = cases{k, 3};
    store_scalar_raw(de, scalars_id, cases{k, 1}, cases{k, 2}, ...
        libpointer([class(blob) 'Ptr'], blob), numel(typecast(blob, 'uint8')));
end
% Int128: two 8-byte words, which no matlab class holds
store_scalar_raw(de, 0, 'i128', S, libpointer('int64Ptr', int64([-1 -1])), 16);
de.close();

% --- read it back -----------------------------------------------------------
de = DEFile(testFile);
results = de.read(0, 'scalars');

num_passed = 0;
num_tests = 0;
for k = 1:size(cases, 1)
    num_tests = num_tests + 1;
    name = cases{k, 1};
    want = cases{k, 4};
    got = results.(name);
    if ~strcmp(class(want), class(got))
        fprintf('❌ %s: expected class %s, got %s\n', name, class(want), class(got));
    elseif isequal(want, got) && isequal(sign(1 ./ double(real(want))), sign(1 ./ double(real(got))))
        % the 1/x comparison also tells -0 from 0
        num_passed = num_passed + 1;
    else
        fprintf('❌ %s:\n  expected: %s\n  got:      %s\n', name, mat2str(want, 17), mat2str(got, 17));
    end
end

num_tests = num_tests + 1;
try
    de.read(0, 'i128');
    fprintf('❌ i128: expected an error for a 16-byte integer\n');
catch err
    if strcmp(err.identifier, 'DAEC:BadElementSize')
        num_passed = num_passed + 1;
    else
        fprintf('❌ i128: expected DAEC:BadElementSize, got %s: %s\n', err.identifier, err.message);
    end
end
de.close();

if num_passed == num_tests
    fprintf('✅ scalar widths are working (%d/%d).\n', num_passed, num_tests);
else
    fprintf('❌ %d of %d SCALAR WIDTH TESTS FAILED!\n', num_tests - num_passed, num_tests);
end

% Clean up
if exist(testFile, 'file')
    delete(testFile);
end


function store_scalar_raw(de, pid, name, obj_type, val_ptr, nbytes)
    enums = DAEC.enums;
    id_ptr = libpointer('int64Ptr', 0);
    [~, ~, ~, ~] = DAEC.check_call('de_store_scalar', de.ptr, pid, char(name), ...
        obj_type, enums.frequency_t.freq_none, nbytes, val_ptr, id_ptr);
end
