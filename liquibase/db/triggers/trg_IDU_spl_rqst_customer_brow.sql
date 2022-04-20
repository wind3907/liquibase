rem *****************************************************
rem @(#) src/schema/triggers/trg_IDU_spl_rqst_customer_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3

rem @(#) File : trg_IDU_spl_rqst_customer_arow
rem @(#) Usage: sqlplus USR/PWD trg_IDU_spl_rqst_customer_arow.sql
rem Description:
rem ---  Maintenance history  ---
rem 10-JUN-2003 prpnxk Initial version

rem *****************************************************
CREATE OR REPLACE TRIGGER swms.trg_IDU_spl_rqst_customer_brow
	BEFORE UPDATE OR INSERT OR DELETE ON swms.spl_rqst_customer
	FOR EACH ROW

	DECLARE
		 l_msg_old	VARCHAR2 (2000);
		 l_msg_new	VARCHAR2 (2000);
		 l_user_id	VARCHAR2 (10);
	--

	BEGIN
		pl_audit.g_application_func := 'O';
		pl_audit.g_program_name := 'trg_IDU_spl_rqst_customer_arow';
		l_user_id := SUBSTR (USER, 5);

		IF UPDATING THEN
			l_msg_old := 'Update spl_rqst_customer, ';
			l_msg_old := l_msg_old || 'Old value: customer_id, Name , No. of Decimals ' ||
			:OLD.customer_id || ', ' || :OLD.customer_name || ', ' || :OLD.catch_wt_dec;

			l_msg_new := 'New value: customer_id, Name , No. of Decimals ' ||
			:NEW.customer_id || ', ' || :NEW.customer_name || ', ' || :NEW.catch_wt_dec;
			:NEW.upd_user := l_user_id;
			:NEW.upd_date := TRUNC (SYSDATE);

		ELSIF INSERTING THEN
			l_msg_old := 'Insert spl_rqst_customer, ';
			l_msg_new := 'New value: customer_id, Name , No. of Decimals ' ||
			:NEW.customer_id || ', ' || :NEW.customer_name || ', ' || :NEW.catch_wt_dec;

		ELSIF DELETING THEN
			l_msg_old := 'Delete spl_rqst_customer, ';
			l_msg_old := l_msg_old || 'Old value: customer_id, Name , No. of Decimals, Deleted By ' ||
			:OLD.customer_id || ', ' || :OLD.customer_name || ', ' || :OLD.catch_wt_dec || ', ' || l_user_id;
			l_msg_new := null;

		END IF;

  pl_audit.ins_trail (l_msg_old, l_msg_new);

END trg_IDU_spl_rqst_customer_brow;
/

