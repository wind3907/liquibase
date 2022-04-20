/*
**********************************************************************************
** Date:       31-AUG-2021
** File:       Jira3523_DML_add_lr_sched_job_class.sql
**
**
**    Modification History:
**    Date         Designer  Comments
**    -----------  --------  -----------------------------------------------------
**    31-AUG-2021  mcha1213  Initial
**
**********************************************************************************
*/

SET ECHO OFF
SET SCAN OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  K_This_Script             CONSTANT  VARCHAR2(50 CHAR) := 'Jira3523_DML_add_lr_sched_job_class.sql';
  e_stop_now exception;

BEGIN

  DBMS_OUTPUT.PUT_LINE('Starting script Jira3523_DML_add_lr_sched_job_class.sql');  

  INSERT INTO sched (sched_jbcl_job_class, 
                     sched_lgrp_lbr_grp, 
                     sched_type, 
                     sched_actv_flag)
  select 'CM' sched_jbcl_job_class,
         s.sched_lgrp_lbr_grp, 
         s.sched_type, 
         s.sched_actv_flag
  from (select distinct
               sched_lgrp_lbr_grp, 
               sched_type, 
               sched_actv_flag 
          from sched) s
  where s.sched_actv_flag = 'Y'
  and not exists (select 'x'
                  from sched s0
                  where s0.sched_lgrp_lbr_grp = s.sched_lgrp_lbr_grp 
                    and s0.sched_type = s.sched_type 
                    and s0.sched_actv_flag = s.sched_actv_flag
                    and s0.sched_jbcl_job_class = 'CM');


  IF sql%found THEN 
      DBMS_OUTPUT.PUT_LINE('Added schedules for CM job class.');
  END IF;
  
  INSERT INTO sched (sched_jbcl_job_class, 
                     sched_lgrp_lbr_grp, 
                     sched_type, 
                     sched_actv_flag)
  select 'DM' sched_jbcl_job_class,
         s.sched_lgrp_lbr_grp, 
         s.sched_type, 
         s.sched_actv_flag
  from (select distinct
               sched_lgrp_lbr_grp, 
               sched_type, 
               sched_actv_flag 
          from sched) s
  where s.sched_actv_flag = 'Y'
  and not exists (select 'x'
                  from sched s0
                  where s0.sched_lgrp_lbr_grp = s.sched_lgrp_lbr_grp 
                    and s0.sched_type = s.sched_type 
                    and s0.sched_actv_flag = s.sched_actv_flag
                    and s0.sched_jbcl_job_class = 'DM');


  IF sql%found THEN 
      DBMS_OUTPUT.PUT_LINE('Added schedules for DM job class.');
  END IF;

  INSERT INTO sched (sched_jbcl_job_class, 
                     sched_lgrp_lbr_grp, 
                     sched_type, 
                     sched_actv_flag)
  select 'FM' sched_jbcl_job_class,
         s.sched_lgrp_lbr_grp, 
         s.sched_type, 
         s.sched_actv_flag
  from (select distinct
               sched_lgrp_lbr_grp, 
               sched_type, 
               sched_actv_flag 
          from sched) s
  where s.sched_actv_flag = 'Y'
  and not exists (select 'x'
                  from sched s0
                  where s0.sched_lgrp_lbr_grp = s.sched_lgrp_lbr_grp 
                    and s0.sched_type = s.sched_type 
                    and s0.sched_actv_flag = s.sched_actv_flag
                    and s0.sched_jbcl_job_class = 'FM');


  IF sql%found THEN 
      DBMS_OUTPUT.PUT_LINE('Added schedules for FM job class.');
  END IF;

  
  
  DBMS_OUTPUT.PUT_LINE('Ending script Jira3523_DML_add_lr_sched_job_class.sql');  

  EXCEPTION
    WHEN OTHERS THEN
      Dbms_Output.Put_Line( '- Failed on inserting LR job class to table SCHED, ' || SQLERRM );
      RAISE;
END;
/

