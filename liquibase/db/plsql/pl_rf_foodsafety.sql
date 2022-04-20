create or replace PACKAGE pl_rf_FoodSafety AS

/***************************************************************
CONSTANT VARIABLE
***************************************************************/    
    RF_TIMESTAMP_FORMAT VARCHAR2(30):='YYYY-MM-DD HH24:MI:SS';
    
/***************************************************************
FUNCTIONS
***************************************************************/ 
    FUNCTION FoodSafetyTempsQuery (
        i_rf_log_init_record   IN rf_log_init_record,
        i_erm_id               IN erm.erm_id%TYPE,
        o_server               OUT fst_qry_obj
        
    ) RETURN rf.status;

    FUNCTION FoodSafetyTempsUpdate (
        i_rf_log_init_record   IN rf_log_init_record,
        i_client               IN fst_upd_obj
    ) RETURN rf.status;

END pl_rf_FoodSafety;
/

create or replace PACKAGE BODY pl_rf_FoodSafety AS


/*************************************************************************
**
**  Function : FoodSafetyTempsQuery
**
**  Description
**    Receiving module - Food Safety data - Query
**
**  Date      	 Modlog   Designer                           Comments
**  --------	  	 ------	  --------           ----------------------------------------
**  10/24/19            	  lnic4226	            Food Safety project      Initial version
**************************************************************************/ 
FUNCTION FoodSafetyTempsQuery(
    i_rf_log_init_record        IN    rf_log_init_record,
    i_erm_id                    IN    erm.erm_id%TYPE,
    o_server                    OUT   fst_qry_obj

)RETURN rf.status AS

    l_func_name     VARCHAR2(25):= 'FoodSafetyTempsQuery';
    l_dummy         VARCHAR2(12);
    rf_status       rf.status := rf.status_normal;

    BEGIN

		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize(). 

        o_server := fst_qry_obj(' ',' ',' ',' ',' ',' ');


        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Receiving FoodSafety - query - erm_id ['
                                        || i_erm_id
                                        || ']', sqlcode, sqlerrm);

        -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

        rf_status := rf.initialize(i_rf_log_init_record);
        IF rf_status = RF.STATUS_NORMAL THEN

        -- Step 3:    main business logic begins...

            BEGIN
                /*Get status and type for the PO from ERM table.Allow only Master PO to be collected */

                SELECT
                    erm_id
                INTO 
                    l_dummy
                FROM
                    erm
                WHERE
                    erm_id = i_erm_id
                    AND food_safety_print_flag = 'Y';

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'unable to get PO detailsy - erm_id ['
                    || i_erm_id || ']', sqlcode, sqlerrm);

                    rf_status:= RF.STATUS_INV_PO;                    
            END;  

        /*If PO is valid - populate values from FOOD_SAFETY_INBOUND table if entry is already there for this PO*/

        IF(rf_status = rf.status_normal)THEN     

        /*Get the Food Safety values for this erm id*/ 
            BEGIN 
                SELECT
                    door_no,
                    TO_CHAR(door_open_time, RF_TIMESTAMP_FORMAT),
                    front_temp,
                    mid_temp,
                    back_temp,
                    TO_CHAR(time_collected, RF_TIMESTAMP_FORMAT)
                INTO
                    o_server.door_no,
                    o_server.door_open_datetime,
                    o_server.trailer_front_temp,
                    o_server.trailer_middle_temp,
                    o_server.trailer_back_temp,
                    o_server.temp_collect_datetime
                FROM
                    food_safety_inbound
                WHERE
                    erm_id = i_erm_id;

            EXCEPTION
                WHEN no_data_found THEN

                        SELECT
                            door_no
                        INTO 
                            o_server.door_no
                        FROM
                            erm
                        WHERE
                            erm_id = i_erm_id;

                        rf_status := rf.status_normal;
            END;
        END IF;


    END IF; /* rf.Initialize() returned NORMAL */

    -- Step 4:  Call rf.Complete() with final status

    rf.complete(rf_status);
    RETURN rf_status;

    -- Step 5:  Call rf.logexception() and raise if any error unhandled.

    EXCEPTION  
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'foodsafetytempsquery failed', sqlcode, sqlerrm);
            rf.logexception();
            RAISE;

END FoodSafetyTempsQuery;

/*************************************************************************
**
**  Function : FoodSafetyTempsUpdate
**
**  Description
**    Receiving module - Food Safety data - Update
**
**  Date      	 Modlog   Designer                           Comments
**  --------	  	 ------	  --------           ----------------------------------------
**  10/24/19            	  lnic4226	            Food Safety project      Initial version 
**************************************************************************/

