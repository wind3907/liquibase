rem *****************************************************
rem @(#) src/schema/triggers/trg_upd_sel_equip_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.4

rem @(#) File : trg_upd_sel_equip_arow
rem @(#) Usage: sqlplus USR/PWD trg_upd_sel_equip_arow.sql
rem Description:
rem ---  Maintenance history  ---
rem 03-APR-2002 prppxx Initial version Trace SSl change
rem                    with SWMS audit function.
rem 05-JUN-2002 prppxx Make it standard for build into
rem                    schemas dir.
rem 10-Oct-2004 prppxx Populate screen name in audit trail (D#11790).

rem *****************************************************
create or replace trigger swms.trg_upd_sel_equip_arow
 after update on swms.sel_equip for each row

 declare
 l_msg_old     varchar2(2000);
 l_msg_new     varchar2(2000);
 --

begin
  pl_audit.g_application_func := 'O';
  pl_audit.g_program_name := 'trg_upd_sel_method_arow';
  pl_audit.g_screen_type := 'OC1SB';

  IF ((:old.high_cube != :new.high_cube) OR 
      (:old.min_cube_unitize != :new.min_cube_unitize)) THEN 

    l_msg_old := 
        'Old value: ' || 'equip_id:' || :old.equip_id || ',' ||
        'high_cube:' || to_char(:old.high_cube) || ',' || 
	'min_cube_unitize:' || to_char(:old.min_cube_unitize);
     
    l_msg_new := 
        'New value: ' || 'equip_id:' || :new.equip_id || ',' ||
        'high_cube:' || to_char(:new.high_cube) || ',' ||
	'min_cube_unitize:' || to_char(:new.min_cube_unitize);

    pl_audit.ins_trail(l_msg_old, l_msg_new);
  END IF;
end trg_upd_sel_equip_arow;
/

