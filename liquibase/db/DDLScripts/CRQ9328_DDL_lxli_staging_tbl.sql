CREATE TABLE SWMS.LXLI_STAGING_HDR_OUT
(
   SEQUENCE_NUMBER        NUMBER NOT NULL,
   LFUN_LBR_FUNC          VARCHAR2 (2 CHAR),
   RECORD_STATUS          VARCHAR2 (1 CHAR),
   FILE_NAME              VARCHAR2 (100 CHAR),
   RESEND_FLAG            NUMBER,
   FTP_TIMESTAMP          DATE,
   TABLE_PROCESSED_FROM   VARCHAR2 (30 CHAR),
   ADD_DATE               DATE DEFAULT SYSDATE,
   ADD_USER               VARCHAR2 (30 CHAR) DEFAULT REPLACE (USER, 'OPS$'),
   UPD_DATE               DATE,
   UPD_USER               VARCHAR2 (30 CHAR)
) SEGMENT CREATION IMMEDIATE PCTFREE 3 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM LXLI_STAGING_HDR_OUT FOR SWMS.LXLI_STAGING_HDR_OUT;

CREATE INDEX SWMS.LXLI_STAGING_HDR_OUT_PK ON SWMS.LXLI_STAGING_HDR_OUT (SEQUENCE_NUMBER)
TABLESPACE SWMS_ITS1
STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
PCTFREE 10;

ALTER TABLE SWMS.LXLI_STAGING_HDR_OUT ADD (
  CONSTRAINT LXLI_STAGING_HDR_OUT_PK
  PRIMARY KEY
  (SEQUENCE_NUMBER)
  USING INDEX SWMS.LXLI_STAGING_HDR_OUT_PK
  ENABLE VALIDATE);

GRANT DELETE,
      INSERT,
      SELECT,
      UPDATE
   ON SWMS.LXLI_STAGING_HDR_OUT
   TO SWMS_USER;

GRANT SELECT ON SWMS.LXLI_STAGING_HDR_OUT TO SWMS_VIEWER;

--SWMS.LXLI_STAGING_LD_OUT

CREATE TABLE SWMS.LXLI_STAGING_LD_OUT
(
   SEQUENCE_NUMBER   NUMBER NOT NULL,
   LBATCH_NO         VARCHAR2 (13 CHAR),
   SBATCH_NO         VARCHAR2 (13 CHAR),
   BATCH_DATE        DATE,
   FLOAT_ID          VARCHAR2 (4 CHAR),
   HI_SUM_PIECE      NUMBER (6),
   KVI_CUBE          NUMBER (6),
   KVI_WEIGHT        NUMBER (6),
   USER_ID           VARCHAR2 (30 CHAR),
   PALLET_JACK_ID    VARCHAR2 (10 CHAR),
   ROUTE_NO          VARCHAR2 (10 CHAR),
   TRUCK_NO          VARCHAR2 (10 CHAR),
   TRAILER           VARCHAR2 (30 CHAR),
   DOOR_AREA         VARCHAR2 (3 CHAR),
   ACTL_START_TIME   VARCHAR2(20),
   L_JBCD_JOB_CODE   VARCHAR2 (6 CHAR),
   TRUCK_MAX_ZONE    VARCHAR2 (10 CHAR),
   TRAILER_LEN       VARCHAR2 (3 CHAR),
   S_JBCD_JOB_CODE   VARCHAR2 (6 CHAR),
   C_DESCR           VARCHAR2 (15 CHAR),
   F_DESCR           VARCHAR2 (15 CHAR),
   D_DESCR           VARCHAR2 (15 CHAR),
   BATCH_FLAG        VARCHAR2 (1 CHAR),
   RESEND_FLAG       VARCHAR2 (1 CHAR),
   DATA_STRING       VARCHAR2 (2000 CHAR),
   ERROR_CODE        VARCHAR2 (100 CHAR),
   ERROR_MSG         VARCHAR2 (2000 CHAR),
   ADD_DATE          DATE DEFAULT SYSDATE,
   ADD_USER          VARCHAR2 (30 CHAR) DEFAULT REPLACE (USER, 'OPS$'),
   UPD_DATE          DATE,
   UPD_USER          VARCHAR2 (30 CHAR)
)
SEGMENT CREATION IMMEDIATE PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM LXLI_STAGING_LD_OUT FOR SWMS.LXLI_STAGING_LD_OUT;

