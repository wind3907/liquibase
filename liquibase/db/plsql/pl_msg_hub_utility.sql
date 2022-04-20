create or replace PACKAGE PL_MSG_HUB_UTLITY AS

    FUNCTION insert_meta_header(
        i_batch_id    IN   VARCHAR2,
        i_staging_table_name   IN   VARCHAR2,
        i_hub_source_site  IN   VARCHAR2,
        i_hub_destination_site  IN   VARCHAR2
    ) RETURN PLS_INTEGER;

    FUNCTION insert_meta_header(
         i_batch_id    IN   VARCHAR2,
         i_staging_table_name   IN   VARCHAR2,
         i_hub_source_site  IN   VARCHAR2,
         i_hub_destination_site  IN   VARCHAR2,
         i_record_count  IN   NUMBER
    ) RETURN PLS_INTEGER;

END PL_MSG_HUB_UTLITY;
/

create or replace PACKAGE BODY PL_MSG_HUB_UTLITY AS

    FUNCTION insert_meta_header(
        i_batch_id    IN   VARCHAR2,
        i_staging_table_name   IN   VARCHAR2,
        i_hub_source_site  IN   VARCHAR2,
        i_hub_destination_site  IN   VARCHAR2
    ) RETURN PLS_INTEGER AS
        Type refc is ref cursor;
        Cur refc;
        l_record_count NUMBER;
    BEGIN
      pl_text_log.ins_msg('INFO', 'PL_MSG_HUB_META_HEADER_HELPER','Inserting record for batch_id: [' || i_batch_id || '] stag_table_name: [' || i_STAGING_TABLE_NAME||']',  sqlcode, sqlerrm);

      Open cur for 'SELECT count(1) FROM '|| i_staging_table_name || ' WHERE batch_id = '''||i_batch_id ||'''';

      Fetch cur into l_record_count;

      pl_text_log.ins_msg('INFO', 'PL_MSG_HUB_META_HEADER_HELPER','site from: [' || i_hub_source_site || '] site_to: [' || i_hub_destination_site||'] record_count :['||l_record_count||']',  sqlcode, sqlerrm);

      return insert_meta_header(i_batch_id,i_staging_table_name,i_hub_source_site,i_hub_destination_site,l_record_count);
    END insert_meta_header;

    FUNCTION insert_meta_header(
        i_batch_id    IN   VARCHAR2,
        i_staging_table_name   IN   VARCHAR2,
        i_hub_source_site  IN   VARCHAR2,
        i_hub_destination_site  IN   VARCHAR2,
        i_record_count  IN   NUMBER
    ) RETURN PLS_INTEGER AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        TYPE entity_name_t IS TABLE OF VARCHAR(128) INDEX BY VARCHAR2(128);
        entity_name_tab entity_name_t;
    BEGIN

        entity_name_tab('xdock_returns_out') := 'returns';
        entity_name_tab('xdock_manifest_dtls_out') := 'manifest';
        entity_name_tab('xdock_pm_out') := 'item';
        entity_name_tab('xdock_tracer') := 'tracer';
        entity_name_tab('xdock_ordm_out') := 'order';
        entity_name_tab('xdock_ordm_routing_out') := 'ordm-routing';
        entity_name_tab('xdock_floats_out') := 'float';

        BEGIN
            DELETE from xdock_meta_header where batch_id = i_batch_id and staging_table_name = i_staging_table_name;

            INSERT INTO xdock_meta_header
            (batch_id, staging_table_name,entity_name,hub_source_site,hub_destination_site,batch_status,add_date,number_of_rows)
            VALUES
            (i_batch_id,i_staging_table_name,entity_name_tab(LOWER(i_staging_table_name)),i_hub_source_site,i_hub_destination_site,'NEW',sysdate,i_record_count);
            COMMIT;
            return 0;
        EXCEPTION
            WHEN OTHERS THEN
            pl_text_log.ins_msg('INFO', 'PL_MSG_HUB_META_HEADER_HELPER','error happened: [' || i_batch_id ,  sqlcode, sqlerrm);
            ROLLBACK;
            return 1;
        END;
    END insert_meta_header;
END PL_MSG_HUB_UTLITY;
/
