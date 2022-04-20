/********************************************************************
**
** Script to create new staging table GS1_finish_good_in       
**
** Modification History:
** 
**    Date     Designer       Comments
**    -------- -------------- --------------------------------------
**    4/15/19  P. Kabran      Created
**    7/02/19  P. Kabran      Fixed UPC size and also changed table
**                            privileges.
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN 
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'GS1_FINISH_GOOD_IN'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE 'CREATE TABLE SWMS.GS1_FINISH_GOOD_IN
        (
           SEQUENCE_NUMBER NUMBER(10) NOT NULL, 
           RECORD_STATUS   VARCHAR2(1 CHAR) NOT NULL, 
           DATETIME        DATE NOT NULL,
           FUNC_CODE       VARCHAR2(1 CHAR),
           PO_NO           VARCHAR2(12 CHAR),
           ORDER_ID        VARCHAR2(14 CHAR),
           WEIGHT          NUMBER(9, 3) NOT NULL,
           PROD_ID         VARCHAR2(9 CHAR) NOT NULL,
           UPC             VARCHAR2(14 CHAR),
           BOX_ID          VARCHAR2(50 CHAR),
           PACK_DATE       DATE,
           ERROR_MSG       VARCHAR2(300),
           ADD_USER        VARCHAR2(30 CHAR),
           ADD_DATE        DATE,
           UPD_USER        VARCHAR2(30 CHAR),
           UPD_DATE        DATE
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
            CREATE OR REPLACE PUBLIC SYNONYM GS1_FINISH_GOOD_IN FOR SWMS.GS1_FINISH_GOOD_IN';

        EXECUTE IMMEDIATE '
            ALTER TABLE SWMS.GS1_FINISH_GOOD_IN ADD
                CONSTRAINT GS1_FINISH_GOOD_IN_PK
                PRIMARY KEY (SEQUENCE_NUMBER, RECORD_STATUS, DATETIME)
                USING INDEX
                TABLESPACE SWMS_ITS2
                ENABLE
                VALIDATE';
        
        EXECUTE IMMEDIATE '
            CREATE INDEX GS1_FINISH_GOOD_IN_IDX1 ON SWMS.GS1_FINISH_GOOD_IN (RECORD_STATUS)
            TABLESPACE SWMS_ITS2';

	EXECUTE IMMEDIATE '
            GRANT ALL ON SWMS.GS1_FINISH_GOOD_IN TO SWMS_SAP';
        
    END IF;      
END;
/
