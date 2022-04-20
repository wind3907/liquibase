create or replace TRIGGER SWMS.TRG_INS_SAP_CS_IN_BROW
BEFORE INSERT ON SAP_CS_IN REFERENCING NEW AS NEW OLD AS OLD
    FOR EACH ROW
DECLARE
     l_host_type_flag VARCHAR2(6)  := 'AS400';    -- SMOD-1120: To Verify OpCo Type (SAP/NON-SAP)
     l_host_comm_flag VARCHAR2(15)  := 'APCOM';   -- SMOD-2173: Guard against OpCo not using STAGING TABLES
     invalid_catch_wt_trk EXCEPTION;              -- SMOD-2173: Add missed CATCH_WT_TRK verification
     record_not_found EXCEPTION;
BEGIN

    -- SMOD-1120: To Verify OpCo Type (SAP/NON-SAP)
    l_host_type_flag := pl_common.f_get_syspar('HOST_TYPE', 'x');
    l_host_comm_flag := pl_common.f_get_syspar('HOST_COMM', 'x');

    IF ( l_host_type_flag = 'SAP' ) THEN
        UPDATE PM SET ITEM_COST=:NEW.ITEM_COST WHERE PROD_ID=:NEW.PROD_ID;
    ELSIF ( l_host_comm_flag = 'STAGING TABLES' ) THEN
        IF ( :NEW.CATCH_WT_TRK = 'Y' OR :NEW.CATCH_WT_TRK = 'N' ) THEN
            UPDATE PM SET
                ITEM_COST=:NEW.ITEM_COST,
                LAST_SHP_DATE=TO_DATE(NVL(:NEW.LAST_SHIP_DATE,TO_CHAR(SYSDATE,'YYYYMMDD')),'YYYYMMDD'),
                AVG_WT=:NEW.AVG_WEIGHT/SPC
            WHERE PROD_ID = :NEW.PROD_ID
               AND CUST_PREF_VENDOR = :NEW.CUST_PREF_VENDOR;
        ELSE
            :NEW.RECORD_STATUS := 'F';
            RAISE invalid_catch_wt_trk;
        END IF;
    END IF;

    IF SQL%ROWCOUNT = 0 THEN
        :NEW.RECORD_STATUS := 'F';
        RAISE record_not_found;
    ELSE
        :NEW.RECORD_STATUS := 'S';
    END IF;

    EXCEPTION
        WHEN invalid_catch_wt_trk THEN
            pl_log.ins_msg('FATAL', 'TRG_INS_SAP_CS_IN_BROW',
            'Invalid catch_wt_trk for PROD_ID:' ||:NEW.PROD_ID,SQLCODE, SQLERRM, 'MAINTENANCE', 'TRG_INS_SAP_CS_IN_BROW','N');
        WHEN record_not_found THEN
            pl_log.ins_msg('WARN', 'TRG_INS_SAP_CS_IN_BROW',
            'ITEM NOT FOUND IN PM TABLE: PROD_ID:' ||:NEW.PROD_ID,SQLCODE, SQLERRM, 'MAINTENANCE', 'TRG_INS_SAP_CS_IN_BROW','N');
        WHEN OTHERS THEN
            pl_log.ins_msg('FATAL', 'TRG_INS_SAP_CS_IN_BROW',
            'ERROR UPDATING COST INTO PM TABLE' ||:NEW.PROD_ID,SQLCODE, SQLERRM, 'MAINTENANCE', 'TRG_INS_SAP_CS_IN_BROW','Y');
            RAISE_APPLICATION_ERROR(-20001,	'TRG_INS_SAP_CS_IN_BROW' || ': '|| SQLERRM);

END;
/

