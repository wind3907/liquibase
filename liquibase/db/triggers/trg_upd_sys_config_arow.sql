/**************************************************************
--
-- This trigger inserts a row into sys_config_details when a
-- row is changed in sys_config.
--
**************************************************************/
CREATE OR REPLACE TRIGGER swms.trg_upd_sys_config_arow
   AFTER UPDATE ON swms.sys_config 
   FOR EACH ROW

DECLARE
   l_message VARCHAR2(500);

BEGIN
   INSERT INTO swms.sys_config_details(scd_seq_no, 
                                       scd_upd_date, 
                                       scd_upd_name,
                                       scd_prev_val)
      VALUES(:OLD.seq_no, 
             sysdate, 
             replace(user, 'OPS$'),
             :OLD.config_flag_val);

EXCEPTION
   WHEN OTHERS THEN
      l_message := 'Insert into sys_config_details FAILED. ' ||
                   'Timestamp = [' || TO_CHAR(sysdate, 'YYYY-MM-DD HH24:MI:SS') || '] ' || 
                   'User = [' || user || '] ' ||
                   'Sys_config.seq_no = [' || :OLD.seq_no || '] ' ||
                   'Old syspar value = [' || :OLD.config_flag_val || '] '; 

      pl_log.ins_msg('FATAL', 'trg_upd_sys_config_arow', l_message, SQLCODE, SQLERRM);

END trg_upd_sys_config_arow;
/
