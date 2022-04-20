CREATE OR REPLACE PACKAGE SWMS.pl_auto_route_close AS
/******************************************************************************
   NAME:       pl_auto_route_close
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        10/27/2015	mdev3739		1. Created this package.
   2.0		  12/31/2015	mdev3739		2. 6000010239	SWMS Exception email alert
   3.0		  03/09/2016	spot3255		3. removed PRAGMA AUTONOMOUS_TRANSACTION,COMMIT 
											from procedure: p_pre_validation
   4.0        06/02/2017	jluo6971   CRQ000000031681 - Fixed route still
					   close even if there is weight not
					   collected yet (especially for
					   bulk/combine pull).
   5.0        07/24/2017	jluo6971   CRQ000000034260 - Fixed cursor
					   pac_ord to match what route close
					   from CRT does.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    10/07/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3710_Site_2_Do_not_send_PAC_to_SUS
--
--                      Change cursor pac_ordd to exclude 'X' cross dock type.
--
******************************************************************************/
  
  PROCEDURE p_pre_validation
 ( i_route_no IN varchar2 );
  
  PROCEDURE p_clam_pab_check(i_route_no IN varchar2,o_status OUT NUMBER);
  
  PROCEDURE p_check_for_clambed_no(i_clam_bed_tracked_syspar In varchar2,i_route_no IN varchar2,o_status OUT NUMBER);
  
  PROCEDURE p_create_PAB_transactions(i_route_no IN varchar2);
  PROCEDURE p_use_avg_cw(i_route_no IN varchar2,o_status OUT NUMBER);
  PROCEDURE p_truck_close(i_route_no IN varchar2,o_status OUT NUMBER);
  PROCEDURE p_ins_cc_wh_out(i_route_no IN varchar2,o_status OUT NUMBER);
  PROCEDURE p_del_process(i_route_no IN varchar2,o_status OUT NUMBER);
  PROCEDURE p_upd_cc_if_exists(i_route_no IN varchar2);
  PROCEDURE p_close_get_meat_route(i_route_no route.route_no%TYPE);
  v_global_need_clam varchar2(1 byte);
  v_global_sap_company varchar2(10 byte) := 'AS400';
 
END pl_auto_route_close;
/
CREATE OR REPLACE PACKAGE BODY SWMS.pl_auto_route_close AS
/******************************************************************************
   NAME:       pl_auto_route_close
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        10/27/2015      mdev3739       1. Created this package body.
******************************************************************************/
 
PROCEDURE p_pre_validation  (i_route_no IN VARCHAR2) IS

CURSOR c_get_whout_cool IS
    SELECT d.route_no, d.order_id, d.order_line_id, qty_ordered, uom,
           NVL(wh_out_qty, 0) wh_out_qty,
           d.prod_id, p.spc,
           DECODE(uom, 1, qty_ordered - NVL(wh_out_qty,0),
                       (qty_ordered - NVL(wh_out_qty, 0)) / p.spc) ship_qty,
           COUNT(DECODE(country_of_origin || wild_farm,
                        NULL, 1,
                        DECODE(country_of_origin, NULL, 1,
                                                  DECODE(wild_farm, NULL, 1, NULL)))) cool_qty
    FROM ordd d, pm p, v_ord_cool_batch v
    WHERE d.prod_id = p.prod_id
    AND   d.route_no = i_route_no
    AND   d.route_no = v.route_no
    AND   d.order_id = v.order_id
    AND   d.order_line_id = v.order_line_id
    AND   NVL(d.wh_out_qty, 0) <> 0
    AND   d.deleted IS NULL
    GROUP BY d.route_no, d.order_id, d.order_line_id, qty_ordered, uom, wh_out_qty,
             d.prod_id, p.spc,
             DECODE(uom, 1, qty_ordered - NVL(wh_out_qty, 0),
                         (qty_ordered - NVL(wh_out_qty, 0)) / p.spc);
                         
v_exists    VARCHAR(1) := NULL;
v_stat     VARCHAR(1); 
e_return_value EXCEPTION; 
v_status NUMBER;
v_route_status route.status%TYPE;
/*PRAGMA AUTONOMOUS_TRANSACTION; */
BEGIN
        
    BEGIN
    
        SELECT status INTO v_route_status FROM ROUTE 
                                          WHERE route_no = i_route_no;
                                          
         IF v_route_status ='CLS' THEN
         
         Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'Route has been closed already', NULL, NULL);
         
          pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no||',Route has been closed already.' ); 
         
         RETURN;
         
         END IF;
         
                      
    END;
    /* check_route_add_on- Start */
     BEGIN
       IF INSTR(i_route_no,' ') != 0 THEN -- It is a cling-on
       
        Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'It is a cling on route', NULL, NULL);  
        
        pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no||',It is a cling on route.' );    
        
        RAISE e_return_value; 
        
       END IF;
       --
       SELECT NULL
       INTO   v_stat
       FROM   ROUTE
       WHERE  ROUTE_NO LIKE i_route_no || ' %'
       AND    ROUTE_NO != i_route_no
       AND    STATUS   != 'CLS'
       ;
       RAISE TOO_MANY_ROWS;
           
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          NULL;
       WHEN TOO_MANY_ROWS THEN
           
            Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'Add-on routes should be closed first', SQLCODE, SQLERRM);
                    
            pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no||',Add-on routes should be closed first.' );  
            --raise_application_error(-20101, 'Add-on routes should be closed first');
            RAISE e_return_value;   
       WHEN OTHERS THEN
          Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'Add-on routes should be closed first-When Others clause', SQLCODE, SQLERRM);
          --raise_application_error(-20102, 'Add-on routes should be closed first-When Others clause');
          
          pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no||',Add-on routes should be closed first-When Others clause,'|| SQLCODE ||'-'|| SQLERRM );  
          RAISE e_return_value;     
      END;
    /* check_route_add_on- End */
    
    /* Check for check_for_cool_data - Start */
    BEGIN
        SELECT '1' INTO v_exists
        FROM ord_cool c, route r, ordm m, ordd d
        WHERE r.route_no = m.route_no
        AND   r.route_no LIKE i_route_no || '%'
        AND   r.route_no = m.route_no
        AND   c.order_id = m.order_id
        AND   ((c.country_of_origin IS NULL) OR (c.wild_farm IS NULL))
        AND   r.route_no = d.route_no
        AND   m.order_id = d.order_id
        AND   d.order_id = c.order_id
        AND   d.order_line_id = c.order_line_id
        AND   NVL(d.wh_out_qty, 0) = 0
        AND   d.deleted IS NULL
        AND   ROWNUM = 1;

         Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'COOL data needs to be collected. Route cannot be closed', NULL, NULL);
         
         pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no|| ',COOL data needs to be collected. Route cannot be closed.' ); 
         --raise_application_error(-20103, 'COOL data needs to be collected. Route cannot be closed');

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          
         Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'COOL data needs to be collected. Route cannot be closed- When others Clause', SQLCODE, SQLERRM);
         -- raise_application_error(-20104, 'COOL data needs to be collected. Route cannot be closed- When others Clause');
         pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no|| ',COOL data needs to be collected. Route cannot be closed- When others Clause.' || SQLCODE ||'-'|| SQLERRM ); 
         RAISE e_return_value; 
      END;
      
      
      FOR c1 IN c_get_whout_cool LOOP
        IF c1.cool_qty > c1.wh_out_qty THEN
           Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'COOL data needs to be collected. Route cannot be closed', NULL, NULL);
           
           pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION',
                                'route_no-'||i_route_no|| ',COOL data needs to be collected. Route cannot be closed.' ); 
          --raise_application_error(-20105, 'COOL data needs to be collected. Route cannot be closed');
          RAISE e_return_value; 
        END IF;
      END LOOP;
 
 /* Check for check_for_cool_data - End */
 
    BEGIN
    
    SELECT config_flag_val 
     INTO v_global_sap_company
     FROM sys_config
        WHERE config_flag_name = 'HOST_TYPE';           
   
    EXCEPTION 
        WHEN OTHERS THEN
               --MESSAGE( STRING_TRANSLATION.GET_STRING(3942));
                Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'Cannot retrieve type of company', SQLCODE, SQLERRM);
               v_global_sap_company := 'AS400';
              
                  
    END;

p_clam_pab_check(i_route_no,v_status);

   
IF v_status > 0 THEN

RAISE e_return_value;

END IF;

-- if everything sucess then doing commit
/*COMMIT;*/

EXCEPTION

WHEN e_return_value THEN
-- If any error on any of programs then doing the rollback
ROLLBACK;
Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_PRE_VALIDATION', 'Entire Auto route close Failed. Please check swms_log table further', NULL, NULL);

update ROUTE
   set   AUTO_CLOSE_STATUS = 'E'
   where  ROUTE_NO = i_route_no;
COMMIT;


END p_pre_validation;

PROCEDURE p_clam_pab_check  (i_route_no IN VARCHAR2,o_status OUT NUMBER ) IS

v_clam VARCHAR2(1);
v_ordcw_count NUMBER;     /* Charm 6000003694 Changes */
v_ct_wt_count NUMBER;     /* Charm 6000003694 Changes */
v_wh_out_qty_tot NUMBER;  /* Charm 6000003694 Changes */
v_status NUMBER;

