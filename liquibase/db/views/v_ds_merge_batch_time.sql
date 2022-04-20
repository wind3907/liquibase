------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ds_merge_batch_time.sql, swms, swms.9, 10.1.1 9/7/06 1.4
--
-- View:
--    v_ds_merge_batch_time
--
-- Description:
--    This view calculates the batch time for a merged discrete selection
--    labor management batch by adding together the product of the kvi's and
--    tmu's for the parent and child batches.  There is a separate view for
--    non-merged batches.  There could possibly be one view for both non-merged
--    and merged batches but I am not sure it would always return the correct
--    results.  The same goes for the non discrete selection views.
--
--    Non discrete selection batches and discrete selection batches have
--    separate views because they do not use the same kvi columns.
--
--    The kvi_distance, ds_case_time and ds_split time are in minutes.
--    The document time, order time and kvi distance are only added in for
--    the parent batch.  The kvi distance should be zero for the child batches.
--    The doc time and order time are taken as is from the job code.
--    They are not multiplied by the batches kvi value.
--
--    The following views were created when implementing discrete selection
--    to use in calculating the goal/target time of a selection batch.
--    07/22/05 prpbcb  Package pl_lm_time.sql uses these views to calculate
--                     the batch time.  Future changes may end up making
--                     these views confusing or hard to change to get the
--                     correct results so it may be that the logic would
--                     need to be moved to the package.
--       - v_batch_no_null_kvi
--       - v_job_code_no_null_tmu
--       - v_non_merge_batch_time
--       - v_merge_batch_time
--       - v_ds_non_merge_batch_time
--       - v_ds_merge_batch_time
--    The goal is to take whats in crt_lbr_mgmt_bats.pc and lm_down.pc and
--    convert to PL/SQL.
--
--
--    NOTE:  If this view changes then view v_ds_audit_manual_operation may
--           need to be changed.
--
-- Used by:
--    Package pl_lm_time.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/06/04 prpbcb   Oracle 7 rs239a DN None.  Does not exist on oracle 7.
--                      Oracle 8 rs239b swms8 DN 11481
--                      Oracle 8 rs239b swms9 DN 11490
--                      Initially created for selection batches when
--                      implementing discrete selection.
--    08/30/04 prpbcb   Added shorts.
------------------------------------------------------------------------------

PROMPT Create view v_ds_merge_batch_time

CREATE OR REPLACE VIEW swms.v_ds_merge_batch_time
AS
SELECT b.parent_batch_no,
    (((SUM(DECODE(b.batch_no,
                  b.parent_batch_no, 1,
                  0) * j.tmu_doc_time)) +
      (SUM(DECODE(b.batch_no,
                  b.parent_batch_no, 1,
                  0) * j.tmu_order_time)) +
      (SUM(b.kvi_cube               *   j.tmu_cube)) +
      (SUM(b.kvi_wt                 *   j.tmu_wt))                + 
      (SUM(0                        *   j.tmu_no_piece))          +  
      (SUM(b.kvi_no_pallet          *   j.tmu_no_pallet))         +
      (SUM(b.kvi_no_item            *   j.tmu_no_item))           +
      (SUM(b.kvi_no_data_capture    *   j.tmu_no_data_capture))   +
      (SUM(b.kvi_no_po              *   j.tmu_no_po))             +
      (SUM(b.kvi_no_stop            *   j.tmu_no_stop))           +
      (SUM(b.kvi_no_zone            *   j.tmu_no_zone))           + 
      (SUM(b.kvi_no_loc             *   j.tmu_no_loc))            +
      (SUM(0                        *   j.tmu_no_case))           + 
      (SUM(0                        *   j.tmu_no_split))          + 
      (SUM(b.kvi_no_merge           *   j.tmu_no_merge))          +
      (SUM(0                        *   j.tmu_no_aisle))          + 
      (SUM(b.kvi_no_drop            *   j.tmu_no_drop))           +
      (SUM(b.kvi_no_cart            *   j.tmu_no_cart))           +
      (SUM(b.kvi_no_pallet_piece    *   j.tmu_no_pallet_piece))   +
      (SUM(b.kvi_no_cart_piece      *   j.tmu_no_cart_piece))     +
      (SUM(b.shorts                 *   j.tmu_no_short))          +
      (SUM(b.kvi_walk               *   j.tmu_walk))              +
      (SUM(b.kvi_walk_equipment     *   j.tmu_walk_equipment))    +
   (SUM(b.kvi_no_clam_bed_data_capture    *   j.tmu_no_clam_bed_data_capture))
             ) / 1667 )  +
      (SUM(DECODE(b.batch_no,
                  b.parent_batch_no, b.kvi_distance,
                  0)))   +
      (SUM(DECODE(b.batch_no,
                  b.parent_batch_no, b.ds_case_time,
                  0)))   +
      (SUM(DECODE(b.batch_no,
                  b.parent_batch_no, b.ds_split_time,
                  0)))   +
      (SUM(DECODE(b.batch_no,
                  b.parent_batch_no, b.kvi_pickup_object,
                  0)))    batch_time_in_minutes
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
 GROUP BY b.parent_batch_no
/

