CREATE OR REPLACE VIEW swms.v_ordcw
AS
SELECT f.batch_no, f.float_no, f.truck_no, f.float_seq,
       cw.order_id, cw.order_line_id, cw.seq_no, cw.catch_weight,
       cw.cw_type, cw.uom, cw.cw_float_no, cw.cw_scan_method,
       cw.order_seq, cw.case_id, NVL(f.pallet_pull, 'N') pallet_pull,
       cw.upd_date, cw.upd_user, cw.cw_kg_lb
  FROM floats f, ordcw cw
 WHERE f.float_no = cw.cw_float_no
/
GRANT SELECT, UPDATE ON swms.v_ordcw TO swms_user
/
CREATE OR REPLACE PUBLIC SYNONYM v_ordcw FOR swms.v_ordcw
/
