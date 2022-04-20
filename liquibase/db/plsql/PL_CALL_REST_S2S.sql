create or replace PACKAGE PL_CALL_REST_S2S AS

    FUNCTION call_rest_post(
        json_in IN VARCHAR2,
        message_id IN VARCHAR2,
        result OUT VARCHAR2
    ) RETURN PLS_INTEGER;

    FUNCTION get_xdock_syspar(
        i_config_flag_name IN system_xdock_config.config_flag_name%TYPE
    ) RETURN VARCHAR2;

END PL_CALL_REST_S2S;
/

create or replace PACKAGE BODY PL_CALL_REST_S2S AS
    --  PL_CALL_REST_S2S package
--   Return codes
--          0 : success
--          1 : failure - http status <> 200 || exception
    FUNCTION call_rest_post(
        json_in IN VARCHAR2,
        message_id IN VARCHAR2,
        result OUT VARCHAR2
    ) RETURN PLS_INTEGER AS
        req                       UTL_HTTP.REQ;
        resp                      UTL_HTTP.RESP;
        resp_string               VARCHAR2(500);
        url                       VARCHAR2(100);
        auth_credentials          VARCHAR2(100);
        auth_credentials_encode   VARCHAR2(100);
        l_swms_host_url           system_xdock_config.config_flag_val%TYPE;
        l_swms_host_end_point     system_xdock_config.config_flag_val%TYPE;
        l_swms_client_id_syspar   system_xdock_config.config_flag_val%TYPE;
        l_swms_client_pass_syspar system_xdock_config.config_flag_val%TYPE;
        l_swms_https_enabled      system_xdock_config.config_flag_val%TYPE;
        l_directory_path          VARCHAR2(100);
    BEGIN

        l_swms_host_url := get_xdock_syspar('S2S_HTTP_URL');
        l_swms_host_end_point := get_xdock_syspar('S2S_HTTP_URL_END_POINT');
        l_swms_client_id_syspar := get_xdock_syspar('S2S_CLIENT_ID');
        l_swms_client_pass_syspar := get_xdock_syspar('S2S_CLIENT_PASS');
        l_swms_https_enabled := get_xdock_syspar('S2S_HTTPS_ENABLED');

        IF l_swms_https_enabled = 'Y' THEN
            select directory_path into l_directory_path from dba_directories where directory_name = 'S3_SSL_WALLET';
            utl_http.set_wallet('file:' || l_directory_path);
            url := 'https://';
        ELSE
            url := 'http://';
        END IF;

        url := url || l_swms_host_url || '/' || l_swms_host_end_point;

        auth_credentials := l_swms_client_id_syspar || ':' || l_swms_client_pass_syspar;
        auth_credentials_encode :=
                UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_ENCODE(UTL_RAW.CAST_TO_RAW(auth_credentials)));

        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);
        req := UTL_HTTP.BEGIN_REQUEST(
                url => url,
                method => 'POST'
            );
        UTL_HTTP.SET_HEADER(req, 'content-type', 'application/json');
        UTL_HTTP.SET_HEADER(req, 'Content-Length', length(json_in));
        UTL_HTTP.SET_HEADER(req, 'Authorization', 'Basic ' || auth_credentials_encode);
        UTL_HTTP.WRITE_TEXT(req, json_in);
        UTL_HTTP.set_persistent_conn_support(req, FALSE);
        pl_log.ins_msg('INFO', 'CALL_REST_S2S_POST',
                       'CALL_REST_S2S_POST - Sending the request [' || url || '] for batch_id [' || message_id ||
                       ']', sqlcode, sqlerrm); -- for swms.log file

        resp := UTL_HTTP.GET_RESPONSE(req);
        IF resp.status_code = '200'
        THEN
            BEGIN
                LOOP
                    UTL_HTTP.READ_LINE(resp, resp_string, TRUE);
                    result := result || resp_string;
                END LOOP;
                UTL_HTTP.END_RESPONSE(resp);
            EXCEPTION
                WHEN UTL_HTTP.end_of_body THEN
                    UTL_HTTP.END_RESPONSE(resp);
            END;
            pl_log.ins_msg('INFO', 'CALL_REST_S2S_POST', 'CALL_REST_S2S_POST - RESPONSE MSG: ' || result, sqlcode,
                           sqlerrm); -- for swms.log file
            RETURN (0);
        ELSE
            pl_log.ins_msg('FATAL', 'CALL_REST_S2S_POST',
                           'CALL_REST_S2S_POST - Resp.status_code=[' || resp.status_code || ']' ||
                           resp.reason_phrase, sqlcode, sqlerrm);
            result := resp.reason_phrase;
            RETURN (1);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                pl_log.ins_msg('FATAL', 'CALL_REST_S2S_POST',
                               'CALL_REST_S2S_POST - UTL_HTTP EXCEPTION MSG: ' || UTL_HTTP.get_detailed_sqlerrm,
                               sqlcode, sqlerrm);
                DBMS_OUTPUT.PUT_LINE(' UTL_HTTP EXCEPTION MSG: ' || UTL_HTTP.get_detailed_sqlerrm);
                DBMS_OUTPUT.PUT_LINE(' sqlerrm: ' || sqlerrm);
                result := sqlerrm;
                RETURN (1);
            END;
            UTL_HTTP.END_RESPONSE(resp);
    END call_rest_post;

    FUNCTION get_xdock_syspar(
        i_config_flag_name IN system_xdock_config.config_flag_name%TYPE
    )
        RETURN VARCHAR2 IS
        l_syspar_value system_xdock_config.config_flag_val%TYPE;
    BEGIN
        SELECT config_flag_val
        INTO l_syspar_value
        FROM system_xdock_config
        WHERE config_flag_name = UPPER(i_config_flag_name);

        RETURN (l_syspar_value);

    EXCEPTION
        WHEN OTHERS THEN
            pl_log.ins_msg('FATAL', 'GET_XDOCK_SYSPAR',
                           'GET_XDOCK_SYSPAR - ERROR IN GETTING THE CONFIG PROPERTY: ' || sqlerrm, sqlcode,
                           sqlerrm);
    END get_xdock_syspar;
END PL_CALL_REST_S2S;
/