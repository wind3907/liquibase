------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_conn_batch_vw.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    conn_batch_vw
--
-- Description:
--    Labor mgmt view.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/03/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Created this file for the existing view conn_batch_vw.
--                      Discrete selection changes.
--                      Added:
--                         - kvi_no_clam_bed_data_capture
--                         - kvi_walk
--                         - kvi_pickup_object  (This has the time in minutes
--                                               to pickup the ojects required
--                                               for selecting.)
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.conn_batch_vw
AS
SELECT DECODE(status, 'M', parent_batch_no, NULL) parent_batch_no,
       ins_indirect_jobcd,
       userenv,
       mispick,
       damage,
       shorts,
       mod_date,
       mod_usr,
       kvi_no_cart,
       kvi_no_pallet_piece,
       kvi_no_cart_piece,
       ins_indirect_dt,
       actl_start_time,
       actl_stop_time,
       actl_time_spent,
       batch_no,
       jbcd_job_code,
       status,
       batch_date,
       report_date,
       ref_no,
       parent_batch_date,
       no_breaks,
       no_lunches,
       kvi_doc_time,
       kvi_cube,
       kvi_wt,
       kvi_no_piece,
       kvi_no_pallet,
       kvi_no_item,
       kvi_no_data_capture,
       kvi_no_po,
       kvi_no_stop,
       kvi_no_zone,
       kvi_no_loc,
       kvi_no_case,
       kvi_no_split,
       kvi_no_merge,
       kvi_no_aisle,
       kvi_no_drop,
       kvi_order_time,
       kvi_from_loc,
       kvi_to_loc,
       kvi_distance,
       goal_time,
       target_time,
       user_id,
       user_supervsr_id,
       kvi_no_clam_bed_data_capture,
       kvi_walk,
       kvi_pickup_object
  FROM batch;

