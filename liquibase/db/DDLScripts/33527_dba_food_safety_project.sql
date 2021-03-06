--CRQ #33527, created for food safety project
create table SWMS.FOOD_SAFETY_OUTBOUND(
MANIFEST_NO NUMBER(7) NOT NULL,
CUSTOMER_ID VARCHAR2(14),
STOP_NO NUMBER(7,2) NOT NULL,
OBLIGATION_NO VARCHAR2(16) NOT NULL,
PROD_ID VARCHAR2(9) NOT NULL,
TEMP_COLLECTED NUMBER,
TIME_COLLECTED DATE,
ADD_SOURCE VARCHAR2(5),
ADD_DATE DATE DEFAULT SYSDATE NOT NULL,
ADD_USER VARCHAR2(10) DEFAULT REPLACE(USER, 'OPS$') NOT NULL,
UPD_SOURCE VARCHAR2(5),
UPD_DATE DATE,
UPD_USER VARCHAR2(10));


alter table FOOD_SAFETY_OUTBOUND add constraint FOOD_SAFETY_OUTBOUND_PK primary key (MANIFEST_NO, STOP_NO, PROD_ID);

CREATE OR REPLACE PUBLIC SYNONYM FOOD_SAFETY_OUTBOUND FOR SWMS.FOOD_SAFETY_OUTBOUND;

create table SWMS.FOOD_SAFETY_INBOUND
( LOAD_NO VARCHAR2(12),
DOOR_NO VARCHAR2(4) NOT NULL,
DOOR_OPEN_TIME date,
FRONT_TEMP number,
MID_TEMP number,
BACK_TEMP number,
ERM_ID Varchar2(12) NOT NULL,
ERM_TYPE Varchar2(3),
TIME_COLLECTED date,
ADD_DATE date DEFAULT SYSDATE NOT NULL,
ADD_SOURCE VARCHAR2(5),
ADD_USER VARCHAR2(10) DEFAULT REPLACE(USER, 'OPS$') NOT NULL,
UPD_SOURCE VARCHAR2(5),
UPD_DATE date,
UPD_USER Varchar2(10)
);

alter table FOOD_SAFETY_INBOUND ADD CONSTRAINT FOOD_SAFETY_INBOUND_PK primary key(ERM_ID);

CREATE OR REPLACE PUBLIC SYNONYM FOOD_SAFETY_INBOUND FOR SWMS.FOOD_SAFETY_INBOUND;
CREATE OR REPLACE PUBLIC SYNONYM FOOD_SAFETY_OUTBOUND FOR SWMS.FOOD_SAFETY_OUTBOUND;

ALTER TABLE BATCH ADD(DOOR_DROP_TIME DATE);
ALTER TABLE ARCH_BATCH ADD(DOOR_DROP_TIME DATE);
ALTER TABLE SAP_PO_IN ADD(LOAD_NO VARCHAR(12));
