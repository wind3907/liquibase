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
    WHERE  table_name = 'XDOCK_TRACER'
      AND  owner = 'SWMS';
    IF (v_table_exists = 0) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE "SWMS"."XDOCK_TRACER"
                              (	
                                "BATCH_ID" VARCHAR2(14 CHAR), 
                                "RECORD_STATUS" VARCHAR2(20 CHAR), 
                                "SITE_FROM" VARCHAR2(20 CHAR), 
                                "SITE_TO" VARCHAR2(20 CHAR), 
                                "CREATED_DATE" DATE, 
                                "SENT_DATE" DATE, 
                                "ENRICH_DATE" DATE,
                                "DELIVERED_DATE" DATE, 
                                "MESSAGE" VARCHAR2(200 CHAR), 
                                "ERROR" VARCHAR2(1000 CHAR), 
                                constraint XDOCK_TRACER_PK primary key("BATCH_ID")
                              ) ';
        EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_TRACER FOR SWMS.XDOCK_TRACER';
        EXECUTE IMMEDIATE 'GRANT ALL ON SWMS.XDOCK_TRACER TO SWMS_USER';
        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_TRACER TO SWMS_VIEWER';
   END IF;
END;
/

