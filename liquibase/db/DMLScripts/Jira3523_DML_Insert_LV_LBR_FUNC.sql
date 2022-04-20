/******************************************************************
*  JIRA 3523  Create LR LM batches
*   
*
******************************************************************/ 

DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.lbr_func
    WHERE lfun_lbr_func = 'LR';
    
	IF v_row_count = 0 THEN
      
		Insert into swms.lbr_func (lfun_lbr_func, create_batch_flag, show_rf_batch_flag, print_goal_flag, uom, descrip, wis_hr_wk_qualify, calc_perf_inc, calc_ten_inc)
        values ('LR','N','N','Y','PL','LIVE RECEIVING',NULL, 'HR','HR');
		

	commit;
	END IF;
END;
/