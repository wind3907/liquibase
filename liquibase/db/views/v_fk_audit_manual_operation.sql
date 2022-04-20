------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_fk_audit_manual_operation.sql, swms, swms.9, 10.1.1 9/7/06 1.5
--
-- Views:
--    v_fk_audmanualoprintermediate  (intermediate view)
--    v_fk_audit_manual_operation
--
-- Description:
--    These views are used to create the manual operations that are
--    represented by a kvi and tmu for the forklift audit report for a
--    forklift labor mgmt batch.
--
--    View v_fk_audit_manual_operation will not have any null values.
--
--    It basically takes a forklift labor mgmt batch record including merged
--    batches and breaks the batch into many records with each record being
--    an operation  This lets the audit program loop through the records and
--    removes hardcoding in the program.  The display_order column in the select
--    statements is used to order the records on the report.  Two views were
--    need to get the final result (or at least I could not find a way to use
--    one view and still have the indexs used on the batch# and the parent
--    batch#).
--
--    Only the operations that apply to forklift labor mgmt are selected.
--    For instance kvi_no_stop is not selected as it does not apply
--    to forklift labor mgmt.  The operations that do not apply may not be
--    be in this script or may be commented out.  If at some time the
--    manual time on the audit report does not batch that of the batch
--    then check this view and check the program that calculates the batch
--    goal/target time to see if an operation is missing from the view.
--
--    The audit report calculates the goal/target time by looking at the
--    time in minutes and the frequency.  The time in minutes is the tmu / 1667.
--    The views calculate the time in minutes.  The tmu is on the report but
--    not used in any calculation when the report is created (see A below).
--
--    The kvi time for the doc is added for parent and child batches.
--    This corresponds to how the goal/target time is calculated
--    for forklift labor mgmt batches.  Other types of batches only add
--    the doc time for the parent batch.
--
--    Because a merged batch can have batches with different job codes
--    the records are group by operation, job code and tmu.
--
--    A.  There is special processing of the tmu for pieces, cases and splits.
--    If the job code has a non-zero value for tmu_no_case or tmu_no_split
--    then the tmu time in minutes is calculated for cases and splits and for
--    pieces it is set to zero.
--    If tmu_no_case and tmu_no_split are both zero then the tmu time in
--    minutes for cases and splits is set to zero and for pieces it is
--    calculated.  This corresponds to how the goal/target time for the
--    batch was calculated.  The audit report is looking at the tmu time in
--    minutes which is why it is set to zero in the view.
--    The program that inserts the audit records (as of 1/23/03 is
--    lmg_audit_manual_time in lm_goaltime.pc) needs to know if pieces or
--    cases and splits where used so that a message can be put on the audit
--    report.  To do this column use_pieces was added to the view.  This
--    column will have the following values:
--       Y  - Pieces used in the calculation
--       N  - Pieces not used in the calculation which means cases and
--            splits were used.
--       NA - not applicable for the operation.
--    Only for the PIECES operation will the value be Y or N.  For all
--    other operations it will be NA.  Don't make the value larger than
--    two characters.
-- 
--    View v_fk_audit_manual_operation has the following columns:
--       batch_no      - The batch number.  This is always the parent batch no.
--       operation     - Type of operation such as PIECES or CASES.  It
--                       corresponds to what kvi is being selected.
--       jbcd_job_code_cmt - The job code plus comments.
--       tmu           - The tmu for the job code.
--       tmu_min       - The tmu converted to minutes (tmu / 1667).
--                       See A above which explains why this is sometimes
--                       set to zero.
--       total_kvi     - Total kvi for the grouping of batch#, job code,
--                       operation and tmu.
--       display_order - Used to order the records on the audit report.
--       use_pieces    - Designates if pieces used in the calculation.
--                       See explanation above.  Don't make the value larger
--                       than two characters.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/13/03 prpbcb   rs239a DN None.
--                      rs239b DN 11209
--                      View created.
--                      RDC non-dependent changes.
--                      Not dual maintained back to oracle 7 at this time
--                      and may not be.
--                      These views are a modified version of view
--                      v_ds_audit_manual_operation from rs239a which is a
--                      view created for dynamic selection which is still
--                      under development.
--                      View v_fk_audit_manual_operation is used in
--                      function lmg_audit_manual_time() in lm_goaltime.pc
--
--    01/06/05 prpbcb   Oracle 8 rs239b swms9 DN 11848
--                      Changes for specify TMU at the pallet type level.
--                      Changed jbcd_job_code to jbcd_job_code_cmt.  It will
--                      have the job code plus any relevant comments.
--
--                      At this time the only TMU at the pallet type level
--                      is tmu_no_pallet.
--                      The view is starting to get out of control.  If more
--                      changes need to be made then it may be better to do
--                      away with the view and use PL/SQL to create the manual
--                      operations audit records.
--
--    01/26/05 prpbcb   Oracle 8 rs239b swms9 DN 11866
--                      The "PALLETS" record was not selected at the job
--                      code level when there was nothing at the pallet type
--                      level.  This caused the audit batch time not to
--                      match that of the batch.  They should match.
------------------------------------------------------------------------------

--
-- Intermediate view
--
PROMPT Create view v_fk_audmanualoprintermediate
--
-- The display_order column is used to order the records on the audit report.
--
-- *****  The UNION ALL is required to get the correct results  *****
--
CREATE OR REPLACE VIEW swms.v_fk_audmanualoprintermediate
AS
SELECT b.batch_no                      batch_no,    -- pieces parent batch
       b.kvi_no_piece                  kvi,
       j.tmu_no_piece                  tmu,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, j.tmu_no_piece / 1667,
                                              0) tmu_min,
       'PIECES'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       1                               display_order,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, 'Y', 'N') use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,    -- pieces child batches
       b.kvi_no_piece                  kvi,
       j.tmu_no_piece                  tmu,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, j.tmu_no_piece / 1667,
                                              0) tmu_min,
       'PIECES'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       1                               display_order,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, 'Y', 'N') use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,     -- cases parent batch
       b.kvi_no_case                   kvi,
       j.tmu_no_case                   tmu,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, 0,
                                              j.tmu_no_case / 1667) tmu_min,
       'CASES'                         operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       2                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,     -- cases child batches
       b.kvi_no_case                   kvi,
       j.tmu_no_case                   tmu,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, 0,
                                              j.tmu_no_case / 1667) tmu_min,
       'CASES'                         operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       2                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,     -- splits parent batch
       b.kvi_no_split                  kvi,
       j.tmu_no_split                  tmu,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, 0,
                                              j.tmu_no_split / 1667) tmu_min,
       'SPLITS'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       3                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,     -- splits child batches
       b.kvi_no_split                  kvi,
       j.tmu_no_split                  tmu,
       DECODE(j.tmu_no_case + j.tmu_no_split, 0, 0,
                                              j.tmu_no_split / 1667) tmu_min,
       'SPLITS'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       3                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL                                           -- KVI Pallets
