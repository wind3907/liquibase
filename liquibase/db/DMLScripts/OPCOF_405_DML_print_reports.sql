/**************************************************************
Script to insert a row into PRINT_REPORTS table for new report
"Open Manifests > 7 Days".
***************************************************************/

DECLARE
    v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*) 
       INTO v_row_count
    FROM print_reports
    WHERE report = 'mf1rb';

    IF v_row_count = 0 THEN
        INSERT INTO print_reports
                       (report, 
                        queue_type, 
                        descrip, 
                        command,
                        fifo, 
                        copies, 
                        duplex)
               VALUES
                       ('mf1rb', 
                        'RPTP', 
                        'Manifests Open', 
                        'runsqlrpt :p/:f :r', 
                        'N', 
                        1,
                        'N');
            
        COMMIT;

    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE; 

END;
/
