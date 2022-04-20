create or replace package pl_xdock_sls_helper as
    ----------------------
    -- Package constants
    ----------------------
    /************************************************************************
    -- pl_xdock_sls_helper
    --
    -- Description:   Package for xdock sls related data merging functionalities
    --
    --
    -- Modification log: OPCOF 3568
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 12-Aug-2021  lwee1503      Initial version.
    *************************************************************************/

    ---------------------------------
    -- function/procedure signatures
    ---------------------------------

    PACKAGE_NAME CONSTANT swms_log.program_name%TYPE := 'PL_XDOCK_SLS_HELPER';
    APPLICATION_FUNC CONSTANT swms_log.application_func%TYPE := 'POPULATE_SLS_DATA';
    c_oracle_normal CONSTANT NUMBER := 0; /*  ORACLE operation successful. */

    PROCEDURE populateSLSDataRunner;

    PROCEDURE populateSLSData(
        i_float_no IN floats.float_no%TYPE
    );

    PROCEDURE populateXdockLasPallet(
        i_float_no IN floats.float_no%TYPE
    );

    PROCEDURE populateXdockLasTruck(
        i_float_no IN floats.float_no%TYPE
    );

END pl_xdock_sls_helper;
/

create or replace PACKAGE BODY pl_xdock_sls_helper as
    PROCEDURE populateSLSDataRunner
    AS
        l_func_name CONSTANT swms_log.procedure_name%TYPE := 'populateSLSDataRunner';
        CURSOR c_float_list IS
            SELECT distinct (f.float_no)
            FROM swms.floats f left join las_pallet p
            ON f.truck_no = p.truck
                AND f.float_seq = p.palletno
                AND f.batch_no = p.batch
            WHERE f.cross_dock_type = 'X'
                    AND p.truck is null
                    AND p.palletno is null
                    AND p.batch is null;
    BEGIN
        FOR i IN c_float_list
            LOOP
                BEGIN

                    populateSLSData(i.float_no);

                    pl_log.ins_msg('DEBUG', l_func_name,
                                   'SLS data populating process completed for float no:' || i.float_no, SQLCODE,
                                   SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);


                EXCEPTION
                    WHEN OTHERS THEN
                        pl_log.ins_msg('ERROR', l_func_name, 'Error in populating SLS data for float no' ||i.float_no,
                                       sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                END;
            END LOOP;
    END populateSLSDataRunner;

    PROCEDURE populateSLSData(i_float_no IN floats.float_no%TYPE)
    AS
        l_route_status route.status%TYPE := NULL;
    BEGIN

        select r.status
        into l_route_status
        from route r
                 inner join floats f on r.route_no = f.route_no
        where f.float_no = i_float_no;

        IF l_route_status = 'OPN' OR l_route_status = 'SHT' THEN

            pl_lm_loader.create_loader_batches(NULL, NULL, i_float_no);

            populateXdockLasTruck(i_float_no);

            populateXdockLasPallet(i_float_no);

            COMMIT;
        ELSE
            pl_log.ins_msg('DEBUG',
                           PACKAGE_NAME || '.populateSLSData',
                           'route not opened yet. no need of creating las_truck records ' ||
                           'float no [' || i_float_no || '] ',
                           NULL, NULL);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            pl_log.ins_msg('ERROR',
                           PACKAGE_NAME || '.populateSLSData',
                           'populateSLSData ' ||
                           'float no [' || i_float_no ||
                           '] In When others error[' ||
                           TO_CHAR(SQLCODE) || '] ',
                           sqlcode, sqlerrm);
    END populateSLSData;


    PROCEDURE populateXdockLasPallet(i_float_no IN floats.float_no%TYPE)
        IS
    BEGIN
        /* TODO do we need delete las_pallet query here for this float_no */

        INSERT INTO las_pallet
        (Truck, selection_status,
         PalletNo, batch, max_stop, min_stop)
        SELECT v.truck_no,
               'S',
               v.float_seq,
               floats_batch_no,
               MAX(stop_no),
               MIN(stop_no)
        FROM v_ob1rb v
        WHERE v.float_no = i_float_no
        GROUP BY v.truck_no, floats_batch_no, 'S', v.float_seq;
        pl_log.ins_msg('DEBUG',
                       PACKAGE_NAME || '.populateXdockLasPallet',
                       'populateXdockLasPallet ' ||
                       'float no [' || i_float_no || '] ' ||
                       'insert #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                       NULL, NULL);
    EXCEPTION
        WHEN OTHERS THEN
            pl_log.ins_msg('FATAL',
                           PACKAGE_NAME || '.populateXdockLasPallet',
                           'populateXdockLasPallet ' ||
                           'float no [' || i_float_no ||
                           '] In When others error[' ||
                           TO_CHAR(SQLCODE) || '] ',
                           sqlcode, sqlerrm);
    END populateXdockLasPallet;


    PROCEDURE populateXdockLasTruck(i_float_no IN floats.float_no%TYPE)
    AS
        l_truck_no     route.truck_no%TYPE := NULL;
        l_route_status route.status%TYPE   := NULL;
        l_cube_length  NUMBER              := 6;
        l_cube_dry     NUMBER              := 0;
        l_cube_cooler  NUMBER              := 0;
        l_cube_freezer NUMBER              := 0;
        l_truck_exists NUMBER              := 0;
        CURSOR c_get_truckinfo IS
            SELECT v.truck_no,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'D', v.float_no, NULL))) dry_pallets,
                   SUM(DECODE(v.comp_code, 'D', v.cases, 0))       dry_cases,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'D', v.stop_no, null)))  dry_stops,
                   SUM(DECODE(v.comp_code, 'D', v.cube, 0))        dry_cube,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'D', DECODE(p.loader_status,'*',NULL,v.float_no)
                                          , NULL))) dry_remaining,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'C', v.float_no, NULL))) cooler_pallets,
                   SUM(DECODE(v.comp_code,
                              'C', v.cases, 0))                    cooler_cases,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'C', v.stop_no, null)))  cooler_stops,
                   SUM(DECODE(v.comp_code, 'C', v.cube, 0))        cooler_cube,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'C', DECODE(p.loader_status,'*',NULL,v.float_no)
                                          , NULL))) cooler_remaining,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'F', v.float_no, NULL))) freezer_pallets,
                   SUM(DECODE(v.comp_code,
                              'F', v.cases, 0))                    freezer_cases,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'F', v.stop_no, null)))  freezer_stops,
                   SUM(DECODE(v.comp_code, 'F', v.cube, 0))        freezer_cube,
                   COUNT(DISTINCT (DECODE(v.comp_code,
                                          'F', DECODE(p.loader_status,'*',NULL,v.float_no)
                                          , NULL))) freezer_remaining,
                   v.route_no
            FROM v_ob1rb v
            LEFT join las_pallet p on v.floats_batch_no = p.batch
            and v.truck_no = p.truck
            AND v.float_seq = p.palletno
            WHERE v.truck_no = l_truck_no
              AND v.status <> 'CLS'
            GROUP BY v.truck_no, v.route_no;
        CURSOR c_get_las_truck_info (
            csTruck las_truck.truck%TYPE) IS
            SELECT count(1)
            FROM las_truck
            WHERE truck = csTruck;

    BEGIN
        select r.truck_no
        into l_truck_no
        from route r
                 inner join floats f on r.route_no = f.route_no
        where f.float_no = i_float_no;

        FOR cgt IN c_get_truckinfo
            LOOP


                /* Calculate the l_cube_dry with the value from las_truck*/
                l_cube_dry := cgt.dry_cube;
                IF LENGTH(TO_CHAR(l_cube_dry)) > l_cube_length THEN
                    l_cube_dry := ROUND(l_cube_dry);
                    IF LENGTH(TO_CHAR(l_cube_dry)) > l_cube_length THEN
                        l_cube_dry := TO_NUMBER(RPAD('9', l_cube_length, '9'));
                    END IF;
                END IF;

                /* Calculate the l_cube_cooler with the value from las_truck*/
                l_cube_cooler := cgt.cooler_cube;
                IF LENGTH(TO_CHAR(l_cube_cooler)) > l_cube_length THEN
                    l_cube_cooler := ROUND(l_cube_cooler);
                    IF LENGTH(TO_CHAR(l_cube_cooler)) > l_cube_length THEN
                        l_cube_cooler := TO_NUMBER(RPAD('9', l_cube_length, '9'));
                    END IF;
                END IF;

                /* Calculate the l_cube_freezer with the value from las_truck*/
                l_cube_freezer := cgt.freezer_cube;
                IF LENGTH(TO_CHAR(l_cube_freezer)) > l_cube_length THEN
                    l_cube_freezer := ROUND(l_cube_freezer);
                    IF LENGTH(TO_CHAR(l_cube_freezer)) > l_cube_length THEN
                        l_cube_freezer := TO_NUMBER(RPAD('9', l_cube_length, '9'));
                    END IF;
                END IF;

                OPEN c_get_las_truck_info(l_truck_no);
                FETCH c_get_las_truck_info INTO l_truck_exists;

                IF (l_truck_exists = 0) THEN

                    INSERT INTO las_truck
                    (TRUCK, ROUTE_NO,
                     DRY_PALLETS, DRY_CASES, DRY_STOPS, DRY_CUBE, DRY_REMAINING,
                     COOLER_PALLETS, COOLER_CASES, COOLER_STOPS,
                     COOLER_CUBE, COOLER_REMAINING,
                     FREEZER_PALLETS, FREEZER_CASES, FREEZER_STOPS,
                     FREEZER_CUBE, FREEZER_REMAINING)
                    VALUES (cgt.truck_no, cgt.route_no,
                            cgt.dry_pallets, cgt.dry_cases, cgt.dry_stops,
                            TO_CHAR(l_cube_dry), cgt.dry_remaining,
                            cgt.cooler_pallets, cgt.cooler_cases, cgt.cooler_stops,
                            TO_CHAR(l_cube_cooler), cgt.cooler_remaining,
                            cgt.freezer_pallets, cgt.freezer_cases, cgt.freezer_stops,
                            TO_CHAR(l_cube_freezer), cgt.freezer_remaining);
                ELSE
                    UPDATE LAS_TRUCK
                    SET TRUCK             = cgt.truck_no,
                        DRY_PALLETS       = TO_CHAR(cgt.dry_pallets),
                        DRY_CASES         = TO_CHAR(cgt.dry_cases),
                        DRY_STOPS         = TO_CHAR(cgt.dry_stops),
                        DRY_CUBE          = TO_CHAR(l_cube_dry),
                        DRY_REMAINING     = TO_CHAR(cgt.dry_remaining),
                        COOLER_PALLETS    = TO_CHAR(cgt.cooler_pallets),
                        COOLER_CASES      = TO_CHAR(cgt.cooler_cases),
                        COOLER_STOPS      = TO_CHAR(cgt.cooler_stops),
                        COOLER_CUBE       = TO_CHAR(l_cube_cooler),
                        COOLER_REMAINING  = TO_CHAR(cgt.cooler_remaining),
                        FREEZER_PALLETS   = TO_CHAR(cgt.freezer_pallets),
                        FREEZER_CASES     = TO_CHAR(cgt.freezer_cases),
                        FREEZER_STOPS     = TO_CHAR(cgt.freezer_stops),
                        FREEZER_CUBE      = TO_CHAR(l_cube_freezer),
                        FREEZER_REMAINING = TO_CHAR(cgt.freezer_remaining),
                        DRY_STATUS        = DECODE(DRY_STATUS, 'C', DECODE(SIGN(cgt.dry_remaining-DRY_REMAINING), 1, '', 'C'), DRY_STATUS),
                        COOLER_STATUS     = DECODE(COOLER_STATUS, 'C', DECODE(SIGN(cgt.cooler_remaining-COOLER_REMAINING), 1, '','C'),
                                                   COOLER_STATUS),
                        FREEZER_STATUS    = DECODE(FREEZER_STATUS, 'C', DECODE(SIGN(cgt.freezer_remaining-FREEZER_REMAINING), 1, '', 'C'),
                                                   FREEZER_STATUS),
                        DRY_COMPLETE_TIME = DECODE(SIGN(cgt.dry_remaining-DRY_REMAINING), 1, '', DRY_COMPLETE_TIME),
                        DRY_COMPLETE_USER = DECODE(SIGN(cgt.dry_remaining-DRY_REMAINING), 1, '', DRY_COMPLETE_USER),
                        COOLER_COMPLETE_TIME = DECODE(SIGN(cgt.cooler_remaining-COOLER_REMAINING), 1, '', COOLER_COMPLETE_TIME),
                        COOLER_COMPLETE_USER = DECODE(SIGN(cgt.cooler_remaining-COOLER_REMAINING), 1, '', COOLER_COMPLETE_USER),
                        FREEZER_COMPLETE_TIME = DECODE(SIGN(cgt.freezer_remaining-FREEZER_REMAINING), 1, '', FREEZER_COMPLETE_TIME),
                        FREEZER_COMPLETE_USER = DECODE(SIGN(cgt.freezer_remaining-FREEZER_REMAINING), 1, '', FREEZER_COMPLETE_USER)
                    WHERE TRUCK = cgt.truck_no;
                END IF;
                pl_log.ins_msg('DEBUG',
                               PACKAGE_NAME || '.populateXdockLasTruck',
                               'populateXdockLasTruck ' ||
                               'float no [' || i_float_no || '] ' ||
                               'cgt.truck_no [' || cgt.truck_no || ']',
                               NULL, NULL);
            END LOOP;

    END populateXdockLasTruck;

END pl_xdock_sls_helper;
/

CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_sls_helper FOR swms.pl_xdock_sls_helper;
GRANT EXECUTE ON swms.pl_xdock_sls_helper TO SWMS_USER;
