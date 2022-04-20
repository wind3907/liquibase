DECLARE
    l_col_count NUMBER := 0;
    l_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO l_col_count
    FROM user_tab_cols
    WHERE table_name = 'INV'
    AND column_name = 'QTY_PRODUCED';

    IF l_col_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV ADD QTY_PRODUCED NUMBER(7)';
    END IF;

    SELECT count(*)
    INTO l_col_count
    FROM user_tab_cols
    WHERE table_name = 'PUTAWAYLST'
    AND column_name = 'QTY_PRODUCED';

    IF l_col_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST ADD QTY_PRODUCED NUMBER(7)';
    END IF;
END;
/