SELECT b.batch_no                      batch_no,    -- pallets parent batch
       b.kvi_no_pallet                 kvi,
       j.tmu_no_pallet                 tmu,
       j.tmu_no_pallet / 1667          tmu_min,
       'PALLETS'                       operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       4                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND NOT EXISTS        -- Do not use the pallet TMU at the job code level
       (SELECT 'x'       -- if it is setup at the pallet type level.
          FROM loc, pallet_type_tmu ptmu
         WHERE ptmu.job_code = b.jbcd_job_code
           AND (  (loc.logi_loc = b.kvi_from_loc AND ptmu.apply_at_loc = 'FROM')
                OR (loc.logi_loc = b.kvi_to_loc AND ptmu.apply_at_loc = 'TO') )
           AND ptmu.pallet_type = loc.pallet_type)
UNION ALL                                           -- KVI Pallets
SELECT b.parent_batch_no               batch_no,    -- pallets child batches
       b.kvi_no_pallet                 kvi,
       j.tmu_no_pallet                 tmu,
       j.tmu_no_pallet / 1667          tmu_min,
       'PALLETS'                       operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       4                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
   AND NOT EXISTS        -- Do not use the pallet TMU at the job code level
       (SELECT 'x'       -- if it is setup at the pallet type level.
          FROM loc, pallet_type_tmu ptmu
         WHERE ptmu.job_code = b.jbcd_job_code
           AND (  (loc.logi_loc = b.kvi_from_loc AND ptmu.apply_at_loc = 'FROM')
                OR (loc.logi_loc = b.kvi_to_loc AND ptmu.apply_at_loc = 'TO') )
           AND ptmu.pallet_type = loc.pallet_type)
