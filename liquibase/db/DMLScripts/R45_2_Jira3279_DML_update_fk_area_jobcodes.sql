DECLARE
    d_job_code    fk_area_jobcodes.swap_jobcode%TYPE;
    c_job_code    fk_area_jobcodes.swap_jobcode%TYPE;
    f_job_code    fk_area_jobcodes.swap_jobcode%TYPE;
    rows_updated  PLS_INTEGER := 0;
BEGIN

    SELECT nvl(swap_jobcode, 'X') INTO d_job_code
    FROM   fk_area_jobcodes
    WHERE  sub_area_code = 'D';

    SELECT nvl(swap_jobcode, 'X') INTO c_job_code
    FROM   fk_area_jobcodes
    WHERE  sub_area_code = 'C';

    SELECT nvl(swap_jobcode, 'X') INTO f_job_code
    FROM   fk_area_jobcodes
    WHERE  sub_area_code = 'F';

    IF d_job_code != 'DRYSWP' THEN
        UPDATE fk_area_jobcodes
        SET swap_jobcode = 'DRYSWP'
        WHERE sub_area_code = 'D';
        rows_updated := rows_updated + 1;
    END IF;

    IF c_job_code != 'CLRSWP' THEN
        UPDATE fk_area_jobcodes
        SET swap_jobcode = 'CLRSWP'
        WHERE sub_area_code = 'C';
        rows_updated := rows_updated + 1;
    END IF;

    IF f_job_code != 'FZRSWP' THEN
        UPDATE fk_area_jobcodes
        SET swap_jobcode = 'FZRSWP'
        WHERE sub_area_code = 'F';    
        rows_updated := rows_updated + 1;
    END IF;
	
    IF rows_updated > 0 THEN
        COMMIT;
    END IF;
	
END;
/