CREATE INDEX SWMS.LXLI_STAGING_LD_OUT_R01 ON SWMS.LXLI_STAGING_LD_OUT (SEQUENCE_NUMBER)
TABLESPACE SWMS_ITS1
STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
PCTFREE 10;

ALTER TABLE SWMS.LXLI_STAGING_LD_OUT ADD (
  CONSTRAINT LXLI_STAGING_LD_OUT_R01
  FOREIGN KEY (SEQUENCE_NUMBER)
  REFERENCES SWMS.LXLI_STAGING_HDR_OUT (SEQUENCE_NUMBER)
  ON DELETE CASCADE
  ENABLE VALIDATE);

GRANT DELETE,
      INSERT,
      SELECT,
      UPDATE
   ON SWMS.LXLI_STAGING_LD_OUT
   TO SWMS_USER;

GRANT SELECT ON SWMS.LXLI_STAGING_LD_OUT TO SWMS_VIEWER;

--LXLI_STAGING_SL_OUT

CREATE TABLE SWMS.LXLI_STAGING_SL_OUT
(
   SEQUENCE_NUMBER         NUMBER  NOT NULL,
   BATCH_NO                VARCHAR2 (13 CHAR),
   BATCH_DATE              DATE,
   FLOAT_NO                NUMBER(9),
   FLOAT_DETAIL_SEQ_NO     NUMBER(3),
   CUST_ID                 VARCHAR2 (10 CHAR),
   STOP_NO                 NUMBER (7, 2),
   DOOR_NO                 NUMBER (3),
   PROD_ID                 VARCHAR2 (9 CHAR),
   SRC_LOC                 VARCHAR2 (10 CHAR),
   LOC_PALLET_TYPE         VARCHAR2 (2 CHAR),
   QTY_ALLOC               NUMBER (9),
   SHIP_DATE               VARCHAR2(20),
   ROUTE_NO                VARCHAR2 (10 CHAR),
   TOTAL_DTL_CUBE          NUMBER (12, 4),
   WEIGHT                  NUMBER (8, 4),
   SPLIT_FLAG              VARCHAR2 (1 CHAR),
   CATCH_WT_TRK            VARCHAR2 (1 CHAR),
   FLOAT_BATCH_SEQ         NUMBER (2),
   ZONE_ON_FLOAT           NUMBER (2),
   SEL_TYPE                VARCHAR2 (3 CHAR),
   EQUIP_ID                VARCHAR2 (10 CHAR),
   QTY_SHORT               NUMBER (3),
   SCAN_TYPE               VARCHAR2 (1 CHAR),
   CATCH_WT_ENTRY_METHOD   VARCHAR2 (1 CHAR),
   AREA                    VARCHAR2 (1 CHAR),
   USER_ID                 VARCHAR2 (30 CHAR),
   START_TIME              VARCHAR2(20),
   LOC_UOM                 NUMBER (2),
   JBCD_JOB_CODE           VARCHAR2 (6 CHAR),
   PICKTIME                VARCHAR2(20),
   COO_TRK_FLAG            VARCHAR2 (1 CHAR),
   CLAMBED_TRK_FLAG        VARCHAR2 (1 CHAR),
   RESEND_FLAG             VARCHAR2 (1 CHAR),
   DATA_STRING             VARCHAR2 (2000 CHAR),
   ERROR_CODE              VARCHAR2 (100 CHAR),
   ERROR_MSG               VARCHAR2 (2000 CHAR),
   ADD_DATE                DATE DEFAULT SYSDATE,
   ADD_USER                VARCHAR2 (30 CHAR) DEFAULT REPLACE (USER, 'OPS$'),
   UPD_DATE                DATE,
   UPD_USER                VARCHAR2 (30 CHAR)
)
SEGMENT CREATION IMMEDIATE PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM LXLI_STAGING_SL_OUT FOR SWMS.LXLI_STAGING_SL_OUT;

CREATE INDEX SWMS.LXLI_STAGING_SL_OUT_R01 ON SWMS.LXLI_STAGING_SL_OUT (SEQUENCE_NUMBER)
TABLESPACE SWMS_ITS1
STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
PCTFREE 10;

