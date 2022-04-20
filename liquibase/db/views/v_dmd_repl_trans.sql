CREATE OR REPLACE VIEW SWMS.V_DMD_REPL_TRANS AS
SELECT trans_type, trans_date, prod_id, uom,
       src_loc, pallet_id, dest_loc, route_no, cmt,
       REPLACE(user_id,'OPS$') user_id
  FROM trans
 WHERE trans_type IN ('RPL', 'DFK')
   AND user_id = DECODE(trans_type,'RPL','ORDER',user_id)
   AND trans_date > TRUNC(SYSDATE - 1)
 ORDER BY route_no, prod_id, trans_date DESC;
