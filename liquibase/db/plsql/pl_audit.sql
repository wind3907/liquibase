rem @(#) src/schema/plsql/pl_audit.sql, swms, swms.9, 10.1.1 9/7/06 1.3
rem @(#) File : pl_audit.sql
rem @(#) Usage: sqlplus USR/PWD pl_audit.sql

rem ---  Maintenance history  ---
rem 04-FEB-2002 prppxx Initial version
rem 
rem This package procedure will insert into table swms_audit for the user 
rem to track of swms database change using the maintenance form.
rem Columns:
rem  audit_seq_no => sequence swms_audit_seq will generate the number
rem  user_id	=> user id without OPS$ 
rem  user_session => userenv('sessionid') session id
rem  add_date	=> system date
rem  application_func => R=RECEIVING,O=ORDER PROCESS,M=MAINTENANCE,
rem			 L=LABOR,I=INVENTORY,D=DRIVER CHECK-IN
rem  program_name => the program name
rem  old_val_txt	=> message line show the old value  
rem  new_val_txt	=> message line show the new value  
rem 
rem 07-MAY-2003 acpppp Changes made to log screen type also.
rem  screen_type => P=PALLET TYPE
create or replace PACKAGE swms.pl_audit as
  PROCEDURE ins_trail (i_old_val_txt          in swms_audit.old_val_txt%TYPE,
                       i_new_val_txt          in swms_audit.new_val_txt%TYPE);

  /* These three global variables below need to defined one time in the calling 
     program 
  */
  g_application_func  swms_audit.application_func%TYPE := 'UNDEFINE';
  g_program_name      swms_audit.program_name%TYPE := 'UNDEFINE';
  g_screen_type       swms_audit.screen_type%TYPE := 'UNDEFINE';

end pl_audit;
/

create or replace PACKAGE BODY swms.pl_audit AS
 /* *********************************************************************** */
  PROCEDURE ins_trail (i_old_val_txt          in swms_audit.old_val_txt%TYPE,
		       i_new_val_txt          in swms_audit.new_val_txt%TYPE) is

begin
     insert into swms_audit
       (audit_seq_no,user_id,user_session,add_date,application_func,
        program_name, old_val_txt,new_val_txt,screen_type)
     select swms_audit_seq.nextval,replace(USER,'OPS$',null),userenv('SESSIONID'),
       sysdate,decode(substr(upper(pl_audit.g_application_func),1,1),'R',
		      'RECEIVING','O',
		      'ORDER PROCESS','M',
		      'MAINTENANCE','I',
		      'INVENTORY','D',
		      'DRIVER CHECKIN','L',
		      'LABOR MGT',
		      nvl(upper(pl_audit.g_application_func),'UNKNOWN')),
       upper(g_program_name), upper(i_old_val_txt), upper(i_new_val_txt),
       decode(substr(upper(pl_audit.g_screen_type),1,1),'P',
                     'PALLET TYPE',
                     nvl(upper(pl_audit.g_screen_type),'UNKNOWN'))
     from dual
     where rownum=1;
end ins_trail;

end pl_audit;
/
