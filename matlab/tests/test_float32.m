% Reading 32-bit float data written by julia.
%
% The library stores float values as an opaque blob and reports type_float for
% both single and double precision, so the reader has to divide nbytes by the
% element count to tell them apart. Before this was handled, a Float32 series
% written from julia was memcpy'd straight into a double array, which produced
% garbage values and over-read the blob by a factor of two.
%
% The high-level matlab writer only emits doubles, so this test writes the
% single-precision values through the low-level library calls instead - that is
% the same on-disk layout julia produces. No library changes are needed for any
% of this, so it runs against the stock libdaec build.
%
% Covered here: scalars, vectors and matrices, in single and double precision,
% real and complex. Not covered: ndtseries (tensors). DEFile.read_ndtseries
% cannot tell the two widths apart because de_load_ndtseries_value does not
% return nbytes - see the TODO there - so a single-precision tensor is still
% misread on this side. src/test.c covers the tensor case at the library level,
% where nbytes is available.

DAEC.load()
test_dir = '';
testFile = fullfile(test_dir, ['test_daec_f32_' num2str(randi(1000)) '.daec'])

% values chosen so that single(v) ~= v for some of them, and exact for others
raw_vals = [0.1, 0.2, 1.5, 2.25, 100.375, -3.5];
raw_mat = [0.1, 0.2, 1.5; 2.25, 100.375, -3.5];
raw_scalar = 0.1;
raw_complex = complex(1.25, -2.5);
% complex arrays, which the binding stores as [real(v), imag(v)] - all the real
% parts first, then all the imaginary ones, not interleaved pairs
raw_complex_vec = [complex(1.25, -2.5); complex(0.1, 0.2); complex(100.375, -3.5)];
raw_complex_mat = complex(raw_mat, -raw_mat);

% what a correct read must return: the double value of the stored single
expected.vectors.f32_plain = double(single(raw_vals(:)));
expected.vectors.f64_plain = raw_vals(:);
expected.vectors.c32_plain = as_single_complex(raw_complex_vec);
expected.vectors.c64_plain = raw_complex_vec;
expected.scalars.f32_scalar = double(single(raw_scalar));
expected.scalars.f64_scalar = raw_scalar;
expected.scalars.f32_complex = as_single_complex(raw_complex);
expected.scalars.f64_complex = raw_complex;
expected.matrices.f32_matrix = double(single(raw_mat));
expected.matrices.f64_matrix = raw_mat;
expected.matrices.c32_matrix = as_single_complex(raw_complex_mat);
expected.matrices.c64_matrix = raw_complex_mat;

de = DEFile(testFile);
de.truncate();

% --- write the fixtures through the low-level api ---------------------------
enums = DAEC.enums;

vectors_id = de.new_catalog(0, 'vectors');
scalars_id = de.new_catalog(0, 'scalars');
matrices_id = de.new_catalog(0, 'matrices');

nvals = numel(raw_vals);
vec_axis = de.create_axis(enums.frequency_t.freq_none, nvals, 1);

% single-precision vector: 4 bytes per element
store_tseries_raw(de, vectors_id, 'f32_plain', enums.type_t.type_vector, ...
    vec_axis, libpointer('singlePtr', single(raw_vals(:))), 4 * nvals);
% double-precision vector: unchanged behaviour, guards against a regression
store_tseries_raw(de, vectors_id, 'f64_plain', enums.type_t.type_vector, ...
    vec_axis, libpointer('doublePtr', double(raw_vals(:))), 8 * nvals);

% complex vectors: 3 elements, so 6 parts - 8 bytes per element when single,
% 16 when double. This is the width a reader is most likely to get wrong,
% because a complex element is a *pair* of floats rather than one.
ncplx = numel(raw_complex_vec);
cplx_axis = de.create_axis(enums.frequency_t.freq_none, ncplx, 1);
store_tseries_raw(de, vectors_id, 'c32_plain', enums.type_t.type_vector, ...
    cplx_axis, libpointer('singlePtr', single(split_complex(raw_complex_vec))), ...
    8 * ncplx, enums.type_t.type_complex);
store_tseries_raw(de, vectors_id, 'c64_plain', enums.type_t.type_vector, ...
    cplx_axis, libpointer('doublePtr', double(split_complex(raw_complex_vec))), ...
    16 * ncplx, enums.type_t.type_complex);

% single- and double-precision matrices
[nrows, ncols] = size(raw_mat);
ax1 = de.create_axis(enums.frequency_t.freq_none, nrows, 1);
ax2 = de.create_axis(enums.frequency_t.freq_none, ncols, 1);
store_mvtseries_raw(de, matrices_id, 'f32_matrix', enums.type_t.type_matrix, ...
    ax1, ax2, libpointer('singlePtr', single(raw_mat(:))), 4 * numel(raw_mat));
store_mvtseries_raw(de, matrices_id, 'f64_matrix', enums.type_t.type_matrix, ...
    ax1, ax2, libpointer('doublePtr', double(raw_mat(:))), 8 * numel(raw_mat));

