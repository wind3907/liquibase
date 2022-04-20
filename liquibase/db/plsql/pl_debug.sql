rem *****************************************************
rem @(#) src/schema/plsql/pl_debug.sql, swms, swms.9, 10.1.1 9/7/06 1.3

rem @(#) File : create_proc_debug.sql

rem ---  Maintenance history  ---
rem 22-MAY-2000 prpksn Initial version

rem *****************************************************

/* This is the SPECIFICATION FOR THE PACKAGE */
create or replace PACKAGE swms.Debug AS
  /* This package works by inserting into process_error table.
     In order to see the output, select from process_error in 
     sqlplus with: select error_msg from process_error where
     user_id = USER and process_id=<PROGRAM_FUNCTION> 
     order by value_1 or process_date */

     /* This is the main debug procedure. i_description will be
     concatenated with i_value and inserted into process_error */

     PROCEDURE Debug (i_process_id in varchar2, 
		      i_userenv_id in varchar2,
		      i_description in varchar2, 
		      i_value in varchar2);

     PROCEDURE Reset;
END Debug;
/
CREATE or REPLACE PACKAGE BODY swms.Debug as
  /* T_linecount is used to order the rows in process_error */
  t_linecount  number;

  PROCEDURE Debug (i_process_id in varchar2,
		   i_userenv_id in varchar2,
		   i_description in varchar2, 
		   i_value in varchar2) IS
  begin
    insert into process_error 
    (process_id, user_id, process_date, userenv_id,value_1,
     error_msg)
    values
    (i_process_id,USER,sysdate,i_userenv_id, to_char(t_linecount),
     i_description || ' : ' || i_value);
    commit;
     t_linecount := t_linecount + 1;

  end Debug;

  PROCEDURE reset is
  begin
    t_linecount := 1;
    Delete from process_error where user_id=USER;
  END Reset;

BEGIN
  reset;
END Debug;
/
