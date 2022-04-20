/****************************************************************************
** Date:       22-JAN-2013
** Programmer: Singh Swati
** File:       38526_dba_add_food_safety_inbound_child.sql
** CRQ#:       38526	 
** 
** This script creates a 'FOOD_SAFETY_INBOUND_CHILD' table
******************************************************************************/
create table SWMS.FOOD_SAFETY_INBOUND_CHILD
( LOAD_NO VARCHAR2(12),
PARENT_ERM_ID Varchar2(12) NOT NULL,
ERM_ID Varchar2(12) NOT NULL,
ADD_DATE date DEFAULT SYSDATE NOT NULL,
ADD_SOURCE VARCHAR2(5),
ADD_USER VARCHAR2(10) DEFAULT REPLACE(USER, 'OPS$') NOT NULL,
UPD_SOURCE VARCHAR2(5),
UPD_DATE date,
UPD_USER Varchar2(10)
);

alter table FOOD_SAFETY_INBOUND_CHILD ADD CONSTRAINT FOOD_SAFETY_INBOUND_CHILD_PK primary key(ERM_ID);

CREATE OR REPLACE PUBLIC SYNONYM FOOD_SAFETY_INBOUND_CHILD FOR SWMS.FOOD_SAFETY_INBOUND_CHILD;


--GRANT ALL ON swms.FOOD_SAFETY_INBOUND_CHILD TO SWMS_USER;
/
