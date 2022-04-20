/****************************************************************************
** Date:       29-JUL-2021
** File:       DDL_Chic-Fil-A.sql
**
** Script to create table
**
**
** Modification History :
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    29-JUL-2021 Siva Rajamanickam    Table creation for Chic-Fil-A Project
**
****************************************************************************/
DECLARE
    v_exists NUMBER := 0;
BEGIN
    SELECT
        COUNT(*)
    INTO v_exists
    FROM
        user_tables
    WHERE
        table_name = 'GS1_CUST_ITEM_MAINT';

    IF ( v_exists = 0 ) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE GS1_CUST_ITEM_MAINT (
			CUST_ID			VARCHAR2(14 CHAR) NOT NULL,
			PROD_ID			VARCHAR2(9 CHAR) NOT NULL,
			CUST_PREF_VENDOR        VARCHAR2(10 CHAR) NOT NULL,
			GS1_ENABLED		VARCHAR2(1 CHAR),
			CONSTRAINT GS1_CUST_ITEM_MAINT_PK PRIMARY KEY (CUST_ID, PROD_ID))';
															 
        EXECUTE IMMEDIATE 'GRANT ALL ON GS1_CUST_ITEM_MAINT to swms_user';
        EXECUTE IMMEDIATE 'GRANT SELECT ON GS1_CUST_ITEM_MAINT to SWMS_VIEWER';
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM GS1_CUST_ITEM_MAINT FOR SWMS.GS1_CUST_ITEM_MAINT';
    END IF;

    SELECT
        COUNT(*)
    INTO v_exists
    FROM
        user_tables
    WHERE
        table_name = 'ORDGS1';

    IF ( v_exists = 0 ) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE ORDGS1 (
			ORDER_ID          		VARCHAR2(14 CHAR) NOT NULL,
			ORDER_LINE_ID     		NUMBER(3) NOT NULL,
			SEQ_NO                          NUMBER(4) NOT NULL,
			ROUTE_NO          		VARCHAR2(10 CHAR) NOT NULL,
			PROD_ID           		VARCHAR2(9 CHAR),
			CUST_PREF_VENDOR  		VARCHAR2(10 CHAR),
			SHIPPED_DATE      		DATE,
			GS1_GTIN          		VARCHAR2(14),
			UOM               		VARCHAR2(1),
			GS1_LOT_ID        		VARCHAR2(20),
			GS1_PRODUCTION_DATE             DATE,
			CUST_PO                         VARCHAR2(15 CHAR),
			ADD_DATE          		DATE DEFAULT sysdate,
			ADD_USER          		VARCHAR2(30 CHAR) NOT NULL,
			UPD_DATE          		DATE,
			UPD_USER          		VARCHAR2(30 CHAR),
			FLOAT_NO                        NUMBER(7),
			SCAN_METHOD                     CHAR(1 CHAR),
			ORDER_SEQ                       NUMBER(8),
			CASE_ID                         NUMBER(13) GENERATED ALWAYS AS ("ORDER_SEQ"*1000+"SEQ_NO") VIRTUAL VISIBLE,
                        CONSTRAINT ORDGS1_PK PRIMARY KEY(ORDER_ID,ORDER_LINE_ID,SEQ_NO))';
			
        EXECUTE IMMEDIATE 'GRANT ALL ON ORDGS1 to swms_user';
        EXECUTE IMMEDIATE 'GRANT SELECT ON ORDGS1 to SWMS_VIEWER';
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM ORDGS1 FOR SWMS.ORDGS1';
    END IF;

    SELECT
        COUNT(*)
    INTO v_exists
    FROM
        user_tables
    WHERE
        table_name = 'ORDGS1_BCKUP';

    IF ( v_exists = 0 ) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE ORDGS1_BCKUP (
			ORDER_ID          		VARCHAR2(14 CHAR) NOT NULL,
			ORDER_LINE_ID     		NUMBER(3) NOT NULL,
			SEQ_NO                          NUMBER(4) NOT NULL,
			ROUTE_NO          		VARCHAR2(10 CHAR) NOT NULL,
			PROD_ID           		VARCHAR2(9 CHAR),
			CUST_PREF_VENDOR  		VARCHAR2(10 CHAR),
			SHIPPED_DATE      		DATE,
			GS1_GTIN          		VARCHAR2(14),
			UOM               		VARCHAR2(1),
			GS1_LOT_ID        		VARCHAR2(20),
			GS1_PRODUCTION_DATE             DATE,
			CUST_PO                         VARCHAR2(15 CHAR),
			ADD_DATE          		DATE DEFAULT sysdate,
			ADD_USER          		VARCHAR2(30 CHAR) NOT NULL,
			BKUP_DATE                       DATE DEFAULT sysdate,
			UPD_DATE          		DATE,
			UPD_USER          		VARCHAR2(30 CHAR),
			FLOAT_NO                        NUMBER(7),
			SCAN_METHOD                     CHAR(1 CHAR),
			ORDER_SEQ                       NUMBER(8),
			CASE_ID                         NUMBER(13))';
			
        EXECUTE IMMEDIATE 'GRANT ALL ON ORDGS1_BCKUP to swms_user';
        EXECUTE IMMEDIATE 'GRANT SELECT ON ORDGS1_BCKUP to SWMS_VIEWER';
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM ORDGS1_BCKUP FOR SWMS.ORDGS1_BCKUP';
    END IF;

    SELECT
        COUNT(*)
    INTO v_exists
    FROM
        user_tables
    WHERE
        table_name = 'GS1_OUT';

    IF ( v_exists = 0 ) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE GS1_OUT (
			ORDER_ID          		VARCHAR2(14 CHAR) NOT NULL,
			ORDER_LINE_ID     		NUMBER(3) NOT NULL,
			SEQ_NO                          NUMBER(4) NOT NULL,
			RECORD_STATUS     		VARCHAR2(1 CHAR) NOT NULL,
			ROUTE_NO          		VARCHAR2(10 CHAR) NOT NULL,
			PROD_ID           		VARCHAR2(9 CHAR),
			CUST_PREF_VENDOR  		VARCHAR2(10 CHAR),
			SHIPPED_DATE      		DATE,
			GS1_GTIN          		VARCHAR2(14),
			UOM               		VARCHAR2(1),
			GS1_LOT_ID        		VARCHAR2(20),
			GS1_PRODUCTION_DATE             DATE,
			CUST_PO                         VARCHAR2(15 CHAR),
			ADD_DATE          		DATE DEFAULT sysdate,
			ADD_USER          		VARCHAR2(30 CHAR) NOT NULL,
			UPD_DATE          		DATE,
			UPD_USER          		VARCHAR2(30 CHAR),
			FLOAT_NO                        NUMBER(7),
			SCAN_METHOD                     CHAR(1 CHAR),
			ORDER_SEQ                       NUMBER(8),
			CASE_ID                         NUMBER(13),
                        CONSTRAINT GS1_OUT_PK PRIMARY KEY(ORDER_ID,ORDER_LINE_ID,SEQ_NO))';
			
        EXECUTE IMMEDIATE 'GRANT ALL ON GS1_OUT to swms_user';
        EXECUTE IMMEDIATE 'GRANT SELECT ON GS1_OUT to SWMS_VIEWER';
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM GS1_OUT FOR SWMS.GS1_OUT';
    END IF;

END;
/
