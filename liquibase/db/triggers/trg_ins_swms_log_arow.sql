CREATE OR REPLACE TRIGGER swms.trg_ins_swms_log_arow
AFTER INSERT ON swms.swms_log
FOR EACH ROW
WHEN (NEW.MSG_ALERT = 'Y' AND NEW.MSG_TEXT IS NOT NULL)
------------------------------------------------------------------------------
-- Table:
--    SWMS_LOG
--
-- Description:
--    This trigger inserts the log record into appl_error_log table when the 
--    newly inserted record has msg_alert field value as 'Y'.
--
-- Exceptions raised:
--    
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/24/10 ykri0358 swms212 Created
--                      Project: swms212-SWMS Log details to be written into 
--                      appl_error_log table. 
------------------------------------------------------------------------------

DECLARE

message VARCHAR2(2000);

BEGIN
    
    INSERT INTO appl_error_log
    (routing_code, severity, priority, error_code, error_seq, 
error_status,add_time,update_time, event_id, error_msg)values
    ('SWMS-APPS','E','2',substr(:NEW.SQL_ERR_MSG,1,10), :NEW.Process_id, ' ', SYSDATE,SYSDATE, 0, substr(:NEW.MSG_TEXT,1,70));
    
EXCEPTION

    WHEN OTHERS THEN
        message := 'Insert into appl_error_log table failed for log: Process_id:' || :NEW.process_id ;
        pl_log.ins_msg('FATAL', 'trg_ins_swms_log_arow', message, SQLCODE, SQLERRM, NULL, NULL, 'N');
        
END trg_ins_swms_log_arow;
/ 