UNION ALL
                          -- KVI Pallets
                          -- Pallet type TMU parent batch "From" location
SELECT b.batch_no                      batch_no,
       b.kvi_no_pallet                 kvi,
       ptmu.tmu_no_pallet              tmu,
       ptmu.tmu_no_pallet / 1667       tmu_min,
       'PALLETS'                       operation,
       b.jbcd_job_code || ' Batch ' || b.batch_no ||
          ' TMU at pallet type level for "From" locn ' ||
          b.kvi_from_loc || ' ' || loc.pallet_type  jbcd_job_code_cmt,
       4                               display_order,
       'NA' use_pieces
  FROM loc,
       pallet_type_tmu ptmu,
       v_batch_no_null_kvi b
 WHERE ptmu.job_code = b.jbcd_job_code
   AND loc.logi_loc = b.kvi_from_loc
   AND ptmu.pallet_type = loc.pallet_type
   AND ptmu.apply_at_loc = 'FROM'
UNION ALL
                          -- KVI Pallets
                          -- Pallet type TMU parent batch "To" location
SELECT b.batch_no                      batch_no,
       b.kvi_no_pallet                 kvi,
       ptmu.tmu_no_pallet              tmu,
       ptmu.tmu_no_pallet / 1667       tmu_min,
       'PALLETS'                       operation,
       b.jbcd_job_code || ' Batch ' || b.batch_no ||
          ' TMU at pallet type level for "To" locn ' ||
          b.kvi_to_loc || ' ' || loc.pallet_type    jbcd_job_code_cmt,
       4                               display_order,
       'NA' use_pieces
  FROM loc,
       pallet_type_tmu ptmu,
       v_batch_no_null_kvi b
 WHERE ptmu.job_code = b.jbcd_job_code
   AND loc.logi_loc = b.kvi_to_loc
   AND ptmu.pallet_type = loc.pallet_type
   AND ptmu.apply_at_loc = 'TO'
UNION ALL
                          -- KVI Pallets
                          -- Pallet type TMU child batches "From" location
SELECT b.parent_batch_no               batch_no,
       b.kvi_no_pallet                 kvi,
       ptmu.tmu_no_pallet              tmu,
       ptmu.tmu_no_pallet / 1667       tmu_min,
       'PALLETS'                       operation,
       b.jbcd_job_code || ' Batch ' || b.batch_no ||
          ' TMU at pallet type level for "From" locn ' ||
          b.kvi_from_loc || ' ' || loc.pallet_type  jbcd_job_code_cmt,
       4                               display_order,
       'NA' use_pieces
  FROM loc,
       pallet_type_tmu ptmu,
       v_batch_no_null_kvi b
 WHERE ptmu.job_code = b.jbcd_job_code
   AND loc.logi_loc = b.kvi_from_loc
   AND ptmu.pallet_type = loc.pallet_type
   AND ptmu.apply_at_loc = 'FROM'
   AND b.batch_no != b.parent_batch_no
UNION ALL
                          -- KVI Pallets
                          -- Pallet type TMU child batches "To" location
