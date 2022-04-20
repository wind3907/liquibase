rem *****************************************************
rem @(#) src/schema/triggers/trg_upd_sel_method_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.4

rem @(#) File : trg_upd_sel_method_arow
rem @(#) Usage: sqlplus USR/PWD trg_upd_sel_method_arow.sql
rem Description:
rem ---  Maintenance history  ---
rem 03-APR-2002 prppxx Initial version Trace SSl change 
rem                    with SWMS audit function.
rem 05-JUN-2002 prppxx Make it standard for build into 
rem                    schemas dir.
rem 25-Oct-2004 prppxx Populate screen name in audit trail(D#11790).

rem *****************************************************
create or replace trigger swms.trg_upd_sel_method_arow
 after update on swms.sel_method for each row

 declare
 l_msg_old     varchar2(2000);
 l_msg_new     varchar2(2000);
 --

begin
  pl_audit.g_application_func := 'O';
  pl_audit.g_program_name := 'trg_upd_sel_method_arow';
  pl_audit.g_screen_type := 'OC1SC';

  IF (:old.label_queue != :new.label_queue) OR 
     (:old.report_queue != :new.report_queue) OR
     (:old.equip_id != :new.equip_id) THEN

    l_msg_old := l_msg_old || 
      'Old value: ' || 'method_id,' || 'group,' || 'equip_id,' || 'label q,'||
      'rep q:' || :old.method_id || ',' || to_char(:old.group_no) || ',' ||
      :old.equip_id || ',' || :old.label_queue || ',' || :old.report_queue;
     
    l_msg_new := 
      'New value: ' || 'method_id,' || 'group,' || 'equip_id,' || 'label q,'||
      'rep q:' || :new.method_id || ',' || to_char(:new.group_no) || ',' || 
      :new.equip_id || ',' || :new.label_queue || ',' || :new.report_queue;

    pl_audit.ins_trail(l_msg_old, l_msg_new);
  END IF;
end trg_upd_sel_method_arow;
/

