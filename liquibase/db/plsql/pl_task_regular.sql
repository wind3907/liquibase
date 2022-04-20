rem *****************************************************
rem @(#) src/schema/plsql/pl_task_regular.sql, swms, swms.9, 10.1.1 9/7/06 1.5

rem @(#) File : pl_task_regular.sql
rem @(#) Usage: sqlplus USR/PWD pl_task_regular.sql

rem ---  Maintenance history  ---
rem 03-JUN-2002 acpakp Initial version
rem 15-JUL-2002 acpakp Changed process_batch to return NO_DATA for Iwash 
rem                    and Istop batch number if the batch is not ISTOP
rem                    and NO_DATA for Iwash if batch is ISTOP and duration is null.
rem 05/13/04    prplhj D#11601/11602 Added checking of PO<batch-no> if
rem                    S<batch-no> is not found to process_batch(). Added 'R'
rem		       sequence to ins_dummy_parent().
rem 11/2/05     prpakp Commented out call to process_ins_float_hist since pl_lm1 is changed
rem                    to call this and insert data to float_hist.


CREATE OR REPLACE PACKAGE swms.pl_task_regular IS
/*==========================================================================================
The procedures in this package are
1. check_istop    - If the user enters ISTOP then, this procedure will check whether the user
                  - has any valid batch existing. If no batch exists for the user, this will 
                  - return a message no valid batch existing. If there is  batch existing but 
                  - there is no batch other than ISTART or ISTOP, then this returns a message 
                  - no valid direct batch exists. If not this will call the process_istop 
                  - procedure to complete the process.
2. process_istop  - This will complete the ISTOP process. This procedure will get the 
                  - details of the previous batch by calling get_prev_batch and get the 
                  - duration of STOP process from his schedule. If there is duration for the
                  - stop process this will call ins_indirect procedure to insert two entries,
                  - IWASH nad ISTOP. If the previos batch is a forklift batch, this will call the
                  - procedure ins_indirect will different parameters. If the previous batch is a
                  - Selector batch (Batch Number Starts with S) this will call the procedure
                  - process_ins_float_hist to insert the details of the batch to the float_hist table.
3.process_valid_batch - This procedure will be called if the user enters a valid batch other than
                  - ISTART and ISTOP. This will get all the details about the previous batch by
                  - calling get_prev_batch. If there is no previous batch existing for the user
                  - this will call ins_istart to insert an ISTART for the user. Then update the
                  - current batch entered by the user by calling  upd_current batch.
                  - If there is previous batch existing and if it is to be merged with the previous
                  - batch this will call the merge procedure from pl_task_merge.
                  - If it is not to be merged then, if the previous batch is not a forklift batch,
                  - this will call the procedure pl_lm1.create_schedule to calculate and update 
                  - the no of breaks and lunches, actual time spent. If the previous batch is a 
                  - forklift batch, forklift process will call this procedure. After this update 
                  - the current batch by calling upd_current_batch. If the previous batch is a
                  - Selector batch (Batch Number Starts with S) this will call the procedure
4. process_batch - This is the main procedure in this package.
                  - After checking authorisation and checking whether previous batch is a forklift batch
                  - and getting the forklift terminal location if previous batch is forklift batch,
                  - this procedure is called with user_id,batch_no,forklift_point.
                  - This procedure will check whether the batch number user entered is 
                  - ISTART - call check_for_istart and ins_istart.
                  - ISTOP - call check_istop.
                  - other valid batch - call add_indirect_entry
                  - if batch is a LOT BATCH call process_lot_batch.
                  - else call process_valid_batch.
5 . chk_lot_status - This procedure will check the status and return
                     whether the batch is valid.
                     N - Batch does not exist
                     P - Batch is a parent batch.
                     C - Batch is a child batch.
                     M - Batch is a merged batch.
                     A - Batch is active.
                     Y - if valid batch.
                     This is called from process_lot_batch.
6 . ins_dummy_parent - If the batch is a lot batch and if it is not merged
                     with the previous lot batch then, a dummy parent for the
                     lot batch is created and all lot batches entered by the user
                     merged to this dummy batch.
7 . get_prev_lot_batch - This will get all the details about the previous batch.
8 . process_lot_batch - This will check the status of the batch by calling
                        chk_lot_status. If valid batch then it calls
                        get_prev_lot_batch and get all the details. If this batch
                        is to be merged with previous batch, it calls
                        pl_task_merge.process_merge_batch. If not, then
                        a dummy parent is created by calling ins_dummy_parent
                        and the batch will be merged with the dummy batch as parent.
                        If previous batch is active, the batch will be signed off.

====================================================================================*/

procedure check_istop(i_user_id in arch_batch.user_id%TYPE,
                      i_forklift_point in point_distance.point_a%TYPE,
                      i_ref_no in arch_batch.ref_no%TYPE,
                      o_iwash_batch_no out arch_batch.batch_no%TYPE,
                      o_istop_batch_no out arch_batch.batch_no%TYPE,
                      o_exist out varchar) ;

procedure process_istop(i_user_id in arch_batch.user_id%TYPE,
                        i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                        i_batch_no in arch_batch.batch_no%TYPE,
                        i_batch_date in arch_batch.batch_date%TYPE,
                        i_lfun_lbr_func in job_code.lfun_lbr_func%TYPE,
                        i_lgrp_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                        i_forklift_point in point_distance.point_a%TYPE,
                        i_ref_no in arch_batch.ref_no%TYPE,
                        o_iwash_batch_no out arch_batch.batch_no%TYPE,
                        o_istop_batch_no out arch_batch.batch_no%TYPE);

procedure process_valid_batch(i_user_id in arch_batch.user_id%TYPE,
                              i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                              i_batch_no in arch_batch.batch_no%TYPE,
                              i_ref_no in arch_batch.ref_no%TYPE,
                              i_lfun_lbr_func in job_code.lfun_lbr_func%TYPE,
                              i_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                              i_actl_start_time in arch_batch.actl_start_time%TYPE,
                              i_forklift_point in point_distance.point_a%TYPE);

procedure process_batch(i_user_id in arch_batch.user_id%TYPE,
                        io_batch_no in out arch_batch.batch_no%TYPE,
                        i_forklift_point in point_distance.point_a%TYPE,
                        i_ref_no arch_batch.ref_no%TYPE,
                        o_iwash_batch_no out arch_batch.batch_no%TYPE,
                        o_istop_batch_no out arch_batch.batch_no%TYPE,
                        o_lot_batch_yn out varchar,
                        o_success out varchar);

procedure chk_lot_status (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          o_success out char);

procedure ins_dummy_parent (i_job_code in job_code.jbcd_job_code%TYPE,
                            i_user_id in arch_batch.user_id%TYPE,
                            i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                            i_start_time in arch_batch.actl_start_time%TYPE,
                            o_dummy_parent out arch_batch.batch_no%TYPE);

procedure get_lot_prev_batch (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          i_jbcd_job_code in arch_batch.jbcd_job_code%TYPE,
                          o_prev_batch_no out arch_batch.batch_no%TYPE,
                          o_prev_batch_date out arch_batch.batch_date%TYPE,
                          o_prev_start_time out arch_batch.actl_start_time%TYPE,
                          o_do_merge out char,
                          o_prev_exist out char,
                          o_prev_forklift out char,
                          o_prev_status out  arch_batch.status%TYPE);

procedure process_lot_batch(i_user_id in arch_batch.user_id%TYPE,
                              i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                              i_batch_no in arch_batch.batch_no%TYPE,
                              i_ref_no in arch_batch.ref_no%TYPE,
                              i_jbcd_job_code in job_code.jbcd_job_code%TYPE,
                              i_lgrp_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                              i_actl_start_time in arch_batch.actl_start_time%TYPE,
                              i_forklift_point in point_distance.point_a%TYPE);

END pl_task_regular;
/

/*=========================================================================================*/
/*=========================================================================================*/
CREATE OR REPLACE PACKAGE BODY swms.pl_task_regular IS
/* ========================================================================== */
procedure check_istop(i_user_id in arch_batch.user_id%TYPE,
                      i_forklift_point in point_distance.point_a%TYPE,
                      i_ref_no in arch_batch.ref_no%TYPE,
                      o_iwash_batch_no out arch_batch.batch_no%TYPE,
                      o_istop_batch_no out arch_batch.batch_no%TYPE,
                      o_exist out varchar) is
/*------------------------------------------------------------------------------
Return Values:
    o_exist : N - No valid batch exists
              D - Batch Exists. But No direct active or complete batch.
              Y - Valid Batch exists.
    o_iwash_batch_no - batch_no of the IWASH batch created if duration exists.
    o_istop_batch_no - batch_no of the ISTOP batch created.
    (These two are returned to use in forklift sign off process if previous batch 
     is a forlkift batch)
-------------------------------------------------------------------------------*/
    cursor c_prev_batch_cur is
    select batch_no,jbcd_job_code,lfun_lbr_func,batch_date,lgrp_lbr_grp,user_supervsr_id
    from batch_monitor_view
    where user_id = i_user_id
    and    status = 'A';
    --
    cursor c_get_other_batch is
    select batch_no,jbcd_job_code,lfun_lbr_func,batch_date,lgrp_lbr_grp,user_supervsr_id
    from batch_monitor_view
    where user_id = i_user_id
    and   status = 'C'
    and   actl_stop_time = (select max(actl_stop_time)
                             from batch
                             where user_id = i_user_id
                             and   status in ('A','C'));
 l_job_code job_code.jbcd_job_code%TYPE;
 l_prev_batch_no arch_batch.batch_no%TYPE;
 l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
 l_jbcd_job_code job_code.jbcd_job_code%TYPE;
 l_batch_no arch_batch.batch_no%TYPE;
 l_batch_date arch_batch.batch_date%TYPE;
 l_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
 l_user_supervsr_id arch_batch.user_supervsr_id%TYPE;
 error_prob     varchar2(200) := SQLERRM; 
 begin
   pl_log.g_application_func := 'LABOR';
   pl_log.g_program_name := 'pl_task_regular.sql';
   open c_prev_batch_cur;
   fetch c_prev_batch_cur into l_batch_no, l_jbcd_job_code,l_lfun_lbr_func,
         l_batch_date,l_lgrp_lbr_grp,l_user_supervsr_id;
   if c_prev_batch_cur%notfound then
      open c_get_other_batch;
      fetch c_get_other_batch into l_batch_no, l_jbcd_job_code,l_lfun_lbr_func,
            l_batch_date,l_lgrp_lbr_grp,l_user_supervsr_id;
      if c_get_other_batch%notfound then
         o_exist := 'N';     
      else
         if l_jbcd_job_code IN ('ISTART','ISTOP') then
            o_exist := 'D';
            pl_log.ins_msg('F','check_istop',
                  'There is no Direct Active or complete batch available for this user.ISTOP will not be created.',null,null);
         else
            o_exist := 'Y';
            pl_log.ins_msg('W','check_istop',
                  'There is no Active batch but there is other complete batch. ISTOP will be created.',null,null);
          
            process_istop(i_user_id,l_user_supervsr_id,l_batch_no,l_batch_date,l_lfun_lbr_func,
                                l_lgrp_lbr_grp,i_forklift_point,i_ref_no,o_iwash_batch_no,o_istop_batch_no);
         end if;
      end if;
      close c_get_other_batch;
   else
       o_exist := 'Y';
       process_istop(i_user_id,l_user_supervsr_id,l_batch_no,l_batch_date,l_lfun_lbr_func,
                                l_lgrp_lbr_grp,i_forklift_point,i_ref_no,o_iwash_batch_no,o_istop_batch_no);
   end if;
   
   close c_prev_batch_cur;
end check_istop;
/* ========================================================================== */
procedure process_istop(i_user_id in arch_batch.user_id%TYPE,
                        i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                        i_batch_no in arch_batch.batch_no%TYPE,
                        i_batch_date in arch_batch.batch_date%TYPE,
                        i_lfun_lbr_func in job_code.lfun_lbr_func%TYPE,
                        i_lgrp_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                        i_forklift_point in point_distance.point_a%TYPE,
                        i_ref_no in arch_batch.ref_no%TYPE,
                        o_iwash_batch_no out arch_batch.batch_no%TYPE,
                        o_istop_batch_no out arch_batch.batch_no%TYPE) is
/*-----------------------------------------------------------------------------
Return Values:
         o_iwash_batch_no - batch no of the IWASH batch created for the user 
         o_istop_batch_no - Batch no of the ISTOP batch created for the user.
         (This is returned for use in forklift process).
------------------------------------------------------------------------------*/
  l_dur number;
 
  l_prev_batch_no arch_batch.batch_no%TYPE;
  l_prev_batch_date arch_batch.batch_date%TYPE;
  l_prev_start_time arch_batch.actl_start_time%TYPE;
  l_do_merge char;
  l_prev_exist char;
  l_prev_forklift char;
  l_prev_status arch_batch.status%TYPE;
  l_istop_time arch_batch.actl_stop_time%TYPE;
  l_actl_stop_time arch_batch.actl_stop_time%TYPE;
  l_actl_time_spent arch_batch.actl_time_spent%TYPE;
  l_iwash_batch_no arch_batch.batch_no%TYPE;
  l_istop_batch_no arch_batch.batch_no%TYPE;
  success_flag_bln boolean;

 begin
    pl_task_assign.get_prev_batch(i_user_id,i_batch_no,i_lfun_lbr_func,l_prev_batch_no,l_prev_batch_date,l_prev_start_time,
                   l_do_merge,l_prev_exist,l_prev_forklift,l_prev_status);
    l_actl_stop_time := sysdate;
    if l_prev_status = 'A' then
       l_actl_time_spent := to_number((l_actl_stop_time -l_prev_start_time) * 1440);
  
       pl_lm1.create_schedule(i_batch_no,i_batch_date,l_actl_stop_time,l_actl_time_spent);
    end if;
 
    /* Commented out since pl_lm1 is changed to call this procedure and insert data to float_hist.
    if substr(i_batch_no,1,1) = 'S' then
         pl_task_assign.process_ins_float_hist(i_batch_no,i_user_id);
    end if;*/
   -- If the previous batch if it is a forklift batch the leave the status
   -- as active.  After the user enters the terminal location
   -- host program TP_signoff_from_forklift_batch is called to complete
   -- the batch.  Here we are interested in saving the no_breaks and no_lunches.
   if (l_prev_forklift = 'Y') then
      update batch
      set status = 'A'
      where batch_no = i_batch_no
      and   batch_date = i_batch_date;
   end if;
   pl_task_assign.duration('ISTOP', i_user_id, i_lgrp_lbr_grp,l_dur);
       --
   l_istop_time := l_actl_stop_time +
                            (nvl(l_dur,0)/1440);
   --
   -- Handle the situation where the previous batch is a
   -- forklift batch.  The IWASH and ISTOP get inserted before the forklift
   -- batch is completed.  The IWASH and the ISTOP start and stop times need
   -- to be outside of the forklift start and stop times. One hour should do it.
   -- If this is not done then function lmf_remove_except_time in
   -- lm_forklift.pc will substract the IWASH and ISTOP time from the forklift
   -- time when completing the forklift batch happens furthur on in the processing
   -- after the user enters the terminal location.  The IWASH and ISTOP start
   -- and stop times get adjusted after the forklift batch is completed.
  if (l_prev_forklift = 'Y') then
    if nvl(l_dur,0) > 0 then
       pl_task_assign.ins_indirect('IWASH','C',i_user_id,
                    i_user_supervsr_id,
                    l_actl_stop_time+1/24,
                    l_istop_time+1/24, l_dur,
                    i_forklift_point,
                    i_ref_no,
                    l_iwash_batch_no);
       pl_task_assign.ins_indirect('ISTOP','C',i_user_id,
                     i_user_supervsr_id,
                     l_istop_time+1/24,
                     l_istop_time+1/24, 0,
                     i_forklift_point,
                     i_ref_no,
                     l_istop_batch_no);
    else
       pl_task_assign.ins_indirect('ISTOP','C',i_user_id,
                   i_user_supervsr_id,
                   l_actl_stop_time+1/24,
                   l_actl_stop_time+1/24, 0,
                   i_forklift_point,
                   i_ref_no,
                   l_istop_batch_no);
    end if; 
  else
    if nvl(l_dur,0) > 0 then
       pl_task_assign.ins_indirect('IWASH','C',i_user_id,
                    i_user_supervsr_id,
                    l_actl_stop_time,
                    l_istop_time, l_dur,
                    i_forklift_point,
                    i_ref_no,
                    l_iwash_batch_no);
       pl_task_assign.ins_indirect('ISTOP','C',i_user_id,
                     i_user_supervsr_id,
                     l_istop_time,
                     l_istop_time, 0,
                     i_forklift_point,
                     i_ref_no,
                     l_istop_batch_no);
    else
       pl_task_assign.ins_indirect('ISTOP','C',i_user_id,
                   i_user_supervsr_id,
                   l_actl_stop_time,
                   l_actl_stop_time, 0,
                   i_forklift_point,
                   i_ref_no,
                   l_istop_batch_no);
    end if;
   end if;
   if nvl(l_dur,0) > 0 then
       o_iwash_batch_no := l_iwash_batch_no;
   else
       o_iwash_batch_no := 'NO_DATA';
   end if;     
   o_istop_batch_no := l_istop_batch_no;
end process_istop;


/* ========================================================================== */
procedure process_valid_batch(i_user_id in arch_batch.user_id%TYPE,
                              i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                              i_batch_no in arch_batch.batch_no%TYPE,
                              i_ref_no in arch_batch.ref_no%TYPE,
                              i_lfun_lbr_func in job_code.lfun_lbr_func%TYPE,
                              i_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                              i_actl_start_time in arch_batch.actl_start_time%TYPE,
                              i_forklift_point in point_distance.point_a%TYPE) is

        l_do_merge       char(1);
        l_prev_exist     char(1);
        l_prev_batch_no  arch_batch.batch_no%TYPE;
        l_prev_start_time arch_batch.actl_start_time%TYPE;
        l_prev_forklift char;
        l_prev_status   char;
        l_istart_created  char;
        l_istart_time    arch_batch.actl_start_time%TYPE;
        l_prev_actl_stop_time arch_batch.actl_stop_time%TYPE;
        l_prev_actl_time_spent arch_batch.actl_time_spent%TYPE;
        l_prev_batch_date arch_batch.batch_date%TYPE;
        l_batch_no arch_batch.batch_no%TYPE;
        l_success char;
        --
begin
        pl_task_assign.get_prev_batch(i_user_id,i_batch_no,i_lfun_lbr_func,l_prev_batch_no,l_prev_batch_date,l_prev_start_time,
                   l_do_merge,l_prev_exist,l_prev_forklift,l_prev_status);
        if l_prev_forklift = 'Y' then
            l_do_merge := 'N';
            l_prev_exist := 'Y';
        end if;

        if l_prev_exist = 'N' then

           pl_task_assign.ins_istart('N',i_user_id,i_user_supervsr_id,i_lbr_grp,i_ref_no,l_istart_created,l_istart_time,l_batch_no);

           pl_task_assign.upd_curr_batch('A',l_istart_time,null,i_batch_no,i_user_id,i_user_supervsr_id,i_forklift_point,i_ref_no);

           pl_task_assign.upd_pre_merge(i_user_id,i_user_supervsr_id, i_batch_no,l_istart_time);

        else
           pl_task_assign.create_istart(i_user_id,i_lbr_grp,i_user_supervsr_id);
           if l_do_merge = 'Y' then
              pl_task_merge.process_merge_batch(l_prev_batch_no,i_batch_no,i_user_id,l_success);
           else
              if l_prev_status = 'A' then
                  if l_prev_forklift != 'Y' then
                       l_prev_actl_stop_time := i_actl_start_time;
                       l_prev_actl_time_spent :=
                              to_number((l_prev_actl_stop_time - l_prev_start_time) * 1440);
                       pl_lm1.create_schedule(l_prev_batch_no,l_prev_batch_date,
                                  l_prev_actl_stop_time,l_prev_actl_time_spent);
                       pl_task_assign.calc_parent_total(l_prev_batch_no);
                  end if;
              end if;
              pl_task_assign.upd_curr_batch('A',i_actl_start_time,null,i_batch_no,i_user_id,i_user_supervsr_id,i_forklift_point,i_ref_no);
              pl_task_assign.upd_pre_merge(i_user_id,i_user_supervsr_id, i_batch_no,i_actl_start_time);

              /* Commented out since pl_lm1 is changed to call this and insert data to float_hist.
              if substr(l_prev_batch_no,1,1) = 'S' then
                 pl_task_assign.process_ins_float_hist(l_prev_batch_no,i_user_id);
              end if;*/

          end if;
      end if;
end;
/*======================================================================================================*/
procedure chk_lot_status (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          o_success out char) is


  l_has_parent  char(2);
  l_user_id     arch_batch.user_id%type;
  l_status      arch_batch.status%TYPE;
  l_lot_attach_parent arch_batch.parent_batch_no%TYPE;
  cursor c_chk_lot_status is
     select decode(parent_batch_no,null,'OK',batch_no,'PA','CH'),
         user_id,parent_batch_no,status
     from batch
     where batch_no = i_batch_no;
begin
   pl_log.g_application_func := 'LABOR';
   pl_log.g_program_name := 'pl_task_regular.sql';
  o_success := 'Y';
  open c_chk_lot_status;
  fetch c_chk_lot_status into l_has_parent,l_user_id,
                              l_lot_attach_parent,l_status;
  if c_chk_lot_status%notfound then
     pl_log.ins_msg('F','chk_lot_status','Invalid Batch Lot Number.',null,null);
     o_success := 'N';
  else
     if l_has_parent = 'PA' then
        pl_log.ins_msg('F','chk_lot_status','The batch is a parent batch.',null,null);
        o_success := 'P';
     elsif (l_has_parent = 'CH' and l_user_id != i_user_id) then
        o_success := 'C';
        pl_log.ins_msg('F','chk_lot_status','That Batch Number HAS a PARENT BATCH.',null,null);
     end if;

  end if;
  close c_chk_lot_status;
end;
/*======================================================================================================*/
procedure ins_dummy_parent (i_job_code in job_code.jbcd_job_code%TYPE,
                            i_user_id in arch_batch.user_id%TYPE,
                            i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                            i_start_time in arch_batch.actl_start_time%TYPE,
                            o_dummy_parent out arch_batch.batch_no%TYPE) is
/*=========================================================================================
Return Values:
   o_dummy_parent: Batch Number of the dummy parent batch created for the lot batch.
===========================================================================================*/
begin
  select  'R'|| to_char(seq1.nextval) into o_dummy_parent from dual;
  insert into batch
    (batch_no, parent_batch_no, jbcd_job_code,
     batch_date,status, user_id, user_supervsr_id,
     actl_start_time, damage, parent_batch_date,ref_no)
  VALUES
    (o_dummy_parent, o_dummy_parent, i_job_code,
     trunc(sysdate),'A',i_user_id,i_user_supervsr_id,
     i_start_time, 0 , trunc(sysdate),'PARENT BATCH');
  if sql%notfound then
     raise_application_error(-20104,'Unable to insert into batch table with dummy parent.');
  end if;
end;
/*======================================================================================================*/
procedure get_lot_prev_batch (i_user_id in arch_batch.user_id%TYPE,
                          i_batch_no in arch_batch.batch_no%TYPE,
                          i_jbcd_job_code in arch_batch.jbcd_job_code%TYPE,
                          o_prev_batch_no out arch_batch.batch_no%TYPE,
                          o_prev_batch_date out arch_batch.batch_date%TYPE,
                          o_prev_start_time out arch_batch.actl_start_time%TYPE,
                          o_do_merge out char,
                          o_prev_exist out char,
                          o_prev_forklift out char,
                          o_prev_status out  arch_batch.status%TYPE) is
l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
l_job_code job_code.jbcd_job_code%TYPE;
l_prev_status arch_batch.status%TYPE;
l_prev_batch_no arch_batch.batch_no%TYPE;
 cursor c_lot_prev_cur is
    select batch_no,batch_date,actl_start_time,status,lfun_lbr_func,jbcd_job_code
    from batch_monitor_view
    where user_id = i_user_id
    and status = 'A';
 cursor c_chk_other_lot is
    select batch_no,batch_date,actl_start_time,status,lfun_lbr_func,jbcd_job_code
    from batch_monitor_view
    where user_id = i_user_id
    and   actl_start_time = (select max(actl_start_time)
                          from batch
                          where user_id = i_user_id
                          and   batch_no != i_batch_no
                          and   status = 'C');
begin
  open c_lot_prev_cur;
  fetch c_lot_prev_cur into l_prev_batch_no,o_prev_batch_date,
        o_prev_start_time,l_prev_status,l_lfun_lbr_func,l_job_code;
  if c_lot_prev_cur%NOTFOUND then
     o_prev_forklift := 'N';
     open c_chk_other_lot;
     fetch c_chk_other_lot  into l_prev_batch_no,o_prev_batch_date,
        o_prev_start_time,l_prev_status,l_lfun_lbr_func,l_job_code;
     if c_chk_other_lot%found then
          o_prev_exist := 'Y' ;
          o_do_merge := 'N';
     else
          o_prev_exist := 'N' ;
          o_do_merge := 'N';
     end if;
  else
     if (l_lfun_lbr_func = 'FL' and l_prev_status = 'A') then
           o_prev_forklift := 'Y';
     else
           o_prev_forklift := 'N';
     end if;
     if (substr(l_job_code,4,3) = 'LOT') AND
        (substr(l_prev_batch_no,1,1) = substr(i_jbcd_job_code,2,1))
        then
        o_prev_exist := 'Y';
        o_do_merge := 'Y';
     else
        o_prev_exist := 'Y';
        o_do_merge := 'N';
     end if;
  end if;
  o_prev_status := l_prev_status;
  o_prev_batch_no := l_prev_batch_no;
end;
/*======================================================================================================*/
procedure process_lot_batch(i_user_id in arch_batch.user_id%TYPE,
                         i_user_supervsr_id in arch_batch.user_supervsr_id%TYPE,
                           i_batch_no in arch_batch.batch_no%TYPE,
                           i_ref_no in arch_batch.ref_no%TYPE,
                           i_jbcd_job_code in job_code.jbcd_job_code%TYPE,
                           i_lgrp_lbr_grp in usr.lgrp_lbr_grp%TYPE,
                           i_actl_start_time in arch_batch.actl_start_time%TYPE,
                           i_forklift_point in point_distance.point_a%TYPE) is
l_prev_batch_no arch_batch.batch_no%TYPE;
l_prev_start_time arch_batch.actl_start_time%TYPE;
l_prev_status arch_batch.status%TYPE;
l_prev_batch_date arch_batch.batch_date%TYPE;
l_do_merge varchar2(1);
l_prev_exist varchar2(1);
l_prev_forklift varchar2(1);
l_prev_actl_stop_time arch_batch.actl_stop_time%TYPE;
l_prev_actl_time_spent arch_batch.actl_time_spent%TYPE;
l_new_dummy_parent arch_batch.batch_no%TYPE;
l_actl_start_time arch_batch.actl_start_time%TYPE;
l_istart_exist char;
l_istart_created char;
l_istart_stop_time arch_batch.actl_stop_time%TYPE;
l_batch_no arch_batch.batch_no%TYPE;
l_lot_re_attach char;
l_success char;
begin
  chk_lot_status(i_user_id,i_batch_no,l_success);
  if l_success = 'Y' then
     get_lot_prev_batch(i_user_id,i_batch_no, i_jbcd_job_code,l_prev_batch_no,
                  l_prev_batch_date,l_prev_start_time,l_do_merge,
                  l_prev_exist,l_prev_forklift,l_prev_status);
     if l_prev_forklift = 'Y' then
        l_do_merge := 'N';
     end if;
     if l_prev_exist = 'Y' then
        pl_task_assign.create_istart(i_user_id,i_lgrp_lbr_grp,i_user_supervsr_id);
        if l_do_merge = 'Y' then

            pl_task_merge.process_merge_batch(l_prev_batch_no,i_batch_no,i_user_id,l_success);
            /* This is to update the system time fot LOT Merge batch instead of
               master batch sign on time */
            pl_task_assign.upd_curr_batch('M',sysdate,sysdate,i_batch_no,i_user_id,i_user_supervsr_id,null,null);
        else
           if (l_prev_forklift != 'Y') and (l_prev_status != 'C') then
               l_prev_actl_stop_time := i_actl_start_time;
               l_prev_actl_time_spent :=  to_number((l_prev_actl_stop_time - l_prev_start_time) * 1440);
               pl_lm1.create_schedule(l_prev_batch_no,l_prev_batch_date,
                                  l_prev_actl_stop_time,l_prev_actl_time_spent);
               if substr(l_prev_batch_no,1,1) = 'S' then
                  pl_task_assign.calc_parent_total(l_prev_batch_no);
               else
                  pl_task_merge.calc_parent_total_non_S(l_prev_batch_no);
               end if;
           end if;
           ins_dummy_parent(i_jbcd_job_code,i_user_id,i_user_supervsr_id,i_actl_start_time,l_new_dummy_parent);

           pl_task_merge.process_merge_batch(l_new_dummy_parent,i_batch_no,i_user_id,l_success);
        end if;

     else
         pl_task_assign.check_for_istart(i_user_id,l_istart_exist);
         if l_istart_exist = 'N' then
             pl_task_assign.ins_istart('N',i_user_id,i_user_supervsr_id,i_lgrp_lbr_grp,
                         null,l_istart_created,l_istart_stop_time,l_batch_no);
            l_actl_start_time := l_istart_stop_time;
         else
            l_actl_start_time := sysdate;
         end if;
        ins_dummy_parent(i_jbcd_job_code,i_user_id,i_user_supervsr_id,l_actl_start_time,l_new_dummy_parent);
        pl_task_merge.process_merge_batch(l_new_dummy_parent,i_batch_no,i_user_id,l_success);
     end if;
  end if;
end;

/*======================================================================================================*/
procedure process_batch(i_user_id in arch_batch.user_id%TYPE,
                        io_batch_no in out arch_batch.batch_no%TYPE,
                        i_forklift_point in point_distance.point_a%TYPE,
                        i_ref_no arch_batch.ref_no%TYPE,
                        o_iwash_batch_no out arch_batch.batch_no%TYPE,
                        o_istop_batch_no out arch_batch.batch_no%TYPE,
                        o_lot_batch_yn out varchar,
                        o_success out varchar) is
/*-----------------------------------------------------------------------------
Return Values:
      io_batch_no      : Batch no creted for other indirect jobs or valid batch nos.
      o_iwash_batch_no : Batch no of the IWASH batch created for the user.
                         Has data only if batch_no entered is ISTOP. 
                         NO_DATA if no batch no is created.
      o_istop_batch_no : Batch no of the istop batch created for the user.
                         Has data only if batch_no entered is ISTOP. 
                         NO_DATA if no batch no is created.
      o_lot_batch_yn   : If LOT batch Y
                         else         N
      o_success        : If ISTART - N - Istart already exists
                                     E - Error
                                     D - Duration Exists
                                     Y - Success
                         If ISTOP -  N - No valid batch exists
                                     D - Batch Exists. But No direct active or complete batch.
                                     Y - Success.
                         Others   -  N - Not success
                                     E - error
                                     Y - Success
-----------------------------------------------------------------------------*/
l_batch_no arch_batch.batch_no%TYPE;
l_istart_exist char;
l_user_supervsr_id usr.suprvsr_user_id%TYPE;
l_lgrp_lbr_grp usr.lgrp_lbr_grp%TYPE;
l_istart_created char;
l_istart_time arch_batch.actl_start_time%TYPE;
l_actl_start_time arch_batch.actl_start_time%TYPE;
l_lfun_lbr_func job_code.lfun_lbr_func%TYPE;
l_jbcd_job_code job_code.jbcd_job_code%TYPE;
indirect_success_bln boolean;
l_auth_job char;
 error_prob     varchar2(200) := SQLERRM; 
begin
   o_iwash_batch_no := 'NO_DATA';
   o_istop_batch_no := 'NO_DATA'; 
   o_lot_batch_yn := 'N';
   pl_log.g_application_func := 'LABOR';
   pl_log.g_program_name := 'pl_task_regular.sql';

   pl_task_assign.add_prefix_S(io_batch_no);
   pl_task_assign.validate_userid(i_user_id,l_user_supervsr_id,l_lgrp_lbr_grp);
   if io_batch_no = 'ISTART' then

        pl_task_assign.check_for_istart(i_user_id,l_istart_exist);

        if l_istart_exist = 'N' then
            pl_task_assign.ins_istart('Y',i_user_id,l_user_supervsr_id,l_lgrp_lbr_grp,i_ref_no,
                          l_istart_created,l_istart_time,io_batch_no);
            if l_istart_created = 'D' then
               o_success := 'D';
            elsif l_istart_created = 'E' then
               o_success := 'E';
            else
               o_success := 'Y';
            end if;

        elsif l_istart_exist = 'Y' then
            o_success := 'N';
        elsif l_istart_exist = 'E' then
            o_success := 'E';
        end if;
    elsif io_batch_no = 'ISTOP' then
        check_istop(i_user_id,i_forklift_point,i_ref_no,o_iwash_batch_no,
                       o_istop_batch_no,o_success);
             
    else
        pl_task_assign.add_indirect_entry(io_batch_no,i_ref_no,indirect_success_bln);
        if indirect_success_bln = TRUE then
          o_success := 'Y';
          begin
            select nvl(actl_start_time,sysdate),lfun_lbr_func,jbcd_job_code
            into l_actl_start_time,l_lfun_lbr_func,l_jbcd_job_code
            from batch_monitor_view
            where batch_no = io_batch_no;
            if substr(l_jbcd_job_code,4,3) = 'LOT' then
                o_lot_batch_yn := 'Y';
                 process_lot_batch(i_user_id,l_user_supervsr_id,io_batch_no,i_ref_no,
                              l_jbcd_job_code,l_lgrp_lbr_grp,l_actl_start_time,i_forklift_point);
            else
                 process_valid_batch(i_user_id,l_user_supervsr_id,io_batch_no,i_ref_no,l_lfun_lbr_func,
                            l_lgrp_lbr_grp,l_actl_start_time,i_forklift_point);
            end if;
            exception
              when no_data_found then
		-- D#11601 Checked PO<batch-no> also
		io_batch_no := REPLACE(io_batch_no, 'S', 'PO');
		begin
		  select nvl(actl_start_time,sysdate),lfun_lbr_func,
			jbcd_job_code
		  into l_actl_start_time,l_lfun_lbr_func,l_jbcd_job_code
		  from batch_monitor_view
		  where batch_no = io_batch_no;

		  if substr(l_jbcd_job_code,4,3) = 'LOT' then
		    o_lot_batch_yn := 'Y';
		    process_lot_batch(i_user_id,l_user_supervsr_id,io_batch_no,
			i_ref_no,l_jbcd_job_code,l_lgrp_lbr_grp,
			l_actl_start_time,i_forklift_point);
		  else
		    process_valid_batch(i_user_id,l_user_supervsr_id,
			io_batch_no,i_ref_no,l_lfun_lbr_func,
			l_lgrp_lbr_grp,l_actl_start_time,i_forklift_point);
		  end if;
		exception
		  when no_data_found then
		    o_success := 'E';
		end;
         end;
       else
         o_success := 'N';
     end if;
  end if;
  exception
      when others then
         o_success := 'E';
         error_prob := SQLERRM;                                      
         rollback;                                                     
         pl_log.ins_msg('F','process_batch',
           'Batch_no is '||io_batch_no  || '  User Id: ' ||i_user_id,null,null);
         pl_log.ins_msg('F','process_batch',error_prob,null,null);
         commit;
         raise_application_error(-20104,'When Other failed: '|| error_prob);
end process_batch;

/* ========================================================================== */
END pl_task_regular;
/

