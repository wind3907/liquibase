/****************************************************************************
** File: CRQ31527create_table_apcom_queue.sql
**
** Desc: Script create new table:APCOM_QUEUE and added index and primary key
**        
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    03-dec-2017 Elaine Zheng    create new table:APCOM_QUEUE and added 
**                                index and primary key
**                                   
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM all_tables
  WHERE  table_name = 'APCOM_QUEUE'
  AND  owner='SWMS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.APCOM_QUEUE
(
  QUEUE_NAME       VARCHAR2(2 BYTE),
  SECOND_DURATION  NUMBER,
  IN_OR_OUT        VARCHAR2(1 BYTE),
  MONITOR          VARCHAR2(1 BYTE)
)
TABLESPACE SWMS_DTS2
RESULT_CACHE (MODE DEFAULT)
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
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
CREATE UNIQUE INDEX SWMS.APCOM_QUEUE_PK ON SWMS.APCOM_QUEUE
(QUEUE_NAME)
LOGGING
TABLESPACE SWMS_DTS2
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
            FLASH_CACHE      DEFAULT
            CELL_FLASH_CACHE DEFAULT
           )
NOPARALLEL';
  EXECUTE IMMEDIATE '
ALTER TABLE SWMS.APCOM_QUEUE ADD (
  CONSTRAINT APCOM_QUEUE_PK
  PRIMARY KEY
  (QUEUE_NAME)
  USING INDEX SWMS.APCOM_QUEUE_PK
  ENABLE VALIDATE)';

  END IF;
END;
/

