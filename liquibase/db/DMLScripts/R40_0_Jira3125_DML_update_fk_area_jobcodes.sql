/******************************************************************
*  JIRA 3125 Add RTN column to default job code screen  
*   
*
******************************************************************/ 

DECLARE
v_row_count NUMBER := 0;
BEGIN

	update fk_area_jobcodes
	set rtn_jobcode = 'CLRRTN'
	where sub_area_code = 'C';

	update fk_area_jobcodes
	set rtn_jobcode = 'DRYRTN'
	where sub_area_code = 'D';

	update fk_area_jobcodes
	set rtn_jobcode = 'FZRRTN'
	where sub_area_code = 'F';    
	
	commit;
	
END;
/