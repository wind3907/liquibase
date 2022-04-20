/****************************************************************************
  File:
    xdock_ordd_out.sql

  Desc:
    Create the XDOCK_ORDD_OUT table as a staging table to send ORDD data from
    site 1(Fulfillment) to site 2(Last mile).

    Note: Original intention to send from site 2 to site 1.

****************************************************************************/

DECLARE
	v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_ORDD_OUT'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    -- Data from ORDD
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_ORDD_OUT (
        sequence_number           NUMBER               NOT NULL ENABLE, -- Sequence: XDOCK_SEQNO_SEQ
        batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE, -- Generated from: pl_xdock_common.get_batch_id
        order_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE,
        order_line_id             NUMBER(3,0)          NOT NULL ENABLE,
        prod_id                   VARCHAR2(9 CHAR)     NOT NULL ENABLE,
        cust_pref_vendor          VARCHAR2(10 CHAR)    NOT NULL ENABLE,
        lot_id                    VARCHAR2(30 CHAR),
        status                    VARCHAR2(3 CHAR),
        record_status             VARCHAR2(1 CHAR)     NOT NULL ENABLE,
        qty_ordered               NUMBER(7,0)          NOT NULL ENABLE,
        qty_shipped               NUMBER(7,0),
        uom                       NUMBER(2,0),
        weight                    NUMBER(9,2),
        partial                   VARCHAR2(1 CHAR),
        page                      VARCHAR2(4 CHAR),
        inck_key                  VARCHAR2(5 CHAR),
        seq                       NUMBER(8,0),
        area                      VARCHAR2(1 CHAR),
        route_no                  VARCHAR2(10 CHAR),
        stop_no                   NUMBER(7,2),
        qty_alloc                 NUMBER(7,0),
        zone_id                   VARCHAR2(5 CHAR),
        pallet_pull               VARCHAR2(1 CHAR),
        sys_order_id              NUMBER(10,0),
        sys_order_line_id         NUMBER(5,0),
        wh_out_qty                NUMBER(7,0),
        reason_cd                 VARCHAR2(3 CHAR),
        pk_adj_type               VARCHAR2(3 CHAR),
        pk_adj_dt                 DATE,
        user_id                   VARCHAR2(30 CHAR),
        cw_type                   VARCHAR2(1 CHAR),
        qa_ticket_ind             VARCHAR2(1 CHAR),
        deleted                   VARCHAR2(3 CHAR),
        pcl_flag                  VARCHAR2(1 CHAR),
        pcl_id                    VARCHAR2(14 CHAR),
        original_uom              NUMBER(2,0),
        dod_cust_item_barcode     VARCHAR2(13 CHAR),
        dod_fic                   VARCHAR2(3 CHAR),
        product_out_qty           NUMBER,
        master_order_id           VARCHAR2(25 CHAR),
        remote_local_flg          VARCHAR2(1 CHAR),
        remote_qty                NUMBER(7,0),
        rdc_po_no                 VARCHAR2(16 CHAR),
        qty_ordered_original      NUMBER(7,0),
        original_order_line_id    NUMBER(3,0),
        original_seq              NUMBER(8,0),
        delivery_document_id      VARCHAR2(30 CHAR),
        add_date                  DATE DEFAULT SYSDATE NOT NULL ENABLE,
        add_user                  VARCHAR2(30 CHAR)    NOT NULL ENABLE,
        upd_date                  DATE,              -- Populated by database trigger on the table
        upd_user                  VARCHAR2(30 CHAR), -- Populated by database trigger on the table
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

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_ORDD_OUT IS ''XDOCK_ORDD_OUT staging table to send ordd information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_ORDD_OUT_PK ON SWMS.XDOCK_ORDD_OUT
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

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDD_OUT_IDX1
      ON SWMS.XDOCK_ORDD_OUT(batch_id)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDD_OUT_IDX2
      ON SWMS.XDOCK_ORDD_OUT(record_status)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_ORDD_OUT FOR SWMS.XDOCK_ORDD_OUT';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_ORDD_OUT ADD (
        CONSTRAINT XDOCK_ORDD_OUT_PK
        PRIMARY KEY (SEQUENCE_NUMBER)
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

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_ORDD_OUT TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_ORDD_OUT TO SWMS_VIEWER';
  END IF;
END;
/
