-- set echo on

BEGIN
	$if dbms_db_version.ver_le_11 $then
		EXECUTE IMMEDIATE 'create or replace library SWMS.libsyslog as ''/swms/curr/lib/libsyslog.so''';
	$else
		EXECUTE IMMEDIATE 'create or replace library SWMS.libsyslog as ''/swms/curr/lib/libsyslog.so'' AGENT ''EXTPROC_LINK''';
	$end
END;
/
show sqlcode
show errors

CREATE OR REPLACE PACKAGE SWMS.pl_syslog
AS

-- constants from AIX /usr/include/sys/syslog.h

/*
 *  Option flags for openlog.
 *
 *  LOG_ODELAY no longer does anything; LOG_NDELAY is the
 *  inverse of what it used to be.
 */

	LOG_PID		pls_integer := 1;	-- #define LOG_PID     0x01    /* log the pid with each message */
	LOG_CONS	pls_integer := 2;	-- #define LOG_CONS    0x02    /* log on the console if errors in sending */
	LOG_ODELAY	pls_integer := 4;	-- #define LOG_ODELAY  0x04    /* delay open until syslog() is called */
	LOG_NDELAY	pls_integer := 8;	-- #define LOG_NDELAY  0x08    /* don't delay open */
	LOG_NOWAIT	pls_integer := 16;	-- #define LOG_NOWAIT  0x10    /* if forking to log on console, don't wait() */

/*
 *  Facility codes
 */

	LOG_KERN	pls_integer := 0;	-- #define LOG_KERN    (0<<3)  /* kernel messages */
	LOG_USER	pls_integer := 8;	-- #define LOG_USER    (1<<3)  /* random user-level messages */
	LOG_MAIL	pls_integer := 16;	-- #define LOG_MAIL    (2<<3)  /* mail system */
	LOG_DAEMON	pls_integer := 24;	-- #define LOG_DAEMON  (3<<3)  /* system daemons */
	LOG_AUTH	pls_integer := 32;	-- #define LOG_AUTH    (4<<3)  /* security/authorization messages */
	LOG_SYSLOG	pls_integer := 40;	-- #define LOG_SYSLOG  (5<<3)  /* messages generated internally by syslogd */
	LOG_LPR		pls_integer := 48;	-- #define LOG_LPR     (6<<3)  /* line printer subsystem */
	LOG_NEWS	pls_integer := 56;	-- #define LOG_NEWS    (7<<3)  /* news subsystem */
	LOG_UUCP	pls_integer := 64;	-- #define LOG_UUCP    (8<<3)  /* uucp subsystem */
	LOG_CRON	pls_integer := 72;	-- #define LOG_CRON    (9<<3)  /* clock daemon */
		/* other codes through 14 reserved for system use */
	LOG_ASO		pls_integer := 96;	-- #define LOG_ASO     (12<<3) /* Active System Optimizer. Reserved for internal use */
	LOG_CAA		pls_integer := 120;	-- #define LOG_CAA     (15<<3) /* Cluster aware AIX subsystem */
	LOG_LOCAL0	pls_integer := 128;	-- #define LOG_LOCAL0  (16<<3) /* reserved for local use */
	LOG_LOCAL1	pls_integer := 136;	-- #define LOG_LOCAL1  (17<<3) /* reserved for local use */
	LOG_LOCAL2	pls_integer := 144;	-- #define LOG_LOCAL2  (18<<3) /* reserved for local use */
	LOG_LOCAL3	pls_integer := 152;	-- #define LOG_LOCAL3  (19<<3) /* reserved for local use */
	LOG_LOCAL4	pls_integer := 160;	-- #define LOG_LOCAL4  (20<<3) /* reserved for local use */
	LOG_LOCAL5	pls_integer := 168;	-- #define LOG_LOCAL5  (21<<3) /* reserved for local use */
	LOG_LOCAL6	pls_integer := 176;	-- #define LOG_LOCAL6  (22<<3) /* reserved for local use */
	LOG_LOCAL7	pls_integer := 184;	-- #define LOG_LOCAL7  (23<<3) /* reserved for local use */

/*
 *  Priorities (these are ordered)
 */

	LOG_MERG	pls_integer := 0;	-- #define LOG_EMERG   0   /* system is unusable */
	LOG_ALERT	pls_integer := 1;	-- #define LOG_ALERT   1   /* action must be taken immediately */
	LOG_CRIT	pls_integer := 2;	-- #define LOG_CRIT    2   /* critical conditions */
	LOG_ERR		pls_integer := 3;	-- #define LOG_ERR     3   /* error conditions */
	LOG_WARNING	pls_integer := 4;	-- #define LOG_WARNING 4   /* warning conditions */
	LOG_NOTICE	pls_integer := 5;	-- #define LOG_NOTICE  5   /* normal but signification condition */
	LOG_INFO	pls_integer := 6;	-- #define LOG_INFO    6   /* informational */
	LOG_DEBUG	pls_integer := 7;	-- #define LOG_DEBUG   7   /* debug-level messages */


-- Functions and Procedures --

	function new_syslog_data
	-- no parameters
	return pls_integer;


	-- extern pls_integer openlog_r_swms(const char * ID, int LogOption, int Facility, struct syslog_data * SysLogData)

	function openlog_r
	(
		ID			in string,
		LogOption	in pls_integer,
		Facility	in pls_integer,
		-- syslog_data	in out string	-- actually a pointer to a struct syslog_data
		syslog_data	in pls_integer	-- actually a pointer to a struct syslog_data
	)
	return pls_integer;


	-- extern pls_integer syslog_r(int pri, struct syslog_data *SysLogData, const char *fmt, ...);

	function syslog_r
	(
		pri			in pls_integer,
		-- syslog_data	in out string,	-- actually a pointer to a struct syslog_data
		syslog_data	in pls_integer,	-- actually a pointer to a struct syslog_data
		fmt			in string
	)
	return pls_integer;


	-- extern void closelog_r(struct syslog_data *SysLogData);

	procedure closelog_r
	(
		-- syslog_data	in out string	-- actually a pointer to a struct syslog_data
		syslog_data	in pls_integer	-- actually a pointer to a struct syslog_data
	);

END pl_syslog;
/
SHOW ERRORS

CREATE OR REPLACE PACKAGE BODY SWMS.pl_syslog
AS
	function new_syslog_data
		-- no parameters
	return pls_integer
	as
		external
		library		libsyslog
		name		"new_syslog_data"
		language	C;


	function openlog_r
	(
		ID			in string,
		LogOption	in pls_integer,
		Facility	in pls_integer,
		-- syslog_data	in out string	-- actually a pointer to a struct syslog_data
		syslog_data	in pls_integer	-- actually a pointer to a struct syslog_data
	)
	return pls_integer
	as
		external
		library		libsyslog
		name		"openlog_r_swms"
		language	C;


	function syslog_r
	(
		pri			in pls_integer,
		-- syslog_data	in out string,	-- actually a pointer to a struct syslog_data
		syslog_data	in pls_integer,	-- actually a pointer to a struct syslog_data
		fmt			in string
	)
	return pls_integer
	as
		external
		library		libsyslog
		name		"syslog_r_swms"
		language	C;


	procedure closelog_r
	(
		-- syslog_data	in out string	-- actually a pointer to a struct syslog_data
		syslog_data	in pls_integer	-- actually a pointer to a struct syslog_data
	)
	as
		external
		library		libsyslog
		name		"closelog_r_swms"
		language	C;

END pl_syslog;
/
show errors;

grant execute on swms.pl_syslog to public;
create or replace public synonym pl_syslog for swms.pl_syslog;
