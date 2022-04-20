
--    20-jun-2012    modifiied tables for PI Direct insert in to staging table.

/****************************************************************************
** Date:       20-JUN-2011
** File:       CRQ37911_PI_direct_insert_dml_schema.sql
**
** Alters the SAP_PO_IN and SAP_CS_IN statging tables for direct PI 
** insert in to staging tables.
**
** Redundant Fields  are removed from tables :
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    06/20/12 ssin2436 CRQ37911
**                      Project: CRQ37911_PI_direct_insert_dml_schema.sql - 
**                      For inbound interfaces for PI direct insert in to 
**                      staging table removed the redundant fields from the
**			table and have modified the size of fields.  
**                      
**                      
**
****************************************************************************/

/* Taking backup of the records for SAP_CS_IN and CUBITRON_MEASUREMENT_IN table before altering the table*/

CREATE TABLE SWMS.SAP_CS_IN_BK AS SELECT * FROM SWMS.SAP_CS_IN;
COMMIT;

CREATE TABLE SWMS.CUBITRON_MEASUREMENT_IN_BK AS SELECT * FROM SWMS.CUBITRON_MEASUREMENT_IN;
COMMIT;

TRUNCATE TABLE SWMS.SAP_CS_IN;
ALTER TABLE SWMS.SAP_CS_IN
MODIFY DATETIME DATE;

TRUNCATE TABLE SWMS.CUBITRON_MEASUREMENT_IN;
ALTER TABLE SWMS.CUBITRON_MEASUREMENT_IN
MODIFY SCAN_DATE DATE;

ALTER TABLE SWMS.SAP_PO_IN 
MODIFY sched_date VARCHAR2(8);

ALTER TABLE SWMS.SAP_PO_IN 
MODIFY sched_time VARCHAR(6);

ALTER TABLE SWMS.SAP_PO_IN DROP COLUMN INBOUND_SCHED_DATE;

ALTER TABLE SWMS.SAP_PO_IN DROP COLUMN INBOUND_SCHED_TIME;

