/******************************************************************
*  Insert_scripts_table 
*  to enable runsql for adding all zones to an equipment
******************************************************************/ 
DECLARE
  l_row_count NUMBER := 0;
  l_option_no NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO  l_row_count
  FROM swms.scripts      
  WHERE script_name='add_all_zones_to_equip.sh';

  SELECT MAX(nvl(option_no, 0)) + 1
  INTO l_option_no
  FROM swms.scripts;
	  
  IF l_row_count = 0 THEN	  
    INSERT INTO swms.scripts (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT,
      LAST_RUN_DATE, LAST_RUN_USER, UPDATE_FUNCTION, PRINT_OPTIONS, DISPLAY_HELP, OPTION_NO)
    VALUES ('add_all_zones_to_equip.sh', 'MAINTENANCE', 'Y', 0,
      null, null, 'Y', null, 'Add all zones to the Equipment ID that is entered.', l_option_no); 
  END IF;
  
  
  SELECT COUNT(*)
  INTO  l_row_count
  FROM swms.scripts      
  WHERE script_name='delete_equipment.sh';

  SELECT MAX(nvl(option_no, 0)) + 1
  INTO l_option_no
  FROM swms.scripts;
	  
  IF l_row_count = 0 THEN	  
    INSERT INTO swms.scripts (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT,
      LAST_RUN_DATE, LAST_RUN_USER, UPDATE_FUNCTION, PRINT_OPTIONS, DISPLAY_HELP, OPTION_NO)
    VALUES ('delete_equipment.sh', 'MAINTENANCE', 'Y', 0,
      null, null, 'Y', null, 'Delete zones from the equipment', l_option_no); 
  END IF;

  COMMIT;
END;
/
