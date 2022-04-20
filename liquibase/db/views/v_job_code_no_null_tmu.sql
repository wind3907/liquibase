------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_job_code_no_null_tmu.sql, swms, swms.9, 10.1.1 9/7/06 1.4
--
-- View:
--    v_job_code_no_null_tmu
--
-- Description:
--    This is a view of the JOB_CODE table with a NVL(x, 0) on the
--    columns.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/13/03 prpbcb   rs239a DN None
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
--    02/05/04 prpbcb   Oracle 7 rs239a DN None.
--                      Oracle 8 rs239b swms8 DN 11481
--                      Oracle 8 rs239b swms9 DN 11490
--                      Discrete selection changes.
--                      Added:
--        NVL(tmu_walk, 0)                       tmu_walk
--        NVL(tmu_walk_equipment, 0)             tmu_walk_equipment
--        NVL(tmu_no_clam_bed_data_capture, 0)   tmu_no_clam_bed_data_capture
--        NVL(tmu_no_short, 0)                   tmu_no_short
--
--                      The following views were created when implementing
--                      discrete selection to use in calculating the goal/target
--                      time of a selection batch.
--                         - v_batch_no_null_kvi
--                         - v_job_code_no_null_tmu
--                         - v_non_merge_batch_time
--                         - v_merge_batch_time
--                         - v_ds_non_merge_batch_time
--                         - v_ds_merge_batch_time
------------------------------------------------------------------------------

PROMPT Create view v_job_code_no_null_tmu

CREATE OR REPLACE VIEW swms.v_job_code_no_null_tmu
AS
SELECT jbcd_job_code, 
       engr_std_flag,
       NVL(tmu_doc_time, 0)            tmu_doc_time,
       NVL(tmu_cube, 0)                tmu_cube,
       NVL(tmu_wt, 0)                  tmu_wt, 
       NVL(tmu_no_piece, 0)            tmu_no_piece,
       NVL(tmu_no_pallet, 0)           tmu_no_pallet, 
       NVL(tmu_no_item, 0)             tmu_no_item, 
       NVL(tmu_no_data_capture, 0)     tmu_no_data_capture,
       NVL(tmu_no_po, 0)               tmu_no_po, 
       NVL(tmu_no_stop, 0)             tmu_no_stop, 
       NVL(tmu_no_zone, 0)             tmu_no_zone,
       NVL(tmu_no_loc, 0)              tmu_no_loc, 
       NVL(tmu_no_case, 0)             tmu_no_case,
       NVL(tmu_no_split, 0)            tmu_no_split,
       NVL(tmu_no_merge, 0)            tmu_no_merge,
       NVL(tmu_no_aisle, 0)            tmu_no_aisle,
       NVL(tmu_no_drop, 0)             tmu_no_drop,
       NVL(tmu_order_time, 0)          tmu_order_time, 
       NVL(tmu_no_cart, 0)             tmu_no_cart,
       NVL(tmu_no_pallet_piece, 0)     tmu_no_pallet_piece,
       NVL(tmu_no_cart_piece, 0)       tmu_no_cart_piece,
       NVL(tmu_no_short, 0)            tmu_no_short,
       NVL(tmu_no_clam_bed_data_capture, 0)   tmu_no_clam_bed_data_capture,
       NVL(tmu_walk, 0)                tmu_walk,
       NVL(tmu_walk_equipment, 0)      tmu_walk_equipment
  FROM job_code
/

