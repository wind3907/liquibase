rem *****************************************************
rem @(#) src/schema/triggers/trg_DU_fs_inbound_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3

rem @(#) File : trg_DU_fs_inbound_brow
rem @(#) Usage: sqlplus USR/PWD trg_DU_fs_inbound_brow.sql
rem Description:
rem ---  Maintenance history  ---
rem 24-FEB-2012 ssin2436 Initial version
rem 23-APR-2013 bgul2852 To delete food_Safety_inbound_child records

rem *****************************************************
CREATE OR REPLACE TRIGGER swms.trg_DU_fs_inbound_brow
	BEFORE UPDATE OR DELETE ON swms.food_safety_inbound
	FOR EACH ROW

	DECLARE
		 l_msg_old	VARCHAR2 (2000);
		 l_msg_new	VARCHAR2 (2000);
		 l_user_id	VARCHAR2 (10);
		 
		 l_time_collect_hh_old VARCHAR2 (30);
	     l_time_collect_mi_old VARCHAR2 (30);
		 l_time_collect_hh_new VARCHAR2 (30);
	     l_time_collect_mi_new VARCHAR2 (30);
	

	BEGIN
		pl_audit.g_application_func := 'R';
		pl_audit.g_program_name := 'swms.fs_inbound_brow';
		l_user_id := SUBSTR (USER, 5);
		
		l_time_collect_hh_old:=to_char(:OLD.time_collected,'HH24');
        l_time_collect_mi_old:=to_char(:OLD.time_collected,'MI');
		
		l_time_collect_hh_new:=to_char(:NEW.time_collected,'HH24');
        l_time_collect_mi_new:=to_char(:NEW.time_collected,'MI');

		IF UPDATING THEN
			l_msg_old := 'Update food_safety_inbound for this PO,';
			l_msg_old := l_msg_old || 'Old value: '||'erm_id='||:OLD.erm_id||',load_no='||:OLD.load_no||',front_temp='||:OLD.front_temp||',mid_temp='||:OLD.mid_temp||',back_temp='||:OLD.back_temp||',time_collected='||:OLD.time_collected||',time_collected_hours='||l_time_collect_hh_old||',time_collected_min='||l_time_collect_mi_old;
			
			l_msg_new := 'New value: erm_id='||:NEW.erm_id||',load_no='||:NEW.load_no||',front_temp='||:NEW.front_temp||',mid_temp='||:NEW.mid_temp||',back_temp='||:NEW.back_temp||',time_collected='||:NEW.time_collected ||',time_collected_hours='||l_time_collect_hh_new||',time_collected_min='||l_time_collect_mi_new;
			

		ELSIF DELETING THEN
			l_msg_old := 'Delete food_safety_inbound, ';
			l_msg_old := l_msg_old || 'Old value: erm_id='||:OLD.erm_id||',load_no='||:OLD.load_no||',front_temp='||:OLD.front_temp||',mid_temp='||:OLD.mid_temp||',back_temp='||:OLD.back_temp||',time_collected='||:OLD.time_collected||',time_collected_hours='||l_time_collect_hh_old||',time_collected_min='||l_time_collect_mi_old;

			l_msg_new := null;

			DELETE from food_safety_inbound_child where load_no= :OLD.load_no;

		END IF;

  pl_audit.ins_trail (l_msg_old, l_msg_new);

END trg_DU_fs_inbound_brow;
/
