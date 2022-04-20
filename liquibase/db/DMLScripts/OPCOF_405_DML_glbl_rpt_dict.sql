DECLARE
    v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*) 
       INTO v_row_count
    FROM global_report_dict
    WHERE report_name = 'mf1rb';

    IF v_row_count = 0 THEN
        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES
            (3, 'mf1rb', '1', 'Manifests Open ', 15);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES
            (3, 'mf1rb', '2', 'Manifest#', 11);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (3, 'mf1rb', '3', 'Manifest Date', 13);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (3, 'mf1rb', '4', ' # Of Days|Open', 15);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (3, 'mf1rb', '5', ' # Of Returns|Entered', 21);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES
            (12, 'mf1rb', '1', 'French Manifests Open ', 15);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES
            (12, 'mf1rb', '2', 'French Manifest#', 11);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (12, 'mf1rb', '3', 'French Manifest Date', 13);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (12, 'mf1rb', '4', ' French # Of Days|Open', 15);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (12, 'mf1rb', '5', ' French # Of Returns|Entered', 21);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES
            (13, 'mf1rb', '1', 'Spanish Manifests Open ', 15);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES
            (13, 'mf1rb', '2', 'Spanish Manifest#', 11);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (13, 'mf1rb', '3', 'Spanish Manifest Date', 13);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (13, 'mf1rb', '4', ' Spanish # Of Days|Open', 15);

        INSERT INTO global_report_dict
            (lang_id, report_name, fld_lbl_name, fld_lbl_desc, max_len)
        VALUES 
            (13, 'mf1rb', '5', ' Spanish # Of Returns|Entered', 21);

        COMMIT;

    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE; 

END;
/