begin
  begin
    pl_log.ins_msg ('INFO', 'p_clam_pab_check', 'Starting p_clam_pab_check. Route[' || i_route_no || ']',
        SQLCODE, SQLERRM, 'AUTO ROUTE CLOSE', 'pl_auto_route_close');
    --:global.clam_sys:='N';

    select config_flag_val into v_clam
    from sys_config
    where config_flag_name='CLAM_BED_TRACKED';

    if v_clam='Y' then
      p_check_for_clambed_no(v_clam,i_route_no,v_status);
      -- :global.clam_sys:='Y';
      IF v_status > 0 THEN
        o_status := 1;
        RETURN;
      END IF;
                
    end if;
  exception when no_data_found then
    v_clam:='N';
  end;
       
     
  if v_clam='Y' and v_global_need_clam='N' then
    p_create_PAB_transactions(i_route_no);
           
    IF v_status > 0 THEN

      o_status := 1;
      RETURN;

    END IF;
  end if;

  if v_global_need_clam='Y' then
    -- pl_log.ins_msg( 'FATAL', 'p_pre_validation','Cannot close route %s1.  One or more items need clam bed information collected.', SQLCODE,  SQLERRM, 'O', 'PL_AUTO_ROUTE_CLOSE' );                                                             ;
    Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_CLAM_PAB_CHECK',  'Cannot close route %s1.  One or more items need clam bed information collected', NULL, NULL);
           
    pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_CLAM_PAB_CHECK',
                              'route_no-'||i_route_no|| ',Cannot close route %s1.  One or more items need clam bed information collected.' ); 
    o_status := 1;
    RETURN;
    -- raise_application_error(-20106, 'Cannot close route %s1.  One or more items need clam bed information collected');
  end if;

  --
  -- If this route is a raw material route, then skip this catchweight logic. JIRA 707
  --
  IF pl_common.f_is_raw_material_route(i_route_no) = 'Y' THEN
    pl_log.ins_msg ('INFO', 'p_clam_pab_check', 'Route [' || i_route_no || '] is a raw material route, skipping procedure p_use_avg_cw',
        SQLCODE, SQLERRM, 'AUTO ROUTE CLOSE', 'pl_auto_route_close');
  ELSE
      /* Charm 6000003694 Changes */
      select count(cw.order_id), count(cw.catch_weight) 
        into v_ordcw_count, v_ct_wt_count
        from ordcw cw, ordd d
        where cw.ORDER_ID = d.ORDER_ID
        and  cw.ORDER_LINE_ID = d.ORDER_LINE_ID
        and  cw.prod_id = d.prod_id
        and d.ROUTE_NO = i_route_no
        and  d.CW_TYPE IS NOT NULL
        and  nvl(d.DELETED,' ') NOT IN ('PAD', 'PAL')
        and  nvl(d.STATUS,' ') IN ('OPN', 'SHT')
        and  cw.CW_TYPE IS NOT NULL;

      select sum(wh_out_qty)
        into v_wh_out_qty_tot
        from ordd 
        where nvl(STATUS,' ') IN ('OPN', 'SHT') 
        and cw_type IS NOT NULL 
        and wh_out_qty is not null 
        and route_no = i_route_no;
        
      /* CRQ000000031681 NVL the values since they can be NULL to compare */ 
      /* Again */
      IF NVL(v_ordcw_count, 0) != NVL(v_ct_wt_count, 0) + NVL(v_wh_out_qty_tot, 0) then
        -- MESSAGE('Cannot close route.Catchweights entered for ware house out items, Delete catch weights for that Items.');
        --BELL;
              
        Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_CLAM_PAB_CHECK',  'Cannot close route.Catchweights entered for ware house out items, Delete catch weights for that Items.', NULL, NULL);
              
        pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_CLAM_PAB_CHECK',
                                    'route_no-'||i_route_no||  ',Cannot close route.Catchweights entered for ware house out items, Delete catch weights for that Items.' );
        o_status := 1;
        RETURN;
              
              
      END IF;

      /* Charm 6000003694 Changes ends */

      /* CRQ000000031681 Move the average-out weight action here and also
        the truck close action here so in case there is weight to be 
        collected from above, we stop creating all transactions and not
        close the route. In this case the average-out weight will never be
        performed. */ 
      p_use_avg_cw(i_route_no,v_status);

      IF v_status > 0 THEN
        o_status := 1;
        RETURN;
      END IF;

  END IF;-- end if f_is_raw_material_route
        
  p_truck_close(i_route_no,v_status);

  IF v_status > 0 THEN
     o_status := 1;
     RETURN;
  END IF;
 o_status := 0;

EXCEPTION
   WHEN OTHERS THEN
   
   o_status := 1;
   
   Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_CLAM_PAB_CHECK','error is', SQLCODE, SQLERRM);
   
   pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_CLAM_PAB_CHECK',
                                'route_no-'||i_route_no||  ',error is'|| SQLCODE||'-'|| SQLERRM );
     
end p_clam_pab_check;

PROCEDURE p_check_for_clambed_no(i_clam_bed_tracked_syspar  IN  VARCHAR2,i_route_no IN VARCHAR2,o_status OUT NUMBER)
IS
   --
   -- This cursor looks for clam bed data that has not been collected for the route.
   --
   CURSOR c_missing_clam_bed_data
             (cp_clam_bed_tracked_syspar IN VARCHAR2)
   IS
      SELECT 'Y'
        FROM ordm a, ordd b, pm c, ordcb d
       WHERE a.order_id      = b.order_id
         AND a.order_id      = d.order_id
         AND b.order_line_id = d.order_line_id
         AND b.prod_id       = d.prod_id
         AND b.prod_id       = c.prod_id
         AND pl_common.f_is_clam_bed_tracked_item(c.category, i_clam_bed_tracked_syspar) = 'Y'
         AND a.route_no      = i_route_no
         AND (   d.clam_bed_no  IS NULL
              OR d.harvest_date IS NULL);

   l_need_clam VARCHAR2(1);
BEGIN
   --
   -- i_clam_bed_tracked_syspar needs to be Y or N. If not then
   -- display an error and raise an exception.
   -- The calling object needs to have populated it.
   --
   IF (NVL(i_clam_bed_tracked_syspar, 'x') NOT IN ('Y', 'N')) THEN
     -- MESSAGE( STRING_TRANSLATION.GET_STRING(5546 ,i_clam_bed_tracked_syspar));
    --  raise_application_error(-20109, 'check_for_clambed_no: ERROR  Value for i_clam_bed_tracked_syspar not Y or N.'); 
       Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_CLAM_FOR_CLAMBED_NO','check_for_clambed_no: ERROR  Value for i_clam_bed_tracked_syspar not Y or N.', NULL, NULL);
       
       pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_CLAM_FOR_CLAMBED_NO',
                                'route_no-'||i_route_no||  ',check_for_clambed_no: ERROR  Value for i_clam_bed_tracked_syspar not Y or N.' );
       o_status := 1;
       RETURN;
   END IF;
       
   v_global_need_clam := 'N';

   OPEN c_missing_clam_bed_data(i_clam_bed_tracked_syspar);
   FETCH c_missing_clam_bed_data INTO l_need_clam;
   IF (c_missing_clam_bed_data%NOTFOUND) THEN
      l_need_clam := 'N';
   END IF;
   CLOSE c_missing_clam_bed_data;

   IF (l_need_clam = 'Y') THEN
       v_global_need_clam := 'Y';
      -- MESSAGE( STRING_TRANSLATION.GET_STRING(5538 ,i_route_no))                                                              ;
       Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_CLAM_FOR_CLAMBED_NO','Cannot close route'|| i_route_no||'One or more items need clam bed information collected.', NULL, NULL);
       --raise_application_error(-20110, 'Cannot close route'|| i_route_no||'One or more items need clam bed information collected.');
       pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_CLAM_FOR_CLAMBED_NO',
                                'route_no-'||i_route_no|| ',Cannot close route.One or more items need clam bed information collected.' );
       o_status := 1;
       RETURN; 
   END IF;
   
 o_status := 0;
EXCEPTION
       
   WHEN OTHERS THEN
     -- MESSAGE( STRING_TRANSLATION.GET_STRING(5547 ,:SYSTEM.CURRENT_FORM));
      --MESSAGE(SQLERRM);
      Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_CLAM_FOR_CLAMBED_NO','check_for_clambed_no: ERROR', SQLCODE, SQLERRM);
     -- raise_application_error(-20111, '%s1 check_for_clambed_no: ERROR');
     
     pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_CLAM_FOR_CLAMBED_NO',
                                'route_no-'||i_route_no|| ',check_for_clambed_no: ERROR'|| SQLCODE ||'-'|| SQLERRM );
     o_status := 1;
     
END p_check_for_clambed_no;

PROCEDURE p_create_PAB_transactions(i_route_no In varchar2 ) IS
v_order_id           ordcb.order_id%TYPE;
v_order_line_id      ordcb.order_line_id%TYPE;
v_prod_id            ordcb.prod_id%TYPE;
v_cust_pref_vendor   ordcb.cust_pref_vendor%TYPE;
v_clam_bed_no        ordcb.clam_bed_no%TYPE;
v_harvest_date       ordcb.harvest_date%TYPE;
-- 11/01/10 - ykri0358 - CR 4051 Added sys_order_id adn sys_order_line_id for SCI016
v_sys_order_id           ordd.sys_order_id%TYPE;
v_sys_order_line_id      ordd.sys_order_line_id%TYPE;
v_pab                VARCHAR2(1);
-- 03/18/10 - gsaj0457 - 12554:Added for 212 Legacy Enhancements - SCE042 - Begin 
    --Increased the field size of v_cust_id from 6 to 10.
v_cust_id         VARCHAR2(10);  -- DN#10338 prplhj Added
-- 03/18/10 - gsaj0457 - 12554:Added for 212 Legacy Enhancements - SCE042 - End 
v_qty             NUMBER(7,2);  -- DN#10338 prplhj Added
v_uom             NUMBER(2);    -- DN#10338 prplhj Added
cursor C1 is
select b.order_id,b.order_line_id,
b.prod_id,b.cust_pref_vendor,b.clam_bed_no,b.harvest_date, a.cust_id
from ordcb b, ordm a where
a.order_id=b.order_id and
a.route_no=i_route_no;
-- DN#10338 prplhj: Added cursor for qty and uom
CURSOR c2 IS
   SELECT qty_ordered, uom
      FROM ordm m, ordd d
      WHERE m.order_id = v_order_id
      AND   m.order_id = d.order_id
      AND   m.route_no = d.route_no
      AND   m.stop_no = d.stop_no
      AND   d.order_line_id = v_order_line_id
      AND   d.prod_id = v_prod_id
      AND   d.cust_pref_vendor = v_cust_pref_vendor;
