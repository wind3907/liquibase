create or replace PACKAGE SWMS.PL_CALL_REST
AS
    FUNCTION call_rest_get(
		params     IN    VARCHAR2,
        endpoint   IN    VARCHAR2,
        result     OUT   VARCHAR2
	) RETURN PLS_INTEGER;

    FUNCTION call_rest_post(
		json_in    IN   VARCHAR2,
        endpoint   IN   VARCHAR2,
        result     OUT  VARCHAR2
	) RETURN PLS_INTEGER;

END PL_CALL_REST;
/

create or replace PACKAGE BODY SWMS.PL_CALL_REST
AS
  
-- PL_CALL_REST package
--   Return codes
--          0 : success
--          1 : failure - http status <> 200 || exception

    function create_url(
        params     IN    VARCHAR2,
        endpoint   IN    VARCHAR2
    ) RETURN VARCHAR2 AS
    $if swms.platform.SWMS_REMOTE_DB $then
        url                  VARCHAR2(100);
        params_as_json_obj   json_object_t;
        param_keys           json_key_list;
        l_swms_host_syspar   sys_config.config_flag_val%TYPE;
    $end
    BEGIN
    $if swms.platform.SWMS_REMOTE_DB $then
        l_swms_host_syspar := pl_common.f_get_syspar('SWMS_HOST', 'localhost');

        url:='http://' || l_swms_host_syspar || ':8088/remotedb/' || endpoint;
               
        IF params IS NOT NULL then       
            url:=url|| '?'; -- SHORT DNS NOT WORKING
            params_as_json_obj := json_object_t.parse(params); -- converting parameter json string to a json object
            param_keys := params_as_json_obj.get_keys; -- get the paramter keys
            FOR i IN 1..param_keys.count LOOP  -- prepare the query string parameters from the params json
                url := url || param_keys(i) || '=' || params_as_json_obj.get_string(param_keys(i));
                IF param_keys.next(i) IS NOT NULL THEN
                    url := url || '&';
                END IF;
            END LOOP;
        END IF;

        RETURN url;
    $else
        DBMS_OUTPUT.PUT_LINE('add file function is only required when DB is remote'); 
    $end
    END;


  FUNCTION call_rest_get(
		params     IN    VARCHAR2,
        endpoint   IN    VARCHAR2,
        result     OUT   VARCHAR2
	) RETURN PLS_INTEGER AS
        req                  UTL_HTTP.REQ;
        resp                 UTL_HTTP.RESP;
        resp_string          VARCHAR2(500);
        url                  VARCHAR2(100);
    BEGIN
        url := create_url(params,endpoint);
        
        req := UTL_HTTP.BEGIN_REQUEST(
            url => url,
            method => 'GET', 
            http_version => 'HTTP/1.1'
        );

        pl_text_log.ins_msg('INFO', 'CALL_REST_GET', 'CALL_REST_GET - REQ URL: ' || url,  sqlcode, sqlerrm); -- for swms.log file

        UTL_HTTP.SET_HEADER(req, 'content-type', 'application/json'); 

        resp := UTL_HTTP.GET_RESPONSE(req);

        IF resp.status_code = '200' AND resp.reason_phrase = 'OK' 
        THEN
            BEGIN
                LOOP
                    UTL_HTTP.READ_LINE(resp, resp_string, true); -- read the response body
                    result := result || resp_string;   --- setting the response body to OUT parameter "restul"
                END LOOP;
                UTL_HTTP.END_RESPONSE(resp);
            EXCEPTION
                WHEN UTL_HTTP.end_of_body THEN
                    UTL_HTTP.END_RESPONSE(resp);
            END;
            pl_text_log.ins_msg('INFO', 'CALL_REST_GET', 'CALL_REST_GET - RESPONSE MSG: ' || result,  sqlcode, sqlerrm); -- for swms.log file
            RETURN(0);
        ELSE
            pl_text_log.ins_msg('FATAL', 'CALL_REST_GET', 'CALL_REST_GET - resp.status_code=[' || resp.status_code || '] ' || resp.reason_phrase ,  sqlcode, sqlerrm); -- for swms.log file
            pl_text_log.ins_msg('FATAL', 'CALL_REST_GET', 'CALL_REST_GET - Req not success : '||url ,  sqlcode, sqlerrm);
            result := resp.reason_phrase;
            RETURN(1);
        END IF;

    EXCEPTION
      WHEN OTHERS THEN
        BEGIN
          pl_text_log.ins_msg('FATAL', 'CALL_REST_GET', 'CALL_REST_GET - UTL_HTTP EXCEPTION MSG: ' || UTL_HTTP.get_detailed_sqlerrm
          ,  sqlcode, sqlerrm);
          pl_text_log.ins_msg('FATAL', 'CALL_REST_GET', 'CALL_REST_GET - Req Failed : ' || url ,  sqlcode, sqlerrm);
          result:=sqlerrm;
          RETURN(1);
        END;
        UTL_HTTP.END_RESPONSE(resp);
  END call_rest_get;

  FUNCTION call_rest_post(
		json_in    IN   VARCHAR2,
        endpoint   IN   VARCHAR2,
        result     OUT  VARCHAR2
	) RETURN PLS_INTEGER AS
        req             UTL_HTTP.REQ;
        resp            UTL_HTTP.RESP;
        resp_string     VARCHAR2(500);
        url             VARCHAR2(100);
    BEGIN
        url := create_url(NULL,endpoint); -- DNS NOT WORKING
        
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);
        
        req := UTL_HTTP.BEGIN_REQUEST (
        url    => url,
        method => 'POST'
        );

        UTL_HTTP.SET_HEADER( req, 'content-type', 'application/json' );
        UTL_HTTP.SET_HEADER( req, 'Content-Length', length(json_in) );
        UTL_HTTP.WRITE_TEXT( r => req, data => json_in );

        UTL_HTTP.set_persistent_conn_support(req, FALSE);
        pl_text_log.ins_msg('INFO', 'CALL_REST_POST','CALL_REST_POST - REQ URL: ' || URL,  sqlcode, sqlerrm); -- for swms.log file
        
        resp := UTL_HTTP.GET_RESPONSE(req);

        IF resp.status_code = '200' AND resp.reason_phrase = 'OK' 
        THEN
            BEGIN
                LOOP
                    UTL_HTTP.READ_LINE( resp, resp_string, TRUE ); -- read the response body
                    result:= result || resp_string;   --- setting the response body to OUT parameter "restul"
                END LOOP;
                UTL_HTTP.END_RESPONSE(resp);
            EXCEPTION
                WHEN UTL_HTTP.end_of_body THEN
                    UTL_HTTP.END_RESPONSE(resp);
            END;
            pl_text_log.ins_msg('INFO', 'CALL_REST_POST','CALL_REST_POST - RESPONSE MSG: '|| result ,  sqlcode, sqlerrm); -- for swms.log file
            RETURN(0);
        ELSE
            pl_text_log.ins_msg('FATAL', 'CALL_REST_POST','CALL_REST_POST - Resp.status_code=['|| resp.status_code || ']' || resp.reason_phrase ,  sqlcode, sqlerrm);
            IF endpoint != 'validate_password' THEN
                pl_text_log.ins_msg('FATAL', 'CALL_REST_POST','CALL_REST_POST - Req not success : '||endpoint||' for payload : '||json_in ,  sqlcode, sqlerrm);
            END IF;
            result := resp.reason_phrase;
            RETURN(1);
        END IF;

        EXCEPTION
            WHEN OTHERS THEN
            BEGIN
              pl_text_log.ins_msg('FATAL', 'CALL_REST_POST', 'CALL_REST_POST - UTL_HTTP EXCEPTION MSG: ' || UTL_HTTP.get_detailed_sqlerrm,  sqlcode, sqlerrm);
              IF endpoint != 'validate_password' THEN
                pl_text_log.ins_msg('FATAL', 'CALL_REST_POST', 'CALL_REST_POST - Req Failed : ' ||endpoint||' for payload : '||json_in ,  sqlcode, sqlerrm);
              END IF;
              result:=sqlerrm;
              RETURN(1);
            END;
            UTL_HTTP.END_RESPONSE(resp);
  END call_rest_post;
  
END PL_CALL_REST;
/
show errors;

grant execute on SWMS.PL_CALL_REST to public;
create or replace public synonym PL_CALL_REST for SWMS.PL_CALL_REST;
