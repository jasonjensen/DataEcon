% Frequency -> IRIS conversion, and the unsupported-frequency policy.
%
% Neither part needs IRIS or the loaded library: the lookup table comes from
% daecenums and the policy lives on the DAEC singleton.
%
% The table is indexed directly by the DataEcon frequency value, so every
% entry has to be written at that index. Four of them used to be written at
% index+1, which left the bare base frequencies (plain quarterly, yearly,
% halfyearly, weekly) looking up 0 and falling through to the unsupported
% branch -- which is what made a silent unit-indexing fallback look necessary.

enums = DAEC.enums;
to_iris = enums.frequency_convert.to_iris;
freq = enums.frequency_t;

% every frequency DataEcon can store, and the IRIS frequency it maps to
expected = {
    'freq_yearly',          1
    'freq_yearly_jan',      1
    'freq_yearly_jun',      1
    'freq_yearly_dec',      1
    'freq_halfyearly',      2
    'freq_halfyearly_jan',  2
    'freq_halfyearly_jun',  2
    'freq_halfyearly_dec',  2
    'freq_quarterly',       4
    'freq_quarterly_jan',   4
    'freq_quarterly_mar',   4
    'freq_quarterly_dec',   4
    'freq_monthly',        12
    'freq_weekly',         52
    'freq_weekly_sun0',    52
    'freq_weekly_mon',     52
    'freq_weekly_thu',     52
    'freq_weekly_sun',     52
    'freq_daily',         365
    'freq_bdaily',        260
};

num_passed = 0;
for i = 1:size(expected, 1)
    name = expected{i, 1};
    want = expected{i, 2};
    f = freq.(name);
    got = to_iris(f);
    if got == want
        num_passed = num_passed + 1;
    else
        fprintf('❌ %s (enum %d): expected IRIS freq %d, got %d\n', name, f, want, got);
    end
end

if num_passed == size(expected, 1)
    fprintf('✅ frequency -> IRIS mapping is working (%d/%d).\n', num_passed, size(expected, 1));
else
    fprintf('❌ %d of %d FREQUENCY MAPPINGS FAILED!\n', ...
        size(expected, 1) - num_passed, size(expected, 1));
end

% freq_unit is deliberately unmapped: it has no calendar meaning, so
% iris_date indexes it by unit without needing the opt-in.
if to_iris(freq.freq_unit) == 0
    fprintf('✅ freq_unit is unmapped, as expected.\n');
else
    fprintf('❌ freq_unit should not have an IRIS mapping, got %d.\n', to_iris(freq.freq_unit));
end


% --- the unsupported-frequency policy -------------------------------------
policy_passed = 0;
policy_tests = 0;

restore = DAEC.iris_unsupported_freq();   % read, don't change

policy_tests = policy_tests + 1;
if strcmp(restore, 'error')
    policy_passed = policy_passed + 1;
else
    fprintf('❌ default policy should be ''error'', got ''%s''\n', restore);
end

policy_tests = policy_tests + 1;
prev = DAEC.iris_unsupported_freq('unit');
if strcmp(prev, 'error') && strcmp(DAEC.iris_unsupported_freq(), 'unit')
    policy_passed = policy_passed + 1;
else
    fprintf('❌ setting to ''unit'' did not take, or did not return the old value\n');
end

% reading must not change the setting
policy_tests = policy_tests + 1;
DAEC.iris_unsupported_freq();
if strcmp(DAEC.iris_unsupported_freq(), 'unit')
    policy_passed = policy_passed + 1;
else
    fprintf('❌ a no-argument call changed the setting\n');
end

policy_tests = policy_tests + 1;
try
    DAEC.iris_unsupported_freq('something_else');
    fprintf('❌ an invalid policy was accepted\n');
catch
    policy_passed = policy_passed + 1;
end

DAEC.iris_unsupported_freq(restore);

policy_tests = policy_tests + 1;
if strcmp(DAEC.iris_unsupported_freq(), restore)
    policy_passed = policy_passed + 1;
else
    fprintf('❌ could not restore the original policy\n');
end

if policy_passed == policy_tests
    fprintf('✅ unsupported-frequency policy is working (%d/%d).\n', policy_passed, policy_tests);
else
    fprintf('❌ %d of %d POLICY TESTS FAILED!\n', policy_tests - policy_passed, policy_tests);
end
