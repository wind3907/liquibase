create or replace PACKAGE      swms.PL_EQUIP_OUT
AS
  ---------------------------------------------------------------------------
  -- Package Name:
  --   PL_EQUIP_OUT
  -- Description:
  --    This package sends equip failure to EAI
  --    This package is called by  trigger.
  -- Modification History:
  --    Date     Designer Comments
  -- Procedure:
  --    equip_out_eai
  ---------------------------------------------------------------------------
  PROCEDURE equip_out_eai(p_seq_no          IN sap_equip_out.sequence_number%type,
                          p_equip_id        IN sap_equip_out.equip_id%type, 
                          p_equip_name      IN sap_equip_out.equip_name%type ,
                          p_add_user        IN sap_equip_out.add_user%type, 
                          p_inspection_date IN sap_equip_out.inspection_date%type );
  
  
    PROCEDURE equip_in_eai(p_seq_no          IN sap_equip_out.sequence_number%type,
                          p_equip_id        IN sap_equip_out.equip_id%type, 
                          p_equip_name      IN sap_equip_out.equip_name%type ,
                          p_add_user        IN sap_equip_out.add_user%type, 
                          p_inspection_date IN sap_equip_out.inspection_date%type,
                          p_content         OUT Varchar2);
  
 END PL_EQUIP_OUT;
 /
create or replace PACKAGE BODY swms.PL_EQUIP_OUT
IS
  ---------------------------------------------------------------------------
  -- Package Name:
  --   PL_EQUIP_OUT
  -- Description:
  --    This package generate files in /swms/data
  --    This package is called by trg_insupd_lxlisho_brow.
  -- Modification History:
  --    Date     Designer Comments
  --   04/10/2017 pdas8114 Initial Version
  --   05/03/2017 vkal9662 Exceptions and Alerts added to the process
  -- Procedure:
  --    equip_out_eai
  --
  -- Description:
  --
  ---------------------------------------------------------------------------
  PROCEDURE add_alert(
      p_add_user SAP_EQUIP_OUT.add_user%type,
      p_message SWMS_FAILURE_EVENT.MSG_BODY%type,
      p_unique_id SWMS_FAILURE_EVENT.UNIQUE_ID%type)
  IS
  BEGIN
    BEGIN
      INSERT
      INTO SWMS_FAILURE_EVENT
        (
          ALERT_ID,
          MODULES,
          ERROR_TYPE,
          UNIQUE_ID,
          STATUS,
          MSG_SUBJECT,
          MSG_BODY,
          ADD_DATE,
          ADD_USER
        )
        VALUES
        (
          failure_seq.NEXTVAL,
          'PL_SWMS_TO_SPROCKET',
          'WARN',
          p_unique_id,-- change this later
          'E',
          'Error passing data from swms to sprocket',
          p_message,
          sysdate,
          p_add_user
        );
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line ('Error inserting in to SWMS_FAILURE_EVENT:'||SQLERRM);
    END;
  END add_alert;
  PROCEDURE equip_in_eai
    (
      p_seq_no          IN sap_equip_out.sequence_number%type,
      p_equip_id        IN sap_equip_out.equip_id%type,
      p_equip_name      IN sap_equip_out.equip_name%type ,
      p_add_user        IN sap_equip_out.add_user%type,
      p_inspection_date IN sap_equip_out.inspection_date%type,
      p_content OUT VARCHAR2
    )
  IS
    l_seq_no SAP_EQUIP_OUT.SEQUENCE_NUMBER%type;
    l_equip_id SAP_EQUIP_OUT.EQUIP_ID%type;
    l_equip_name SAP_EQUIP_OUT.EQUIP_NAME%type;
    l_add_user SAP_EQUIP_OUT.add_user%type;
    l_dcid            VARCHAR2(10);
    l_inspection_date VARCHAR2(30);
    l_date            VARCHAR2(50);
    l_http_request utl_http.req;
    l_http_response utl_http.resp;
    l_url     VARCHAR2(4000);
    name      VARCHAR2(4000);
    buffer    VARCHAR2(4000);
    l_content VARCHAR2(4000);
  BEGIN
    l_seq_no     := p_seq_no;
    l_equip_id   := p_equip_id;
    l_equip_name := p_equip_name;
    l_add_user   := p_add_user;
    BEGIN
      SELECT SUBSTR(attribute_value, 1 ,INSTR(attribute_value, ':', 1, 1)-1)
      INTO l_dcid
      FROM maintenance m
      WHERE component = 'COMPANY';
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line ('Issue retrieving Company from Maintanance table');
    END;
    dbms_output.put_line ('l_dcid'|| l_dcid);
    ---date conversion to ISO 8601 format
    --2011-12-03T10:15:30+01:00--2017-04-10T20:50:47+00:00
    BEGIN
      SELECT ((TO_CHAR(p_inspection_date,'YYYY-MM-DD')
        ||'T'
        ||TO_CHAR(p_inspection_date,'HH24:MI:SS'))
        ||TO_CHAR(SYSTIMESTAMP,'TZH:TZM')) tz
      INTO l_inspection_date
      FROM dual;
      --building string
      l_content := '{ 
