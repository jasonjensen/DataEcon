% test_tse.m
% Round-trip tests for storing/reading TimeSeriesEcon.m series to a .daec file.
%
% Requires BOTH the +tse package on the MATLAB path AND a loadable libdaec
% (file I/O goes through the native library).  Writes tse.TSeries /
% tse.MVTSeries of every frequency to a temp .daec, reads them back with
% 'read_to_tse', and compares firstdate / values / colnames.
%
% Usage: set tseRoot to your TimeSeriesEcon.m checkout, then run this script.

tseRoot = '';   % e.g. '../../TimeSeriesEcon.m'
if ~isempty(tseRoot)
    addpath(tseRoot);
end
if exist('tse.MIT', 'class') ~= 8
    error('TimeSeriesEcon.m (+tse) is not on the path; set tseRoot at the top of this script.');
end

DAEC.load()
test_dir = '';
testFile = fullfile(test_dir, ['test_daec_tse' num2str(randi(1000)) '.daec']);

% --- build test data ------------------------------------------------------
test_struct = struct();

test_struct.tseries = struct();
test_struct.tseries.yearly       = tse.TSeries(tse.yy(1990),                        (1:30)');
test_struct.tseries.halfyearly   = tse.TSeries(tse.MIT(tse.HalfYearly(6), 2000, 1), (1:12)');
test_struct.tseries.quarterly    = tse.TSeries(tse.qq(2000, 1),                     100 + cumsum(randn(24, 1)));
% non-default end period -> exercises the DataEcon enum aliasing (code 65)
test_struct.tseries.quarterly_jan = tse.TSeries(tse.MIT(tse.Quarterly(1), 2000, 1), (1:8)');
test_struct.tseries.monthly      = tse.TSeries(tse.mm(2010, 6),                     (1:60)');
test_struct.tseries.weekly       = tse.TSeries(tse.MIT(tse.Weekly(7), 2021, 1),     rand(10, 1));
test_struct.tseries.daily        = tse.TSeries(tse.day('2023-01-01'),               cumsum(randn(15, 1)));
test_struct.tseries.bdaily       = tse.TSeries(tse.bday('2023-01-02'),              cumsum(randn(20, 1)));

test_struct.mvtseries = struct();
test_struct.mvtseries.quarterly = tse.MVTSeries(tse.qq(2000, 1),                 {'gdp','cpi','rate'}, reshape(1:72, 24, 3));
test_struct.mvtseries.monthly   = tse.MVTSeries(tse.mm(2010, 6),                 {'x','y'},            reshape(1:120, 60, 2));
test_struct.mvtseries.weekly    = tse.MVTSeries(tse.MIT(tse.Weekly(7), 2021, 1), {'p','q'},            reshape(1:20, 10, 2));

% --- write, then read back as tse objects --------------------------------
de = DEFile(testFile);
de.truncate();
de.write(test_struct);
de.close();

de = DEFile(testFile, 'read_to_tse', true);
results_struct = de.read();
de.close();

% --- compare --------------------------------------------------------------
for f = fieldnames(test_struct)'
    sub_orig = test_struct.(f{1});
    sub_res  = results_struct.(f{1});
    num_tests  = numel(fieldnames(sub_orig));
    num_passed = 0;
    for ff = fieldnames(sub_orig)'
        if compare_tse(sub_orig.(ff{1}), sub_res.(ff{1}), ff{1})
            num_passed = num_passed + 1;
        end
    end
    if num_passed == num_tests
        fprintf('✅ %s reading and writing is working (%d/%d).\n', f{1}, num_passed, num_tests);
    else
        fprintf('❌ %s: %d of %d FAILED.\n', f{1}, num_tests - num_passed, num_tests);
    end
end

% --- regression: default read (no read_to_tse) still yields DESeries -----
de = DEFile(testFile, 'readonly', true);
plain = de.read();
de.close();
if isa(plain.tseries.yearly, 'DESeries') && isa(plain.mvtseries.quarterly, 'DESeries')
    fprintf('✅ default read (no read_to_tse) still returns DESeries.\n');
else
    fprintf('❌ default read regression: expected DESeries, got %s / %s.\n', ...
        class(plain.tseries.yearly), class(plain.mvtseries.quarterly));
end

if exist(testFile, 'file')
    delete(testFile);
end

% --- local comparison helper ---------------------------------------------
function same = compare_tse(orig, read, name)
    same = false;
    if ~strcmp(class(orig), class(read))
        fprintf('  ❌ %s: class %s -> %s\n', name, class(orig), class(read));
        return
    end
    if orig.firstdate ~= read.firstdate
        fprintf('  ❌ %s: firstdate %s -> %s\n', name, char(orig.firstdate), char(read.firstdate));
        return
    end
    if ~isequaln(orig.values, read.values)
        fprintf('  ❌ %s: values differ\n', name);
        return
    end
    if isa(orig, 'tse.MVTSeries')
        if ~isequal(cellstr(orig.colnames), cellstr(read.colnames))
            fprintf('  ❌ %s: colnames {%s} -> {%s}\n', name, ...
                strjoin(cellstr(orig.colnames), ','), strjoin(cellstr(read.colnames), ','));
            return
        end
    end
    same = true;
end
