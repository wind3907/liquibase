CREATE TABLE SWMS.DOD_LABEL_HEADER_BCKUP
(
  ROUTE_NO           VARCHAR2(10 CHAR)     NOT NULL,
  ORDER_ID           VARCHAR2(14 CHAR)     NOT NULL,
  STOP_NO            NUMBER(7,2)           NOT NULL,
  TRUCK_NO           VARCHAR2(10 CHAR),
  SHIP_DATE          DATE,
  STATUS             VARCHAR2(3 CHAR)      NOT NULL,
  CUST_ID            VARCHAR2(10 CHAR)     NOT NULL,
  CUST_NAME          VARCHAR2(30 CHAR),
  DOD_CONTRACT_NO    VARCHAR2(13 CHAR)     NOT NULL,
  ADD_DATE           DATE,
  ADD_USER           VARCHAR2(30 CHAR),
  PRINT_USER         VARCHAR2(30 CHAR),
  PRINT_FLAG         VARCHAR2(1 CHAR)      DEFAULT 'N',
  PRINT_DATE         DATE,
  BKUP_DATE          DATE                  DEFAULT  SYSDATE
)
SEGMENT CREATION IMMEDIATE PCTFREE 3 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_BACKUP";

CREATE OR REPLACE PUBLIC SYNONYM DOD_LABEL_HEADER_BCKUP FOR SWMS.DOD_LABEL_HEADER_BCKUP;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.DOD_LABEL_HEADER_BCKUP TO SWMS_USER;

GRANT SELECT ON SWMS.DOD_LABEL_HEADER_BCKUP TO SWMS_VIEWER;

CREATE TABLE SWMS.DOD_LABEL_DETAIL_BCKUP
(
  ORDER_ID               VARCHAR2(14 CHAR)      NOT NULL,
  ORDER_LINE_ID          NUMBER(3)              NOT NULL,
  PROD_ID                VARCHAR2(9 CHAR)       NOT NULL,
  ROUTE_NO               VARCHAR2(10 CHAR)      NOT NULL,
  SRC_LOC                VARCHAR2(10 CHAR),
  QTY_ALLOC              NUMBER(9),
  PALLET_ID              VARCHAR2(18 CHAR),
  BATCH_NO               NUMBER(9),
  MAX_CASE_SEQ           NUMBER(9),
  START_SEQ              NUMBER(9),
  END_SEQ                NUMBER(9),
  PACK_DATE              DATE,
  EXP_DATE               DATE,
  LOT_ID                 VARCHAR2(30 CHAR),
  DOD_CUST_ITEM_BARCODE  VARCHAR2(13 CHAR),
  DOD_FIC                VARCHAR2(3 CHAR),
  ADD_DATE               DATE,
  ADD_USER               VARCHAR2(30 CHAR),
  UPD_DATE               DATE,
  UPD_USER               VARCHAR2(30 CHAR),
  BKUP_DATE              DATE                  DEFAULT  SYSDATE
 )
 SEGMENT CREATION IMMEDIATE PCTFREE 3 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_BACKUP";

CREATE OR REPLACE PUBLIC SYNONYM DOD_LABEL_DETAIL_BCKUP FOR SWMS.DOD_LABEL_DETAIL_BCKUP;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.DOD_LABEL_DETAIL_BCKUP TO SWMS_USER;

GRANT SELECT ON SWMS.DOD_LABEL_DETAIL_BCKUP TO SWMS_VIEWER;