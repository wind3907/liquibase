-- This script contains all SWMS application DDLs needed for upgrading 
-- from Oracle 11g to Oracle 12c (or Oracle 18c).

-- Note, in Oracle 12c and higher, all identifiers -- tables, columns, 
-- user IDs, packages, functions, etc. can be 128 bytes long.  Earlier 
-- versions limited these to 30 characters.


-- Existing RF_LOG table description:
/*
SQL> desc rf_log;
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 ADD_DATE                                  NOT NULL TIMESTAMP(6) WITH LOCAL TIME
                                                     ZONE
 MSG_SEQ                                   NOT NULL NUMBER
 USER_ID                                   NOT NULL VARCHAR2(30)
 IP_ADDRESS                                         VARCHAR2(45)
 SID                                                NUMBER
 SERIAL#                                            NUMBER
 CALLER_OWNER                                       VARCHAR2(30)
 CALLER_NAME                                        VARCHAR2(30)
 CALLER_LINENO                                      NUMBER
 CALLER_CALLER_T                                    VARCHAR2(30)
 RF_STATUS                                          NUMBER(5)
 EVENT                                     NOT NULL VARCHAR2(10)
 MSG_PRIORITY                              NOT NULL VARCHAR2(8)
 MSG_TEXT                                  NOT NULL VARCHAR2(2048)
 INIT_RECORD                                        SWMS.RF_LOG_INIT_RECORD
*/

alter table rf_log
	modify
	(
		user_id        varchar2(128),
		caller_owner   varchar2(128),
		caller_name    varchar2(257)	/* package name.function name */
	);
