--------------------------------------------------------------------
--   sccs_id=@(#) src/schema/triggers/trg_insupd_batch_brow.sql, swms, swms.9, 11.2 1/13/10 1.8
--
--   Trigger Name   : trg_insupd_batch_brow 
--   Created By     : acpakp 
--   Table Used     : BATCH 
--   Comments       : 
--   This trigger will fire on insert/update on BATCH TABLE.
--   This trigger will truncate the time from batch date before
--   insert or update of batch_date  
--
-- Modification History:
--   DN10728: prppxx: Modify to track retro batch
--   DN11347: prppxx: Update to the lastest code for Oracle 8.
--   08/24/06 prppxx: Added update user and update date.
--   DN12293: prplhj: Added the update for SOS_BATCH table during BATCH insert.
--   11/27/07 D#12316 prplhj Added picked_by update to SOS_BATCH table.
--   08/11/09 D#12514 prplhj Fixed batch reserved user for Future batch.
--   01/07/10 D#12552 prppxx Add upd of lxli_send_flag for ressigned batch.
--   11/29/10 CR19928 prplhj Seperated SOS_BATCH.start_time update to only
--			perform update when the BATCH.status is F.
--   06/09/15 spin4795 As part of the Symbotic project I changed the update of
--                     the SOS_BATCH STSTUS column so that it would not update
--                     a Pending (X) status to another value.
-- 08-Nov-2021 pkab6563 - Jira 3828: Indirect adjustment change.
--------------------------------------------------------------------
CREATE OR REPLACE TRIGGER swms.trg_insupd_batch_brow
       BEFORE INSERT OR UPDATE ON swms.batch 
       FOR EACH ROW 
DECLARE
   l_start_dur           NUMBER;
   l_batch_no            batch.batch_no%TYPE;
   l_istart_batch_no     batch.batch_no%TYPE;
   l_job_class           job_code.jbcl_job_class%type;
   l_lm_retro_on         usr.lm_retro_on%TYPE;
   l_actl_start_time     batch.actl_start_time%TYPE;
   l_actl_stop_time      batch.actl_stop_time%TYPE;
   l_cnt                 NUMBER;
   l_old_batch_date      VARCHAR2(14); 
   l_cmt                 batch.cmt%TYPE;

begin
/* DN10728 prppxx added */
IF INSERTING THEN
      :new.batch_date := trunc(:new.batch_date);
   IF :new.user_id IS NOT NULL and :new.jbcd_job_code in ('ISTART','ISTOP') THEN

      BEGIN
         IF :new.jbcd_job_code = 'ISTART' THEN
           pl_lm_retro.get_retro_flag(:new.user_id, l_lm_retro_on);
           IF l_lm_retro_on = 'Y' THEN
             pl_lm_retro.get_retro_info(:new.user_id, :new.jbcd_job_code,
                                        l_actl_start_time, l_start_dur);

             IF SYSDATE > (l_actl_start_time + nvl(l_start_dur,0)/1440) THEN
               pl_lm_retro.g_user_id := :new.user_id;
               :new.actl_start_time := l_actl_start_time;
               IF :new.status = 'C' THEN
                 :new.actl_stop_time := l_actl_start_time + nvl(l_start_dur,0)/1440;
                 :new.actl_time_spent := l_start_dur;
                 pl_lm_retro.g_count_retro := 1;
               ELSE
                 pl_lm_retro.g_count_retro := 0;
               END IF;
             END IF;
           END IF; /* lm_retro_on is Y */
         END IF;

      EXCEPTION WHEN NO_DATA_FOUND THEN
         null;
      END;
   END IF;
ELSIF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
      if :new.batch_date != :old.batch_date then
         :new.batch_date := trunc(:new.batch_date);
      end if;
      BEGIN
        pl_lm_retro.get_retro_flag(:new.user_id, l_lm_retro_on);
        IF l_lm_retro_on = 'Y' THEN
           IF pl_lm_retro.g_user_id = :new.user_id THEN
             IF pl_lm_retro.g_count_retro = 1 OR :new.jbcd_job_code = 'ISTART' THEN
                  pl_lm_retro.get_retro_info(:new.user_id, :new.jbcd_job_code,
                                             l_actl_start_time, l_start_dur);

                  IF :new.jbcd_job_code = 'ISTART' THEN
                     IF :new.status = 'C' THEN
                        :new.actl_stop_time := l_actl_start_time + nvl(l_start_dur,0)/1440;
                        :new.actl_time_spent := l_start_dur;
                        pl_lm_retro.g_count_retro := 1;
                     END IF;
                  ELSE
                     IF (:old.status != :new.status AND :new.status = 'A') THEN
                        :new.actl_start_time := l_actl_start_time + nvl(l_start_dur,0)/1440;
                        pl_lm_retro.g_count_retro := 0;
                     END IF;
                  END IF;
             ELSE
                  pl_lm_retro.g_count_retro := 0;
             END IF;
           END IF;
        END IF;
      EXCEPTION WHEN NO_DATA_FOUND THEN
         null;
     END;
     IF :new.batch_no LIKE 'S%' THEN
	BEGIN
		UPDATE sos_batch
		SET status = DECODE(status,'X','X',:new.status),
		    picked_by = DECODE(:new.status,
					'F', DECODE(reserved_by,
						NULL, NULL,
						picked_by),
                                         picked_by),
		    end_time = DECODE(:new.status, 'C', SYSDATE, NULL)
		WHERE batch_no = SUBSTR(:new.batch_no, 2);
		IF :new.status = 'F' THEN
			-- If status is not F, keep whatever the start_time
			-- was. This prevents the system updates the start_time
			-- time portion to 00:00:00 due to default date
			-- format setting.
			UPDATE sos_batch
			SET start_time = NULL
			WHERE batch_no = SUBSTR(:new.batch_no, 2);
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			NULL;
	END;

        IF :new.status = 'F' AND :old.status = 'A' AND :old.lxli_send_flag = '1' THEN
           :new.lxli_send_flag := NULL;
        END IF;
        IF :new.status = 'A' AND :old.status != 'A' AND :OLD.lms_sent_flag = 'SUCCESS' THEN
            :new.lms_sent_flag := null;
        END IF;
        IF :new.status = 'C' AND :old.status != 'C' AND :OLD.lms_sent_flag = 'SUCCESS' THEN
            :new.lms_sent_flag := null;
        END IF;
     END IF;

     -- indirect adjustment change
     IF :old.jbcd_job_code LIKE 'I%' AND :old.status = 'C' AND :old.lms_sent_flag = 'SUCCESS'
            AND :old.ref_no LIKE 'INSERT_INDIRECT%' AND :old.ins_indirect_dt IS NOT NULL 
            AND :old.ins_indirect_jobcd IS NOT NULL THEN
         l_old_batch_date := TO_CHAR(:old.batch_date, 'MMDDYYYYHH24MISS');
         l_cmt := 'Old batch date: ' || l_old_batch_date;
         INSERT INTO trans(trans_id, trans_type, trans_date, user_id, rec_id, lot_id, 
                           labor_batch_no, mfg_date, exp_date, cmt)
                    VALUES(trans_id_seq.NEXTVAL, 'IAC', sysdate, user, :old.jbcd_job_code, :old.user_id, 
                           :old.batch_no, :old.actl_start_time, :old.actl_stop_time, l_cmt); 
         :new.lms_sent_flag := NULL;
     END IF; -- indirect adjustment change

END IF;  -- if updating
end;
/

