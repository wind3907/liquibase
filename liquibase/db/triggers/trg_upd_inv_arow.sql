/******************************************************************************
  @(#) trg_upd_inv_arow.sql
  @(#) src/schema/triggers/trg_upd_inv_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.3
******************************************************************************/

/******************************************************************************
  Modification History
  Date      User   Defect  Comment
  10/09/02  prpnxk 11048   Initial creation
******************************************************************************/
CREATE OR REPLACE TRIGGER swms.trig_upd_inv_arow
AFTER UPDATE OF exp_date ON SWMS.INV
FOR EACH ROW
WHEN (NEW.exp_date != OLD.exp_date)
DECLARE
	l_cmt		trans.cmt%TYPE := '';
	l_mfg_dt	trans.mfg_date%TYPE;
BEGIN
	IF (:OLD.mfg_date != :NEW.mfg_date) THEN
		l_cmt := 'Old Mfg Dt. = ' || TO_CHAR (:OLD.mfg_date, 'MM/DD/YYYY') || ', ';
		l_mfg_dt := :NEW.mfg_date;
	ELSE
		l_mfg_dt := :OLD.mfg_date;
	END IF;
	l_cmt := l_cmt || 'Old Exp Dt. = ' || TO_CHAR (:OLD.exp_date, 'MM/DD/YYYY');
	INSERT INTO trans (trans_id, trans_date, trans_type, user_id, prod_id, cust_pref_vendor,
			   pallet_id, src_loc, qty, mfg_date, exp_date, cmt)
	VALUES (trans_id_seq.NEXTVAL, SYSDATE, 'EDC', USER, :OLD.prod_id, :OLD.cust_pref_vendor,
		:OLD.logi_loc, :OLD.plogi_loc, :OLD.qoh, l_mfg_dt, :NEW.exp_date, l_cmt);
END;
/

