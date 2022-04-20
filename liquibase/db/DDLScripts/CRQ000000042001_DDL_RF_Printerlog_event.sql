DECLARE
	n_count					PLS_INTEGER;
	SQL_stmt				VARCHAR2(2000 CHAR);
	v_column_exists			NUMBER := 0;  

BEGIN
	SELECT COUNT(*)
		INTO n_count
		FROM all_objects
		WHERE object_type	= 'TABLE'
			AND owner		= 'SWMS'
			AND object_name	= 'RF_PRINTERLOG_EVENTS';

	IF N_COUNT > 0 THEN
		DBMS_OUTPUT.PUT_LINE('Table SWMS.RF_PRINTERLOG_EVENTS found, skipping recreation...');
	ELSE
		DBMS_OUTPUT.PUT_LINE('Table SWMS.RF_PRINTERLOG_EVENTS not found, creating now...');

		SQL_stmt := 
			'CREATE table swms.rf_printerlog_events ('
				|| 'host                    varchar2(64 char),		'
				|| 'swms_version            varchar2(20 char),		'
				|| 'log_filename            varchar2(1024 char),	'
				|| 'log_linenum             number,					'
				|| 'user_id                 varchar2(30 char),		'
				|| 'terminal                varchar2(20 char),		'
				|| 'app_name                varchar2(12 char),		'
				|| 'app_version             varchar2(15 char),		'
				|| 'connect_string          varchar2(32 char),		'
				|| 'printer_model           varchar2(32 char),		'
				|| 'printer_serial          varchar2(32 char),		'
				|| 'firmware_version        varchar2(32 char),		'
				|| 'firmware_date           varchar2(10 char),		'
				|| 'event_timestamp         date,					'
				|| 'zebra_printer_status    number,					'
				|| 'message_type            varchar2(10 char),		'
				|| 'message                 varchar2(255 char),		'
				|| 'add_date                date default sysdate,	'
				|| 'constraint pk_rf_printerlog_events primary key(log_filename,log_linenum)'
				|| ')';

		EXECUTE IMMEDIATE SQL_stmt;

		SQL_stmt := 'GRANT all on swms.rf_printerlog_events to swms_user';
		EXECUTE IMMEDIATE SQL_stmt;


		SQL_stmt := 'create or replace public synonym rf_printerlog_events for swms.rf_printerlog_events';
		EXECUTE IMMEDIATE SQL_stmt;
	end if;
end;
/