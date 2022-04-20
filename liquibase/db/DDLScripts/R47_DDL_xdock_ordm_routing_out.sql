/****************************************************************************

  File:
    xdock_ordm_routing_out.sql

  Desc:
    Create the XDOCK_ORDM_ROUTING_OUT table as a staging table to send ORDM data from
    one site to another.

    Note: Original intention to send from site 2 to site 1.

****************************************************************************/

DECLARE
	v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_ORDM_ROUTING_OUT'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    -- Data from ORDM
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_ORDM_ROUTING_OUT (
        sequence_number       NUMBER               NOT NULL ENABLE, -- Sequence: XDOCK_SEQNO_SEQ
        batch_id              VARCHAR2(14 CHAR)    NOT NULL ENABLE, -- Generated from: pl_xdock_common.get_batch_id
        order_id              VARCHAR2(14 CHAR)    NOT NULL ENABLE,
        route_no              VARCHAR2(10 CHAR)    NOT NULL ENABLE,
        truck_no              VARCHAR2(10 CHAR)    NOT NULL ENABLE,
        stop_no               NUMBER(7,2)          NOT NULL ENABLE,
        record_status         VARCHAR2(1 CHAR)     NOT NULL ENABLE,
        cross_dock_type       VARCHAR2(2 CHAR)     NOT NULL ENABLE,
        delivery_document_id  VARCHAR2(30 CHAR)    NOT NULL ENABLE,
        site_id               VARCHAR2(5 CHAR)     NOT NULL ENABLE,
        site_from             VARCHAR2(5 CHAR)     NOT NULL ENABLE,
        site_to               VARCHAR2(5 CHAR)     NOT NULL ENABLE,
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

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_ORDM_ROUTING_OUT IS ''XDOCK_ORDM_ROUTING_OUT staging table for cross dock site 2'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_ORDM_ROUTING_OUT_PK ON SWMS.XDOCK_ORDM_ROUTING_OUT
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

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDM_ROUTING_OUT_IDX1
      ON SWMS.XDOCK_ORDM_ROUTING_OUT(batch_id)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';


    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDM_ROUTING_OUT_IDX2
      ON SWMS.XDOCK_ORDM_ROUTING_OUT(record_status)
      TABLESPACE SWMS_ITS2
      PCTFREE 10
      STORAGE (
        INITIAL 64K
        NEXT 1M
        MINEXTENTS 1
        MAXEXTENTS UNLIMITED
        PCTINCREASE 0
      )';


    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_ORDM_ROUTING_OUT FOR SWMS.XDOCK_ORDM_ROUTING_OUT';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_ORDM_ROUTING_OUT ADD (
        CONSTRAINT XDOCK_ORDM_ROUTING_OUT_PK
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

    EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_ORDM_ROUTING_OUT TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_ORDM_ROUTING_OUT TO SWMS_VIEWER';
  END IF;
END;
/
