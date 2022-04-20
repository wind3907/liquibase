/****************************************************************************

  File:
    xdock_floats_out.sql

  Desc:
    Create the XDOCK_FLOATS_OUT table as a staging table to send FLOAT data
    from site 1(Fulfillment) to site 2(Last mile).

****************************************************************************/

DECLARE
  v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_FLOATS_OUT'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    -- Data from FLOAT table
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_FLOATS_OUT (
        sequence_number           NUMBER               NOT NULL ENABLE, -- Sequence: XDOCK_SEQNO_SEQ
        batch_id                  VARCHAR2(14 CHAR)    NOT NULL ENABLE, -- Generated from: pl_xdock_common.get_batch_id
        batch_no                  NUMBER(9,0),
        batch_seq                 NUMBER(2,0),
        float_no                  NUMBER(9,0)          NOT NULL ENABLE,
        float_seq                 VARCHAR2(4 CHAR),
        route_no                  VARCHAR2(10 CHAR),
        b_stop_no                 NUMBER(7,2),
        e_stop_no                 NUMBER(7,2),
        record_status             VARCHAR2(1 CHAR)     NOT NULL ENABLE,
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

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_FLOATS_OUT IS ''XDOCK_FLOATS_OUT staging table to send float table information from site 1 to site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_FLOATS_OUT_PK ON SWMS.XDOCK_FLOATS_OUT
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

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_FLOATS_OUT_IDX1
      ON SWMS.XDOCK_FLOATS_OUT(batch_id)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_FLOATS_OUT_IDX2
      ON SWMS.XDOCK_FLOATS_OUT(record_status)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_FLOATS_OUT FOR SWMS.XDOCK_FLOATS_OUT';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_FLOATS_OUT ADD (
        CONSTRAINT XDOCK_FLOATS_OUT_PK
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

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_FLOATS_OUT TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_FLOATS_OUT TO SWMS_VIEWER';
  END IF;
END;
/
