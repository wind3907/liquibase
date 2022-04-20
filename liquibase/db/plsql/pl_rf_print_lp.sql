CREATE OR REPLACE PACKAGE swms.pl_rf_print_lp AS
    FUNCTION Query
    (
        i_rf_log_init_record        in swms.rf_log_init_record,
        i_query_by                  in pls_integer,
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out swms.print_lp_result_obj
    ) RETURN swms.rf.STATUS;


    FUNCTION QueryByTest
    (
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out swms.print_lp_result_obj
    ) RETURN swms.rf.STATUS;

end pl_rf_print_lp;
/
SHOW ERRORS;


CREATE OR REPLACE PACKAGE BODY swms.pl_rf_print_lp AS

    /*----------------------------------------------------------------*/
    /* Function Query                                                 */
    /*----------------------------------------------------------------*/

    FUNCTION Query
    (
        i_rf_log_init_record        in swms.rf_log_init_record,
        i_query_by                  in pls_integer, -- 0=Test, 1=ByLocation, 2=ByLp, 3=ByItem, 4=ByExtUpc, 5=ByIntUpc
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out swms.print_lp_result_obj
    ) RETURN swms.rf.STATUS
    IS
        rf_status                   swms.rf.STATUS := swms.rf.STATUS_NORMAL;
        CURSOR c_inv IS
            SELECT i.plogi_loc, i.logi_loc, p.ti, p.hi, TRUNC(i.qoh/p.spc) case_qty,                
                   MOD(i.qoh, p.spc) split_qty, i.prod_id, p.descrip, p.mfg_sku, 
                   i.cust_pref_vendor, p.brand, i.exp_date, p.pallet_type, i.inv_uom, 
                   i.rec_id, i.rec_date, p.pack, p.prod_size,
                   DECODE(p.cubitron, 'Y', '** NEEDS CUBITRON **', NULL) cubitron,
                   SUBSTR(p.external_upc, 9 , 5) ucn
              FROM inv i, pm p
             WHERE i.prod_id = p.prod_id
               AND i.cust_pref_vendor = p.cust_pref_vendor
               AND i.plogi_loc != i.logi_loc
               AND NOT EXISTS (SELECT 1 
                                 FROM loc l 
                                WHERE l.logi_loc = i.plogi_loc 
                                  AND l.slot_type IN('MXC', 'MXF'))
               AND i.plogi_loc        = DECODE(i_query_by, 1, TRIM(i_query_input), i.plogi_loc)
               AND i.logi_loc         = DECODE(i_query_by, 2, TRIM(i_query_input), i.logi_loc)
               AND i.prod_id          = DECODE(i_query_by, 3, TRIM(i_query_input), i.prod_id)
               AND i.cust_pref_vendor = DECODE(i_query_by, 3, TRIM(i_query_input_cpv), i.cust_pref_vendor)
               AND i.prod_id          = DECODE(i_query_by, 4, (SELECT prod_id 
                                                                 FROM pm_upc
                                                                WHERE TRIM(i_query_input) IN (external_upc, internal_upc)
                                                                  AND ROWNUM = 1)
                                                            , i.prod_id)
               AND i.prod_id          = DECODE(i_query_by, 5, (SELECT prod_id 
                                                                 FROM pm_upc
                                                                WHERE internal_upc = TRIM(i_query_input)
                                                                  AND ROWNUM = 1)
                                                            , i.prod_id);
                                                            
        l_result_table      swms.print_lp_result_table;     
        i                   NUMBER;     
        l_pick_loc          loc.logi_loc%TYPE;
        l_cnt               NUMBER;
    BEGIN
        Pl_Text_Log.ins_msg ('I', 'pl_rf_print_lp', 'BEGIN Function Query i_query_by=['||i_query_by||']  i_query_input=[' ||i_query_input||'] i_query_input_cpv =['||i_query_input_cpv||']', NULL, NULL);
        l_result_table      := swms.print_lp_result_table();

        
        -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

        o_detail_collection := swms.print_lp_result_obj(swms.print_lp_result_table());              


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

        rf_status := rf.Initialize(i_rf_log_init_record);
        IF rf_status = swms.rf.STATUS_NORMAL THEN

			-- main business logic begins...

			-- Step 3:  Open cursor, fetch results, close cursor

            BEGIN
                IF i_query_by = 0 THEN  
                        rf_status := QueryByTest(i_query_input, i_query_input_cpv, o_detail_collection);
                        i := 1;
                ELSE    
                    i := 0;
                    FOR rec IN c_inv
                    LOOP
                        BEGIN
                            SELECT logi_loc
                              INTO l_pick_loc
                              FROM loc l
                             WHERE l.perm = 'Y'
                               AND l.prod_id = rec.prod_id
                               AND l.cust_pref_vendor = rec.cust_pref_vendor
                               AND l.uom IN (0 ,2)
                               AND l.rank = 1                               
                               AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_pick_loc := NULL;
                        END;
                        
                        i := i + 1;
                        l_result_table.EXTEND(1);
                        l_result_table(i) := swms.print_lp_result_record (
                                                   rec.plogi_loc,										-- location         varchar2(10),               
                                                   rec.logi_loc,										-- pallet_id        varchar2(18),
                                                   NVL(rec.ti,0),										-- ti               number(4),
                                                   NVL(rec.hi,0),										-- hi               number(4),
                                                   NVL(rec.case_qty,0),									-- case_qty         number(7),
                                                   NVL(rec.split_qty,0),							    -- split_qty        number(7),
                                                   rec.prod_id,											-- prod_id          varchar2(10),
                                                   rec.descrip,											-- descrip          varchar2(100),
                                                   rec.mfg_sku,											-- mfg_sku          varchar2(14),
                                                   rec.cust_pref_vendor,								-- cust_pref_vendor varchar2(10),
                                                   rec.brand,											-- brand            varchar2(7),
                                                   TO_CHAR(rec.exp_date, RF.SERIALIZED_DATE_PATTERN),	-- exp_date         varchar2(10),
                                                   rec.pallet_type,										-- pallet_type      varchar2(2),
                                                   NVL(rec.inv_uom,0),									-- uom              number(2),
                                                   rec.rec_id,											-- erm_id           varchar2(12),
                                                   TO_CHAR(rec.rec_date, RF.SERIALIZED_DATE_PATTERN),	-- erm_date         varchar2(10),
                                                   rec.pack,											-- pack             varchar2(4),
                                                   rec.prod_size,										-- prod_size        varchar2(6)
                                                   rec.cubitron,										-- message          varchar2(30)
                                                   rec.ucn,												-- ucn              varchar2(5)
                                                   l_pick_loc											-- logi_loc         varchar2(10)
                                                );
                    END LOOP;
                        
                    o_detail_collection := swms.print_lp_result_obj(l_result_table);                    
                        
                END IF;
            END;
            
            IF i = 0 THEN
                CASE 
                    WHEN i_query_by = 1 THEN
                        SELECT COUNT(*)
                          INTO l_cnt 
                          FROM loc
                         WHERE logi_loc = i_query_input;
                         
                        IF l_cnt > 0 THEN
                            rf_status := rf.STATUS_INV_NOT_FOUND;
                        ELSE
                            rf_status := rf.STATUS_INV_LOCATION;
                        END IF; 
                    WHEN i_query_by = 2 THEN
                        SELECT COUNT(*)
                          INTO l_cnt 
                          FROM inv
                         WHERE logi_loc = i_query_input;
                         
                        IF l_cnt > 0 THEN
                            rf_status := rf.STATUS_INV_NOT_FOUND;
                        ELSE
                            rf_status := rf.STATUS_INV_LABEL;
                        END IF;
                    WHEN i_query_by = 3 THEN
                        SELECT COUNT(*)
                          INTO l_cnt 
                          FROM pm
                         WHERE prod_id = i_query_input;
                         
                        IF l_cnt > 0 THEN
                            rf_status := rf.STATUS_INV_NOT_FOUND;
                        ELSE
                            rf_status := rf.STATUS_INV_PRODID;
                        END IF; 
                    WHEN i_query_by = 4 THEN
                        SELECT COUNT(*)
                          INTO l_cnt 
                          FROM pm_upc
                         WHERE i_query_input IN (external_upc, internal_upc);
                         
                        IF l_cnt > 0 THEN
                            rf_status := rf.STATUS_INV_NOT_FOUND;
                        ELSE
                            rf_status := rf.STATUS_INV_EXT_UPC;
                        END IF; 
                    WHEN i_query_by = 5 THEN
                        SELECT COUNT(*)
                          INTO l_cnt 
                          FROM pm_upc
                         WHERE internal_upc = i_query_input;
                         
                        IF l_cnt > 0 THEN
                            rf_status := rf.STATUS_INV_NOT_FOUND;
                        ELSE
                            rf_status := rf.STATUS_INV_EXT_UPC;    
                        END IF; 
                END CASE;       
            END IF;
            
        END IF; /* rf.Initialize() returned NORMAL */
        

		-- Step 4:  Call rf.Complete() with final status

        rf.Complete(rf_status);
        RETURN rf_status;

    EXCEPTION
        WHEN OTHERS THEN
            rf.LogException();  -- log it
            RAISE;              -- then throw up to next handler, if any
    END Query;


    /*----------------------------------------------------------------*/
    /* Function QueryByTest                                           */
    /*----------------------------------------------------------------*/

    function QueryByTest
    (
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out swms.print_lp_result_obj
    ) return swms.rf.STATUS
    IS
        rf_status                   swms.rf.STATUS := swms.rf.STATUS_NORMAL;

        l_result_table              swms.print_lp_result_table;
        l_result_record             swms.print_lp_result_record;

    BEGIN

        -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

        l_result_table      := swms.print_lp_result_table();
        

        FOR i in 1..10 
        LOOP
            l_result_table.EXTEND(1);
            --insert into l_result_table values(l_result_record);
            l_result_table(i) :=
                swms.print_lp_result_record (
                    '1234567890',									-- location         varchar2(10),
                    '123456789012345678',							-- pallet_id        varchar2(18),
                    8888,											-- ti               number(4),
                    7777,											-- hi               number(4),
                    1234567,										-- case_qty         number(7),
                    0,												-- split_qty        number(7),
                    '1234567890',									-- prod_id          varchar2(10),
                    '123456789012345678901234567890',				-- descrip          varchar2(100),
                    '12345678901234',								-- mfg_sku          varchar2(14),
                    '1234567890',									-- cust_pref_vendor varchar2(10),
                    '1234567',										-- brand            varchar2(7),
                    TO_CHAR(sysdate, RF.SERIALIZED_DATE_PATTERN),	-- exp_date         varchar2(10),
                    'WW',											-- pallet_type      varchar2(2),
                    2,												-- uom              number(2),
                    '123456789012',									-- erm_id           varchar2(12),
                    TO_CHAR(sysdate, RF.SERIALIZED_DATE_PATTERN),	-- erm_date         varchar2(10),
                    '1234',											-- pack             varchar2(4),
                    '123456',										-- prod_size        varchar2(6)
                    '** NEEDS CUBITRON **',							-- message          varchar2(30),
                    '12345',										-- ucn              varchar2(5),
                    'XXXXXX'										-- logi_loc         varchar2(10)                            
                );
        END LOOP;       
        
        o_detail_collection := swms.print_lp_result_obj(l_result_table);
        
        RETURN rf_status;
    END QueryByTest;

END pl_rf_print_lp;
/
SHOW ERRORS;


ALTER PACKAGE swms.pl_rf_print_lp compile plsql_code_type = native;

GRANT EXECUTE ON swms.pl_rf_print_lp to swms_user;
CREATE OR REPLACE PUBLIC SYNONYM pl_rf_print_lp FOR swms.pl_rf_print_lp;
