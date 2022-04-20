/*--------------------------------------------------------------------
-- Trigger trg_del_batch_brow
--   
-- Modification history:
--
-- Date         Author       Comment
-- -----------  ----------   -----------------------------------------
-- 08-Nov-2021  pkab6563     Tigger created - Jira 3828: Indirect 
--                           adjustment deletion.
--
--------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER swms.trg_del_batch_brow
       BEFORE DELETE ON swms.batch 
       FOR EACH ROW 
DECLARE
   l_old_batch_date      VARCHAR2(14); 
   l_cmt                 batch.cmt%TYPE;
   l_dummy               VARCHAR2(1);

BEGIN
    IF :old.jbcd_job_code LIKE 'I%' AND :old.status = 'C' AND :old.lms_sent_flag = 'SUCCESS'
            AND :old.ref_no LIKE 'INSERT_INDIRECT%' AND :old.ins_indirect_dt IS NOT NULL 
            AND :old.ins_indirect_jobcd IS NOT NULL  THEN
        BEGIN
            -- is batch transfer to arch_batch running?
            -- if so, we don't want to log an IAD transaction. 
            SELECT 'X' 
            INTO   l_dummy
            FROM   swms.arch_batch
            WHERE  batch_no = :old.batch_no
              AND  batch_date = :old.batch_date;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_old_batch_date := TO_CHAR(:old.batch_date, 'MMDDYYYYHH24MISS');
                l_cmt := 'Old batch date: ' || l_old_batch_date;
                INSERT INTO trans(trans_id, trans_type, trans_date, user_id, rec_id, lot_id, 
                                  labor_batch_no, mfg_date, exp_date, cmt)
                           VALUES(trans_id_seq.NEXTVAL, 'IAD', sysdate, user, :old.jbcd_job_code, :old.user_id, 
                                  :old.batch_no, :old.actl_start_time, :old.actl_stop_time, l_cmt); 

            WHEN OTHERS THEN
                pl_log.ins_msg('WARN', 'trg_del_batch_brow', 'Trigger FAILED', SQLCODE, SUBSTR(SQLERRM, 1, 500));

        END;
    END IF; -- indirect adjustment deletion
END;
/
