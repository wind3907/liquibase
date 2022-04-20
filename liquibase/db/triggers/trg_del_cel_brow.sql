REM *****************************************************
REM @(#) src/schema/triggers/trg_del_cel_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.2

REM @(#) File :  trg_del_cel_brow.sql
REM @(#) Usage: sqlplus USR/PWD  trg_del_cel_brow.sql
REM Description:
REM ---  Maintenance history  ---
REM 12/01/05 prplhj D#12028 Initial version.

REM *****************************************************

CREATE OR REPLACE TRIGGER swms.trg_del_cel_brow
BEFORE DELETE ON swms.cc_exception_list
FOR EACH ROW
DECLARE
  iTransID	trans.trans_id%TYPE := NULL;
  szBatchNo	trans.batch_no%TYPE := NULL;
  dtCCGenDate	DATE := NULL;
BEGIN
  -- Retrieve the latest cycle count task partial info for the matched data
  BEGIN
    SELECT trans_id, group_no, cc_gen_date INTO iTransID, szBatchNo, dtCCGenDate
    FROM cc_edit
    WHERE prod_id = :old.prod_id
    AND   cust_pref_vendor = :old.cust_pref_vendor
    AND   phys_loc = :old.phys_loc
    AND   logi_loc = :old.logi_loc
    AND   adj_flag IN ('Y', 'A')
    AND   ROWNUM = 1
    ORDER BY add_date DESC;
  EXCEPTION
    WHEN OTHERS THEN
      iTransID := NULL;
      szBatchNo := NULL;
      dtCCGenDate := NULL;
  END;
  -- Save all the delete CC_EXCEPTION_LIST table data to CC_EDIT table so they
  -- can be researched later if something is wrong
  BEGIN
    INSERT INTO cc_edit
      (trans_id, group_no,
       prod_id, cust_pref_vendor,
       phys_loc, logi_loc, old_qty, new_qty,
       reason_code, cc_gen_date, gen_user_id, adj_flag,
       add_date, add_user, upd_date, upd_user)
      VALUES (
       DECODE(iTransID, NULL, trans_id_seq.nextval, iTransID),
       TO_NUMBER(szBatchNo),
       :old.prod_id, :old.cust_pref_vendor,
       :old.phys_loc, :old.logi_loc, :old.qty, TO_NUMBER(:old.uom),
       :old.cc_except_code, dtCCGenDate, REPLACE(USER, 'OPS$', ''), 'D',
       SYSDATE, REPLACE(USER, 'OPS$', ''), :old.cc_except_date, NULL);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
END trg_del_cel_brow;
/

