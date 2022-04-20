--CONNECT swms/swms;

--CREATE OR REPLACE LIBRARY FRM_login_lib AS '/home2/prp/dwayne/ora_login/libora_login.so';
--CREATE OR REPLACE LIBRARY FRM_login_lib AS '/swms/dvlp/lib/libora_login.so';

BEGIN
$if dbms_db_version.ver_le_11 $then
	EXECUTE IMMEDIATE 'create or replace library FRM_login_lib as ''/swms/curr/lib/libora_login.so''';
$else
	EXECUTE IMMEDIATE 'create or replace library FRM_login_lib as ''/swms/curr/lib/libora_login.so'' AGENT ''EXTPROC_LINK''';
$end
END;
/
show sqlcode
show errors

CREATE OR REPLACE PACKAGE FRM_login
AS
	-- Constants from <usersec.h>

	MAX_SEED		CONSTANT NUMBER := 4294967295;

	/* attribute types */

	SEC_CHAR		constant PLS_INTEGER := 1;
	SEC_INT			constant PLS_INTEGER := 2;
	SEC_LIST		constant PLS_INTEGER := 3;
	SEC_BOOL		constant PLS_INTEGER := 4;


	/* The user attributes names */

	S_ID			constant STRING(30) := 'id';			/* SEC_INT - user, group id */
	S_PWD			constant STRING(30) := 'password';		/* SEC_CHAR - user password */
	S_PGRP			constant STRING(30) := 'pgrp';			/* SEC_CHAR - primary group name */
	S_PGID			constant STRING(30) := 'pgid';			/* SEC_INT - primary group gid */
	S_GROUPS		constant STRING(30) := 'groups';		/* SEC_LIST - concurrent group list */
	S_GROUPSIDS		constant STRING(30) := 'groupsids';		/* SEC_LIST - concurrent group list by id */
	S_ADMGROUPS		constant STRING(30) := 'admgroups';		/* SEC_LIST - groups for which this user is an administrator */
	S_PUSERS		constant STRING(30) := 'primary';		/* SEC_LIST - primary users of group */
	S_USERS			constant STRING(30) := 'users';			/* SEC_LIST - the members of a group */
	S_ADMIN			constant STRING(30) := 'admin';			/* SEC_BOOL - administrative group */
	S_ADMS			constant STRING(30) := 'adms';			/* SEC_LIST - group administrators */
	S_PACCT			constant STRING(30) := 'pacct';			/* NOT_IMPLEM - primary account */
	S_ACCTS			constant STRING(30) := 'accts';			/* NOT_IMPLEM - this users accounts */
	S_ADMACCTS		constant STRING(30) := 'admacct';		/* NOT_IMPLEM - accounts for which this user is an administrator */
	S_AUDITCLASSES	constant STRING(30) := 'auditclasses';	/* SEC_LIST - the users audit classes */
	S_HOME			constant STRING(30) := 'home';			/* SEC_CHAR - home directory */
	S_SHELL			constant STRING(30) := 'shell';			/* SEC_CHAR - the users login shell */
	S_GECOS			constant STRING(30) := 'gecos';			/* SEC_CHAR - user information */
	S_SYSENV		constant STRING(30) := 'sysenv';		/* SEC_LIST - protected environment */
	S_USRENV		constant STRING(30) := 'usrenv';		/* SEC_LIST - public environment */
	S_LOGINCHK		constant STRING(30) := 'login';			/* SEC_BOOL - login permitted or not */
	S_SUCHK			constant STRING(30) := 'su';			/* SEC_BOOL - su permitted or not */
	S_DAEMONCHK		constant STRING(30) := 'daemon';		/* SEC_BOOL - cron or src permitted */
	S_RLOGINCHK		constant STRING(30) := 'rlogin';		/* SEC_BOOL - rlogin or telnet allowed*/
	S_TELNETCHK		constant STRING(30) := 'telnet';		/* SEC_BOOL - rlogin or telnet allowed*/
	S_ADMCHK		constant STRING(30) := 'admchk';		/* SEC_BOOL - force passwd renewal */
	S_TPATH			constant STRING(30) := 'tpath';			/* SEC_CHAR - can be "nosak", "always", "notsh", or "on" */
	S_TTYS			constant STRING(30) := 'ttys';			/* SEC_LIST - allowed login ttys */
	S_SUGROUPS		constant STRING(30) := 'sugroups';		/* SEC_LIST - groups that can su to this account */
	S_EXPIRATION	constant STRING(30) := 'expires';		/* SEC_CHAR - account expiration */
	S_AUTH1			constant STRING(30) := 'auth1';			/* SEC_LIST - primary authentication */
	S_AUTH2			constant STRING(30) := 'auth2';			/* SEC_LIST - secondary authentication*/
	S_ULIMIT		constant STRING(30) := 'limits';		/* SEC_INT  - ulimit */
	S_UFSIZE 		constant STRING(30) := 'fsize';			/* SEC_INT  - file size */
	S_UCPU			constant STRING(30) := 'cpu';			/* SEC_INT  - cpu usage limit */
	S_UDATA 		constant STRING(30) := 'data';			/* SEC_INT  - data memory limit */
	S_USTACK 		constant STRING(30) := 'stack';			/* SEC_INT  - stack memory limit */
	S_UCORE 		constant STRING(30) := 'core';			/* SEC_INT  - core memory limit */
	S_URSS			constant STRING(30) := 'rss';			/* SEC_INT  - rss memory limit */
	S_UNOFILE		constant STRING(30) := 'nofiles';		/* SEC_INT  - file descriptor limit */
	S_UTHREADS		constant STRING(30) := 'threads';		/* SEC_INT  - threads per proc limit */
	S_UNPROC		constant STRING(30) := 'nproc';			/* SEC_INT  - processes per user limit */
	S_UFSIZE_HARD 	constant STRING(30) := 'fsize_hard';	/* SEC_INT  - hard file size */
	S_UCPU_HARD		constant STRING(30) := 'cpu_hard';		/* SEC_INT  - hard cpu usage limit */
	S_UDATA_HARD 	constant STRING(30) := 'data_hard';		/* SEC_INT  - hard data memory limit */
	S_USTACK_HARD 	constant STRING(30) := 'stack_hard';	/* SEC_INT  - hard stack memory limit */
	S_UCORE_HARD 	constant STRING(30) := 'core_hard';		/* SEC_INT  - hard core memory limit */
	S_URSS_HARD		constant STRING(30) := 'rss_hard';		/* SEC_INT  - hard rss memory limit */
	S_UNOFILE_HARD	constant STRING(30) := 'nofiles_hard';	/* SEC_INT  - hard file desc limit */
	S_UTHREADS_HARD	constant STRING(30) := 'threads_hard';	/* SEC_INT  - hard threads per proc limit */
	S_UNPROC_HARD	constant STRING(30) := 'nproc_hard';	/* SEC_INT  - hard processes per user limit */
	S_UMASK			constant STRING(30) := 'umask';			/* SEC_INT  - file creation mask */
	S_AUTHSYSTEM	constant STRING(30) := 'SYSTEM';		/* SEC_CHAR - authentication grammar */
	S_REGISTRY		constant STRING(30) := 'registry';		/* SEC_CHAR - administration domain */
	S_LOGTIMES		constant STRING(30) := 'logintimes';	/* SEC_LIST - valid login times */
	S_LOCKED		constant STRING(30) := 'account_locked';/* SEC_BOOL - is the account locked */
	S_LOGRETRIES	constant STRING(30) := 'loginretries';	/* SEC_INT  - invalid login attempts before the account is locked */
	S_MINALPHA		constant STRING(30) := 'minalpha';		/* SEC_INT - passwd minalpha   */
	S_MINOTHER		constant STRING(30) := 'minother';		/* SEC_INT - passwd minother   */
	S_MINDIFF		constant STRING(30) := 'mindiff';		/* SEC_INT - passwd mindiff    */
	S_MAXREPEAT		constant STRING(30) := 'maxrepeats';	/* SEC_INT - passwd maxrepeats */
	S_MINLEN		constant STRING(30) := 'minlen';		/* SEC_INT - passwd minlen     */
	S_MINAGE		constant STRING(30) := 'minage';		/* SEC_INT - passwd minage     */
	S_MAXAGE		constant STRING(30) := 'maxage';		/* SEC_INT - passwd maxage     */
	S_MAXEXPIRED	constant STRING(30) := 'maxexpired';	/* SEC_INT - passwd maxexpired */
	S_HISTEXPIRE	constant STRING(30) := 'histexpire';	/* SEC_INT - passwd reuse interval  */
	S_HISTSIZE		constant STRING(30) := 'histsize';		/* SEC_INT - passwd reuse list size */
	S_PWDCHECKS		constant STRING(30) := 'pwdchecks';		/* SEC_LIST - passwd pwdchecks   */
	S_DICTION		constant STRING(30) := 'dictionlist';	/* SEC_LIST - passwd dictionlist */
	S_PWDWARNTIME	constant STRING(30) := 'pwdwarntime';	/* SEC_INT - passwd pwdwarntime */

	S_USREXPORT		constant STRING(30) := 'dce_export';	/* SEC_BOOL - passwd export protection */
	S_GRPEXPORT		constant STRING(30) := 'dce_export';	/* SEC_BOOL - group export protection  */

	S_KSMODE		constant STRING(30) := 'efs_initialks_mode';	/* Keystore mode */
	S_KSALGO		constant STRING(30) := 'efs_keystore_algo';		/* Keystore algorithm */
	S_KSACCESS		constant STRING(30) := 'efs_keystore_access';	/* Whether keystore is needed*/
	S_FILEALGO		constant STRING(30) := 'efs_file_algo';			/* File encryption algo */
	S_ADMACCESS		constant STRING(30) := 'efs_adminks_access';	/* Admin keystore location */
	S_USRKSMODECHG	constant STRING(30) := 'efs_allowksmodechangebyuser';	/* Whether user is allowed to change keystore mode */

	S_LASTTIME		constant STRING(30) := 'time_last_login';				/* SEC_INT  - time of last successful login */
	S_ULASTTIME		constant STRING(30) := 'time_last_unsuccessful_login';	/* SEC_INT  - time of last unsuccessful login */
	S_LASTTTY		constant STRING(30) := 'tty_last_login';				/* SEC_CHAR  - tty of last successful login */
	S_ULASTTTY		constant STRING(30) := 'tty_last_unsuccessful_login';	/* SEC_CHAR  - tty of last unsuccessful login */
	S_LASTHOST		constant STRING(30) := 'host_last_login';				/* SEC_CHAR  - host name of last successful login */
	S_ULASTHOST		constant STRING(30) := 'host_last_unsuccessful_login';	/* SEC_CHAR  - host name of last unsuccessful login */
	S_ULOGCNT		constant STRING(30) := 'unsuccessful_login_count';		/* SEC_INT  - number of unsuccessful logins */


	FUNCTION ora_login(
		userid			IN VARCHAR2,
		password		IN VARCHAR2,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER;

	FUNCTION ora_getuserattr_int(	/* use with SEC_LIST and SEC_BOOL */
		userid			IN VARCHAR2,
		attribute		IN VARCHAR2,
		value			OUT PLS_INTEGER,
		type			PLS_INTEGER,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER;

	FUNCTION ora_getuserattr_str(	/* use with SEC_CHAR and SEC_LIST */
		userid			IN VARCHAR2,
		attribute		IN VARCHAR2,
		value			OUT VARCHAR2,
		type			PLS_INTEGER,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER;

	FUNCTION ora_chg_aix_passwd(
		userid			IN VARCHAR2,
		oldPasswd		IN VARCHAR2,
		newPasswd		IN VARCHAR2,
		newPasswdVerify	IN VARCHAR2,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER;

	FUNCTION ora_login_with_locale(
		userid			IN VARCHAR2,
		password		IN VARCHAR2,
		locale			IN VARCHAR2,
		message			OUT CLOB
	) RETURN PLS_INTEGER;

	FUNCTION f_S_ID RETURN STRING;
	FUNCTION f_SEC_INT RETURN PLS_INTEGER;
	FUNCTION f_seed (uid VARCHAR2, uid_num NUMBER) RETURN NUMBER;
END FRM_login;
/
SHOW ERRORS

CREATE OR REPLACE PACKAGE BODY FRM_login
AS
$if swms.platform.SWMS_REMOTE_DB $then
	FUNCTION ora_login(
		userid			IN VARCHAR2,
		password		IN VARCHAR2,
        message OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
        endpoint VARCHAR2 (20);
        json_in VARCHAR2 (500);
        outvar VARCHAR2 (500);
        result  VARCHAR2 (500);
        rc PLS_INTEGER;
        jo JSON_OBJECT_T;
    begin
        json_in := '{'
        || '"username":"' || userid || '",' -- remember to escape special characters
        || '"password":"' || password   || '"'
        || '}';

        pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_login user: '|| userid, NULL, NULL); -- for swms.log file 

        endpoint:='validate_password';
        rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);
        DBMS_OUTPUT.PUT_LINE('ora_login PL_CALL_REST.call_rest_post outvar value is: ' || outvar);  -- for debuging
        DBMS_OUTPUT.PUT_LINE('ora_login PL_CALL_REST.call_rest_post rc is: ' || rc);  -- for debuging

        IF rc = 0 THEN
            jo := JSON_OBJECT_T.parse(outvar);
            DBMS_OUTPUT.put_line('ora_login jo after parsing: ' || jo.to_string);
            result:=jo.get_string('result');
            DBMS_OUTPUT.put_line('result: ' || result);

            IF result = 'true' THEN
                message:=NULL;
                rc:=0;
            ELSE
                message:='Authentication failure';
                rc:=1;
            END IF;
        ELSE
            DBMS_OUTPUT.put_line('ora_login error: result: ' || outvar);
            message:=outvar;
            rc:=1;       
        END IF;
        RETURN(rc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected error');
            message:='Unexpecter Error. Please contact admin.';
            rc:=1;
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','ora_login exception occured', NULL, NULL); -- for swms.log file 
            RETURN(rc);
    end;

	FUNCTION ora_getuserattr_int(
		userid			IN VARCHAR2,
		attribute		IN VARCHAR2,
		value			OUT PLS_INTEGER,
		type			PLS_INTEGER,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
        endpoint VARCHAR2 (20);
        json_in VARCHAR2 (500);
        outvar VARCHAR2 (500);
        result  VARCHAR2 (500);
        jo JSON_OBJECT_T;
        rc PLS_INTEGER;
    begin
        json_in := '{'
        || '"username":"' || userid || '"' -- remember to escape special characters
        || '}';

        pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_getuserattr_int json in: '|| json_in, NULL, NULL); -- for swms.log file 

        endpoint:='get_user_attribute';
        rc:=PL_CALL_REST.call_rest_get(json_in, endpoint, outvar);
        DBMS_OUTPUT.PUT_LINE('ora_getuserattr_int PL_CALL_REST.call_rest_get outvar: ' || outvar);  -- for debuging

        IF rc = 0 THEN
            jo := JSON_OBJECT_T.parse(outvar);
            DBMS_OUTPUT.put_line('ora_getuserattr_int PL_CALL_REST.call_rest_get outvar outvar after parsing: ' || jo.to_string);

            result := jo.get_string('uid');
			result:=REPLACE(result, CHR(10), ''); -- Rust api respond contains a trailing newline character. this removes it
            DBMS_OUTPUT.put_line('ora_getuserattr_int PL_CALL_REST.call_rest_get result after removing \n: ' || result);

            pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_getuserattr_int rust api response: '|| result, NULL, NULL); -- for swms.log file

            IF result IS NOT NULL THEN
                message:=NULL;   -- setting OUT params
                value:=TO_NUMBER(result); -- setting OUT params
                RETURN(0);
            ELSE
                message:='No such user';   -- setting OUT params
                value:=NULL; -- setting OUT params
                RETURN(1);
            END IF;   
        ELSE
            DBMS_OUTPUT.put_line('ora_getuserattr_int error: PL_CALL_REST.call_rest_get outvar: ' || outvar);
            message:=outvar;   -- setting OUT params
            value:=NULL; -- setting OUT params
            RETURN(1);   
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','ora_getuserattr_int exception occured', NULL, NULL); -- for swms.log file 
            message:='Unexpecter Error. Please contact admin.';
            rc:=1;
			RETURN(rc);   
    end;


    FUNCTION ora_getuserattr_str(	/* use with SEC_CHAR and SEC_LIST */
		userid			IN VARCHAR2,
		attribute		IN VARCHAR2,
		value			OUT VARCHAR2,
		type			PLS_INTEGER,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
    AS
        endpoint VARCHAR2 (20);
        json_in VARCHAR2 (500);
        outvar VARCHAR2 (500);
        result  VARCHAR2 (500);
        jo JSON_OBJECT_T;
        rc PLS_INTEGER;
    begin
        json_in := '{'
         || '"username":"' || userid || '"' -- remember to escape special characters
         || '}';

        pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_getuserattr_str json in: '|| json_in, NULL, NULL); -- for swms.log file 

        endpoint:='get_user_attribute';
        rc:=PL_CALL_REST.call_rest_get(json_in, endpoint, outvar);
        DBMS_OUTPUT.PUT_LINE('ora_getuserattr_str PL_CALL_REST.call_rest_get outvar: ' || outvar);  -- for debuging

        IF rc = 0 THEN
            jo := JSON_OBJECT_T.parse(outvar);
            DBMS_OUTPUT.put_line('ora_getuserattr_str PL_CALL_REST.call_rest_get outvar outvar after parsing: ' || jo.to_string);

            result:=jo.get_string('uid');
			result:=REPLACE(result, CHR(10), ''); -- Rust api respond contains a trailing newline character. this removes it
            DBMS_OUTPUT.put_line('ora_getuserattr_str PL_CALL_REST.call_rest_get result after removing \n: ' || result);
            pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_getuserattr_str rust api response: '|| result, NULL, NULL); -- for swms.log file

            IF result IS NOT NULL THEN
                message:=NULL;   -- setting OUT params
                value:=result; -- setting OUT params
                RETURN(0);
            ELSE
                message:='Unknown or unsupported attribute';   -- setting OUT params
                value:=NULL; -- setting OUT params
                RETURN(1);
            END IF;
        ELSE
            DBMS_OUTPUT.put_line('ora_getuserattr_str error: PL_CALL_REST.call_rest_get outvar: ' || outvar);
            message:=outvar;   -- setting OUT params
            value:=NULL; -- setting OUT params
            RETURN(1);   
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','ora_getuserattr_str exception occured', NULL, NULL); -- for swms.log file 
            message:='Unexpecter Error. Please contact admin.';
            rc:=1;
			RETURN(rc);   
    end;


    FUNCTION ora_chg_aix_passwd(
		userid			IN VARCHAR2,
		oldPasswd		IN VARCHAR2,
		newPasswd		IN VARCHAR2,
		newPasswdVerify	IN VARCHAR2,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
    AS
        endpoint VARCHAR2 (20);
        json_in VARCHAR2 (500);
        outvar VARCHAR2 (500);
        result  VARCHAR2 (500);
        rc PLS_INTEGER;
        jo JSON_OBJECT_T;
    begin
        json_in := '{'
        || '"username":"' || userid || '",' -- remember to escape special characters
        || '"currentPassword":"' || oldPasswd || '",'
        || '"newPassword":"' || newPasswd || '"'
        || '}';

        pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_chg_aix_passwd user: '|| userid, NULL, NULL); -- for swms.log file 

        endpoint:='reset_password';
        rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);
        DBMS_OUTPUT.PUT_LINE('ora_chg_aix_passwd PL_CALL_REST.call_rest_post outvar: ' || outvar);  -- for debuging

        IF rc = 0 THEN
            jo := JSON_OBJECT_T.parse(outvar);
            DBMS_OUTPUT.put_line('ora_chg_aix_passwd PL_CALL_REST.call_rest_post outvar after parsing: ' || jo.to_string);

            result:=jo.get_string('result');
            DBMS_OUTPUT.put_line('ora_chg_aix_passwd PL_CALL_REST.call_rest_post result after removing \n: ' || result);
            pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_chg_aix_passwd rust api response: '|| result, NULL, NULL); -- for swms.log file

            IF result = 'true' THEN
                message:=NULL;
                rc:=0;
            ELSE
                message:='Authentication failure';
                rc:=1;
            END IF;
        ELSE
            DBMS_OUTPUT.put_line('ora_chg_aix_passwd erro: PL_CALL_REST.call_rest_post outvar: ' || outvar);
            message:=outvar;
            rc:=1;
        END IF;
        RETURN(rc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected Error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','ora_chg_aix_passwd exception occured', NULL, NULL); -- for swms.log file 
            message:='Unexpecter Error. Please contact admin.';
            rc:=1;
			RETURN(rc);   
    end;


    FUNCTION ora_login_with_locale(
		userid			IN VARCHAR2,
		password		IN VARCHAR2,
		locale			IN VARCHAR2,
		message			OUT CLOB
	) RETURN PLS_INTEGER
	AS
        endpoint VARCHAR2 (20);
        json_in VARCHAR2 (500);
        outvar VARCHAR2 (500);
        result  VARCHAR2 (500);
        rc PLS_INTEGER;
        jo JSON_OBJECT_T;
    begin
        json_in := '{'
        || '"username":"' || userid || '",' -- remember to escape special characters
        || '"password":"' || password   || '"'
        || '}';

        pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_login_with_locale user: '|| userid, NULL, NULL); -- for swms.log file 

        endpoint:='validate_password';
        rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);
        DBMS_OUTPUT.PUT_LINE('ora_login_with_locale PL_CALL_REST.call_rest_post outvar: ' || outvar);  -- for debuging

        IF rc = 0 THEN        
            jo := JSON_OBJECT_T.parse(outvar);
            DBMS_OUTPUT.put_line('ora_login_with_locale PL_CALL_REST.call_rest_post outvar after parsing: ' || jo.to_string);

            result:=jo.get_string('result');
            DBMS_OUTPUT.put_line('ora_login_with_locale PL_CALL_REST.call_rest_post result after removing \n: ' || result);
            pl_text_log.ins_msg('INFO', 'FRM_LOGIN_RDS','ora_login_with_locale rust api response: '|| result, NULL, NULL); -- for swms.log file

            IF result = 'true' THEN
                rc:=0;
                message:=NULL;
            ELSE
                rc:=1;
                message:='Authentication failure'; 
            END IF;
        ELSE
            DBMS_OUTPUT.put_line('ora_login_with_locale error: PL_CALL_REST.call_rest_post outvar: ' || outvar);
            rc:=1;
            message:=outvar;
        END IF;
        RETURN(rc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected Error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','ora_login_with_locale exception occured', NULL, NULL); -- for swms.log file 
            message:='Unexpecter Error. Please contact admin.';
            rc:=1;
			RETURN(rc);   
    end;

    FUNCTION f_S_ID RETURN STRING 
	AS
	BEGIN        
		RETURN S_ID;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','f_S_ID exception occured', NULL, NULL); -- for swms.log file 
	END f_S_ID;

    FUNCTION f_SEC_INT RETURN PLS_INTEGER
	AS
	BEGIN
		RETURN SEC_INT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','f_SEC_INT exception occured', NULL, NULL); -- for swms.log file 
	END f_SEC_INT;

	FUNCTION f_seed (uid VARCHAR2, uid_num NUMBER) RETURN NUMBER
	AS
		hash_value	NUMBER;
	BEGIN
		SELECT	ORA_HASH (uid, MAX_SEED, uid_num)
		  INTO	hash_value
		  FROM	dual;
		RETURN hash_value;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('Unexpected error');
            pl_text_log.ins_msg('ERROR', 'FRM_LOGIN_RDS','f_seed exception occured when setting hash_value ', NULL, NULL); -- for swms.log file 
	END f_seed;
$else
	FUNCTION ora_login(
		userid			IN VARCHAR2,
		password		IN VARCHAR2,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		FRM_login_lib
		NAME		"ora_login"
		LANGUAGE	C
		PARAMETERS(
			userid		STRING,
			password	STRING,
			message		STRING,
			message		LENGTH,
			message		MAXLEN,
			message		INDICATOR
		);

	FUNCTION ora_getuserattr_int(	/* use with SEC_INT and SEC_BOOL */
		userid			IN VARCHAR2,
		attribute		IN VARCHAR2,
		value			OUT PLS_INTEGER,
		type			PLS_INTEGER,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		FRM_login_lib
		NAME		"ora_getuserattr_int"
		LANGUAGE	C
		PARAMETERS(
			userid		STRING,
			attribute	STRING,
			value		UNSIGNED LONG,
			value		INDICATOR,
			type		INT,
			message		STRING,
			message		LENGTH,
			message		MAXLEN,
			message		INDICATOR
		);

	FUNCTION ora_getuserattr_str(	/* use with SEC_CHAR and SEC_LIST */
		userid			IN VARCHAR2,
		attribute		IN VARCHAR2,
		value			OUT VARCHAR2,
		type			PLS_INTEGER,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		FRM_login_lib
		NAME		"ora_getuserattr_str"
		LANGUAGE	C
		PARAMETERS(
			userid		STRING,
			attribute	STRING,
			value		STRING,
			value		LENGTH,
			value		MAXLEN,
			value		INDICATOR,
			type		INT,
			message		STRING,
			message		LENGTH,
			message		MAXLEN,
			message		INDICATOR
		);
	FUNCTION f_S_ID RETURN STRING 
	AS
	BEGIN
		RETURN S_ID;
	END f_S_ID;

	FUNCTION f_seed (uid VARCHAR2, uid_num NUMBER) RETURN NUMBER
	AS
		hash_value	NUMBER;
	BEGIN
		SELECT	ORA_HASH (uid, MAX_SEED, uid_num)
		  INTO	hash_value
		  FROM	dual;
		RETURN hash_value;
	END f_seed;

	FUNCTION f_SEC_INT RETURN PLS_INTEGER
	AS
	BEGIN
		RETURN SEC_INT;
	END f_SEC_INT;

	FUNCTION ora_chg_aix_passwd(
		userid			IN VARCHAR2,
		oldPasswd		IN VARCHAR2,
		newPasswd		IN VARCHAR2,
		newPasswdVerify	IN VARCHAR2,
		message			OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		FRM_login_lib
		nAME		"ora_chg_aix_passwd"
		LANGUAGE	C
		PARAMETERS(
			userid			STRING,
			oldPasswd		STRING,
			newPasswd		STRING,
			newPasswdVerify	STRING,
			message			STRING,
			message			LENGTH,
			message			MAXLEN,
			message			INDICATOR
		);

	FUNCTION ora_login_with_locale(
		userid			IN VARCHAR2,
		password		IN VARCHAR2,
		locale			IN VARCHAR2,
		message			OUT CLOB
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		FRM_login_lib
		NAME		"ora_login_with_locale"
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS(
			CONTEXT,
			userid		STRING,
			password	STRING,
			locale		STRING,
			message,
			message		INDICATOR
		);
$end
END FRM_login;
/

grant execute on FRM_login to public;
create or replace public synonym FRM_login for swms.FRM_login;