begin
     OPEN C1;
     LOOP
         FETCH C1 INTO v_order_id,v_order_line_id,
                       v_prod_id,v_cust_pref_vendor,
                       v_clam_bed_no,v_harvest_date, v_cust_id;
         EXIT WHEN C1%NOTFOUND;
         -- DN#10338 prplhj: Get qty and uom
         OPEN c2;
         FETCH c2 INTO v_qty, v_uom;
         IF c2%NOTFOUND THEN
            v_qty := 0;
            v_uom := 0;
         END IF;
         CLOSE c2;
         --- 11/01/10 - ykri0358 - CR 4051 Added sys_order_id and sys_order_line_id for SCI016
           SELECT sys_order_id, sys_order_line_id
           INTO v_sys_order_id, v_sys_order_line_id
      FROM ordd d
      WHERE d.order_id = v_order_id
      AND   d.order_line_id = v_order_line_id
      AND   d.prod_id = v_prod_id
      AND   d.cust_pref_vendor = v_cust_pref_vendor;
         -- DN#10338 prplhj: Added qty, uom, lot_id (cust_id)
         INSERT INTO TRANS (TRANS_ID,
                            TRANS_TYPE,
                            TRANS_DATE,
                            ORDER_LINE_ID,
                            ORDER_ID,
                            PROD_ID,
                            CUST_PREF_VENDOR,
                            QTY,
                            UOM,
                            LOT_ID,
                            USER_ID,
                            ROUTE_NO,
                            CLAM_BED_NO,
                            EXP_DATE,
                            UPLOAD_TIME,
                            CMT,SYS_ORDER_ID, SYS_ORDER_LINE_ID)
                     VALUES(TRANS_ID_SEQ.NEXTVAL,
                            'PAB',
                             SYSDATE,
                             V_ORDER_LINE_ID,
                          V_ORDER_ID||'L'||LPAD(TO_CHAR
(V_ORDER_LINE_ID),3,'0'),
                             V_PROD_ID,
                             V_CUST_PREF_VENDOR,
                             v_qty,
                             v_uom,
                             v_cust_id,
                             USER,
                             i_route_no,
                             V_CLAM_BED_NO,
                             V_HARVEST_DATE,
                            to_date('01-JAN-1980','DD-MON-YYYY'),
 'Created by paecb.inp-entry form for clam bed no',v_sys_order_id, v_sys_order_line_id);
       END LOOP;
       CLOSE C1;
END p_create_PAB_transactions;
PROCEDURE p_use_avg_cw (i_route_no IN VARCHAR2,o_status OUT NUMBER ) IS
-- DN#4888:acpjjs:AVG_WT should be made to CASES for UOM=0.
--
   CURSOR c_avgcw IS
      select c.ORDER_ID, c.ORDER_LINE_ID,
             d.PROD_ID,  d.CUST_PREF_VENDOR, d.UOM,
             count(*) - nvl(d.WH_OUT_QTY, 0) CNT
      from   ORDCW c, ORDD d
      where  c.ORDER_ID      = d.ORDER_ID
        and  c.ORDER_LINE_ID = d.ORDER_LINE_ID
        and  d.ROUTE_NO = i_route_no
        and  nvl(d.DELETED,' ') NOT IN ('PAD', 'PAL')
        and  nvl(d.STATUS,' ') IN ('OPN', 'SHT')
        and  d.CW_TYPE IS NOT NULL
        and  c.catch_weight IS NULL
      group  by
             c.ORDER_ID, c.ORDER_LINE_ID,
             d.PROD_ID,  d.CUST_PREF_VENDOR, d.UOM,
             nvl(d.WH_OUT_QTY, 0)
      having count(*) > nvl(WH_OUT_QTY, 0);
   --
   avgcw_count NUMBER(10);
   total_count NUMBER(10) := 0;
   --
   CURSOR c_cwtype(orderid VARCHAR2, line_id number) IS
      select sum(decode(CW_TYPE, 'A' ,1, 0) ) ACTUAL,
             sum(decode(CW_TYPE, 'M' ,1, 0) ) MEAN
      from   ORDCW
      where  ORDER_ID = orderid
        and  ORDER_LINE_ID = line_id
        and  CW_TYPE IS NOT NULL;
   --
   cwtype     c_cwtype%ROWTYPE;
   --
   avg_type   VARCHAR2(1);
   avg_weight NUMBER;
BEGIN
   FOR avgcw IN c_avgcw
   LOOP
      select nvl(AVG_WT, 0) * DECODE(avgcw.UOM, 1,1, nvl(SPC,1))
      into   avg_weight
      from   PM
      where  PROD_ID          = avgcw.PROD_ID
        and  CUST_PREF_VENDOR = avgcw.CUST_PREF_VENDOR;
      IF nvl(avg_weight, 0) = 0 THEN
         -- ('Average weight is 0 or NULL. Contact Administrator.');
        -- MESSAGE( STRING_TRANSLATION.GET_STRING(5562))                 ;
         --BELL;
         
         Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW','Average weight is 0 or NULL. Contact administrator', NULL, NULL);
         
           
        -- raise_application_error(-20111, 'Average weight is 0 or NULL. Contact administrator.'); 
      END IF;
      --
      update ORDCW c
      set    c.CW_TYPE = 'M',
             c.CATCH_WEIGHT = avg_weight
      where  c.ORDER_ID      = avgcw.ORDER_ID
        and  c.ORDER_LINE_ID = avgcw.ORDER_LINE_ID
        and  c.catch_weight IS NULL
        and  rownum <= avgcw.CNT;
      --
      IF sql%ROWCOUNT != avgcw.CNT THEN
         --MESSAGE( STRING_TRANSLATION.GET_STRING(5563 ,avgcw.ORDER_ID ,to_char(avgcw.ORDER_LINE_ID)));
         --BELL; 
         Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW','Error: Update AVG-CW failed. Order:'||avgcw.ORDER_ID||','||to_char(avgcw.ORDER_LINE_ID), NULL, NULL);
         --raise_application_error(-20112, 'Error: Update AVG-CW failed. Order:%s1/%s2'); 
         
         pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW',
                                'route_no-'||i_route_no|| ',Error: Update AVG-CW failed. Order:'||avgcw.ORDER_ID||','||to_char(avgcw.ORDER_LINE_ID));
         o_status := 1;
         RETURN;
      END IF;
      --
      total_count := total_count + sql%ROWCOUNT;
      OPEN c_cwtype(avgcw.ORDER_ID, avgcw.ORDER_LINE_ID);
      FETCH c_cwtype INTO cwtype;
      CLOSE c_cwtype;
      --
      IF cwtype.ACTUAL > 0 THEN
         IF cwtype.MEAN > 0 THEN
            avg_type := 'C';
         ELSE
            avg_type := 'A';
         END IF;
      ELSE
         IF cwtype.MEAN > 0 THEN
            avg_type := 'M';
         ELSE
            avg_type := 'I';
         END IF;
      END IF;
      --
      -- update ORDD
      -- set    CW_TYPE = avg_type
      -- where  ORDER_ID = avgcw.ORDER_ID
      --  and  ORDER_LINE_ID = avgcw.ORDER_LINE_ID;
      --
      IF sql%NOTFOUND THEN
        -- MESSAGE( STRING_TRANSLATION.GET_STRING(5564 ,avgcw.ORDER_ID ,to_char(avgcw.ORDER_LINE_ID)));
         --BELL;
         Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW','Error: Update ORDER DETAILS failed. Order:'||avgcw.ORDER_ID||','||to_char(avgcw.ORDER_LINE_ID), NULL, NULL);
         
          pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW',
                                'route_no-'||i_route_no|| ',Error: Update AVG-CW failed. Order:'||avgcw.ORDER_ID||','||to_char(avgcw.ORDER_LINE_ID));
        -- raise_application_error(-20112, 'Error: Update ORDER DETAILS failed. Order:%s1/%s2');
        o_status := 1;
       RETURN;
      END IF;
      --
   END LOOP;
   
o_status := 0;  
  
EXCEPTION
    WHEN OTHERS THEN
      --MESSAGE( STRING_TRANSLATION.GET_STRING(3701 ,to_char(ERROR_CODE) ,SQLERRM));
      --BELL;
       Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW','Error:', SQLCODE, SQLERRM);
       
       pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_USE_AVG_CW',
                                'route_no-'||i_route_no||',Error is' ||SQLCODE||'-'||SQLERRM);
      --raise_application_error(-20113, 'Error:'||SQLCODE||'-'||SQLERRM);
      o_status := 1;
END p_use_avg_cw;

