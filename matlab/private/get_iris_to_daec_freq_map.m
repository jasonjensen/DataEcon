function [ret] = get_iris_to_daec_freq_map()
    
    persistent iris_to_daec_freq
    if isempty(iris_to_daec_freq)
        iris_to_daec_freq = zeros(366, 1);
        iris_to_daec_freq(1) = DAEC.enums.frequency_t.freq_yearly_dec;
        iris_to_daec_freq(4) = DAEC.enums.frequency_t.freq_quarterly_mar;
        iris_to_daec_freq(12) = DAEC.enums.frequency_t.freq_monthly;
        iris_to_daec_freq(52) = DAEC.enums.frequency_t.freq_weekly_thu;
        iris_to_daec_freq(365) = DAEC.enums.frequency_t.freq_daily;
    end

    ret = iris_to_daec_freq;

end