% complex matrices, on the same axes as the real ones
store_mvtseries_raw(de, matrices_id, 'c32_matrix', enums.type_t.type_matrix, ...
    ax1, ax2, libpointer('singlePtr', single(split_complex(raw_complex_mat))), ...
    8 * numel(raw_complex_mat), enums.type_t.type_complex);
store_mvtseries_raw(de, matrices_id, 'c64_matrix', enums.type_t.type_matrix, ...
    ax1, ax2, libpointer('doublePtr', double(split_complex(raw_complex_mat))), ...
    16 * numel(raw_complex_mat), enums.type_t.type_complex);

% scalars
store_scalar_raw(de, scalars_id, 'f32_scalar', enums.type_t.type_float, ...
    libpointer('singlePtr', single(raw_scalar)), 4);
store_scalar_raw(de, scalars_id, 'f64_scalar', enums.type_t.type_float, ...
    libpointer('doublePtr', double(raw_scalar)), 8);
% a complex single is two 4-byte floats
store_scalar_raw(de, scalars_id, 'f32_complex', enums.type_t.type_complex, ...
    libpointer('singlePtr', single(split_complex(raw_complex))), 8);
% the double-precision pair, so a reader that hardcodes one width fails here
store_scalar_raw(de, scalars_id, 'f64_complex', enums.type_t.type_complex, ...
    libpointer('doublePtr', double(split_complex(raw_complex))), 16);

de.close();

% --- read it back through the normal path -----------------------------------
de = DEFile(testFile);
results_struct = de.read();
de.close();

num_passed = 0;
num_tests = 0;
for f = fieldnames(expected)'
    sub_expected = expected.(f{1});
    sub_results = results_struct.(f{1});
    for ff = fieldnames(sub_expected)'
        num_tests = num_tests + 1;
        want = sub_expected.(ff{1});
        got = sub_results.(ff{1});
        if ~isa(got, 'double')
            fprintf('❌ %s.%s: expected class double, got %s\n', f{1}, ff{1}, class(got));
            continue
        end
        if ~isequal(size(want), size(got))
            fprintf('❌ %s.%s: expected size %s, got %s\n', f{1}, ff{1}, ...
                mat2str(size(want)), mat2str(size(got)));
            continue
        end
        % values must match bit for bit - widening a single to double is exact
        if isequal(want, got)
            num_passed = num_passed + 1;
        else
            fprintf('❌ %s.%s:\n  expected: %s\n  got:      %s\n', f{1}, ff{1}, ...
                mat2str(want, 17), mat2str(got, 17));
        end
    end
end

if num_passed == num_tests
    fprintf('✅ float32 reading is working (%d/%d).\n', num_passed, num_tests);
else
    fprintf('❌ %d of %d FLOAT32 TESTS FAILED!\n', num_tests - num_passed, num_tests);
end

% Clean up
if exist(testFile, 'file')
    delete(testFile);
end


% --- low-level write helpers ------------------------------------------------
% The high-level writer promotes everything to double, so these bypass it and
% hand the library a raw single-precision blob, the way julia does.

function store_tseries_raw(de, pid, name, obj_type, axis_id, val_ptr, nbytes, eltype)
    enums = DAEC.enums;
    if nargin < 8
        eltype = enums.type_t.type_float;
    end
    id_ptr = libpointer('int64Ptr', 0);
    [~, ~, ~, ~] = DAEC.check_call('de_store_tseries', de.ptr, pid, char(name), ...
        obj_type, eltype, enums.frequency_t.freq_none, ...
        axis_id, nbytes, val_ptr, id_ptr);
end

function store_mvtseries_raw(de, pid, name, obj_type, axis_id1, axis_id2, val_ptr, nbytes, eltype)
    enums = DAEC.enums;
    if nargin < 9
        eltype = enums.type_t.type_float;
    end
    id_ptr = libpointer('int64Ptr', 0);
    [~, ~, ~, ~] = DAEC.check_call('de_store_mvtseries', de.ptr, pid, char(name), ...
        obj_type, eltype, enums.frequency_t.freq_none, ...
        axis_id1, axis_id2, nbytes, val_ptr, id_ptr);
end

function store_scalar_raw(de, pid, name, obj_type, val_ptr, nbytes)
    enums = DAEC.enums;
    id_ptr = libpointer('int64Ptr', 0);
    [~, ~, ~, ~] = DAEC.check_call('de_store_scalar', de.ptr, pid, char(name), ...
        obj_type, enums.frequency_t.freq_none, nbytes, val_ptr, id_ptr);
end

% --- complex layout helpers -------------------------------------------------

function parts = split_complex(value)
    % The binding's on-disk layout for a complex array: every real part, then
    % every imaginary part, which for a column vector or matrix is just the
    % horizontal concatenation read in column-major order.
    parts = [real(value), imag(value)];
end

function out = as_single_complex(value)
    % What a correct read must return for a complex single: each part rounded
    % to single precision and widened back to double.
    out = complex(double(single(real(value))), double(single(imag(value))));
end
