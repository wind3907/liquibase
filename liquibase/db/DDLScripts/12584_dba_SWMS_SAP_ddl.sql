
--**********************************************************************
-- SCE020 – Non-Inventory Asset Tracking In STS
-- Script to Create a new Table and add a new column to LAS_TRUCK_EQUIPMENT_TYPE Table
--***********************************************************************/

/* Table changes*/
CREATE TABLE SWMS.STS_EQUIPMENT
(
    ROUTE_NO     VARCHAR2(10),
    TRUCK_NO     VARCHAR2(3),
    CUST_ID      VARCHAR2(14),
    BARCODE      VARCHAR2(8),
    STATUS       VARCHAR2(1),
    QTY          NUMBER(3,0),
    QTY_RETURNED NUMBER(3,0),
    ADD_DATE  DATE
);

/* Index creation*/
CREATE INDEX SWMS.STS_EQUIPMENT_IDX1 ON STS_EQUIPMENT (CUST_ID, STATUS) NOPARALLEL;


ALTER TABLE SWMS.LAS_TRUCK_EQUIPMENT_TYPE
ADD 
   (
      BARCODE  VARCHAR2(8)
   );
   
--**********************************************************************
-- SCE057 Add UOM Field to SWMS
-- Script to add  a new column in PM table
--***********************************************************************/
/* Table changes */

ALTER TABLE SWMS.PM
ADD
   (
      PROD_SIZE_UNIT varchar2(3)
   );

