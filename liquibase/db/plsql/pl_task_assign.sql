rem *****************************************************
rem @(#) src/schema/plsql/pl_task_assign.sql, swms, swms.9, 10.1.1 9/7/06 1.8

rem @(#) File : pl_task_assign.sql
rem @(#) Usage: sqlplus USR/PWD pl_task_assign.sql

rem ---  Maintenance history  ---
rem 18-FEB-2002 acpakp Initial version
rem 15-JUL-2002 acpakp Changed adjust_istop_time to take care of 'NO_DATA'
rem                    in IWASH_BATCH_NO to take care of null value 
rem                    returning for i_wash_batch_no in Oracle 8.
rem 05/11/04    prplhj D#11601/11602 Added PO batch checking to
rem                    chk_authorised(). Added float_no to
rem		       insert_to_float_hist().
rem 07/25/05    prpswp Removed the conn and create synonym and grant stmts 
rem		       from the script.
rem 07/25/05    prpakp Changed not to insert the data to float_hist if the
rem		       previous batch is a short batch from SOS which has
rem		       the batch start with SS.
rem 11/2/05     prpakp Corrected the variable declaration for batch number
rem                    from a number to a character in INS_FLOAT_HIST procedure.
rem 03/31/06    prpbcb Treat returns T batch as a forklift batch.
rem                    Modified procedure procedure check_forklift_batch().
rem                    Ticket: 129886
rem                    DN 12079
rem 06/14/06    prppxx Added wilcard '%' for batch_no in INSERT_TO_FLOAT_HIST.
rem		       D# 12102. Ticket 164066.


CREATE OR REPLACE PACKAGE swms.pl_task_assign IS
/*==========================================================================================
There are five packages that are used in task assign.
They are
1.pl_task_assign
2.pl_task_merge
3.pl_task_retro
4.pl_task_indirect
5.pl_task_regular

All the common procedures are in pl_task_assign.
All procedures related to merge is in pl_task_merge.
All procedures related to retro are in pl_task_retro.
All procedures related to indirect are in pl_task_indirect.
All procedures related to regular batches are in pl_task_regular.

/*==========================================================================================

The procedures in this package are
1. chk_authorised - This is used to check the batch number entered by the user is valid
                  - and whether the user has authorisation to enter the job code.
                  - In case of indirect job code, thi will check the corp code in job code
                  - table to identify whether the job code is authorised. If not check for
                  - the existance of the batch in the batch table. If the batch exists and
                  - if the status is not A,M,C,X then batch is a valid batch.
                  - This also returns the target time and goal time of the batch since these data
                  - will be lost if the batches gets merged. 
2. add_prefix_S   - If the first character of the batch entered by the user is a number (0-9)
                  - then this procedure will prefix the batch with 'S'.

3. add_indirect_entry - This will insert the indirect batch (other than ISTART and ISTOP)
                  - into batch table if the indirect job code entered is authorised.
4. check_for_istart - This procedure will check the existance of ISTART for the user.
                  - If the user enters ISTART, then this will check whether for the users 
                  - Schedule, there is duration for the start process. If there is duration, 
                  - users are not allowed to enter ISTART.
5. ins_istart     - This procedure will insert the ISTART batch for the user. If there is no 
                  - duration for start in the schedule and the user enters ISTART, then this 
                  - will insert the batch for the user with status as A. If the user enters
                  - any other batch and he doesn't have an ISTART, this will create an ISTART
                  - for the user.
6. get_prev_batch - This procedure will get all the details about the previous batch of the user.
7. duration       - This will get the duration of the start and stop process of the user from
                  - his schedule.
8.ins_indirect   - This will create the indirect batch for the user for the given job_code.
9.upd_current_batch - this will update the current batch with user_id,user_supervsr_id ,status,
                  - actl_start_time,actl_stop_time ,kvi_no_po ,kvi_from_loc.
10.process_ins_float_hist - This procedure will get the batch number of all the child batches if exits
                  - for the user and calls insert_to_float_hist procedure to insert the details of each 
                  - batch.
11.insert_to_float_hist - This will insert the details of the batch to float_hist table.
12. validate_userid - This procedure is called from process_batch to get the supervisor id and labor 
                  - group of the user.
13.calc_parent_total - Calculate the total count,total pallet,total piece and update the previous
                  - batch with the details.
14.upd_pre_merge  - Updates the user_id, supervisor id, start time,stop time, status
                  - for all child batches of the parent batch the user is signing on to.
                  - This is called after upd_current_batch in process_batch.
15.create_istart  - This procedure will create an ISTART for the user as the first batch 
                  - if there is one missing for him and there is a batch exists.
16.rf_feedback    - This will calculate the performace percentage of the previous job and 
                  - daily avg performace percentage to display the feedback in RF.
17. check_forklift_batch -This procedure will check whether the previous batch existing
                  - for the user is a forklift batch. If the previous batch is a forklift batch
                  - then this will return the message that the previous batch is forklift.
                  - this will allow the form to accept forklift terminal location fromthe user.
18.adjust_istop_time - This will be called after the forklift sign off process is complete to update
                  - the timings. Since forklift is signed off after the batch is created that will have
                  - a time greter than the start of time of the current batch. This is adjusted to avoid
                  - overlapping.
19.validate_point_a - This procedure will check whether the forklift terminal point entered
                  - by the user is valid or not.
20.change_status    - This is used to update the status of the current batch the user is 
                    - signing on to. This is called before calling the pro*c program to 
                    - sign of forklift batch.
====================================================================================*/
procedure chk_authorised (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          o_target_time out number,
                          o_goal_time out number,
                          o_auth_job out varchar,
                          o_valid_batch out varchar);
procedure add_prefix_S (io_batch_no in out arch_batch.batch_no%TYPE);

procedure add_indirect_entry (io_batch_no in out arch_batch.batch_no%TYPE,
                              i_ref_no in arch_batch.ref_no%TYPE,
                              o_indir_cd_success out boolean);

Procedure check_for_istart(i_user_id in arch_batch.user_id%TYPE,
                           o_exist out char);

procedure create_istart (i_user_id arch_batch.user_id%TYPE,
                         i_lbr_grp usr.lgrp_lbr_grp%TYPE,
                         i_user_supervsr_id arch_batch.user_supervsr_id%TYPE);

procedure ins_istart (i_start_entry in char,
                      i_user_id in arch_batch.user_id%TYPE,
                      i_user_supervsr_id in  arch_batch.user_supervsr_id%TYPE,
                      i_lbr_grp in usr.LGRP_LBR_GRP%TYPE,
                      i_ref_no in arch_batch.ref_no%TYPE,
                      o_istart_created out char,
                      o_actl_stop_time out arch_batch.actl_stop_time%TYPE,
                      o_batch_no out arch_batch.batch_no%TYPE);

procedure get_prev_batch(i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          i_lfun_lbr_func in  job_code.lfun_lbr_func%TYPE,
                          o_prev_batch_no out arch_batch.batch_no%TYPE,
                          o_prev_batch_date out arch_batch.batch_date%TYPE,
                          o_prev_start_time out arch_batch.actl_start_time%TYPE,
                          o_do_merge out char,
                          o_prev_exist out char,
                          o_prev_forklift out char,
                          o_prev_status out arch_batch.status%TYPE);

procedure duration(i_job_code in job_code.jbcd_job_code%TYPE,
                    i_user_id in arch_batch.user_id%TYPE,
                    i_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                    o_out_dur out number);

procedure ins_indirect (i_jbcd_job_code in job_code.jbcd_job_code%TYPE,
                           i_status in arch_batch.status%TYPE,
                           i_user_id in arch_batch.user_id%TYPE,
                           i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                           i_actl_start_time in arch_batch.actl_start_time%TYPE,
                           i_actl_stop_time in arch_batch.actl_stop_time%TYPE,
                           i_actl_time_spent in arch_batch.actl_time_spent%TYPE,
                           i_forklift_point in point_distance.point_a%TYPE,
                           i_ref_no in arch_batch.ref_no%TYPE,
                           o_batch_no out arch_batch.batch_no%TYPE);

procedure upd_curr_batch (i_status in char,
                             i_actl_start_time in arch_batch.actl_start_time%TYPE,
                             i_actl_stop_time in arch_batch.actl_stop_time%TYPE,
                             i_batch_no in arch_batch.batch_no%TYPE,
                             i_user_id in arch_batch.user_id%TYPE,
                             i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                             i_forklift_point in point_distance.point_a%TYPE,
                             i_ref_no in arch_batch.ref_no%TYPE);

procedure process_ins_float_hist(i_prev_batch in arch_batch.batch_no%TYPE,
                                 i_user_id in arch_batch.user_id%TYPE);

procedure insert_to_float_hist(i_get_batch_no in arch_batch.batch_no%TYPE,
                               i_user_id in arch_batch.user_id%TYPE);

procedure validate_userid(i_user_id in usr.user_id%TYPE,
                          o_supervsr_id out usr.suprvsr_user_id%TYPE,
                          o_lbr_grp out usr.lgrp_lbr_grp%TYPE);

procedure calc_parent_total (i_parent_batch in arch_batch.parent_batch_no%TYPE);

procedure upd_pre_merge ( i_user_id in arch_batch.user_id%TYPE,
                          i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                          i_parent_batch_no in arch_batch.parent_batch_no%TYPE,
                          i_start_stop_time in arch_batch.actl_start_time%TYPE);

procedure rf_feedback(i_batch_no in arch_batch.batch_no%TYPE,
                      i_user_id in arch_batch.user_id%TYPE,
                      o_feedback_mask out number,
                      o_break_lunch out number,
                      o_prev_perf out number,
                      o_dir_time out  arch_batch.goal_time%TYPE,
                      o_targ_goal_time out arch_batch.goal_time%TYPE,
                      o_daily_perf out number );

procedure check_forklift_batch( i_user_id in usr.user_id%TYPE,
                              o_fork_batch_no out arch_batch.batch_no%TYPE,
                              o_forklift_flag  out varchar,
                              o_parent_batch_no out arch_batch.parent_batch_no%TYPE);

procedure adjust_istop_time(i_istop_batch_no    IN arch_batch.batch_no%TYPE,
                            i_iwash_batch_no    IN arch_batch.batch_no%TYPE,
                            i_forklift_batch_no IN arch_batch.batch_no%TYPE);

procedure validate_point_a(i_point_a point_distance.point_a%TYPE,
                           o_valid_point out varchar);

procedure change_status(i_batch_no in arch_batch.batch_no%TYPE,
                        i_status in arch_batch.status%TYPE,
                        o_status out arch_batch.status%TYPE);
END pl_task_assign;
/

/*=========================================================================================*/
/*=========================================================================================*/
CREATE OR REPLACE PACKAGE BODY swms.pl_task_assign IS
/* ========================================================================== */
procedure chk_authorised (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          o_target_time out number,
                          o_goal_time out number,
                          o_auth_job  out varchar,
                          o_valid_batch  out varchar) is
/*---------------------------------------------------------------------------
Return values : 
   o_auth_job : Y - authorised
                N - Not authorised
   o_valid_batch : Y - Valid Batch
                   N - Invalid Batch. Does not exist.
                   C - Batch Exists but laready complete
                   A - Batch exists but already worked on
                   X - Batch Exists but not ready to work on.
                   M - Batch exists but it is merged.
                   F - Forklift batch. Cannot be signed on here.
                   I - If ISTART check for ISTART and if exists return I
                   D - If Duration exist in ISTART
----------------------------------------------------------------------------*/
   l_auth_job char;
   l_job_code job_code.jbcd_job_code%type;
   l_batch_no arch_batch.batch_no%TYPE;
   l_procedure_name   varchar2(40);
   l_status char;
   l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
   l_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
   l_dur number(3);

   cursor c_job_code is
      select nvl(corp_code,'N'),jbcd_job_code
      from job_code
      where jbcd_job_code = i_batch_no
      and   lfun_lbr_func = 'IN'
      and   jbcd_job_code not in ('ISTART','ISTOP');

   cursor c_get_batch is
      select batch_no,status,lfun_lbr_func,target_time,goal_time
      from batch_monitor_view
      where batch_no = l_batch_no;
begin

  o_target_time := 0;
  o_goal_time := 0;
  if ((i_batch_no = 'ISTART') or (i_batch_no = 'ISTOP')) then
      o_auth_job := 'Y';
      if (i_batch_no = 'ISTART') then
          begin
            select 'I'
            into o_valid_batch
            from batch
            where user_id = i_user_id
            and jbcd_job_code = 'ISTART';
            exception
              when no_data_found then
                begin
                 select lgrp_lbr_grp 
                 into l_lgrp_lbr_grp
                 from usr
                 where replace(user_id,'OPS$','') = i_user_id;
                 exception when others then
                      l_lgrp_lbr_grp := null;
                end; 
                 duration('ISTART',i_user_id,l_lgrp_lbr_grp,l_dur);
                 if l_dur > 0 then
                     o_valid_batch := 'D';
                 else
                     o_valid_batch := 'Y';
                 end if;
              when others then
                   o_valid_batch := 'N';
          end;
      else 
        o_valid_batch := 'Y';
      end if;
  else
    open c_job_code;
    fetch c_job_code into l_auth_job,l_job_code;
    if c_job_code%FOUND then
       o_auth_job := l_auth_job;
       o_valid_batch := 'Y';
    else
      o_auth_job := 'Y';
      l_batch_no := i_batch_no;
      add_prefix_S(l_batch_no);
      open c_get_batch;
      fetch c_get_batch into l_batch_no,
                             l_status,l_lfun_lbr_func,
                             o_target_time,o_goal_time;
      -- D#11601 Added PO batch no checking
      if c_get_batch%NOTFOUND then
         close c_get_batch;
         l_batch_no := 'PO' || i_batch_no;
         open c_get_batch;
         fetch c_get_batch into l_batch_no,
                                l_status,l_lfun_lbr_func,
                                o_target_time,o_goal_time;
         if c_get_batch%NOTFOUND then
            l_status := NULL;
            o_valid_batch := 'N';
         end if;
      end if;
      if l_status = 'C' THEN
           o_valid_batch := 'C';
      elsif l_status = 'A' THEN
           o_valid_batch := 'A';
      elsif l_status = 'X' THEN
           o_valid_batch := 'X';
      elsif l_status = 'M'  THEN
           o_valid_batch := 'M';
      else
          if l_lfun_lbr_func = 'FL' then
             o_valid_batch := 'F';
          else
             o_valid_batch := 'Y';
          end if;
      end if;
      close c_get_batch;
    end if;
    close c_job_code;
 end if;
end;

/* ========================================================================== */
 PROCEDURE add_prefix_S (io_batch_no in out arch_batch.batch_no%TYPE) is
/*---------------------------------------------------------------------------
Return values:
      io_batch_no : return batch no prefixed with S if the batch number starts 
                    a number.(0-9)
-----------------------------------------------------------------------------*/

  l_first_char char(1);
  begin
   begin
    select 'X'
    into l_first_char
    from dual
    where  ascii(substr(io_batch_no,1,1)) between 48 and 57;
       io_batch_no := 'S'||io_batch_no;
    exception
       when no_data_found then
            null;
       when others then
            null;
   end;

  end add_prefix_S;

/* ========================================================================== */
procedure add_indirect_entry (io_batch_no in out arch_batch.batch_no%TYPE,
                              i_ref_no in arch_batch.ref_no%TYPE,
                              o_indir_cd_success out boolean) is
/*----------------------------------------------------------------------------
Return values:
          io_batch_no - If authorised job code, the batch no created for the 
                        indirect job code.
          o_indirect_cd_success - TRUE  - if insert successfully completed
                                - FLASE - if insert fails
------------------------------------------------------------------------------*/
   l_authorize_indir  job_code.corp_code%TYPE;
   l_job_code job_code.jbcd_job_code%type;
   l_procedure_name   varchar2(40);
  
   cursor c_job_code is
      select nvl(corp_code,'N'),jbcd_job_code
      from job_code
      where jbcd_job_code = io_batch_no
      and   lfun_lbr_func = 'IN'
      and   jbcd_job_code not in ('ISTART','ISTOP');
begin
  pl_log.g_application_func := 'LABOR';
  pl_log.g_program_name := 'pl_task_assign.sql';
  l_procedure_name := 'chk_indirect_entry';
  open c_job_code;
  fetch c_job_code into l_authorize_indir,l_job_code;

  if c_job_code%FOUND then

     if l_authorize_indir = 'N' then
         o_indir_cd_success := FALSE;
     else
       begin
         select 'I' || to_char(seq1.nextval)
         into io_batch_no
         from dual;
         --
         insert into batch
         (batch_no,jbcd_job_code,status,batch_date,actl_start_time,total_count,
          total_pallet,total_piece,ref_no,mod_usr)
          VALUES
          (io_batch_no,l_job_code,'F',trunc(sysdate),sysdate,1,0,0,i_ref_no,
           decode(substr(i_ref_no,1,2),'RF',substr(i_ref_no,4),substr(i_ref_no,5)));
          if sql%notfound then
            o_indir_cd_success := FALSE;
            raise_application_error(-20100,'Insertion into batch failed.Job Code='||l_job_code||' Ref No='||i_ref_no);
          else
            o_indir_cd_success := TRUE;
            pl_log.ins_msg('I',l_procedure_name,
             'Batch # ' || io_batch_no || ' has been ' ||
              'successfully created.',null,null);
          end if;        
        end;
     end if;
  else
     o_indir_cd_success := TRUE;
  end if;
end;

/* ========================================================================== */
Procedure check_for_istart(i_user_id in arch_batch.user_id%TYPE,o_exist out char) IS
/*-----------------------------------------------------------------------------
Return Values:
        o_exist = N ->no istart exist
                = Y ->istart already exist
                = E ->Error checking
-------------------------------------------------------------------------------*/
     l_X   CHAR(1);
BEGIN
  begin
      SELECT 'X' INTO l_X
      FROM BATCH
      WHERE batch_date between (sysdate - 1) and sysdate
      AND   user_id = i_user_id
      AND jbcd_job_code = 'ISTART';
      o_exist := 'Y';

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
      o_exist := 'N';
     WHEN TOO_MANY_ROWS THEN
       o_exist := 'E';
       raise_application_error(-20100,'More than one ISTART exist now.  Correct the situation.');
     when others then
       o_exist := 'E';
       raise_application_error(-20100,'Error in selection of ISTART. Correct the situation.');
  end;
END;
/*============================================================================*/
procedure create_istart (i_user_id arch_batch.user_id%TYPE,
                         i_lbr_grp usr.lgrp_lbr_grp%TYPE,
                         i_user_supervsr_id arch_batch.user_supervsr_id%TYPE) is
  l_date   arch_batch.actl_start_time%TYPE;
  l_start_time arch_batch.actl_start_time%TYPE;
  l_dur number := 0;

  cursor c_re_ck_istart is
    select actl_start_time
    from batch
    where user_id = i_user_id
    and   jbcd_job_code = 'ISTART';

  cursor c_get_min_time is
    select min(actl_start_time)
    from batch
    where user_id = i_user_id
    and status in ('C','A');
begin
  open c_re_ck_istart;
  fetch c_re_ck_istart into l_date;
  if c_re_ck_istart%notfound then
      open c_get_min_time;
      fetch c_get_min_time into l_start_time;
      if c_get_min_time%found then
          duration('ISTART',i_user_id,i_lbr_grp,l_dur);
          insert into batch
               (BATCH_NO, BATCH_DATE,JBCD_JOB_CODE, STATUS, USER_ID,
                USER_SUPERVSR_ID,ACTL_START_TIME, ACTL_STOP_TIME,
                ACTL_TIME_SPENT,NO_LUNCHES,
                NO_BREAKS,TOTAL_COUNT,TOTAL_PIECE,TOTAL_PALLET)
          Select 'I'||TO_CHAR(SEQ1.NEXTVAL), trunc(sysdate),
               'ISTART','C',i_user_id,i_user_supervsr_id,
                l_start_time - (nvl(l_dur,0)/1440),
                l_start_time,nvl(l_dur,0),0, 0,1,0,0
          from sys.dual;
          if sql%notfound then
            raise_application_error(-20100,'Creation of ISTART failed in create_istart');
          end if;
      end if;
  end if;
end;
/* ========================================================================== */
procedure ins_istart (i_start_entry in char,
                      i_user_id in arch_batch.user_id%TYPE,
                      i_user_supervsr_id in  arch_batch.user_supervsr_id%TYPE,
                      i_lbr_grp in usr.LGRP_LBR_GRP%TYPE,
                      i_ref_no in arch_batch.ref_no%TYPE,
                      o_istart_created out char,
                      o_actl_stop_time out arch_batch.actl_stop_time%TYPE,
                      o_batch_no out arch_batch.batch_no%TYPE) is
/*----------------------------------------------------------------------------
Return Values :
     o_istart_created = D -> Duration exist. Cannot create.
                      = E -> Error creating
------------------------------------------------------------------------------*/
/* This procedure is for user that does not have any record */
/* in BATCH table. Need to create a new batch of ISTART and JOB CODE */
/* i_start_entry tell the system that the user enter the */
/* ISTART values therefore leaving this batch active      */

  l_actl_start_time arch_batch.actl_start_time%TYPE;
  l_dur number := 0;
  l_batch_no arch_batch.batch_no%TYPE;
begin
 
   duration('ISTART', i_user_id, i_lbr_grp,l_dur);
   l_actl_start_time := sysdate;
   o_actl_stop_time := l_actl_start_time;
   if i_start_entry = 'Y' and nvl(l_dur,0) > 0 then
      o_istart_created := 'D';
      pl_log.ins_msg('F','ins_istart',
      'ISTART entry is not allow because there is a duration.',null,null);
   else
     /* the reason I broke into 2 insert instead of using */
     /* the decode function is b/c there is a bug with the decode */
     /* for the date return */
     begin
        select 'I'||to_char(seq1.nextval) 
        into l_batch_no
        from dual;
            o_batch_no := l_batch_no;           
        exception
           when no_data_found then
               o_istart_created := 'N';
           when others then
               o_istart_created := 'E';
     end;

     if i_start_entry = 'Y' then
       INSERT INTO BATCH
                  (BATCH_NO, BATCH_DATE,
                   JBCD_JOB_CODE, STATUS, USER_ID,
                   USER_SUPERVSR_ID,
                   ACTL_START_TIME, ACTL_STOP_TIME, ACTL_TIME_SPENT,
                   NO_LUNCHES,
                   NO_BREAKS,TOTAL_COUNT,TOTAL_PIECE,TOTAL_PALLET,ref_no)
       Select l_batch_no, trunc(sysdate),
                'ISTART', 'A', i_user_id,
                i_user_supervsr_id,
                l_actl_start_time,
                null,null,
                0, 0, 1, 0, 0,i_ref_no
        from sys.dual;
        if sql%notfound then
          o_istart_created := 'E';
          raise_application_error(-20100,'Unable to insert ISTART batch in ins_istart');
        end if;
      else
       INSERT INTO BATCH (BATCH_NO,
                   BATCH_DATE,
                   JBCD_JOB_CODE, STATUS, USER_ID,
                   USER_SUPERVSR_ID,
                   ACTL_START_TIME,
                   ACTL_STOP_TIME,
                   ACTL_TIME_SPENT,
                   NO_LUNCHES,
                   NO_BREAKS,
                   TOTAL_COUNT,
                   TOTAL_PIECE,
                   TOTAL_PALLET,ref_no)
       Select l_batch_no,
                trunc(sysdate),
                'ISTART', 'C',
                i_user_id, i_user_supervsr_id,
                l_actl_start_time - (l_dur/1440),
                l_actl_start_time, l_dur, 0, 0,
                1, 0, 0,i_ref_no
        from sys.dual;
        if sql%notfound then
          o_istart_created := 'E';
          raise_application_error(-20100,'Unable to insert ISTART batch in ins_istart');
        end if;
      end if;
    end if;
end ins_istart;
/* ========================================================================== */
procedure get_prev_batch (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          i_lfun_lbr_func in job_code.lfun_lbr_func%TYPE,
                          o_prev_batch_no out arch_batch.batch_no%TYPE,
                          o_prev_batch_date out arch_batch.batch_date%TYPE,
                          o_prev_start_time out arch_batch.actl_start_time%TYPE,
                          o_do_merge out char,
                          o_prev_exist out char,
                          o_prev_forklift out char,
                          o_prev_status out  arch_batch.status%TYPE) is
/*----------------------------------------------------------------------------
Return values:
       o_prev_batch_no - Previous batch_no of the user
       o_prev_batch_date - Batch dtae of the previous batch of the user.
       o_prev_start_time - Start time of the previous batch.
       o_do_merge - Y - If the current batch needs to be merged with the previous batch.
                  - N - If not to be merged.
       o_prev_exist - Y - If previous batch exist for the user
                    - N - If no previous batch exists.
       o_prev_forklift - Y - If the previous batch of the user is a forklift batch 
                             and have a status as active.
                       - N - If the previous batch is not a forklift batch or a 
                             forklift batch with status as C.
       o_prev_status - Status of the previous batch if exists.
------------------------------------------------------------------------------*/
    l_lfun_lbr_func  job_code.lfun_lbr_func%TYPE;
    l_job_code job_code.jbcd_job_code%TYPE;
    l_prev_batch_no arch_batch.batch_no%TYPE;
    l_prev_start_time arch_batch.actl_start_time%TYPE;
    l_prev_status arch_batch.status%TYPE;
    l_batch_date arch_batch.batch_date%TYPE;

    cursor c_prev_batch_cur is
    select batch_no,actl_start_time,jbcd_job_code,status,lfun_lbr_func,batch_date
    from batch_monitor_view
    where user_id = i_user_id
    and    status = 'A';
    --
    cursor c_other_prev is
    select batch_no,actl_start_time,jbcd_job_code,status,lfun_lbr_func,batch_date
    from batch_monitor_view
    where user_id = i_user_id
    and   actl_stop_time = (select max(actl_stop_time)
                             from batch
                             where user_id = i_user_id
                             and   batch_no != i_batch_no
                             and   status = 'C');
begin

  pl_log.g_application_func := 'LABOR';
  pl_log.g_program_name := 'pl_task_assign.sql';
 
   open c_prev_batch_cur;
     fetch c_prev_batch_cur
     into l_prev_batch_no,l_prev_start_time,
          l_job_code,l_prev_status,l_lfun_lbr_func,l_batch_date;
     if c_prev_batch_cur%notfound then
        o_prev_forklift := 'N';
        open c_other_prev;
        fetch c_other_prev
        into l_prev_batch_no, l_prev_start_time,
             l_job_code,l_prev_status,l_lfun_lbr_func,l_batch_date;
 
        if c_other_prev%found then
            o_prev_exist := 'Y' ;
            o_do_merge := 'N';
            if l_job_code != 'ISTOP' then
             pl_log.ins_msg('W','get_prev_batch',
               'This user does not have an Active batch status!'||
              ' Time Gap will Exists.',null,null);
            end if;
        else
            o_prev_exist := 'N' ;
            o_do_merge := 'N';
        end if;
        close c_other_prev;
     else
        if (l_lfun_lbr_func = 'FL' and l_prev_status = 'A') then
           o_prev_forklift := 'Y';
        else
           o_prev_forklift := 'N';
        end if;

        o_prev_exist := 'Y' ;
        if ((((sysdate - l_prev_start_time) * 1440) < 3)
            AND i_lfun_lbr_func = l_lfun_lbr_func
            AND substr(l_prev_batch_no,1,1) != 'I'
            AND l_prev_status = 'A')  then
           o_do_merge := 'Y';
        else
           o_do_merge := 'N';
        end if;
     end if;
     o_prev_batch_no := l_prev_batch_no;
     o_prev_start_time := l_prev_start_time;
     o_prev_status := l_prev_status;
     o_prev_batch_date := l_batch_date;
end get_prev_batch;
/* ========================================================================== */
procedure duration (i_job_code in job_code.jbcd_job_code%TYPE,
                    i_user_id in arch_batch.user_id%TYPE,
                    i_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                    o_out_dur out number) is
/*---------------------------------------------------------------------------
Return Values:
       o_out_dur : Duration of start or stop process from the users schedule
                   depending on the job code.
----------------------------------------------------------------------------*/
  l_stop   sched_type.stop_dur%type;
  l_start  sched_type.start_dur%type;
  --
  cursor c_get_dur is
  select nvl(start_dur,0),nvl(stop_dur,0)
  from sched_type st, usr u, sched s, job_code j
  where s.sched_type = st.sctp_sched_type
  and u.lgrp_lbr_grp = i_lbr_grp
  and replace(u.user_id,'OPS$',null) = i_user_id
  and u.lgrp_lbr_grp = s.sched_lgrp_lbr_grp
  and s.sched_jbcl_job_class = j.jbcl_job_class
  and j.jbcd_job_code = i_job_code;
begin
  open c_get_dur;
  fetch c_get_dur into l_start,l_stop;
  if c_get_dur%notfound then
     l_start := 0;
     l_stop := 0;
  end if;
  if i_job_code = 'ISTART' then
     o_out_dur := l_start;
  else
     o_out_dur := l_stop;
  end if;

end;

/* ========================================================================== */
procedure ins_indirect (i_jbcd_job_code in job_code.jbcd_job_code%TYPE,
                           i_status in arch_batch.status%TYPE,
                           i_user_id in arch_batch.user_id%TYPE,
                           i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                           i_actl_start_time in arch_batch.actl_start_time%TYPE,
                           i_actl_stop_time in arch_batch.actl_stop_time%TYPE,
                           i_actl_time_spent in arch_batch.actl_time_spent%TYPE,
                           i_forklift_point in point_distance.point_a%TYPE,
                           i_ref_no in arch_batch.ref_no%TYPE,
                           o_batch_no out arch_batch.batch_no%TYPE) is
/*--------------------------------------------------------------------------
Return Values:
     o_batch_no - batch number of the  indirect batch cretaed for the user.
---------------------------------------------------------------------------*/

-- Store the batch# in a global variable which
-- is used when the previous batch is a forklift batch
-- and to populate the kvi_from loc with the terminal
-- location.

       l_batch_no   varchar2(30);
begin
       select 'I'||TO_CHAR(seq1.NEXTVAL) INTO l_batch_no FROM DUAL;
       o_batch_no := l_batch_no; 
              --
       INSERT INTO BATCH
                  (BATCH_NO, BATCH_DATE,
                   JBCD_JOB_CODE, STATUS, USER_ID,
                   USER_SUPERVSR_ID,
                   ACTL_START_TIME, ACTL_STOP_TIME,
                   ACTL_TIME_SPENT,
                   NO_LUNCHES, NO_BREAKS,
                   KVI_DOC_TIME,KVI_CUBE,KVI_WT,KVI_NO_PIECE,
                   KVI_NO_PALLET,KVI_NO_ITEM,KVI_NO_DATA_CAPTURE,
                   KVI_NO_PO,KVI_NO_STOP,KVI_NO_ZONE,KVI_NO_LOC,
                   KVI_NO_CASE,KVI_NO_SPLIT,KVI_NO_MERGE,
                   KVI_NO_AISLE, KVI_NO_DROP,KVI_ORDER_TIME,DAMAGE,
                   TOTAL_COUNT,TOTAL_PIECE,TOTAL_PALLET,
                   KVI_FROM_LOC,ref_no,mod_usr)
       Select l_batch_no, trunc(sysdate),
                i_jbcd_job_code, i_status, i_user_id,
                i_user_supervsr_id,
                i_actl_start_time, i_actl_stop_time,
                nvl(i_actl_time_spent,0), 0, 0,
                0, 0, 0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                1, 0, 0,i_forklift_point,i_ref_no,
                decode(substr(i_ref_no,1,2),'RF',substr(i_ref_no,4),substr(i_ref_no,5))
       from sys.dual;
       if sql%notfound then
          raise_application_error(-20100,'Unable to insert batch in ins_indirect');
       end if;
end;
/* ========================================================================== */
procedure calc_parent_total (i_parent_batch in arch_batch.parent_batch_no%TYPE) is

  l_batch_cnt number := 0;
  l_total_piece   number := 0;
  l_total_pallet  number := 0;
  l_batch_count   number := 0;
  --
  /* We search for the total of childs batch information ONLY */
  /* because parent is already calculate of the first round */
  cursor c_conn_by_cur is
  select sum(nvl(kvi_no_piece,0)),sum(nvl(kvi_no_pallet,0))
  from conn_batch_vw
  connect by parent_batch_no = prior batch_no
  start with batch_no = i_parent_batch;
  --
  /* With MULTI batch we want to count only the Parent Batch */
  /* and not the the child batch. But you can have a child that */
  /* is MULTI batch that are within MULTI or REG batch */
  /* As for the Merge in Task Assign, we do want to count them */
  /* as separate batch */

  cursor c_parent_multi is
  select count(*)
  from conn_batch_vw
  where  batch_no not like parent_batch_no || '_'
  connect by parent_batch_no = prior batch_no
  start with batch_no = i_parent_batch;
begin
     l_batch_count := 0;
     l_total_piece := 0;
     l_total_pallet := 0;
  open c_conn_by_cur;
  fetch c_conn_by_cur into l_total_piece,l_total_pallet;
  if c_conn_by_cur%notfound then
     l_total_piece := 0;
     l_total_pallet := 0;
     l_batch_count := 0;
  else
     open c_parent_multi;
     fetch c_parent_multi into l_batch_count;
     if c_parent_multi%notfound or nvl(l_batch_count,0) = 0 then
          l_batch_count := 0;
     end if;
     close c_parent_multi;
  end if;
  update batch
    set total_count = l_batch_count,
        total_piece = l_total_piece,
        total_pallet = l_total_pallet
  where batch_no = i_parent_batch;
  if sql%notfound then
          raise_application_error(-20100,'Notifify SWMS Tech-Unable to Update Total--Count/Piece in calc_parent_total');
    
  end if;

end;
/* ========================================================================== */
procedure process_ins_float_hist (i_prev_batch in arch_batch.batch_no%TYPE,
                                  i_user_id in arch_batch.user_id%TYPE) is

  l_batch_no  arch_batch.batch_no%type;
  l_type      varchar2(2);
  --
  cursor c_get_parent_child_cur is
  select substr(batch_no,2,length(batch_no))
  from conn_batch_vw
  connect by parent_batch_no = prior batch_no
  start with batch_no = i_prev_batch ;
  --
  begin

    begin
       select substr(i_prev_batch,1,2) into l_type
       from dual;
       exception
        when others then
           null;
    end;

    if (l_type <> 'SS') then
   	 open c_get_parent_child_cur;
    	LOOP
       		fetch c_get_parent_child_cur into l_batch_no;
       		if c_get_parent_child_cur%found then
          		insert_to_float_hist(l_batch_no,i_user_id);
       		else
          		EXIT;
       		end if;
    	END LOOP;
    end if;
end;
/* ========================================================================== */
PROCEDURE INSERT_TO_FLOAT_HIST(i_get_batch_no in arch_batch.batch_no%TYPE,
                               i_user_id in arch_batch.user_id%TYPE) IS
 l_batch_no       float_hist.batch_no%TYPE;
 l_route_no       floats.route_no%TYPE;
 l_user_id        arch_batch.user_id%TYPE;
 l_prod_id        float_detail.prod_id%TYPE;
 l_cust_pref_vendor float_detail.cust_pref_vendor%TYPE;
 l_order_id       float_detail.order_id%TYPE;
 l_order_line_id  float_detail.order_line_id%TYPE;
 l_cust_id        ordm.cust_id%TYPE;
 l_qty_order      float_detail.qty_order%TYPE;
 l_qty_alloc      float_detail.qty_alloc%TYPE;
 l_merge_alloc_flag float_detail.merge_alloc_flag%TYPE;
 l_stop_no        float_detail.stop_no%TYPE;
 l_src_loc        float_detail.src_loc%TYPE;
 l_uom            float_detail.uom%TYPE;
 l_ship_date      ordm.ship_date%TYPE;
 l_float_no       floats.float_no%TYPE;
 l_dummy_exist char;

    CURSOR C_FLOAT_HIST IS
    SELECT  to_char(f.batch_no), f.route_no, i_user_id,
            fd.prod_id, fd.cust_pref_vendor, fd.order_id,
            fd.order_line_id, o.cust_id,
            sum(fd.qty_order), sum(fd.qty_alloc),
            fd.merge_alloc_flag,
            fd.stop_no, fd.src_loc, nvl(fd.uom,2), o.ship_date,f.float_no
      FROM  ordm o,
            floats f,
            float_detail fd
     WHERE  f.batch_no = to_number(i_get_batch_no)
       AND  o.order_id = fd.order_id
       AND  fd.qty_alloc <> 0
       AND  f.float_no = fd.float_no
       AND  fd.merge_alloc_flag <> 'M'
     GROUP  BY f.batch_no, f.route_no, fd.prod_id, fd.cust_pref_vendor,
               fd.order_id,
               fd.order_line_id, o.cust_id, fd.merge_alloc_flag,
               fd.stop_no, fd.src_loc, fd.uom, o.ship_date,f.float_no;
BEGIN
    open C_FLOAT_HIST;
    loop
      fetch C_FLOAT_HIST into
           l_batch_no,l_route_no,l_user_id,l_prod_id,l_cust_pref_vendor,
           l_order_id, l_order_line_id, l_cust_id, l_qty_order, l_qty_alloc,
           l_merge_alloc_flag, l_stop_no, l_src_loc, l_uom, l_ship_date,
           l_float_no;
      exit when C_FLOAT_HIST%NOTFOUND;
      begin
         select 'X' into l_dummy_exist
         from float_hist
         where batch_no like l_batch_no || '%'
         and   order_id = l_order_id
         and   order_line_id = l_order_line_id
         and   uom = l_uom
         and   src_loc= l_src_loc;
             null;
         exception
            when no_data_found then
              INSERT INTO FLOAT_HIST
                (batch_no, route_no, user_id, prod_id, cust_pref_vendor,
                 order_id,
                 order_line_id, cust_id, qty_order, qty_alloc,
                 merge_alloc_flag, stop_no, src_loc, uom, ship_date,
                 float_no,add_user,add_date)
              VALUES
                (l_batch_no, l_route_no, l_user_id,l_prod_id,l_cust_pref_vendor,
                 l_order_id,l_order_line_id, l_cust_id,l_qty_order,l_qty_alloc,
                 l_merge_alloc_flag, l_stop_no,l_src_loc, l_uom, l_ship_date,
                 l_float_no,l_user_id,sysdate);
            when others then
                 null;
        end;
     end loop;
     CLOSE C_FLOAT_HIST;
END;


/* ========================================================================== */
procedure upd_curr_batch (i_status in char,
                             i_actl_start_time in arch_batch.actl_start_time%TYPE,
                             i_actl_stop_time in arch_batch.actl_stop_time%TYPE,
                             i_batch_no in arch_batch.batch_no%TYPE,
                             i_user_id in arch_batch.user_id%TYPE,
                             i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                             i_forklift_point in point_distance.point_a%TYPE,
                             i_ref_no in arch_batch.ref_no%TYPE) is
  l_kvi_no_po  number;
begin
if i_status = 'M' and substr(i_batch_no,1,2) = 'PO' then
   l_kvi_no_po := 1;
else
   l_kvi_no_po := null;
end if;
   update batch
     set user_id = i_user_id,
         user_supervsr_id = i_user_supervsr_id,
         status = i_status,
         actl_start_time = i_actl_start_time,
         actl_stop_time = i_actl_stop_time,
         ref_no = nvl(ref_no,i_ref_no),
         kvi_no_po = nvl(l_kvi_no_po,kvi_no_po),
         kvi_from_loc = i_forklift_point
   where batch_no = i_batch_no;
   --
   if sql%notfound then
          raise_application_error(-20100,'Unable to update batch. Call Tech Support in upd_curr_batch');
   end if;
end;

/* ========================================================================== */
procedure validate_userid(i_user_id in usr.user_id%TYPE,
                          o_supervsr_id out usr.suprvsr_user_id%TYPE,
                          o_lbr_grp out usr.lgrp_lbr_grp%TYPE) is
/*------------------------------------------------------------------------------
Return Values:
        o_supervsr_id - Supervisor Id of the user.
        o_lbr_grp     - Labor group of the user.
-------------------------------------------------------------------------------*/
  l_badge_no    usr.badge_no%type;
 
  cursor c_usr_cur is
   select suprvsr_user_id,lgrp_lbr_grp,badge_no
   from usr
   where (replace(user_id,'OPS$',null) = i_user_id OR
          replace(badge_no,'OPS$',null) = i_user_id)
   AND    lgrp_lbr_grp is not null;
  begin
    open c_usr_cur;
    fetch c_usr_cur into o_supervsr_id,o_lbr_grp,l_badge_no;
    if c_usr_cur%notfound then
          raise_application_error(-20100,'User ID or Badge # is invalid OR the Labor Grp');

    end if;
end validate_userid;

/* ========================================================================== */
procedure upd_pre_merge ( i_user_id in arch_batch.user_id%TYPE,
                          i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                          i_parent_batch_no in arch_batch.parent_batch_no%TYPE,
                          i_start_stop_time in arch_batch.actl_start_time%TYPE) is
begin
  update batch
    set user_id = i_user_id,
        user_supervsr_id = i_user_supervsr_id,
        actl_start_time = i_start_stop_time,
        actl_stop_time = i_start_stop_time
  where parent_batch_no = i_parent_batch_no
  and   parent_batch_no <> batch_no
  and   substr(batch_no,1,length(parent_batch_no)) = i_parent_batch_no
  and   status = 'M';
  if sql%notfound then
     null;
  end if;
end;
/* ========================================================================== */
procedure rf_feedback(i_batch_no in arch_batch.batch_no%TYPE,
                      i_user_id in arch_batch.user_id%TYPE,
                      o_feedback_mask out number,
                      o_break_lunch out number,
                      o_prev_perf out number,
                      o_dir_time out  arch_batch.goal_time%TYPE,
                      o_targ_goal_time out arch_batch.goal_time%TYPE,
                      o_daily_perf out number ) is
/*=============================================================================
Return Values:
   o_merged_time - If merged, merged goal time or target time which is > 0. 
                   If not merged, goal time or target time of the current batch which is > 0.
   o_prev_perf   - Performance percentage of the previous job. If previous job is 
                   an indirect job then 0.
   o_daily_perf  - Average Performance percentage of all jobs other than indirect jobs
                   on that day.

=============================================================================*/

  l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
  l_prev_time_spent arch_batch.actl_time_spent%TYPE;
  l_prev_goal_time arch_batch.goal_time%TYPE;
  l_prev_target_time arch_batch.target_time%TYPE;
  l_goal_target arch_batch.goal_time%TYPE;
  l_direct_time arch_batch.actl_time_spent%TYPE;
  l_curr_feed_mask job_code.mask_lvl%TYPE;
  l_prev_feed_mask job_code.mask_lvl%TYPE;
  l_job_code job_code.jbcd_job_code%TYPE;



begin
  begin
    select mask_lvl,jbcd_job_code
    into l_curr_feed_mask,l_job_code
    from job_code
    where jbcd_job_code = i_batch_no
    or    jbcd_job_code = (select jbcd_job_code from batch
                           where batch_no = i_batch_no);
    dbms_output.put_line('Curr Feed Mask '||to_char(l_curr_feed_mask));
    dbms_output.put_line('Curr FJob Code '||l_job_code);
    exception
       when no_data_found then
             l_curr_feed_mask := 1;
   end;
dbms_output.put_line('Curr-'||to_char(l_curr_feed_mask));
   begin
     select nvl(b.actl_time_spent,0),nvl(b.target_time,0),nvl(b.goal_time,0),
            j.mask_lvl,nvl(no_breaks,0)+nvl(no_lunches,0),j.lfun_lbr_func
     into l_prev_time_spent,l_prev_target_time,l_prev_goal_time,
            l_prev_feed_mask,o_break_lunch,l_lfun_lbr_func
     from batch b,job_code j
     where b.jbcd_job_code = j.jbcd_job_code
     and   b.user_id = i_user_id
     and   b.actl_stop_time = (select max(actl_stop_time) 
                             from batch
                             where user_id = i_user_id
                             and batch_no != i_batch_no
                             and status = 'C')
     and status = 'C';
dbms_output.put_line('Prev-'||to_char(l_prev_feed_mask));
         if l_lfun_lbr_func = 'FL' then
             l_prev_feed_mask := 1;
dbms_output.put_line('In Forklift Prev-'||to_char(l_prev_feed_mask));
         end if;
     exception
       when others then
           l_prev_feed_mask := 1;
   end;
dbms_output.put_line('Prev-'||to_char(l_prev_feed_mask));
   if (l_prev_feed_mask in ('1','2') and l_curr_feed_mask='1') then
         o_feedback_mask := 1;
   elsif (l_prev_feed_mask in ('1','2') and l_curr_feed_mask in ('2','3','4'))  then
         o_feedback_mask := 2;
   elsif (l_prev_feed_mask = '3' and l_curr_feed_mask in ('1','2','3','4'))  then
         o_feedback_mask := 3;
   elsif (l_prev_feed_mask = '4' and l_curr_feed_mask in ('1','2','3','4'))  then
         o_feedback_mask := 4;
   end if;
   
   if l_prev_goal_time > 0 and l_prev_time_spent > 0 then
      o_prev_perf := round((l_prev_goal_time/nvl(l_prev_time_spent,0)) * 100);
   elsif l_prev_target_time > 0  and l_prev_time_spent > 0 then
      o_prev_perf := round((l_prev_target_time/nvl(l_prev_time_spent,0)) * 100);
   else
      o_prev_perf := 0;
   end if;
  begin
    select sum(nvl(goal_time,0)) + sum(nvl(target_time,0)),
          sum(nvl(actl_time_spent,0))
    into l_goal_target,l_direct_time
    from batch
    where status = 'C'
    and   jbcd_job_code not like 'I%'
    and   actl_start_time >= (select min(actl_start_time)
                             from batch
                             where user_id = i_user_id
                             and jbcd_job_code = 'ISTART')
    and actl_start_time <= sysdate
    and user_id = i_user_id;
       if l_goal_target = 0 or l_direct_time = 0 then
          o_daily_perf := 0;
       else
          o_daily_perf := round((l_goal_target/l_direct_time) * 100);
       end if;
       o_dir_time := l_direct_time;
       o_targ_goal_time := l_goal_target;
    exception
       when no_data_found then
           o_daily_perf := 0;
       when others then
           o_daily_perf := 0;
    end;      
                             
end rf_feedback;

/*=========================================================================== */
procedure check_forklift_batch ( i_user_id in usr.user_id%TYPE,
                              o_fork_batch_no out arch_batch.batch_no%TYPE,
                              o_forklift_flag  out varchar,
                              o_parent_batch_no out arch_batch.parent_batch_no%TYPE) is
/*----------------------------------------------------------------------------
Return Values:
    o_forklift_flag : Y - If the previous batch for the user is forklift batch
                          and the status as A.
                      N - If the previous batch is not forklift batch or if the
                          previous batch is forklit batch with status as C.
   o_fork_batch_no : Batch Number of the forklift batch.

Maintenance history  ---
03-MAR-2006 prpbcb  Treat returns T batch as a forklift batch.  Changed
                       and lfun_lbr_func = 'FL'
                    to
                       and lfun_lbr_func in ('FL', 'RP')
-----------------------------------------------------------------------------*/
  l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
  l_fork_batch_no batch.batch_no%TYPE;
  cursor c_batch_cur is
    select lfun_lbr_func, batch_no, parent_batch_no
    from batch_monitor_view
    where user_id = i_user_id
    and lfun_lbr_func IN ('FL', 'RP')
    and    status = 'A';
   begin
     open c_batch_cur;
     fetch c_batch_cur into l_lfun_lbr_func,l_fork_batch_no,o_parent_batch_no;
     o_fork_batch_no := l_fork_batch_no;
     if c_batch_cur%notfound then
          o_forklift_flag := 'N';
     else
          o_forklift_flag := 'Y';
     end if;
     close c_batch_cur;
end;
/* ========================================================================== */
procedure validate_point_a(i_point_a point_distance.point_a%TYPE,
                           o_valid_point out varchar) is
/*-----------------------------------------------------------------------------
Return Values:
   o_valid_point : N - Not a valid point
                   Y - Valid point
-------------------------------------------------------------------------------*/
  cursor c_pt is
  select point_a
  from point_distance
  where point_type='DA'
  and   point_a = i_point_a
  union
  select aisle||substr(bay,1,2) point_a
  from bay_distance
  where aisle||substr(bay,1,2) = i_point_a;
  l_point_a   point_distance.point_a%type;
begin
if i_point_a is not null then
  open c_pt;
  fetch c_pt into l_point_a;
  if c_pt%NOTFOUND then
     o_valid_point := 'N';
  else
     o_valid_point := 'Y';
  end if;
  close c_pt;
else
  o_valid_point := 'N';
end if;
end;
/* ========================================================================== */
procedure adjust_istop_time(i_istop_batch_no    IN arch_batch.batch_no%TYPE,
                            i_iwash_batch_no    IN arch_batch.batch_no%TYPE,
                            i_forklift_batch_no IN arch_batch.batch_no%TYPE) IS
-- This procedure adjusts the IWASH and ISTOP actual start
-- and stop times when the user is inserting an ISTOP and the previous batch
-- was a forklift batch.  The IWASH and ISTOP get created then the forklift
-- batch is completed which leaves the forklift batch with a stop time
-- after the IWASH and ISTOP.  This procedure adjusts the times.
   l_forklift_actl_stop_time  DATE;
   l_iwash_actl_start_time    DATE;
   l_iwash_actl_stop_time     DATE;
   CURSOR c_stop_time_cur IS
      SELECT actl_stop_time
        FROM batch
       WHERE batch_no = i_forklift_batch_no;
   CURSOR c_iwash_cur IS
      SELECT actl_start_time, actl_stop_time
        FROM batch
       WHERE batch_no = i_iwash_batch_no;
BEGIN
   OPEN c_stop_time_cur;
   FETCH c_stop_time_cur INTO l_forklift_actl_stop_time;
   CLOSE c_stop_time_cur;
   IF (i_iwash_batch_no IS NULL or i_iwash_batch_no = 'NO_DATA') THEN
      -- Only have an ISTOP.
      UPDATE BATCH
         SET actl_start_time = l_forklift_actl_stop_time,
             actl_stop_time = l_forklift_actl_stop_time +
                  (actl_stop_time - actl_start_time)
       WHERE batch_no = i_istop_batch_no;
   ELSE
   -- Have an IWASH and ISTOP.
      OPEN c_iwash_cur;
      FETCH c_iwash_cur INTO l_iwash_actl_start_time, l_iwash_actl_stop_time;
      CLOSE c_iwash_cur;
      UPDATE BATCH
         SET actl_start_time = l_forklift_actl_stop_time,
             actl_stop_time = l_forklift_actl_stop_time +
                  (l_iwash_actl_stop_time - l_iwash_actl_start_time)
       WHERE batch_no = i_iwash_batch_no;
      UPDATE BATCH
         SET actl_start_time = l_forklift_actl_stop_time +
                  (l_iwash_actl_stop_time - l_iwash_actl_start_time),
             actl_stop_time = l_forklift_actl_stop_time +
                  (l_iwash_actl_stop_time - l_iwash_actl_start_time)
       WHERE batch_no = i_istop_batch_no;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
          raise_application_error(-20100,'Failed selecting iwash and istop time');
END;
/* ========================================================================== */
procedure change_status(i_batch_no in arch_batch.batch_no%TYPE,
                        i_status in arch_batch.status%TYPE,
                        o_status out arch_batch.status%TYPE) is
/*============================================================================
Return Values:
    o_status : status of the batch send to pro*c program. 
               This is called again to update the status back to 
               original status after signing off from forklift batch.
=============================================================================*/
begin
  pl_log.g_application_func := 'LABOR';
  pl_log.g_program_name := 'pl_task_assign.sql';
  begin
     select status into o_status
     from batch
     where batch_no = i_batch_no;
         update batch
         set status = i_status
         where batch_no = i_batch_no; 
     exception
        when no_data_found then
           pl_log.ins_msg('F','change_status',
                  'No batch found while selecting status of batch number '||i_batch_no,null,null);
        when others then
           pl_log.ins_msg('F','change_status',
                  'Failed while selecting status of batch number '||i_batch_no,null,null);
  end;

end change_status;
/*===========================================================================*/
END pl_task_assign;
/

