create or replace PACKAGE PL_MSG_HUB_META_HEADER_HELPER AS

    FUNCTION insert_meta_header(
        i_batch_id    IN   VARCHAR2,
        i_staging_table_name   IN   VARCHAR2
    ) RETURN PLS_INTEGER;

    FUNCTION insert_meta_header(
         i_batch_id    IN   VARCHAR2,
         i_staging_table_name   IN   VARCHAR2,
         i_site_from  IN   VARCHAR2,
         i_site_to  IN   VARCHAR2,
         i_record_count  IN   NUMBER
    ) RETURN PLS_INTEGER;

END PL_MSG_HUB_META_HEADER_HELPER;
/

create or replace PACKAGE BODY PL_MSG_HUB_META_HEADER_HELPER AS

    FUNCTION insert_meta_header(
        i_batch_id    IN   VARCHAR2,
        i_staging_table_name   IN   VARCHAR2
    ) RETURN PLS_INTEGER AS
        Type refc is ref cursor;
        Cur refc;
        l_site_from xdock_meta_header.site_from%TYPE;
        l_site_to xdock_meta_header.site_to%TYPE;
        l_record_count NUMBER;
    BEGIN
      pl_text_log.ins_msg('INFO', 'PL_MSG_HUB_META_HEADER_HELPER','Inserting record for batch_id: [' || i_batch_id || '] stag_table_name: [' || i_STAGING_TABLE_NAME||']',  sqlcode, sqlerrm);

      Open cur for 'SELECT site_from,site_to,count(1)  FROM '|| i_staging_table_name || ' WHERE batch_id = '''||i_batch_id ||''' GROUP BY batch_id,site_from,site_to';

      Fetch cur into l_site_from,l_site_to,l_record_count;

      pl_text_log.ins_msg('INFO', 'PL_MSG_HUB_META_HEADER_HELPER','site from: [' || l_site_from || '] site_to: [' || l_site_to||'] record_count :['||l_record_count||']',  sqlcode, sqlerrm);

      return insert_meta_header(i_batch_id,i_staging_table_name,l_site_from,l_site_to,l_record_count);
    END insert_meta_header;

    FUNCTION insert_meta_header(
        i_batch_id    IN   VARCHAR2,
        i_staging_table_name   IN   VARCHAR2,
        i_site_from  IN   VARCHAR2,
        i_site_to  IN   VARCHAR2,
        i_record_count  IN   NUMBER
    ) RETURN PLS_INTEGER AS
        TYPE entity_name_t IS TABLE OF VARCHAR(128) INDEX BY VARCHAR2(128);
        entity_name_tab entity_name_t;
    BEGIN

        entity_name_tab('xdock_returns_out') := 'returns';
        entity_name_tab('xdock_manifest_out') := 'manifest';
        entity_name_tab('xdock_order_xref') := 'order-cross-reference';


        DELETE from xdock_meta_header where batch_id = i_batch_id and staging_table_name = i_staging_table_name;

        INSERT INTO xdock_meta_header
        (batch_id, staging_table_name,entity_name,site_from,site_to,batch_status,add_date,number_of_rows)
        VALUES
        (i_batch_id,i_staging_table_name,entity_name_tab(i_staging_table_name),i_site_from,i_site_to,'NEW',sysdate,i_record_count);
        return 0;
    END insert_meta_header;
END PL_MSG_HUB_META_HEADER_HELPER;
/
