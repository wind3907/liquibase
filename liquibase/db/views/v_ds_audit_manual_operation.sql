------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ds_audit_manual_operation.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_ds_audit_manual_operation
--
-- Description:
--    This view is used to create the manual operations that are represented by
--    a kvi and tmu for the selection audit report for a non merge batch.
--    It basically takes one batch record and breaks it into many records by
--    operation.  This lets the audit program to loop through the records and
--    removes hardcoding in the program.  The last value in the select
--    statements is used to order the records.
--
--    The audit report calculates the goal/target time by looking at the
--    time and frequency.  The time is the tmu / 1667.  The tmu is on the
--    report but not used in any calculation.
--    The operations not used in calculating the goal/target time
--    will have the time set to 0.  This corresponds to the views that
--    calculate the goal/target time so when the report is run the goal/target
--    time on the report matches the goal/target time in the batch table.
--
--    The kvi time for the doc and order time is 1 because they are added in
--    only once.  This matches the views used to calculate the goal/target time.
--
--    NOTE:  If one of the views that calculate the batch time is changed then
--           this view may need to be changed too.
--
--    -------------------------------------------------------------------
--    -- The length of the "operation" cannot exceed 10 characters     --
--    -- This operation is used in lm_goaltime.pc and is inserted      --
--    -- into table FORKLIFT_AUDIT which both have a max length of 10. --
--    -------------------------------------------------------------------
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/26/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Initially created for selection batches when
--                      implementing discrete selection.
--                      Added clam_bed_data_capture.
--                      Added shorts.
------------------------------------------------------------------------------

PROMPT Create view v_ds_audit_manual_operation

CREATE OR REPLACE VIEW swms.v_ds_audit_manual_operation
AS
SELECT b.batch_no                      batch_no,
       1                               kvi,
       j.tmu_doc_time                  tmu,
       j.tmu_doc_time / 1667           tmu_min,
       'DOCTIME'                       operation,
       1                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       1                               kvi,
       j.tmu_order_time                tmu,
       j.tmu_order_time / 1667         tmu_min,
       'ORDERTIME'                     operation,
       2                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_cube                      kvi,
       j.tmu_cube                      tmu, 
       j.tmu_cube / 1667               tmu_min, 
       'CUBE'                          operation,
       3                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_wt                        kvi,
       j.tmu_wt                        tmu, 
       j.tmu_wt / 1667                 tmu_min, 
       'WEIGHT'                        operation,
       4                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_piece                  kvi,
       j.tmu_no_piece                  tmu,
       0                               tmu_min,
       'PIECES'                        operation,
       5                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_pallet                 kvi,
       j.tmu_no_pallet                 tmu,
       j.tmu_no_pallet / 1667          tmu_min,
       'PALLETS'                       operation,
       6                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_case                   kvi,
       j.tmu_no_case                   tmu,
       0                               tmu_min,
       'CASES'                         operation,
       7                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_split                  kvi,
       j.tmu_no_split                  tmu,
       0                               tmu_min,
       'SPLITS'                        operation,
       8                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_merge                  kvi,
       j.tmu_no_merge                  tmu,
       j.tmu_no_merge / 1667           tmu_min,
       'MERGES'                        operation,
       9                               seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_cart_piece             kvi,
       j.tmu_no_cart_piece             tmu,
       j.tmu_no_cart_piece / 1667      tmu_min,
       'CARTPIECES'                    operation,
       10                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_cart                   kvi,
       j.tmu_no_cart                   tmu,
       j.tmu_no_cart / 1667            tmu_min,
       'CARTS'                         operation,
       11                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.shorts                        kvi,
       j.tmu_no_short                  tmu,
       j.tmu_no_short / 1667           tmu_min,
       'SHORTS'                        operation,
       12                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_zone                   kvi,
       j.tmu_no_zone                   tmu,
       j.tmu_no_zone / 1667            tmu_min,
       'ZONES'                         operation,
       13                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_drop                   kvi,
       j.tmu_no_drop                   tmu,
       j.tmu_no_drop / 1667            tmu_min,
       'DROPS'                         operation,
       14                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_item                   kvi,
       j.tmu_no_item                   tmu,
       j.tmu_no_item / 1667            tmu_min,
       'ITEMS'                         operation,
       15                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_po                     kvi,
       j.tmu_no_po                     tmu,
       j.tmu_no_po / 1667              tmu_min,
       'POS'                           operation,
       16                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_stop                   kvi,
       j.tmu_no_stop                   tmu,
       j.tmu_no_stop / 1667            tmu_min,
       'STOPS'                         operation,
       17                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_pallet_piece           kvi,
       j.tmu_no_pallet_piece           tmu,
       j.tmu_no_pallet_piece / 1667    tmu_min,
       'PLTPIECES'                     operation,
       18                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_loc                    kvi,
       j.tmu_no_loc                    tmu,
       j.tmu_no_loc / 1667             tmu_min,
       'LOCATIONS'                     operation,
       19                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_aisle                  kvi,
       j.tmu_no_aisle                  tmu,
       0                               tmu_min,
       'AISLES'                        operation,
       20                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_no_data_capture           kvi,
       j.tmu_no_data_capture           tmu,
       j.tmu_no_data_capture / 1667    tmu_min,
       'CAPTURE'                       operation,
       21                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                             batch_no,
       b.kvi_no_clam_bed_data_capture         kvi,
       j.tmu_no_clam_bed_data_capture         tmu,
       j.tmu_no_clam_bed_data_capture / 1667  tmu_min,
       'CLAM_BED'                             operation,
       22                                     seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_walk                      kvi,
       j.tmu_walk                      tmu,
       j.tmu_walk / 1667               tmu_min,
       'WALKING'                       operation,
       23                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
UNION
SELECT b.batch_no                      batch_no,
       b.kvi_walk_equipment            kvi,
       j.tmu_walk_equipment            tmu,
       j.tmu_walk_equipment / 1667     tmu_min,
       'WALKING_EQUIPMENT'             operation,
       24                              seq
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
/

