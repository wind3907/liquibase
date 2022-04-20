------------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/defects/12572_dml_asn_reports_schema_changes.sql, swms, swms.9, 11.2 3/31/10 1.1
--
-- File: 12572_dba_asn_reports_schema_changes.sql
--
-- Modification History:
--    Date		Designer	Comments
--    -----------	--------	----------------------------------------------------
--    23-MAR-2010	CTVGG000	For VSN Exception report.
------------------------------------------------------------------------------------
INSERT INTO SWMS.SCRIPTS (
	SCRIPT_NAME, 
	APPLICATION_FUNC, 
	RESTARTABLE, 
	RUN_COUNT, 
	LAST_RUN_DATE,
	LAST_RUN_USER, 
	UPDATE_FUNCTION, 
	PRINT_OPTIONS, 
	DISPLAY_HELP 
	) 
VALUES ( 
	'vsn_exception_report.sh', 
	'RECEIVING', 
	'Y', 
	0,  
	NULL, 
	NULL, 
	'N', 
	'-z1 -p12', 
	'This script is the VSN Exception Report which lists failed VSNs and % of pallets that were used in SWMS.'
); 
