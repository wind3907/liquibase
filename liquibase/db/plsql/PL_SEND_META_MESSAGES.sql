create or replace PACKAGE PL_SEND_META_MESSAGES AS
    FUNCTION send_meta_messages (
        batch_id                IN                VARCHAR2,
        entity_name             IN                VARCHAR2,
        HUB_SOURCE_SITE         IN                VARCHAR2,
        HUB_DESTINATION_SITE    IN                VARCHAR2,
        result_str              OUT               VARCHAR2
    )RETURN PLS_INTEGER;

    FUNCTION check_site_validity(
        HUB_SOURCE_SITE         IN                VARCHAR2,
        HUB_DESTINATION_SITE    IN                VARCHAR2
    ) RETURN INTEGER;

    PROCEDURE update_entity_tables_on_error(
        batch_id                IN                VARCHAR2,
        entity_name             IN                VARCHAR2
    );

    PROCEDURE update_entity_table_on_error(
        batch_id                IN                VARCHAR2,
        table_name              IN                VARCHAR2
    );

END PL_SEND_META_MESSAGES;
/

create or replace PACKAGE BODY PL_SEND_META_MESSAGES AS
    FUNCTION send_meta_messages(
        batch_id                IN                VARCHAR2,
        entity_name             IN                VARCHAR2,
        HUB_SOURCE_SITE         IN                VARCHAR2,
        HUB_DESTINATION_SITE    IN                VARCHAR2,
        result_str              OUT               VARCHAR2
    ) RETURN PLS_INTEGER AS
        json_string     VARCHAR(500);
        result          PLS_INTEGER;
        is_valid_sites  INTEGER;
    BEGIN

        pl_text_log.ins_msg_async('INFO','SEND_META_MESSAGES','SEND_META_MESSAGES - Starting the meta message processing for batch_id' || batch_id,sqlcode,sqlerrm);

        is_valid_sites :=  check_site_validity(HUB_SOURCE_SITE ,HUB_DESTINATION_SITE);

        IF is_valid_sites = 1 THEN
            result := 1;
            result_str := 'Source site['||HUB_SOURCE_SITE||'] or destination site['||HUB_DESTINATION_SITE||'] is invalid';
            update_entity_tables_on_error(batch_id,entity_name);
        ELSE
            json_string := '{
            "id":"'||trim(batch_id)||'",
            "topic": "'||trim(entity_name)||'",
            "sourceSite": "'||trim(HUB_SOURCE_SITE)||'",
            "destinationSite":"'||trim(HUB_DESTINATION_SITE)||'"
            }';

            pl_text_log.ins_msg_async('INFO','SEND_META_MESSAGES','SEND_META_MESSAGES - JSON Object created',sqlcode,sqlerrm);

            result := SWMS.PL_CALL_REST_S2S.call_rest_post(json_string,batch_id,result_str);
            IF result = 0 THEN
                pl_text_log.ins_msg_async('INFO','SEND_META_MESSAGES','SEND_META_MESSAGES - update the sent_timestamp and error as null for batch_id' || batch_id,sqlcode,sqlerrm);
            END IF;
        END IF;

        RETURN result;
    END send_meta_messages;

--  check_site_validity function
--   Return codes
--          0 : valid site codes
--          1 : invalid site code

    FUNCTION check_site_validity(
        HUB_SOURCE_SITE         IN                VARCHAR2,
        HUB_DESTINATION_SITE    IN                VARCHAR2
    ) RETURN INTEGER AS
    BEGIN

        IF HUB_SOURCE_SITE is null or HUB_DESTINATION_SITE is null
        THEN
            pl_text_log.ins_msg_async('FATAL','SEND_META_MESSAGES','SEND_META_MESSAGES - Source site or destination site is null',sqlcode,sqlerrm);
            RETURN 1;

        ELSIF LENGTH(TRIM(HUB_SOURCE_SITE)) != 3  or LENGTH(TRIM(HUB_DESTINATION_SITE)) != 3
        THEN
            pl_text_log.ins_msg_async('FATAL','SEND_META_MESSAGES','SEND_META_MESSAGES - Source site or destination site value length invalid ',sqlcode,sqlerrm);
            RETURN 1;

        ELSIF pl_common.get_company_no()  != HUB_SOURCE_SITE
        THEN
            pl_text_log.ins_msg_async('FATAL','SEND_META_MESSAGES','SEND_META_MESSAGES - invalid source site',sqlcode,sqlerrm);
            RETURN 1;
        END IF;

        RETURN 0;
    END check_site_validity;

    PROCEDURE update_entity_tables_on_error(
        batch_id                IN                VARCHAR2,
        entity_name             IN                VARCHAR2
    ) IS BEGIN

        IF entity_name = 'returns' THEN
            update_entity_table_on_error(batch_id,'xdock_returns_out');

        ELSIF entity_name = 'manifest' THEN
            update_entity_table_on_error(batch_id,'xdock_manifest_dtls_out');

        ELSIF entity_name = 'item' THEN
            update_entity_table_on_error(batch_id,'xdock_pm_out');

        ELSIF entity_name = 'tracer' THEN
            update_entity_table_on_error(batch_id,'xdock_tracer');

        ELSIF entity_name = 'order' THEN
            update_entity_table_on_error(batch_id,'xdock_ordm_out');
            update_entity_table_on_error(batch_id,'xdock_ordd_out');

        ELSIF entity_name = 'ordm-routing' THEN
            update_entity_table_on_error(batch_id,'xdock_ordm_routing_out');

        ELSIF entity_name = 'float' THEN
            update_entity_table_on_error(batch_id,'xdock_floats_out');
            update_entity_table_on_error(batch_id,'xdock_float_detail_out');
            update_entity_table_on_error(batch_id,'xdock_ordcw_out');
        END IF;

    END update_entity_tables_on_error;


    PROCEDURE update_entity_table_on_error(
        batch_id                IN                VARCHAR2,
        table_name              IN                VARCHAR2
    )
        IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        record_status      VARCHAR2(1);
    BEGIN

        record_status := 'F';

        EXECUTE IMMEDIATE 'UPDATE '|| table_name ||' SET RECORD_STATUS = '''|| record_status ||''' WHERE BATCH_ID = trim('''|| batch_id||''')';
        COMMIT;
        pl_text_log.ins_msg_async('INFO','SEND_META_MESSAGES','SEND_META_MESSAGES - Record status updated on table : ' || table_name ||' '||batch_id||' '||record_status ,sqlcode,sqlerrm);

    EXCEPTION  WHEN OTHERS THEN
        pl_text_log.ins_msg_async('FATAL','SEND_META_MESSAGES','SEND_META_MESSAGES - Error in updating the table : ' || table_name ,sqlcode,sqlerrm);

    END update_entity_table_on_error;
END PL_SEND_META_MESSAGES;
/