FUNCTION FoodSafetyTempsUpdate(
    i_rf_log_init_record   IN rf_log_init_record
    , i_client             IN fst_upd_obj
)RETURN rf.status AS
    rf_status           rf.status := rf.status_normal;
    l_func_name         VARCHAR2(25):= 'foodsafetytempsupdate';
    l_load_no           erm.load_no%TYPE;  
    l_door_no           erm.door_no%TYPE;
    l_erm_id            erm.erm_id%TYPE;        
    l_erm_type          erm.erm_type%TYPE;
    ORACLE_REC_LOCKED   EXCEPTION;
    PRAGMA EXCEPTION_INIT(ORACLE_REC_LOCKED, -54);
    ORACLE_PRIMARY_KEY_CONSTRAINT EXCEPTION;
    PRAGMA EXCEPTION_INIT(ORACLE_PRIMARY_KEY_CONSTRAINT, -1400);
    
    BEGIN

        -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
        -- No OUT parameter to initialize.

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Receiving FoodSafety - update - i_client [' ||i_client.erm_id ||']['
        || i_client.door_open_datetime || '][' ||i_client.trailer_front_temp||']['||i_client.trailer_middle_temp||']['||i_client.trailer_back_temp||']['||i_client.temp_collect_datetime, sqlcode, sqlerrm);

        -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

        rf_status := rf.initialize(i_rf_log_init_record);    
        IF rf_status = RF.STATUS_NORMAL THEN

        -- Step 3:  main business logic begins ...

            BEGIN
                SELECT 
                    erm_id 
                INTO 
                    l_erm_id
                FROM 
                    FOOD_SAFETY_INBOUND F
                WHERE 
                    F.erm_id = i_client.erm_id
                    FOR UPDATE OF door_open_time NOWAIT;

                UPDATE 
                    food_safety_inbound 
                SET 
                    door_open_time = to_date(i_client.door_open_datetime,RF_TIMESTAMP_FORMAT),
                    front_temp = i_client.trailer_front_temp, 
                    mid_temp = i_client.trailer_middle_temp, 
                    back_temp = i_client.trailer_back_temp, 
                    time_collected = to_date(i_client.temp_collect_datetime,RF_TIMESTAMP_FORMAT), 
                    upd_date = SYSDATE,
                    upd_user = REPLACE(user, 'OPS$', NULL),
                    upd_source = 'RF'
                WHERE 
                    erm_id = i_client.erm_id;   

                IF sql%rowcount=0 THEN
                    RF_STATUS:=RF.STATUS_UPDATE_FAIL;
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'Update food_safety_inbound failed - status ['
                    || rf_status || ']', sqlcode, sqlerrm);    
                END IF;    
            EXCEPTION
                WHEN ORACLE_REC_LOCKED THEN
                    rf_status := Rf.STATUS_REC_LOCK_BY_OTHER;
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'update food_safety_inbound failed - record lock ['
                    || rf_status || ']', sqlcode, sqlerrm);
                
                WHEN NO_DATA_FOUND THEN
                    BEGIN

                        /*Fetch the value of load_no,door_no,erm_id,erm_type corresponding 
                        to erm_id from erm table  to insert into FOOD_SAFETY_INBOUND table*/

                        SELECT 
                            DECODE(load_no,NULL,'No Load No',load_no),door_no,erm_id,erm_type 
                        INTO 
                            l_load_no,l_door_no,l_erm_id,l_erm_type 
                        FROM 
                            erm  
                        WHERE 
                            erm_id = i_client.erm_id;

                        INSERT INTO 
                            food_safety_inbound 
                            (load_no, door_no, 
                            door_open_time, front_temp, mid_temp, 
                            back_temp, erm_id, erm_type, 
                            time_collected, add_date, 
                            add_user, upd_date, upd_user,add_source,upd_source)
                        VALUES
                            (l_load_no, l_door_no, 
                            to_date(i_client.door_open_datetime,RF_TIMESTAMP_FORMAT), i_client.trailer_front_temp, 
                            i_client.trailer_middle_temp, i_client.trailer_back_temp, 
                            i_client.erm_id, l_erm_type, to_date(i_client.temp_collect_datetime,RF_TIMESTAMP_FORMAT), 
                            SYSDATE , REPLACE(user, 'OPS$', NULL) ,NULL,NULL,'RF',NULL);         

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            RF_STATUS:=rf.STATUS_INV_PO;                       

                        WHEN DUP_VAL_ON_INDEX THEN
                            RF_STATUS:=RF.STATUS_INSERT_FAIL;                        
                        WHEN ORACLE_PRIMARY_KEY_CONSTRAINT THEN
                            RF_STATUS:=RF.STATUS_INSERT_FAIL;
                        WHEN OTHERS THEN
                            RF_STATUS:=RF.STATUS_DATA_ERROR;
                            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Insert into food_safety_inbound failed - status ['
                            || rf_status || ']', sqlcode, sqlerrm);                            
                    END;                                
            
            WHEN OTHERS THEN
                    RF_STATUS:=RF.STATUS_DATA_ERROR;
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'Update food_safety_inbound failed - status ['
                    || rf_status || ']', sqlcode, sqlerrm);
            END;

            IF rf_STATUS=RF.STATUS_NORMAL THEN
                COMMIT;
            ELSE
                ROLLBACK;
            END IF;

            

        END IF; /* rf.Initialize() returned NORMAL */

        -- Step 4:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

        -- Step 5:  Call rf.logexception() and raise if any error unhandled.

    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'FoodSafetyTempsUpdate failed', sqlcode, sqlerrm);
            rf.LogException();	
            raise;    

    END FoodSafetyTempsUpdate;

END pl_rf_foodsafety;
/

GRANT EXECUTE ON pl_rf_foodsafety TO SWMS_USER;
/
