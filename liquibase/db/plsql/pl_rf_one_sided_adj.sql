--
-- Return values
--   rf.STATUS_NORMAL      -- Normal successful completion.  Result record returned.
--   rf.STATUS_INV_PRODID  -- The PROD_ID entered does not exist in the PM table.
--   rf.STATUS_INVALID_UPC -- The UPC entered is associated with more than one PROD_ID in the PM_UPC table.
--
CREATE OR REPLACE PACKAGE swms.pl_rf_one_sided_adj AS
    FUNCTION Query
    (
        i_rf_log_init_record        in rf_log_init_record,
        i_query_by                  in pls_integer,
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out print_lp_result_obj
    ) RETURN rf.STATUS;


    FUNCTION QueryByTest
    (
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out print_lp_result_obj
    ) RETURN rf.STATUS;


    FUNCTION ValidateUpdate
    (
        i_rf_log_init_record        in rf_log_init_record,
        i_location                  in inv.plogi_loc%TYPE,
        i_prod_id                   in inv.prod_id%TYPE,
        i_cust_pref_vendor          in inv.cust_pref_vendor%TYPE,
        i_case_qty                  in number,
        i_exp_date                  in varchar2,
        o_pallet_id                 out inv.logi_loc%TYPE
    ) RETURN rf.STATUS;
end pl_rf_one_sided_adj;
/
SHOW ERRORS;


