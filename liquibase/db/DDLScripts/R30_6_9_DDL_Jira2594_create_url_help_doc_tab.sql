/********************************************************************
**
** Script to create new URL_HELP_DOC table      
**
** Modification History:
** 
**    Date       Designer       Comments
**    -------- -------------- --------------------------------------
**    10/09/19   xzhe5043       Created for Jira card 2594.
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN 
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'URL_HELP_DOC'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE 'CREATE TABLE SWMS.URL_HELP_DOC
        (
           SEQ                NUMBER(9,3) NOT NULL,
           MODULE_NAME        VARCHAR2(30 CHAR),
           LEVEL_TYPE         VARCHAR2(30 CHAR),
           PROGRAM_NAME       VARCHAR2(30 CHAR),
           SUB_PROGRAM_NAME   VARCHAR2(30 CHAR),
           HELP_URL           VARCHAR2(2000 CHAR),
		   ENABLE_FLAG        VARCHAR2(1 CHAR),
           CONSTRAINT seq_pk PRIMARY KEY (SEQ)
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
            CREATE OR REPLACE PUBLIC SYNONYM URL_HELP_DOC FOR SWMS.URL_HELP_DOC';

	EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.URL_HELP_DOC TO SWMS_USER';
        
	EXECUTE IMMEDIATE '
    	    GRANT SELECT ON SWMS.URL_HELP_DOC TO SWMS_VIEWER';   
    END IF;      
END;
/
