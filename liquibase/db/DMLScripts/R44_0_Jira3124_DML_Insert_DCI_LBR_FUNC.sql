/******************************************************************
*  JIRA 3124  
*   
*
******************************************************************/ 

DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.lbr_func
    WHERE lfun_lbr_func = 'DC';
    
	IF v_row_count = 0 THEN
      
		Insert into swms.lbr_func (lfun_lbr_func, create_batch_flag, show_rf_batch_flag, print_goal_flag, uom, descrip, wis_hr_wk_qualify, calc_perf_inc, calc_ten_inc)
        values ('DC','N','N','Y','PL','DCI PUTAWAY TRACKING',6, 'CS','CS');

	commit;
	END IF;
END;
/