--
-- 10/07/21 Brian Bent
-- Changed to exclude 'X' cross dock type. PAC do not go up to SUS at Site 2.
--
PROCEDURE p_truck_close(i_route_no IN VARCHAR2,o_status OUT NUMBER ) IS
   CURSOR pac_ordd IS
     SELECT d.prod_id,
       d.cust_pref_vendor,
       d.sys_order_id,
       d.sys_order_line_id,
       d.order_id,
       d.order_line_id,
       d.reason_cd,
       d.cw_type,
       d.uom,
       SUM(NVL(d.qty_alloc,0)) qty_alloc,
       SUM(NVL(d.qty_alloc,0) -
	DECODE(d.uom, 1, NVL(d.wh_out_qty, 0),
		NVL(d.wh_out_qty * p.spc,0))) qty_shipped,
       SUM(NVL(d.qty_alloc,0)/decode(d.uom,1,1,p.spc)) qalc_cs
  FROM pm p,
       ordd d,
       ordm m
 WHERE d.route_no          = i_route_no
   AND m.order_id          = d.order_id
   AND NVL(m.cross_dock_type, 'xxx') <> 'X'
   AND p.prod_id           = d.prod_id
   AND p.cust_pref_vendor  = d.cust_pref_vendor
   AND d.cw_type           IS NOT NULL
   AND NVL(d.status,' ')   IN ('OPN', 'SHT')
   AND NVL(d.deleted,' ')  NOT IN ('PAD', 'PAL')
   AND NVL(d.qty_alloc, 0) - 
	DECODE(d.uom, 1, NVL(d.wh_out_qty, 0),
		NVL(d.wh_out_qty * p.spc, 0) ) > 0
   AND EXISTS  
         (SELECT 'x'
            FROM float_detail fd,
                 floats f
           WHERE f.route_no          = d.route_no
             AND f.float_no          = fd.float_no
             AND f.route_no          = d.route_no
             AND fd.order_id         = d.order_id
             AND fd.order_line_id    = d.order_line_id
             AND fd.prod_id          = d.prod_id
             AND fd.cust_pref_vendor = d.cust_pref_vendor
             AND fd.merge_alloc_flag <> 'M' 
             AND fd.uom              = d.uom  -- New to the join
             AND f.pallet_pull       <> 'R')
   GROUP BY d.prod_id,
          d.cust_pref_vendor,
          d.sys_order_id,
          d.sys_order_line_id,
          d.order_id,
          d.order_line_id,
          d.reason_cd,
          d.cw_type,
          d.uom
   ORDER BY d.prod_id;
   CURSOR c_send_pam IS
    SELECT d.route_no, v.order_id, v.order_line_id, d.qty_ordered, d.uom,
           DECODE(d.uom, 1, NVL(d.wh_out_qty, 0),
                  NVL(d.wh_out_qty, 0) * p.spc) wh_out_qty2,
           d.prod_id, d.cust_pref_vendor, p.spc,
           d.sys_order_id, d.sys_order_line_id,
           v.country_of_origin, v.wild_farm, v.seq_no,
           DECODE(d.uom, 1, d.qty_ordered - NVL(d.wh_out_qty,0),
                       (d.qty_ordered / p.spc) - NVL(d.wh_out_qty, 0)) ship_qty,
           COUNT(v.seq_no) cool_qty,
           d.deleted
    FROM ordd d, pm p, v_ord_cool_batch v
    WHERE d.prod_id = p.prod_id
    AND   d.route_no = i_route_no
    AND   d.route_no = v.route_no
    AND   d.order_id = v.order_id
    AND   d.order_line_id = v.order_line_id
    AND   v.country_of_origin IS NOT NULL
    AND   v.wild_farm IS NOT NULL
    AND   d.deleted IS NULL
    GROUP BY d.route_no, v.order_id, v.order_line_id, d.qty_ordered, d.uom,
             DECODE(d.uom, 1, NVL(d.wh_out_qty, 0),
                    NVL(d.wh_out_qty, 0) * p.spc),
             d.prod_id, d.cust_pref_vendor, p.spc,
             d.sys_order_id, d.sys_order_line_id,
             v.country_of_origin, v.wild_farm, v.seq_no,
             DECODE(d.uom, 1, d.qty_ordered - NVL(d.wh_out_qty, 0),
                         (d.qty_ordered / p.spc) - NVL(d.wh_out_qty, 0)),
             d.deleted
    ORDER BY v.order_id, v.order_line_id, v.seq_no;
   upl_time date    ;
   pac_count NUMBER(10);
   total_cw  NUMBER(12,3);
   t_uom     NUMBER(2);
   iPamIdx    NUMBER := 0;
   iInsNeeded    NUMBER := 0;
   szOldOid    ordd.order_id%TYPE := NULL;
   iOldOLnID    ordd.order_line_id%TYPE := NULL;
   szOldProd    ordd.prod_id%TYPE := NULL;
   szOldCpv    ordd.cust_pref_vendor%TYPE := NULL;
   v_total_wo  ordd.WH_OUT_QTY%TYPE;
	/* CRQ000000031681 Don't restrict number width */
   v_count_wo   number;
   v_count_cw_reqd number;
   v_count_cw_ordd number;
   v_status NUMBER;

   l_ordm_xdock_type    ordm.cross_dock_type%TYPE;
   l_floats_xdock_type  floats.cross_dock_type%TYPE;
BEGIN
--
-- For each line item deleteions(PAL) and for each Warehouse items(PAW)
-- one record is inserted into TRANS.
-- DN#4577:acpjjs:Added UOM for PAW trans.
-- Insert into float_hist_errors with reason code='WO':error tracking
  pl_log.ins_msg ('INFO', 'p_truck_close', 'Starting p_truck_close for route [' || i_route_no || '].',
        SQLCODE, SQLERRM, 'ROUTE CLOSE', 'pl_auto_route_close');

select sum(nvl(d.WH_OUT_QTY,0)),
       sum(decode(d.WH_OUT_QTY, NULL,0, 0,0, 1) ),
       sum(decode(d.CW_TYPE, NULL,0,
                  (decode(d.UOM, 0,
                   nvl(d.QTY_ALLOC,0)/decode(p.SPC, NULL,1,0,1, p.SPC),
                   nvl(d.QTY_ALLOC,0) )
                   - nvl(d.WH_OUT_QTY,0)) )),
       sum(decode(d.CW_TYPE, NULL,0,
                  decode(d.QTY_ALLOC,NULL,0,0,0,
                         decode(d.UOM,0,nvl(d.WH_OUT_QTY,0)*nvl(p.SPC,0),
                                d.WH_OUT_QTY),0,
                         1)  ))
       into   v_total_wo,
              v_count_wo,
              v_count_cw_reqd,
              v_count_cw_ordd
       from   PM p, ORDD d
       where  p.PROD_ID = d.PROD_ID
       and  p.CUST_PREF_VENDOR = d.CUST_PREF_VENDOR
       and  nvl(d.DELETED,' ') NOT IN ('PAD', 'PAL')
       and  nvl(d.STATUS,' ') IN ('OPN', 'SHT')
       and  d.ROUTE_NO = i_route_no;
       
   insert into TRANS
   (      TRANS_ID,     TRANS_TYPE,
          TRANS_DATE,   USER_ID,
          UPLOAD_TIME,  ROUTE_NO,
          PROD_ID,      CUST_PREF_VENDOR,
          SYS_ORDER_ID, SYS_ORDER_LINE_ID,
          ORDER_ID,     ORDER_LINE_ID,
          REASON_CODE,  QTY,   UOM  )
   select TRANS_ID_SEQ.nextval, 'PAW',
          sysdate,      user,
          TO_DATE('01-JAN-1980','DD-MON-YYYY'),  i_route_no,
          PROD_ID,      CUST_PREF_VENDOR,
          SYS_ORDER_ID, SYS_ORDER_LINE_ID,
          ORDER_ID,     ORDER_LINE_ID,
          REASON_CD,
          WH_OUT_QTY,   decode(UOM,2,0,uom)
   from   ORDD
   where  ROUTE_NO = i_route_no
   and    nvl(WH_OUT_QTY,0) > 0
   and    nvl(DELETED, ' ') NOT IN ('PAL','PAD')
   ;
   
   DBMS_OUTPUT.PUT_LINE('Starting 0');
   
   IF sql%ROWCOUNT != v_count_wo THEN
     -- MESSAGE( STRING_TRANSLATION.GET_STRING(5557 ,to_char(sql%ROWCOUNT)));
     -- raise_application_error(-20114, 'Error: Insert TRANS failed. Type PAW. Count:'||to_char(sql%ROWCOUNT));
      Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE','Error: Insert TRANS failed. Type PAW. Count:'||to_char(sql%ROWCOUNT), NULL, NULL);
      
      pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE',
                               'route_no-'||i_route_no||',Error: Insert TRANS failed. Type PAW. Count:'||to_char(sql%ROWCOUNT));
      o_status := 1;
      RETURN;
   END IF;
   begin
     INSERT INTO float_hist_errors(prod_id,cust_pref_vendor,order_id,order_line_id,
                                   reason_code,ret_qty,ret_uom)
                SELECT prod_id,cust_pref_vendor,order_id, order_line_id,
                       'WO', sum(nvl(wh_out_qty,0)), uom
                FROM ordd
                WHERE route_no=i_route_no
                AND wh_out_qty is not null
                AND nvl(deleted,' ') not in ('PAL','PAD')
                group by prod_id,cust_pref_vendor,order_id,uom,order_line_id;
  exception when dup_val_on_index  then
        --MESSAGE( STRING_TRANSLATION.GET_STRING(5558))  ;
        --null;
        Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE', 'Insert into float_hist_errors failed', SQLCODE, SQLERRM);
        
  end;
--
-- For each warehouse out write cycle count request records one
-- for each slot in the warehouse that contains this the product.
-- DN#5079:acpjjs:CC is based on SYSCONFIG flag. Added new procedure
--

DBMS_OUTPUT.PUT_LINE('Starting 1');
   p_ins_cc_wh_out(i_route_no,v_status);
   
 DBMS_OUTPUT.PUT_LINE('Starting 2');
   
   
 IF v_status > 0 THEN
     o_status := 1;
     RETURN;
  END IF;
--
-- For each line items having catch weights (PAC) one record is
-- inserted into TRANS.
-- DN#5026:acpjjs:added UOM for PAC records.
-- DN#5496:acpjjs:WH_OUT_QTY is checked after converting to splits.
--

