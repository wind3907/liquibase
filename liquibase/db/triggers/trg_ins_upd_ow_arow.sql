CREATE OR REPLACE TRIGGER swms.trg_ins_upd_ow_arow
BEFORE INSERT OR UPDATE ON swms.sap_ow_out
FOR EACH ROW
WHEN (USER != 'SWMS_JDBC' AND USER != 'OPS$SWMS')

------------------------------------------------------------------------------
-- Table:
--    SAP_OW_OUT
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
--                      Project: swms212- Staging table SAP_OW_OUT 
--                      insert/update details to be written into 
--                      SAP_TRACE_STAGING_TBL table. 
--    01/26/12 sray0453	Retriggered message should be sent to SAP 
--			with bypass_flag turned on.
------------------------------------------------------------------------------

DECLARE

message VARCHAR2(80); 
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN


IF INSERTING THEN
    IF (SYS_CONTEXT('USERENV','MODULE')) NOT LIKE 'swmsowwriter%' THEN 
        INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number, old_batch_id, new_batch_id, 
        old_record_status, new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
        values('SAP_OW_OUT', replace(USER,'OPS$',NULL), 'I', :NEW.sequence_number, :OLD.batch_id,
        :NEW.batch_id, :OLD.record_status, :NEW.record_status, :OLD.bypass_flag,:NEW.bypass_flag, SYSDATE,
        substr(SYS_CONTEXT('USERENV','MODULE'),1,50));
    END IF;
END IF;

IF UPDATING THEN
    IF (SYS_CONTEXT('USERENV','MODULE')) NOT LIKE 'swmsowwriter%' THEN 
        INSERT INTO SAP_TRACE_STAGING_TBL (
        staging_table, upd_user, Ins_upd_flag, sequence_number, old_batch_id, new_batch_id, 
        old_record_status, new_record_status, old_bypass_flag, new_bypass_flag, add_date,sys_context_parameter)
        values('SAP_OW_OUT', replace(USER,'OPS$',NULL), 'U', :NEW.sequence_number, :OLD.batch_id,
        :NEW.batch_id, :OLD.record_status, :NEW.record_status, :OLD.bypass_flag,:NEW.bypass_flag, SYSDATE,
        substr(SYS_CONTEXT('USERENV','MODULE'),1,50));
    END IF;
    IF (:OLD.record_status = 'S' OR :OLD.record_status = 'F') AND :NEW.record_status='N' THEN

        :NEW.bypass_flag := 'Y';

                --update BYPASS_FLAG to 'Y' for other records in SAP_OW_OUT having same BATCH_ID and ROUTE_NO
                BEGIN
                UPDATE swms.sap_ow_out
                SET bypass_flag = 'Y',
                record_status = 'N'
                WHERE batch_id = :OLD.batch_id
                AND route_no = :OLD.route_no
                AND sequence_number != :OLD.sequence_number
                AND bypass_flag != 'Y';
                
	EXCEPTION
                        WHEN OTHERS THEN
                                message := 'trg_upd_ow_arow:ERROR';
                                pl_log.ins_msg('FATAL', 'trg_upd_ow_arow', message, SQLCODE, SQLERRM, 'RESEND OF ROUTE FAILED', 'trg_upd_ow_arow.sql', 'Y');
                END;

END IF;
END IF;
COMMIT;
EXCEPTION

    WHEN OTHERS THEN
        message := 'SAP_TRACE_STAGING_TBL:INSERT FAILED:Sequence-no :' || :NEW.sequence_number;
        pl_log.ins_msg('FATAL', 'trg_ins_upd_ow_arow', message, SQLCODE, SQLERRM, 'PICK ADJUSTMENT', 'trg_ins_upd_ow_arow.sql', 'Y');
        
END trg_ins_upd_ow_arow;
/  
