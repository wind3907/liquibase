/****************************************************************************
** Date:       17-Aug-2015
** File:       Charm-6000007850_DDL_ORDCW_HIST_Table.sql
**
**             Script to create table ORDCW_HIST 
**             for storing the audit history data of ORDCW .
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    17-Aug-15 AKLU6632 Charm#6000007850
**                       Project: Catch weight Frequency Scan VS Keying Project
**
****************************************************************************/

CREATE TABLE SWMS.ORDCW_HIST
(
  ORDER_ID          VARCHAR2(14 CHAR),
  ORDER_LINE_ID     NUMBER(3),
  SEQ_NO            NUMBER(4),
  PROD_ID           VARCHAR2(9 CHAR),
  CUST_PREF_VENDOR  VARCHAR2(10 CHAR),
  CATCH_WEIGHT      NUMBER(9,3),
  CW_TYPE           VARCHAR2(1 CHAR),
  UOM               NUMBER(1),
  ADD_DATE          DATE,
  ADD_USER          VARCHAR2(30 CHAR),
  UPD_DATE          DATE,
  UPD_USER          VARCHAR2(30 CHAR),
  CW_FLOAT_NO       NUMBER(7),
  CW_SCAN_METHOD    CHAR(1 CHAR),
  ORDER_SEQ         NUMBER(8),
  CASE_ID           NUMBER(13),
  CW_KG_LB          NUMBER(9,3),
  BKUP_DATE         DATE,
  BKUP_USER         VARCHAR2(30 CHAR)
);

COMMENT ON TABLE SWMS.ORDCW_HIST IS 'ORDCW HIST FOR CATCHWEIGHT HISTORY DATA FOR CHARM 6000007850';

CREATE OR REPLACE PUBLIC SYNONYM ORDCW_HIST FOR SWMS.ORDCW_HIST;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.ORDCW_HIST TO SWMS_USER;

GRANT SELECT ON SWMS.ORDCW_HIST TO SWMS_VIEWER;

CREATE INDEX SWMS.ORDCW_HIST_IDX1
ON SWMS.ORDCW_HIST(UPD_USER);

CREATE INDEX SWMS.ORDCW_HIST_IDX2
ON SWMS.ORDCW_HIST(UPD_DATE);
