------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_batch_no_null_kvi
--
-- Description:
--    This is a view of the BATCH table with a NVL(x, 0) on the
--    columns.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/13/03 prpbcb   rs239a DN None.
--                      rs239b DN 11209
--                      View created.  
--                      RDC non-dependent changes.
--                      This view is on rs239a for discrete selection which
--                      is still being developed.  The RDC non-dependent
--                      changes required changes to how the manual time is
--                      created for the forklift audit report and it turns
--                      out that some of the views created for discrete
--                      selection can be used for the forklift audit changes.
--                      Some of the columns were removed because they
--                      were for discrete selection.
--
--    11/10/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Discrete selection changes.
--                      Added:
--         NVL(ds_case_time, 0)                  ds_case_time,
--         NVL(ds_split_time, 0)                 ds_split_time,
--         NVL(kvi_walk, 0)                      kvi_walk,
--         NVL(kvi_walk_equipment, 0)            kvi_walk_equipment,
--         NVL(kvi_no_clam_bed_data_capture, 0)  kvi_no_clam_bed_data_capture,
--         NVL(kvi_pickup_object, 0)             kvi_pickup_object,
--         NVL(shorts, 0)                        shorts,
--
--                      The following views were created when implementing
--                      discrete selection to use in calculating the
--                      goal/target time of a selection batch.
--                         - v_batch_no_null_kvi
--                         - v_job_code_no_null_tmu
--                         - v_non_merge_batch_time
--                         - v_merge_batch_time
--                         - v_ds_non_merge_batch_time
--                         - v_ds_merge_batch_time
--
--    04/19/10 prpbcb   DN 12580
--                      Project:
--                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
--
--                      Change the suspend batch processing when lxli
--                      forklift is active.  Complete the labor mgmt batch(s)
--                      if the task(s) is completed.  Suspend the labor mgmt
--                      batch for the tasks not yet completed.  Designate a
--                      new parent batch when necessary.  Before everything
--                      was suspended.  This is done because lxli cannot
--                      handle a batch performed within the time of another
--                      batch.
--
--                      Add columns:
--                         REF_BATCH_NO
--                         DROPPED_FOR_A_BREAK_AWAY_FLAG
--                         RESUMED_AFTER_BREAK_AWAY_FLAG
--                      These are new columns in the BATCH table.
--
--    07/19/10 prpbcb   Activity: SWMS12.0.0_0000_QC11345
--                      Project:  QC11345
--                      Copy from rs239b.
--
------------------------------------------------------------------------------

PROMPT Create view v_batch_no_null_kvi

CREATE OR REPLACE VIEW swms.v_batch_no_null_kvi
AS
SELECT batch_no, 
       jbcd_job_code, 
       status,
       ref_no,
       parent_batch_no, 
       NVL(shorts, 0)                   shorts,
       NVL(kvi_doc_time, 0)             kvi_doc_time, 
       NVL(kvi_cube, 0)                 kvi_cube,
       NVL(kvi_wt, 0)                   kvi_wt, 
       NVL(kvi_no_piece, 0)             kvi_no_piece, 
       NVL(kvi_no_pallet, 0)            kvi_no_pallet,
       NVL(kvi_no_item, 0)              kvi_no_item,
       NVL(kvi_no_data_capture, 0)      kvi_no_data_capture,
       NVL(kvi_no_po, 0)                kvi_no_po,
       NVL(kvi_no_stop, 0)              kvi_no_stop,
       NVL(kvi_no_zone, 0)              kvi_no_zone, 
       NVL(kvi_no_loc, 0)               kvi_no_loc,
       NVL(kvi_no_case, 0)              kvi_no_case, 
       NVL(kvi_no_split, 0)             kvi_no_split, 
       NVL(kvi_no_merge, 0)             kvi_no_merge,
       NVL(kvi_no_aisle, 0)             kvi_no_aisle, 
       NVL(kvi_no_drop, 0)              kvi_no_drop,
       NVL(kvi_order_time, 0)           kvi_order_time,
       NVL(kvi_distance, 0)             kvi_distance,
       NVL(kvi_no_cart, 0)              kvi_no_cart,
       NVL(kvi_no_pallet_piece, 0)      kvi_no_pallet_piece,
       NVL(kvi_no_cart_piece, 0)        kvi_no_cart_piece,
       NVL(goal_time, 0)                goal_time,
       NVL(target_time, 0)              target_time,
       NVL(actl_time_spent, 0)          actl_time_spent,
       NVL(ds_case_time, 0)             ds_case_time,
       NVL(ds_split_time, 0)            ds_split_time,
       NVL(kvi_walk, 0)                 kvi_walk,
       NVL(kvi_walk_equipment, 0)       kvi_walk_equipment,
       NVL(kvi_no_clam_bed_data_capture, 0)  kvi_no_clam_bed_data_capture,
       NVL(kvi_pickup_object, 0)             kvi_pickup_object,
       user_id,
       user_supervsr_id,
       kvi_from_loc,
       kvi_to_loc,
       ref_batch_no,
       dropped_for_a_break_away_flag,
       resumed_after_break_away_flag
  FROM batch
/

