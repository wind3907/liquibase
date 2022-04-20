/****************************************************************************************
** Desc: Script to Add MU as cross_dock_type for master data
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    10/01/2019    sban3548    Add cross dock type 'MU' for CMU project  
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.cross_dock_type
    WHERE cross_dock_type = 'MU';

    IF v_row_count = 0 THEN
	
        INSERT INTO cross_dock_type
        (
            cross_dock_type,
            receive_whole_pallet,
            description
        )
        VALUES
        (
            'MU',
            'Y',
            'CMU CROSS DOCK'
        );

        COMMIT;

    END IF;
END;							  
/
