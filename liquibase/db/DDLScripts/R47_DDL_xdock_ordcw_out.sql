/****************************************************************************

  File:
    R47_DDL_xdock_ordcw_out.sql

  Desc:
    Create the XDOCK_ORDCW_OUT table as a staging table to send ORDCW data
    from site 1(Fulfillment) to site 2(Last mile).

****************************************************************************/

DECLARE
	v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_ORDCW_OUT'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    -- Data from ORDCW table
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_ORDCW_OUT (
        sequence_number           NUMBER               NOT NULL ENABLE, -- Sequence: XDOCK_SEQNO_SEQ
        batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE, -- Generated from: pl_xdock_common.get_batch_id
        record_status             VARCHAR2(1 CHAR)     NOT NULL ENABLE,
        route_no                  VARCHAR2(10 CHAR)    NOT NULL ENABLE,
        order_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE,
        order_line_id             NUMBER(3,0)          NOT NULL ENABLE,
        seq_no                    NUMBER(4,0),
        prod_id                   VARCHAR2(9 CHAR),
        cust_pref_vendor          VARCHAR2(10 CHAR),
        catch_weight              NUMBER(9,3),
        cw_type                   VARCHAR2(1 CHAR),
        uom                       NUMBER(1,0),
        cw_float_no               NUMBER(7,0),
        cw_scan_method            CHAR(1 CHAR),
        order_seq                 NUMBER(8,0),
        case_id                   NUMBER(13,0),
        cw_kg_lb                  NUMBER(9,3),
        pkg_short_used            CHAR(1 CHAR),
        add_date                  DATE DEFAULT SYSDATE NOT NULL ENABLE,
        add_user                  VARCHAR2(30 CHAR)    NOT NULL ENABLE,
        upd_date                  DATE,                -- Populated by database trigger on the table
        upd_user                  VARCHAR2(30 CHAR),   -- Populated by database trigger on the table
        error_code                VARCHAR2(100 CHAR),
        error_msg                 VARCHAR2(500 CHAR)
      )
      TABLESPACE SWMS_DTS2
      RESULT_CACHE (MODE DEFAULT)
      PCTUSED    0
      PCTFREE    10
      INITRANS   1
      MAXTRANS   255
      STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
            FLASH_CACHE      DEFAULT
            CELL_FLASH_CACHE DEFAULT
          )
      LOGGING
      NOCOMPRESS
      NOCACHE
      NOPARALLEL
      MONITORING';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_ORDCW_OUT IS ''XDOCK_ORDCW_OUT staging table to send ORDCW table information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_ORDCW_OUT_PK ON SWMS.XDOCK_ORDCW_OUT
      (SEQUENCE_NUMBER)
      LOGGING
      TABLESPACE SWMS_ITS2
      PCTFREE    10
      INITRANS   2
      MAXTRANS   255
      STORAGE    (
        INITIAL          64K
        NEXT             1M
        MINEXTENTS       1
        MAXEXTENTS       UNLIMITED
        PCTINCREASE      0
        BUFFER_POOL      DEFAULT
        FLASH_CACHE      DEFAULT
        CELL_FLASH_CACHE DEFAULT
      )
      NOPARALLEL';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDCW_OUT_IDX1
      ON SWMS.XDOCK_ORDCW_OUT(batch_id)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDCW_OUT_IDX2
      ON SWMS.XDOCK_ORDCW_OUT(record_status)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_ORDCW_OUT FOR SWMS.XDOCK_ORDCW_OUT';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_ORDCW_OUT ADD (
        CONSTRAINT XDOCK_ORDCW_OUT_PK
        PRIMARY KEY
        (SEQUENCE_NUMBER)
        USING INDEX TABLESPACE SWMS_ITS2
        STORAGE (
          INITIAL 64K
          NEXT 1M
          MINEXTENTS 1
          MAXEXTENTS UNLIMITED
          PCTINCREASE 0
        )
        ENABLE VALIDATE
      )';

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_ORDCW_OUT TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_ORDCW_OUT TO SWMS_VIEWER';
  END IF;
END;
/
