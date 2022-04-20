/******************************************************************
*  Insert_scripts_table 
*  to enable runsql list available for users 
*   
*  07/30/2018 xzhe5043
******************************************************************/ 
DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
     INTO  v_row_count
      from swms.scripts      
      WHERE script_name='SO_not_shipped_rpt.sh';
	  
    IF v_row_count = 0 THEN	  
		Insert into swms.scripts (SCRIPT_NAME,APPLICATION_FUNC,RESTARTABLE,RUN_COUNT,
							     LAST_RUN_DATE,LAST_RUN_USER,UPDATE_FUNCTION,PRINT_OPTIONS,DISPLAY_HELP,OPTION_NO) 
		values ('SO_not_shipped_rpt.sh','ORDER PROCESSING','Y',1,
		SYSDATE-4,'OPS$USSDJV','N','-w132 -z1 -p12','   Displays not shipped Sales order information.',209);
     End If;
  commit;
END;
/