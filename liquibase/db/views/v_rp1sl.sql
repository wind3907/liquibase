------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_rp1sl.sql, swms, swms.9, 10.1.1 9/7/06 1.3
--
-- View:
--    v_sn_error_logs
--
-- Description:
--    This view is used in the rp1sl screen.
--
-- Used by:
--    Screen rp1sl
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/19/04 prplhj   D#11390 View interface to swms_log for SN error logs.
--    12/07/09 ctvgg000 ASN to all OPCOs changes - Added SWMSVNREADER errors.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_sn_error_logs AS
 SELECT process_id,
	userenv_id sn_po_no,
	add_date log_date,
	msg_no rec_type,
	msg_type,
	program_name,
	procedure_name,
	msg_text
 FROM swms_log
 WHERE application_func = 'SN_ERROR_LOGS'
 AND   program_name IN ('swmssnreader','swmsvnreader');
/

