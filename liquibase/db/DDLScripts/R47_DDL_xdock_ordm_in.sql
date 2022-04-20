/****************************************************************************
  File:
    R47_DDL_xdock_ordm_in.sql

  Desc:
    Create the XDOCK_ORDM_IN table as a staging table to recieve ORDM data from
    site 1(Fulfillment) xdock_ordm_out to site 2(Last mile) xdock_ordm_in.

****************************************************************************/

DECLARE
	v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(1)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_ORDM_IN'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_ORDM_IN (
      sequence_number       NUMBER               NOT NULL ENABLE,
      batch_id              VARCHAR2(14 CHAR)    NOT NULL ENABLE,
      order_id              VARCHAR2(14 CHAR)    NOT NULL ENABLE,
      route_no              VARCHAR2(10 CHAR)    NOT NULL ENABLE,
      stop_no               NUMBER(7,2)          NOT NULL ENABLE,
      record_status         VARCHAR2(1 CHAR)     NOT NULL ENABLE,
      truck_no              VARCHAR2(10 CHAR),
      trailer_no            VARCHAR2(10 CHAR),
      priority              NUMBER(3,0),
      truck_type            VARCHAR2(3 CHAR),
      ship_date             DATE,
      status                VARCHAR2(3 CHAR)     NOT NULL ENABLE,
      cust_id               VARCHAR2(10 CHAR)    NOT NULL ENABLE,
      carr_id               VARCHAR2(10 CHAR),
      wave_number           VARCHAR2(5 CHAR),
      order_type            VARCHAR2(3 CHAR),
      unitize_ind           VARCHAR2(1 CHAR),
      cust_po               VARCHAR2(15 CHAR),
      cust_name             VARCHAR2(30 CHAR),
      cust_contact          VARCHAR2(30 CHAR),
      cust_addr1            VARCHAR2(40 CHAR),
      cust_addr2            VARCHAR2(40 CHAR),
      cust_addr3            VARCHAR2(40 CHAR),
      cust_city             VARCHAR2(20 CHAR),
      cust_state            VARCHAR2(2 CHAR),
      cust_zip              VARCHAR2(10 CHAR),
      cust_cntry            VARCHAR2(10 CHAR),
      ship_id               VARCHAR2(30 CHAR),
      ship_name             VARCHAR2(30 CHAR),
      ship_addr1            VARCHAR2(80 CHAR),
      ship_addr2            VARCHAR2(40 CHAR),
      ship_addr3            VARCHAR2(160 CHAR),
      ship_city             VARCHAR2(20 CHAR),
      ship_state            VARCHAR2(2 CHAR),
      ship_zip              VARCHAR2(10 CHAR),
      ship_cntry            VARCHAR2(10 CHAR),
      sales                 VARCHAR2(2 CHAR),
      grpm_id               VARCHAR2(30 CHAR),
      grpm_seq              NUMBER(7,0),
      del_time              DATE,
      d_pieces              NUMBER(9,0),
      c_pieces              NUMBER(9,0),
      f_pieces              NUMBER(9,0),
      weight                NUMBER(9,3),
      sys_order_id          NUMBER(10,0),
      sys_order_line_id     NUMBER(5,0),
      immediate_ind         VARCHAR2(1 CHAR),
      delivery_method       VARCHAR2(1 CHAR),
      deleted               VARCHAR2(3 CHAR),
      frz_special           VARCHAR2(1 CHAR),
      clr_special           VARCHAR2(1 CHAR),
      dry_special           VARCHAR2(1 CHAR),
      old_stop_no           NUMBER(7,2),
      cross_dock_type       VARCHAR2(2 CHAR),
      dod_contract_no       VARCHAR2(13 CHAR),
      delivery_document_id  VARCHAR2(30 CHAR),
      site_id               VARCHAR2(5 CHAR),
      site_from             VARCHAR2(5 CHAR),
      site_to               VARCHAR2(5 CHAR),
      site_to_route_no      VARCHAR2(10 CHAR),
      site_to_stop_no       NUMBER(7,2),
      site_to_truck_no      VARCHAR2(10 CHAR),
      site_to_door_no       VARCHAR2(10 CHAR),
      add_date              DATE DEFAULT SYSDATE NOT NULL ENABLE,
      add_user              VARCHAR2(30 CHAR)    NOT NULL ENABLE,
      upd_date              DATE,                -- Populated by database trigger on the table
      upd_user              VARCHAR2(30 CHAR),   -- Populated by database trigger on the table
      error_code            VARCHAR2(100 CHAR),
      error_msg             VARCHAR2(500 CHAR)
    )
    TABLESPACE SWMS_DTS2';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_ORDM_IN IS ''XDOCK_ORDM_IN staging table to receive ORDM table information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_ORDM_IN_PK
      ON SWMS.XDOCK_ORDM_IN(SEQUENCE_NUMBER)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDM_IN_IDX1
      ON SWMS.XDOCK_ORDM_IN(batch_id)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDM_IN_IDX2
      ON SWMS.XDOCK_ORDM_IN(record_status)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_ORDM_IN FOR SWMS.XDOCK_ORDM_IN';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_ORDM_IN ADD (
      CONSTRAINT XDOCK_ORDM_IN_PK
      PRIMARY KEY (SEQUENCE_NUMBER)
      USING INDEX TABLESPACE SWMS_ITS2
    )';

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_ORDM_IN TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_ORDM_IN TO SWMS_VIEWER';
  END IF;
END;
/
