rem *****************************************************
rem @(#) src/schema/triggers/trg_DU_fs_outbound_brow.sql, swms, swms.9, 10.1.1 03/03/12 1.3

rem @(#) File : trg_DU_fs_outbound_brow
rem @(#) Usage: sqlplus USR/PWD trg_DU_fs_outbound_brow.sql
rem Description:
rem ---  Maintenance history  ---
rem 24-FEB-2012 aver0639 Initial version

rem *****************************************************
CREATE OR REPLACE TRIGGER swms.trg_DU_fs_outbound_brow
	BEFORE UPDATE OR DELETE ON swms.food_safety_outbound
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
		pl_audit.g_application_func := 'O';
		pl_audit.g_program_name := 'fs_outbound_brow';
		l_user_id := SUBSTR (USER, 5);
		
		l_time_collect_hh_old:=to_char(:OLD.time_collected,'HH24');
        l_time_collect_mi_old:=to_char(:OLD.time_collected,'MI');		
		l_time_collect_hh_new:=to_char(:NEW.time_collected,'HH24');
        l_time_collect_mi_new:=to_char(:NEW.time_collected,'MI');

		IF UPDATING THEN
			l_msg_old :='Update food_safety_outbound for this Manifest';
			l_msg_old := l_msg_old || 'Old value: manifest_no='||:OLD.manifest_no||',stop_no='||:OLD.stop_no||',prod_id='||:OLD.prod_id||',temp_collected='||:OLD.temp_collected||',time_collected='||:OLD.time_collected ||',time_collected_hours='||l_time_collect_hh_old||',time_collected_min='||l_time_collect_mi_old;
			
			l_msg_new := 'New value: manifest_no='||:NEW.manifest_no||',stop_no='||:NEW.stop_no||',prod_id='||:NEW.prod_id||',temp_collected='||:NEW.temp_collected ||',time_collected'||:NEW.time_collected ||',time_collected_hours='||l_time_collect_hh_new||',time_collected_min='||l_time_collect_mi_new;

			:NEW.upd_user := l_user_id;
			:NEW.upd_date := TRUNC (SYSDATE);


		ELSIF DELETING THEN
			l_msg_old := 'Delete food_safety_outbound, ';
			l_msg_old := l_msg_old || 'Old value: manifest_no='||:OLD.manifest_no || ',stop_no=' || :OLD.stop_no || ',prod_id='|| :OLD.prod_id||',temp_collected='||:OLD.temp_collected ||',time_collected='||:OLD.time_collected ||',time_collected_hours='||l_time_collect_hh_old||',time_collected_min='||l_time_collect_mi_old;
			
			
			l_msg_new := null;

		END IF;

  pl_audit.ins_trail (l_msg_old, l_msg_new);

END trg_DU_fs_outbound_brow;
/
