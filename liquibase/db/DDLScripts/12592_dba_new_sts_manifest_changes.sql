----------------------------------------------------------------------------------
--
-- Date:       06-26-10
-- Programmer: CTVGG000
-- File:       12592_dba_sts_manifest_schema_changes.sql
-- Defect#:    12592
-- Project:    Changes to manifest to STS project 
--             Drop Not Null constraint on column TERMS and OBLIGATION_NO 
--
-- Version 2 : 01-18-11
--             Changed to accomodate new requirements at the time of moving this
--             file to 12.0
--
--             1. Removed alter statement to make the obligation# column nullable.
--             2. Modified ALTER statement which adds a not null REC_TYPE column
--                to an ALTER statement which adds a nullable REC_TYPE column to
--                manifest_stops table.
--             3. Modified INVOICE_WGT column from NUMBER(9,2) to NUMBER(9,3).
--             4. Modified INVOICE_CUBE column from NUMBER(9,2) to NUMBER(9,3).
----------------------------------------------------------------------------------

ALTER TABLE SWMS.MANIFEST_STOPS MODIFY TERMS VARCHAR2(30) NULL;

ALTER TABLE SWMS.MANIFEST_STOPS ADD REC_TYPE CHAR(1); 

-- This script was changed when moving from CMVC to clearcase to add the below
-- statements and comment the above statement altering the obligation column.

-- Obligation # cannot be a nullable field since it is a part of the primary key
-- for manifest_stops table and also SUS will always send a value for this field.

-- The below is for companies that already have REC_TYPE Column installed from the
-- earlier version of this script.

ALTER TABLE SWMS.MANIFEST_STOPS MODIFY REC_TYPE CHAR(1) NULL;

ALTER TABLE SWMS.MANIFEST_STOPS MODIFY INVOICE_CUBE NUMBER(9,3);

ALTER TABLE SWMS.MANIFEST_STOPS MODIFY INVOICE_WGT NUMBER(9,3);


