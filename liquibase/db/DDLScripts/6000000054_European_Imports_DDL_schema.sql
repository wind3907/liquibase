/****************************************************************************
** Date:       05-MAY-2014
** File:       6000000054_European_Imports_DDL.sql
**
** Script to create tables as part of 
**		European Imports integration
**
** Create below tables along with index and synonyms
** 		1.CROSS_DOCK_DATA_COLLECT_IN
** 		2.CROSS_DOCK_DATA_COLLECT
** 		3.CROSS_DOCK_XREF
** 		4.CROSS_DOCK_STATUS
** 		5.CROSS_DOCK_TYPE
**		6.CROSS_DOCK_PALLET_XREF
**
** Alter below table to include a new field, CROSS_DOCK_TYPE,DATA_COLLECT
**		1.ERM
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    05-MAY-14 Infosys  Created 6 new tables and altered 1 existing table 
**						mentioned above
**
****************************************************************************/


/*  
**  Alter Table script for European Imports. New Column Cross Dock Type added        
*/
ALTER TABLE swms.erm ADD (sys_order_id	  VARCHAR2(10 CHAR));
ALTER TABLE swms.erm ADD (cross_dock_type VARCHAR2(2 CHAR));
ALTER TABLE swms.erm ADD (data_collect	  VARCHAR2(1 CHAR));
ALTER TABLE swms.ordm ADD (cross_dock_type VARCHAR2(2 CHAR));

/* 
**  Create table Script for European Imports Data Collection - Inbound Table
*/

CREATE TABLE SWMS.CROSS_DOCK_DATA_COLLECT_IN
(
  SEQUENCE_NUMBER     		NUMBER(10),
  INTERFACE_TYPE      		VARCHAR2(3 CHAR),
  RECORD_STATUS       		VARCHAR2(1 CHAR),
  DATETIME            		DATE,
  RETAIL_CUST_NO		VARCHAR2(14 CHAR)	NOT NULL,
  SHIP_DATE			DATE,
  PARENT_PALLET_ID		VARCHAR2(18 CHAR),
  ERM_ID              		VARCHAR2(12 CHAR),
  REC_TYPE            		VARCHAR2(1 CHAR),
  PROD_ID             		VARCHAR2(9 CHAR),
  LINE_NO             		NUMBER(4),
  QTY                 		NUMBER(8),
  UOM                 		NUMBER(2),
  AREA                		VARCHAR2(1 CHAR),
  PALLET_TYPE				VARCHAR2(2 CHAR),
  EXP_DATE            		DATE,
  CATCH_WT            		NUMBER(9,3),
  CATCH_WT_UOM        		VARCHAR2(3 CHAR),
  MSG_ID              		VARCHAR2(36 CHAR),
  ADD_USER            		VARCHAR2(30 CHAR),
  ADD_DATE            		DATE,
  UPD_USER            		VARCHAR2(30 CHAR),
  UPD_DATE            		DATE
);


CREATE OR REPLACE PUBLIC SYNONYM CROSS_DOCK_DATA_COLLECT_IN FOR SWMS.CROSS_DOCK_DATA_COLLECT_IN;

CREATE SEQUENCE SWMS.CROSS_DOCK_DATA_COLLECT_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM CROSS_DOCK_DATA_COLLECT_SEQ FOR SWMS.CROSS_DOCK_DATA_COLLECT_SEQ;

CREATE INDEX SWMS.CROSS_DOCK_DATA_IN_IDX1 ON SWMS.CROSS_DOCK_DATA_COLLECT_IN
(RECORD_STATUS);

CREATE INDEX SWMS.CROSS_DOCK_DATA_IN_IDX2 ON SWMS.CROSS_DOCK_DATA_COLLECT_IN
(REC_TYPE);

/* 
**  Create table Script for European Imports Data Collection 
*/
CREATE TABLE swms.cross_dock_data_collect
(
  erm_id                  VARCHAR2(12 CHAR)     NOT NULL,
  rec_type                VARCHAR2(1 CHAR),
  line_no                 NUMBER(4),
  prod_id                 VARCHAR2(9 CHAR),
  qty                     NUMBER(8),
  uom                     NUMBER(2),
  area                    VARCHAR2(1 CHAR),
  pallet_id               VARCHAR2(18 CHAR),
  parent_pallet_id        VARCHAR2(18 CHAR),
  pallet_type             VARCHAR2(2 CHAR),
  temp             		  NUMBER(6,1),
  temp_unit               VARCHAR2(1 CHAR),
  exp_date                DATE,
  mfg_date                DATE,
  catch_wt                NUMBER(9,3),
  catch_wt_unit           VARCHAR2(3 CHAR),
  harvest_date            DATE,
  clam_bed_no             VARCHAR2(10 CHAR),
  country_of_origin       VARCHAR2(2 CHAR),
  wild_farm               VARCHAR2(1 CHAR),  
  data_collect  		  VARCHAR2(1 CHAR),
  add_date                DATE,
  upd_date                DATE,
  add_user                VARCHAR2(30 CHAR),
  upd_user                VARCHAR2(30 CHAR)
);

