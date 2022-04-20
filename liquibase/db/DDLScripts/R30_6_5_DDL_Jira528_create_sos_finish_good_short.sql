/****************************************************************************
** File: R30_6_5_DDL_Jira528_create_sos_finish_good_short.sqll
**
** Desc: Script create new table: sos_finish_good_short
**        
**
** Modification History:
**    Date     Designer           Comments
**    -------- -------- ---------------------------------------------------
**    08/07/18 mpha8134 Created
****************************************************************************/
 DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
	/* Add new column in ORDCW */
	SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
    WHERE column_name = 'PKG_SHORT_USED'
        AND table_name = 'ORDCW';

    IF v_column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ORDCW ADD PKG_SHORT_USED CHAR(1 CHAR)';
    END IF;


	/* Add new table SOS_FINISH_GOOD_SHORT */
    SELECT COUNT(*)
    INTO v_column_exists
    FROM all_tables
    WHERE  table_name = 'SOS_FINISH_GOOD_SHORT'
    AND  owner='SWMS';
              
    IF (v_column_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE 'CREATE TABLE SWMS.SOS_FINISH_GOOD_SHORT
        (
			AREA VARCHAR2(1 CHAR) NOT NULL ENABLE, 
			ORDERSEQ NUMBER(8,0) NOT NULL ENABLE, 
			ORDER_ID VARCHAR2(14 CHAR) NOT NULL ENABLE,
			PICKTYPE VARCHAR2(2 CHAR) NOT NULL ENABLE, 
			BATCH_NO VARCHAR2(7 CHAR),
			PROD_ID VARCHAR(9 CHAR) NOT NULL ENABLE,
			UOM NUMBER(2) NOT NULL ENABLE,
			PALLET_ID VARCHAR2(18 CHAR) NOT NULL ENABLE, 
			WEIGHT NUMBER(9,3),
			TRUCK VARCHAR2(4 CHAR), 
			LOCATION VARCHAR2(6 CHAR) NOT NULL ENABLE, 
			DOCK_FLOAT_LOC VARCHAR2(3 CHAR), 
			QTY_TOTAL NUMBER(3,0) NOT NULL ENABLE, 
			QTY_SHORT NUMBER(3,0) NOT NULL ENABLE, 
			SOS_STATUS VARCHAR2(1 CHAR),
			SHORT_TIME DATE, 
			FORK_STATUS VARCHAR2(8 CHAR), 
			RESOLUTION_TIME DATE, 
			SHORT_GROUP VARCHAR2(1 CHAR), 
			USER_ID VARCHAR2(30 CHAR), 
			SHORT_BATCH_NO VARCHAR2(13 CHAR), 
			SHORT_REASON VARCHAR2(8 CHAR), 
			PALLET VARCHAR2(4 CHAR), 
			QTY_SHORT_ON_SHORT NUMBER(3,0), 
			SHORT_ON_SHORT_STATUS VARCHAR2(1 CHAR), 
			WHOUT_DATE DATE, 
			WHOUT_BY VARCHAR2(30 CHAR), 
			PIK_STATUS VARCHAR2(1 BYTE), 
			SPUR_LOCATION VARCHAR2(10 BYTE), 
			FLOAT_NO NUMBER(9,0), 
			FLOAT_DETAIL_SEQ_NO NUMBER(3,0), 
			WH_OUT_QTY NUMBER(7,0)
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
            CREATE OR REPLACE PUBLIC SYNONYM SOS_FINISH_GOOD_SHORT FOR SWMS.SOS_FINISH_GOOD_SHORT';
        
		EXECUTE IMMEDIATE '
        	ALTER TABLE SWMS.SOS_FINISH_GOOD_SHORT ADD 
        	CONSTRAINT SOS_FINISH_GOOD_SHORT_PK
        		PRIMARY KEY (ORDERSEQ, LOCATION, PICKTYPE, FLOAT_NO, FLOAT_DETAIL_SEQ_NO)
            	ENABLE
            	VALIDATE';
        
		EXECUTE IMMEDIATE '
        	GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.SOS_FINISH_GOOD_SHORT TO SWMS_USER';
        
		EXECUTE IMMEDIATE '
    		GRANT SELECT ON SWMS.SOS_FINISH_GOOD_SHORT TO SWMS_VIEWER';   
	END IF;      
END;
/
