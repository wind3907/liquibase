create or replace PACKAGE PL_XDOCK_META_MESSAGE_RETRY AS

    PROCEDURE retry_meta_message_runner;

    PROCEDURE retry_meta_message_to_hub(
        i_batch_id IN xdock_meta_header.batch_id%TYPE
    );

    PROCEDURE update_entity_table_data(
        i_batch_id IN VARCHAR2,
        i_table_name IN VARCHAR2
    );

END PL_XDOCK_META_MESSAGE_RETRY;
/

create or replace PACKAGE BODY PL_XDOCK_META_MESSAGE_RETRY AS

    PROCEDURE retry_meta_message_runner AS
        CURSOR c_xdock_error_message_list IS
            SELECT batch_id
            FROM swms.xdock_meta_header
            WHERE batch_status = 'ERROR'
               OR batch_status = 'SENT'
                AND add_date BETWEEN (SYSDATE - 1) AND (sysdate + (1 / 1440 * -15));
    BEGIN
        FOR i IN c_xdock_error_message_list
            LOOP
                BEGIN
                    retry_meta_message_to_hub(i.batch_id);
                END;
            END LOOP;
    END retry_meta_message_runner;

    PROCEDURE retry_meta_message_to_hub(
        i_batch_id IN xdock_meta_header.batch_id%TYPE
    ) IS
        l_batch_status         xdock_meta_header.batch_status%TYPE;
        l_staging_table_name   xdock_meta_header.staging_table_name%TYPE;
        l_hub_source_site      xdock_meta_header.hub_source_site%TYPE;
        l_hub_destination_site xdock_meta_header.hub_destination_site%TYPE;
        l_result               NUMBER;
    BEGIN
        SELECT batch_status, staging_table_name, hub_source_site, hub_destination_site
        INTO l_batch_status,l_staging_table_name,l_hub_source_site,l_hub_destination_site
        FROM swms.xdock_meta_header
        WHERE batch_id = i_batch_id;

        IF l_batch_status = 'SENT' THEN
            l_result := swms.pl_msg_hub_utlity.insert_meta_header(i_batch_id, l_staging_table_name, l_hub_source_site,
                                                                  l_hub_destination_site);
        ELSIF l_batch_status = 'ERROR' THEN
            update_entity_table_data(i_batch_id, l_staging_table_name);
            l_result := swms.pl_msg_hub_utlity.insert_meta_header(i_batch_id, l_staging_table_name, l_hub_source_site,
                                                                  l_hub_destination_site);
        END IF;
        pl_text_log.ins_msg_async('DEBUG', 'META_MESSAGES_RETRY_PROCESS',
                                  'META_MESSAGES_RETRY_PROCESS - Meta message retried for batch id :' ||i_batch_id, sqlcode, sqlerrm);

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', 'META_MESSAGES_RETRY_PROCESS',
                                          'META_MESSAGES_RETRY_PROCESS - Error in retrying meta message for batch id : ' ||
                                          i_batch_id, sqlcode,
                                          sqlerrm);
    END retry_meta_message_to_hub;


    PROCEDURE update_entity_table_data(
        i_batch_id IN VARCHAR2,
        i_table_name IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        record_status VARCHAR2(1);
    BEGIN

        record_status := 'N';

        EXECUTE IMMEDIATE 'UPDATE ' || i_table_name || ' SET RECORD_STATUS = ''' || record_status ||
                          ''' WHERE BATCH_ID = trim(''' || i_batch_id || ''')';
        COMMIT;
        pl_text_log.ins_msg_async('DEBUG', 'META_MESSAGES_RETRY_PROCESS',
                                  'META_MESSAGES_RETRY_PROCESS - Record status updated on table : ' || i_table_name ||
                                  ' for batch id :' ||i_batch_id, sqlcode, sqlerrm);

    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('ERROR', 'META_MESSAGES_RETRY_PROCESS',
                                      'META_MESSAGES_RETRY_PROCESS - Error in updating the entity table : ' ||
                                      i_table_name, sqlcode,
                                      sqlerrm);

    END update_entity_table_data;

END PL_XDOCK_META_MESSAGE_RETRY;
/
