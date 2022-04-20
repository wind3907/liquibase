-- Charm6000003080 - Putaway task needs to be completed
CREATE OR REPLACE VIEW SWMS.V_PUTAWAY_COMPLETE
(
   PALLET_ID,
   REC_ID,
   PROD_ID,
   DEST_LOC,
   PUTAWAY_PUT,
   UPD_DATE,
   UPD_USER,
   QTY_RECEIVED,
   BATCH_NO,
   STATUS
)
AS
   SELECT p.pallet_id,
          p.rec_id,
          p.prod_id,
          p.dest_loc,
          p.putaway_put,
          p.upd_date,
          p.upd_user,
          p.qty_received,
          b.batch_no,
          b.status
     FROM putawaylst p, batch b
    WHERE p.PALLET_BATCH_NO = B.BATCH_NO(+);


CREATE OR REPLACE PUBLIC SYNONYM V_PUTAWAY_COMPLETE FOR SWMS.V_PUTAWAY_COMPLETE;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.V_PUTAWAY_COMPLETE TO SWMS_USER;

GRANT SELECT ON SWMS.V_PUTAWAY_COMPLETE TO SWMS_VIEWER;
