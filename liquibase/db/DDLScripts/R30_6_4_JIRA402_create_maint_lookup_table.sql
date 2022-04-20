/****************************************************************************
** File: CRQ31527create_maint_lookup_table.sql
**
** Desc: Script create new table:SWMS_MAINT_LOOKUP and added index and primary key
**        
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    13-April-2018 Elaine Zheng    create new table:MAINT_LOOKUP and added 
**                                  index and primary key
**                                   
****************************************************************************/
 DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
 
              SELECT COUNT(*)
              INTO v_column_exists
              FROM all_tables
              WHERE  table_name = 'SWMS_MAINT_LOOKUP'
              AND  owner='SWMS';
              
             IF (v_column_exists = 0) THEN  
                                 
                EXECUTE IMMEDIATE 'CREATE TABLE SWMS.SWMS_MAINT_LOOKUP
            (
              ID_LANGUAGE    NUMBER                         NOT NULL,
              CODE_TYPE     VARCHAR2(10 BYTE)               NOT NULL,
              CODE_NAME     VARCHAR2(10 BYTE)               NOT NULL,
              CODE_DESC     VARCHAR2(50 BYTE),
              CORP_CONTROL  VARCHAR2(1 BYTE)
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
            CREATE OR REPLACE PUBLIC SYNONYM SWMS_MAINT_LOOKUP FOR SWMS.SWMS_MAINT_LOOKUP';
            EXECUTE IMMEDIATE '
            ALTER TABLE SWMS.SWMS_MAINT_LOOKUP ADD 
            CONSTRAINT SWMS_MAINT_LOOKUP_PK
             PRIMARY KEY (CODE_NAME, CODE_TYPE, ID_LANGUAGE)
             ENABLE
             VALIDATE';
            EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.SWMS_MAINT_LOOKUP TO SWMS_USER';
            EXECUTE IMMEDIATE '
            GRANT SELECT ON SWMS.SWMS_MAINT_LOOKUP TO SWMS_VIEWER';   
            END IF;      
END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE table_name = 'ZONE' AND column_name = 'CODE_NAME_RESTRICT';
        

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ZONE
ADD (CODE_NAME_RESTRICT VARCHAR2(10 BYTE))';
  END IF;
END;
/
 DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
 
              SELECT COUNT(*)
              INTO v_column_exists
              FROM all_tables
              WHERE  table_name = 'SWMS_CODE_TYPES'
              AND  owner='SWMS';
              
             IF (v_column_exists = 0) THEN  
                                  
                EXECUTE IMMEDIATE 'CREATE TABLE SWMS.SWMS_CODE_TYPES
            (
              CODE_TYPE     VARCHAR2(10 BYTE)               NOT NULL,
              CODE_DESC     VARCHAR2(50 BYTE)
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
            CREATE UNIQUE INDEX SWMS.CODE_TYPE_PK ON SWMS.SWMS_CODE_TYPES
            (CODE_TYPE)
            LOGGING
            TABLESPACE SWMS_DTS2
            PCTFREE    10
            INITRANS   2
            MAXTRANS   255
            STORAGE    (
                        PCTINCREASE      0
                        BUFFER_POOL      DEFAULT
                        FLASH_CACHE      DEFAULT
                        CELL_FLASH_CACHE DEFAULT
                       )
            NOPARALLEL';
                        EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.SWMS_CODE_TYPES TO SWMS_USER';
            EXECUTE IMMEDIATE '
            GRANT SELECT ON SWMS.SWMS_CODE_TYPES TO SWMS_VIEWER'; 
            END IF; 
      END;
/
