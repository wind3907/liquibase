/******************************************************************************
  @(#) trg_del_returns_brow.sql
  @(#) src/schema/triggers/trg_del_returns_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3
******************************************************************************/

/******************************************************************************
  Modification History
  Date      User   Defect  Comment
  02/20/02  prplhj 10772   Initial creation
******************************************************************************/

CREATE OR REPLACE TRIGGER swms.trg_del_returns_brow
BEFORE DELETE ON swms.returns
FOR EACH ROW
-- This trigger is used to delete or update the returned quantity so far for
-- the ORDD_FOR_RTN table when the returns are purged and the manifest that
-- related to the returns has been closed.
DECLARE
  l_data	VARCHAR2(30);
  l_ship_splits	NUMBER(10) := 0;
  l_rtn_splits	NUMBER(10) := 0;
  l_orig_inv	manifest_dtls.orig_invoice%TYPE := NULL;
  CURSOR c_get_mf_status (cp_mf_no NUMBER) IS
    SELECT manifest_status
    FROM  manifests
    WHERE manifest_no = cp_mf_no;
  CURSOR c_get_rsn_group (cp_reason VARCHAR2) IS
    SELECT reason_group
    FROM reason_cds
    WHERE reason_cd_type = 'RTN'
    AND   reason_cd = cp_reason;
  CURSOR c_get_orig_inv (cp_mf_no   NUMBER,
                         cp_ob_no   VARCHAR2,
                         cp_prod_id VARCHAR2,
                         cp_cpv     VARCHAR2) IS
    SELECT orig_invoice
    FROM manifest_dtls
    WHERE manifest_no = cp_mf_no
    AND   obligation_no = cp_ob_no
    AND   prod_id = cp_prod_id
    AND   cust_pref_vendor = cp_cpv;
  CURSOR c_get_ship_info (cp_mf_no   NUMBER,
                          cp_ob_no   VARCHAR2,
                          cp_prod_id VARCHAR2,
                          cp_cpv     VARCHAR2) IS
    SELECT NVL(SUM(NVL(d.shipped_qty, 0) *
	           DECODE(d.shipped_split_cd, '1', 1, NVL(p.spc, 0))), 0)
    FROM manifest_dtls d, pm p
    WHERE d.manifest_no = cp_mf_no
    AND   (d.obligation_no = cp_ob_no OR d.orig_invoice = cp_ob_no)
    AND   d.prod_id = cp_prod_id
    AND   d.cust_pref_vendor = cp_cpv
    AND   p.prod_id = d.prod_id
    AND   p.cust_pref_vendor = d.cust_pref_vendor;
  CURSOR c_conv_to_splits (cp_prod_id VARCHAR2,
			   cp_cpv     VARCHAR2,
			   cp_qty     NUMBER,
			   cp_uom     VARCHAR2) IS
    SELECT NVL(cp_qty, 0) * DECODE(cp_uom, '1', 1, NVL(p.spc, 0))
    FROM pm p
    WHERE p.prod_id = cp_prod_id
    AND   p.cust_pref_vendor = cp_cpv;
BEGIN
  -- Note: In order for this trigger to work, the RETURNS record deletion
  --       must proceed the manifest header and detail deletion

  -- Only care about manifests that have been closed
  OPEN c_get_mf_status(:old.manifest_no);
  FETCH c_get_mf_status INTO l_data;
  IF c_get_mf_status%FOUND AND l_data <> 'CLS' THEN
    CLOSE c_get_mf_status;
    RETURN;
  END IF;
  CLOSE c_get_mf_status;

  -- No reason to care about overages
  OPEN c_get_rsn_group(:old.return_reason_cd);
  FETCH c_get_rsn_group INTO l_data;
  CLOSE c_get_rsn_group;
  IF l_data = 'OVR' AND :old.obligation_no IS NULL THEN
    RETURN;
  END IF;
  
  OPEN c_get_orig_inv(:old.manifest_no, :old.obligation_no,
                      :old.prod_id, :old.cust_pref_vendor);
  FETCH c_get_orig_inv INTO l_orig_inv;
  CLOSE c_get_orig_inv;

  -- Get original order ship information in splits
  OPEN c_get_ship_info(:old.manifest_no, :old.obligation_no,
                        :old.prod_id, :old.cust_pref_vendor);
  FETCH c_get_ship_info INTO l_ship_splits;
  CLOSE c_get_ship_info;

  -- Get current returned quantity in splits
  OPEN c_conv_to_splits(:old.prod_id, :old.cust_pref_vendor,
			:old.returned_qty, :old.returned_split_cd);
  FETCH c_conv_to_splits INTO l_rtn_splits;
  CLOSE c_conv_to_splits;

  BEGIN
    UPDATE ordd_for_rtn
      SET rtn_qty = NVL(rtn_qty, 0) + NVL(l_rtn_splits, 0)
      WHERE (order_id = :old.obligation_no OR order_id = l_orig_inv)
      AND   prod_id = :old.prod_id
      AND   cust_pref_vendor = :old.cust_pref_vendor
      AND   uom = TO_NUMBER(:old.shipped_split_cd);

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001,
                              'Error update current ORDD_FOR_RTN data: ' ||
			      TO_CHAR(SQLCODE));
  END;

  -- Delete those orders that have been returned full and keep those that
  -- have been returned partial until the maximum kept date is up
  BEGIN
    DELETE ordd_for_rtn
      WHERE (order_id = :old.obligation_no OR order_id = l_orig_inv)
      AND   prod_id = :old.prod_id
      AND   cust_pref_vendor = :old.cust_pref_vendor
      AND   uom = TO_NUMBER(:old.shipped_split_cd)
      AND   rtn_qty >= l_ship_splits;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001,
			      'Error delete current ORDD_FOR_RTN data: ' ||
			      TO_CHAR(SQLCODE));
  END;
END;
/

