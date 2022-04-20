/********************************************************************
**
** Script to create new xdock_meta_header table
**
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN
    SELECT COUNT(*)
    INTO v_table_exists
    FROM   all_tables
    WHERE  table_name = 'XDOCK_META_HEADER'
      AND  owner = 'SWMS';
    IF (v_table_exists = 0) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE "SWMS"."XDOCK_META_HEADER"
                              (	"BATCH_ID" VARCHAR2(14),
                                "STAGING_TABLE_NAME" VARCHAR2(128),
                                "ENTITY_NAME" VARCHAR2(128),
                                "HUB_SOURCE_SITE" VARCHAR2(10),
                                "HUB_DESTINATION_SITE" VARCHAR2(10),
                                "BATCH_STATUS" VARCHAR2(10),
                                "ADD_DATE" DATE,
                                "SENT_DATE" DATE,
                                "DELIVERED_DATE" DATE,
                                "ERROR" VARCHAR2(200),
                                "NUMBER_OF_ROWS" NUMBER(*,0),
                                "FAILED_MESSAGE_PAYLOAD" CLOB,
                                constraint XDOCK_META_HEADER_PK primary key("BATCH_ID", "STAGING_TABLE_NAME")
                              ) ';
        EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_META_HEADER FOR SWMS.XDOCK_META_HEADER';
        EXECUTE IMMEDIATE 'GRANT ALL ON SWMS.XDOCK_META_HEADER TO SWMS_USER';
        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_META_HEADER TO SWMS_VIEWER';
   END IF;
END;
/