ALTER TABLE SWMS.LXLI_STAGING_SL_OUT ADD (
  CONSTRAINT LXLI_STAGING_SL_OUT_R01 
  FOREIGN KEY (SEQUENCE_NUMBER) 
  REFERENCES SWMS.LXLI_STAGING_HDR_OUT (SEQUENCE_NUMBER)
  ENABLE VALIDATE);

GRANT DELETE,INSERT,SELECT,UPDATE ON SWMS.LXLI_STAGING_SL_OUT TO SWMS_USER;

GRANT SELECT ON SWMS.LXLI_STAGING_SL_OUT TO SWMS_VIEWER;

--LXLI_STAGING_FL_HEADER_OUT

CREATE TABLE SWMS.LXLI_STAGING_FL_HEADER_OUT
(
   SEQUENCE_NUMBER     NUMBER,
   HDR_LINE_NUMBER     NUMBER,
   BATCH_NO            VARCHAR2 (13 CHAR),
   BATCH_DATE          DATE, 
   USER_ID             VARCHAR2 (30 CHAR),
   EQUIP_ID            VARCHAR2 (10 CHAR),
   JBCD_JOB_CODE       VARCHAR2 (6 CHAR),
   PALLET_ID           VARCHAR2 (18 CHAR),
   PROD_ID             VARCHAR2 (9 CHAR),
   TRANS_CASE_QTY      NUMBER (8),
   STACK_CASE_QTY      NUMBER (6),
   EXP_DATE            VARCHAR2(20),
   LATEST_TIMESTAMP    VARCHAR2(20),
   BATCH_START_TIME    VARCHAR2(20),
   START_SCAN_METHOD   VARCHAR2 (1 CHAR),
   BATCH_STOP_TIME     VARCHAR2(20),
   STOP_SCAN_METHOD    VARCHAR2 (1 CHAR),
   TO_LOCATION         VARCHAR2 (10 CHAR),
   MSKU_FLAG           VARCHAR2 (1 CHAR),
   STACK_SPLIT_QTY     NUMBER (6),
   RESEND_FLAG         VARCHAR2 (1 CHAR),
   DATA_STRING         VARCHAR2 (2000 CHAR),
   ERROR_CODE          VARCHAR2 (100 CHAR),
   ERROR_MSG           VARCHAR2 (2000 CHAR),
   ADD_DATE            DATE DEFAULT SYSDATE,
   ADD_USER            VARCHAR2 (30 CHAR) DEFAULT REPLACE (USER, 'OPS$'),
   UPD_DATE            DATE,
   UPD_USER            VARCHAR2 (30 CHAR)
)
SEGMENT CREATION IMMEDIATE PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM LXLI_STAGING_FL_HEADER_OUT FOR SWMS.LXLI_STAGING_FL_HEADER_OUT;

CREATE INDEX SWMS.LXLI_STAGING_FL_HEADER_OUT_NK1 ON SWMS.LXLI_STAGING_FL_HEADER_OUT (SEQUENCE_NUMBER,HDR_LINE_NUMBER)
TABLESPACE SWMS_ITS1
STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
PCTFREE 10;

GRANT DELETE,INSERT,SELECT,UPDATE ON SWMS.LXLI_STAGING_FL_HEADER_OUT TO SWMS_USER;

GRANT SELECT ON SWMS.LXLI_STAGING_FL_HEADER_OUT TO SWMS_VIEWER;

--LXLI_STAGING_FL_INV_OUT