DBMS_OUTPUT.PUT_LINE('Starting 3');
   FOR pac_rec IN pac_ordd
   LOOP
      select sum(CATCH_WEIGHT)
      into   total_cw
      from   ORDCW
      where  ORDER_ID      = pac_rec.ORDER_ID
        and  ORDER_LINE_ID = pac_rec.ORDER_LINE_ID
        and  CW_TYPE IS NOT NULL;
      --
      if pac_rec.uom=2 then
             t_uom:=0;
      else
             t_uom:=1;
      end if;
      if pac_rec.uom is null then
          t_uom:=0;
      end if;
      insert into TRANS
      (      TRANS_ID,     TRANS_TYPE,
             TRANS_DATE,   USER_ID,
             UPLOAD_TIME,  ROUTE_NO,
             PROD_ID,      CUST_PREF_VENDOR,
             SYS_ORDER_ID, SYS_ORDER_LINE_ID,
             ORDER_ID,     ORDER_LINE_ID,
             REASON_CODE,  ADJ_FLAG,
             QTY,          UOM,
             QTY_EXPECTED, WEIGHT )
      values
      (      TRANS_ID_SEQ.nextval, 'PAC',
             sysdate,              user,
             to_date('01-JAN-1980','DD-MON-YYYY'),          i_route_no,
             pac_rec.PROD_ID,      pac_rec.CUST_PREF_VENDOR,
             pac_rec.SYS_ORDER_ID, pac_rec.SYS_ORDER_LINE_ID,
             pac_rec.ORDER_ID,     pac_rec.ORDER_LINE_ID,
             pac_rec.REASON_CD,    pac_rec.CW_TYPE,
             pac_rec.QTY_SHIPPED,  t_uom,
             pac_rec.QTY_ALLOC,    total_cw   )
      ;
      --
      pac_count := pac_ordd%ROWCOUNT;
   END LOOP;
   --
DBMS_OUTPUT.PUT_LINE('Starting 4');
   iInsNeeded := 0;
   iPamIdx := 0;
   szOldOid := NULL;
   iOldOLnID := NULL;
   szOldProd := NULL;
   szOldCpv := NULL;
   FOR ipam IN c_send_pam LOOP
     iInsNeeded := 1;
     IF (ipam.order_id <> NVL(szOldOid, ' ') OR
         ipam.order_line_id <> NVL(iOldOLnID, 0)) AND
        (ipam.prod_id <> NVL(szOldProd, ' ') OR
         ipam.cust_pref_vendor <> NVL(szOldCpv, ' ')) THEN
       szOldOid := ipam.order_id;
       iOldOLnID := ipam.order_line_id;
       szOldProd := ipam.prod_id;
       szOldCpv := ipam.cust_pref_vendor;
       iPamIdx := 0;
     END IF;
     IF (ipam.order_id = NVL(szOldOid, ' ')) AND
        (ipam.prod_id = NVL(szOldProd, ' ')) AND
        (ipam.cust_pref_vendor = NVL(szOldCpv, ' ')) AND
        (ipam.order_line_id <> NVL(iOldOLnID, 0)) THEN
       -- To handle the case that the same order has both case and splits with warehouse outs
       iOldOLnID := ipam.order_line_id;
       iPamIdx := 0;
     END IF;
     IF ipam.wh_out_qty2 = 0 AND ipam.deleted IS NULL THEN
       iPamIdx := 0;
       iInsNeeded := 1;
     ELSIF ipam.deleted IS NOT NULL THEN
       iInsNeeded := 0;
     ELSE
       IF iPamIdx >= ipam.ship_qty THEN
         iInsNeeded := 0;
       END IF;
     END IF;
     IF iInsNeeded = 1 THEN
       -- Only send PAM for no-warehouse-out lines
     BEGIN
         IF v_global_sap_company ='SAP' THEN
             
                INSERT INTO trans
           (trans_id, trans_type, trans_date,
            prod_id, cust_pref_vendor, user_id,
            order_id, order_line_id,
            route_no,
            upload_time, batch_no,
            sys_order_id, sys_order_line_id,uom,
            country_of_origin, wild_farm) VALUES (
            trans_id_seq.nextval, 'PAM', SYSDATE,
            ipam.prod_id, ipam.cust_pref_vendor, USER,
            ipam.order_id, ipam.order_line_id,
            i_route_no,
            TO_DATE('01011980', 'MMDDYYYY'), '88',
            ipam.sys_order_id, ipam.sys_order_line_id,
            ipam.uom,ipam.country_of_origin, ipam.wild_farm);
    
        ELSE         
         INSERT INTO trans
           (trans_id, trans_type, trans_date,
            prod_id, cust_pref_vendor, user_id,
            order_id, order_line_id,
            route_no,
            upload_time, batch_no,
            sys_order_id, sys_order_line_id,
            country_of_origin, wild_farm) VALUES (
            trans_id_seq.nextval, 'PAM', SYSDATE,
            ipam.prod_id, ipam.cust_pref_vendor, USER,
            ipam.order_id, ipam.order_line_id,
            i_route_no,
            TO_DATE('01011980', 'MMDDYYYY'), '88',
            ipam.sys_order_id, ipam.sys_order_line_id,
            ipam.country_of_origin, ipam.wild_farm);
            END IF;
         IF ipam.uom = 1 THEN
           IF ipam.wh_out_qty2 IS NOT NULL AND
              MOD(NVL(ipam.wh_out_qty2, 0), ipam.spc) = 0 THEN
             iPamIdx := iPamIdx + NVL(ipam.wh_out_qty2, 0);
           ELSE
             iPamIdx := iPamIdx + 1;
           END IF;
         ELSE
           iPamIdx := iPamIdx + 1;
         END IF;

         EXCEPTION WHEN OTHERS THEN
           --  MESSAGE( STRING_TRANSLATION.GET_STRING(5559 ,TO_CHAR(SQLCODE)))  ;
           --raise_application_error(-20118, 'Error inserting PAM transactions'||TO_CHAR(SQLCODE));
            Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE', 'Error inserting PAM transactions', SQLCODE, SQLERRM);
            
            pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE',
                               'route_no-'||i_route_no||',Error inserting PAM transactions'|| SQLCODE ||'-'||SQLERRM);
            o_status := 1;
            RETURN; 
            
       END;
     END IF;
   END LOOP;
   
DBMS_OUTPUT.PUT_LINE('Starting 5');

 --IF pac_count != :TRK_CLS.COUNT_CW_ORDD THEN
 --   MESSAGE('Error: Insert TRANS failed. Type PAC. Count:'||
 --            to_char(pac_count));
 --   BELL; RAISE FORM_TRIGGER_FAILURE;
 --END IF;
 --  debugger('PAC');
--
-- For full order deletions (PAD) and LineItem deletions(PAL)
-- create a new manifest and insert into TRANS.
--
   p_del_process(i_route_no,v_status);
   
DBMS_OUTPUT.PUT_LINE('Starting 6');
   
    IF v_status > 0 THEN
     o_status := 1;
     RETURN;
  END IF;
--
-- For one truck close(PAT) one record(for one route)
-- is inserted into TRANS.
-- changed upload time from '01-JAN-80' to sysdate:pims no 96-001964
   IF INSTR(i_route_no,' ') =0 THEN
      upl_time :=  to_date('01-JAN-1980','DD-MON-YYYY');
   ELSE
      upl_time :=  sysdate;
   END IF;
   insert into TRANS
   (      TRANS_ID,     TRANS_TYPE,cmt,
          TRANS_DATE,   USER_ID,
          UPLOAD_TIME,  ROUTE_NO )
   values
   (      TRANS_ID_SEQ.nextval, 'PAT','Route has been Closed by Automatically',
          sysdate,      user,
          upl_time,i_route_no );
   --
  IF sql%NOTFOUND THEN
      --MESSAGE( STRING_TRANSLATION.GET_STRING(5560 ,to_char(sql%ROWCOUNT)));
       Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE', 'Error: Insert TRANS failed. Type PAT. Count:', SQLCODE, SQLERRM);
            
   END IF;
   
 DBMS_OUTPUT.PUT_LINE('Starting 7');
 --  debugger('INSERT OVER');
   --
   if v_global_need_clam='Y' then
   
     -- MESSAGE( STRING_TRANSLATION.GET_STRING(5538 ,i_route_no))                                                              ;
     --raise_application_error(-20120, 'Cannot close route'||i_route_no||'.  One or more items need clam bed information collected.'); 
     Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE', 'Cannot close route'||i_route_no||'.  One or more items need clam bed information collected.', NULL, NULL);
     
     pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE',
                               'route_no-'||i_route_no||',One or more items need clam bed information collected.'); 
     
    o_status := 1;
       RETURN;
   end if;
   update ROUTE
   set    STATUS = 'CLS',
          AUTO_CLOSE_STATUS = 'Y'
   where  ROUTE_NO = i_route_no;
   --
   IF sql%NOTFOUND THEN
     -- MESSAGE( STRING_TRANSLATION.GET_STRING(5561));
     --raise_application_error(-20121, 'Error: Update ROUTE failed'); 
     Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE', 'Error: Update ROUTE failed', SQLCODE, SQLERRM);
     
     pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE',
                               'route_no-'||i_route_no||',Error: Update ROUTE failed'||SQLCODE||'-'|| SQLERRM); 
    o_status := 1;
    RETURN;
   END IF;

  -- Run cross dock portion if order is a cross dock order.
  BEGIN
    SELECT DISTINCT cross_dock_type
    INTO l_ordm_xdock_type
    FROM ordm
    WHERE route_no = i_route_no;
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      pl_log.ins_msg(
        'FATAL',
        'p_truck_close',
        'Retrieved too many cross_dock_type rows in the ordm table, expected 1.',
        sqlcode,
        sqlerrm,
        'ROUTE CLOSE',
        'pl_auto_route_close'
      );
      RAISE;
    WHEN NO_DATA_FOUND THEN
      pl_log.ins_msg(
        'WARN',
        'p_truck_close',
        'No Data Found when looking up cross dock type in the ordm table.',
        sqlcode,
        sqlerrm,
        'ROUTE CLOSE',
        'pl_auto_route_close'
      );
  END;

  IF l_ordm_xdock_type = 'S' THEN
    pl_xdock_order_info_out.main(i_route_no);
  END IF;

  BEGIN
    SELECT DISTINCT cross_dock_type
    INTO l_floats_xdock_type
    FROM floats
    WHERE route_no = i_route_no;
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      pl_log.ins_msg(
        'FATAL',
        'p_truck_close',
        'Retrieved too many cross_dock_type rows in the floats table, expected 1.',
        sqlcode,
        sqlerrm,
        'ROUTE CLOSE',
        'pl_auto_route_close'
      );
      RAISE;
    WHEN NO_DATA_FOUND THEN
      pl_log.ins_msg(
        'WARN',
        'p_truck_close',
        'No Data Found when looking up cross dock type in the floats table.',
        sqlcode,
        sqlerrm,
        'ROUTE CLOSE',
        'pl_auto_route_close'
      );
  END;

  IF l_floats_xdock_type = 'S' THEN
    pl_xdock_floats_info_out.main(i_route_no);
  END IF;

   --
   -- ('The truck/route is closed.');
   o_status := 0;

   pl_log.ins_msg ('INFO', 'p_truck_close', 'Route closed successfully. Route[' || i_route_no || ']',
        SQLCODE, SQLERRM, 'ROUTE CLOSE', 'pl_auto_route_close');

