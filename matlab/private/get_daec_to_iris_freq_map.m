function [ret] = get_daec_to_iris_freq_map()
    
    persistent daec_to_iris_freq
    if isempty(daec_to_iris_freq)
        daec_to_iris_freq = zeros(300, 1);

        % Map DataEcon frequency ranges to IRIS frequencies
        % Yearly frequencies (256-268)
        for i = DAEC.enums.frequency_t.freq_yearly:DAEC.enums.frequency_t.freq_yearly_dec
            daec_to_iris_freq(i+1) = 1;
        end

        % Half-yearly frequencies (128-134)  
        for i = DAEC.enums.frequency_t.freq_halfyearly:DAEC.enums.frequency_t.freq_halfyearly_dec
            daec_to_iris_freq(i+1) = 2;
        end

        % Quarterly frequencies (64-67)
        for i = DAEC.enums.frequency_t.freq_quarterly:DAEC.enums.frequency_t.freq_quarterly_dec
            daec_to_iris_freq(i+1) = 4;
        end

        % Monthly frequency (32)
        daec_to_iris_freq(DAEC.enums.frequency_t.freq_monthly) = 12;

        % Weekly frequencies (16-23)
        for i = DAEC.enums.frequency_t.freq_weekly:DAEC.enums.frequency_t.freq_weekly_sun
            daec_to_iris_freq(i+1) = 52;
        end

        % Daily frequencies
        daec_to_iris_freq(DAEC.enums.frequency_t.freq_daily) = 365;
        daec_to_iris_freq(DAEC.enums.frequency_t.freq_bdaily) = 260;  % Business daily

    end

    ret = daec_to_iris_freq;

end

