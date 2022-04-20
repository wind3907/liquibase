CREATE OR REPLACE TRIGGER swms.trg_ins_upd_lm_arow
AFTER INSERT OR UPDATE ON swms.sap_lm_out
FOR EACH ROW
WHEN (USER != 'SWMS_JDBC' AND USER != 'OPS$SWMS')

------------------------------------------------------------------------------
-- Table:
--    SAP_LM_OUT
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
--                      Project: swms212- Staging table SAP_LM_OUT 
--                      insert/update details to be written into 
--                      SAP_TRACE_STAGING_TBL table. 
------------------------------------------------------------------------------

DECLARE

message VARCHAR2(80); 

BEGIN

IF INSERTING THEN
    IF (SYS_CONTEXT('USERENV','MODULE')) NOT LIKE 'TRG_INSUPD_PM_BROW%' THEN
        INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number, old_batch_id, new_batch_id, 
        old_record_status, new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
        values('SAP_LM_OUT', replace(USER,'OPS$',NULL), 'I', :NEW.sequence_number, :OLD.batch_id,
        :NEW.batch_id, :OLD.record_status, :NEW.record_status, :OLD.bypass_flag,:NEW.bypass_flag, SYSDATE,
        substr(SYS_CONTEXT('USERENV','MODULE'),1,60));
    END IF;
END IF;

IF UPDATING THEN
    IF (SYS_CONTEXT('USERENV','MODULE')) NOT LIKE 'TRG_INSUPD_PM_BROW%' THEN
        INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number, old_batch_id, new_batch_id, 
        old_record_status, new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
        values('SAP_LM_OUT', replace(USER,'OPS$',NULL), 'U', :NEW.sequence_number, :OLD.batch_id,
        :NEW.batch_id, :OLD.record_status, :NEW.record_status, :OLD.bypass_flag,:NEW.bypass_flag, SYSDATE,
        substr(SYS_CONTEXT('USERENV','MODULE'),1,60));
    END IF;
END IF;
    
EXCEPTION

    WHEN OTHERS THEN
        message := 'SAP_TRACE_STAGING_TBL:INSERT FAILED:Sequence-no :' || :NEW.sequence_number;
        pl_log.ins_msg('FATAL', 'trg_ins_upd_lm_arow', message, SQLCODE, SQLERRM, 'PICK ADJUSTMENT', 'trg_ins_upd_lm_arow.sql', 'Y');
        
END trg_ins_upd_lm_arow;
/  
