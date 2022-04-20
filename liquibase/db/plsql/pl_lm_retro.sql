rem *****************************************************
rem @(#) src/schema/plsql/pl_lm_retro.sql, swms, swms.9, 10.1.1 9/7/06 1.4

rem @(#) File : pl_lm_retro.sql
rem @(#) Usage: sqlplus USR/PWD pl_lm_retro.sql
rem Description: The two procedures in this package are 
rem              used in triggers trg_ins_batch_row
rem              and trg_upd_batch_row.
rem ---  Maintenance history  ---
rem 08-JUN-2001 prppxx Initial version
rem
rem *****************************************************
/* SPECIFICATION FOR THE PACKAGE */
CREATE OR REPLACE PACKAGE swms.pl_lm_retro AS
  g_upd_batch_no        arch_batch.batch_no%TYPE;
  g_upd_batch_date      arch_batch.batch_date%TYPE;
  g_retro_start_time    arch_batch.actl_start_time%TYPE;
  g_user_id             arch_batch.user_id%TYPE;
  g_jbcd_job_code       arch_batch.jbcd_job_code%TYPE;
  g_start_duration      NUMBER; --sched_type.start_dur%TYPE;
  g_count_retro	  	NUMBER := 0;

  PROCEDURE get_retro_flag (i_user_id	    IN arch_batch.user_id%TYPE,
                            o_retro_flag    OUT usr.lm_retro_on%TYPE);

  PROCEDURE get_retro_info (i_user_id	        IN arch_batch.user_id%TYPE,
                            i_jbcd_job_code	IN arch_batch.jbcd_job_code%TYPE,
                            o_retro_time	OUT arch_batch.actl_start_time%TYPE,
                            o_duration	        OUT NUMBER );
END pl_lm_retro;
/

/* PACKAGE BODY FOR PROCEDURES */
CREATE OR REPLACE PACKAGE BODY swms.pl_lm_retro AS
  PROCEDURE get_retro_flag (i_user_id       IN arch_batch.user_id%TYPE,
                            o_retro_flag    OUT usr.lm_retro_on%TYPE) is
  BEGIN
    SELECT nvl(lm_retro_on,'N')
    INTO o_retro_flag
    FROM usr
   WHERE (user_id = i_user_id
         OR user_id = 'OPS$' || i_user_id);
  EXCEPTION 
    when no_data_found then
       o_retro_flag := 'N';
  END get_retro_flag;

  PROCEDURE get_retro_info ( i_user_id        IN arch_batch.user_id%TYPE,
                             i_jbcd_job_code  IN arch_batch.jbcd_job_code%TYPE,       
                             o_retro_time     OUT arch_batch.actl_start_time%TYPE,    
                             o_duration       OUT NUMBER) is
  BEGIN
  DECLARE
     l_retro_flag	usr.lm_retro_on%TYPE;
     l_job_class        job_code.jbcl_job_class%TYPE;

     CURSOR get_class IS
        SELECT jbcl_job_class
          FROM job_code
         WHERE jbcd_job_code = i_jbcd_job_code;
          --
    CURSOR get_batch_sched IS
        SELECT to_date(to_char(sysdate,'MM/DD/YY ') ||
         to_char(st.start_time,'HH24:MI'),'MM/DD/YY HH24:MI'), 
                 st.start_dur
          FROM sched_type st, sched s, usr u
         WHERE s.sched_actv_flag = 'Y'
           AND s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp
           AND s.sched_jbcl_job_class = l_job_class
           AND st.sctp_sched_type = s.sched_type
           AND (u.user_id = i_user_id
               OR u.user_id = 'OPS$' || i_user_id);
    BEGIN
        OPEN get_class;
        FETCH get_class into l_job_class;
        IF get_class%FOUND THEN
          OPEN get_batch_sched;
          FETCH get_batch_sched into o_retro_time, o_duration;
          IF get_batch_sched%NOTFOUND THEN
            raise_application_error(-20001,'get_batch_sched is not found');
          END IF;
        ELSE
          raise_application_error(-20002,'get_class is not found');
        END IF;
    END;
  END get_retro_info;
end pl_lm_retro;
/