CREATE TABLE SWMS.LXLI_STAGING_FL_INV_OUT
(
   SEQUENCE_NUMBER    NUMBER NOT NULL,
   HDR_LINE_NUMBER    NUMBER,
   LINE_NUMBER        NUMBER,
   BATCH_NO           VARCHAR2 (13 CHAR),
   BATCH_DATE         DATE,
   PLOGILOC           VARCHAR2 (10 CHAR),
   LOCATION_IND       VARCHAR2 (4 CHAR),
   PALLET_ID          VARCHAR2 (18 CHAR),
   PROD_ID            VARCHAR2 (9 CHAR),
   SYS_QTY            NUMBER (8),
   ACTUAL_QTY         NUMBER (8),
   EXP_DATE           VARCHAR2(20),
   LATEST_TIMESTAMP   VARCHAR2(20),
   RESEND_FLAG        VARCHAR2 (1 CHAR),
   DATA_STRING        VARCHAR2 (2000 CHAR),
   ERROR_CODE         VARCHAR2 (100 CHAR),
   ERROR_MSG          VARCHAR2 (2000 CHAR),
   ADD_DATE           DATE DEFAULT SYSDATE,
   ADD_USER           VARCHAR2 (30 CHAR) DEFAULT REPLACE (USER, 'OPS$'),
   UPD_DATE           DATE,
   UPD_USER           VARCHAR2 (30 CHAR)
)
SEGMENT CREATION IMMEDIATE PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM LXLI_STAGING_FL_INV_OUT FOR SWMS.LXLI_STAGING_FL_INV_OUT;

ALTER TABLE SWMS.LXLI_STAGING_FL_INV_OUT ADD (
  CONSTRAINT LXLI_STAGING_FL_INV_OUT_R01 
  FOREIGN KEY (SEQUENCE_NUMBER) 
  REFERENCES SWMS.LXLI_STAGING_HDR_OUT (SEQUENCE_NUMBER)
  ENABLE VALIDATE);

GRANT DELETE,INSERT,SELECT,UPDATE ON SWMS.LXLI_STAGING_FL_INV_OUT TO SWMS_USER;

CREATE INDEX SWMS.LXLI_STAGING_FL_INV_OUT_NK1 ON SWMS.LXLI_STAGING_FL_INV_OUT (SEQUENCE_NUMBER,HDR_LINE_NUMBER)
TABLESPACE SWMS_ITS1
STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
PCTFREE 10;

GRANT SELECT ON SWMS.LXLI_STAGING_FL_INV_OUT TO SWMS_VIEWER;

--LXLI_GOALTIME_IN

CREATE TABLE SWMS.LXLI_GOALTIME_IN
(
   BATCH_NO        VARCHAR2 (13 CHAR),
   GOAL_TIME       NUMBER (8, 2),
   DATA_STRING     VARCHAR2 (2000 CHAR),
   RECORD_STATUS   VARCHAR2 (1 CHAR),
   ERROR_CODE      VARCHAR2 (100 CHAR),
   ERROR_MSG       VARCHAR2 (2000 CHAR),
   ADD_DATE        DATE DEFAULT SYSDATE,
   ADD_USER        VARCHAR2 (30 CHAR) DEFAULT REPLACE (USER, 'OPS$'),
   UPD_DATE        DATE,
   UPD_USER        VARCHAR2 (30 CHAR)
)
SEGMENT CREATION IMMEDIATE PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM LXLI_GOALTIME_IN FOR SWMS.LXLI_GOALTIME_IN;

GRANT DELETE,INSERT,SELECT,UPDATE ON SWMS.LXLI_GOALTIME_IN TO SWMS_USER;

GRANT SELECT ON SWMS.LXLI_GOALTIME_IN TO SWMS_VIEWER;


CREATE TABLE SWMS.INTERFACE_POSITION_LOOKUP
(
INTERFACE_TYPE    VARCHAR2(30 CHAR) NOT NULL,
FUNCTION_TYPE    VARCHAR2(2 CHAR),
HEADER_TYPE    VARCHAR2(1 CHAR),
FIELD_NAME    VARCHAR2(30 CHAR),
FIELD_ORDER    NUMBER(3),
FROM_POSITION    NUMBER(3),
END_POSITION    NUMBER(3),
FIELD_LENGTH    NUMBER(3)
)
SEGMENT CREATION IMMEDIATE PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING STORAGE
(
 INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL
 DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT
)
TABLESPACE "SWMS_DTS2";

CREATE OR REPLACE PUBLIC SYNONYM INTERFACE_POSITION_LOOKUP FOR SWMS.INTERFACE_POSITION_LOOKUP;

GRANT DELETE,INSERT,SELECT,UPDATE ON SWMS.INTERFACE_POSITION_LOOKUP TO SWMS_USER;

GRANT SELECT ON SWMS.INTERFACE_POSITION_LOOKUP TO SWMS_VIEWER;
