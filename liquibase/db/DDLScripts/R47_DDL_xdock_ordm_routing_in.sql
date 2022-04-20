/****************************************************************************

  File:
    R47_DDL_xdock_ordm_routing_in.sql

  Desc:
    Create the XDOCK_ORDM_ROUTING_IN table as a staging table to receive data
    from Site 2's xdock_ordm_routing_out table.

****************************************************************************/

DECLARE
  v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'XDOCK_ORDM_ROUTING_IN'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN
    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.XDOCK_ORDM_ROUTING_IN (
        sequence_number       NUMBER               NOT NULL ENABLE,
        batch_id              VARCHAR2(14 CHAR)    NOT NULL ENABLE,
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
      TABLESPACE SWMS_DTS2';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_ORDM_ROUTING_IN IS ''XDOCK_ORDM_ROUTING_IN staging table for cross dock site 1'' ';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_ORDM_ROUTING_IN_PK
      ON SWMS.XDOCK_ORDM_ROUTING_IN (SEQUENCE_NUMBER)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDM_ROUTING_IN_IDX1
      ON SWMS.XDOCK_ORDM_ROUTING_IN(batch_id)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_ORDM_ROUTING_IN_IDX2
      ON SWMS.XDOCK_ORDM_ROUTING_IN(record_status)
      TABLESPACE SWMS_ITS2';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_ORDM_ROUTING_IN FOR SWMS.XDOCK_ORDM_ROUTING_IN';

    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_ORDM_ROUTING_IN ADD (
      CONSTRAINT XDOCK_ORDM_ROUTING_IN_PK
      PRIMARY KEY (SEQUENCE_NUMBER)
      USING INDEX TABLESPACE SWMS_ITS2
    )';

    EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_ORDM_ROUTING_IN TO SWMS_USER';

    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_ORDM_ROUTING_IN TO SWMS_VIEWER';
  END IF;
END;
/
