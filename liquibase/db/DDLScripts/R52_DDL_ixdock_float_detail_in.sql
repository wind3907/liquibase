/****************************************************************************

  File:
    R52_DDL_ixdock_float_detail_in.sql

  Desc:
    Create the IXDOCK_FLOAT_DETAIL_IN table as a staging table to receive FLOAT
    data from site 1(Fulfillment) ixdock_float_details_out to site 2(Last mile)
    ixdock_float_details_in.

****************************************************************************/

DECLARE
  v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(1)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'IXDOCK_FLOAT_DETAIL_IN'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.IXDOCK_FLOAT_DETAIL_IN (
      sequence_number           NUMBER               NOT NULL ENABLE,
      batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE,
      float_no                  NUMBER(9,0)          NOT NULL ENABLE,
      seq_no                    NUMBER(3,0)          NOT NULL ENABLE,
      zone                      NUMBER(2,0)          NOT NULL ENABLE,
      stop_no                   NUMBER(7,2)          NOT NULL ENABLE,
      record_status             VARCHAR2(1 CHAR)     NOT NULL ENABLE,
      prod_id                   VARCHAR2(9 CHAR)     NOT NULL ENABLE,
      src_loc                   VARCHAR2(10 CHAR),
      ipo_no                    VARCHAR2(12 CHAR),
      ipo_line_id               NUMBER(3),
      end_cust_id               VARCHAR2(10 CHAR),
      end_cust_name             VARCHAR2(30 CHAR),
      rack_float_zone           VARCHAR2(4 CHAR),
      rack_location             VARCHAR2(10 CHAR),
      pallet_id                 VARCHAR2(18 CHAR),
      parent_pallet_id          VARCHAR2(18 CHAR),
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
    TABLESPACE SWMS_DTS2';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.IXDOCK_FLOAT_DETAIL_IN IS ''IXDOCK_FLOAT_DETAIL_IN staging table to receive float table information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.IXDOCK_FLOAT_DETAIL_IN_PK
      ON SWMS.IXDOCK_FLOAT_DETAIL_IN(SEQUENCE_NUMBER)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_FLOAT_DETAIL_IN_IDX1
      ON SWMS.IXDOCK_FLOAT_DETAIL_IN(batch_id)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_FLOAT_DETAIL_IN_IDX2
      ON SWMS.IXDOCK_FLOAT_DETAIL_IN(record_status)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM IXDOCK_FLOAT_DETAIL_IN FOR SWMS.IXDOCK_FLOAT_DETAIL_IN';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.IXDOCK_FLOAT_DETAIL_IN ADD (
      CONSTRAINT IXDOCK_FLOAT_DETAIL_IN_PK
      PRIMARY KEY (SEQUENCE_NUMBER)
      USING INDEX TABLESPACE SWMS_ITS2
    )';

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.IXDOCK_FLOAT_DETAIL_IN TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.IXDOCK_FLOAT_DETAIL_IN TO SWMS_VIEWER';
  END IF;
END;
/
