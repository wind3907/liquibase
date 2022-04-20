------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_la1ra.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_la1ra
--
-- Description:
--    This view is used for labor management auditing.  
--
--    If for some reason the detail_level is null then 1 will be used so
--    that the record is always selected.  Ideally each audit record should
--    have a detail level specified.  If the operation is CMT then the
--    operation is set to null.
--
--    The frequency for operations RL, LL, RE, LE is in inches. The time
--    is for time to move one foot so the frequency is divided by 12 then
--    multiplied by the time.
--
-- Used by:
--    Audit report la1ra.
--    Audit form la1ra.
--    Package pl_lma.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/02/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Initially created for selection batches when
--                      implementing discrete selection.
--                      At this time forklift and discrete selection use
--                      this view.
------------------------------------------------------------------------------

PROMPT Create view v_la1ra

CREATE OR REPLACE VIEW swms.v_la1ra
AS
SELECT aud.audit_func,
       aud.user_id,
       aud.equip_id,
       aud.batch_no,
       aud.seq_no,
       b.jbcd_job_code job_code,
       jc.descrip job_code_descrip,
       aud.cmt,
       DECODE(aud.operation, 'CMT', NULL, aud.operation) operation,
       aud.tmu,
       aud.time,
       aud.from_loc,
       aud.to_loc,
       aud.frequency,
       aud.time * DECODE(aud.operation,
                        'CMT', NULL,
                        'RL', frequency/12,
                        'LL', frequency/12, 
                        'RE', frequency/12,
                        'LE', frequency/12,
                        frequency) total_time,
       NVL(aud.detail_level, 1) detail_level
  FROM job_code jc,
       batch b,
       forklift_audit aud
 WHERE jc.jbcd_job_code  = b.jbcd_job_code
   AND b.batch_no        = aud.batch_no
UNION
SELECT aud.audit_func,
       aud.user_id,
       aud.equip_id,
       aud.batch_no,
       aud.seq_no,
       b.jbcd_job_code job_code,
       jc.descrip job_code_descrip,
       aud.cmt,
       DECODE(aud.operation, 'CMT', NULL, aud.operation) operation,
       aud.tmu,
       aud.time,
       aud.from_loc,
       aud.to_loc,
       aud.frequency,
       aud.time * DECODE(aud.operation,
                        'CMT', NULL,
                        'RL', frequency/12,
                        'LL', frequency/12, 
                        'RE', frequency/12,
                        'LE', frequency/12,
                        frequency) total_time,
       NVL(aud.detail_level, 1) detail_level
  FROM job_code jc,
       arch_batch b,
       forklift_audit aud
 WHERE jc.jbcd_job_code  = b.jbcd_job_code
   AND b.batch_no        = aud.batch_no
/

