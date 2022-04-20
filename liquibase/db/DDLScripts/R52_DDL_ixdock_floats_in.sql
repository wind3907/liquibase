/****************************************************************************

  File:
    R52_DDL_ixdock_floats_in.sql

  Desc:
    Create the IXDOCK_FLOATS_IN table as a staging table to send FLOAT data
    from site 1(Fulfillment) ixdock_floats_out to site 2(Last mile) ixdock_floats_in.

****************************************************************************/

DECLARE
  v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(1)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'IXDOCK_FLOATS_IN'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.IXDOCK_FLOATS_IN (
      sequence_number           NUMBER               NOT NULL ENABLE,
      batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE,
      batch_no                  NUMBER(9,0),
      batch_seq                 NUMBER(2,0),
      float_no                  NUMBER(9,0)          NOT NULL ENABLE,
      float_seq                 VARCHAR2(4 CHAR),
      route_no                  VARCHAR2(10 CHAR),
      b_stop_no                 NUMBER(7,2),
      e_stop_no                 NUMBER(7,2),
      record_status             VARCHAR2(1 CHAR)     NOT NULL ENABLE,
      rack_id                   VARCHAR2(10 CHAR),
      float_cube                NUMBER(12,4),
      group_no                  NUMBER(3,0),
      merge_group_no            NUMBER(3,0),
      merge_seq_no              NUMBER(3,0),
      merge_loc                 VARCHAR2(10 CHAR),
      zone_id                   VARCHAR2(5 CHAR),
      equip_id                  VARCHAR2(10 CHAR),
      comp_code                 VARCHAR2(1 CHAR),
      split_ind                 VARCHAR2(1 CHAR),
      pallet_pull               VARCHAR2(1 CHAR),
      pallet_id                 VARCHAR2(18 CHAR),
      home_slot                 VARCHAR2(10 CHAR),
      drop_qty                  NUMBER(9,0),
      door_area                 VARCHAR2(1 CHAR),
      single_stop_flag          VARCHAR2(1 CHAR),
      status                    VARCHAR2(3 CHAR),
      ship_date                 DATE,
      parent_pallet_id          VARCHAR2(18 CHAR),
      fl_method_id              VARCHAR2(10 CHAR),
      fl_sel_type               VARCHAR2(3 CHAR),
      fl_opt_pull               VARCHAR2(1 CHAR),
      truck_no                  VARCHAR2(10 CHAR),
      door_no                   NUMBER(3,0),
      cw_collect_status         CHAR(1 CHAR),
      cw_collect_user           VARCHAR2(30 CHAR),
      fl_no_of_zones            NUMBER(3,0),
      fl_multi_no               NUMBER(3,0),
      fl_sel_lift_job_code      VARCHAR2(6 BYTE),
      mx_priority               NUMBER(2,0),
      is_sleeve_selection       VARCHAR2(1 CHAR),
      add_date                  DATE DEFAULT SYSDATE NOT NULL ENABLE,
      add_user                  VARCHAR2(30 CHAR)    NOT NULL ENABLE,
      upd_date                  DATE,                -- Populated by database trigger on the table
      upd_user                  VARCHAR2(30 CHAR),   -- Populated by database trigger on the table
      error_code                VARCHAR2(100 CHAR),
      error_msg                 VARCHAR2(500 CHAR)
    )
    TABLESPACE SWMS_DTS2';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.IXDOCK_FLOATS_IN IS ''IXDOCK_FLOATS_IN staging table to receive float table information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.IXDOCK_FLOATS_IN_PK
      ON SWMS.IXDOCK_FLOATS_IN (SEQUENCE_NUMBER)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_FLOATS_IN_IDX1
      ON SWMS.IXDOCK_FLOATS_IN(batch_id)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_FLOATS_IN_IDX2
      ON SWMS.IXDOCK_FLOATS_IN(record_status)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM IXDOCK_FLOATS_IN FOR SWMS.IXDOCK_FLOATS_IN';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.IXDOCK_FLOATS_IN ADD (
      CONSTRAINT IXDOCK_FLOATS_IN_PK
      PRIMARY KEY (SEQUENCE_NUMBER)
      USING INDEX TABLESPACE SWMS_ITS2
    )';

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.IXDOCK_FLOATS_IN TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.IXDOCK_FLOATS_IN TO SWMS_VIEWER';
  END IF;
END;
/
