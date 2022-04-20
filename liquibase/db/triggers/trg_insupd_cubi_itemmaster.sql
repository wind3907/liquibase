CREATE OR REPLACE TRIGGER swms.trg_insupd_cubi_itemmaster
AFTER INSERT OR UPDATE ON swms.CUBITRON_ITEMMASTER_OUT
FOR EACH ROW
WHEN (USER != 'SWMS_JDBC' AND USER != 'OPS$SWMS')
------------------------------------------------------------------------------
-- Table:
--    CUBITRON_ITEMMASTER_OUT
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
--                      Project: swms212- Staging table CUBITRON_ITEMMASTER_OUT 
--                      insert/update details to be written into 
--                      SAP_TRACE_STAGING_TBL table. 
------------------------------------------------------------------------------

DECLARE

message VARCHAR2(80); 

BEGIN

IF INSERTING THEN
    
    INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number,old_record_status,
        new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
    values('CUBITRON_ITEMMASTER_OUT', replace(USER,'OPS$',NULL), 'I', :NEW.sequence_number, 
     :OLD.record_status, :NEW.record_status, NULL, NULL, SYSDATE,
     substr(SYS_CONTEXT('USERENV','MODULE'),1,50));     

END IF;

IF UPDATING THEN
    
    INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number,old_record_status,
        new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
    values('CUBITRON_ITEMMASTER_OUT', replace(USER,'OPS$',NULL), 'U', :NEW.sequence_number, 
     :OLD.record_status, :NEW.record_status, NULL, NULL, SYSDATE,
     substr(SYS_CONTEXT('USERENV','MODULE'),1,50));

END IF;
    
EXCEPTION

    WHEN OTHERS THEN
        message := 'SAP_TRACE_STAGING_TBL:INSERT FAILED:Sequence-no :' || :NEW.sequence_number;
        pl_log.ins_msg('FATAL', 'trg_insupd_cubi_itemmaster', message, SQLCODE, SQLERRM, 'CUBITRON', 'trg_insupd_cubi_itemmaster.sql', 'Y');
        
END trg_insupd_cubi_itemmaster;
/  
