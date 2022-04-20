/****************************************************************************
** File: Jira438_create_table_inboud_cust_setup.sql
**
** Desc: Script create new table:INBOUND_CUST_SETUP and added index and primary key
**                                   
****************************************************************************/
 DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
 
              SELECT COUNT(*)
              INTO v_column_exists
              FROM all_tables
              WHERE  table_name = 'INBOUND_CUST_SETUP'
              AND  owner='SWMS';
              
             IF (v_column_exists = 0) THEN  
                                 
                EXECUTE IMMEDIATE 'CREATE TABLE SWMS.INBOUND_CUST_SETUP
            (
              CUST_ID       VARCHAR2(10 BYTE)               NOT NULL,
              STAGING_LOC   VARCHAR2(10 BYTE)               NOT NULL
            )
            TABLESPACE SWMS_DTS2
            RESULT_CACHE (MODE DEFAULT)
            PCTUSED    0
            PCTFREE    10
            INITRANS   1
            MAXTRANS   255
            STORAGE    (
                        PCTINCREASE      0
                        BUFFER_POOL      DEFAULT
                        FLASH_CACHE      DEFAULT
                        CELL_FLASH_CACHE DEFAULT
                       )
            LOGGING 
            NOCOMPRESS 
            NOCACHE
            NOPARALLEL
            MONITORING';
            EXECUTE IMMEDIATE '
            CREATE OR REPLACE PUBLIC SYNONYM INBOUND_CUST_SETUP FOR SWMS.INBOUND_CUST_SETUP';
            EXECUTE IMMEDIATE '
            ALTER TABLE SWMS.INBOUND_CUST_SETUP ADD 
            CONSTRAINT INBOUND_CUST_SETUP_PK
             PRIMARY KEY (CUST_ID)
             ENABLE
             VALIDATE';
            EXECUTE IMMEDIATE '
            ALTER TABLE SWMS.INBOUND_CUST_SETUP ADD
            CONSTRAINT STAGING_LOC_UNIQUE
             UNIQUE (STAGING_LOC)
             ENABLE';
            EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.INBOUND_CUST_SETUP TO SWMS_USER';
            EXECUTE IMMEDIATE '
            GRANT SELECT ON SWMS.INBOUND_CUST_SETUP TO SWMS_VIEWER';   
            END IF;      
END;
/