DBMS_OUTPUT.PUT_LINE('Starting 8');
   
EXCEPTION
     WHEN OTHERS THEN
     -- MESSAGE( STRING_TRANSLATION.GET_STRING(3701 ,to_char(ERROR_CODE) ,SQLERRM));
      -- raise_application_error(-20122, 'Error:'||to_char(SQLCODE)||SQLERRM);
      
      Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE', 'WHEN-OTHERS', SQLCODE, SQLERRM);
      o_status := 1;
      
      pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_TRUCK_CLOSE',
                               'route_no-'||i_route_no||',WHEN-OTHERS'||SQLCODE||'-'|| SQLERRM); 
       
 
END p_truck_close;

PROCEDURE p_ins_cc_wh_out(i_route_no IN VARCHAR2,o_status OUT NUMBER ) IS
        
cc_gen_exc_reserve_flag  VARCHAR2(1) := 'Y';   -- default is 'Y'
v_home_slot VARCHAR2(10);
v_batch_no  NUMBER(10);
has_home       VARCHAR2(1) := 'N';
v_last_ship_slot inv.logi_loc%TYPE := null;
v_inv_exist    VARCHAR2(1) := 'N';
v_pallet_id    cc.logi_loc%type := null; --DN#11231 LPN-18 changes acpppp
v_pallet_exist VARCHAR2(10) := 'N';
szInductionLoc    zone.induction_loc%TYPE := NULL;
szOutboundLoc    zone.outbound_loc%TYPE := NULL;
iStatus        NUMBER := 0;
sLShipSlot    inv.logi_loc%TYPE := NULL;
v_global_hs  inv.logi_loc%TYPE;

CURSOR get_home_slot(p_prodid VARCHAR2, p_cpv VARCHAR2,p_uom NUMBER) IS
 SELECT l.LOGI_LOC
 FROM   loc l, inv i
 WHERE  l.LOGI_LOC = i.PLOGI_LOC
   AND  l.PERM     = 'Y'
   AND  i.PROD_ID  = p_prodid
   AND (( p_uom  in (0,2)  AND l.uom in (0,2))
    OR (p_uom = 1  AND l.uom in (0,1)))
   AND  i.CUST_PREF_VENDOR = p_cpv;

CURSOR get_last_ship_slot(l_prod_id VARCHAR2, l_cpv VARCHAR2) IS
 SELECT LAST_SHIP_SLOT
 FROM   PM
 WHERE PROD_ID          = l_prod_id
 AND CUST_PREF_VENDOR = l_cpv
 AND  EXISTS (SELECT 1 FROM loc WHERE logi_loc = pm.last_ship_slot)
         ;
CURSOR chk_last_ship_slot_inv(i_prod_id VARCHAR2, i_cpv VARCHAR2,
   i_last_ship_slot VARCHAR2) IS
SELECT i.logi_loc
FROM   PM P, INV I
WHERE P.PROD_ID          = I.PROD_ID
AND I.PLOGI_LOC        = i_last_ship_slot
AND P.PROD_ID          = i_prod_id
AND P.CUST_PREF_VENDOR = i_cpv
         ;
CURSOR new_pallet_exist(n_pallet_id VARCHAR2) IS
SELECT 'Y'
FROM INV
WHERE LOGI_LOC = n_pallet_id;
CURSOR wh_outs IS
SELECT DISTINCT PROD_ID, CUST_PREF_VENDOR CPV,uom,
      Wh_out_qty
      FROM   ORDD
      WHERE  nvl(WH_OUT_QTY,0) > 0
      AND  NVL(DELETED,' ') NOT IN ('PAD', 'PAL')
      AND  ROUTE_NO = i_route_no
         ;
CURSOR sysconfig_cc_gen IS
SELECT CONFIG_FLAG_VAL
FROM   SYS_CONFIG
WHERE  CONFIG_FLAG_NAME = 'CC_GEN_EXC_RESERVE'
            ;
            
 
