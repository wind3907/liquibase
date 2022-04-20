rem *****************************************************
rem @(#) src/schema/triggers/trg_insdelupd_sel_method_zone_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.4

rem @(#) File : trg_insdelupd_sel_method_zone
rem @(#) Usage: sqlplus USR/PWD trg_insdelupd_sel_method_zone.sql
rem Description:
rem ---  Maintenance history  ---
rem 03-APR-2002 prppxx Initial version Trace SSl change
rem                    with SWMS audit function.
rem 05-JUN-2002 prppxx Make it standard for build into
rem                    schemas dir.
rem 25-Oct-2004 prppxx Populate screen name in audit trail(D#11790).

rem *****************************************************
create or replace trigger swms.trg_insdelupd_sel_method_zone
 after update or insert or delete on swms.sel_method_zone for each row

 declare
 l_msg_old     varchar2(2000);
 l_msg_new     varchar2(2000);
 --

begin
  pl_audit.g_application_func := 'O';
  pl_audit.g_program_name := 'trg_insdelupd_sel_method_zone';
  pl_audit.g_screen_type := 'OC1SC';

  IF UPDATING THEN
     l_msg_old := 'Update sel_method_zone, ';
     l_msg_old := l_msg_old || 'Old value: ' || 'method_id,' || 'group_no,' ||
                  'seq_no,' || 'zone_id:' || :old.method_id || ',' || 
                  to_char(:old.group_no) || ',' || to_char(:old.seq_no) || 
                  ',' || :old.zone_id;
     
     l_msg_new := 'New value: ' || 'method_id,' || 'group_no,' ||
                  'seq_no,' || 'zone_id:' || :new.method_id || ',' ||        
                  to_char(:new.group_no) || ',' || to_char(:new.seq_no) ||
                  ',' || :new.zone_id;
  ELSIF INSERTING THEN
     l_msg_old := 'Insert sel_method_zone, ';
     l_msg_new := 'New value: ' || 'method_id,' || 'group_no,' ||               
                  'seq_no,' || 'zone_id:' || :new.method_id || ',' ||   
                  to_char(:new.group_no) || ',' || to_char(:new.seq_no) ||
                  ',' || :new.zone_id;
  ELSIF DELETING THEN
     l_msg_old := 'Delete sel_method_zone, ';
     l_msg_old := l_msg_old || 'Old value: ' || 'method_id,' || 'group_no,' ||
                  'seq_no,' || 'zone_id:' || :old.method_id || ',' ||
                  to_char(:old.group_no) || ',' || to_char(:old.seq_no) ||
                  ',' || :old.zone_id;
     l_msg_new := null;
  END IF;

  pl_audit.ins_trail(l_msg_old, l_msg_new);
end trg_insdelupd_sel_method_zone;
/

