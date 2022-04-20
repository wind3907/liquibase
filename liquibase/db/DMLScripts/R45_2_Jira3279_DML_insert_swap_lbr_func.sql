DECLARE
    row_cnt PLS_INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  row_cnt
    FROM  swms.lbr_func
    WHERE lfun_lbr_func = 'SW';
    
    IF row_cnt = 0 THEN
        INSERT INTO swms.lbr_func (lfun_lbr_func, create_batch_flag, show_rf_batch_flag, print_goal_flag, uom, descrip, wis_hr_wk_qualify, calc_perf_inc, calc_ten_inc)
        VALUES ('SW', 'N', 'N', 'Y', 'PL', 'SWAP', NULL, 'HR', 'HR');

	COMMIT;
    END IF;
END;
/
