/****************************************************************************
  File:
    R52_DDL_ixdock_ordd_out.sql

  Desc:
    Create the IXDOCK_ORDD_OUT table as a staging table to send ORDD data from
    site 1(Fulfillment) to site 2(Last mile).

    Note: Original intention to send from site 2 to site 1.

****************************************************************************/

DECLARE
	v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'IXDOCK_ORDD_OUT'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    -- Data from ORDD
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.IXDOCK_ORDD_OUT (
        sequence_number           NUMBER               NOT NULL ENABLE,
        batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE,
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
        ipo_no                    VARCHAR2(12 CHAR),
        ipo_line_id               NUMBER(3),
        end_cust_id               VARCHAR2(10 CHAR),
        end_cust_name             VARCHAR2(30 CHAR),
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
      TABLESPACE SWMS_DTS2';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.IXDOCK_ORDD_OUT IS ''IXDOCK_ORDD_OUT staging table to send ordd information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.IXDOCK_ORDD_OUT_PK ON SWMS.IXDOCK_ORDD_OUT
      (SEQUENCE_NUMBER)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_ORDD_OUT_IDX1
      ON SWMS.IXDOCK_ORDD_OUT(batch_id)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_ORDD_OUT_IDX2
      ON SWMS.IXDOCK_ORDD_OUT(record_status)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM IXDOCK_ORDD_OUT FOR SWMS.IXDOCK_ORDD_OUT';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.IXDOCK_ORDD_OUT ADD (
        CONSTRAINT IXDOCK_ORDD_OUT_PK
        PRIMARY KEY (SEQUENCE_NUMBER)
        USING INDEX TABLESPACE SWMS_ITS2
      )';

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.IXDOCK_ORDD_OUT TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.IXDOCK_ORDD_OUT TO SWMS_VIEWER';
  END IF;
END;
/