"InspectionReport":[
{    
"EQUIP_ID": "'||l_equip_id||'",    
"OPCOID": "'||l_dcid||'",    
"EQUIP_NAME": "'||l_equip_name||'",    
"ADD_USER": "'||l_add_user||'",      
"INSPECTION_DATE": "'||l_inspection_date||'"    
}
]
}';
      dbms_output.put_line ('l_content:'||l_content);
      p_content:= l_content;
      dbms_output.put_line ('p_content:' || p_content);
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line ('Issue equip_in_eai');
    END;
  END equip_in_eai;
  PROCEDURE equip_out_eai(
      p_seq_no          IN sap_equip_out.sequence_number%type,
      p_equip_id        IN sap_equip_out.equip_id%type,
      p_equip_name      IN sap_equip_out.equip_name%type ,
      p_add_user        IN sap_equip_out.add_user%type,
      p_inspection_date IN sap_equip_out.inspection_date%type)
  IS
    l_seq_no SAP_EQUIP_OUT.SEQUENCE_NUMBER%type;
    l_equip_id SAP_EQUIP_OUT.EQUIP_ID%type;
    l_equip_name SAP_EQUIP_OUT.EQUIP_NAME%type;
    l_add_user SAP_EQUIP_OUT.add_user%type;
    l_http_request utl_http.req;
    l_http_response utl_http.resp;
    l_url             VARCHAR2(4000);-- := 'http://rs242si:7800/Sprocket/SWMS';
    name              VARCHAR2(4000);
    buffer            VARCHAR2(4000);
    lo_content        VARCHAR2(4000);
    l_sprocket_syspar VARCHAR2(3);
    --sos, rf,trigger on sap_equip_out, both insert and update--record_status--S when we get response, N is new--in process X
  BEGIN
    BEGIN
      -- the code for sprocket will execute only when
      -- in the SYS_Congif table config_flag_name
      --  ENBL_SWMS_SPROCKET_INTFC is set to 'Y'
      SELECT PL_COMMON.F_GET_SYSPAR('ENBL_SWMS_SPROCKET_INTFC', NULL)
      INTO l_sprocket_syspar
      FROM dual;
    EXCEPTION
    WHEN OTHERS THEN
      l_sprocket_syspar := 'N';
    END;
    
    dbms_output.put_line ('l_sprocket_syspar:'||l_sprocket_syspar);
    
    IF NVL(l_sprocket_syspar , 'N') = 'Y' THEN
      BEGIN
        SELECT 'http://'
          ||Host
          ||':'
          ||upper_port
          ||'/Sprocket/InspectionReport'
        INTO l_url
        FROM dba_network_acls
        WHERE acl = '/sys/acls/sprocket_webservice.xml';
      EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line ('Issue retrieving URL details from the ACL table');
      END;
      
      dbms_output.put_line ('URL from sql:'||l_url);
      
      equip_in_eai(p_seq_no,p_equip_id,p_equip_name,p_add_user,p_inspection_date,lo_content);
      
      dbms_output.put_line ('content from out_eai:'||lo_content);
      
      pl_log.ins_msg('INFO' , 'pl_equip_out.equip_out_eai', lo_content, 1, l_url, 'MAINTENANCE', 'pl_equip_out');
      
      l_http_request := sys.utl_http.begin_request(l_url, 'POST',' HTTP/1.1');
      
      sys.utl_http.set_header(l_http_request, 'user-agent', 'mozilla/5.0');
      sys.utl_http.set_header(l_http_request, 'content-type', 'application/json');
      sys.utl_http.set_header(l_http_request, 'Content-Length', LENGTH(lo_content));
      sys.utl_http.write_text(l_http_request, lo_content);
      
      l_http_response := sys.utl_http.get_response(l_http_request);
      
      dbms_output.put_line('Response Status Code: '||l_http_response.status_code);
      dbms_output.put_line('Response Reason: '||l_http_response.reason_phrase);
      dbms_output.put_line('Response Version: '||l_http_response.http_version);
      
      pl_log.ins_msg('INFO' , 'pl_equip_out.equip_out_eai-Http status', lo_content, l_http_response.status_code, l_http_response.reason_phrase, 'MAINTENANCE', 'pl_equip_out.equip_out_eai', 'N');
    
      BEGIN
        LOOP
          sys.UTL_HTTP.read_text(l_http_response, buffer);
          dbms_output.put_line('reading response: '||buffer);
        END LOOP;
        sys.UTL_HTTP.end_response(l_http_response);
      EXCEPTION
      WHEN UTL_HTTP.end_of_body THEN
        sys.UTL_HTTP.end_response(l_http_response);
      WHEN OTHERS THEN
        sys.UTL_HTTP.end_response(l_http_response);
        ADD_ALERT(p_add_user, 'Error communicating with Sprocket:', SQLERRM);
        pl_log.ins_msg('FATAL', 'After http call pl_equip_out.equip_out_eai', lo_content, SQLCODE, SQLERRM, 'MAINTENANCE', 'pl_equip_out.equip_out_eai', 'Y');
      END;
    END IF; -- l_sprocket_syspar = 'Y' check
  END equip_out_eai;
END PL_EQUIP_OUT;
/