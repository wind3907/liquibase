CREATE OR REPLACE TRIGGER swms.trg_ins_upd_mf_arow
AFTER INSERT OR UPDATE ON swms.SAP_MF_IN
FOR EACH ROW
WHEN (USER != 'SWMS_JDBC' AND USER != 'OPS$SWMS')

------------------------------------------------------------------------------
-- Table:
--    SAP_MF_IN
--
-- Description:
--    This trigger maitains the log of records inserted or updated in the 
--    sap_equip_out table by inserting the old and new values into
--    SAP_TRACE_STAGING_TBL table.
--
-- Exceptions raised:
--    
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/22/10 ykri0358 swms212 Created
--                      Project: swms212- Staging table SAP_MF_IN 
--                      insert/update details to be written into 
--                      SAP_TRACE_STAGING_TBL table. 
------------------------------------------------------------------------------

DECLARE

message VARCHAR2(80); 

BEGIN

IF INSERTING THEN
    
   IF (SYS_CONTEXT('USERENV','MODULE')) NOT LIKE 'swmsmfreader%' THEN 
        INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number, 
        old_record_status, new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
        values('SAP_MF_IN', replace(USER,'OPS$',NULL), 'I', :NEW.sequence_number, 
        :OLD.record_status, :NEW.record_status, NULL, NULL, SYSDATE,
        substr(SYS_CONTEXT('USERENV','MODULE'),1,50));
   END IF;
END IF;

IF UPDATING THEN
    IF (SYS_CONTEXT('USERENV','MODULE')) NOT LIKE 'swmsmfreader%' THEN 
        INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number,
        old_record_status, new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
        values('SAP_MF_IN', replace(USER,'OPS$',NULL), 'U', :NEW.sequence_number, 
         :OLD.record_status, :NEW.record_status, NULL, NULL, SYSDATE,
         substr(SYS_CONTEXT('USERENV','MODULE'),1,50));
   END IF;
END IF;
    
EXCEPTION

    WHEN OTHERS THEN
        message := 'SAP_TRACE_STAGING_TBL:INSERT FAILED:Sequence-no :' || :NEW.sequence_number;
        pl_log.ins_msg('FATAL', 'trg_ins_upd_mf_arow', message, SQLCODE, SQLERRM, 'MANIFEST', 'trg_ins_upd_mf_arow.sql', 'Y');
        
END trg_ins_upd_mf_arow;
/  
