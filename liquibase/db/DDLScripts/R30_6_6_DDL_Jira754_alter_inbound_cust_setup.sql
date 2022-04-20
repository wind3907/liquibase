DECLARE
    l_col_count NUMBER := 0;
    l_count NUMBER := 0;
BEGIN

    SELECT count(*)
    INTO l_col_count
    FROM user_tab_cols
    WHERE table_name = 'INBOUND_CUST_SETUP'
    AND column_name = 'CUST_NAME';

    IF l_col_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE INBOUND_CUST_SETUP ADD CUST_NAME VARCHAR2(30)';
    END IF;

    SELECT count(*)
    INTO l_col_count
    FROM user_tab_cols
    WHERE table_name = 'INBOUND_CUST_SETUP'
    AND column_name = 'STAGING_LOC'
    AND nullable = 'N';

    IF l_col_count > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE INBOUND_CUST_SETUP MODIFY (STAGING_LOC NULL)';
    END IF;

    SELECT count(*)
    INTO l_col_count
    FROM user_tab_cols 
    WHERE table_name = 'INBOUND_CUST_SETUP' 
    AND column_name = 'RACK_CUT_LOC';

    IF l_col_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE INBOUND_CUST_SETUP ADD RACK_CUT_LOC VARCHAR2(10)';
    END IF;

    SELECT count(*)
    INTO l_col_count
    FROM user_tab_cols 
    WHERE table_name = 'INBOUND_CUST_SETUP' 
    AND column_name = 'WILLCALL_LOC';

    IF l_col_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE INBOUND_CUST_SETUP ADD WILLCALL_LOC VARCHAR2(10)';
    END IF;

    SELECT count(*)
    INTO l_count
    FROM all_constraints
    WHERE owner = 'SWMS'
    AND constraint_name = 'STAGING_LOC_UNIQUE';

    IF l_count = 1 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE INBOUND_CUST_SETUP DROP CONSTRAINT STAGING_LOC_UNIQUE';
    END IF;

END;
/