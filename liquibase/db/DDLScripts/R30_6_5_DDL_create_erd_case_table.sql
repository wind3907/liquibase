/****************************************************************************
** File: R30_6_5_DDL_create_erd_case_table.sql
**
** Desc: Script create new table:ERD_CASE
**                                   
****************************************************************************/
DECLARE
	v_table_exists NUMBER := 0;
	v_index_exists NUMBER := 0;
BEGIN 
 
    SELECT COUNT(*)
    INTO v_table_exists
    FROM all_tables
    WHERE  table_name = 'ERD_CASE'
    AND  owner='SWMS';	
              
    IF (v_table_exists = 0) THEN  

		EXECUTE IMMEDIATE 'CREATE TABLE SWMS.ERD_CASE (
			ERM_ID VARCHAR2(12 CHAR) NOT NULL ENABLE, 
			ERM_LINE_ID NUMBER(4,0) NOT NULL ENABLE, 
			SALEABLE VARCHAR2(1 CHAR), 
			MISPICK VARCHAR2(1 CHAR), 
			ITEM_SEQ NUMBER(3,0), 
			PROD_ID VARCHAR2(9 CHAR) NOT NULL ENABLE, 
			CUST_ID VARCHAR2(10 CHAR), 
			CUST_NAME VARCHAR2(17 CHAR), 
			CMT VARCHAR2(30 CHAR), 
			WEIGHT NUMBER(9,3), 
			TEMP NUMBER(6,1),
			QTY NUMBER(8,0) NOT NULL ENABLE, 
			UOM NUMBER(2,0), 
			QTY_REC NUMBER(8,0), 
			UOM_REC NUMBER(2,0), 
			ORDER_ID VARCHAR2(14 CHAR), 
			QTY_UPLOADED NUMBER(8,0), 
			CUST_PREF_VENDOR VARCHAR2(10 CHAR) NOT NULL ENABLE, 
			MASTER_CASE_IND VARCHAR2(1 CHAR), 
			STATUS VARCHAR2(3 CHAR), 
			REASON_CODE VARCHAR2(3 CHAR), 
			PRD_WEIGHT NUMBER(9,3), 
			EXP_DATE DATE, 
			MFG_DATE DATE, 
			ORIG_ERM_LINE_ID NUMBER(4,0),
			CONSTRAINT ERD_CASE_PROD_ID_CPV_FK FOREIGN KEY (PROD_ID, CUST_PREF_VENDOR)
				REFERENCES SWMS.PM (PROD_ID, CUST_PREF_VENDOR) DISABLE
		) SEGMENT CREATION IMMEDIATE 
			PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
			STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
			PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
			TABLESPACE SWMS_DTS1';
    END IF;      

	SELECT count(*)
	INTO v_index_exists
	FROM all_objects
	WHERE object_name = 'ERD_CASE_FK1'
	AND owner = 'SWMS'
	AND object_Type = 'INDEX';

	IF v_index_exists = 0 THEN
		EXECUTE IMMEDIATE 'CREATE INDEX SWMS.ERD_CASE_FK1 ON SWMS.ERD_CASE (PROD_ID) 
			PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
			STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
			PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
			TABLESPACE SWMS_ITS1';
	END IF;
END;
/