BEGIN
  --
  -- DN#5079:acpjjs:Insert CC should be based on SYSCONFIG flag.
  -- IF CC_GEN_EXC_RESERVE_FLAG != 'N' THEN
  -- Generate cycle tasks for both home slots and all reserve slots
  -- ELSIF (home slot found in inv) THEN
  -- Generate cycle tasks for home slots only
  -- ELSE Item has no home slot, so generate CC for all reserve slots
  --
  -- D#12210 Remove the '-RC' appended to user_id because it causes 
  -- inserting failure if user_id is 8 character long.
  BEGIN
    OPEN   sysconfig_cc_gen;
    FETCH  sysconfig_cc_gen INTO cc_gen_exc_reserve_flag ;
    IF sysconfig_cc_gen%NOTFOUND THEN
      cc_gen_exc_reserve_flag := 'Y';
    END IF;
    CLOSE  sysconfig_cc_gen;
  EXCEPTION
    WHEN OTHERS THEN
      cc_gen_exc_reserve_flag := 'Y';   -- default is 'Y'
      IF sysconfig_cc_gen%ISOPEN THEN CLOSE sysconfig_cc_gen; END IF;
  END;
  FOR wh_out IN wh_outs
  LOOP
    SELECT CC_BATCH_NO_SEQ.NEXTVAL
    INTO   v_batch_no
    FROM   DUAL
    ;
    --
    -- Does this item has a home slot ?
    --
    BEGIN
      OPEN   get_home_slot(wh_out.PROD_ID, wh_out.CPV,wh_out.uom);
      FETCH  get_home_slot INTO v_home_slot;
      v_global_hs:=v_home_slot;
      IF get_home_slot%NOTFOUND THEN
        v_home_slot := 'ALL';
        has_home := 'N';
        v_global_hs := NULL;
      ELSE
        has_home := 'Y';
      END IF;
      CLOSE  get_home_slot;
    EXCEPTION
      WHEN OTHERS THEN
        v_home_slot := 'ALL';
        has_home := 'N';
        v_global_hs := NULL;
        IF get_home_slot%ISOPEN THEN CLOSE get_home_slot; END IF;
    END;
    IF nvl(cc_gen_exc_reserve_flag,'Y') != 'N' THEN
      v_home_slot := 'ALL';
    END IF;
    pl_ml_common.get_induction_loc(wh_out.prod_id, wh_out.cpv,
                    wh_out.uom, iStatus, szInductionLoc);
    pl_ml_common.get_outbound_loc(wh_out.prod_id, wh_out.cpv,
                   wh_out.uom, iStatus, szOutboundLoc);
    p_upd_cc_if_exists(i_route_no);
    
    IF v_home_slot NOT IN (szInductionLoc) AND has_home = 'Y' THEN
    BEGIN
      INSERT INTO CC
        (      TYPE,
               BATCH_NO,
               LOGI_LOC,
               PHYS_LOC,
               STATUS,
               PROD_ID,
               CUST_PREF_VENDOR,
               USER_ID,
               CC_GEN_DATE,
               CC_REASON_CODE,
               add_user
        )
        SELECT 'PROD',
               v_batch_no,
               LOGI_LOC,
               PLOGI_LOC,
               'NEW',
               PROD_ID,
               CUST_PREF_VENDOR,
               NULL,
               SYSDATE,
               'WO',
               REPLACE(USER, 'OPS$', '')
               --REPLACE(USER, 'OPS$', '') || '-RC'
        FROM   INV i
        WHERE (PLOGI_LOC = v_home_slot OR v_home_slot = 'ALL' )
        AND  i.PROD_ID = wh_out.PROD_ID
        AND  i.CUST_PREF_VENDOR = wh_out.CPV
        AND  NOT EXISTS
               (SELECT 'Duplicates'
                FROM   CC
                WHERE cc.PHYS_LOC = i.PLOGI_LOC
                AND   cc.LOGI_LOC = i.LOGI_LOC
                AND   cc.PROD_ID  = i.PROD_ID
                AND   cc.CUST_PREF_VENDOR = i.CUST_PREF_VENDOR )
        ;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        BEGIN
          UPDATE CC
            SET CC_REASON_CODE='WO'
            WHERE PHYS_LOC=v_home_slot
            and   prod_id=wh_out.prod_id;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            --MESSAGE( STRING_TRANSLATION.GET_STRING(5565 ,TO_CHAR(S) ,SQLERRM));
            --BELL; 
           -- raise_application_error(-20115, 'Error:CC-upd:'||TO_CHAR(SQLCODE) || SQLERRM );
            Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT', 'Error:CC-upd 1:', SQLCODE, SQLERRM);
             pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT',
                               'route_no-'||i_route_no||',Error:CC-upd 1:'||SQLCODE||'-'|| SQLERRM); 
            
            o_status := 1;
            RETURN;
          
        END;
      WHEN OTHERS THEN
        --MESSAGE( STRING_TRANSLATION.GET_STRING(5566 ,TO_CHAR(ERROR_CODE) ,SQLERRM));
        --BELL; 
        Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT', 'Error:CC-upd 2:', SQLCODE, SQLERRM);
        
        pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT',
                               'route_no-'||i_route_no||',Error:CC-upd 2:'||SQLCODE||'-'|| SQLERRM); 
         -- raise_application_error(-20116, 'Error:CC-upd:'||TO_CHAR(SQLCODE) || SQLERRM );  
            o_status := 1;
            RETURN;
    END;
    END IF;
    
    begin
      update  cc set cc_reason_code='CC'
      where prod_id = wh_out.prod_id
      and   phys_loc <>  logi_loc
      AND   phys_loc NOT IN (szInductionLoc);
    exception when no_data_found then null;
    end;
    /* Insert this to implement contra code */
    if v_global_hs is not null AND v_home_slot NOT IN (szInductionLoc) then
      BEGIN
        v_home_slot:= v_global_hs;
        INSERT INTO CC_EXCEPTION_LIST(logi_loc,
                                      phys_loc,
                                      prod_id,
                                      cust_pref_vendor,
                                      cc_except_date,
                                      cc_except_code,
                                      uom,
                                      qty)
          values (v_home_slot,
                  v_home_slot,
                  wh_out.prod_id,
                  wh_out.cpv,
                  sysdate,
                  'WO',
                  nvl(wh_out.uom,'0'),
                  wh_out.wh_out_qty);
      EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
        BEGIN
          Update CC_EXCEPTION_LIST
            set qty=qty+wh_out.wh_out_qty
            where logi_loc=v_home_slot
            and   phys_loc=v_home_slot
            and   prod_id=wh_out.prod_id
            and   cc_except_code='WO';
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            --MESSAGE( STRING_TRANSLATION.GET_STRING(5567 ,TO_CHAR(ERROR_CODE) ,SQLERRM));
             Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT', 'Error:CC-upd 3:', SQLCODE, SQLERRM);
             
             
        pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT',
                               'route_no-'||i_route_no||',Error:CC-upd 3:'||SQLCODE||'-'|| SQLERRM); 
           --raise_application_error(-20117, 'Error:CC-upd:'||TO_CHAR(SQLCODE) || SQLERRM );
            o_status := 1;
            RETURN;
        END;
      END;
    end if;
    if has_home = 'N' then
      BEGIN
        -- The item has no home, it's either a floating or Mini-load item
        OPEN   get_last_ship_slot(wh_out.prod_id, wh_out.cpv);
        FETCH  get_last_ship_slot INTO v_last_ship_slot;
        IF get_last_ship_slot%FOUND AND
           v_last_ship_slot NOT IN ('*', szInductionLoc, 'DDDDDD') THEN
          -- The item has a valid last ship slot
          sLShipSlot := NULL;
          v_pallet_id := NULL;
          OPEN   chk_last_ship_slot_inv(wh_out.prod_id, wh_out.cpv, v_last_ship_slot);
          FETCH  chk_last_ship_slot_inv INTO sLShipSlot;
          IF chk_last_ship_slot_inv%NOTFOUND THEN
            -- Although the item has a last ship slot, it doesn't has any inventory.
            -- We go ahead to create a new pallet ID and insert a new inventory record
            -- for the last ship slot/new pallet ID. The purpose of the new inventory
            -- is to create a warehouse out cycle count record through a cursor loop.
            -- The cycle count record is treat as to notify user that a warehouse out
            -- occurred during order processing but user can cycle count it out later
            -- if needed even without any inventory. The new inventory is then deleted
            -- after the cycle count record is created. Otherwise, cycle count record(s)
            -- is/are created for all pallets of existing inventory with the same
            -- last ship slot.
            v_inv_exist := 'N';
            sLShipSlot := NULL;
            BEGIN
              SELECT pallet_id_seq.nextval INTO v_pallet_id FROM DUAL;
            EXCEPTION
              WHEN OTHERS THEN 
               -- MESSAGE( STRING_TRANSLATION.GET_STRING(5568 ,TO_CHAR(SQLCODE)))       ;
               --raise_application_error(-20117,TO_CHAR(SQLCODE) || 'Unable to generate next license plate' );
                Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT', 'Unable to generate next license plate', SQLCODE, SQLERRM);
                
                             
        pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_INS_CC_WH_OUT',
                               'route_no-'||i_route_no||',Unable to generate next license plate'||SQLCODE||'-'|| SQLERRM); 
                o_status := 1;
                RETURN;
            END;
            BEGIN
              INSERT INTO inv
                (prod_id, cust_pref_vendor, inv_date, logi_loc, plogi_loc,
                 qoh, qty_alloc, qty_planned, min_qty, abc, status)
                VALUES (
                 wh_out.prod_id, wh_out.cpv, SYSDATE, v_pallet_id, v_last_ship_slot,
                 0, 0, 0, 0, 'A', 'AVL');
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          ELSE
            v_inv_exist := 'Y';
          END IF;
          CLOSE chk_last_ship_slot_inv;
          FOR clssi IN chk_last_ship_slot_inv(wh_out.prod_id, wh_out.cpv, v_last_ship_slot) LOOP
            BEGIN
              INSERT INTO cc
                (type, batch_no, logi_loc, phys_loc,
                 prod_id, cust_pref_vendor,
                 status, user_id, cc_gen_date, cc_reason_code, add_user)
                VALUES (
                 'PROD', v_batch_no,
                 DECODE(v_inv_exist, 'N', v_pallet_id, clssi.logi_loc), v_last_ship_slot,
                 wh_out.prod_id, wh_out.cpv,
                 'NEW', NULL, SYSDATE, 'WO', REPLACE(USER, 'OPS$', ''));
            EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                BEGIN
                  UPDATE cc
                    SET cc_reason_code = 'WO'
                    WHERE phys_loc = v_last_ship_slot
                    AND   prod_id = wh_out.prod_id;
                EXCEPTION
                  WHEN OTHERS THEN
                    NULL;
                END;
              WHEN OTHERS THEN
                NULL;
            END;
            BEGIN
              INSERT INTO cc_exception_list
                (prod_id, cust_pref_vendor, logi_loc, phys_loc,
                 cc_except_code, cc_except_date, qty, uom)
                VALUES (
                 wh_out.prod_id, wh_out.cpv,
                 DECODE(v_inv_exist, 'N', v_pallet_id, clssi.logi_loc), v_last_ship_slot,
                 'WO', SYSDATE, wh_out.wh_out_qty, NVL(wh_out.uom, '0'));
            EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                BEGIN
                  UPDATE cc_exception_list
                    SET cc_except_code = 'WO'
                    WHERE phys_loc = v_last_ship_slot
                    AND   prod_id = wh_out.prod_id;
                EXCEPTION
                  WHEN OTHERS THEN
                    NULL;
                END;
              WHEN OTHERS THEN
                NULL;
            END;
          END LOOP;
          IF v_inv_exist = 'N' THEN
            BEGIN
              DELETE inv
                WHERE logi_loc = v_pallet_id;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
        END IF;
        close get_last_ship_slot;  /* prpakp added this */
      END;
    END IF;
  END LOOP; 
o_status := 0;
END p_ins_cc_wh_out;

PROCEDURE p_del_process(i_route_no IN varchar2,o_status OUT NUMBER) IS

   CURSOR pad_ordd IS
   SELECT DISTINCT
          SYS_ORDER_ID,
          REASON_CD
   FROM   ORDD
   WHERE  ROUTE_NO = i_route_no
   AND    DELETED  = 'PAD'
   ;
   CURSOR pal_ordd IS
   SELECT d.ORDER_ID,     min(d.ORDER_LINE_ID) order_line_id,
          d.PROD_ID,      d.CUST_PREF_VENDOR,
          d.SYS_ORDER_ID, d.SYS_ORDER_LINE_ID,
          d.STOP_NO,      d.DELETED,
          d.REASON_CD,    decode(d.UOM,2,0,d.uom) uom,
          sum(DECODE(d.UOM, 1,d.QTY_ALLOC,
                 NVL(d.QTY_ALLOC,0)/DECODE(p.SPC,NULL,1,0,1,p.SPC) )
                 - NVL(WH_OUT_QTY,0))   QTY
   FROM   PM p,  ORDD d
   WHERE  d.ROUTE_NO = i_route_no
   AND    d.DELETED  IN ('PAD','PAL')
   AND    d.PROD_ID  = p.PROD_ID(+)
   AND    d.CUST_PREF_VENDOR = p.CUST_PREF_VENDOR(+)
   group by d.ORDER_ID,d.PROD_ID,d.CUST_PREF_VENDOR,d.SYS_ORDER_ID, d.SYS_ORDER_LINE_ID,
            d.STOP_NO, d.DELETED,d.REASON_CD, d.UOM;

   CURSOR del_man IS
   SELECT MANIFEST_NO
   FROM   MANIFESTS
   WHERE  ROUTE_NO = i_route_no
   AND    MANIFEST_STATUS = 'PAD'
   ;
   --
   pal_rec1     pal_ordd%ROWTYPE;
   pal_count    NUMBER(10)  := 0;
   pad_count    NUMBER(10);
   del_manifest NUMBER(7);
   del_line_id  NUMBER(3) := 0;
   del_reason   VARCHAR2(3);
   v_truck_no   route.truck_no%TYPE;

BEGIN
   OPEN   pal_ordd;
   FETCH  pal_ordd INTO pal_rec1;
   IF pal_ordd%NOTFOUND THEN
      CLOSE  pal_ordd;
      RETURN ;
   END IF;
   CLOSE  pal_ordd;
   
   OPEN   del_man;
   FETCH  del_man INTO del_manifest;
   IF del_man%NOTFOUND THEN
      CLOSE  del_man;
      SELECT MANIFEST_NO_SEQ.NEXTVAL
      INTO   del_manifest
      FROM   DUAL
      ;
      
      SELECT truck_no INTO v_truck_no FROM route 
                                      WHERE route_no = i_route_no;
                                      
      INSERT INTO MANIFESTS
      (      MANIFEST_NO,  MANIFEST_CREATE_DT,
             MANIFEST_STATUS,
             ROUTE_NO,     TRUCK_NO
      )
      VALUES
      (      del_manifest, SYSDATE,
             'PAD',
             i_route_no,
             v_truck_no
      )
      ;
   ELSE
      CLOSE  del_man;
      SELECT MAX(ERM_LINE_ID)
      INTO   del_line_id
      FROM   RETURNS
      WHERE  MANIFEST_NO = del_manifest
      ;
   END IF;
   --
   IF del_line_id IS NULL THEN del_line_id := 0; END IF;
   --
