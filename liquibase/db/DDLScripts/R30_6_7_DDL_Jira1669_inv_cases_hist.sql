/********************************************************************
**
** Script to create new inv_cases_hist table      
**
** Modification History:
** 
**    Date     Comments
**    -------- -------------- --------------------------------------
**    5/15/19  vkal9662 Created
**    7/02/19  pkab6563 Fixed UPC size. 
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN 
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'INV_CASES_HIST'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE 'CREATE TABLE SWMS.INV_CASES_HIST
        (
           PROD_ID           VARCHAR2(9 CHAR) NOT NULL,
           REC_ID            VARCHAR2(12 CHAR),
           ORDER_ID          VARCHAR2(14 CHAR),
           BOX_ID            VARCHAR2(50 CHAR),
           PACK_DATE         DATE,
           WEIGHT            NUMBER(9,3) NOT NULL,
           UPC               VARCHAR2(14 CHAR),
           LOGI_LOC          VARCHAR2(18 CHAR) NOT NULL,
           ALLOCATE_IND  VARCHAR2(3 CHAR),
           ADD_USER          VARCHAR2(30 CHAR),
           ADD_DATE          DATE,
           UPD_USER          VARCHAR2(30 CHAR),
           UPD_DATE          DATE
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
            CREATE OR REPLACE PUBLIC SYNONYM INV_CASES_HIST FOR SWMS.INV_CASES_HIST';

	EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.INV_CASES_HIST TO SWMS_USER';
        
	EXECUTE IMMEDIATE '
    	    GRANT SELECT ON SWMS.INV_CASES_HIST TO SWMS_VIEWER';   
    END IF;      
END;
/
