/*--------------------------------------------------------------------
-- Trigger trg_upddel_arch_batch_brow
--
-- Modification history:
--
-- Date         Author       Comment
-- -----------  ----------   -----------------------------------------
-- 08-Nov-2021  pkab6563     Tigger created - Jira 3828: Indirect
--                           adjustment change and deletion.
--
--------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER swms.trg_upddel_arch_batch_brow
       BEFORE UPDATE OR DELETE ON swms.arch_batch 
       FOR EACH ROW 
DECLARE
   l_old_batch_date      VARCHAR2(14); 
   l_cmt                 batch.cmt%TYPE;

BEGIN
    IF UPDATING THEN
        IF :old.jbcd_job_code LIKE 'I%' AND :old.status = 'C' AND :old.lms_sent_flag = 'SUCCESS'
            AND :old.ref_no LIKE 'INSERT_INDIRECT%' AND :old.ins_indirect_dt IS NOT NULL 
            AND :old.ins_indirect_jobcd IS NOT NULL AND (sysdate - :new.actl_stop_time < 8)  THEN
         l_old_batch_date := TO_CHAR(:old.batch_date, 'MMDDYYYYHH24MISS');
         l_cmt := 'Old batch date: ' || l_old_batch_date;
         INSERT INTO trans(trans_id, trans_type, trans_date, user_id, rec_id, lot_id, 
                           labor_batch_no, mfg_date, exp_date, cmt)
                    VALUES(trans_id_seq.NEXTVAL, 'IAC', sysdate, user, :old.jbcd_job_code, :old.user_id, 
                           :old.batch_no, :old.actl_start_time, :old.actl_stop_time, l_cmt); 
         :new.lms_sent_flag := NULL;
        END IF; -- indirect adjustment change
    ELSIF DELETING THEN
        IF :old.jbcd_job_code LIKE 'I%' AND :old.status = 'C' AND :old.lms_sent_flag = 'SUCCESS'
            AND :old.ref_no LIKE 'INSERT_INDIRECT%' AND :old.ins_indirect_dt IS NOT NULL 
            AND :old.ins_indirect_jobcd IS NOT NULL AND (sysdate - :old.actl_stop_time < 8)  THEN
         l_old_batch_date := TO_CHAR(:old.batch_date, 'MMDDYYYYHH24MISS');
         l_cmt := 'Old batch date: ' || l_old_batch_date;
         INSERT INTO trans(trans_id, trans_type, trans_date, user_id, rec_id, lot_id, 
                           labor_batch_no, mfg_date, exp_date, cmt)
                    VALUES(trans_id_seq.NEXTVAL, 'IAD', sysdate, user, :old.jbcd_job_code, :old.user_id, 
                           :old.batch_no, :old.actl_start_time, :old.actl_stop_time, l_cmt); 
        END IF; -- indirect adjustment deletion
    END IF;  -- if updating/deleting

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN', 'trg_upddel_arch_batch_brow', 'Trigger FAILED', SQLCODE, SUBSTR(SQLERRM, 1, 500));
END;
/
