CREATE OR REPLACE TRIGGER SWMS.trg_insupt_pm_hazardous
BEFORE INSERT OR UPDATE OF HAZARDOUS
ON SWMS.PM 
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW   
DECLARE
	v_test varchar2(1 byte);

/******************************************************************************
   NAME:       trg_insupt_pm_hazardous
   PURPOSE:    
        To avoid the the temp_trk insert or update through the swmsimreader.This
        will handle the both insert and update of temp_trk value in pm Table.
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/14/2013      manoj_devendhiran       1. Created this trigger.
   2.0        04/20/202      XZHE5043  JIRA779 added syspar check

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     trg_insupt_pm_hazardous
      Sysdate:         8/14/2013
      Date and Time:   8/14/2013, 11:04:50 AM, and 8/14/2013 11:04:50 AM
      Username:        manoj_devendhiran (set in TOAD Options, Proc Templates)
      Table Name:      PM (set in the "New PL/SQL Object" dialog)
      Trigger Options:  (set in the "New PL/SQL Object" dialog)
******************************************************************************/
BEGIN
	IF pl_common.f_get_syspar('ENABLE_PM_TEMP_TRK', 'N') ='N' THEN
		IF :NEW.HAZARDOUS IS NOT NULL THEN
			SELECT NVL(temp_trk,'N') INTO v_test 
			  FROM HACCP_CODES
			 WHERE haccp_code = :NEW.HAZARDOUS;

			:NEW.TEMP_TRK:=v_test;
		ELSE 
			:NEW.TEMP_TRK:= 'N';
		END IF; 
	END IF;              
		EXCEPTION
		   WHEN NO_DATA_FOUND THEN
				:NEW.TEMP_TRK:= 'N';
		   WHEN OTHERS THEN
				pl_log.ins_msg('WARN', 'trg_insupt_pm_hazardous', 'Final WHEN-OTHERS catch all error insert or update of hazardous record.', SQLCODE, SQLERRM, 'INVENTORY', 'trg_insupt_pm_hazardous');                  
END trg_insupt_pm_hazardous;
/

