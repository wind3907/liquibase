CREATE OR REPLACE  PROCEDURE "SWMS"."LOAD_BLOB_TABLE_PROC"
    (p_filename IN VARCHAR2) AS
$if swms.platform.SWMS_REMOTE_DB $then
  src_file            VARCHAR2 (256) := '/tmp/swms/reports/' || p_filename;
  endpoint            VARCHAR2 (20);
  json_in             VARCHAR2 (500);
  outvar              VARCHAR2 (500);
  result              VARCHAR2 (500);
  jo                  JSON_OBJECT_T;
  rc                  NUMBER;
  REPORT_LOAD_FAILED  EXCEPTION;
  POST_REQUEST_FAILED EXCEPTION;
BEGIN
  json_in := '{'
    || '"command":"source /swms/base/bin/java_tool_profile;' 
    || 'java -Djava.security.egd=file:/dev/./urandom -Dsecurerandom.source=file:/dev/./urandom -jar /swms/base/bin/swms-java-tools-1.0-SNAPSHOT.jar LOAD_REPORT_DATA ' || src_file || '"' 
    || '}';
  
  endpoint:='execute';
  rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);
  
  IF rc != 0 THEN
    RAISE POST_REQUEST_FAILED;
  END IF;
  
  jo := JSON_OBJECT_T.parse(outvar);
  result:=jo.get_string('result');
  
  IF REPLACE(result, CHR(10), '') != 'success' THEN
    RAISE REPORT_LOAD_FAILED;
  END IF;
	pl_text_log.ins_msg('INFO', 'LOAD_BLOB_TABLE_PROC', 'LOAD_BLOB_TABLE_PROC success', NULL, NULL);
EXCEPTION
  WHEN POST_REQUEST_FAILED THEN
    pl_text_log.ins_msg('FATAL', 'LOAD_BLOB_TABLE_PROC', 'POST Request Failed. rc=[' || rc || ']', NULL, NULL);
  WHEN REPORT_LOAD_FAILED THEN
    pl_text_log.ins_msg('FATAL', 'LOAD_BLOB_TABLE_PROC', 'Failed inserting report into report_data table. return=[' || result || ']', NULL, NULL);
  WHEN OTHERS THEN
    pl_text_log.ins_msg('FATAL', 'LOAD_BLOB_TABLE_PROC', 'Procedure execution failed. src_file=[' || src_file || ']', NULL, NULL);
END;
$else
  src_file  BFILE := BFILENAME('CLOB_REPORT_DIR', p_filename);
  dest_clob CLOB;
  v_id NUMBER;
  dest_offset INTEGER := 1;
  src_offset INTEGER := 1;
  lang_context INTEGER := 0;
  warning INTEGER;
BEGIN
  SELECT NVL(MAX(ID)+1,1) INTO v_id FROM report_data;
  dbms_output.put_line('V-ID in REPORT_DATA table: [' || to_char(v_id) || ']');
  INSERT INTO report_data VALUES(v_id, p_filename, EMPTY_CLOB())
     RETURNING text INTO dest_clob;
  DBMS_LOB.OPEN(src_file, DBMS_LOB.LOB_READONLY);
  DBMS_LOB.LoadClobFromFile( DEST_LOB     => dest_clob,
                             SRC_BFILE    => src_file,
                             AMOUNT       => DBMS_LOB.LOBMAXSIZE,
                             DEST_OFFSET  => dest_offset,
                             SRC_OFFSET   => src_offset,
                             BFILE_CSID   => DBMS_LOB.DEFAULT_CSID,
                             LANG_CONTEXT => lang_context,
                             WARNING      => warning );
  DBMS_LOB.CLOSE(src_file);
  COMMIT;
  dbms_output.put_line ('dest_offset = [' || to_char(dest_offset) || ']  src_offset = [' || to_char(src_offset) ||
                        ']  lang_context = [' || to_char(lang_context) || ']');
  dbms_output.put_line ('warning = [' || to_char(warning) || ']');
END;
$end
/
