CREATE OR REPLACE TRIGGER swms.trg_ins_sap_pm_misc_in_arow
BEFORE INSERT ON swms.sap_pm_misc_in
FOR EACH ROW
WHEN (NEW.RECORD_STATUS = 'N')

------------------------------------------------------------------------------
-- Table:
--    SAP_PM_MISC_IN
--
-- Description:
--    This trigger processes records from staging table and updates PM table
--
-- Exceptions raised:
--    
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/24/11 ykri0358 Created
--                      
------------------------------------------------------------------------------

DECLARE

query_str VARCHAR2(200);

BEGIN

    query_str := 'UPDATE PM SET ' || :NEW.attribute_ind || ' = ' || :NEW.pm_attribute || ' where prod_id = ' ||:NEW.prod_id;
    
    EXECUTE IMMEDIATE query_str ;
    
    IF SQL%ROWCOUNT = 0 THEN
    
        :NEW.record_status := 'F';
        pl_log.ins_msg('FATAL','trg_ins_sap_pm_misc_in_arow', 'PM:Update failed:Prod_id:' || :NEW.prod_id,SQLCODE,'NO DATA FOUND','MAINTENANCE',NULL,'Y');
    
    ELSE
	:NEW.record_status := 'S';

    END IF;

    EXCEPTION
    
        WHEN OTHERS THEN
            
            :NEW.record_status := 'F';
            
            pl_log.ins_msg('FATAL','trg_ins_sap_pm_misc_in_arow', 'PM:Update failed:Prod_id:' || :NEW.prod_id,SQLCODE,SQLERRM,'MAINTENANCE',NULL,'Y');
        
END trg_ins_sap_pm_misc_in_arow;  
/
