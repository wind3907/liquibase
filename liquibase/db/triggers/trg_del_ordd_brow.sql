/******************************************************************************
  @(#) trg_del_ordd_brow.sql
  @(#) src/schema/triggers/trg_del_ordd_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3
******************************************************************************/

/******************************************************************************
  Modification History
  Date      User   Defect  Comment
  02/20/02  prplhj 10772   Initial creation
  02/26/02  prplhj 10772   Insert into ORDD_FOR_RTN only when route is closed
******************************************************************************/

CREATE OR REPLACE TRIGGER swms.trg_del_ordd_brow
BEFORE DELETE ON swms.ordd
FOR EACH ROW
-- This trigger is used to populate the ORDD_FOR_RTN table for returns
-- processing on RF when the ORDD table is purged.
DECLARE
  l_existed	NUMBER(1) := 0;
  CURSOR c_get_route_status (cp_route VARCHAR2) IS
    SELECT 1
    FROM route
    WHERE route_no = cp_route
    AND   status = 'CLS';
BEGIN
  -- For only those > 0 quantity shipped
  IF :old.qty_shipped = 0 THEN
    RETURN;
  END IF;
  OPEN c_get_route_status(:old.route_no);
  FETCH c_get_route_status INTO l_existed;
  IF c_get_route_status%FOUND THEN
    BEGIN
      INSERT INTO ordd_for_rtn (
        ordd_seq, route_no, stop_no,
        order_id, order_line_id,
        prod_id, cust_pref_vendor,
        rtn_qty, uom, gen_date)
        VALUES (:old.seq, :old.route_no, :old.stop_no,
                :old.order_id, :old.order_line_id,
                :old.prod_id, :old.cust_pref_vendor,
                NULL, DECODE(:old.uom, 1, 1, 0), TRUNC(SYSDATE));

    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        BEGIN
          UPDATE ordd_for_rtn
          SET route_no = :old.route_no,
              stop_no = :old.stop_no,
              order_id = :old.order_id,
              order_line_id = :old.order_line_id,
              prod_id = :old.prod_id,
              cust_pref_vendor = :old.cust_pref_vendor,
	      uom = :old.uom,
              gen_date = TRUNC(SYSDATE)
          WHERE ordd_seq = :old.seq;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002,
				    'Error update ORDD_FOR_RTN data: ' ||
				    TO_CHAR(SQLCODE));
        END;
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error insert ORDD_FOR_RTN data: ' ||
			        TO_CHAR(SQLCODE));
    END;
  END IF;
  CLOSE c_get_route_status;
END;
/

