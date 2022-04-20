/****************************************************************************

  File:
    R52_DDL_ixdock_manifests_in.sql

  Desc:
    Create the IXDOCK_MANIFESTS_IN table as a staging table to send Manifests data
    from site 1(Fulfillment) to site 2(Last mile).

****************************************************************************/

DECLARE
    v_table_exists NUMBER := 0;
BEGIN

    SELECT COUNT(*)
    INTO v_table_exists
    FROM all_tables
    WHERE table_name = 'IXDOCK_MANIFESTS_IN'
      AND owner = 'SWMS';

    IF(v_table_exists = 0) THEN

        EXECUTE IMMEDIATE '
        CREATE TABLE SWMS.IXDOCK_MANIFESTS_IN (
            sequence_number         NUMBER               NOT NULL ENABLE,
            batch_id                VARCHAR2(14 CHAR)    NOT NULL ENABLE,
            manifest_no             NUMBER(7)            NOT NULL,
            manifest_create_dt      DATE                 NOT NULL,
            manifest_status         VARCHAR2(3 CHAR)     NOT NULL,
            record_status           VARCHAR2(1 CHAR)     NOT NULL ENABLE,
            route_no                VARCHAR2(10 CHAR),
            truck_no                VARCHAR2(10 CHAR),
            sts_completed_ind       VARCHAR2(1 CHAR),
            add_date                DATE DEFAULT SYSDATE NOT NULL ENABLE,
            add_user                VARCHAR2(30 CHAR)    NOT NULL ENABLE,
            upd_date                DATE,                -- Populated by database trigger on the table
            upd_user                VARCHAR2(30 CHAR),   -- Populated by database trigger on the table
            error_code              VARCHAR2(100 CHAR),
            error_msg               VARCHAR2(500 CHAR)
        ) ';

        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.IXDOCK_MANIFESTS_IN
            ADD CONSTRAINT IXDOCK_MANIFESTS_IN_PK PRIMARY KEY (batch_id,sequence_number)';

        EXECUTE IMMEDIATE 'CREATE INDEX SWMS.IXDOCK_MANIFESTS_IN_IDX2
            ON SWMS.IXDOCK_MANIFESTS_IN (record_status)';

        EXECUTE IMMEDIATE 'CREATE
        OR REPLACE PUBLIC SYNONYM IXDOCK_MANIFESTS_IN FOR SWMS.IXDOCK_MANIFESTS_IN';

        EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.IXDOCK_MANIFESTS_IN TO SWMS_USER';

        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.IXDOCK_MANIFESTS_IN TO SWMS_VIEWER';
    END IF;
END;
/
