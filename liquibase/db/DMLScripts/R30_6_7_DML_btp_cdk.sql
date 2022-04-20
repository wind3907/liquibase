DECLARE
    l_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO l_exists
    FROM cross_dock_type
    WHERE cross_dock_type = 'BP';

    IF (l_exists = 0)  THEN

        INSERT INTO cross_dock_type
        (
            cross_dock_type,
            receive_whole_pallet,
            description
        )
        VALUES
        (
            'BP',
            'N',
            'Build to pallet CDK type'
        );

        COMMIT;

    END IF;
END;							  
/