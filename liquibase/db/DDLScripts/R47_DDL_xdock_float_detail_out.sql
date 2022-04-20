/****************************************************************************

  File:
    R47_DDL_xdock_float_deatil_out.sql

  Desc:
    Create the XDOCK_FLOAT_DETAIL_OUT table as a staging table to send FLOAT data
    from site 1(Fulfillment) to site 2(Last mile).

****************************************************************************/

DECLARE
  v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_FLOAT_DETAIL_OUT'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    -- Data from FLOAT table
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_FLOAT_DETAIL_OUT (
        sequence_number           NUMBER               NOT NULL ENABLE, -- Sequence: XDOCK_SEQNO_SEQ
        batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE, -- Generated from: pl_xdock_common.get_batch_id
        float_no                  NUMBER(9,0)          NOT NULL ENABLE,
        seq_no                    NUMBER(3,0)          NOT NULL ENABLE,
        zone                      NUMBER(2,0)          NOT NULL ENABLE,
        stop_no                   NUMBER(7,2)          NOT NULL ENABLE,
        record_status             VARCHAR2(1 CHAR)     NOT NULL ENABLE,
        prod_id                   VARCHAR2(9 CHAR)     NOT NULL ENABLE,
        src_loc                   VARCHAR2(10 CHAR),
        multi_home_seq            NUMBER(5,0),
        uom                       NUMBER(2,0),
        qty_order                 NUMBER(9,0),
        qty_alloc                 NUMBER(9,0),
        merge_alloc_flag          VARCHAR2(1 CHAR),
        merge_loc                 VARCHAR2(10 CHAR),
        status                    VARCHAR2(3 CHAR)     NOT NULL ENABLE,
        order_id                  VARCHAR2(14 CHAR),
        order_line_id             NUMBER(3,0),
        cube                      NUMBER(12,4),
        copy_no                   NUMBER(3,0),
        merge_float_no            NUMBER(9,0),
        merge_seq_no              NUMBER(3,0),
        cust_pref_vendor          VARCHAR2(10 CHAR)    NOT NULL ENABLE,
        clam_bed_trk              VARCHAR2(1 CHAR),
        route_no                  VARCHAR2(10 CHAR),
        route_batch_no            NUMBER,
        alloc_time                DATE,
        rec_id                    VARCHAR2(12 CHAR),
        mfg_date                  DATE,
        exp_date                  DATE,
        lot_id                    VARCHAR2(30 CHAR),
        carrier_id                VARCHAR2(18 CHAR),
        order_seq                 NUMBER(8,0),
        sos_status                VARCHAR2(1 CHAR),
        cool_trk                  VARCHAR2(1 CHAR),
        catch_wt_trk              VARCHAR2(1 CHAR),
        item_seq                  NUMBER(3,0),
        qty_short                 NUMBER(3,0) DEFAULT 0,
        st_piece_seq              NUMBER(3,0),
        selector_id               VARCHAR2(10 CHAR),
        bc_st_piece_seq           NUMBER(3,0),
        short_item_seq            NUMBER(4,0),
        sleeve_id                 VARCHAR2(11 CHAR),
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

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_FLOAT_DETAIL_OUT IS ''XDOCK_FLOAT_DETAIL_OUT staging table to send float table information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_FLOAT_DETAIL_OUT_PK ON SWMS.XDOCK_FLOAT_DETAIL_OUT
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

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_FLOAT_DETAIL_OUT_IDX1
      ON SWMS.XDOCK_FLOAT_DETAIL_OUT(batch_id)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_FLOAT_DETAIL_OUT_IDX2
      ON SWMS.XDOCK_FLOAT_DETAIL_OUT(record_status)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_FLOAT_DETAIL_OUT FOR SWMS.XDOCK_FLOAT_DETAIL_OUT';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_FLOAT_DETAIL_OUT ADD (
        CONSTRAINT XDOCK_FLOAT_DETAIL_OUT_PK
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

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_FLOAT_DETAIL_OUT TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_FLOAT_DETAIL_OUT TO SWMS_VIEWER';
  END IF;
END;
/
