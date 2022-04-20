rem *****************************************************
rem @(#) src/schema/plsql/pl_lm1.sql, swms, swms.9, 10.1.1 9/7/06 1.4

rem @(#) File : pl_lm1.sql
rem @(#) Usage: sqlplus USR/PWD pl_lm1.sql 

rem ---  Maintenance history  ---
rem 14-FEB-2000 prpksn Initial version
rem 11-JUL-2001 prpbcb DN 10599  Ticket: 262080  Changed
rem                select max(actl_start_time)
rem             to
rem                select NVL(max(actl_start_time), SYSDATE)
rem             when selecting the ISTART for the user.  There was an
rem             exception for no data found to use the sysdate but this
rem             will never be executed because a row will always be returned
rem             when using the max function.  Not having a value for the
rem             date caused the create_schedule procedure to fail.
rem             Changed char variables to varchar2.
rem             Changed where clause in cursor get_batch_info from
rem                where batch_no = i_batch_no
rem                  and status in ('C','A');
rem             to
rem                where batch_no = i_batch_no
rem                  and status||'' in ('C','A');
rem             so the index on the batch number is used and not the index
rem             on the status.
rem 28-AUG-2001 prpbcb DN 10640  Ticket: 269386 (rs239b DN 10641)
rem             Commented out the commit after the insert into process_error
rem             table in the WHEN OTHERS exception handler.  The commit could
rem             cause forklift labor mgmt batches to have status of 'N' which
rem             in turn causes other problems.  With the commit commented
rem             out the process error records could get rolled back
rem             depending on what the calling program does.  The forklift
rem             program rolls them back.
rem
rem 18-OCT-2001 prpksn DN       Ticket:277101,222666
rem 	        Add in the procedure upd_prev_arch_batch and cursor get_arch_batch_info
rem		to handle both situation for historical and current. This fix is for
rem		ins_indirect.fmt form and ins_indirect_hist.fmt.
rem		Also, process_error table will not be use any more but the program will
rem		use swms_log table instead.
rem		Another situation is that when updating historical, you have a chance 
rem		of updating a wrong batch no since batch date and batch no is the primary key.
rem		To fix that, we will have 2 create_schedule procedures with diff parameter.
rem 02-NOV-2005 prpakp DN 12026 Ticket:78136
rem             Changed the upd_prev_batch and upd_arch_prev_batch procedure to call
rem             pl_task_assign.process_ins_float_hist procedure to insert order history to
rem             float_hist table when the previous batch is a selection batch. This was not done
rem             causing no order history for those selection batches followed by forklift or 
rem             receiving batches.
rem 24-JUL-2019 SWMSP:854 - LM batch UPD failed error when the start time is NULL in IFKLT batch.
rem *****************************************************

/* This is the SPECIFICATION FOR THE PACKAGE */
create or replace PACKAGE swms.pl_lm1 as
  PROCEDURE create_schedule(i_batch_no   in arch_batch.batch_no%TYPE,
			    i_batch_date in arch_batch.batch_date%TYPE,
		            i_stop_time  in date,
			    p_time_spend in out arch_batch.actl_time_spent%TYPE);

  PROCEDURE create_schedule(i_batch_no   in arch_batch.batch_no%TYPE,
		            i_stop_time  in date,
			    p_time_spend in out arch_batch.actl_time_spent%TYPE);

  PROCEDURE upd_prev_arch_batch (i_batch_no in arch_batch.batch_no%TYPE,
				 i_batch_date in arch_batch.batch_date%TYPE,
                                 i_status in arch_batch.status%TYPE,
                                 i_actl_stop_time in date,
                                 i_no_breaks in arch_batch.no_breaks%TYPE,
                                 i_no_lunches in arch_batch.no_lunches%TYPE,
                                 i_actl_time_spent in arch_batch.actl_time_spent%TYPE,
                                 i_user_id in arch_batch.user_id%TYPE) ;

  PROCEDURE upd_prev_batch (i_batch_no in arch_batch.batch_no%TYPE,
			    i_batch_date in arch_batch.batch_date%TYPE,
                            i_status in arch_batch.status%TYPE,
                            i_actl_stop_time in date,
                            i_no_breaks in arch_batch.no_breaks%TYPE,
                            i_no_lunches in arch_batch.no_lunches%TYPE,
                            i_actl_time_spent in arch_batch.actl_time_spent%TYPE,
                            i_user_id in arch_batch.user_id%TYPE);
end pl_lm1;
/
/* ************************************************************************** */


/* PACKAGE BODY FOR PROCEDURES AND FUNCTION */
create or replace PACKAGE body swms.pl_lm1 as

/* ========================================================================== */
  PROCEDURE upd_prev_arch_batch (i_batch_no in arch_batch.batch_no%TYPE,
				 i_batch_date in arch_batch.batch_date%TYPE,
                                 i_status in arch_batch.status%TYPE,
                                 i_actl_stop_time in date,
                                 i_no_breaks in arch_batch.no_breaks%TYPE,
                                 i_no_lunches in arch_batch.no_lunches%TYPE,
                                 i_actl_time_spent in arch_batch.actl_time_spent%TYPE,
                                 i_user_id in arch_batch.user_id%TYPE)  is
  begin
       update arch_batch
         set status = i_status,
             actl_stop_time = i_actl_stop_time,
             no_breaks = nvl(i_no_breaks,no_breaks),
             no_lunches = nvl(i_no_lunches,no_lunches),
             actl_time_spent = nvl(i_actl_time_spent,actl_time_spent)
       where batch_no = i_batch_no
       and   trunc(batch_date) = trunc(i_batch_date);
      if sql%notfound then
         raise_application_error(-20103,'Unable to update due to Invalid arch batch _ ' || i_batch_no);
      else
         if substr(i_batch_no,1,1) = 'S' then
             pl_task_assign.process_ins_float_hist(i_batch_no,i_user_id);
         end if;
      end if;
 end upd_prev_arch_batch;
/* ========================================================================== */

/* ========================================================================== */
  PROCEDURE upd_prev_batch (i_batch_no in arch_batch.batch_no%TYPE,
			    i_batch_date in arch_batch.batch_date%TYPE,
                            i_status in arch_batch.status%TYPE,
                            i_actl_stop_time in date,
                            i_no_breaks in arch_batch.no_breaks%TYPE,
                            i_no_lunches in arch_batch.no_lunches%TYPE,
                            i_actl_time_spent in arch_batch.actl_time_spent%TYPE,
                            i_user_id in arch_batch.user_id%TYPE)  is
  begin
       update batch
         set status = i_status,
             actl_stop_time = i_actl_stop_time,
             no_breaks = nvl(i_no_breaks,no_breaks),
             no_lunches = nvl(i_no_lunches,no_lunches),
             actl_time_spent = nvl(i_actl_time_spent,actl_time_spent)
       where batch_no = i_batch_no
       and   trunc(batch_date) = trunc(i_batch_date);
      if sql%notfound then
         raise_application_error(-20103,'Unable to update due to Invalid batch _ ' || i_batch_no);
      else
         if substr(i_batch_no,1,1) = 'S' then
             pl_task_assign.process_ins_float_hist(i_batch_no,i_user_id);
         end if;
      end if;
 end upd_prev_batch;
/* ========================================================================== */

/* ========================================================================== */
PROCEDURE chk_force_lunch_brk (o_force_lunch_brk out varchar2) IS
  cursor get_sys_config is
   select config_flag_val
   from sys_config
   where config_flag_name = 'FORCE_LUNCH_BRK';   

BEGIN
  open get_sys_config;
  fetch get_sys_config into o_force_lunch_brk;
  if get_sys_config%notfound then
    o_force_lunch_brk := 'N';
  end if;
END chk_force_lunch_brk;
/* ========================================================================== */

/* ========================================================================== */
PROCEDURE create_schedule(i_batch_no   in arch_batch.batch_no%TYPE,
		          i_stop_time  in date,
			  p_time_spend in out arch_batch.actl_time_spent%TYPE) IS
  l_time_spend  arch_batch.actl_time_spent%TYPE;
  l_batch_date  arch_batch.batch_date%TYPE;
BEGIN
  /* This is from the current batch calling program that did not have batch date */
  select batch_date into l_batch_date
  from batch
  where batch_no = i_batch_no
  and   rownum = 1;

  create_schedule(i_batch_no,l_batch_date,i_stop_time,p_time_spend);

  exception 
   when no_data_found then
       raise_application_error(-20113,'Unable to to find batch number');
END create_schedule;
/* ========================================================================== */
  
/* ========================================================================== */
  PROCEDURE create_schedule(i_batch_no   in arch_batch.batch_no%TYPE,
			    i_batch_date in arch_batch.batch_date%TYPE,
		            i_stop_time  in date,
			    p_time_spend in out arch_batch.actl_time_spent%TYPE) IS 
/* This procedure is to return the total breaks, total lunches */
/* and the number of time that break has been spend with the period */
/* of start and stop time */
begin
 declare
  t_job_class   job_code.jbcl_job_class%type;
  t_job_code    job_code.jbcd_job_code%type;
  t_sched_type  sched_type.sctp_sched_type%type;
  t_brk1_start  sched_type.brk_1_start_time%type;
  t_brk2_start  sched_type.brk_2_start_time%type;
  t_brk3_start  sched_type.brk_3_start_time%type;
  t_brk4_start  sched_type.brk_4_start_time%type;
  t_lunch_start  sched_type.lunch_start_time%type;
  t_brk1_stop   sched_type.brk_1_start_time%type;
  t_brk2_stop   sched_type.brk_2_start_time%type;
  t_brk3_stop   sched_type.brk_3_start_time%type;
  t_brk4_stop   sched_type.brk_4_start_time%type;
  t_lunch_stop   sched_type.lunch_start_time%type;
  t_brk1_dur    sched_type.brk_1_dur%type;
  t_brk2_dur    sched_type.brk_2_dur%type;
  t_brk3_dur    sched_type.brk_3_dur%type;
  t_brk4_dur    sched_type.brk_4_dur%type;
  t_lunch_dur    sched_type.lunch_dur%type;
  t_lunch_conv   varchar2(20);
  t_brk1_conv     varchar2(20);
  t_brk2_conv     varchar2(20);
  t_brk3_conv     varchar2(20);
  t_brk4_conv     varchar2(20);
  t_lgrp_lbr_grp  lbr_grp.lgrp_lbr_grp%type;
  t_user_id       arch_batch.user_id%TYPE;
  p_total_break   arch_batch.no_breaks%type;
  p_total_lunch   arch_batch.no_lunches%type;
  p_start_time    arch_batch.actl_start_time%TYPE;
  p_stop_time     arch_batch.actl_stop_time%TYPE;
  p_brk_spend     number;
  char_start_time  varchar2(20);
  t_force_lunch_brk_flag varchar2(1) := 'N';
  dt_start_time   date;
  user_istart_time date;
  debug_on      boolean := FALSE;
  NO_DATA_SELECT  exception;
  error_prob     varchar2(200) := SQLERRM;
  l_historical_flag  varchar2(1) := 'N';
  l_procedure_name   varchar2(40);
  --

  cursor get_batch_info is
  select user_id,lgrp_lbr_grp,actl_start_time,jbcl_job_class,
	 actl_stop_time,report_date
  from batch_monitor_view
  where batch_no = i_batch_no
    and status||'' in ('C','A');
  --
  cursor get_arch_batch_info is
  select user_id,lgrp_lbr_grp,actl_start_time,jbcl_job_class,
	 actl_stop_time,report_date
  from v_warehouse
  where batch_no = i_batch_no
  and   trunc(batch_date) = trunc(i_batch_date)
  and status = 'C';

  bmv_rec  get_batch_info%ROWTYPE;
  --
  cursor get_sched is
  select sched_type
  from sched
  where sched_actv_flag = 'Y'
  and sched_lgrp_lbr_grp = t_lgrp_lbr_grp
  and sched_jbcl_job_class = t_job_class;
  --
  cursor get_sched_type is
  select decode(brk_1_start_time,null,null,
     to_char(user_istart_time,'DD-MON-rr') || ' ' ||
       to_char(brk_1_start_time,'HH24:MI')),
   decode(brk_2_start_time,null,null,
       to_char(user_istart_time,'DD-MON-rr') || ' ' ||
       to_char(brk_2_start_time,'HH24:MI')),
   decode(brk_3_start_time,null,null,
   to_char(user_istart_time,'DD-MON-rr') || ' ' ||
       to_char(brk_3_start_time,'HH24:MI')),
   decode(brk_4_start_time,null,null,
   to_char(user_istart_time,'DD-MON-rr') || ' ' ||
       to_char(brk_4_start_time,'HH24:MI')),
   decode(lunch_start_time,null,null,
       to_char(user_istart_time,'DD-MON-rr') || ' ' ||
       to_char(lunch_start_time,'HH24:MI')),
   nvl(brk_1_dur,0),nvl(brk_2_dur,0),
   nvl(brk_3_dur,0),nvl(brk_4_dur,0),nvl(lunch_dur,0),
   decode(start_time,null,null,
       to_char(user_istart_time,'DD-MON-rr') || ' ' ||
           to_char(start_time,'HH24:MI'))
  from sched_type
  where sctp_sched_type = t_sched_type;
begin
  /* setup global variable for inserting swms debug messages */
  pl_log.g_application_func := 'LABOR';
  pl_log.g_program_name := 'pl_lm1.sql';
  l_procedure_name := 'create_schedule';

  open get_batch_info;
  fetch get_batch_info into bmv_rec;
  if get_batch_info%NOTFOUND then
    /* Check to see if it is in the historical table */
     open get_arch_batch_info;
     fetch get_arch_batch_info into bmv_rec;
     if get_arch_batch_info%NOTFOUND then
        raise_application_error(-20100,'Batch cannot be found with ' ||
                                'status Active or Complete.');
        raise NO_DATA_SELECT;
     end if;
     l_historical_flag := 'Y';
     close get_arch_batch_info;
  else
     l_historical_flag := 'N';
  end if;
  close get_batch_info;
  t_lgrp_lbr_grp := bmv_rec.lgrp_lbr_grp;
  t_job_class    := bmv_rec.jbcl_job_class;
  p_start_time   := bmv_rec.actl_start_time;
  t_user_id      := bmv_rec.user_id;
  p_stop_time  := i_stop_time;
  if p_stop_time is null then
     p_stop_time := nvl(bmv_rec.actl_stop_time,sysdate);
  end if;
  if p_start_time is null then
     p_start_time := sysdate;   
  end if; --SWMSP:854 - LM batch UPD failed error when the start time is NULL in IFKLT batch.
  p_time_spend := to_number((p_stop_time - p_start_time) * 1440);
  p_total_break := 0;
  p_total_lunch := 0;
  p_brk_spend := 0;

  chk_force_lunch_brk(t_force_lunch_brk_flag);
  --
  if l_historical_flag = 'N' then 
    begin
      select NVL(max(actl_start_time), SYSDATE) into user_istart_time
      from batch
      where jbcd_job_code = 'ISTART'
      and   user_id = bmv_rec.user_id;
    end;
  else
    begin
      select NVL(max(actl_start_time), SYSDATE) into user_istart_time
      from arch_batch
      where jbcd_job_code = 'ISTART'
      and   user_id = bmv_rec.user_id
      and   trunc(report_date) = trunc(bmv_rec.report_date);
    end;
end if;
  --

  open get_sched;
  fetch get_sched into t_sched_type;
  if get_sched%notfound then
     raise_application_error(-20101, 'There is not a valid ACTIVE '||
       'SCHEDULE set up for this user/job code.');
     raise NO_DATA_SELECT;
  end if;
  close get_sched;
  --
  open get_sched_type;
  fetch get_sched_type into t_brk1_conv, t_brk2_conv,t_brk3_conv,
    t_brk4_conv,t_lunch_conv,
    t_brk1_dur,t_brk2_dur,t_brk3_dur,t_brk4_dur,t_lunch_dur,
    char_start_time;
  if get_sched_type%notfound then
     raise_application_error(-20102,
      'Unable to fetch  break or lunch in sched_type.');
     raise NO_DATA_SELECT;
  end if;
  dt_start_time := to_date(char_start_time,'DD-MON-RR HH24:MI');
  if t_lunch_conv is not null then
     pl_log.ins_msg('D',l_procedure_name,
       'char_start_time is '||char_start_time || '  t-lunch-conv is '|| t_lunch_conv,
       null,null);

     t_lunch_start := to_date(t_lunch_conv,'DD-MON-RR HH24:MI');
     pl_log.ins_msg('D',l_procedure_name,
	't-lunch-start values '||to_char(t_lunch_start,'mm/dd/rrrr hh24:mi'),
	null,null);

     if (((t_lunch_start - dt_start_time) * 1440) < 0) and
        (trunc(sysdate) = trunc(user_istart_time + 1)) then
        t_lunch_start := t_lunch_start + 1;
     end if;

     /* prpksn loader prob */
     pl_log.ins_msg('D',l_procedure_name,
		    't_lunch_start is '||to_char(t_lunch_start,'mm/dd/rr hh24:mi'),
		    null,null);

     pl_log.ins_msg('D',l_procedure_name,
       'trunc sysdate/istart '||
       to_char(trunc(sysdate),'mm/dd/rr hh24:mi') || '  '||
       to_char(trunc(user_istart_time+1 ),'mm/dd/rr HH24:mi') ||
       '  After t_lunch_start is '||to_char(t_lunch_start, 'mm/dd/rr hh24:mi'),
	null,null);

     t_lunch_stop := t_lunch_start + (nvl(t_lunch_dur,0)/1440) ;
  end if;
     /* prpksn loader prob */
     pl_log.ins_msg('D',l_procedure_name,
                    'Between lunch and 1st brk. t_lunch_stop is '||
                     to_char(t_lunch_stop,'mm/dd/rr hh24:mi'),
		     null,null);

  if t_brk1_conv is not null then
     t_brk1_start := to_date(t_brk1_conv,'DD-MON-rr HH24:MI');
     if (((t_brk1_start - dt_start_time) * 1440) < 0) and
        (trunc(sysdate) = trunc(user_istart_time + 1)) then
        t_brk1_start := t_brk1_start + 1;
     end if;
     t_brk1_stop := t_brk1_start + (nvl(t_brk1_dur,0)/1440) ;
  end if;
  if t_brk2_conv is not null then
     t_brk2_start := to_date(t_brk2_conv,'DD-MON-rr HH24:MI');
     if (((t_brk2_start - dt_start_time) * 1440) < 0) and
        (trunc(sysdate) = trunc(user_istart_time + 1)) then
         t_brk2_start := t_brk2_start + 1;
     end if;
     t_brk2_stop := t_brk2_start + (nvl(t_brk2_dur,0)/1440) ;
  end if;
  if t_brk3_conv is not null then
     t_brk3_start := to_date(t_brk3_conv,'DD-MON-rr HH24:MI');
     if (((t_brk3_start - dt_start_time) * 1440) < 0) and
        (trunc(sysdate) = trunc(user_istart_time + 1)) then
        t_brk3_start := t_brk3_start + 1;
     end if;

     pl_log.ins_msg('D',l_procedure_name,
       't_brk3 trunc sysdate/istart '||
       to_char(trunc(sysdate),'mm/dd/rr hh24:mi') || '  '||
       to_char(trunc(user_istart_time+1 ),'mm/dd/rr hh24:mi') ||
       '  After brk3 start is '||to_char(t_brk3_start, 'mm/dd/rr hh24:mi'),
       null,null);

     t_brk3_stop := t_brk3_start + (nvl(t_brk3_dur,0)/1440) ;
  end if;
  if t_brk4_conv is not null then
     t_brk4_start := to_date(t_brk4_conv,'DD-MON-rr HH24:MI');
     if (((t_brk4_start - dt_start_time) * 1440) < 0) and
        (trunc(sysdate) = trunc(user_istart_time + 1)) then
        t_brk4_start := t_brk4_start + 1;
     end if;
     t_brk4_stop := t_brk4_start + (nvl(t_brk4_dur,0)/1440) ;
  end if;

/* Begin giving break and lunch from this point */
/* the elsif statement is to force the lunch in vie syspar flag */

  if (p_start_time <= t_brk1_start) and
      (p_stop_time >= t_brk1_stop) and
      (p_time_spend >= t_brk1_dur)  and t_brk1_start is not null then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk1_dur;
  elsif (t_force_lunch_brk_flag = 'Y' and t_brk1_start is not null) and
      (p_stop_time > t_brk1_start and p_stop_time < t_brk1_stop and
       p_start_time <= t_brk1_start ) then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk1_dur;
  end if;
  if (p_start_time <= t_brk2_start) and
      (p_stop_time >= t_brk2_stop) and
      (p_time_spend > t_brk2_dur) and t_brk2_start is not null then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk2_dur;
  elsif (t_force_lunch_brk_flag = 'Y' and t_brk2_start is not null) and
      (p_stop_time > t_brk2_start and p_stop_time < t_brk2_stop and
       p_start_time <= t_brk2_start ) then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk2_dur;
  end if;
  if (p_start_time <= t_brk3_start) and
      (p_stop_time >= t_brk3_stop) and
      (p_time_spend > t_brk3_dur) and t_brk3_start is not null then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk3_dur;
  elsif (t_force_lunch_brk_flag = 'Y') and (t_brk3_start is not null) and
      (p_stop_time > t_brk3_start and p_stop_time < t_brk3_stop and
       p_start_time <= t_brk3_start ) then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk3_dur;
  end if;
  if (p_start_time <= t_brk4_start) and
      (p_stop_time >= t_brk4_stop) and
      (p_time_spend > t_brk4_dur) and t_brk4_start is not null then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk4_dur;
  elsif (t_force_lunch_brk_flag = 'Y' and t_brk4_start is not null) and
      (p_stop_time > t_brk4_start and p_stop_time < t_brk4_stop and
       p_start_time <= t_brk4_start ) then
    p_total_break := nvl(p_total_break,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_brk4_dur;
  end if;
  if (p_start_time <= t_lunch_start) and
      (p_stop_time >= t_lunch_stop) and
      (p_time_spend > t_lunch_dur) and t_lunch_start is not null then
    p_total_lunch := nvl(p_total_lunch,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_lunch_dur;
  elsif (t_force_lunch_brk_flag = 'Y' and t_lunch_start is not null) and
      (p_stop_time > t_lunch_start and p_stop_time < t_lunch_stop and
       p_start_time <= t_lunch_start ) then
    p_total_lunch := nvl(p_total_lunch,0) + 1;
    p_brk_spend := nvl(p_brk_spend,0) + t_lunch_dur;
  end if;
  /* Start updating the lunch and breaks */
  if p_brk_spend > 0 then
     p_time_spend := p_time_spend - nvl(p_brk_spend,0);
  end if;
  if l_historical_flag = 'N' then
     upd_prev_batch(i_batch_no,
		    i_batch_date,
		    'C',
		    p_stop_time,
		    p_total_break,
		    p_total_lunch,
		    p_time_spend,
                    t_user_id);
  else
     upd_prev_arch_batch(i_batch_no,
		    i_batch_date,
		    'C',
		    p_stop_time,
		    p_total_break,
		    p_total_lunch,
		    p_time_spend,
                    t_user_id);
  end if;
  exception when NO_DATA_SELECT then
     p_total_break := 0;
     p_total_lunch := 0;
     p_brk_spend := 0;
    when OTHERS then
    -- By kiet
     rollback;
       pl_log.ins_msg('F',l_procedure_name,
         'I_batch_no is '||i_batch_no  || '  Stop time: ' || 
	 to_char(i_stop_time,'MM/DD/RR HH24:MI:SS') ||
         '   p_time_spend: ' || to_char(p_time_spend),
	 null,null);
       error_prob := SQLERRM;
       pl_log.ins_msg('F',l_procedure_name,error_prob,null,null);
       -- commit;   08/28/01 prpbcb  Commented out.
     commit;
       raise_application_error(-20104,
          'When Other failed: '|| error_prob);
 end;
end create_schedule;
/* ========================================================================== */

end pl_lm1;
/