/*   SELECT REASON_CD
   INTO   del_reason
   FROM   REASON_CDS
   WHERE  REASON_CD_TYPE = 'RTN'
   AND    REASON_GROUP   = 'NOR'
   AND    ROWNUM = 1
   ;*/
--
  del_reason:='R60';
FOR pal_rec IN pal_ordd
LOOP
   del_line_id := del_line_id + 1;
   --
/*Insert ordd.order_id||L||ordd.order_line_id in the new field */
/*orig_invoice in manifest_dtls.This change is to send invoice no to */
/* the HOST_COMMAND  :acpsxd 04/30/96 .*/
   INSERT INTO MANIFEST_DTLS
   (      MANIFEST_NO,  STOP_NO,
          REC_TYPE,     OBLIGATION_NO,
          PROD_ID,      CUST_PREF_VENDOR,
          SHIPPED_QTY,  SHIPPED_SPLIT_CD,
          MANIFEST_DTL_STATUS,ORIG_INVOICE
   )
   VALUES
   (      del_manifest,   pal_rec.STOP_NO,     'D',
          TO_CHAR(pal_rec.SYS_ORDER_ID)
                   ||'L'||TO_CHAR(pal_rec.SYS_ORDER_LINE_ID),
          pal_rec.PROD_ID,pal_rec.CUST_PREF_VENDOR,
          pal_rec.QTY,    pal_rec.UOM,         'OPN',
          pal_rec.order_id || 'L' || LPAD(TO_CHAR(pal_rec.order_line_id),3,'0'));
   --
   IF NVL(pal_rec.QTY,0) != 0 THEN
   INSERT INTO RETURNS
   (      MANIFEST_NO,      ROUTE_NO,
          STOP_NO,          REC_TYPE,
          OBLIGATION_NO,
          PROD_ID,          CUST_PREF_VENDOR,
          RETURN_REASON_CD,
          RETURNED_QTY,     RETURNED_SPLIT_CD,
          RETURNED_PROD_ID, ERM_LINE_ID,
          SHIPPED_QTY,      SHIPPED_SPLIT_CD
   )
   VALUES
   (      del_manifest,     i_route_no,
          pal_rec.STOP_NO,  'D',
          TO_CHAR(pal_rec.SYS_ORDER_ID)
                     ||'L'||TO_CHAR(pal_rec.SYS_ORDER_LINE_ID),
          pal_rec.PROD_ID,  pal_rec.CUST_PREF_VENDOR,
          del_reason,
          pal_rec.QTY,      pal_rec.UOM,
          pal_rec.PROD_ID,  del_line_id,
          pal_rec.QTY,      pal_rec.UOM
   )
   ;
   END IF;
   --
   IF pal_rec.DELETED = 'PAL' THEN
   INSERT INTO TRANS
   (      TRANS_ID,     TRANS_TYPE,
          TRANS_DATE,   USER_ID,
          UPLOAD_TIME,  ROUTE_NO,
          PROD_ID,      CUST_PREF_VENDOR,
          SYS_ORDER_ID, SYS_ORDER_LINE_ID,
          ORDER_ID,     ORDER_LINE_ID,
          REASON_CODE,  REC_ID,
          QTY,          UOM
   )
   VALUES
   (      TRANS_ID_SEQ.NEXTVAL, 'PAL',
          SYSDATE,              USER,
          to_date('01-JAN-1980','DD-MON-YYYY'),          i_route_no,
          pal_rec.PROD_ID,      pal_rec.CUST_PREF_VENDOR,
          pal_rec.SYS_ORDER_ID, pal_rec.SYS_ORDER_LINE_ID,
          pal_rec.ORDER_ID,     pal_rec.ORDER_LINE_ID,
          pal_rec.REASON_CD,    del_manifest,
          pal_rec.QTY,          pal_rec.UOM
   )
   ;
   pal_count := pal_count + 1;
   --
   END IF;
END LOOP;
--
     /*    IF pal_count != :TRK_CLS.COUNT_LOD THEN
      MESSAGE('Error: Insert TRANS failed. Type PAL. Count:'||
               to_char(pal_count));
      BELL; RAISE FORM_TRIGGER_FAILURE;
   END IF; */
--
-- For each full order deletions (PAD) one record(for distinct SYSORDER)
-- is inserted into TRANS.
--
   FOR pad_rec IN pad_ordd
   LOOP
      insert into TRANS
      (      TRANS_ID,     TRANS_TYPE,
             TRANS_DATE,   USER_ID,
             ROUTE_NO,     REC_ID,
             UPLOAD_TIME,
             SYS_ORDER_ID, REASON_CODE )
      values
      (      TRANS_ID_SEQ.nextval, 'PAD',
             sysdate,              user,
             i_route_no,     del_manifest,
             TO_DATE('01-JAN-1980','DD-MON-YYYY'),
             pad_rec.SYS_ORDER_ID, pad_rec.REASON_CD )
      ;
      pad_count := pad_ordd%ROWCOUNT;
   END LOOP;
   --
 /*  IF pad_count != :TRK_CLS.COUNT_FOD THEN
      MESSAGE('Error: Insert TRANS failed. Type PAD. Count:'||
               to_char(pad_count));
      BELL; RAISE FORM_TRIGGER_FAILURE;
   END IF; */
   --
   
o_status := 0;
EXCEPTION
    WHEN OTHERS THEN
      --MESSAGE( STRING_TRANSLATION.GET_STRING(3701 ,to_char(ERROR_CODE) ,SQLERRM));
      -- raise_application_error(-20118, TO_CHAR(SQLCODE) || SQLERRM );
       Pl_Log.ins_msg ('FATAL','PL_AUTO_ROUTE_CLOSE.P_DEL_PROCESS', 'WHEN OTHERS', SQLCODE, SQLERRM);
       
       pl_event.ins_failure_event('PL_AUTO_ROUTE_CLOSE','Q','CRIT',i_route_no,'CRIT:PL_AUTO_ROUTE_CLOSE.P_DEL_PROCESS',
                               'route_no-'||i_route_no||',WHEN OTHERS'||SQLCODE||'-'|| SQLERRM); 
       o_status := 1;
END p_del_process;

PROCEDURE p_upd_cc_if_exists(i_route_no In VARCHAR2 ) IS
v_exists VARCHAR2(1);
v_prior cc_reason.cc_priority%TYPE;
vop     cc_reason.cc_priority%TYPE;
begin
    /* get the cc_priority for reason code 'WO' */
    begin
         select cc_priority into v_prior
         from cc_reason
         where cc_reason_code='WO';
         exception when no_data_found then null;
    end;
    begin
         select 'Y' into v_exists
         from cc
         where prod_id in (select prod_id from ordd where
                      route_no=i_route_no and
                      wh_out_qty is not null and
                      nvl(deleted,' ') not in ('PAD','PAL'));
    exception when no_data_found then null;
    when too_many_rows then
         v_exists:='Y';
    end;
    if v_exists='Y' then
         update cc set cc_reason_code='WO' ,
                       cc_gen_date=sysdate
         where prod_id in (select prod_id from ordd where
         route_no=i_route_no and
         wh_out_qty is not null and
         nvl(deleted,' ') not in ('PAL','PAD')) and
         cc_reason_code in (select cc_reason_code from cc_reason
                            where cc_priority > v_prior);
    end if;
end p_upd_cc_if_exists ;


/*
** This procedure will check to see if the ENABLE_FINISH_GOODS syspar is
** set to 'Y', if the route is a "get meat" route (by checking if the route was auto generated),
** and if SOS has been completed for this route and then attempt
** to close the route. SOS complete in this procedure
** is defined by the all selectors dropping the floats at the door
** i.e. all batches for this route have a value for BATCH.DROP_DOOR_TIME
** which gets set in the sos_batchcmp.pc program.
**
** The batch number is passed to this procedure since it gets called from 
** sos_batchcmp.pc program.
** JIRA 707
*/
PROCEDURE p_close_get_meat_route(i_route_no route.route_no%TYPE)
IS

  l_batch_count pls_integer := 0;
  l_short_count pls_integer := 0;
  l_dropped_at_door_count pls_integer := 0;

BEGIN

  --
  -- Return if this route isn't a "raw material" or get meat route.
  --
  IF pl_common.f_is_raw_material_route(i_route_no) = 'N' THEN
    RETURN;
  END IF;

  --
  -- Get the number of shorts for this route.
  --
  SELECT count(*)
  INTO l_short_count
  FROM float_detail
  WHERE route_no = i_route_no
  AND nvl(qty_short, 0) > 0;

  IF l_short_count > 0 THEN
    pl_log.ins_msg ('INFO', 'p_close_get_meat_route', 
        'Shorts exist for this route. Stopping the route close process. Route[' || i_route_no || ']',
        SQLCODE, SQLERRM, 'AUTO ROUTE CLOSE', 'pl_auto_route_close');
    RETURN;
  END IF;

  --
  -- Get counts to check if the number of "completed" batches is
  -- equal to the number of SOS batches for this route.
  --
  SELECT count(b.batch_no), count(b.door_drop_time)
  INTO l_batch_count, l_dropped_at_door_count
  FROM batch b, sos_batch sb
  WHERE sb.route_no = i_route_no
  AND b.batch_no = 'S' || sb.batch_no;

  --
  -- If the number of dropped at door is equal to the # of batches for this route,
  -- then attempt to close the route.
  --
  IF l_dropped_at_door_count = l_batch_count THEN

    p_pre_validation(i_route_no);

  ELSE
    pl_log.ins_msg ('INFO', 'p_close_get_meat_route', 'Unable to close route, There are batches that have not been completed. ' ||
      'l_batch_count=[' || l_batch_count ||'], l_dropped_at_door_count=[' || l_dropped_at_door_count || ']',
      SQLCODE, SQLERRM, 'AUTO ROUTE CLOSE', 'pl_auto_route_close');
  END IF;

END p_close_get_meat_route;

END pl_auto_route_close;
/
SHOW ERRORS
