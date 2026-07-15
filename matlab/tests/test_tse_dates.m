% test_tse_dates.m
% Encoding and round-trip tests for the tse.MIT <-> DEDate date layer.
%
% Requires the TimeSeriesEcon.m +tse package on the MATLAB path.  The core
% identity and round-trip checks need only the DataEcon MATLAB classes -- no
% native libdaec library.  If libdaec is loadable, an extra calendar
% cross-check confirms that BOTH libraries decode the shared integer to the
% same (year, period) / (year, month, day) -- this is what actually pins the
% weekly / bdaily epoch alignment.
%
% Usage: set tseRoot to your TimeSeriesEcon.m checkout, then run this script.

% --- add the tse package to the path -------------------------------------
tseRoot = '';   % e.g. '../../TimeSeriesEcon.m'
if ~isempty(tseRoot)
    addpath(tseRoot);
end
if exist('tse.MIT', 'class') ~= 8
    error('TimeSeriesEcon.m (+tse) is not on the path; set tseRoot at the top of this script.');
end

% --- try to load libdaec for the optional calendar cross-check -----------
have_lib = false;
try
    DAEC.load();
    have_lib = DAEC.isloaded();
catch
    have_lib = false;
end

% --- one MIT per frequency -----------------------------------------------
% Columns: name, MIT, kind ('yp' | 'cal' | 'none' for the cross-check)
cases = {
    'yearly',      tse.yy(2020),                          'yp'
    'halfyearly',  tse.MIT(tse.HalfYearly(6), 2020, 2),   'yp'
    'quarterly',   tse.qq(2020, 3),                       'yp'
    'monthly',     tse.mm(2020, 7),                       'yp'
    'weekly',      tse.MIT(tse.Weekly(7), 2021, 10),      'cal'
    'daily',       tse.day('2023-01-15'),                 'cal'
    'bdaily',      tse.bday('2023-01-16'),                'cal'
    'unit',        tse.MIT(tse.Unit(), 42),               'none'
};

num_passed = 0;
num_tests  = 0;

for i = 1:size(cases, 1)
    name = cases{i, 1};
    m    = cases{i, 2};
    kind = cases{i, 3};

    % (1) forward: tse.MIT -> DEDate is the identity on (frequency, value)
    d = DAEC.daec_from_tse_date(m);
    num_tests = num_tests + 1;
    if double(d.frequency) == double(m.frequency) && int64(d.value) == int64(m.value)
        num_passed = num_passed + 1;
    else
        fprintf('❌ %-11s forward identity failed: MIT %d/%d vs DEDate %d/%d\n', ...
            name, double(m.frequency), int64(m.value), ...
            double(d.frequency), int64(d.value));
    end

    % (2) inverse: DEDate -> tse.MIT round-trips
    m2 = DAEC.tse_date(d);
    num_tests = num_tests + 1;
    if m == m2
        num_passed = num_passed + 1;
    else
        fprintf('❌ %-11s inverse round-trip failed: %s vs %s\n', ...
            name, char(m), char(m2));
    end

    % (3) optional: libdaec must decode the shared integer the same way tse does
    if have_lib && ~strcmp(kind, 'none')
        num_tests = num_tests + 1;
        try
            if strcmp(kind, 'yp')
                year_ptr   = libpointer('int32Ptr', 0);
                period_ptr = libpointer('uint32Ptr', 0);
                [y, p] = DAEC.check_call('de_unpack_year_period_date', ...
                    d.frequency, d.value, year_ptr, period_ptr);
                yp = tse.mit2yp(m);
                ok = (double(y) == double(yp(1))) && (double(p) == double(yp(2)));
                if ~ok
                    fprintf('❌ %-11s YP cross-check: libdaec (%d,%d) vs tse (%d,%d)\n', ...
                        name, double(y), double(p), double(yp(1)), double(yp(2)));
                end
            else % 'cal'
                year_ptr  = libpointer('int32Ptr', 0);
                month_ptr = libpointer('uint32Ptr', 0);
                day_ptr   = libpointer('uint32Ptr', 0);
                [y, mo, dy] = DAEC.check_call('de_unpack_calendar_date', ...
                    d.frequency, d.value, year_ptr, month_ptr, day_ptr);
                [ty, tm, td] = ymd(tse.toDate(m));   % end-of-period day
                ok = (double(y) == ty) && (double(mo) == tm) && (double(dy) == td);
                if ~ok
                    fprintf('❌ %-11s calendar cross-check: libdaec %04d-%02d-%02d vs tse %04d-%02d-%02d\n', ...
                        name, double(y), double(mo), double(dy), ty, tm, td);
                end
            end
            num_passed = num_passed + double(ok);
        catch e
            fprintf('❌ %-11s cross-check errored: %s\n', name, e.message);
        end
    end
end

if ~have_lib
    fprintf('ℹ️  libdaec not loaded; ran identity + round-trip only (skipped the calendar cross-check).\n');
end
if num_passed == num_tests
    fprintf('✅ tse.MIT <-> DEDate date layer: %d/%d checks passed.\n', num_passed, num_tests);
else
    fprintf('❌ %d of %d checks FAILED.\n', num_tests - num_passed, num_tests);
end
