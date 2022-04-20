rem *****************************************************
rem @(#) src/schema/triggers/trg_insdel_ssl_master_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.3

rem @(#) File : trg_insdel_ssl_master_arow
rem @(#) Usage: sqlplus USR/PWD trg_insdel_ssl_master_arow.sql
rem Description:
rem ---  Maintenance history  ---
rem 03-APR-2002 prppxx Initial version Trace SSl change
rem                    with SWMS audit function.
rem 05-JUN-2002 prppxx Make it standard for build into
rem                    schemas dir.

rem *****************************************************
create or replace trigger swms.trg_insdel_ssl_master_arow
 after insert or delete on swms.sel_method_master for each row

 declare
 l_msg_old     varchar2(2000);
 l_msg_new     varchar2(2000);
 --

begin
  pl_audit.g_application_func := 'O';
  pl_audit.g_program_name := 'trg_insdel_ssl_master_arow';

  IF INSERTING THEN
     l_msg_old := null;
     l_msg_new := 'Insert SSL master, ' || 'method_id:' || :new.method_id;
  ELSIF DELETING THEN
     l_msg_old := 'Delete SSL master, ';
     l_msg_old := l_msg_old ||  'method_id:' || :old.method_id;
     l_msg_new := null;
  END IF;

  pl_audit.ins_trail(l_msg_old, l_msg_new);
end trg_insdel_ssl_master_arow;
/

