REM
REM  File: gen_v_order_proc_syspars.sql
REM  sccs_id = @(#) src/schema/views/gen_v_order_proc_syspars.sql, swms, swms.9, 10.1.1 5/18/07 1.2
REM
REM  MODIFICATION HISTORY
REM  02/28/07 prpnxk D#12251 Initial version. Create view v_order_proc_syspars.
REM
SET TERM ON
SET VERIFY OFF
SET PAGES 0
SET FEED OFF
SET TRIM ON
SET TRIMSPOOL ON
SET LINESIZE 500

COL ROW_NUM NOPRINT

SPOOL /tmp/v_order_proc_syspars.sql
SELECT	ROWNUM ROW_NUM, DECODE (ROWNUM, 1, 'CREATE OR REPLACE VIEW swms.v_order_proc_syspars (', NULL) || REPLACE (config_flag_name, '/', '_') ||
	DECODE (ROWNUM, (SELECT COUNT (0) FROM swms.sys_config WHERE application_func = 'ORDER PROCESSING'),
	') AS SELECT ', ',')
  FROM swms.sys_config
 WHERE application_func = 'ORDER PROCESSING'
 ORDER BY 1
/
SELECT ROWNUM ROW_NUM, 'MAX (DECODE (config_flag_name, '''|| config_flag_name || ''', config_flag_val, NULL))' ||
	DECODE (ROWNUM, (SELECT COUNT (0) FROM swms.sys_config WHERE application_func = 'ORDER PROCESSING'),
	' FROM swms.sys_config WHERE application_func = ''ORDER PROCESSING'';', ',')
  FROM swms.sys_config
 WHERE application_func = 'ORDER PROCESSING'
 ORDER BY 1
/
SPOOL OFF

@/tmp/v_order_proc_syspars.sql

COMMENT ON TABLE swms.v_order_proc_syspars IS 'From gen_v_order_proc_syspars.sql VIEW sccs_id=@(#) src/schema/views/gen_v_order_proc_syspars.sql, swms, swms.9, 10.1.1 5/18/07 1.2';

HOST rm /tmp/v_order_proc_syspars.sql
