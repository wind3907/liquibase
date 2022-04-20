/****************************************************************************

  File:
    xdock_manifest_dtls_in.sql

  Desc:
    Create the XDOCK_MANIFEST_DTLS_IN table as a staging table to send Manifest Details data
    from site 1(Fulfillment) to site 2(Last mile).

****************************************************************************/

DECLARE
    v_table_exists NUMBER := 0;
BEGIN

    SELECT COUNT(*)
    INTO v_table_exists
    FROM all_tables
    WHERE table_name = 'XDOCK_MANIFEST_DTLS_IN'
      AND owner = 'SWMS';

    IF(v_table_exists = 0) THEN

        EXECUTE IMMEDIATE '
        CREATE TABLE SWMS.XDOCK_MANIFEST_DTLS_IN
        (
            batch_id                VARCHAR2(14 CHAR) NOT NULL,
            sequence_no             NUMBER NOT NULL,
            record_status           VARCHAR2(1 CHAR),
            site_id                 VARCHAR2(6 CHAR),
            site_from               VARCHAR2(6 CHAR),
            site_to                 VARCHAR2(6 CHAR),
            delivery_document_id    VARCHAR2(30 CHAR),
            manifest_no             NUMBER(7,0),
            stop_no                 VARCHAR2(7 CHAR),
            rec_type                VARCHAR2(1 CHAR),
            obligation_no           VARCHAR2(14 CHAR),
            prod_id                 VARCHAR2(9 CHAR),
            cust_pref_vendor        VARCHAR2(10 CHAR),
            shipped_qty             NUMBER(4,0),
            shipped_split_cd        VARCHAR2(1 CHAR),
            manifest_dtl_status     VARCHAR2(3 CHAR),
            orig_invoice            VARCHAR2(16 CHAR),
            invoice_no              VARCHAR2(14 CHAR),
            pod_flag                VARCHAR2(1 CHAR),
            return_reason_cd        VARCHAR2(3 CHAR),
            disposition             VARCHAR2(3 CHAR),
            erm_line_id             NUMBER(4,0),
            route_no                VARCHAR2(10 CHAR),
            add_date                DATE,
            add_user                VARCHAR2(30 CHAR),
            add_source              VARCHAR2(3 CHAR),
            upd_date                DATE,
            upd_user                VARCHAR2(30 CHAR),
            upd_source              VARCHAR2(3 CHAR),
            err_comment             VARCHAR2(10 CHAR)
        ) ';

        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_MANIFEST_DTLS_IN
            ADD CONSTRAINT XDOCK_MANIFEST_DTLS_IN_PK PRIMARY KEY (batch_id,sequence_no)';

        EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_MANIFEST_DTLS_IN_IDX2
            ON SWMS.XDOCK_MANIFEST_DTLS_IN (record_status)';

        EXECUTE IMMEDIATE 'CREATE
        OR REPLACE PUBLIC SYNONYM XDOCK_MANIFEST_DTLS_IN FOR SWMS.XDOCK_MANIFEST_DTLS_IN';

        EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_MANIFEST_DTLS_IN TO SWMS_USER';

        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_MANIFEST_DTLS_IN TO SWMS_VIEWER';
    END IF;
END;
/
