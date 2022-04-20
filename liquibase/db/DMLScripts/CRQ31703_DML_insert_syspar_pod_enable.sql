/*26/05/17  chyd9155    :CRQ31703-POD project iteration 1
Added to find if the opco is enabled for POD*/
/*21/06/17  lnic4226     Change config_flag_val to 'N' as default*/
/*06/12/17	  CHYD9155          DDL and DML standardization for merge  */


/********************************************************************
**    Create syspar POD_ENABLE
********************************************************************/



DECLARE
  v_row_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_row_exists
  FROM SWMS.SYS_CONFIG
  WHERE CONFIG_FLAG_NAME = 'POD_ENABLE';
        

  IF (v_row_exists = 0)
  THEN
	Insert into SWMS.SYS_CONFIG
   (SEQ_NO, APPLICATION_FUNC, CONFIG_FLAG_NAME, CONFIG_FLAG_DESC, CONFIG_FLAG_VAL, 
    VALUE_REQUIRED, VALUE_UPDATEABLE, VALUE_IS_BOOLEAN, DATA_TYPE, DATA_PRECISION, 
    SYS_CONFIG_LIST,VALIDATION_TYPE,SYS_CONFIG_HELP)
	Values
   ((SELECT MAX(seq_no)+1 FROM sys_config), 'DRIVER CHECK IN', 'POD_ENABLE', 'POD enabled?', 'N', 
    'Y', 'N', 'Y', 'CHAR', 1, 
    'L','LIST','If the OPCO has POD enabled then send OS and D details at the stop level to SUS to generate the final invoice to send it to customer in real-time after the delivery at each stop');
COMMIT;
END IF;
END;

/

Insert into SWMS.sys_config_valid_values (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
Select 'POD_ENABLE','Y','Enable POD' from dual
Where not exists (select 1 from sys_config_valid_values c1 where c1.CONFIG_FLAG_NAME = 'POD_ENABLE' and c1.config_flag_val='Y');


Insert into SWMS.sys_config_valid_values (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
Select 'POD_ENABLE','N','Disable POD' from dual
Where not exists (select 1 from sys_config_valid_values c1 where c1.CONFIG_FLAG_NAME = 'POD_ENABLE' and c1.config_flag_val='N');


COMMIT;
