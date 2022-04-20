----------------------------------------------------------------------------------
--
-- Date:       03-03-10
-- Programmer: CTVGG000	
-- File:       12567_dba_sts_manifest_schema_changes.sql
-- Defect#:    12567
-- Project ID: 534000
-- Project:    Manifest to STS
--
--
-- Add a new table to store Invoice, stop level manifest summary information.
--
----------------------------------------------------------------------------------
CREATE TABLE SWMS.MANIFEST_STOPS
(
  MANIFEST_NO        NUMBER(7)                  NOT NULL,
  STOP_NO            NUMBER(7,2)                NOT NULL,
  OBLIGATION_NO      VARCHAR2(16)               NOT NULL,
  INVOICE_NO         VARCHAR2(16)               NOT NULL,
  CUSTOMER_ID        VARCHAR2(14)               NOT NULL,
  CUSTOMER           VARCHAR2(30)               NOT NULL,
  ADDR_LINE_1        VARCHAR2(80)               NOT NULL,
  ADDR_LINE_2        VARCHAR2(40),
  ADDR_LINE_3        VARCHAR2(160),
  ADDR_CITY          VARCHAR2(20)               NOT NULL,
  ADDR_STATE         VARCHAR2(3)                NOT NULL,
  ADDR_POSTAL_CODE   VARCHAR2(10),
  SALESPERSON_ID     VARCHAR2(9),
  SALESPERSON        VARCHAR2(30),
  TIME_IN            VARCHAR2(6),
  TIME_OUT           VARCHAR2(6),
  BUSINESS_HRS_FROM  VARCHAR2(4),
  BUSINESS_HRS_TO    VARCHAR2(4),
  TERMS              VARCHAR2(30)               NOT NULL,
  INVOICE_QTY        NUMBER(5)                  NOT NULL,
  INVOICE_AMT        NUMBER(9,2)                NOT NULL,
  INVOICE_CUBE       NUMBER(9,2)                NOT NULL,
  INVOICE_WGT        NUMBER(9,2)                NOT NULL,
  NOTES              VARCHAR2(160)
);


ALTER TABLE SWMS.MANIFEST_STOPS ADD (
  CONSTRAINT MANIFEST_STOPS_PK
 PRIMARY KEY (MANIFEST_NO, OBLIGATION_NO, INVOICE_NO, STOP_NO ));

CREATE PUBLIC SYNONYM MANIFEST_STOPS FOR SWMS.MANIFEST_STOPS;
GRANT ALL ON MANIFEST_STOPS TO SWMS_USER;
GRANT ALL ON MANIFEST_STOPS TO SWMS_VIEWER;
