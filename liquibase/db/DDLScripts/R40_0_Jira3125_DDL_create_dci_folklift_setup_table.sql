/********************************************************************
**
** Script to create new dci_forklift_setup table      
**
** Modification History:
** 
**    Date       Designer       Comments
**    -------- -------------- --------------------------------------
**    08/24/20   xzhe5043       JIRA 3126 New Screen for driver checkin 
**                              folklift setup.
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN 
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'DCI_FORKLIFT_SETUP'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE 'create table DCI_FORKLIFT_SETUP(
		area_code VARCHAR2(1 CHAR),
		door_no VARCHAR2(4 CHAR),
        CONSTRAINT "AREA_DOOR_PRIMARY" PRIMARY KEY ("AREA_CODE") 
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
            CREATE OR REPLACE PUBLIC SYNONYM DCI_FORKLIFT_SETUP FOR SWMS.DCI_FORKLIFT_SETUP';

	EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.DCI_FORKLIFT_SETUP TO SWMS_USER';
        
	EXECUTE IMMEDIATE '
    	    GRANT SELECT ON DCI_FORKLIFT_SETUP TO SWMS_VIEWER';   
    END IF;      
END;
/
