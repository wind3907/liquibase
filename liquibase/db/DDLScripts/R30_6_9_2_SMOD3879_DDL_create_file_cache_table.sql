/****************************************************************************
** File: R30_6_9_SMOD3879_DDL_create_file_cache_table.sql
*
** Desc: Script creates the table FILE_CACHE. This table is required for LXI_FILE_GEN Package for L&S RDS Project.
** This table needs to be created only in Oracle RDS 12c datable.
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    07/08/20    igoo9289     Created for SMOD-3879 RDS LXI_FILE_GEN
**
****************************************************************************/
DECLARE
    v_table_exists NUMBER := 0;
BEGIN
    $if not dbms_db_version.ver_le_11 $then
        SELECT COUNT(*)
        INTO   v_table_exists
        FROM   all_tables
        WHERE  table_name = 'FILE_CACHE'
          AND  owner = 'SWMS';
        IF (v_table_exists = 0) THEN
            --------------------------------------------------------
            --  DDL for Table MQ_ERROR_LOG
            --------------------------------------------------------
            EXECUTE IMMEDIATE 'CREATE TABLE "SWMS"."FILE_CACHE"
                   (   "ID" NUMBER
                                GENERATED ALWAYS AS IDENTITY ( START WITH 1 INCREMENT BY 1 CACHE 20 MAXVALUE 999999 ORDER CYCLE ),
                       "FILE_PATH" VARCHAR2(200) NOT NULL,
                       "FILE_DATA" CLOB NOT NULL,
                       "ADD_DATE" DATE NOT NULL,
                       CONSTRAINT FILE_CACHE_PK PRIMARY KEY (ID) ENABLE
                   ) TABLESPACE "SWMS_DTS2"';
            EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM FILE_CACHE FOR SWMS.FILE_CACHE';
            EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.FILE_CACHE TO SWMS_USER';
            EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.FILE_CACHE TO SWMS_VIEWER';
            -- Purge file_cache table for entries more than 2 days old
            EXECUTE IMMEDIATE 'INSERT INTO SWMS.SAP_INTERFACE_PURGE (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_DATE, UPD_USER) 
            VALUES (''FILE_CACHE'', 2, ''LXLI file cache records'',SYSDATE, USER)'; 
        END IF;
    $else
        DBMS_OUTPUT.PUT_LINE('CREATION OF FILE_CACHE TABLE IS ONLY NEEDED IF DB IS REMOTE');
    $end
END;
/