SELECT b.parent_batch_no               batch_no,
       b.kvi_no_pallet                 kvi,
       ptmu.tmu_no_pallet              tmu,
       ptmu.tmu_no_pallet / 1667       tmu_min,
       'PALLETS'                       operation,
       b.jbcd_job_code || ' Batch ' || b.batch_no ||
          ' TMU at pallet type level for "To" locn ' ||
          b.kvi_to_loc || ' ' || loc.pallet_type    jbcd_job_code_cmt,
       4                               display_order,
       'NA' use_pieces
  FROM loc,
       pallet_type_tmu ptmu,
       v_batch_no_null_kvi b
 WHERE ptmu.job_code = b.jbcd_job_code
   AND loc.logi_loc = b.kvi_to_loc
   AND ptmu.pallet_type = loc.pallet_type
   AND ptmu.apply_at_loc = 'TO'
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,    -- items parent batch
       b.kvi_no_item                   kvi,
       j.tmu_no_item                   tmu,
       j.tmu_no_item / 1667            tmu_min,
       'ITEMS'                         operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       5                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,    -- items child batches
       b.kvi_no_item                   kvi,
       j.tmu_no_item                   tmu,
       j.tmu_no_item / 1667            tmu_min,
       'ITEMS'                         operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       5                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,  -- po's parent batch
       b.kvi_no_po                     kvi,
       j.tmu_no_po                     tmu,
       j.tmu_no_po / 1667              tmu_min,
       'POS'                           operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       6                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,  -- po's child batches
       b.kvi_no_po                     kvi,
       j.tmu_no_po                     tmu,
       j.tmu_no_po / 1667              tmu_min,
       'POS'                           operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       6                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,         -- cube parent batch
       b.kvi_cube                      kvi,
       j.tmu_cube                      tmu, 
       j.tmu_cube / 1667               tmu_min, 
       'CUBE'                          operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       7                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,        -- cube child batches
       b.kvi_cube                      kvi,
       j.tmu_cube                      tmu, 
       j.tmu_cube / 1667               tmu_min, 
       'CUBE'                          operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       7                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,    -- weight parent batch
       b.kvi_wt                        kvi,
       j.tmu_wt                        tmu, 
       j.tmu_wt / 1667                 tmu_min, 
       'WEIGHT'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       8                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,    -- weight child batches
       b.kvi_wt                        kvi,
       j.tmu_wt                        tmu, 
       j.tmu_wt / 1667                 tmu_min, 
       'WEIGHT'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       8                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,  -- locations parent batch
       b.kvi_no_loc                    kvi,
       j.tmu_no_loc                    tmu,
       j.tmu_no_loc / 1667             tmu_min,
       'NO_LOC'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       9                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,  -- locations child batches
       b.kvi_no_loc                    kvi,
       j.tmu_no_loc                    tmu,
       j.tmu_no_loc / 1667             tmu_min,
       'NO_LOC'                        operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       9                               display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,           -- doc parent batch
       b.kvi_doc_time                  kvi,
       j.tmu_doc_time                  tmu,
       j.tmu_doc_time / 1667           tmu_min,
       'DOCTIME'                       operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       10                              display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,         -- doc child batches
       b.kvi_doc_time                  kvi,
       j.tmu_doc_time                  tmu,
       j.tmu_doc_time / 1667           tmu_min,
       'DOCTIME'                       operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       10                              display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no
UNION ALL
SELECT b.batch_no                      batch_no,  -- data capture parent batch
       b.kvi_no_data_capture           kvi,
       j.tmu_no_data_capture           tmu,
       j.tmu_no_data_capture / 1667    tmu_min,
       'CAPTURE'                       operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       11                              display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
UNION ALL
SELECT b.parent_batch_no               batch_no,  -- data capture child batches
       b.kvi_no_data_capture           kvi,
       j.tmu_no_data_capture           tmu,
       j.tmu_no_data_capture / 1667    tmu_min,
       'CAPTURE'                       operation,
       b.jbcd_job_code                 jbcd_job_code_cmt,
       11                              display_order,
       'NA' use_pieces
  FROM v_job_code_no_null_tmu j,
       v_batch_no_null_kvi b
 WHERE j.jbcd_job_code = b.jbcd_job_code
   AND b.batch_no != b.parent_batch_no;


-----------------------------------------------------------------------------
--           View   v_fk_audit_manual_operation
-----------------------------------------------------------------------------
PROMPT Create view v_fk_audit_manual_operation

CREATE OR REPLACE VIEW swms.v_fk_audit_manual_operation
AS
SELECT v.batch_no, v.operation, v.jbcd_job_code_cmt, v.tmu, v.tmu_min,
       v.display_order, v.use_pieces, SUM(v.kvi) total_kvi
  FROM v_fk_audmanualoprintermediate v
 GROUP BY v.batch_no, v.operation, v.jbcd_job_code_cmt, v.tmu,
          v.tmu_min, v.display_order, v.use_pieces;