CREATE INDEX SWMS.CROSS_DOCK_DATA_IDX1 ON SWMS.CROSS_DOCK_DATA_COLLECT
(REC_TYPE, PALLET_ID, PARENT_PALLET_ID);

CREATE INDEX SWMS.CROSS_DOCK_DATA_IDX2 ON SWMS.CROSS_DOCK_DATA_COLLECT
(REC_TYPE);

CREATE OR REPLACE PUBLIC SYNONYM CROSS_DOCK_DATA_COLLECT FOR SWMS.CROSS_DOCK_DATA_COLLECT;

/* 
**  Create table script for Cross Dock Reference. 
*/

CREATE TABLE swms.cross_dock_xref
(
  erm_id                  VARCHAR2(12 CHAR)     NOT NULL,
  sys_order_id            NUMBER(10),
  status                  VARCHAR2(3 CHAR),
  add_date                DATE,
  upd_date                DATE,
  CONSTRAINT cdk_pk PRIMARY KEY (erm_id, sys_order_id,status)
);

ALTER TABLE swms.cross_dock_xref
ADD CONSTRAINT erm_id_unique UNIQUE (erm_id);


CREATE OR REPLACE PUBLIC SYNONYM CROSS_DOCK_XREF FOR SWMS.CROSS_DOCK_XREF;

/* 
**  Create table script for Cross Dock Pallet Reference. 
*/

CREATE TABLE swms.cross_dock_pallet_xref
(
  RETAIL_CUST_NO		  VARCHAR2(10 CHAR)     NOT NULL,
  erm_id                  VARCHAR2(12 CHAR)     NOT NULL,
  sys_order_id            NUMBER(10),
  parent_pallet_id        VARCHAR2(18 CHAR)     NOT NULL,
  ship_date               DATE,
  float_no          	  NUMBER(9),
  batch_no          	  VARCHAR2(13 CHAR),
  add_user                VARCHAR2(30 CHAR)     DEFAULT USER,
  add_date                DATE                  DEFAULT SYSDATE,
  upd_user                VARCHAR2(30 CHAR),
  upd_date                DATE,
  CONSTRAINT cross_dock_pallet_xref_pk PRIMARY KEY (retail_cust_no,parent_pallet_id,erm_id)
);

CREATE INDEX SWMS.CROSS_DOCK_PALLET_XREF_IDX1 ON SWMS.CROSS_DOCK_PALLET_XREF
(SYS_ORDER_ID);

CREATE INDEX SWMS.CROSS_DOCK_PALLET_XREF_IDX2 ON SWMS.CROSS_DOCK_PALLET_XREF
(PARENT_PALLET_ID);


CREATE OR REPLACE PUBLIC SYNONYM cross_dock_pallet_xref FOR SWMS.cross_dock_pallet_xref;

/*
**  Create table script for Cross Dock Status.
*/

CREATE TABLE swms.CROSS_DOCK_STATUS
(
  status                  VARCHAR2(3 CHAR)      NOT NULL,
  description             VARCHAR2(30 CHAR)     NOT NULL,
  seq					  NUMBER
);


CREATE OR REPLACE PUBLIC SYNONYM CROSS_DOCK_STATUS FOR SWMS.CROSS_DOCK_STATUS;

/* 
**  Create table script for Cross Dock Type.
*/ 

CREATE TABLE swms.CROSS_DOCK_TYPE
(
  CROSS_DOCK_TYPE                   VARCHAR2(2 CHAR)     NOT NULL,
  RECEIVE_WHOLE_PALLET              VARCHAR2(1 CHAR)     NOT NULL,   
  DESCRIPTION           			VARCHAR2(32 CHAR)    NOT NULL        
);


CREATE OR REPLACE PUBLIC SYNONYM CROSS_DOCK_TYPE FOR SWMS.CROSS_DOCK_TYPE;

CREATE OR REPLACE PUBLIC SYNONYM PL_RCV_CROSS_DOCK  FOR SWMS.PL_RCV_CROSS_DOCK;                 

CREATE OR REPLACE PUBLIC SYNONYM PL_CROSS_DOCK_ORDER_PROCESSING  FOR SWMS.PL_CROSS_DOCK_ORDER_PROCESSING;     