CREATE OR REPLACE PACKAGE BODY swms.pl_rf_one_sided_adj AS

    /*----------------------------------------------------------------*/
    /* Function Query                                                 */
    /*----------------------------------------------------------------*/

    FUNCTION Query
    (
        i_rf_log_init_record        in rf_log_init_record,
        i_query_by                  in pls_integer, -- 0=Test, 1=ByLocation, 2=ByLp, 3=ByItem, 4=ByExtUpc, 5=ByIntUpc
        i_query_input               in varchar2,
        i_query_input_cpv           in varchar2, /* only used with ByItem query */
        o_detail_collection         out print_lp_result_obj
    ) RETURN rf.STATUS
    IS
        rf_status           rf.STATUS := rf.STATUS_NORMAL;

        CURSOR c_pm IS
            SELECT p.brand, p.cust_pref_vendor, p.descrip, p.hi, p.last_ship_slot, p.mfg_sku,
                   p.pack, p.prod_id, p.prod_size, p.ti, SUBSTR(p.external_upc, 9 , 5) ucn,
                   p.pallet_type, 2 uom, p.exp_date_trk
              FROM pm p
             WHERE p.prod_id          = DECODE(i_query_by, 3, TRIM(i_query_input), p.prod_id)
               AND p.cust_pref_vendor = DECODE(i_query_by, 3, TRIM(i_query_input_cpv), p.cust_pref_vendor)
               AND p.prod_id          = DECODE(i_query_by, 4, (SELECT prod_id 
                                                                 FROM pm_upc
                                                                WHERE TRIM(i_query_input) IN (external_upc, internal_upc)
                                                                  AND ROWNUM = 1)
                                                            , p.prod_id)
               AND p.prod_id          = DECODE(i_query_by, 5, (SELECT prod_id 
                                                                 FROM pm_upc
                                                                WHERE internal_upc = TRIM(i_query_input)
                                                                  AND ROWNUM = 1)
                                                            , p.prod_id)
               AND ROWNUM = 1;

        l_result_table      print_lp_result_table;

        l_location          zone.induction_loc%TYPE;
        l_exp_date          VARCHAR2(10);   -- print_lp_result_record.exp_date%TYPE;
        l_cnt               NUMBER;
    BEGIN
        pl_text_log.ins_msg ('I', 'pl_rf_one_sided_adj', 'BEGIN Function Query i_query_by=['||i_query_by||
                             ']  i_query_input=['||i_query_input||'] i_query_input_cpv =['||i_query_input_cpv||']',
                             NULL, NULL);

        l_result_table      := print_lp_result_table();

        -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

        o_detail_collection := print_lp_result_obj(print_lp_result_table());              

        -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

        rf_status := rf.Initialize(i_rf_log_init_record);
        IF rf_status = rf.STATUS_NORMAL THEN

            -- main business logic begins...

            -- Step 3:  Open cursor, fetch results, close cursor

            IF i_query_by = 0 THEN  
                rf_status := QueryByTest(i_query_input, i_query_input_cpv, o_detail_collection);
            ELSE    
                BEGIN
                    l_cnt := 1;

                    CASE
                        WHEN i_query_by = 3 THEN
                            SELECT COUNT(*)
                              INTO l_cnt 
                              FROM pm
                             WHERE prod_id = TRIM(i_query_input)
                               AND cust_pref_vendor = TRIM(i_query_input_cpv);
                        WHEN i_query_by = 4 THEN
                            SELECT COUNT(distinct prod_id)
                              INTO l_cnt 
                              FROM pm_upc
                             WHERE i_query_input IN (external_upc, internal_upc);
                        WHEN i_query_by = 5 THEN
                            SELECT COUNT(distinct prod_id)
                              INTO l_cnt 
                              FROM pm_upc
                             WHERE internal_upc = TRIM(i_query_input);
                    END CASE;

                    IF l_cnt = 1 THEN
                        BEGIN
                            SELECT induction_loc
                              INTO l_location
                              FROM zone
                             WHERE rule_id = 5
                               AND induction_loc IS NOT NULL
                               AND ROWNUM = 1;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                l_location := NULL;
                        END;

                        FOR rec IN c_pm LOOP
                            IF rec.exp_date_trk <> 'Y' THEN
                                l_exp_date := NULL;
                            ELSE
                                --l_exp_date := '1980-01-01' ;
								l_exp_date := '010180';
                            END IF;
                            l_result_table.EXTEND(1);
                            l_result_table(1) := print_lp_result_record (
                                                       l_location,                           -- location         varchar2(10),
                                                       NULL,                                 -- pallet_id        varchar2(18),
                                                       NVL(rec.ti,0),                        -- ti               number(4),
                                                       NVL(rec.hi,0),                        -- hi               number(4),
                                                       0,                                    -- case_qty         number(7),
                                                       0,                                    -- split_qty        number(7),
                                                       rec.prod_id,                          -- prod_id          varchar2(10),
                                                       rec.descrip,                          -- descrip          varchar2(100),
                                                       rec.mfg_sku,                          -- mfg_sku          varchar2(14),
                                                       rec.cust_pref_vendor,                 -- cust_pref_vendor varchar2(10),
                                                       rec.brand,                            -- brand            varchar2(7),
                                                       l_exp_date,                           -- exp_date         varchar2(10),
                                                       rec.pallet_type,                      -- pallet_type      varchar2(2),
                                                       rec.uom,                              -- uom              number(2),
                                                       0,                                 -- erm_id           varchar2(12),
                                                       NULL,                                 -- erm_date         varchar2(10),
                                                       rec.pack,                             -- pack             varchar2(4),
                                                       rec.prod_size,                        -- prod_size        varchar2(6)
                                                       NULL,                                 -- message          varchar2(30)
                                                       rec.ucn,                              -- ucn              varchar2(5)
                                                       rec.last_ship_slot                    -- logi_loc         varchar2(10)
                                                       );
                        END LOOP;

                        o_detail_collection := print_lp_result_obj(l_result_table);
                    ELSIF l_cnt = 0 THEN
                        IF i_query_by = 3 THEN
                            rf_status := rf.STATUS_INV_PRODID;
                        ELSE
                            rf_status := rf.STATUS_INVALID_UPC;
                        END IF;
                    ELSE
                        rf_status := rf.STATUS_UPC_NOT_UNIQUE;
                    END IF;
                END;
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
        o_detail_collection         out print_lp_result_obj
    ) return rf.STATUS
    IS
        rf_status                   rf.STATUS := rf.STATUS_NORMAL;

        l_result_table              print_lp_result_table;

    BEGIN
        -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

        l_result_table      := print_lp_result_table();
        l_result_table.EXTEND(1);

        l_result_table(1) :=
            print_lp_result_record (
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

        o_detail_collection := print_lp_result_obj(l_result_table);

        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            rf.LogException();  -- log it
            RAISE;              -- then throw up to next handler, if any
    END QueryByTest;


    /*----------------------------------------------------------------*/
    /* Function ValidateUpdate                                        */
    /*----------------------------------------------------------------*/

    FUNCTION ValidateUpdate
    (
        i_rf_log_init_record        in rf_log_init_record,
        i_location                  in inv.plogi_loc%TYPE,
        i_prod_id                   in inv.prod_id%TYPE,
        i_cust_pref_vendor          in inv.cust_pref_vendor%TYPE,
        i_case_qty                  in number,
        i_exp_date                  in varchar2,
        o_pallet_id                 out inv.logi_loc%TYPE
    ) RETURN rf.STATUS
    IS
        rf_status           rf.STATUS := rf.STATUS_NORMAL;
        l_skid_cube         pallet_type.skid_cube%TYPE;
        l_spc               pm.spc%TYPE;
        l_case_cube         pm.case_cube%TYPE;
        l_slot_type         loc.slot_type%TYPE;
        l_sys_msg_id        NUMBER;
        l_ret_val           NUMBER;
        l_msg_text          VARCHAR2(132);
        l_fname             VARCHAR2(50) := 'pl_rf_one_sided_adj';

        e_fail     EXCEPTION;   
    BEGIN

        pl_text_log.ins_msg ('I', 'pl_rf_one_sided_adj', 'BEGIN Function ValidateUpdate '||
                             'i_prod_id=['||i_prod_id||'] i_cust_pref_vendor =['||i_cust_pref_vendor||']',
                             NULL, NULL);

        o_pallet_id := ' ';

        rf_status := rf.Initialize(i_rf_log_init_record);
        IF rf_status = rf.STATUS_NORMAL THEN
            BEGIN
                SELECT NVL(p.skid_cube,0), l.slot_type
                  INTO l_skid_cube, l_slot_type
                  FROM pallet_type p, loc l
                 WHERE p.pallet_type(+) = l.pallet_type
                   AND l.logi_loc = i_location
                   AND l.perm = 'N';

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    rf_status := rf.STATUS_INV_LOCATION;
            END;
        END IF;

        IF rf_status = rf.STATUS_NORMAL THEN
            SELECT spc, case_cube
              INTO l_spc, l_case_cube
              FROM pm
             WHERE prod_id = i_prod_id
               AND cust_pref_vendor = i_cust_pref_vendor;

            o_pallet_id := pl_common.f_get_new_pallet_id();

            IF length(to_char(i_case_qty * l_spc)) > 7 THEN
                rf_status := rf.STATUS_QTY_TOO_LARGE;
                return rf_status;
            END IF;

            INSERT INTO inv (plogi_loc, logi_loc, prod_id, cust_pref_vendor, qoh, qty_alloc, 
                             qty_planned, min_qty, cube, inv_date, abc, status, inv_uom, exp_date)
            VALUES (i_location, o_pallet_id, i_prod_id, i_cust_pref_vendor, i_case_qty * l_spc,
                    0, 0, 0, (i_case_qty * l_case_cube) + l_skid_cube, SYSDATE, 'A', 'AVL', 0,
                    TO_DATE(i_exp_date,'MMDDYY'));

            IF NVL(i_case_qty,0) != 0 THEN
                INSERT INTO trans
                  (trans_id, trans_type, trans_date,
                   prod_id, cust_pref_vendor,
                   rec_id, src_loc, pallet_id,
                   qty_expected, qty, uom,
                   reason_code, user_id, upload_time,
                   mfg_date, exp_date,
                   old_status, warehouse_id)
                SELECT TRANS_ID_SEQ.NEXTVAL, 'ADJ', SYSDATE,
                  i_prod_id, i_cust_pref_vendor,
                  NULL, i_location, o_pallet_id,
                  0, i_case_qty * l_spc, 2,
                  'SW', USER, NULL, NULL, SYSDATE,
                  'AVL', '000'
                  FROM DUAL;
            END IF;

            COMMIT;

            IF l_slot_type = 'MXI' THEN
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;

                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                  i_interface_ref_doc => 'SYS03',
                                                                  i_label_type => 'LPN',
                                                                  i_parent_pallet_id => NULL,
                                                                  i_rec_ind => 'S',
                                                                  i_pallet_id => o_pallet_id,
                                                                  i_prod_id => i_prod_id,
                                                                  i_case_qty => i_case_qty,
                                                                  i_exp_date => TRUNC(SYSDATE),
                                                                  i_erm_id => NULL,
                                                                  i_batch_id => NULL,
                                                                  i_trans_type => 'XFR',
                                                                  i_task_id => NULL,
                                                                  i_inv_status => 'AVL'
                                                                 );              
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Unable to insert record (SYS03) into matrix_out for pallet_id ' || o_pallet_id;
                    RAISE e_fail;
                END IF;

                l_ret_val := pl_matrix_common.send_message_to_matrix (l_sys_msg_id);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Unable to send message (SYS03) to matrix for pallet_id ' || o_pallet_id;
                    RAISE e_fail;
                END IF;
            END IF;
        END IF;

        rf.Complete(rf_status);
        RETURN rf_status;

    EXCEPTION
        WHEN OTHERS THEN
            rf.LogException();  -- log it
            RAISE;              -- then throw up to next handler, if any
    END ValidateUpdate;

END pl_rf_one_sided_adj;
/
SHOW ERRORS;


ALTER PACKAGE swms.pl_rf_one_sided_adj compile plsql_code_type = native;

CREATE OR REPLACE PUBLIC SYNONYM pl_rf_one_sided_adj FOR swms.pl_rf_one_sided_adj;
GRANT EXECUTE ON swms.pl_rf_one_sided_adj to swms_user;
