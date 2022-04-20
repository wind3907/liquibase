rem *****************************************************
rem @(#) src/schema/triggers/trg_upd_pallet_type_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.3

rem @(#) File : trg_upd_pallet_type_arow
rem @(#) Usage: sqlplus USR/PWD trg_upd_pallet_type_arow.sql
rem Description:
rem *****************************************************
create or replace trigger swms.trg_upd_pallet_type_arow
 after update on swms.pallet_type for each row

declare
 l_msg_old     varchar2(4000) := ' ';
 l_msg_new     varchar2(4000) := ' ';
 l_change_flag varchar2(1) := 'N';
 
begin
  pl_audit.g_application_func := 'R';
  pl_audit.g_screen_type := 'P';
  pl_audit.g_program_name := 'trg_upd_pallet_type_arow';
  
  
  
  --Initialise old and new msg variables only if values are changed.
  
  IF ((NVL(:old.ext_case_cube_flag,' ') != NVL(:new.ext_case_cube_flag,' ')) OR 
        (NVL(:old.putaway_use_repl_threshold,' ') != NVL(:new.putaway_use_repl_threshold,' ')) OR
        (NVL(:old.putaway_pp_prompt_for_hst_qty,' ') != NVL(:new.putaway_pp_prompt_for_hst_qty,' ')) OR
        (NVL(:old.putaway_fp_prompt_for_hst_qty,' ') != NVL(:new.putaway_fp_prompt_for_hst_qty,' ')) OR
      (NVL(:old.ndm_repl_prompt_for_hst_qty,' ') != NVL(:new.ndm_repl_prompt_for_hst_qty,' '))) THEN 
      
      
      l_msg_old := 'Old value: ' || 'Pallet Type :' || :old.descrip || ' ';    
      l_msg_new := 'New value: ' || 'Pallet Type :' || :new.descrip || ' ';
      l_change_flag := 'Y';
      
  END IF;    
  
  
  IF (NVL(:old.ext_case_cube_flag,' ') != NVL(:new.ext_case_cube_flag,' ')) THEN
    l_msg_old := l_msg_old || 'Ext_case_cube_flag: ' || :old.ext_case_cube_flag;
    l_msg_new := l_msg_new || 'Ext_case_cube_flag: ' || :new.ext_case_cube_flag;
  END IF;
  
  IF (NVL(:old.putaway_use_repl_threshold,' ') != NVL(:new.putaway_use_repl_threshold,' ')) THEN     
    l_msg_old := l_msg_old || ' Putaway by Max qty: ' || :old.putaway_use_repl_threshold;
    l_msg_new := l_msg_new || ' Putaway by Max qty: ' || :new.putaway_use_repl_threshold; 
  END IF;
  
  IF (NVL(:old.putaway_pp_prompt_for_hst_qty,' ') != NVL(:new.putaway_pp_prompt_for_hst_qty,' ')) THEN
    l_msg_old := l_msg_old || ' Putaway_pp_prompt_for_hst_qty: ' || :old.putaway_pp_prompt_for_hst_qty;
    l_msg_new := l_msg_new || ' Putaway_pp_prompt_for_hst_qty: ' || :new.putaway_pp_prompt_for_hst_qty; 
  END IF;
  IF (NVL(:old.putaway_fp_prompt_for_hst_qty,' ') != NVL(:new.putaway_fp_prompt_for_hst_qty,' ')) THEN
    l_msg_old := l_msg_old || ' Putaway_fp_prompt_for_hst_qty: ' || :old.putaway_fp_prompt_for_hst_qty;
    l_msg_new := l_msg_new || ' Putaway_fp_prompt_for_hst_qty: ' || :new.putaway_fp_prompt_for_hst_qty;
  END IF;
  IF (NVL(:old.ndm_repl_prompt_for_hst_qty,' ') != NVL(:new.ndm_repl_prompt_for_hst_qty,' ')) THEN 
  
    
    l_msg_old := l_msg_old || ' Replenishment Prompt For HST: ' || :old.ndm_repl_prompt_for_hst_qty;
    l_msg_new := l_msg_new || ' Replenishment Prompt For HST: ' || :new.ndm_repl_prompt_for_hst_qty;
    
    
  END IF;
  
  IF l_change_flag = 'Y' THEN
    pl_audit.ins_trail(l_msg_old, l_msg_new);
  END IF;
end trg_upd_sel_equip_arow;
/

