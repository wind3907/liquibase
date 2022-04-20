-- Package and library to call the queue operations C function from Oracle Form
-- Created by Infosys on 9/11/15


BEGIN
$if dbms_db_version.ver_le_11 $then
	EXECUTE IMMEDIATE 'create or replace library swms.queue_ops_lib as ''/swms/curr/lib/lib_queueops.so''';
$else
	EXECUTE IMMEDIATE 'create or replace library swms.queue_ops_lib as ''/swms/curr/lib/lib_queueops.so'' AGENT ''EXTPROC_LINK''';
$end
END;
/
show sqlcode
show errors

CREATE OR REPLACE PACKAGE SWMS.queue_ops
AS
	FUNCTION queue_ops(	 
		opt		    	IN BINARY_INTEGER,
		queue_name		IN VARCHAR2,
                message                 OUT VARCHAR2
	) RETURN BINARY_INTEGER;

END queue_ops;
/
SHOW ERRORS

CREATE OR REPLACE PACKAGE BODY SWMS.queue_ops
AS
$if swms.platform.SWMS_REMOTE_DB $then
	FUNCTION queue_ops(
		opt           IN  BINARY_INTEGER,
		queue_name    IN  VARCHAR2,
		message       OUT VARCHAR2
	) RETURN BINARY_INTEGER
	AS
		endpoint            VARCHAR2 (20);
		json_in             VARCHAR2 (500);
		outvar              VARCHAR2 (500);
		result              VARCHAR2 (500);
		jo                  JSON_OBJECT_T;
		rc                  NUMBER:= 0;
		rest_code           NUMBER:= 0;
		call_rest           NUMBER:= 0;
		command             VARCHAR2 (500);
		POST_REQUEST_FAILED EXCEPTION;
	BEGIN
		CASE
			WHEN opt = 0 THEN
				command := 'lpstat -p ' || queue_name;
				call_rest := 1;
			WHEN opt = 1 THEN
				command := '/usr/sbin/cupsenable ' || queue_name;
				call_rest := 1;
			WHEN opt = 2 THEN
				command := '/usr/sbin/cupsdisable ' || queue_name;
				call_rest := 1;
			WHEN opt = 3 THEN
				command := 'lprm -P ' || queue_name || ' -' ;
				call_rest := 1;
			WHEN opt = 4 THEN
				command := '/ts/curr/bin/flash_mem_maint ' || queue_name || ' download;/ts/curr/bin/flash_mem_maint ' || queue_name || ' format';
				call_rest := 1;
			WHEN opt = 5 THEN
				command := 'sudo systemctl restart cups; sudo systemctl status cups;';
				call_rest := 1;
			WHEN opt = 6 THEN
				pl_text_log.ins_msg('WARN', 'queue_ops', 'Entering to print the document[' || queue_name || ']', NULL, NULL);
			ELSE
				pl_text_log.ins_msg('WARN', 'queue_ops', 'Option not understandable -' || opt, NULL, NULL);
		END CASE;

		IF call_rest = 1 THEN
			json_in := '{'
				|| '"command":"' || command || '"'
				|| '}';
			endpoint := 'execute';
			rest_code := PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);
			
			IF rest_code != 0 THEN
				RAISE POST_REQUEST_FAILED;
			END IF;

			jo := JSON_OBJECT_T.parse(outvar);
			result := jo.get_string('result');
			rc := jo.get_string('code');
			message := REPLACE(result, CHR(10), '.');
			
			pl_text_log.ins_msg('INFO', 'queue_ops', 'Message[' ||  message || '] length[' || LENGTH(message) || ']', NULL, NULL);
			pl_text_log.ins_msg('INFO', 'queue_ops', 'completing queue_op with rc[' || rc|| ']', NULL, NULL);
		END IF;
		return (rc);
	EXCEPTION
		WHEN POST_REQUEST_FAILED THEN
			rc:= 1;
			message:= 'Unexpected Error. Please contact admin.';
			pl_text_log.ins_msg('FATAL', 'queue_ops', 'POST Request Failed json_in=[' || json_in || ']', NULL, NULL);
			return (rc);
		WHEN OTHERS THEN
			rc:= 1;
			message:= 'Unexpected Error. Please contact admin.';
			pl_text_log.ins_msg('FATAL', 'queue_ops', 'Failed Parsing Response=[' || outvar || ']', NULL, NULL);
			return (rc);
	END;
$else
        FUNCTION queue_ops(	 
		opt		    	IN BINARY_INTEGER,
		queue_name		IN VARCHAR2,
                message                 OUT VARCHAR2
   	) RETURN BINARY_INTEGER  
	AS
		EXTERNAL
		LIBRARY		queue_ops_lib
		NAME		"queue_ops"
		LANGUAGE	C
		PARAMETERS(
			opt		INT,
			queue_name	STRING,
                        message         STRING,
                        message         LENGTH,
                        message         MAXLEN,
                        message         INDICATOR
		);
$end
END queue_ops;
/
SHOW ERRORS
grant execute on swms.queue_ops to public;
grant execute on swms.queue_ops_lib to public;
create or replace public synonym queue_ops for swms.queue_ops;
grant execute on queue_ops to public;
grant execute on queue_ops_lib to public;
commit;
