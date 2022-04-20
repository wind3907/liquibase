CREATE OR REPLACE PACKAGE swms.pl_order_processing IS

/*****************************************************************/
/* sccs_id=%Z% %W% %G% %I% */
/*****************************************************************/

-------------------------------------------------------------------------------
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    09/03/02 prpbcb   rs239a DN 10997  rs239b DN 10999   Ticket 339117
--                      Demand replenishments/bulk pulls for a route that are
--                      in the same group are sometimes coming out on
--                      different batches.
--                      Changed order by clause in procedure gen_fork_batch
--                      from
--                         ORDER BY f.group_no, fd.src_loc
--                      to
--                         ORDER BY f.group_no, r.seq_no, fd.src_loc
--                      so that the replenishments/bulk pulls for a route
--                      will be together. Column r.seq_no is route.seq_no
--                      and specifies the order the user wants the routes
--                      generated.
--
--                      Changed order by clause in procedure gen_repl_batch
--                      from
--                         ORDER BY f.group_no, f.zone_id,
--                       decode (p_home_slot_flag, 'Y', f.home_slot, fd.src_loc)
--                      to
--                         ORDER BY f.group_no, f.zone_id, r.seq_no,
--                       decode (p_home_slot_flag, 'Y', f.home_slot, fd.src_loc)
--                      so that the replenishments for a route will be
--                      together.
--
--                      Be aware that if the number of replenishments/bulk
--                      pulls in a group for a route exceed the maximum number
--                      that the user has specified for a batch then they will
--                      be split across batches.
--
--    09/04/02 prpbcb   rs239a DN 10997  rs239b DN 10999   Ticket 339117
--                      The above change sent to co. 46 yesterday.  rs239b not
--                      yet changed.  Looked at how the settings of the syspars
--                      can affect things and realized the order by in
--                      procedure gen_repl_batch needed to be changed again.
--                      It was changed from
--                         ORDER BY f.group_no, f.zone_id, r.seq_no,
--                       decode (p_home_slot_flag, 'Y', f.home_slot, fd.src_loc)
--                      to
--                         ORDER BY f.group_no, r.seq_no, f.zone_id,
--                       decode (p_home_slot_flag, 'Y', f.home_slot, fd.src_loc)
--                      This file will be checked back in under defect 10997.
--
--   08/28/06  prpakp   Changed to initialize the no of cases value(iCases) to
--          zero when uom is 1 so that ordcw records will not
--          create for the cases value.
--   01/21/08  prpakp   Changed the check in pAssignDoor for route number not
--          having door number from just c_door is null to c_door is
--          is null and c_door is null and also exists in sel_method
--          the area C. Same for dry and freezer door.
--   04/01/10  sth0458  DN12554 - 212 Enh - SCE057
--                      Add UOM field to SWMS
--                      Expanded the length of prod size to accomodate
--                      for prod size unit.  Changed queries to
--                      fetch prod_size_unit along with prod_size
--  01/17/13 sray0453   CRQ26526: ORDCW sequence is not updated properly for bulk pulls.
--  04/08/13 jluo4546   CRQ45459: ORDCW is not created for items w/ both bulk/combo pulls
--          and regaular selections. Add new function update_cwt_wo_info().
-- 04/09/13 spot3255 CRQ46545 :Made some logical changes on repallet function.
-- 02/11/14 spot3255 CRQ48665 :Balancing the ZONE with new ZoneBalance procedure
-- 06/06/14 uatu4196 Charm 6*1685 : Made the zone balacing procedure an autonomous transaction.
--
--
--    10/22/14 prpbcb   Symbotic project.  WIB 558
--
--                      Create procedure "create_float_detail_piece_recs()"
--                      This procedure will create the ORDCW records and
--                      the Symbotic case records.
--                      CRT_order_proc.pc was changed to call create_float_detail_piece_recs().
--
--                      Create procedure "create_ordcb" to create the ORDCB clambed
--                      selection data collection records.
--                      Removed creating the ORDCB records in "order_proc.pc".
--
--                      Create procedure "create_ord_cool" to create the ORD_COOL
--                      country of origing selection data collection records.
--                      Removed creating the ORD_COOL records in "order_proc.pc".
--
--                      Create procedure "update_float_detail_piece_seq" to
--                      update FLOAT_DETAIL.BC_ST_PIECE_SEQ.
--                      This column needs to be set in order to create the
--                      ORCW, ORDCB and and ORD_COOL records as will as SOS
--                      to work correctly.
--                      Right now pl_sos.sql is updating
--                      FLOAT_DETAIL.BC_ST_PIECE_SEQ.  pl_sos.sql
--                      needs to be changed to remove the update.
--
-- 11/20/14  sgup4114   Charm 6*3957 To fix the lock issue of repallet function.
--
--    04/10/15 prpbcb   Symbotic project.
--
--                      Fix the assignment of ordcw.seq_no in procedure
--                      "pCreateOrdCW" for a split order, ordcw.uom = 1.
--                      The seq_no was skipping.
--                      Example:
--
--   ORDER_ID       ORDER_LINE_ID     SEQ_NO        UOM
--   -------------- ------------- ---------- ----------
--   504105919                 16          1          2
--   504105919                 16          2          2
--   504105919                 19          1          2
--   504105919                 19          2          2
--   504105919                 24          1          1  <----   seq_no goes 1, 3, 6
--   504105919                 24          3          1  <----
--   504105919                 24          6          1  <----
--   504105919                 26          1          2
--   504105919                 26          2          2
--   504105919                 26          3          2
--   504105919                 33          1          2
--   504105919                 33          2          2
--   504105919                 35          1          2
--   504105919                 42          1          2
--   504105919                 47          1          2
--   504105919                 49          1          2
--   504105919                 49          2          2
--   504105919                 53          1          2
--   504105919                 53          2          2
--
--
--
--    06/05/15 prpbcb   Symbotic project.
--                      Temporarily put in these two procedure calls in procedure
--                       "create_float_detail_piece_recs()" until we write
--                      an "end of order generation" procedure.
-- pl_matrix_common.populate_mx_wave_number(i_wave_number => i_route_batch_no);
-- pl_matrix_op.assign_mx_priority(i_route_batch_no => i_route_batch_no);
--
--    07/07/15 prpbcb   Symbotic project.
--                      Bug fix.  TFS work item 505
--                      When creating the COOL records in procedure
--                      "create_ord_cool" float_detail.clam_bed_trk was set
--                      to Y instead of float_detail.cool_trk
--
--                      Change the order by in procedure
--                      "update_float_detail_piece_seq()".  See the modification
--                      history in the procedure for more information.
--
--    07/17/15 prpbcb   Symbotic project.
--                      Bug fix.  TFS work item 505
--                      Change procedure "update_float_detail_piece_seq()" to
--                      include only normal selection float_detail records.
--                      -- pallet_pull = 'N'.  Before it included bulk pulls,
--                      combine pulls and VRT bulk pulls which caused the
--                      piece sequence to be set incorrectly.  Bulk pulls and
--                      combine don't go to SOS so we don't want to set the
--                      piece sequence.
--
--    10/27/15 prpbcb   Symbotic project.
--                      Bug fix.  TFS work item ___
--
--                      When collecting the catchweights with SOS for a normal
--                      selection batch the catchweight is assigned to the
--                      bulk pull ORDCW record when the order-item has both a bulk
--                      pull(s) and normal selection.  This is happening because
--                      for normal selection the update is made by case id and
--                      the FLOAT_DETAIL.BC_START_PIECE_SEQ starts at one but
--                      the ORDCW records are created by float_no which will
--                      create the ORDCW records for the bulk pulls first.
--
--                      In ORDCW the case id is ORDER_SEQ || SEQ_NO and since
--                      bulk pulls were selected first when creating the ORDCW
--                      records the SEQ_NO starts with 1
--
--                      Changed procedure "pCreateOrdCW()" to
--                      create the ORDCW records for normal selection batches
--                      first then bulk pulls.  This matches the order the
--                      FLOAT_DETAIL.BC_ST_PIECE_SEQ is assigned.
--
--                      Example: Item has a bulk pull for 5 cases and a normal
--                               selection for 2 cases.
--
--                      ************************************************
--                      ** Before Fix
--                      ************************************************
--                             ------ FLOAT_DETAIL ------
--                      FLOAT_NO ORDER_ID   ORDER_SEQ   QTY     BC_ST_PIECE_SEQ
--                      --------------------------------------------------------
--    Bulk Pull         123      123456789  30000001    5 CS    null (Not set for bulk pulls which is correct)
--    Normal Selection  124      123456789  30000001    2 CS    1    (The case ids will be 30000001001 and 30000001002)
--
--                             ------ ORDCW ------
--                      FLOAT_NO ORDER_ID   SEQ NO   ORDER SEQ   CASE ID
--                      --------------------------------------------------------
--    Bulk Pull         123      123456789    1      30000001   30000001001
--    Bulk Pull         123      123456789    2      30000001   30000001002
--    Bulk Pull         123      123456789    3      30000001   30000001003
--    Bulk Pull         123      123456789    4      30000001   30000001004
--    Bulk Pull         123      123456789    5      30000001   30000001005
--    Normal Selection  124      123456789    6      30000001   30000001006
--    Normal Selection  124      123456789    7      30000001   30000001007
--
--                      Catchweight is collected for the first case on the normal
--                      selection batch.  SOS sends the catchweight to SWMS
--                      with case id 30000001001.  ORDCW is updated using the
--                      case id but ORDCW case id 30000001001 is for the bulk pull
--                      so the bulk pull record is updated instead of the record
--                      for the normal selection batch.
--                      ************************************************
--                      ** End Before Fix
--                      ************************************************
--
--                      ************************************************
--                      ** After Fix
--                      ************************************************
--                             ------ FLOAT_DETAIL ------
--                      FLOAT_NO ORDER_ID   ORDER_SEQ   QTY     BC_ST_PIECE_SEQ
--                      --------------------------------------------------------
--    Bulk Pull         123      123456789  30000001    5 CS    null (Not set for bulk pulls which is correct)
--    Normal Selection  124      123456789  30000001    2 CS    1    (The case ids will be 30000001001 and 30000001002)
--
--                             ------ ORDCW ------
--                      FLOAT_NO ORDER_ID   SEQ NO   ORDER SEQ   CASE ID
--                      --------------------------------------------------------
--    Bulk Pull         123      123456789    3      30000001   30000001003
--    Bulk Pull         123      123456789    4      30000001   30000001002
--    Bulk Pull         123      123456789    5      30000001   30000001005
--    Bulk Pull         123      123456789    6      30000001   30000001006
--    Bulk Pull         123      123456789    7      30000001   30000001007
--    Normal Selection  124      123456789    1      30000001   30000001001
--    Normal Selection  124      123456789    2      30000001   30000001002
--
--                      Catchweight is collected for the first case on the normal
--                      selection batch.  SOS sends the catchweight to SWMS
--                      with case id 30000001001.  ORDCW is updated using the
--                      case id which is correct as case id 30000001001 in
--                      ORDCW is for the normal selection batch.
--                      ************************************************
--                      ** End After Fix
--                      ************************************************
--
--
--    12/03/15 prpbcb   Bug fix.
--                      Project:
-- R30.4--FTP30.3.2--WIB#584--Charm6000009889_ORDCW_records_not created_when_COO_item_bulk_pulled_repalletize_mixed_stops_on_float
--
--                      Getting this error (recorded in SWMS_LOG table) when
--                      creating ORD_COOL records for bulk pull of cool item:
--                ORA-01400: cannot insert NULL into ("SWMS"."ORD_COOL"."SEQ_NO")
--                      This raised an exception.
--                      This is happening because procedure "create_ord_cool()"
--                      was expecting FLOAT_DETAIL.BC_ST_PIECE_SEQ which it will
--                      not be for a bulk pull. 
--
--                      Then what happened is any ORDCW records for the route
--                      where not committed even though PRO*C program CRT_order_proc.pc
--                      has a commit.  CRT_order_proc.pc is doing this:
--      EXEC SQL
--      EXECUTE
--      BEGIN
--         pl_order_processing.create_float_detail_piece_recs(i_route_batch_no => :route_batch_no);
--         -------- pl_order_processing.pCreateOrdCW (iRouteBatchNo=>:route_batch_no);
--      END;
--      END-EXEC;
--
--      stat = check_bad_float_status(route_batch_no);
--
--      EXEC SQL COMMIT;
--
--                      Changed "create_ord_cool()" to account for null FLOAT_DETAIL.BC_ST_PIECE_SEQ
--                      for bulk pulls.
--                      Also changed "create_ord_cool()" to handle exceptions
--                      internally.  No exceptions raised to the outside world
--                      since the basic rule for order generation is don't stop.                     
--                      Did the same for "create_ordcb()".
--
--
--                     Added the re-palletize changes made by Infosys in an
--                     unchecked out version.   Procedures "Repalletize" and
--                     "ZoneBalance".  This fixes bug with stops being mixed
--                     across zones on a float.
--
--
--    03/01/16 prpbcb   Bug fix.
--                      Project:
--           R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--                      Tag along changes to this project. 
-- 
--                      OpCo 335 Bahamas encountered an error in procedure
--                      "update_float_detail_piece_seq()" which resulted in
--                      none of the regular batches for the routes 
--                      generated together getting st_piece_seq and bc_st_piece_seq
--                      assigned.  This the batches could not be downloaded to SOS.
--                      The error was written to the SWMS_LOG table.
--                      The error was:
-- MSG_TEXT                                           SQL_ERR_MSG
-- -------------------------------------------------- ------------------------------------------------------------
-- (i_route_batch_no[1223255],i_route_no[])           ORA-06502: PL/SQL: numeric or value error: number precision
-- l_float_no[254513]  l_float_detail_seq_no[3]       too large
--
--                      The situation that caused the error was 1500 cases ordered
--                      for a floating item so it did not bulk pull.  Four float
--                      detail records created.  They were all on the same float.
--                      The float detail quantities were 383, 750, 104 and 263
--                      with the corresponding value for st_piece_seq and bc_st_piece_seq
--                      being 1, 384, 1134 and 1238
--                      SWMS can only handle 3 digits thus we got the error.
--
--                      So that we don't fail everything if this happens again
--                      procedure "update_float_detail_piece_seq()" changed to
--                      have an exception handler about the UPDATE statement so
--                      only that one float detail record will not get updated.

--                      vkal9662 Jira 419 Auto_Gen_Route procedure added
-------------------------------------------------------------------------------
--    02/11/19 xzhe5043 Jira 694 Modified CW for Finish Good/get meat route to use average weight 
--    02/18/19 xzhe5043 Jira 729 Add GetMeat logic
-- 	  05/29/19 sban3548 Jira OPCOF-1671/2143 Auto populate catch weight for produced cases and 
-- 							not to prompt for catch weight collection during selection for happy path
--                          Recover the produced cases during Route recovery process.
--	  06/14/19 sban3548 Jira OPCOF-2142 Populate Catch Weight for BTP(rule=9) orders even if partial 
--							FG cases produced, mark the float as CW collected.
--	  07/12/19 sban3548 Jira OPCOF-2142 Enhanced to handle exception scenario to Populate Catch Weight for BTP orders
--						even if partially produced and the remaining qty allocated from main WH, then mark the float to collect CW.
--						If the qty ordered exact match with the qty on hand, then only catch weight collection is not Prompted.
--	  08/05/19 sban3548 Jira OPCOF-2476 Allow prompt to enter catch-weight and not use average weight for Get meat order process
--		
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    10/13/20 bben0556 Brian bent
--                      Project: R44-Jira3222_Sleeve_selection
--
--                      Created procedure "post_float_processing()" that
--                      performs actions needed after inventory is allocated to
--                      the floats.
--
--                      Created procedure "upd_normal_selection_floats()".
--                      This procedure updates any relevant columns for normal selection FLOATS
--                      after the float are built and inventory allocated.
--                      For sleeve selection new column SEL_EQUIP.IS_SLEEVE_SELECTION  
--                      designates if sleeve selection.
--
--    07/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      In procedure "post_float_processing" add call to procedure "pl_xdock_op.update_floats"
--                      to update the FLOATS cross_dock_type,  site_from and site_to.  It is far less risky
--                      to have a separate of FLOATS then try do populate these columns when the float is created.
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Ignore 'X' cross dock type when creating data collection records for catchweights,
--                      clam bed and COOL.  All of this is collected at Site 1.
--                      Modified procedures:
--                         - pCreateOrdCW
--                         - create_ordcb
--                         - create_ord_cool
--
--                      Do not assign float detail piece sequence for 'X' cross dock types.  The piece sequence
--                      was assigned at Site 1.  Site 2 neesd to leave it alone.
--                      Modified procedure:
--                         - update_float_detail_piece_seq
--
--
--    10/06/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47_0-xdock-OPCOF3611_Site_2_XDK_task_pick_qty_incorrect
--
--                      At Site 2 for a route that only has 'X' cross dock orders the door is not always
--                      assigned to the respective ROUTE D_DOOR, C_DOOR, F_DOOR column when using the
--                      SHIP_DOOR table to assign the door.  What we will do is if a route has a 'X' cross dock
--                      order then always assign a door to the ROUTE D_DOOR, C_DOOR, and F_DOOR column when
--                      using the SHIP_DOOR table to assign the door.
--                      Modifed procedure:
--                         - pAssignDoor
--
--    08/04/21 jfan4393 Jane Fang
--                      JIRA:OPCOF-3531-Capture CFA GS1
--                      Create procedure "Create_Ordgs1" to capture CFA GS1
--
----------------------------------------------------------------------------------------------------


    RETURN_PALLET       CONSTANT    INTEGER := 23;
    MSKU_REPLENISHMENT  CONSTANT    INTEGER := 17;

    PROCEDURE   gen_repl_batch (t_route_batch_no NUMBER);
    PROCEDURE   gen_fork_batch (t_route_batch_no NUMBER);
    PROCEDURE   gen_msku_repl_batch (t_route_batch_no NUMBER);
    PROCEDURE   GetSplitPickZone (
        pProdId     VARCHAR2,
        p_CPV       VARCHAR2,
        p_SpZoneId OUT  VARCHAR2);
    PROCEDURE   update_ordd_zone (t_route_batch_no  NUMBER);
    PROCEDURE   print_msku_replen_label (i_route_batch_no_IN    NUMBER,
                       i_pallet_id_len_IN   NUMBER);
    PROCEDURE   validate_ordd_against_ssl (   order_type    ordm.order_type%TYPE,
                        select_type     sel_method.sel_type%TYPE,
                                                error_msg       IN OUT  VARCHAR2,
                                                route_batch_no  route.route_batch_no%TYPE       DEFAULT NULL,
                                                route_no        route.route_no%TYPE             DEFAULT NULL,
                        order_id    ordd.order_id%TYPE      DEFAULT NULL);
    PROCEDURE   pAssignDoor (pRouteNo   VARCHAR2);
    PROCEDURE   pCreateOrdCW (  iRouteBatchNo   route.route_batch_no%TYPE DEFAULT NULL,
                    vRouteNo    route.route_no%TYPE       DEFAULT NULL);

--------------------------------------------------------------------------------
-- Procedure:
--    Create_Ordgs1
--
-- Description:
--    The procedure extract CAF GS1 records into the new ORDGS1 table.
---------------------------------------------------------------------------
	PROCEDURE Create_Ordgs1 (i_route_batch_no   route.route_batch_no%TYPE DEFAULT NULL,
                    i_route_no    route.route_no%TYPE       DEFAULT NULL);
    PROCEDURE RePalletize (RouteBatchNo_in  NUMBER);
    PROCEDURE ZoneBalance (float_num NUMBER);
/*
    PROCEDURE update_cwt_wo_info (
            cs_order_id     ordd.order_id%TYPE,
            ci_order_line_id    ordd.order_line_id%TYPE,
            cs_prod_id      ordd.prod_id%TYPE,
            cs_cpv          ordd.cust_pref_vendor%TYPE,
            ci_uom          ordd.uom%TYPE,
            ci_wo_qty       NUMBER);
*/


---------------------------------------------------------------------------
-- Procedure:
--    create_float_detail_piece_recs
--
-- Description:
--    The procedures creates the appropriate piece level records for the
--    specified route batch number or route number.
--
--    This includes:
--        - ORDCW records
--        - ORDGS1 records
--        - Symbotic case records

---------------------------------------------------------------------------
PROCEDURE create_float_detail_piece_recs
            (i_route_batch_no  IN  route.route_batch_no%TYPE DEFAULT NULL,
             i_route_no        IN  route.route_no%TYPE       DEFAULT NULL);


---------------------------------------------------------------------------
-- Procedure:
--    create_ordcb
--
-- Description:
--    This procedure creates the clambed selection data collection records
--    for a route or wave of routes.
--
--    Records are inserted into table ORDCB.
--
--    It is based on the FLOAT_DETAIL table qty allocated and the uom.
--
--    It is similar to how records are created in the ORDCW and
--    ORD_COOL tables.
--
--    It is expected that FLOAT_DETAIL.BC_ST_PIECE_SEQ is set correctly.
---------------------------------------------------------------------------
PROCEDURE create_ordcb
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL);


---------------------------------------------------------------------------
-- Procedure:
--    create_ord_cool
--
-- Description:
--    This procedure creates the coutry of origin data collection records
--    for order selection for a route or wave of routes.
---------------------------------------------------------------------------
PROCEDURE create_ord_cool
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL);


---------------------------------------------------------------------------
-- Procedure:
--    update_float_detail_piece_seq
--
-- Description:
--    This procedure updates FLOAT_DETAIL.BC_ST_PIECE_SEQ.
---------------------------------------------------------------------------
PROCEDURE update_float_detail_piece_seq
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL);
		  
---------------------------------------------------------------------------
-- Procedure:
--    Auto_Gen_Route
-- Description: Jira419
-- Generates routes that have set up in Route Info if Aguto_gen_Flag ='Y'.
---------------------------------------------------------------------------
PROCEDURE Auto_Gen_Route;

---------------------------------------------------------------------------
-- Procedure:
--    	p_update_meat_ord_cw 
-- Description:
--  	Jira#1671: This procedure will update the catch weight from INV_CASES for every order Item
--
---------------------------------------------------------------------------
PROCEDURE p_update_meat_ord_cw(i_route_batch_no route.route_batch_no%TYPE);

PROCEDURE route_recover_invcases(i_route_no route.route_no%TYPE);


---------------------------------------------------------------------------
-- Procedure:
--    post_float_processing
--
-- Description:
--    This procedure performs actions needed after inventory is allocated to
--    the floats.
--
---------------------------------------------------------------------------
PROCEDURE post_float_processing
         (i_route_batch_no  IN  route.route_batch_no%TYPE    DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE          DEFAULT NULL);



END pl_order_processing;
/


CREATE OR REPLACE
PACKAGE BODY swms.pl_order_processing IS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;  -- Package name.
                                             -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(30) := 'ORDER GENERATION';


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


    PROCEDURE gen_repl_batch (t_route_batch_no NUMBER) IS
        bulk_pull       VARCHAR (1);
        home_slot_sort      VARCHAR (1) := 'Y';
        send_dmd_rpl_to_rf  VARCHAR (1) := 'N';
        new_batch_seq       NUMBER (3);
        new_batch_no        NUMBER (9);
        prev_group_no       NUMBER (5) := -99;
        no_recs         NUMBER (5);
        l_gen_uid       VARCHAR2 (30);
        l_type          VARCHAR2 (3) := 'DMD';
        l_user_id       VARCHAR2 (30) := USER;
        l_d_pikpath     NUMBER (9);
        l_s_pikpath     NUMBER (9);

        CURSOR c_batch (p_home_slot_flag varchar2) IS
            SELECT  r.route_no,
            NVL (f.group_no, -1) group_no,  r.seq_no rt_seq_no, f.zone_id, s1.method_id,
            CEIL (bulk_no / driver_no) max_floats_per_batch,
            f.float_no, f.float_seq, fd.prod_id, f.pallet_id,
            f.home_slot, f.equip_id, f.pallet_pull,
            (f.drop_qty / p.spc) drop_qty,
            DECODE (substr (fd.src_loc, 1, 1),
                'F', r.f_door,
                'C', r.c_door,
                r.d_door) door_no,
            fd.uom, fd.order_id,
            fd.src_loc, fd.cust_pref_vendor,
            (fd.qty_order / p.spc) qty_order, fd.seq_no, r.truck_no,
            (fd.qty_alloc / p.spc) qty_alloc,
            f.parent_pallet_id
              FROM  pm p, sel_method s1,
            route r, floats f, float_detail fd
             WHERE  s1.method_id = r.method_id
               AND  s1.group_no = f.group_no
               AND  r.route_batch_no = t_route_batch_no
               AND  f.route_no = r.route_no
               AND  f.float_no = fd.float_no
           AND  p.prod_id = fd.prod_id
               AND  fd.src_loc IS NOT NULL
                   AND  pallet_pull = 'R'
                   AND  bulk_pull   = 'Y'
               AND  NVL (f.batch_no, 0) = 0
           AND  f.parent_pallet_id IS NULL
             ORDER  BY f.group_no,  r.seq_no, f.zone_id,
                        DECODE (p_home_slot_flag, 'Y', f.home_slot, fd.src_loc)
               FOR  UPDATE OF f.float_no;
    BEGIN
        bulk_pull := pl_common.f_get_syspar ('SEPARATE_BULK', 'N');
        send_dmd_rpl_to_rf := pl_common.f_get_syspar ('SEND_DMD_RPL_TO_RF', 'N');
        home_slot_sort := pl_common.f_get_syspar ('SORT_DMD_REPL_BY_HOME_SLOT', 'N');
        no_recs := 0;
        FOR r_batch IN c_batch (home_slot_sort)
        LOOP
            IF ( (c_batch%ROWCOUNT =  1)
            OR   (MOD (no_recs, r_batch.max_floats_per_batch) = 0)
                OR   (prev_group_no <> r_batch.group_no) )
            THEN
                no_recs := 0;
                    prev_group_no :=  r_batch.group_no;
                SELECT float_batch_no_seq.NEXTVAL
                  INTO new_batch_no
                  FROM DUAL;
            END IF;
            no_recs := no_recs + 1;
            new_batch_seq := MOD (no_recs, r_batch.max_floats_per_batch);
                IF (new_batch_seq = 0) THEN
               new_batch_seq := r_batch.max_floats_per_batch;
            END IF;
            UPDATE floats
               SET batch_no = new_batch_no,
                   batch_seq = DECODE (new_batch_seq, 0,
                                          r_batch.max_floats_per_batch,
                                       new_batch_seq)
             WHERE nvl (batch_no, 0) = 0
               AND float_no = r_batch.float_no;
        UPDATE float_detail
           SET route_no = r_batch.route_no
         WHERE float_no = r_batch.float_no;
        UPDATE  replenlst
           SET  batch_no = new_batch_no
         WHERE  pallet_id = r_batch.pallet_id
           AND  dest_loc = r_batch.home_slot
           AND  type = 'DMD';
        UPDATE  trans
           SET  batch_no = new_batch_no
         WHERE  pallet_id = r_batch.pallet_id
           AND  trans_type = 'RPL'
           AND  user_id = 'ORDER'
           AND  float_no = r_batch.float_no;
        END LOOP;
            COMMIT;
    END gen_repl_batch;

    PROCEDURE gen_fork_batch (t_route_batch_no NUMBER) IS
        bulk_pull              VARCHAR (1);
        new_batch_seq          NUMBER (3);
        new_batch_no           NUMBER (9);
        prev_group_no          NUMBER (5) := -99;
        send_dmd_rpl_to_rf     VARCHAR (1) := 'N';
        no_recs                NUMBER (5);
                l_gen_uid                       VARCHAR2 (30);
                l_type                          VARCHAR2 (3) := 'DMD';
                l_user_id                       VARCHAR2 (30) := USER;
                l_d_pikpath                     NUMBER (9);
                l_s_pikpath                     NUMBER (9);

        CURSOR c_batch IS
            SELECT  r.route_no,
            NVL (f.group_no, -1) group_no,
            r.seq_no rt_seq_no,
            MAX (fd.seq_no) seq_no,
            MAX (fd.src_loc) src_loc,
            s1.method_id,
                   CEIL (bulk_no / driver_no) max_floats_per_batch,
                       f.float_no, f.float_seq, fd.prod_id, f.pallet_id,
                       f.home_slot, f.equip_id, f.pallet_pull,
            (f.drop_qty / p.spc) drop_qty,
                       DECODE (substr (fd.src_loc, 1, 1),
                                       'F', r.f_door,
                                       'C', r.c_door,
                                       r.d_door) door_no,
                       DECODE (pallet_pull,
                               'B', 'BLK',
                               'D', 'BLK',
                               'R', 'DMD',
                               'Y', 'BLK',
                               'UNK') repl_type,
            r.truck_no, p.spc,
            MAX (fd.uom) uom, MAX (fd.order_id) order_id,
            MAX (fd.cust_pref_vendor) cust_pref_vendor,
            SUM (fd.qty_alloc / spc) qty_alloc
              FROM  pm p, sel_method s1, route r, floats f, float_detail fd
             WHERE  s1.method_id = r.method_id
               AND  s1.group_no = f.group_no
               AND  r.route_batch_no = t_route_batch_no
               AND  f.route_no = r.route_no
               AND  f.float_no = fd.float_no
               AND  fd.src_loc IS NOT NULL
           AND  p.prod_id = fd.prod_id
               AND  NVL (f.batch_no, 0) = 0
               AND  DECODE (bulk_pull, 'Y',
                       DECODE (pallet_pull, 'N', 0, 'R', 0, 1),
                       DECODE (pallet_pull, 'N', 0, 1)
                    )  <> 0
             GROUP  BY r.route_no, NVL (f.group_no, -1),
                r.seq_no, s1.method_id,
                   CEIL (bulk_no / driver_no),
                   f.float_no, f.float_seq, fd.prod_id, f.pallet_id,
                   f.home_slot, f.equip_id, f.pallet_pull,
                (f.drop_qty / p.spc),
                   DECODE (substr (fd.src_loc, 1, 1),
                           'F', r.f_door,
                           'C', r.c_door,
                           r.d_door),
                   DECODE (pallet_pull,
                       'B', 'BLK',
                       'D', 'BLK',
                       'R', 'DMD',
                       'Y', 'BLK',
                       'UNK'),
                r.truck_no, p.spc
             ORDER BY NVL (f.group_no, -1), MAX (fd.seq_no), MAX (fd.src_loc);

        l_door              replenlst.door_no%TYPE;
        l_home_slot         floats.home_slot%TYPE;

    BEGIN
        bulk_pull := pl_common.f_get_syspar ('SEPARATE_BULK', 'N');
        IF (bulk_pull = 'Y') THEN
            send_dmd_rpl_to_rf := pl_common.f_get_syspar ('SEND_DMD_RPL_TO_RF', 'N');
        ELSE
            send_dmd_rpl_to_rf := 'N';
        END IF;
        no_recs := 0;
        FOR r_batch IN c_batch
        LOOP
            IF ( (c_batch%ROWCOUNT =  1)
            OR   (MOD (no_recs, r_batch.max_floats_per_batch) = 0)
                OR   (prev_group_no <> r_batch.group_no) )
            THEN
                no_recs := 0;
                    prev_group_no :=  r_batch.group_no;
                SELECT float_batch_no_seq.NEXTVAL
                  INTO new_batch_no
                  FROM DUAL;
            END IF;
            no_recs := no_recs + 1;
            new_batch_seq := MOD (no_recs, r_batch.max_floats_per_batch);
                IF (new_batch_seq = 0) THEN
               new_batch_seq := r_batch.max_floats_per_batch;
            END IF;
            UPDATE floats
               SET batch_no = new_batch_no,
                   batch_seq = DECODE (new_batch_seq, 0,
                                          r_batch.max_floats_per_batch,
                                       new_batch_seq)
             WHERE nvl (batch_no, 0) = 0
               AND float_no = r_batch.float_no;
        UPDATE float_detail
           SET route_no = r_batch.route_no
         WHERE float_no = r_batch.float_no;
        UPDATE  replenlst
           SET  batch_no = new_batch_no
         WHERE  pallet_id = r_batch.pallet_id
           AND  dest_loc = r_batch.home_slot
           AND  type = r_batch.repl_type;
        UPDATE  trans
           SET  batch_no = new_batch_no
         WHERE  pallet_id = r_batch.pallet_id
           AND  trans_type = DECODE (r_batch.repl_type, 'DMD', 'RPL', 'PIK')
           AND  float_no = r_batch.float_no;
        END LOOP;
            COMMIT;
    END gen_fork_batch;

    PROCEDURE gen_msku_repl_batch (t_route_batch_no NUMBER) IS
        bulk_pull           VARCHAR (1);
        home_slot_sort          VARCHAR (1) := 'Y';
        send_dmd_rpl_to_rf      VARCHAR (1) := 'N';
        new_batch_seq           NUMBER (3);
        new_batch_no            NUMBER (9);
        prev_group_no           NUMBER (5) := -99;
        prev_parent_pallet_id       inv.parent_pallet_id%TYPE;
        no_recs             NUMBER (5);
                l_gen_uid                       VARCHAR2 (30);
                l_type                          VARCHAR2 (3) := 'DMD';
                l_user_id                       VARCHAR2 (30) := USER;
                l_d_pikpath                     NUMBER (9);
                l_s_pikpath                     NUMBER (9);
        CURSOR c_batch (p_home_slot_flag varchar2) IS
            SELECT  DISTINCT r.route_no,
            NVL (f.group_no, -1) group_no,  r.seq_no rt_seq_no, f.zone_id, s1.method_id,
            CEIL (bulk_no / driver_no) max_floats_per_batch,
            f.float_no, f.float_seq, fd.prod_id, f.pallet_id,
            f.home_slot, f.equip_id, f.pallet_pull,
            (f.drop_qty / p.spc) drop_qty,
            DECODE (substr (fd.src_loc, 1, 1),
                'F', r.f_door,
                'C', r.c_door,
                r.d_door) door_no,
            fd.uom, fd.order_id,
            fd.src_loc, fd.cust_pref_vendor,
            (fd.qty_order / p.spc) qty_order, fd.seq_no, r.truck_no,
            (fd.qty_alloc / p.spc) qty_alloc,
            f.parent_pallet_id
              FROM  pm p, sel_method s1,
            route r, floats f, float_detail fd
             WHERE  s1.method_id = r.method_id
               AND  s1.group_no = f.group_no
               AND  r.route_batch_no = t_route_batch_no
               AND  f.route_no = r.route_no
               AND  f.float_no = fd.float_no
           AND  p.prod_id = fd.prod_id
               AND  fd.src_loc IS NOT NULL
                   AND  pallet_pull = 'R'
                   AND  bulk_pull   = 'Y'
               AND  NVL (f.batch_no, 0) = 0
           AND  f.parent_pallet_id IS NOT NULL
             ORDER  BY f.parent_pallet_id, NVL (f.group_no, -1), r.seq_no, f.zone_id,
                        DECODE (p_home_slot_flag, 'Y', f.home_slot, fd.src_loc);

    BEGIN
        bulk_pull := pl_common.f_get_syspar ('SEPARATE_BULK', 'N');
        send_dmd_rpl_to_rf := pl_common.f_get_syspar ('SEND_DMD_RPL_TO_RF', 'N');
        home_slot_sort := pl_common.f_get_syspar ('SORT_DMD_REPL_BY_HOME_SLOT', 'N');
        no_recs := 0;
        FOR r_batch IN c_batch (home_slot_sort)
        LOOP
            IF ( (c_batch%ROWCOUNT =  1)
            OR   (prev_parent_pallet_id != r_batch.parent_pallet_id))
            THEN
                no_recs := 0;
                prev_parent_pallet_id := r_batch.parent_pallet_id;
                SELECT  float_batch_no_seq.NEXTVAL
                  INTO  new_batch_no
                  FROM  DUAL;
            END IF;
            no_recs := no_recs + 1;
            UPDATE  floats
               SET  batch_no = new_batch_no,
                batch_seq = no_recs
             WHERE  nvl (batch_no, 0) = 0
               AND  float_no = r_batch.float_no;
            UPDATE  float_detail
               SET  route_no = r_batch.route_no
             WHERE  float_no = r_batch.float_no;
            UPDATE  replenlst
               SET  batch_no = new_batch_no
             WHERE  pallet_id = r_batch.pallet_id
               AND  dest_loc = r_batch.home_slot
               AND  type = 'DMD';
            UPDATE  trans
               SET  batch_no = new_batch_no
             WHERE  pallet_id = r_batch.pallet_id
               AND  trans_type = 'RPL'
               AND  float_no = r_batch.float_no;
        END LOOP;
        COMMIT;
    END gen_msku_repl_batch;

    PROCEDURE print_msku_replen_label (i_route_batch_no_IN  NUMBER,
                       i_pallet_id_len_IN   NUMBER) IS

    CURSOR  c_msku_label (p_route_batch_no NUMBER, p_pallet_id_len NUMBER) IS
        SELECT  RPAD (fd.src_loc, 6) || '~' ||
            LPAD (TO_CHAR (fd.qty_order), 4) || '~' ||
            RPAD (f.home_slot, 6) || '~' ||
            RPAD (p.container, 2) || '~' ||
            /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
            /* Declare prod size unit*/
            RPAD (trim(p.pack), 4) || '~' ||
            RPAD (trim(p.prod_size)||trim(prod_size_unit), 9) || '~' ||
            /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - end */
            RPAD (p.brand, 7) || '~' ||
            RPAD (p.descrip, 30) || '~' ||
            RPAD (f.pallet_id, p_pallet_id_len) || '~' ||
            RPAD (p.mfg_sku, 11) || '~' ||
            RPAD (p.prod_id, 7) || '~' ||
            RPAD (TO_CHAR (f.batch_no), 7) || '~' ||
            RPAD (r.truck_no, 3) || '~' ||
            TO_CHAR (fd.stop_no) || '~' ||
            f.parent_pallet_id || '~'
             fld_text,
            f.batch_no,
            ai.name curr_aisle,
            f.parent_pallet_id,
            sm.label_queue,
            f.ship_date,
            f.float_no,
            fd.src_loc
          FROM  sel_method sm, loc ls, aisle_info ai, loc ld, float_detail fd, floats f, pm p, route r
         WHERE  r.route_batch_no = p_route_batch_no
           AND  f.route_no = r.route_no
           AND  f.pallet_pull = 'R'
           AND  f.parent_pallet_id IS NOT NULL
           AND  fd.float_no = f.float_no
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  ld.logi_loc = f.home_slot
           AND  ai.pick_aisle = ld.pik_aisle
           AND  ls.logi_loc = fd.src_loc
           AND  sm.method_id = r.method_id
           AND  sm.group_no = f.group_no
         ORDER  BY ls.pik_path, f.parent_pallet_id, ld.pik_path;
    CURSOR  c_total (p_batch_no NUMBER) IS
        SELECT  UPPER (SUBSTR (z.descrip, 1, 30)) zone_descr,
            SUM (ROUND (fd.qty_alloc / p.spc)) no_cases,
            SUM (ROUND ((fd.qty_alloc / p.spc) * p.case_cube, 2)) tot_cubes
          FROM  zone z, lzone lz, loc l, pm p, float_detail fd, floats f
         WHERE  f.batch_no = p_batch_no
           AND  fd.float_no = f.float_no
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  l.logi_loc = fd.src_loc
           AND  lz.logi_loc = l.logi_loc
           AND  z.zone_id = lz.zone_id
           AND  z.zone_type = 'PIK'
         GROUP  BY UPPER (SUBSTR (z.descrip, 1, 30));
    l_rec_count NUMBER := 1;
    r_total     c_total%ROWTYPE;
    prev_parent floats.parent_pallet_id%TYPE;
    prev_sdate  DATE;
    prev_batch_no   NUMBER;
    prev_src_loc    loc.logi_loc%TYPE;
    l_print_group   NUMBER;
    l_fld_text  VARCHAR2 (1024);
    lh_seq      NUMBER;
    l_lbl_seq   NUMBER;
    temp        NUMBER;
    BEGIN
        FOR r_msku_label IN c_msku_label (i_route_batch_no_IN, i_pallet_id_len_IN)
        LOOP
        BEGIN
            IF ((l_rec_count = 1)
            OR (prev_parent != r_msku_label.parent_pallet_id))
            THEN
                SELECT  print_group_seq.NEXTVAL
                  INTO  l_print_group
                  FROM  dual;
                OPEN c_total (r_msku_label.batch_no);
                FETCH c_total INTO r_total;
                CLOSE c_total;
                IF (prev_parent IS NOT NULL) THEN
                BEGIN
                    SELECT  0
                      INTO  temp
                      FROM  inv
                     WHERE  parent_pallet_id = prev_parent;
                    RAISE TOO_MANY_ROWS;
                    EXCEPTION
                        WHEN TOO_MANY_ROWS THEN
                            l_lbl_seq := l_lbl_seq + 1;
                            INSERT INTO label_header (batch_no, ship_date, label_seq, label_type, fld_text)
                            VALUES (prev_batch_no, prev_sdate, l_lbl_seq, RETURN_PALLET,
                                RPAD (TO_CHAR (prev_batch_no), 7, ' ') || '~ ' || SUBSTR (prev_src_loc, 1, 2) || '-' ||
                                SUBSTR (prev_src_loc, 3, 2) || '-' ||
                                SUBSTR (prev_src_loc, 5) || '~');
                        WHEN OTHERS THEN NULL;
                END;
                END IF;
                prev_parent := r_msku_label.parent_pallet_id;
                prev_sdate := r_msku_label.ship_date;
                prev_batch_no :=  r_msku_label.batch_no;
                prev_src_loc := r_msku_label.src_loc;
                l_fld_text :=   '  ~' || r_total.zone_descr || '~' || r_msku_label.batch_no || '~' ||
                        r_total.no_cases || '~0~0~' || r_total.tot_cubes || '~' ||
                        r_total.no_cases || '~0~0~';
                lh_seq := lh_seq + 1;
                l_rec_count := l_rec_count + 1;
                l_lbl_seq := 1;
                INSERT INTO label_master (print_group, queue, batch_no, seq)
                VALUES (l_print_group, r_msku_label.label_queue, r_msku_label.batch_no, 1);
                INSERT INTO label_header (batch_no, ship_date, label_seq, label_type, fld_text)
                VALUES (r_msku_label.batch_no, r_msku_label.ship_date, l_lbl_seq, 1, l_fld_text);
                UPDATE  floats
                   SET  status = 'OPN'
                 WHERE  float_no = r_msku_label.float_no;
            END IF;
            l_lbl_seq := l_lbl_seq + 1;
            INSERT INTO label_header (batch_no, ship_date, label_seq, label_type, fld_text)
            VALUES (r_msku_label.batch_no, r_msku_label.ship_date, l_lbl_seq, MSKU_REPLENISHMENT, r_msku_label.fld_text);
        END;
        END LOOP;
        IF (prev_parent IS NOT NULL) THEN
        BEGIN
            SELECT  0
              INTO  temp
              FROM  inv
             WHERE  parent_pallet_id = prev_parent;
            RAISE TOO_MANY_ROWS;
            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    l_lbl_seq := l_lbl_seq + 1;
                    INSERT INTO label_header (batch_no, ship_date, label_seq, label_type, fld_text)
                    VALUES (prev_batch_no, prev_sdate, l_lbl_seq, RETURN_PALLET,
                        RPAD (TO_CHAR (prev_batch_no), 7, ' ') || '~ ' || SUBSTR (prev_src_loc, 1, 2) || '-' ||
                        SUBSTR (prev_src_loc, 3, 2) || '-' ||
                        SUBSTR (prev_src_loc, 5) || '~');
                WHEN OTHERS THEN NULL;
        END;
        END IF;
    END print_msku_replen_label;

    PROCEDURE   update_ordd_zone (t_route_batch_no  NUMBER) IS
        CURSOR  c_route IS
            SELECT  route_no
              FROM  route
             WHERE  route_batch_no = t_route_batch_no;
    BEGIN
        FOR r_route IN c_route
        LOOP
            UPDATE  ordd
               SET  zone_id = NULL
             WHERE  route_no = r_route.route_no;
            COMMIT;
        END LOOP;
        --
        -- This process assumes that every slotted item has
        -- a rank 1 pick slot.
        --
        FOR r_route IN c_route
        LOOP
            --
            -- Step 1.  Update pick zones for case home picks
            --
            UPDATE  ordd o
               SET  zone_id =
                (SELECT lz.zone_id
                   FROM pm p, zone z, lzone lz, loc l, inv i
                  WHERE i.prod_id = o.prod_id
                    AND i.cust_pref_vendor = o.cust_pref_vendor
                    AND i.logi_loc = i.plogi_loc
                    AND l.logi_loc = i.plogi_loc
                    AND l.rank = 1
                    AND p.prod_id = o.prod_id
                    AND p.cust_pref_vendor = o.cust_pref_vendor
                    AND TRUNC (o.qty_ordered/p.spc) > 0
                    AND p.auto_ship_flag = 'N'
                    AND l.uom IN (0, 2)
                    AND lz.logi_loc = l.logi_loc
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PIK'
                    AND ROWNUM = 1)
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            --
            -- Step 2.  Update pick zones for split home picks
            --
            UPDATE  ordd o
               SET  zone_id =
                (SELECT lz.zone_id
                   FROM pm p, zone z, lzone lz, loc l, inv i
                  WHERE i.prod_id = o.prod_id
                    AND i.cust_pref_vendor = o.cust_pref_vendor
                    AND i.logi_loc = i.plogi_loc
                    AND l.logi_loc = i.plogi_loc
                    AND l.rank = 1
                    AND p.prod_id = o.prod_id
                    AND p.cust_pref_vendor = o.cust_pref_vendor
                    AND (MOD (o.qty_ordered, NVL (p.spc, 1)) > 0 OR p.auto_ship_flag = 'Y')
                    AND l.uom IN (0, 1)
                    AND lz.logi_loc = l.logi_loc
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PIK'
                    AND ROWNUM = 1)
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            --
            -- Step 3.  Update pick zones for floating items in main warehouse
            --      or floating items for which both cases and splits are
            --      in the mini-load system or for floating items for which
            --      splits are in the miniload, but the order is in cases.
            --
            UPDATE  ordd o
               SET  zone_id =
                (SELECT lz.zone_id
                   FROM pm p, zone z, lzone lz, loc l, inv i
                  WHERE i.prod_id = o.prod_id
                    AND i.cust_pref_vendor = o.cust_pref_vendor
                    AND l.logi_loc = i.plogi_loc
                    AND p.prod_id = o.prod_id
                    AND p.cust_pref_vendor = o.cust_pref_vendor
                    AND ((p.miniload_storage_ind != 'S') OR
                     (p.miniload_storage_ind = 'S' AND o.uom = 2))
                    AND lz.logi_loc = l.logi_loc
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PIK'
                    AND ROWNUM = 1)
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            --
            -- Step 4.  Update pick zones for items for which cases are in the
            --      main warehouse and the splits are in the mini-load system
            --
            UPDATE  ordd o
               SET  zone_id =
                (SELECT lz.zone_id
                   FROM pm p, zone z, lzone lz, zone z1
                  WHERE p.prod_id = o.prod_id
                    AND p.cust_pref_vendor = o.cust_pref_vendor
                    AND p.miniload_storage_ind = 'S'
                    AND z.zone_id = p.split_zone_id
                    AND z.zone_type = 'PUT'
                    AND lz.logi_loc = z.induction_loc
                    AND z1.zone_id = lz.zone_id
                    AND z1.zone_type = 'PIK'
                    AND ROWNUM = 1)
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            --
            -- Step 5.
            -- All the items with proper pick locations are updated.
            -- All the items in floating locations are updated.
            -- If there is anything else left, update the zones using
            -- last ship slot.
            --
            UPDATE  ordd o
               SET  zone_id =
                (SELECT lz.zone_id
                   FROM zone z, lzone lz, pm p
                  WHERE p.prod_id = o.prod_id
                    AND p.cust_pref_vendor = o.cust_pref_vendor
                    AND p.last_ship_slot IS NOT NULL
                    AND lz.logi_loc = p.last_ship_slot
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PIK')
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            --
            -- Step 6.
            -- Can't find the last ship slot either.
            -- Use the default pick zone for the area, if it is set up
            --
            UPDATE  ordd o
               SET  zone_id =
                (SELECT sa.def_pik_zone
                   FROM swms_areas sa, pm p
                  WHERE p.prod_id = o.prod_id
                    AND p.cust_pref_vendor = o.cust_pref_vendor
                    AND sa.area_code = DECODE (p.area, 'C', 'C', 'F', 'F', 'D'))
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            --
            -- Step 7.
            -- Exhausted all choices. Set the rest of the records' pick zones to UNKP
            --
            UPDATE  ordd o
               SET  zone_id = 'UNKP'
             WHERE  route_no = r_route.route_no
               AND  zone_id IS NULL;
            COMMIT;
        END LOOP;
    END update_ordd_zone;

    PROCEDURE validate_ordd_against_ssl (   order_type  ordm.order_type%TYPE,
                        select_type sel_method.sel_type%TYPE,
                        error_msg   IN OUT  VARCHAR2,
                        route_batch_no  route.route_batch_no%TYPE   DEFAULT NULL,
                        route_no    route.route_no%TYPE     DEFAULT NULL,
                        order_id    ordd.order_id%TYPE      DEFAULT NULL)
    IS
        CURSOR  c_ssl ( p_route_batch_no    NUMBER,
                p_route_no      VARCHAR2,
                p_order_id      VARCHAR2,
                p_sel_type      VARCHAR2,
                p_order_type        VARCHAR2)
        IS

                        SELECT  /*+RULE*/ distinct r.method_id, l.zone_id
                          FROM  route r,
                sel_method sm,
                                lzone l,
                zone z,
                                inv i,
                                ordd o
             WHERE  o.order_id = NVL (p_order_id, o.order_id)
               AND  o.route_no = NVL (p_route_no, o.route_no)
               AND  r.route_batch_no = NVL (p_route_batch_no, r.route_batch_no)
               AND  r.route_no = o.route_no
               AND  i.prod_id = o.prod_id
               AND  i.cust_pref_vendor = o.cust_pref_vendor
               AND  i.status = DECODE (p_order_type, 'VRT', 'HLD', 'AVL')
               AND  ((p_order_type = 'VRT' AND i.qty_alloc > 0) OR
                 (p_order_type != 'VRT' AND i.qty_alloc >= 0))
               AND  l.logi_loc = i.plogi_loc
               AND  z.zone_id = l.zone_id
               AND  z.zone_type = 'PIK'
               AND  sm.method_id = r.method_id
               AND  sm.sel_type = p_sel_type
                           AND  NOT EXISTS (SELECT 0
                                              FROM sel_method_zone smz
                                             WHERE smz.method_id = r.method_id
                                               AND smz.smz_sel_type = p_sel_type
                                               AND smz.zone_id = l.zone_id);
    BEGIN
        error_msg := NULL;
        FOR r_ssl IN c_ssl (route_batch_no, route_no, order_id, select_type, order_type)
        LOOP
            IF (c_ssl%ROWCOUNT = 1) THEN
                error_msg := 'SSL = ' || r_ssl.method_id ||
                        ', sel type = ' || select_type ||
                         '. Zone Id(s) not setup = ';
            END IF;
            error_msg := error_msg || r_ssl.zone_id || ', ';
        END LOOP;
    END;

---------------------------------------------------------------------------
-- Procedure:
--    passign_door
--
-- Description:
--    This procedure assigns the door(s) to the route if the door(s) is null.
--    ROUTE_INFO table used first.
--    Then SHIP_DOOR table.
--
-- Parameters:
--    prouteno  - route begin generated
--
-- Called by:
--    xxxx
--
-- Exceptions raised:
--    xxx
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    10/06/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47_0-xdock-OPCOF3611_Site_2_XDK_task_pick_qty_incorrect
--
--                      At Site 2 for a route that only has 'X' cross dock orders the door is not always
--                      assigned to the respective ROUTE D_DOOR, C_DOOR, F_DOOR column when using the
--                      SHIP_DOOR table to assign the door.  What we will do is if a route has a 'X' cross dock
--                      order then always assign a door to the ROUTE D_DOOR, C_DOOR, and F_DOOR column when
--                      using the SHIP_DOOR table to assign the door.
--
---------------------------------------------------------------------------
PROCEDURE pAssignDoor (pRouteNo VARCHAR2)
IS
   --
   -- This cursor gets the next doors to assign to the route using the SHIP_DOOR table.
   --
   CURSOR cShipDoor
   IS
   SELECT seq_no, assign,
          MAX (DECODE (area, 'C', door_no, NULL)) c_door,
          MAX (DECODE (area, 'D', door_no, NULL)) d_door,
          MAX (DECODE (area, 'F', door_no, NULL)) f_door
     FROM ship_door
    GROUP BY seq_no, assign
    ORDER BY assign, seq_no;

    rShipDoor   cShipDoor%ROWTYPE;

   CURSOR cRoute(vRouteNo VARCHAR2)
   IS
   SELECT c_door,
          d_door,
          f_door
     FROM route r
    WHERE route_no = vRouteNo
      AND ((c_door IS NULL AND EXISTS (SELECT 1 FROM sel_method s
                                        WHERE s.method_id = r.method_id
                                          AND s.door_area = 'C'))
           OR
                  (d_door IS NULL AND EXISTS (SELECT 1 FROM sel_method s
                                               WHERE s.method_id = r.method_id
                                                 AND s.door_area = 'D'))
           OR
                  (f_door IS NULL AND EXISTS (SELECT 1 FROM sel_method s
                                               WHERE s.method_id = r.method_id
                                                 AND s.door_area = 'F')))
      FOR UPDATE OF c_door NOWAIT;

   rRoute  cRoute%ROWTYPE;
   lAssign NUMBER;
BEGIN
   --
   -- Update route doors using the doors in the ROUTE_INFO table if the route/truck is setup in the table.
   --
   UPDATE route r
      SET (c_door, d_door, f_door) =
            (SELECT MAX(NVL(r.c_door, ri.c_door)),
                    MAX(NVL(r.d_door, ri.d_door)),
                    MAX(NVL(r.f_door, ri.f_door))
               FROM route_info ri
              WHERE ri.route_no IN (r.route_no, r.truck_no))
    WHERE r.route_no = pRouteNo
      AND EXISTS (SELECT 0
                    FROM route_info x
                   WHERE x.route_no IN (r.route_no, r.truck_no));

   --
   -- Update route doors using the doors in the SHIP_DOOR table if the route door(s) are still null at this point in processing.
   --
   OPEN cRoute (pRouteNo);
   FETCH cRoute INTO rRoute;
   IF (cRoute%FOUND) THEN
      BEGIN
         OPEN    cShipDoor;
         FETCH   cShipDoor INTO rShipDoor;

         UPDATE route r
            SET (c_door, d_door, f_door) =
                    (SELECT MAX(NVL(r.c_door, DECODE (s.door_area, 'C', rShipDoor.c_door, NULL))),
                            MAX(NVL(r.d_door, DECODE (s.door_area, 'D', rShipDoor.d_door, NULL))),
                            MAX(NVL(r.f_door, DECODE (s.door_area, 'F', rShipDoor.f_door, NULL)))
                       FROM
                            sel_method_zone z,
                            sel_method s,
                            ordd o,
                            lzone l,
                            inv i
                      WHERE
                            o.route_no          = r.route_no
                        AND i.prod_id           = o.prod_id
                        AND i.cust_pref_vendor  = o.cust_pref_vendor
                        AND l.logi_loc          = i.plogi_loc
                        AND s.method_id         = r.method_id
                        AND z.method_id         = s.method_id
                        AND z.group_no          = s.group_no
                        AND z.zone_id           = l.zone_id)
          WHERE  CURRENT OF cRoute;

         --
         -- 10/06/21  Brian Bent
         -- Assign door(s) to the route if the route door(s) still null and the route has 'X' cross dock order.
         --
         UPDATE route r
            SET d_door = rShipDoor.d_door
          WHERE route_no =  pRouteNo
            AND d_door   IS NULL
            AND EXISTS
                     (SELECT 'x'
                        FROM ordm m
                       WHERE m.cross_dock_type = 'X'
                         AND m.route_no        = r.route_no);

         UPDATE route r
            SET c_door = rShipDoor.c_door
          WHERE route_no =  pRouteNo
            AND c_door   IS NULL
            AND EXISTS
                     (SELECT 'x'
                        FROM ordm m
                       WHERE m.cross_dock_type = 'X'
                         AND m.route_no        = r.route_no);

         UPDATE route r
            SET f_door = rShipDoor.f_door
          WHERE route_no =  pRouteNo
            AND f_door   IS NULL
            AND EXISTS
                     (SELECT 'x'
                        FROM ordm m
                       WHERE m.cross_dock_type = 'X'
                         AND m.route_no        = r.route_no);


         --
         -- Update ship_door to select the next set of doors.
         --
         SELECT MAX (assign)
           INTO  lAssign
           FROM  ship_door;

         UPDATE  ship_door
            SET  assign = lAssign + 1
          WHERE  seq_no = rShipDoor.seq_no;

         CLOSE cShipDoor;
      END;
   END IF;

   CLOSE cRoute;
END pAssignDoor;


---------------------------------------------------------------------------
-- Procedure:
--    pCreateOrdCW
--
-- Description:
--    The procedures creates the selection catchweight records in the ORDCW
--    table for the specified route batch number or route number.
--    A record is created for each piece selected.
--
-- Parameters:
--    NOTE: One and only one parameter i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    create_float_detail_piece_recs
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/28/14 bben0556 Symbotic project.
--                      Populate ORDCW.ORDER_SEQ from FLOAT_DETAIL.ORDER_SEQ
--                      Added log messages.
--
--                      Fix the assignment of ordcw.seq_no in procedure
--
--    04/10/15 bben0556 Symbotic project.
--                      "pCreateOrdCW" for a split order, ordcw.uom = 1.
--                      The seq_no was skipping.  In the "split" loop
--                      VALUES clause changed iSpSeq to iVar.
--
--                      Example:
--   ORDER_ID       ORDER_LINE_ID     SEQ_NO        UOM
--   -------------- ------------- ---------- ----------
--   504105919                 16          1          2
--   504105919                 16          2          2
--   504105919                 19          1          2
--   504105919                 19          2          2
--   504105919                 24          1          1  <----   seq_no goes 1, 3, 6
--   504105919                 24          3          1  <----
--   504105919                 24          6          1  <----
--   504105919                 26          1          2
--   504105919                 26          2          2
--   504105919                 26          3          2
--   504105919                 33          1          2
--   504105919                 33          2          2
--   504105919                 35          1          2
--   504105919                 42          1          2
--   504105919                 47          1          2
--   504105919                 49          1          2
--   504105919                 49          2          2
--   504105919                 53          1          2
--   504105919                 53          2          2
--
--
--    10/27/15 prpbcb   Symbotic project.
--                      Bug fix.
--                      When collecting the catchweights with SOS for a normal
--                      selection batch the catchweight is assigned to the
--                      bulk pull ORDCW record when the order-item has both a bulk
--                      pull(s) and normal selection.
--
--                      Changed to create the ORDCW records for normal selection batches
--                      first then bulk pulls.  This matches the order the
--                      FLOAT_DETAIL.BC_ST_PIECE_SEQ is assigned.
--                      This was done by adding the folwlog th the ORDER BY in cursor curOrdCW:
--           DECODE(f.pallet_pull, 'N', 0, 1),  -- Want to process normal selection batches first
--                                              -- so that ordcw.seq_no corresponds to float_detail.bc_st_piece_seq
--
--                      See the main work history dated 10/27/15 for more
--                      information.
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Ignore 'X' cross dock type when creating data collection records for catchweights,
--                      clam bed and COOL.  All of this is collected at Site 1.
--                      Modified cursor "curOrdCW" to exclude 'X' cross dock type.
---------------------------------------------------------------------------
PROCEDURE pCreateOrdCW (iRouteBatchNo  route.route_batch_no%TYPE  DEFAULT NULL,
                        vRouteNo       route.route_no%TYPE        DEFAULT NULL)
IS
--
-- This procedure is called from CRT_order_proc, TP_order_proc
-- and pl_op_vrt_alloc.ProcessVRTOrder packaged procedure.
-- From the procedure it is called with route number and
-- from OP it is called with the route batch number.
-- When called from OP, don't create ORDCW for replenishments
-- as well as VRTs (This would protect from duplicate ORDCWs
-- in case you have a VRT order attached to a main route). When
-- called from VRT procedure don't create records for replenishments
-- but do create for pallet pull = 'D' (VRT pick up). This is done
-- by the two 'pallet_pull != ' conditions in the WHERE clause.
--
--  01/29/19 xzhee5043 JIRA694 update catch_wt_trk='N' for finish goods
--
-- 8/02/2019 sban3548 Jira-OPCOF-2476: Removed Avg.weight logic on SOS and allow to enter CW for getmeat order process 
--
-----------------------------------------------------------------------------

   l_object_name  VARCHAR2(30) := 'pCreateOrdCW';
   l_message      VARCHAR2(1024);   -- Work area.
   
   l_bln_record_processed  BOOLEAN := FALSE;  -- Flag if at least one record selected.

   CURSOR curOrdCW
   IS
   SELECT fd.float_no,
          fd.order_id,
          fd.order_line_id,
          fd.prod_id,
          fd.cust_pref_vendor,
          NVL(fd.uom, 2) uom,
          SUM(fd.qty_alloc) qty_alloc,
          NVL(p.spc, 1) spc,
          f.rowid,
          f.route_no,
          fd.order_seq
     FROM pm p,
          float_detail fd,
          floats f,
          ordd o,
          route r,
          ordm
    WHERE r.route_batch_no    = NVL(iRouteBatchNo, r.route_batch_no)
      AND r.route_no          = NVL(vRouteNo, r.route_no)
      AND f.route_no          = r.route_no
      AND fd.float_no         = f.float_no
      AND o.route_no          = f.route_no
      AND o.order_id          = fd.order_id
      AND o.order_line_id     = fd.order_line_id
      AND o.cw_type           = 'I'
      AND o.status            IN ('SHT', 'OPN')
      AND fd.merge_alloc_flag <> 'M'  -- Leave out the pick from the merge location.
                                      -- We use the pick from the slot.
      AND f.pallet_pull       != 'R'
      AND f.pallet_pull       != DECODE(iRouteBatchNo, NULL, 'X', 'D')
      AND p.prod_id           = fd.prod_id
      AND p.cust_pref_vendor  = fd.cust_pref_vendor
      AND ordm.order_id       = o.order_id
      AND NVL(ordm.cross_dock_type, 'aaa') <> 'X'       -- 09/28/21 Exclude Site 2 cross dock pallets
    GROUP BY fd.float_no,
             f.pallet_pull,
             fd.order_id,
             fd.order_line_id,
             fd.prod_id,
             fd.cust_pref_vendor,
             fd.uom,
             p.spc,
             f.rowid,
             f.route_no,
             fd.order_seq
    ORDER BY fd.order_id,
             fd.order_line_id,
             DECODE(f.pallet_pull, 'N', 0, 1),  -- Want to process normal selection batches first
                                                -- so that ordcw.seq_no corresponds to float_detail.bc_st_piece_seq
             fd.float_no;

   iCases              INTEGER := 0;
   iSplits             INTEGER := 0;
   iVar                INTEGER := 0;
   iCsSeq              INTEGER := 0;
   iSpSeq              INTEGER := 0;
   lPrevOrderId        float_detail.order_id%TYPE;
   lPrevOrderLineId    float_detail.order_line_id%TYPE;
   lRowID              ROWID := NULL;
   lPrevCases          NUMBER := 1;
   lPrevSplits         NUMBER := 1;

   --
   -- Variables to count the exceptions and log at the end of the processing.
   --
   l_num_records_processed         PLS_INTEGER := 0;
   l_num_records_created           PLS_INTEGER := 0;
   l_num_records_existing          PLS_INTEGER := 0;
   l_num_errors                    PLS_INTEGER := 0;

   --
   -- Grand totals
   --
   l_total_num_records_processed   PLS_INTEGER := 0;
   l_total_num_records_created     PLS_INTEGER := 0;
   l_total_num_records_existing    PLS_INTEGER := 0;
   l_total_num_errors              PLS_INTEGER := 0;

BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Starting procedure'
         || '  (iRouteBatchNo['   || TO_CHAR(iRouteBatchNo) || '],'
         || 'vRouteNo['           || vRouteNo               || '])'
         || '  This procedure creates a record in ORDCW for each piece to pick on a wave'
         || ' of routes or a specified route.'
         || '  It is based on the FLOAT_DETAIL table qty allocated and the uom.'
         || '  X cross dock orders are excluded.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   FOR recOrdCW IN curOrdCW
   LOOP
      l_bln_record_processed := TRUE;

      IF ((lPrevOrderId != recOrdCW.order_id) OR (lPrevOrderLineId != recOrdCW.order_line_id))
      THEN
         iCsSeq := 0;
         iSpSeq := 0;
         lRowID := recOrdCW.rowid;
         lPrevCases := 1;
         lPrevSplits := 1;

         --
         -- Log the counts for the order-item.
         --
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:' 
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);


         l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
         l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
         l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
         l_total_num_errors              := l_total_num_errors            + l_num_errors;

         l_num_records_processed  := 0;
         l_num_records_created    := 0;
         l_num_records_existing   := 0;
         l_num_errors             := 0;
      ELSIF lPrevOrderId = recOrdCW.order_id AND
                lPrevOrderLineId = recOrdCW.order_line_id AND
                lRowID != recOrdCW.rowid
      THEN
         lPrevCases := lPrevCases + 1;
         lPrevSplits := lPrevSplits + 1;
      END IF;

            IF (recOrdCW.uom != 1) THEN
                iCases := TRUNC (recOrdCW.qty_alloc / recOrdCW.spc);
                iSplits := MOD (recOrdCW.qty_alloc, recOrdCW.spc);

                IF lPrevOrderId = recOrdCW.order_id AND
                    lPrevOrderLineId = recOrdCW.order_line_id AND
                    lRowID != recOrdCW.rowid
                THEN
                    iCases := iCases + lPrevCases - 1;
                    iSplits := iSplits + lPrevSplits - 1;
                END IF;
            ELSE
                iCases := 0;
                iSplits := recOrdCW.qty_alloc;
            END IF;

      --
      -- Log message for info/debugging.
      --
      l_message := 'Starting curOrdCW loop.  Processing order line item:'
         || '  order_id['                  || recOrdCW.order_id               || ']'
         || '  order_line_id['             || TO_CHAR(recOrdCW.order_line_id) || ']'
         || '  prod_id['                   || recOrdCW.prod_id                || ']'
         || '  route_no['                  || recOrdCW.route_no               || ']'
         || '  uom['                       || TO_CHAR(recOrdCW.uom)           || ']'
         || '  iVar['                      || TO_CHAR(iVar)                   || ']'
         || '  order_seq['                 || TO_CHAR(recOrdCW.order_seq)     || ']'
         || '  spc['                       || TO_CHAR(recOrdCW.spc)           || ']'
         || '  sum qty alloc(in splits)['  || TO_CHAR(recOrdCW.qty_alloc)     || ']'
         || '  iCases['                    || TO_CHAR(iCases)                 || ']'
         || '  iSplits['                   || TO_CHAR(iSplits)                || ']';

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                     NULL, NULL, ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || '  ' || l_message);



            IF (iCases > 0) THEN
            BEGIN
                FOR iVar IN lPrevCases..iCases
                LOOP
                   l_num_records_processed := l_num_records_processed + 1;
                   --
                   -- Debug stuff.
                   --
                   DBMS_OUTPUT.PUT_LINE(l_object_name
                        || '  Before inserting ordcw case record.'
                        || '  order_id['      || recOrdCW.order_id || ']'
                        || '  order_line_id[' || to_char(recOrdCW.order_line_id) || ']'
                        || '  prod_id['       || recOrdCW.prod_id || ']'
                        || '  iVar['          || to_char(iVar) || ']'
                        || '  float_no['      || to_char(recOrdCW.float_no) || ']'
                        || '  order_seq['     || to_char(recOrdCW.order_seq) || ']');

                    BEGIN
                        INSERT INTO ordcw
                            (order_id,
                             order_line_id,
                             seq_no,
                             prod_id,
                             cust_pref_vendor,
                             catch_weight,
                             cw_type,
                             uom,
                             cw_float_no,
                             order_seq)
                        VALUES (
                            recOrdCW.order_id,
                            recOrdCW.order_line_id,
                            iVar,
                            recOrdCW.prod_id,
                            recOrdCW.cust_pref_vendor,
                            NULL,  -- JIRA 2476
                            'I',
                            2,
                            recOrdCW.float_no,
                            recOrdCW.order_seq);

                       l_num_records_created := l_num_records_created + 1;
                    EXCEPTION
                        WHEN DUP_VAL_ON_INDEX THEN
                           l_num_records_existing := l_num_records_existing + 1;
                        WHEN OTHERS THEN
                           l_num_errors := l_num_errors + 1;

                            pl_log.ins_msg('I',
                                'ADDORDCW',
                                'ACW CS: error[' ||
                                TO_CHAR(SQLCODE) ||
                                '] r[' ||
                                recOrdCW.route_no ||
                                    '] rb[' || to_char(iRouteBatchNo) ||
                                    '] prevOid[' || lPrevOrderId || '/' ||
                                to_char(lPrevOrderLineId) ||
                                    '] curOid[' || recOrdCW.order_id ||
                                '/' || to_char(recOrdCW.order_line_id) ||
                                    ' q[' || to_char(recOrdCW.qty_alloc) || ']',
                                SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);
                    END;
                END LOOP;
            END;
            END IF;

            IF (iSplits > 0) THEN
            BEGIN
                FOR iVar IN lPrevSplits ..iSplits
                LOOP
                   l_num_records_processed := l_num_records_processed + 1;

                   iSpSeq := iSpSeq + iVar;

                   --
                   -- Debug stuff.
                   --
                   DBMS_OUTPUT.PUT_LINE(l_object_name
                        || '  Before inserting ordcw split record.'
                        || '  order_id['      || recOrdCW.order_id || ']'
                        || '  order_line_id[' || to_char(recOrdCW.order_line_id) || ']'
                        || '  prod_id['       || recOrdCW.prod_id || ']'
                        || '  iVar['          || to_char(iVar) || ']'
                        || '  float_no['      || to_char(recOrdCW.float_no) || ']'
                        || '  order_seq['     || to_char(recOrdCW.order_seq) || ']');

                    BEGIN
                        INSERT INTO ordcw
                            (order_id,
                             order_line_id,
                             seq_no,
                             prod_id,
                             cust_pref_vendor,
                             catch_weight,
                             cw_type,
                             uom,
                             cw_float_no,
                             order_seq)
                        VALUES
                           (recOrdCW.order_id,
                            recOrdCW.order_line_id,
                            iVar,
                            recOrdCW.prod_id,
                            recOrdCW.cust_pref_vendor,
                            NULL, -- JIRA 2476
                            'I',
                            1,
                            recOrdCW.float_no,
                            recOrdCW.order_seq);

                       l_num_records_created := l_num_records_created + 1;
                    EXCEPTION
                        WHEN DUP_VAL_ON_INDEX THEN
                           l_num_records_existing := l_num_records_existing + 1;
                        WHEN OTHERS THEN
                           l_num_errors := l_num_errors + 1;

                            pl_log.ins_msg('I',
                                'ADDORDCW',
                                'ACW SP: error[' ||
                                TO_CHAR(SQLCODE) ||
                                '] r[' ||
                                recOrdCW.route_no ||
                                    '] rb[' || to_char(iRouteBatchNo) ||
                                    '] prevOid[' || lPrevOrderId || '/' ||
                                to_char(lPrevOrderLineId) ||
                                    '] curOid[' || recOrdCW.order_id ||
                                '/' || to_char(recOrdCW.order_line_id) ||
                                    ') q[' || to_char(recOrdCW.qty_alloc) || ']',
                                NULL, NULL);
                    END;
                END LOOP;
                iSpSeq := iSpSeq + iSplits;
            END;
            END IF;
            lPrevOrderId := recOrdCW.order_id;
            lPrevOrderLineId := recOrdCW.order_line_id;
            lRowID := recOrdCW.rowid;
            lPrevCases := iCases;
            lPrevSplits := iSplits;
        END LOOP;

   --
   -- For the last order-item processed.
   --
   l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
   l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
   l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
   l_total_num_errors              := l_total_num_errors            + l_num_errors;

   --
   -- Log the counts for the last order-item.  But only if at least one record processed.
   --
   IF (l_bln_record_processed = TRUE) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:' 
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   END IF;

   --
   -- Log the total counts.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        ' Totals counts:'
                     || '  l_total_num_records_processed['  || TO_CHAR(l_total_num_records_processed)  || ']'
                     || '  l_total_num_records_created['    || TO_CHAR(l_total_num_records_created)    || ']'
                     || '  l_total_num_records_existing['   || TO_CHAR(l_total_num_records_existing)   || ']'
                     || '  l_total_num_errors['             || TO_CHAR(l_total_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   --
   -- Log when done.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (iRouteBatchNo['   || TO_CHAR(iRouteBatchNo) || '],'
                     || 'vRouteNo['           || vRouteNo               || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);


END pCreateOrdCW;

---------------------------------------------------------------------------
-- Procedure:
--    Create_Ordgs1
--
-- Description:
--    The procedures creates the GS1 records in the ORDGS1
--    table for the specified route batch number or route number.
--    A record is created for each piece selected.
--
-- Parameters:
--    NOTE: One and only one parameter i_route_batch_no and i_route_no can
--          be populated.
-- Input:
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    create_float_detail_piece_recs
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    8/5/21   jfan4393 JIRA:OPCOF-3531 CFA PROJECT
--                      Created procedure Create_Ordgs1
--    8/17/21  jfan4393 Updated Float table for the GS1_TRK flag
--
---------------------------------------------------------------------------
PROCEDURE Create_Ordgs1 (i_route_batch_no  route.route_batch_no%TYPE  DEFAULT NULL,
                        i_route_no       route.route_no%TYPE        DEFAULT NULL)
IS

   l_object_name  VARCHAR2(30) := 'Create_Ordgs1';
   l_message      VARCHAR2(1024);

   l_bln_record_processed  BOOLEAN := FALSE;  -- Flag if at least one record selected.

   CURSOR c_ordgs1
   IS
   SELECT fd.float_no,
          fd.order_id,
          fd.order_line_id,
          fd.prod_id,
          fd.cust_pref_vendor,
          NVL(fd.uom, 2) uom,
          SUM(fd.qty_alloc) qty_alloc,
          NVL(p.spc, 1) spc,
          f.rowid,
          f.route_no,
          fd.order_seq,
	  om.ship_date,
	  om.cust_po
     FROM pm p,
          float_detail fd,
          floats f,
          ordd o,
          route r,
	  ordm om,
	  gs1_cust_item_maint gs1
    WHERE r.route_batch_no    = NVL(i_route_batch_no, r.route_batch_no)
      AND r.route_no          = NVL(i_route_no, r.route_no)
      AND f.route_no          = r.route_no
      AND fd.float_no         = f.float_no
      AND o.route_no          = f.route_no
      AND o.order_id          = fd.order_id
      AND o.order_line_id     = fd.order_line_id
      AND om.cust_id          = gs1.cust_id
      AND om.order_id         = o.order_id
      AND om.route_no         = o.route_no
      AND o.prod_id           = gs1.prod_id
      AND gs1.gs1_enabled     = 'Y'
      AND o.status            IN ('SHT', 'OPN')
      AND fd.merge_alloc_flag <> 'M'
      AND f.pallet_pull       != 'R'
      AND f.pallet_pull       != DECODE(i_route_batch_no, NULL, 'X', 'D')
      AND p.prod_id           = fd.prod_id
      AND p.cust_pref_vendor  = fd.cust_pref_vendor
    GROUP BY fd.float_no,
             f.pallet_pull,
             fd.order_id,
             fd.order_line_id,
             fd.prod_id,
             fd.cust_pref_vendor,
             fd.uom,
             p.spc,
             f.rowid,
             f.route_no,
             fd.order_seq,
	     o.uom,
	     om.ship_date,
	     om.cust_po
    ORDER BY fd.order_id,
             fd.order_line_id,
             DECODE(f.pallet_pull, 'N', 0, 1),
             fd.float_no;

   l_cases              INTEGER := 0;
   l_splits             INTEGER := 0;
   l_var                INTEGER := 0;
   l_cs_seq             INTEGER := 0;
   l_sp_seq             INTEGER := 0;
   l_prev_order_id      float_detail.order_id%TYPE;
   l_prev_order_line_id float_detail.order_line_id%TYPE;
   l_row_id             ROWID := NULL;
   l_prev_cases         NUMBER := 1;
   l_prev_splits        NUMBER := 1;

   -- Variables to count the exceptions and log at the end of the processing.
   l_num_records_processed         PLS_INTEGER := 0;
   l_num_records_created           PLS_INTEGER := 0;
   l_num_records_existing          PLS_INTEGER := 0;
   l_num_errors                    PLS_INTEGER := 0;

   -- Grand totals
   l_total_num_records_processed   PLS_INTEGER := 0;
   l_total_num_records_created     PLS_INTEGER := 0;
   l_total_num_records_existing    PLS_INTEGER := 0;
   l_total_num_errors              PLS_INTEGER := 0;

BEGIN
   -- Log starting the procedure.
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Starting procedure'
         || '  (i_route_batch_no['   || TO_CHAR(i_route_batch_no) || '],'
         || 'i_route_no['            || i_route_no               || '])'
         || '  This procedure creates a record in ORDGS1 for each piece to pick on a wave'
         || ' of routes or a specified route.'
         || '  It is based on the FLOAT_DETAIL table qty allocated and the uom.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   FOR recordgs1 IN c_ordgs1
   LOOP
      l_bln_record_processed := TRUE;

      IF ((l_prev_order_id != recordgs1.order_id) OR (l_prev_order_line_id != recordgs1.order_line_id))
      THEN
         l_cs_seq := 0;
         l_sp_seq := 0;
         l_row_id := recordgs1.rowid;
         l_prev_cases := 1;
         l_prev_splits := 1;

         -- Log the counts for the order-item.
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);


         l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
         l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
         l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
         l_total_num_errors              := l_total_num_errors            + l_num_errors;

         l_num_records_processed  := 0;
         l_num_records_created    := 0;
         l_num_records_existing   := 0;
         l_num_errors             := 0;
      ELSIF l_prev_order_id = recordgs1.order_id AND
            l_prev_order_line_id = recordgs1.order_line_id AND
            l_row_id != recordgs1.rowid
      THEN
         l_prev_cases := l_prev_cases + 1;
         l_prev_splits := l_prev_splits + 1;
      END IF;

      IF (recordgs1.uom != 1) THEN
	 l_cases  := TRUNC (recordgs1.qty_alloc / recordgs1.spc);
	 l_splits := MOD (recordgs1.qty_alloc, recordgs1.spc);

	 IF l_prev_order_id = recordgs1.order_id AND
	    l_prev_order_line_id = recordgs1.order_line_id AND
	    l_row_id != recordgs1.rowid
	 THEN
	    l_cases := l_cases + l_prev_cases - 1;
	    l_splits := l_splits + l_prev_splits - 1;
	 END IF;
       ELSE
	  l_cases  := 0;
	  l_splits := recordgs1.qty_alloc;
       END IF;

      -- Log message for info/debugging.
      l_message := 'Starting c_ordgs1 loop.  Processing order line item:'
         || '  order_id['                  || recordgs1.order_id               || ']'
         || '  order_line_id['             || TO_CHAR(recordgs1.order_line_id) || ']'
         || '  prod_id['                   || recordgs1.prod_id                || ']'
         || '  route_no['                  || recordgs1.route_no               || ']'
         || '  uom['                       || TO_CHAR(recordgs1.uom)           || ']'
         || '  l_var['                     || TO_CHAR(l_var)                   || ']'
         || '  order_seq['                 || TO_CHAR(recordgs1.order_seq)     || ']'
         || '  spc['                       || TO_CHAR(recordgs1.spc)           || ']'
         || '  sum qty alloc(in splits)['  || TO_CHAR(recordgs1.qty_alloc)     || ']'
         || '  l_cases['                   || TO_CHAR(l_cases)                 || ']'
         || '  l_splits['                  || TO_CHAR(l_splits)                || ']';

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                     NULL, NULL, ct_application_function, gl_pkg_name);

		IF (l_cases > 0) THEN
		BEGIN
			FOR l_var IN l_prev_cases..l_cases
			LOOP
			   l_num_records_processed := l_num_records_processed + 1;
				BEGIN
					INSERT INTO ordgs1
						(order_id,
						 order_line_id,
						 seq_no,
						 route_no,
						 prod_id,
						 cust_pref_vendor,
						 shipped_date,
						 uom,
						 cust_po,
						 add_user,
						 float_no,
						 order_seq)
					VALUES (
						recordgs1.order_id,
						recordgs1.order_line_id,
						l_var,
						recordgs1.route_no,
						recordgs1.prod_id,
						recordgs1.cust_pref_vendor,
						recordgs1.ship_date,
						2,
						recordgs1.cust_po,
						user,
						recordgs1.float_no,
						recordgs1.order_seq);

				   l_num_records_created := l_num_records_created + 1;
				EXCEPTION
					WHEN DUP_VAL_ON_INDEX THEN
					   l_num_records_existing := l_num_records_existing + 1;
					WHEN OTHERS THEN
					   l_num_errors := l_num_errors + 1;

						pl_log.ins_msg('I',
							'ADDORDGS1',
							'ACW CS: error[' ||
							TO_CHAR(SQLCODE) ||
							'] r[' ||
							recordgs1.route_no ||
								'] rb[' || to_char(i_route_batch_no) ||
								'] prevOid[' || l_prev_order_id || '/' ||
							to_char(l_prev_order_line_id) ||
								'] curOid[' || recordgs1.order_id ||
							'/' || to_char(recordgs1.order_line_id) ||
								' q[' || to_char(recordgs1.qty_alloc) || ']',
							SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);
				END;
			END LOOP;
		END;
		END IF;

		IF (l_splits > 0) THEN
		BEGIN
			FOR l_var IN l_prev_splits ..l_splits
			LOOP
			   l_num_records_processed := l_num_records_processed + 1;
			   l_sp_seq := l_sp_seq + l_var;
				BEGIN
				   INSERT INTO ordgs1
						(order_id,
						 order_line_id,
						 seq_no,
						 route_no,
						 prod_id,
						 cust_pref_vendor,
						 shipped_date,
						 uom,
						 cust_po,
						 add_user,
						 float_no,
						 order_seq)
					VALUES (
						recordgs1.order_id,
						recordgs1.order_line_id,
						l_var,
						recordgs1.route_no,
						recordgs1.prod_id,
						recordgs1.cust_pref_vendor,
						recordgs1.ship_date,
						1,
						recordgs1.cust_po,
						user,
						recordgs1.float_no,
						recordgs1.order_seq);
				   l_num_records_created := l_num_records_created + 1;
				EXCEPTION
					WHEN DUP_VAL_ON_INDEX THEN
					   l_num_records_existing := l_num_records_existing + 1;
					WHEN OTHERS THEN
					   l_num_errors := l_num_errors + 1;

						pl_log.ins_msg('I',
							'ADDORDGS1',
							'ACW SP: error[' ||
							TO_CHAR(SQLCODE) ||
							'] r[' ||
							recordgs1.route_no ||
								'] rb[' || to_char(i_route_batch_no) ||
								'] prevOid[' || l_prev_order_id || '/' ||
							to_char(l_prev_order_line_id) ||
								'] curOid[' || recordgs1.order_id ||
							'/' || to_char(recordgs1.order_line_id) ||
								') q[' || to_char(recordgs1.qty_alloc) || ']',
							NULL, NULL);
				END;
			END LOOP;
			l_sp_seq := l_sp_seq + l_splits;
		END;
		END IF;
        l_prev_order_id := recordgs1.order_id;
        l_prev_order_line_id := recordgs1.order_line_id;
        l_row_id := recordgs1.rowid;
        l_prev_cases := l_cases;
        l_prev_splits := l_splits;

	-- Update Float table for the GS1_TRK flag jfan4393 08/17/21
	    UPDATE float_detail fd
		SET fd.gs1_trk = 'Y'
        WHERE fd.float_no  = recordgs1.float_no
		AND fd.order_line_id = recordgs1.order_line_id;
	END LOOP;

   -- For the last order-item processed.
   l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
   l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
   l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
   l_total_num_errors              := l_total_num_errors            + l_num_errors;

   -- Log the counts for the last order-item.  But only if at least one record processed.
   IF (l_bln_record_processed = TRUE) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   END IF;

   -- Log the total counts.
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        ' Totals counts:'
                     || '  l_total_num_records_processed['  || TO_CHAR(l_total_num_records_processed)  || ']'
                     || '  l_total_num_records_created['    || TO_CHAR(l_total_num_records_created)    || ']'
                     || '  l_total_num_records_existing['   || TO_CHAR(l_total_num_records_existing)   || ']'
                     || '  l_total_num_errors['             || TO_CHAR(l_total_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   -- Log when done.
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (i_route_batch_no['   || TO_CHAR(i_route_batch_no) || '],'
                     || 'i_route_no['            || i_route_no               || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

END Create_Ordgs1;


    PROCEDURE   GetSplitPickZone (
        pProdId     VARCHAR2,
        p_CPV       VARCHAR2,
        p_SpZoneId OUT  VARCHAR2) IS
        SKIP_REST   EXCEPTION;

        CURSOR  c_scene1 IS
            SELECT  l.zone_id
              FROM  zone z, lzone l, inv i
             WHERE  i.inv_uom = 1
               AND  i.prod_id = pProdId
               AND  i.cust_pref_vendor = p_CPV
               AND  i.logi_loc = i.plogi_loc
               AND  l.logi_loc = i.plogi_loc
               AND  z.zone_id = l.zone_id
               AND  z.zone_type = 'PIK'
               AND  ROWNUM = 1;
        CURSOR  c_scene2 IS
            SELECT  DISTINCT (lpicz.zone_id)
              FROM  lzone lpicz, zone picz, zone putz, pm p
             WHERE  p.prod_id = pProdId
               AND  p.cust_pref_vendor = p_CPV
               AND  p.split_zone_id IS NOT NULL
               AND  putz.zone_id = p.split_zone_id
               AND  putz.zone_type = 'PUT'
               AND  putz.rule_id = 3
               AND  putz.induction_loc IS NOT NULL
               AND  lpicz.logi_loc = putz.induction_loc
               AND  picz.zone_id = lpicz.zone_id
               AND  picz.zone_type = 'PIK';
        CURSOR  c_scene3 IS
            SELECT  zon_id
              FROM  (
                SELECT  DISTINCT DECODE (i.logi_loc, i.plogi_loc, -1, 0) sort_field,
                    l.zone_id zon_id
                  FROM  zone z, lzone l, inv i
                 WHERE  i.prod_id = pProdId
                   AND  i.cust_pref_vendor = p_CPV
                   AND  l.logi_loc = i.plogi_loc
                   AND  z.zone_id = l.zone_id
                   AND  z.zone_type = 'PIK'
                 ORDER  BY DECODE (i.logi_loc, i.plogi_loc, -1, 0)
              )
             WHERE  ROWNUM = 1;
    BEGIN

        /*
        ** Find the split pick zone for the item
        **
        ** There are 4 different scenarios
        **
        ** 1.   Item has a separate split home
        **      split pick zone = pick zone of the split home
        ** 2.   Splits for the item are in the miniload and inventory records exist for splits
        **      split pick zone = pick zone of the miniload location of the miniload
        ** 3.   Splits for the item are in the miniload but inventory records does not exist for splits
        **      split pick zone = pick zone of the induction location of the miniload
        ** 4.   Splits are not separated from cases
        **      split pick zone = case pick zone
        **
        */
        /*
        ** Scenario 1
        ** The ROWNUM condition is added just to make sure that the SQL doesn't
        ** produce wrong results in the rare situation that there are multiple
        ** split homes and they are in different pick zones.
        */
        OPEN c_scene1;
        FETCH c_scene1 INTO p_spZoneId;
        IF (c_scene1%FOUND) THEN
            CLOSE c_scene1;
            RAISE SKIP_REST;
        END IF;
        CLOSE c_scene1;
        /*
        ** Scenario 1 was unsuccessful. Scenario 2 and 3 are handled together
        */
        OPEN c_scene2;
        FETCH c_scene2 INTO p_spZoneId;
        IF (c_scene2%FOUND) THEN
            CLOSE c_scene2;
            RAISE SKIP_REST;
        END IF;
        CLOSE c_scene2;
        /*
        ** All 3 scenarios failed. split pick zone is the same as case pick zone.
        ** If the item is slotted, then it should pick up the pick zone of the home slot.
        ** If not, it is a floating item, so whatever pick zone comes back is good.
        ** The ORDER BY clause in the SQL does this trick.
        */
        OPEN c_scene3;
        FETCH c_scene3 INTO p_spZoneId;
        IF (c_scene3%NOTFOUND) THEN
            p_SpZoneId := 'UNKP';
        END IF;
        CLOSE c_scene3;
DBMS_OUTPUT.PUT_LINE ('Zone Id = ' || p_SpZoneId);
    EXCEPTION
        WHEN SKIP_REST THEN
DBMS_OUTPUT.PUT_LINE ('Zone Id in SKIP_REST = ' || p_SpZoneId);
            NULL;
    END GetSplitPickZone;


-----------------------------------------------------------------------------	
---CRQ 46545: Repalletize logic
---6000010128: lnic4226: update float_detail sequence after/before moving the stops
-----------------------------------------------------------------------------
    PROCEDURE RePalletize (RouteBatchNo_in    NUMBER) IS

        CURSOR    stop_1_fwd_cur (pRouteBatchNo    NUMBER) IS
        SELECT    c.*,
                (SELECT    MAX (float_no)
                   FROM    floats
                  WHERE    route_no = c.route_no
                    AND group_no = c.group_no
                    AND TRUNC (b_stop_no) = 1) max_stop_1_float
          FROM (
            SELECT    r.route_batch_no, f.route_no, f.group_no, f.float_no,
                    f.b_stop_no, f.e_stop_no, se.high_cube * se.no_of_zones max_float_cube,
                    CASE f.comp_code
                        WHEN 'C' THEN se.repallet_cube_clr
                        WHEN 'D' THEN se.repallet_cube_dry
                        ELSE se.repallet_cube_frz
                    END repallet_cube,
                    SUM (DECODE (TRUNC (stop_no), 1, cube, 0)) stop_1_cube, SUM (DECODE (TRUNC (stop_no), 1, 0, cube)) others
              FROM    sel_equip se, route r, sel_method s, floats f, float_detail fd
             WHERE    f.pallet_pull = 'N'
               AND    r.route_no = f.route_no
               AND    s.method_id = r.method_id
               AND    s.group_no = f.group_no
               AND    s.sel_type = 'NOR'
               AND    s.merge_group_no IS NULL
               AND    fd.float_no = f.float_no
               AND    se.equip_id = f.equip_id
               AND    r.route_batch_no = pRouteBatchNo
             GROUP    BY  r.route_batch_no, f.route_no, f.group_no, f.float_no, f.comp_code, repallet_cube_clr,
                    repallet_cube_dry, repallet_cube_frz, f.b_stop_no, f.e_stop_no,
                    se.high_cube, se.no_of_zones, se.pct_float_overcube
            HAVING    SUM (DECODE (TRUNC (stop_no), 1, cube, 0)) > 0
               AND    SUM (DECODE (TRUNC (stop_no), 1, 0, cube)) > 0
            ) c
         WHERE EXISTS (
                  SELECT 0
                    FROM floats f1
                   WHERE f1.route_no = c.route_no
                     AND f1.group_no = c.group_no
                     AND f1.float_no > c.float_no)
      ORDER BY route_no, group_no, float_no;
      
      
         CURSOR    stop_1_bck_cur (pRouteBatchNo    NUMBER) IS
        SELECT    c.*,
                (SELECT    MAX (float_no)
                   FROM    floats
                  WHERE    route_no = c.route_no
                    AND group_no = c.group_no
                    AND TRUNC (b_stop_no) = 1) max_stop_1_float
          FROM (
            SELECT    r.route_batch_no, f.route_no, f.group_no, f.float_no,
                    f.b_stop_no, f.e_stop_no, se.high_cube * se.no_of_zones max_float_cube, 
                    CASE f.comp_code
                        WHEN 'C' THEN se.repallet_cube_clr
                        WHEN 'D' THEN se.repallet_cube_dry
                        ELSE se.repallet_cube_frz
                    END repallet_cube,
                    SUM (DECODE (TRUNC (stop_no), 1, cube, 0)) stop_1_cube, SUM (DECODE (TRUNC (stop_no), 1, 0, cube)) others
              FROM    sel_equip se, route r, sel_method s, floats f, float_detail fd
             WHERE    f.pallet_pull = 'N'
               AND    r.route_no = f.route_no
               AND    s.method_id = r.method_id
               AND    s.group_no = f.group_no
               AND    s.sel_type = 'NOR'
               AND    s.merge_group_no IS NULL
               AND    fd.float_no = f.float_no
               AND    se.equip_id = f.equip_id
               AND    r.route_batch_no = pRouteBatchNo
             GROUP    BY  r.route_batch_no, f.route_no, f.group_no, f.float_no, f.comp_code, repallet_cube_clr,
                    repallet_cube_dry, repallet_cube_frz, f.b_stop_no, f.e_stop_no,
                    se.high_cube, se.no_of_zones, se.pct_float_overcube
            HAVING    SUM (DECODE (TRUNC (stop_no), 1, cube, 0)) > 0
            ) c
         WHERE EXISTS (
                  SELECT 0
                    FROM floats f1
                   WHERE f1.route_no = c.route_no
                     AND f1.group_no = c.group_no
                     AND f1.float_no > c.float_no)
      ORDER BY route_no, group_no, float_no;


        CURSOR other_stops_fwd_cur (pRouteBatchNo NUMBER) IS
        SELECT    c.*
          FROM    (
                SELECT    r.route_batch_no, r.route_no, f1.group_no, f1.float_no from_float_no, f2.float_no to_float_no,
                    f1.b_stop_no, TRUNC (f1.e_stop_no) to_e_stop, TRUNC (f2.b_stop_no) repal_stop, f2.e_stop_no f2_e_stop_no,
                    se.high_cube * se.no_of_zones max_float_cube, 
                    DECODE (f1.comp_code, 'C', se.repallet_cube_clr, 'D', se.repallet_cube_dry, se.repallet_cube_frz) repal_cube
                  FROM    sel_method sm, route r, sel_equip se, floats f1, floats f2
                 WHERE    r.route_no = f1.route_no
                   AND    f2.route_no = f1.route_no
                   AND    f2.group_no = f1.group_no
                   AND    f2.float_no != f1.float_no
                   AND    f2.float_no = f1.float_no + 1
                   AND    f2.b_stop_no = f1.e_stop_no
                   AND    f1.pallet_pull = 'N'
                   AND    f2.pallet_pull = 'N'
                   AND    sm.method_id = r.method_id
                   AND    sm.group_no = f1.group_no
                   AND    sm.sel_type = 'NOR'
                   AND    DECODE (f1.comp_code, 'C', se.repallet_cube_clr, 'D', se.repallet_cube_dry, se.repallet_cube_frz) IS NOT NULL
                   AND    se.equip_id = f1.equip_id
                   AND    f1.e_stop_no >= 2
                   AND    sm.merge_group_no IS NULL
                   AND    r.route_batch_no = pRouteBatchNo) c
         WHERE    EXISTS (
                SELECT    SUM (cube)
                  FROM    float_detail fd
                 WHERE    fd.float_no = c.from_float_no
                   AND    TRUNC (fd.stop_no) = TRUNC (c.repal_stop))
         ORDER    BY c.route_no, c.group_no, c.to_float_no desc;

         
        CURSOR other_stops_bck_cur (pRouteBatchNo NUMBER) IS
        SELECT    c.*
          FROM    (
                SELECT    r.route_batch_no, r.route_no, f1.group_no, f1.float_no to_float_no, f2.float_no from_float_no,
                    f1.b_stop_no, TRUNC (f1.e_stop_no) to_e_stop, TRUNC (f2.b_stop_no) repal_stop, f2.e_stop_no f2_e_stop_no,
                    se.high_cube * se.no_of_zones max_float_cube, 
                    DECODE (f1.comp_code, 'C', se.repallet_cube_clr, 'D', se.repallet_cube_dry, se.repallet_cube_frz) repal_cube
                  FROM    sel_method sm, route r, sel_equip se, floats f1, floats f2
                 WHERE    r.route_no = f1.route_no
                   AND    f2.route_no = f1.route_no
                   AND    f2.group_no = f1.group_no
                   AND    f2.float_no != f1.float_no
                   AND    f2.float_no = f1.float_no + 1
                   AND    f2.b_stop_no  = f1.e_stop_no
                   AND    f1.pallet_pull = 'N'
                   AND    f2.pallet_pull = 'N'
                   AND    sm.method_id = r.method_id
                   AND    sm.group_no = f1.group_no
                   AND    sm.sel_type = 'NOR'
                   AND    DECODE (f1.comp_code, 'C', se.repallet_cube_clr, 'D', se.repallet_cube_dry, se.repallet_cube_frz) IS NOT NULL
                   AND    se.equip_id = f1.equip_id
                   AND    f1.e_stop_no >= 2
                   AND    sm.merge_group_no IS NULL
                   AND    r.route_batch_no = pRouteBatchNo) c
         WHERE    EXISTS (
                SELECT    SUM (cube)
                  FROM    float_detail fd
                 WHERE    fd.float_no = c.from_float_no
                   AND    TRUNC (fd.stop_no) = TRUNC (c.repal_stop))
         ORDER    BY c.route_no, c.group_no, c.to_float_no;
        
         /* CURSOR get_float_cur (pRouteBatchNo NUMBER) IS
        SELECT f.float_no
          FROM floats f, route r
         WHERE r.route_no = f.route_no
           AND r.route_batch_no = proutebatchno
           AND pallet_pull = 'N'; */
                 
         
        lCube_Of_From_Float        FLOAT;
        lCube_Of_To_Float        FLOAT;
		Count_Of_Rec_From_Float  NUMBER;
        lMaxSeq    BINARY_INTEGER;
        lZonSeq    BINARY_INTEGER;
        
    BEGIN
        --
        -- For all Stop 1's (stop 1 through 1.99) try to move all the items up so that stop 1 is
        -- on its own pallet. This allows the driver to take the entire stop 1 pallet out during
        -- delivery thus freeing up space on the truck
        --
                              
        FOR    stop_1_fwd_rec IN stop_1_fwd_cur (RouteBatchNo_in)
        LOOP

        BEGIN
            IF (TRUNC (stop_1_fwd_rec.b_stop_no) > 1) THEN 
            BEGIN
                SELECT    SUM (cube), MAX (seq_no)
                  INTO    lCube_Of_To_Float, lMaxSeq
                  FROM    float_detail
                 WHERE    float_no = stop_1_fwd_rec.max_stop_1_float;
                SELECT SUM(cube)
                  INTO lCube_Of_From_Float
                  FROM float_detail
                 WHERE float_no = stop_1_fwd_rec.float_no
                   AND    TRUNC (stop_no) = 1;
                IF (lCube_Of_To_Float+lCube_Of_From_Float<= stop_1_fwd_rec.max_float_cube + stop_1_fwd_rec.repallet_cube)
                THEN
                BEGIN
                    --
                    -- Move all the product on to the last float in the group.
                    -- This float contains stop number 1 only. So, we don't really
                    -- have to worry about which the float zone. We use TRUNC (stop_no)
                    -- because stops 1 through 1.99 is considered to be part of stop 1
                    --   
                                                                  
                      UPDATE    float_detail fd
                       SET    float_no = stop_1_fwd_rec.max_stop_1_float,
                            seq_no = lMaxSeq + ROWNUM
                     WHERE    float_no = stop_1_fwd_rec.float_no
                       AND    TRUNC (stop_no) = 1;
                    --
                    -- Recalculate the total cube and first and last stop on the float
                    -- and update both floats with corresponding info.
                    --
                    UPDATE    floats
                       SET    (b_stop_no, e_stop_no, float_cube) = 
                        (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                           FROM    float_detail
                          WHERE    float_no  = stop_1_fwd_rec.max_stop_1_float)
                      WHERE    float_no  = stop_1_fwd_rec.max_stop_1_float;
                    UPDATE    floats
                       SET    (b_stop_no, e_stop_no, float_cube) = 
                        (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                           FROM    float_detail
                          WHERE    float_no  = stop_1_fwd_rec.float_no)
                      WHERE    float_no  = stop_1_fwd_rec.float_no;
                    commit;  /*Charm 6*3957*/
                    --Rearranging zone cubes for re-palletized floats 
                    ZoneBalance(stop_1_fwd_rec.float_no);
                    ZoneBalance(stop_1_fwd_rec.max_stop_1_float);                   
                     pl_log.ins_msg (
                              'I',
                              'Repallet1',
                                 'UPDATED to ['
                              || stop_1_fwd_rec.max_stop_1_float
                              || '] from ['
                              || stop_1_fwd_rec.float_no
                              || ']',
                              NULL,
                              NULL);
                END;
                END IF;
            END;
            END IF;
        END;
        END LOOP;
        --
        -- For all other stops try to move products to lower floats (products from floats with higher float
        -- number will move to a float with lower float number).
        -- the float zone will have to be updated properly. That would also mean that the zone cube may be
        -- increased considerably and may make the pallet unbalanced. 
        --
        --
            
        FOR other_stops_bck_rec IN other_stops_bck_cur (RouteBatchNo_in)
        LOOP
        BEGIN
            SELECT    SUM (cube),MAX (seq_no)
              INTO    lCube_Of_To_Float,lMaxSeq
              FROM    float_detail
             WHERE    float_no = other_stops_bck_rec.to_float_no;
            SELECT SUM(cube),count(*)
              INTO lCube_Of_From_Float,Count_Of_Rec_From_Float
              FROM float_detail
             WHERE float_no = other_stops_bck_rec.from_float_no
               AND    TRUNC (stop_no) = other_stops_bck_rec.repal_stop;
            IF (lCube_Of_To_Float+lCube_Of_From_Float<= other_stops_bck_rec.max_float_cube + other_stops_bck_rec.repal_cube)
            THEN
            BEGIN
                 --
                 -- Here you are moving from a higher float number to a lower float number and
                 -- the float you are moving to will have products for other stops. That is, if the order for
                 -- stop 10 is split between float numbers 1000 and float 1001, then the products are
                 -- moved from 1001 to 1000. If the floats are set up to have 3 zones, then on float 1000
                 -- stop 10 will be in zone 1 and on float 1001, it wil be on zone 3. So, when we move the
                 -- products, it will have to be moved to the correct zone. 
                 --
				 
                UPDATE    float_detail
                    SET    float_no = other_stops_bck_rec.to_float_no,
                        seq_no = lMaxSeq + ROWNUM,
                         zone = 1
                WHERE    float_no = other_stops_bck_rec.from_float_no
                    AND    TRUNC (stop_no) = other_stops_bck_rec.repal_stop;
                --6000010128: Update sequence of the floats after moving the stops so that the sequence will be arranged properly
				UPDATE    float_detail
                    SET    seq_no = seq_no - Count_Of_Rec_From_Float 
                WHERE    float_no = other_stops_bck_rec.from_float_no;
            
                --
                -- Recalculate the total cube and first and last stop on the float
                -- and update both floats with corresponding info.
                --
                UPDATE    floats
                    SET    (b_stop_no, e_stop_no, float_cube) = 
                    (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                       FROM    float_detail
                     WHERE    float_no  = other_stops_bck_rec.from_float_no)
                WHERE    float_no  = other_stops_bck_rec.from_float_no;
                UPDATE    floats
                     SET    (b_stop_no, e_stop_no, float_cube) = 
                      (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                         FROM    float_detail
                     WHERE    float_no  = other_stops_bck_rec.to_float_no)
                WHERE    float_no  = other_stops_bck_rec.to_float_no;
                commit;/*Charm 6*3957*/
                --Rearranging zone cubes for re-palletized floats 
                ZoneBalance(other_stops_bck_rec.from_float_no);
                ZoneBalance(other_stops_bck_rec.to_float_no);
                              pl_log.ins_msg (
                              'I',
                              'Repallet2',
                                 'UPDATED to ['
                              || other_stops_bck_rec.to_float_no
                              || '] from ['
                              || other_stops_bck_rec.from_float_no
                              || '] stop ' || other_stops_bck_rec.repal_stop,
                              NULL,
                              NULL);
            END;
            END IF;    
        END;
        END LOOP;
        --
        -- For all other stops try to move products to higher floats (products from floats with lower float
        -- number will move to a float with higher float number).
        -- the float zone will have to be updated properly. That would also mean that the zone cube may be
        -- increased considerably and may make the pallet unbalanced. 
        --
        --
        FOR other_stops_fwd_rec IN other_stops_fwd_cur (RouteBatchNo_in)
        LOOP
        BEGIN
            SELECT    SUM (cube),MAX (seq_no),MAX(zone)
              INTO    lCube_Of_To_Float,lMaxSeq,lZonSeq
              FROM    float_detail
             WHERE    float_no = other_stops_fwd_rec.to_float_no;
            SELECT SUM(cube),count(*)
              INTO lCube_Of_From_Float,Count_Of_Rec_From_Float
              FROM float_detail
             WHERE float_no = other_stops_fwd_rec.from_float_no
               AND    TRUNC (stop_no) = other_stops_fwd_rec.repal_stop;
            IF (lCube_Of_To_Float+lCube_Of_From_Float<= other_stops_fwd_rec.max_float_cube + other_stops_fwd_rec.repal_cube)
            THEN
            BEGIN
                 --
                 -- Here you are moving from a lower float number to a higher float number and
                 -- the float you are moving to will have products for other stops. That is, if the order for
                 -- stop 10 is split between float numbers 1000 and float 1001, then the products are
                 -- moved from 1000 to 1001. If the floats are set up to have 3 zones, then on float 1001
                 -- stop 10 will be in zone 3 and on float 1000, it wil be on zone 1. So, when we move the
                 -- products, it will have to be moved to the correct zone. 
                 --
                 -- 6000010128: Update sequence of the floats before moving the stops so that we can move the stop to last zone with the minimum sequence 
                UPDATE    float_detail
                    SET  seq_no = seq_no + Count_Of_Rec_From_Float
                WHERE    float_no = other_stops_fwd_rec.to_float_no;
							  
                UPDATE    float_detail
                    SET    float_no = other_stops_fwd_rec.to_float_no,
                        seq_no = ROWNUM,
                        zone = lZonSeq
                WHERE    float_no = other_stops_fwd_rec.from_float_no
                    AND    TRUNC (stop_no) = other_stops_fwd_rec.repal_stop;
                    
                
                --
                -- Recalculate the total cube and first and last stop on the float
                -- and update both floats with corresponding info.
                --
                UPDATE    floats
                    SET    (b_stop_no, e_stop_no, float_cube) = 
                    (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                       FROM    float_detail
                     WHERE    float_no  = other_stops_fwd_rec.from_float_no)
                WHERE    float_no  = other_stops_fwd_rec.from_float_no;
                UPDATE    floats
                     SET    (b_stop_no, e_stop_no, float_cube) = 
                      (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                         FROM    float_detail
                     WHERE    float_no  = other_stops_fwd_rec.to_float_no)
                WHERE    float_no  = other_stops_fwd_rec.to_float_no;
                commit; /*Charm 6*3957*/
                --Rearranging zone cubes for re-palletized floats
               ZoneBalance(other_stops_fwd_rec.from_float_no);
               ZoneBalance(other_stops_fwd_rec.to_float_no);
                              pl_log.ins_msg (
                              'I',
                              'Repallet3',
                                 'UPDATED to ['
                              || other_stops_fwd_rec.to_float_no
                              || '] from ['
                              || other_stops_fwd_rec.from_float_no
                              || '] stop ' || other_stops_fwd_rec.repal_stop,
                              NULL,
                              NULL);               
            END;
            END IF;
        END;
        END LOOP;
        
    FOR    stop_1_bck_rec IN stop_1_bck_cur (RouteBatchNo_in)
        LOOP
        BEGIN
            IF (TRUNC (stop_1_bck_rec.e_stop_no) = 1) THEN 
            BEGIN
                SELECT    SUM (cube)
                  INTO    lCube_Of_From_Float
                  FROM    float_detail
                 WHERE    float_no = stop_1_bck_rec.max_stop_1_float;
                SELECT SUM(cube), MAX (seq_no)
                  INTO lCube_Of_To_Float, lMaxSeq
                  FROM float_detail
                 WHERE float_no = stop_1_bck_rec.float_no;
                IF (lCube_Of_To_Float+lCube_Of_From_Float<= stop_1_bck_rec.max_float_cube + stop_1_bck_rec.repallet_cube)
                THEN
                BEGIN
                    --
                    -- Move all the product on to the last float in the group.
                    -- This float contains stop number 1 only. So, we don't really
                    -- have to worry about which the float zone. We use TRUNC (stop_no)
                    -- because stops 1 through 1.99 is considered to be part of stop 1
                    --
                               pl_log.ins_msg (
                              'I',
                              'Repallet4',
                                 'lCube_Of_To_Float ['
                              || lCube_Of_To_Float
                              || '] lCube_Of_From_Float ['
                              || lCube_Of_From_Float
                              || '] stop_1_bck_rec.max_float_cube ' || stop_1_bck_rec.max_float_cube || ' other_stops_fwd_rec.repal_cube ' || stop_1_bck_rec.repallet_cube,
                              NULL,
                              NULL);                   
                    
                    UPDATE    float_detail fd
                       SET    float_no = stop_1_bck_rec.float_no,
                            seq_no = lMaxSeq + ROWNUM,
                            zone = 1
                     WHERE    float_no = stop_1_bck_rec.max_stop_1_float
                       AND    TRUNC (stop_no) = 1;
                    
                    --
                    -- Recalculate the total cube and first and last stop on the float
                    -- and update both floats with corresponding info.
                    --
                    UPDATE    floats
                       SET    (b_stop_no, e_stop_no, float_cube) = 
                        (SELECT    MAX (stop_no), MIN (stop_no), SUM (cube)
                           FROM    float_detail
                          WHERE    float_no  = stop_1_bck_rec.float_no)
                      WHERE    float_no  = stop_1_bck_rec.float_no;
                    DELETE floats
                        WHERE    float_no  = stop_1_bck_rec.max_stop_1_float;
                        
                    commit;    /*Charm 6*3957*/
                    --Rearranging zone cubes for re-palletized floats 
                   ZoneBalance(stop_1_bck_rec.float_no);
                   ZoneBalance(stop_1_bck_rec.max_stop_1_float);
                              pl_log.ins_msg (
                              'I',
                              'Repallet4',
                                 'UPDATED to ['
                              || stop_1_bck_rec.float_no
                              || '] from ['
                              || stop_1_bck_rec.max_stop_1_float,
                              NULL,
                              NULL);                     
                END;
                END IF;
            END;
            END IF;
        END;
        END LOOP;
        
        /* FOR    get_float_rec IN get_float_cur (RouteBatchNo_in)
        LOOP
        BEGIN
        ZoneBalance(get_float_rec.float_no);
        END;
        END LOOP; */
    END RePalletize;
---------------------------------------------------------------------------------------------------------------------    
    --CRQ48665: To balance the zones based on float cube
    --6000005411: To balance the zones based on float cube
	--6000010128:lnic4226: Changed the zone balance logic to restrict moving of cubes only to the next immediate zone.
---------------------------------------------------------------------------------------------------------------------
PROCEDURE ZoneBalance (float_num NUMBER)
IS
   v_lAvg_Cube            FLOATS.FLOAT_CUBE%TYPE;
   v_No_of_Zone           NUMBER;
   v_lTot_Currzone_Cube   FLOATS.Float_Cube%TYPE;
   v_lTot_Prevzone_Cube   FLOATS.Float_Cube%TYPE;
   v_lTot_Prevzone        FLOATS.Float_Cube%TYPE;
   v_lOrd_Cube            FLOATS.Float_Cube%TYPE;
   v_lMaxZone             NUMBER;
   v_Exit_Val             NUMBER := 0;
   v_Previous_Cube        FLOAT_DETAIL.CUBE%TYPE;


BEGIN
--Find average cube of float and no of zones in the float	
   
   SELECT f.float_cube / se.no_of_zones,se.no_of_zones
     INTO v_lAvg_Cube,v_lMaxZone
     FROM floats f, sel_equip se
    WHERE f.float_no = float_num AND f.equip_id = se.equip_id;
	
   FOR Counter in 1..v_lMaxZone - 1
   LOOP
      BEGIN

--Find cube of maximum zone	  
      
	  SELECT NVL (SUM (cube), 0) INTO v_lTot_Currzone_Cube
        FROM float_detail
       WHERE float_no = float_num AND zone = v_lMaxZone;

--increasing the cube which is less than the average cube

         IF (v_lTot_Currzone_Cube < v_lAvg_Cube)
         THEN
                LOOP
                v_Exit_Val :=0;
                  BEGIN
                     SELECT NVL (SUM (CUBE), 0)
                       INTO v_lOrd_Cube
                       FROM float_detail
                      WHERE float_no = float_num
                            AND ZONE = v_lMaxZone -1
                            AND seq_no =
                                   (SELECT MIN(seq_no)
                                      FROM float_detail
                                     WHERE float_no = float_num
                                           AND ZONE =
                                                  v_lMaxZone -1);



                     SELECT NVL (SUM (cube), 0) INTO v_lTot_Currzone_Cube
                     FROM float_detail
                     WHERE float_no = float_num AND zone = v_lMaxZone;

--After increasing The cube of current zone should be lesser or equal to average cube of the float
                     IF ( ((v_lTot_Currzone_Cube + v_lOrd_Cube) <= v_lAvg_Cube) AND v_lOrd_cube <> 0)
                     THEN
                        BEGIN
                           UPDATE float_detail
                              SET ZONE = v_lMaxZone
                            WHERE float_no = float_num
                                  AND ZONE = v_lMaxZone - 1
                                  AND seq_no =
                                         (SELECT MIN (seq_no)
                                            FROM float_detail
                                           WHERE float_no = float_num
                                                 AND ZONE =
                                                        v_lMaxZone - 1);

                           COMMIT;
                           pl_log.ins_msg (
                              'I',
                              'ZoneBalance',
                                 'UPDATED cube ['
                              || v_lOrd_cube
                              || '] to zone ['
                              || v_lMaxZone
                              || ']',
                              NULL,
                              NULL);
                        END;
                     ELSE
                        v_Exit_Val := 1;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        pl_log.ins_msg (
                           'I',
                           'ZoneBalance',
                           'Error [ ' || TO_CHAR (SQLCODE) || ']',
                           NULL,
                           NULL);
                  END;
                        pl_log.ins_msg (
                           'I',
                           'ZoneBalance',
                           'Exit ',
                           NULL,
                           NULL);
                  EXIT WHEN v_Exit_Val = 1;
              END LOOP;

            v_lMaxZone := v_lMaxZone - 1;
--Reducing the cube which is more than the average cube.
         ELSIF (v_lTot_Currzone_Cube > v_lAvg_Cube)
         THEN
             LOOP
             v_Exit_Val :=0;
                  BEGIN
                     SELECT NVL (SUM (CUBE), 0)
                       INTO v_lOrd_Cube
                       FROM float_detail
                      WHERE float_no = float_num AND ZONE = v_lMaxZone
                            AND seq_no =
                                   (SELECT MAX (seq_no)
                                      FROM float_detail
                                     WHERE float_no = float_num
                                           AND ZONE = v_lMaxZone);

                     SELECT NVL (SUM (cube), 0) INTO v_lTot_Currzone_Cube
                     FROM float_detail
                     WHERE float_no = float_num AND zone = v_lMaxZone;
--After Reducing The cube of current zone should be greater or equal to average cube of the float                              
                     IF ( ((v_lTot_Currzone_Cube - v_lOrd_Cube) >= v_lAvg_Cube) AND v_lOrd_cube <> 0)
                     THEN
                        BEGIN
                           UPDATE float_detail
                              SET ZONE = v_lMaxZone - 1
                            WHERE float_no = float_num AND ZONE = v_lMaxZone
                                  AND seq_no =
                                         (SELECT MAX (seq_no)
                                            FROM float_detail
                                           WHERE float_no = float_num
                                                 AND ZONE = v_lMaxZone);

                           COMMIT;
                           pl_log.ins_msg (
                              'I',
                              'ZoneBalance',
                                 'UPDATED cube ['
                              || v_lOrd_cube
                              || '] from zone ['
                              || v_lMaxZone
                              || ']',
                              NULL,
                              NULL);
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              pl_log.ins_msg (
                                 'I',
                                 'ZoneBalance',
                                 'Error [ ' || TO_CHAR (SQLCODE) || ']',
                                 NULL,
                                 NULL);
                        END;
                     ELSE
                        v_Exit_Val := 1;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        pl_log.ins_msg (
                           'I',
                           'ZoneBalance',
                           'Error [ ' || TO_CHAR (SQLCODE) || ']',
                           NULL,
                           NULL);
                  END;

                  EXIT WHEN v_Exit_Val = 1;
            END LOOP;
            v_lMaxZone := v_lMaxZone - 1;
            
         ELSE
         
            v_lMaxZone := v_lMaxZone - 1;
            
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            pl_log.ins_msg ('I',
                            'ZoneBalance',
                            'Error [ ' || TO_CHAR (SQLCODE) || ']',
                            NULL,
                            NULL);
      END;
   END LOOP;
EXCEPTION
   WHEN OTHERS
   THEN
      pl_log.ins_msg ('I',
                      'ZoneBalance',
                      'Error[ ' || TO_CHAR (SQLCODE) || ']',
                      NULL,
                      NULL);
END ZoneBalance;


---------------------------------------------------------------------------
-- Procedure:
--    create_float_detail_piece_recs
--
-- Description:
--    The procedures creates the appropriate piece level records for the
--    specified route batch number or route number.
--
--    This includes:
--        - ORDCW records
--        - ORDGS1 records
--        - Symbotic case records.
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    CRT_order_proc.pc
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/10/14 bben0556 Created as part of the Symbotic project.
---------------------------------------------------------------------------
PROCEDURE create_float_detail_piece_recs
            (i_route_batch_no  IN  route.route_batch_no%TYPE DEFAULT NULL,
             i_route_no        IN  route.route_no%TYPE       DEFAULT NULL)
IS
   l_object_name  VARCHAR2(30) := 'create_float_detail_piece_recs';
   l_message      VARCHAR2(512);

   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of parameters.
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || ']),'
         || '  This procedure calls the appropriate procedures to create the'
         || ' ORDCW,ORDGS1, ORDCB, ORDC_COOL records and Symbotic case records on a wave of routes'
         || ' or a specified route.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_no should be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Create ORDCW records.
   -- These are the catch weight data collection records for order selection.
   --
   pCreateOrdCW(iRouteBatchNo => i_route_batch_no,
                vRouteNo      =>  i_route_no);

   --
   -- Create ORDGS1 records.
   -- These are the CFA GS1 data collection records for order selection.
   --
   Create_Ordgs1(i_route_batch_no => i_route_batch_no,
                 i_route_no       =>  i_route_no);
   --
   -- Create ORDCB records. Clam bed.
   -- These are the clam bed data collection records for order selection.
   --
   create_ordcb(i_route_batch_no => i_route_batch_no,
                i_route_no       => i_route_no);

   --
   -- Create ORD_COOL records.
   -- These are the country of origin data collection records for order selection.
   --
   create_ord_cool(i_route_batch_no => i_route_batch_no,
                   i_route_no       => i_route_no);

   --
   -- Create the Symbotic case records.
   --
   pl_matrix_op.create_case_records(i_route_batch_no => i_route_batch_no,
                                    i_route_no       => i_route_no);


--
-- 6/04/2015  Brian Bent
-- Temporarily put in these procedure calls until we write
-- an "end of order generation" procedure.
--
pl_matrix_common.populate_mx_wave_number(i_wave_number => i_route_batch_no);
pl_matrix_op.assign_mx_priority(i_route_batch_no => i_route_batch_no);

   --
   -- Log when done.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Ending procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);


EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_no should be populated.
      --
      l_message := l_object_name ||
             '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
          || 'i_route_no[' || i_route_no || '])'
          || '   One and only one of i_route_batch_no and i_route_no can be populated.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

END create_float_detail_piece_recs;

---------------------------------------------------------------------------
-- Procedure:
--    create_ordcb
--
-- Description:
--    This procedure creates the clam bed selection data collection records
--    for a route or wave of routes.
--    This procedure creates the clam bed data collection records
--    for order selection for a route or wave of routes.
--
--    Records are inserted into table ORDCB.
--
--    It is based on the FLOAT_DETAIL table qty allocated and the uom.
--
--    It is similar to how records are created in the ORDCW and
--    ORD_COOL tables.
--
--    It is expected that FLOAT_DETAIL.BC_ST_PIECE_SEQ is set correctly.
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/31/14 bben0556 Created.
--                      Program "order_proc.pc" no longer creates the
--                      ORDCB records.
--
--    11/30/15 prpbcb   Bug fix.
--                      TFS work item ___
--
--                      Changed to account for null FLOAT_DETAIL.BC_ST_PIECE_SEQ
--                      for bulk pulls.
--                      FLOAT_DETAIL.BC_ST_PIECE_SEQ will be null for bulk
--                      pulls.  
--                      Also changed to handle exceptions internally.  No
--                      exceptions raised to the outside world since the basic
--                      rule for order generation is don't stop.
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Ignore 'X' cross dock type when creating data collection records for catchweights,
--                      clam bed and COOL.  All of this is collected at Site 1.
--                      Modfied cursor "c_float_detail" to exclude 'X' cross dock type.
---------------------------------------------------------------------------
PROCEDURE create_ordcb
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'create_ordcb';
   l_message       VARCHAR2(512);

   -- value of syspar CLAM_BED_TRACKED
   l_syspar_clam_bed_tracked     sys_config.config_flag_val%TYPE;

   l_seq_no  PLS_INTEGER; -- The case sequence in the case number, 1, 2, 3...
                          -- Similar to what is in ORDCW and ORD_COOL.

   l_previous_order_id        float_detail.order_id%TYPE;       -- To know when switching to different order-item.
   l_previous_order_line_id   float_detail.order_line_id%TYPE;  -- To know when switching to different order-item.

   --
   -- These variables are used in error messages since we cannot reference
   -- a cursor for loop record outside the loop.
   --
   l_float_no              float_detail.float_no%TYPE;
   l_float_detail_seq_no   float_detail.seq_no%TYPE;

   --
   -- Variables to count the exceptions and log at the end of the processing.
   --
   l_num_records_processed         PLS_INTEGER := 0;
   l_num_records_created           PLS_INTEGER := 0;
   l_num_records_existing          PLS_INTEGER := 0;
   l_num_errors                    PLS_INTEGER := 0;

   --
   -- Grand totals
   --
   l_total_num_records_processed   PLS_INTEGER := 0;
   l_total_num_records_created     PLS_INTEGER := 0;
   l_total_num_records_existing    PLS_INTEGER := 0;
   l_total_num_errors              PLS_INTEGER := 0;

   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                              -- parameters.

   --
   -- This cursor selects the items to create the ORDCB records for.
   --
   CURSOR c_float_detail(cp_route_batch_no  route.route_batch_no%TYPE,
                         cp_route_no        route.route_no%TYPE)
   IS
   SELECT f.route_no,
          f.batch_no,
          fd.order_seq,
          fd.order_id,
          fd.order_line_id,
          DECODE(fd.uom, 1, 1, 2) uom,  -- Though the float_detail.uom should be only 1 or 2.
          fd.prod_id,
          fd.cust_pref_vendor,
          fd.float_no,      -- FYI FLOAT_DETAIL PK
          fd.seq_no,        -- FYI FLOAT_DETAIL PK
          fd.qty_alloc,
          fd.zone,
          DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc)  piece_count,
          --
          fd.st_piece_seq,        -- Poor naming of this column.
                                  -- Starting piece sequence for the order-item combination.
          fd.bc_st_piece_seq,     -- Poor naming of this column.
          --
          -- CARRIER_ID should be populated when picking from a non-home slot.
          -- CARRIER_ID will be null if picked from a home slot.
          NVL(fd.carrier_id, fd.src_loc) swms_pallet_id,
          --
          'N'                     case_short_flag,
          'NEW'                   status,
          SYSDATE                 add_date,
          USER                    add_user
     FROM haccp_codes h,
          pm,
          floats f,
          float_detail fd,
          route r,
          loc,                     -- to get the slot type
          ordm                     -- 09/29/21 Added so that 'X' cross dock type can be excluded
    WHERE
          (   r.route_batch_no   = cp_route_batch_no
           OR f.route_no         = cp_route_no)
      --
      AND  h.haccp_code                    = pm.category
      AND  h.haccp_type                    = 'C'
      AND  h.clambed_trk                   = 'Y'
      --
      AND ordm.order_id                    = fd.order_id
      AND NVL(ordm.cross_dock_type, 'aaa') <> 'X'
      --
      AND loc.logi_loc                     = fd.src_loc
      AND r.route_no                       = f.route_no
      AND pm.prod_id                       = fd.prod_id
      AND pm.cust_pref_vendor              = fd.cust_pref_vendor
      AND f.float_no                       = fd.float_no
      AND NVL(f.pallet_pull, 'x')          <>  'R'          -- No demand repl
      AND fd.merge_alloc_flag              <> 'M'  -- Leave out the pick from the merge location.
                                                   -- We use the pick from the slot.
    ORDER BY fd.order_id,
             fd.order_line_id,
             DECODE(f.pallet_pull, 'N', 0, 1),  -- Want to process normal selection batches first    11/30/2015 Brian Bent Added.
                                                -- so that ordcb.seq_no corresponds to float_detail.bc_st_piece_seq
          -- r.route_batch_no,   -- 11/30/2015  Brian Bent Comment out.  Don't need.
             f.route_no,
             fd.order_seq,
             fd.bc_st_piece_seq,                -- 11/25/2015 Brian Bent  Added.
             f.batch_no,
             fd.float_no,
             fd.zone;
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || ']),'
         || '  This procedure creates the ORDCB records for each piece that'
         || ' requires clam bed data collection on a wave'
         || ' of routes or a specified route.'
         || '  It is based on the FLOAT_DETAIL table qty allocated and the uom.'
         || '  X cross dock orders are excluded.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_no should be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Check the clam bed syspar.
   -- If 'Y' then create the ORDCB records.
   --
   l_syspar_clam_bed_tracked := pl_common.f_get_syspar('CLAM_BED_TRACKED', 'not_found');

   --
   -- If the syspar is not found then log a message and set it to N.
   --
   IF (l_syspar_clam_bed_tracked = 'not_found') THEN
      pl_log.ins_msg
        (pl_log.ct_warn_msg, l_object_name,
            '(i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['            || i_route_no                     || '])'
         || '  Syspar CLAM_BED_TRACKED not found.  Defaulting to N.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

      l_syspar_clam_bed_tracked := 'N';  -- Change it from 'not_found' to 'N'.
   END IF;

   --
   -- Create the ORDCB records if syspar CLAM_BED_TRACKED is Y.
   --
   IF (l_syspar_clam_bed_tracked = 'Y') THEN
      --
      -- Initialization
      --
      l_previous_order_id      := NULL;
      l_previous_order_line_id := NULL;
      l_seq_no := 0;

      FOR r_float_detail IN c_float_detail(i_route_batch_no, i_route_no)
      LOOP
         --
         -- Note: FLOAT_DETAIL.BC_ST_PIECE_SEQ needs to be correct.
         --       Bulk pulls will have a null FLOAT_DETAIL.BC_ST_PIECE_SEQ.
         --       So account for this is if all we have is a bulk pull for
         --       the item.
         --

         IF (    l_previous_order_id      = r_float_detail.order_id
             AND l_previous_order_line_id = r_float_detail.order_line_id)
         THEN
            l_seq_no := NVL(r_float_detail.bc_st_piece_seq, CASE l_seq_no WHEN NULL THEN 1 ELSE l_seq_no END);
         ELSE
            l_seq_no := NVL(r_float_detail.bc_st_piece_seq, 1);

            --
            -- Log the counts for the order-item if not the first record processed.
            --
            IF (l_previous_order_id IS NOT NULL)  THEN
               pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
            END IF;

            l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
            l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
            l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
            l_total_num_errors              := l_total_num_errors            + l_num_errors;

            l_num_records_processed  := 0;
            l_num_records_created    := 0;
            l_num_records_existing   := 0;
            l_num_errors             := 0;
         END IF;

         --
         -- For error messages.
         --
         l_float_no             := r_float_detail.float_no;
         l_float_detail_seq_no  := r_float_detail.seq_no;

         --
         -- Log message for info/debugging.
         --
         l_message := 'In cursor c_float_detail loop.  Processing order line item:'
                      || ' route_no['        || r_float_detail.route_no         || ']'
                      || ' batch_no['        || r_float_detail.batch_no         || ']'
                      || ' float_no['        || r_float_detail.float_no         || ']'
                      || ' zone['            || r_float_detail.zone             || ']'
                      || ' order_seq['       || r_float_detail.order_seq        || ']'
                      || ' order_id['        || r_float_detail.order_id         || ']'
                      || ' order_line_id['   || r_float_detail.order_line_id    || ']'
                      || ' prod_id['         || r_float_detail.prod_id          || ']'
                      || ' uom['             || r_float_detail.uom              || ']'
                      || ' qty_alloc['       || r_float_detail.qty_alloc        || ']'
                      || ' piece_count['     || r_float_detail.piece_count      || ']'
                      || ' swms_pallet_id['  || r_float_detail.swms_pallet_id   || ']'
                      || ' l_seq_no['        || l_seq_no                        || ']';

         DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' || l_message);

         pl_log.ins_msg (pl_log.ct_info_msg, l_object_name, l_message,
                        NULL, NULL, ct_application_function, gl_pkg_name);

         --
         -- Create ORDCB records at piece level.
         --
         FOR i IN 1..r_float_detail.piece_count LOOP

            l_num_records_processed := l_num_records_processed + 1;

            --
            -- Debug stuff.   Main purpose is to show l_seq_no.
            --
            DBMS_OUTPUT.PUT_LINE(l_object_name || '  in loop "i IN 1..r_float_detail.piece_count"'
                                 ||  ' l_seq_no['      || TO_CHAR(l_seq_no) || ']');

            --
            -- Start a new block to trap exceptions.
            --
            BEGIN
               INSERT INTO ordcb
               (
                  order_id,
                  order_line_id,
                  seq_no,
                  prod_id,
                  cust_pref_vendor,
                  order_seq
               )
               VALUES
               (
                  r_float_detail.order_id,
                  r_float_detail.order_line_id,
                  l_seq_no,
                  r_float_detail.prod_id,
                  r_float_detail.cust_pref_vendor,
                  r_float_detail.order_seq
               );

               l_num_records_created := l_num_records_created + 1;

               --
               -- Update float_detail record for clam bed label printing.
               --
               UPDATE float_detail fd
                  SET fd.clam_bed_trk = 'Y'
                WHERE fd.float_no  = r_float_detail.float_no
                  AND fd.seq_no    = r_float_detail.seq_no;

            EXCEPTION
               WHEN DUP_VAL_ON_INDEX THEN
                  l_num_records_existing := l_num_records_existing + 1;
               WHEN OTHERS THEN
                  --
                  -- Got some oracle error.  Log a message and continue processing.
                  --
                  l_num_errors := l_num_errors + 1;

                  pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['             || i_route_no                      || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']'
                      || '  l_seq_no['              || TO_CHAR(l_seq_no)              || ']'
                      || '  WHEN OTHERS inside loop.  Log message and continue the loop.',
                     SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);
            END;

            l_seq_no := l_seq_no + 1;

         END LOOP;  -- end the piece count loop

         l_previous_order_id       := r_float_detail.order_id;
         l_previous_order_line_id  := r_float_detail.order_line_id;

      END LOOP;     -- end the float detail loop

      --
      -- For the last order-item processed.
      --
      l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
      l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
      l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
      l_total_num_errors              := l_total_num_errors            + l_num_errors;

      --
      -- Log the counts for the last order-item.
      --
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   END IF;  -- end IF l_syspar_clam_bed_tracked = 'Y') THEN

   --
   -- Log the total counts.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        ' Totals counts:'
                     || '  l_total_num_records_processed['  || TO_CHAR(l_total_num_records_processed)  || ']'
                     || '  l_total_num_records_created['    || TO_CHAR(l_total_num_records_created)    || ']'
                     || '  l_total_num_records_existing['   || TO_CHAR(l_total_num_records_existing)   || ']'
                     || '  l_total_num_errors['             || TO_CHAR(l_total_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
                     || 'i_route_no['              || i_route_no                     || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_no can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.'
                   || '  Log message.  Exception not raised.  Leaving procedure.';

      pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);  -- 11/30/2015  Brian Bent Don't raise exception to
                                                                     -- outside world.  We want order generation to continue.

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['             || i_route_no                      || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']'
                      || '  l_seq_no['              || TO_CHAR(l_seq_no)              || ']'
                      || '  WHEN OTHERS at end of procedure.  Log message.  Exception not propagated.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      -- RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,  -- 11/30/2015  Brian Bent Don't raise exception to
      --      l_object_name || ': ' || SQLERRM);            -- outside world.  We want order generation to continue.
END create_ordcb;


---------------------------------------------------------------------------
-- Procedure:
--    create_ord_cool
--
-- Description:
--    This procedure creates the coutry of origin data collection records
--    for order selection for a route or wave of routes.
--
--    Records are inserted into table ORD_COOL.
--
--    It is based on the FLOAT_DETAIL table qty allocated and the uom.
--
--    It is similar to how records are created in the ORDCW and
--    ORDCB tables.
--
--    It is expected that FLOAT_DETAIL.BC_ST_PIECE_SEQ is set correctly.
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    None.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/31/14 bben0556 Created.
--                      Program "order_proc.pc" no longer creates the
--                      ORD_COOL records.
--                      The logic in the cursor that selects the records
--                      is different than what was in "order_proc.pc".
--                      "order_proc.pc" keyed off the ORDD table.
--                      This procedure keys off the FLOAT_DETAIL table.
--
--    11/25/15 prpbcb   Bug fix.
--                      TFS work item ___
--
--                      Not creating ORD_COOL records for bulk pull of cool
--                      item.  This is happening because it was expected
--                      FLOAT_DETAIL.BC_ST_PIECE_SEQ is always populated which it will
--                      not be for a bulk pull.  Changed "create_ord_cool()" to
--                      account for null FLOAT_DETAIL.BC_ST_PIECE_SEQ for bulk pulls.
--                      Also changed "create_ord_cool()" to handle exceptions
--                      internally.  No exceptions raised to the outside world
--                      since the basic rule for order generation is don't stop.                     
--
--                      Output the cust_id in the log messages.
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Ignore 'X' cross dock type when creating data collection records for catchweights,
--                      clam bed and COOL.  All of this is collected at Site 1.
--                      Modfied cursor "c_float_detail" to exclude 'X' cross dock type.
---------------------------------------------------------------------------
PROCEDURE create_ord_cool
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'create_ord_cool';
   l_message       VARCHAR2(512);

   l_seq_no  PLS_INTEGER; -- The case sequence in the case number, 1, 2, 3...
                          -- Similar to what is in ORDCW and ORDCB.

   l_previous_order_id        float_detail.order_id%TYPE;       -- To know when switching to different order-item.
   l_previous_order_line_id   float_detail.order_line_id%TYPE;  -- To know when switching to different order-item.


   --
   -- These variables are used in error messages since we cannot reference
   -- a cursor for loop record outside the loop.
   --
   l_float_no              float_detail.float_no%TYPE;
   l_float_detail_seq_no   float_detail.seq_no%TYPE;

   --
   -- Variables to count the exceptions and log at the end of the processing.
   --
   l_num_records_processed         PLS_INTEGER := 0;
   l_num_records_created           PLS_INTEGER := 0;
   l_num_records_existing          PLS_INTEGER := 0;
   l_num_errors                    PLS_INTEGER := 0;

   --
   -- Grand totals
   --
   l_total_num_records_processed   PLS_INTEGER := 0;
   l_total_num_records_created     PLS_INTEGER := 0;
   l_total_num_records_existing    PLS_INTEGER := 0;
   l_total_num_errors              PLS_INTEGER := 0;

   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                              -- parameters.

   --
   -- This cursor selects the items to create the ORD_COOL records for.
   --
   CURSOR c_float_detail(cp_route_batch_no  route.route_batch_no%TYPE,
                         cp_route_no        route.route_no%TYPE)
   IS
   SELECT f.route_no,
          f.batch_no,
          f.pallet_pull,
          fd.order_seq,
          fd.order_id,
          fd.order_line_id,
          DECODE(fd.uom, 1, 1, 2) uom,  -- Though the float_detail.uom should be only 1 or 2.
          fd.prod_id,
          fd.cust_pref_vendor,
          fd.float_no,      -- FYI FLOAT_DETAIL PK
          fd.seq_no,        -- FYI FLOAT_DETAIL PK
          fd.qty_alloc,
          fd.zone,
          DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc)  piece_count,
          --
          fd.st_piece_seq,        -- Poor naming of this column.
                                  -- Starting piece sequence for the order-item combination.
          fd.bc_st_piece_seq,     -- Poor naming of this column.
          --
          -- CARRIER_ID should be populated when picking from a non-home slot.
          -- CARRIER_ID will be null if picked from a home slot.
          NVL(fd.carrier_id, fd.src_loc) swms_pallet_id,
          --
          'N'                     case_short_flag,
          'NEW'                   status,
          SYSDATE                 add_date,
          USER                    add_user,
          ordm.cust_id            cust_id
     FROM haccp_codes h,
          cool_category cc,
          spl_rqst_customer s,
          ordm,
          pm,
          floats f,
          float_detail fd,
          route r
    WHERE (   r.route_batch_no    = cp_route_batch_no
           OR f.route_no          = cp_route_no)
      --
      AND cc.category             = SUBSTR(pm.category, 1, 2)
      AND h.haccp_code            = pm.category
      AND h.haccp_type            = 'O'
      AND h.cool_trk              = 'Y'
      AND ((cc.item_trk = 'N')
           OR
           (cc.item_trk = 'Y'
            AND (pm.prod_id, pm.cust_pref_vendor) IN
                (SELECT cm.prod_id, cm.cust_pref_vendor FROM cool_item_master cm)
           )
          )
      --
      AND NVL(ordm.cross_dock_type, 'aaa') <> 'X'        -- Exclude 'X' cross dock type.
      AND ordm.order_id                    = fd.order_id
      AND ordm.cust_id                     = s.customer_id
      AND s.cool_trk                       = 'Y'
      AND r.route_no                       = f.route_no
      AND pm.prod_id                       = fd.prod_id
      AND pm.cust_pref_vendor              = fd.cust_pref_vendor
      AND f.float_no                       = fd.float_no
      AND NVL(f.pallet_pull, 'x')          <>  'R'          -- No demand repl
      AND fd.merge_alloc_flag              <> 'M'  -- Leave out the pick from the merge location.
                                                   -- We use the pick from the slot.
    ORDER BY fd.order_id,
             fd.order_line_id,
             DECODE(f.pallet_pull, 'N', 0, 1),  -- Want to process normal selection batches first    11/24/2015 Brian Bent Added.
                                                -- so that ord_cool.seq_no corresponds to float_detail.bc_st_piece_seq
             fd.order_seq,
             fd.bc_st_piece_seq,                -- 11/25/2015 Brian Bent  Added.
             f.batch_no,
             fd.float_no,
             fd.zone;
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || ']),'
         || '  This procedure creates the ORD_COOL records for each piece that'
         || ' requires country of origin data collection on a wave'
         || ' of routes or a specified route.'
         || '  It is based on the FLOAT_DETAIL table qty allocated and the uom.'
         || '  X cross dock orders are excluded.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_batch_no should
   -- be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Initialization
   --
   l_previous_order_id      := NULL;
   l_previous_order_line_id := NULL;
   l_seq_no := 0;

   --
   -- Create the ORD_COOL records.
   --
   FOR r_float_detail IN c_float_detail(i_route_batch_no, i_route_no)
   LOOP
      --
      -- Note: FLOAT_DETAIL.BC_ST_PIECE_SEQ needs to be correct.
      --       Bulk pulls will have a null FLOAT_DETAIL.BC_ST_PIECE_SEQ.
      --       So account for this is if all we have is a bulk pull for
      --       the item.
      --

      IF (    l_previous_order_id      = r_float_detail.order_id
          AND l_previous_order_line_id = r_float_detail.order_line_id)
      THEN
         l_seq_no := NVL(r_float_detail.bc_st_piece_seq, CASE l_seq_no WHEN NULL THEN 1 ELSE l_seq_no END);
      ELSE
         l_seq_no := NVL(r_float_detail.bc_st_piece_seq, 1);

         --
         -- Log the counts for the order-item if not the first record processed.
         --
         IF (l_previous_order_id IS NOT NULL)  THEN
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
         END IF;

         l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
         l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
         l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
         l_total_num_errors              := l_total_num_errors            + l_num_errors;

         l_num_records_processed  := 0;
         l_num_records_created    := 0;
         l_num_records_existing   := 0;
         l_num_errors             := 0;
      END IF;

/***
XXX
      IF (
      -- l_seq_no := NVL(r_float_detail.bc_st_piece_seq, 1);   -- 11/25/2015  Brian Bent  Comment out.
      l_seq_no := 1;
****/

      --
      -- For error messages.
      --
      l_float_no             := r_float_detail.float_no;
      l_float_detail_seq_no  := r_float_detail.seq_no;

      --
      -- Log message for info/debugging.
      --
      l_message := 'In cursor c_float_detail loop.  Processing order line item:'
         || ' route_no['                   || r_float_detail.route_no                 || ']'
         || ' batch_no['                   || TO_CHAR(r_float_detail.batch_no)        || ']'
         || ' pallet_pull['                || r_float_detail.pallet_pull              || ']'
         || ' float_no['                   || TO_CHAR(r_float_detail.float_no)        || ']'
         || ' zone['                       || TO_CHAR(r_float_detail.zone)            || ']'
         || ' cust_id['                    || r_float_detail.cust_id                  || ']'
         || ' order_seq['                  || TO_CHAR(r_float_detail.order_seq)       || ']'
         || ' order_id['                   || r_float_detail.order_id                 || ']'
         || ' order_line_id['              || TO_CHAR(r_float_detail.order_line_id)   || ']'
         || ' bc_st_piece_seq['            || TO_CHAR(r_float_detail.bc_st_piece_seq) || ']'
         || ' prod_id['                    || r_float_detail.prod_id                  || ']'
         || ' uom['                        || TO_CHAR(r_float_detail.uom)             || ']'
         || ' qty_alloc['                  || TO_CHAR(r_float_detail.qty_alloc)       || ']'
         || ' piece_count['                || TO_CHAR(r_float_detail.piece_count)     || ']'
         || ' swms_pallet_id['             || r_float_detail.swms_pallet_id           || ']'
         || ' l_seq_no(starting seq_no)['  || TO_CHAR(l_seq_no)                       || ']';

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' || l_message);

      pl_log.ins_msg (pl_log.ct_info_msg, l_object_name, l_message,
                     NULL, NULL, ct_application_function, gl_pkg_name);

      FOR i IN 1..r_float_detail.piece_count LOOP

         l_num_records_processed := l_num_records_processed + 1;

         --
         -- Debug stuff.   Main purpose is to show l_seq_no.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || '  in loop "i IN 1..r_float_detail.piece_count"'
                              ||  ' l_seq_no['      || TO_CHAR(l_seq_no) || ']');

         --
         -- Start a new block to trap exceptions.
         --
         BEGIN
            INSERT INTO ord_cool
            (
               order_id,
               order_line_id,
               seq_no,
               prod_id,
               cust_pref_vendor,
               order_seq
            )
            VALUES
            (
               r_float_detail.order_id,
               r_float_detail.order_line_id,
               l_seq_no,
               r_float_detail.prod_id,
               r_float_detail.cust_pref_vendor,
               r_float_detail.order_seq
            );

            l_num_records_created := l_num_records_created + 1;

            --
            -- Flag the float_detail as a cool item.
            --
            UPDATE float_detail fd
               SET fd.cool_trk = 'Y'
             WHERE fd.float_no  = r_float_detail.float_no
               AND fd.seq_no    = r_float_detail.seq_no;

         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               l_num_records_existing := l_num_records_existing + 1;
            WHEN OTHERS THEN
               --
               -- Got some oracle error.
               --
               l_num_errors := l_num_errors + 1;

               pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['              || i_route_no                     || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']'
                      || '  l_seq_no['              || TO_CHAR(l_seq_no)              || ']'
                      || '  WHEN OTHERS inside loop.  Log message and continue the loop.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
         END;

         l_seq_no := l_seq_no + 1;

      END LOOP;  -- end the piece count loop

      l_previous_order_id       := r_float_detail.order_id;
      l_previous_order_line_id  := r_float_detail.order_line_id;

   END LOOP;     -- end the float detail loop

   --
   -- For the last order-item processed.
   --
   l_total_num_records_processed   := l_total_num_records_processed + l_num_records_processed;
   l_total_num_records_created     := l_total_num_records_created   + l_num_records_created;
   l_total_num_records_existing    := l_total_num_records_existing  + l_num_records_existing;
   l_total_num_errors              := l_total_num_errors            + l_num_errors;

   --
   -- Log the counts for the last order-item.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '  Counts for the order line item:'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']'
                     || '  l_num_errors['             || TO_CHAR(l_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   --
   -- Log the total counts.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        ' Totals counts:'
                     || '  l_total_num_records_processed['  || TO_CHAR(l_total_num_records_processed)  || ']'
                     || '  l_total_num_records_created['    || TO_CHAR(l_total_num_records_created)    || ']'
                     || '  l_total_num_records_existing['   || TO_CHAR(l_total_num_records_existing)   || ']'
                     || '  l_total_num_errors['             || TO_CHAR(l_total_num_errors)             || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);



   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
                     || 'i_route_no['              || i_route_no                     || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_n can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.'
                   || '  Log message.  Exception not raised.  Leaving procedure.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);  -- 11/25/2015  Brian Bent Don't raise exception to
                                                                     -- outside world.  We want order generation to continue.

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['              || i_route_no                     || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']'
                      || '  l_seq_no['              || TO_CHAR(l_seq_no)              || ']'
                      || '  WHEN OTHERS at end of procedure.  Log message.  Exception not propagated.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      -- RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,    -- 11/25/2015  Brian Bent Don't raise exception to
      --      l_object_name || ': ' || SQLERRM);              -- outside world.  We want order generation to continue.
END create_ord_cool;


---------------------------------------------------------------------------
-- Procedure:
--    update_float_detail_piece_seq
--
-- Description:
--    This procedure updates FLOAT_DETAIL.ST_PIECE_SEQ.
--    and FLOAT_DETAIL.BC_ST_PIECE_SEQ.
--
--    'X' cross type orders excluded as the piece seq assigned at Site 1 and
--    needs to be left alone at Site 2.
--
--    IMPORTANT !!!!!!!!!
--    These columns needs to be set in order to create the ORCW, ORDCB and
--    and ORD_COOL records as well as for SOS pick label printing to work
--    correctly.
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/10/14 bben0556 Created.
--    02/05/15 ayad5195 Changed for Matrix fix to order by order_seq , seq_no
--
--    07/09/15 bben0556 Brian Bent
--                      Change the ORDER BY once again.
--                      From
--  ORDER BY fd.order_id, fd.order_line_id, fd.order_seq, fd.seq_no, fd.float_no, fd.zone; --Matrix
--                      to
--  ORDER BY fd.order_id, fd.order_line_id, fd.order_seq, loc.pik_path, fd.float_no, fd.zone, fd.seq_no;
--
--                      Have DESC on fd.seq_no because fd.seq_no is the order the
--                      float_detail record was created and this starts with the last zone
--                      in the float working toward the first zone in the float.
--                      README:  I took out the DESC on fd.seq_no since it is
--                               possible additional float detail records
--                               could be created when picking floating items
--                               from multiple slots. These float detail
--                               records would be created sequentially so
--                               having DESC may confuse the selector
--                               when displaying the picking info to the
--                               selector and SOS and when printing the
--                               SOS pick labels.
--
--                      The order by was changed to match how SOS RF orders the
--                      records when displaying picks for multiple orders from
--                      the same location.
--                      Example:
--                         1 order for 12 cases.
--                         2 cases are in zone 1 of the "R" float.
--                         10 cases are in zone 2 of the "R" float.
--                         The RF orders these by float-zone.  Before the
--                         change the RF screen displayed:
--                             Cases 11 -> 12 of 12 cases
--                             Cases  1 -> 10 of 12 cases
--                         Ater the change the RF displays:
--                             Cases 1 ->  2 of 12 cases
--                             Cases 3 -> 12 of 12 cases
--
--                      Also added to the order by the float_detail src loc
--                      pik path for situations where we are picking from
--                      different floatings locations of a floating item for
--                      a particular order.  We want the pick label sequencing
--                      to go in location order.  Be aware to be more exact
--                      we could also use the selection method pick zone
--                      ordering and the pik path but using the pik path
--                      should work fine in normal situations.
--                      Example:
--                         1 order for 10 cases of a floating item.
--                         To fill the order the cases were picked from
--                         3 different slots.
--                            - 4 cases from slot CA05A1
--                            - 1 cases from slot CA08C1
--                            - 5 cases from slot CA12A1
--                        The case sequence on the RF will be:
--                             Cases 1 ->  4 of 10 cases from location CA05A1
--                             Cases 5 ->  5 of 10 cases from location CA08C1
--                             Cases 6 -> 10 of 10 cases from location CA12A1
--
--    07/17/15 bben0556 Brian Bent
--                      Change to include only normal selection float_detail
--                      records--pallet_pull = 'N'.  Before it included bulk
--                      pull, combine pulls and VRT bulk pulls which caused the
--                      piece sequence to be set incorrectly.  Bulk pulls and
--                      combine don't go to SOS so we don't want to set the
--                      piece sequence.
--
--                      Changed
--    AND NVL(f.pallet_pull, 'x') <>  'R'          -- No demand repl
--                      to
--    AND f.pallet_pull = 'N'
--
--
--    03/01/16 bben0556 Changed
--                 l_bc_st_piece_seq   float_detail.bc_st_piece_seq%TYPE;
--                      to
--                 l_bc_st_piece_seq   PLS_INTEGER
--                      to handle the situation where the piece seq is more
--                      than 3 digits.  See the modification history for
--                      the package dated 03/01/16 for more info.                      
--                      Put exception handler about the UPDATE statement so
--                      only that one float detail record will not get updated
--                      if there is an issue with the updated.
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Do not assign float detail piece sequence for 'X' cross dock types.  The piece sequence
--                      was assigned at Site 1.  Site 2 neesd to leave it alone.
--                      Modified cursor "c_float_detail" to exclude 'X' cross dock type.
---------------------------------------------------------------------------
PROCEDURE update_float_detail_piece_seq
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'update_float_detail_piece_seq';
   l_message       VARCHAR2(512);

   l_previous_order_id        float_detail.order_id%TYPE;
   l_previous_order_line_id   float_detail.order_line_id%TYPE;
   l_previous_piece_count     NUMBER;
   l_bc_st_piece_seq          PLS_INTEGER;
   l_previous_order_seq       float_detail.order_seq%TYPE; --Matrix
   --
   -- Variables for logging at the end of the processing.
   --
   l_num_records_processed         PLS_INTEGER := 0;

   --
   -- These variables are used in error messages since we cannot reference
   -- a cursor for loop record outside the loop.
   --
   l_float_no              float_detail.float_no%TYPE;
   l_float_detail_seq_no   float_detail.seq_no%TYPE;


   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                              -- parameters.

   --
   -- This cursor selects the float details records to update.
   --
   CURSOR c_float_detail(cp_route_batch_no  route.route_batch_no%TYPE,
                         cp_route_no        route.route_no%TYPE)
   IS
   SELECT f.route_no,
          f.batch_no,
          fd.order_seq,
          fd.order_id,
          fd.order_line_id,
          DECODE(fd.uom, 1, 1, 2) uom,  -- Though the float_detail.uom should be only 1 or 2.
          fd.prod_id,
          fd.cust_pref_vendor,
          fd.float_no,      -- FYI FLOAT_DETAIL PK
          fd.seq_no,        -- FYI FLOAT_DETAIL PK
          fd.qty_alloc,
          fd.zone,
          fd.status        float_detail_status,
          DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc)  piece_count,
          --
          fd.st_piece_seq,
          fd.bc_st_piece_seq
     FROM floats f,
          float_detail fd,
          route r,
          pm,
          loc,
          ordm                  -- 09/21/28 Added to exclude 'X' cross dock type
    WHERE
          (   r.route_batch_no    = cp_route_batch_no
           OR f.route_no          LIKE  cp_route_no)  --xxxx used like for testing, will keep LIKE for production too
      --
      AND r.route_no                       = f.route_no
      AND pm.prod_id                       = fd.prod_id
      AND pm.cust_pref_vendor              = fd.cust_pref_vendor
      AND f.float_no                       = fd.float_no
      AND f.pallet_pull                    = 'N'            -- Only want regular selection batches.
      AND loc.logi_loc                     = fd.src_loc
      AND ordm.order_id                    = fd.order_id
      AND NVL(ordm.cross_dock_type, 'aaa') <> 'X'          -- Exclude 'X' cross dock type
    ORDER BY fd.order_id,
             fd.order_line_id,
             fd.order_seq,
             loc.pik_path,
             fd.float_no,
             fd.zone,
             fd.seq_no;

  --ORDER BY fd.order_id, fd.order_line_id, fd.float_no, fd.zone;
  --ORDER BY fd.order_id, fd.order_line_id, fd.order_seq, fd.seq_no, fd.float_no, fd.zone; --Matrix
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || '])'
         || '  This procedure updates FLOAT_DETAIL.BC_ST_PIECE_SEQ',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_batch_no should
   -- be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Initialization
   --
   l_previous_order_id      := NULL;
   l_previous_order_line_id := NULL;
   l_previous_order_seq     := NULL; --Matrix

   FOR r_float_detail IN c_float_detail(i_route_batch_no, i_route_no)
   LOOP

      IF (    l_previous_order_id      = r_float_detail.order_id
          AND l_previous_order_line_id = r_float_detail.order_line_id
          AND l_previous_order_seq     = r_float_detail.order_seq )   --Matrix
      THEN
         l_bc_st_piece_seq := l_previous_piece_count + 1;
      ELSE
         l_bc_st_piece_seq := 1;
         l_previous_piece_count := 0;
         dbms_output.put_line('=================================================================================================================');
      END IF;

      dbms_output.put_line(
                  'route_no:'         || r_float_detail.route_no
               || ' batch_no:'        || r_float_detail.batch_no
               || ' float_no:'        || r_float_detail.float_no
               || ' zone:'            || r_float_detail.zone
               || ' order_seq:'       || r_float_detail.order_seq
               || ' order_id:'        || r_float_detail.order_id
               || ' order_line_id:'   || r_float_detail.order_line_id
               || ' prod_id:'         || r_float_detail.prod_id
               || ' uom:'             || r_float_detail.uom
               || ' qty_alloc:'       || r_float_detail.qty_alloc
               || ' float_detail_status:' || r_float_detail.float_detail_status
               || ' st_piece_seq:'    || r_float_detail.st_piece_seq
               || ' bc_st_piece_seq:' || r_float_detail.bc_st_piece_seq
               || '  piece_count:'    || r_float_detail.piece_count
               || '  l_bc_st_piece_seq:' || l_bc_st_piece_seq);

      --
      -- For error messages.
      --
      l_float_no             := r_float_detail.float_no;
      l_float_detail_seq_no  := r_float_detail.seq_no;


      Pl_Text_Log.Ins_Msg('FATAL','PL_ORDER_PROCESSING','PL_ORDER_PROCESSING: Before updating float_detail float_no:'   || r_float_detail.float_no
                      || ' order_seq:'        || R_Float_Detail.Order_Seq
                      || ' seq_no:'       || R_Float_Detail.seq_no
                      , NULL, NULL);
      --
      -- Update the float_detail record with the piece sequence.
      -- Start a new block to trap errors.
      --
      BEGIN
         UPDATE float_detail fd
            SET fd.bc_st_piece_seq = l_bc_st_piece_seq,
                fd.st_piece_seq    = l_bc_st_piece_seq
          WHERE fd.float_no  = r_float_detail.float_no
            AND fd.seq_no    = r_float_detail.seq_no;
      EXCEPTION
         WHEN OTHERS THEN
            --
            -- Got an oracle error.  Log it and keep going.  Do not stop processing.
            --
      l_message := 'TABLE=float_detail  ACTION=UPDATE'
          || '  KEY=[' || TO_CHAR(r_float_detail.float_no) || ']'
          || '[' || TO_CHAR(r_float_detail.seq_no) || '](r_float_detail.float_no,r_float_detail.seq_no)'
          || '  MESSAGE="Failed to date bc_st_piece_seq and st_piece_seq.'
          || '  This will not stop processing but will cause a failure on the RF'
          || ' when the batch is download."';

            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['              || i_route_no                     || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      END;

      l_num_records_processed := l_num_records_processed + 1;

      l_previous_order_id       := r_float_detail.order_id;
      l_previous_order_line_id  := r_float_detail.order_line_id;
      l_previous_order_seq      := r_float_detail.order_seq;  --Matrix
      l_previous_piece_count    := r_float_detail.piece_count + l_previous_piece_count;

   END LOOP;     -- end the route batch number/route loop

   --
   -- Log the counts.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '(i_route_batch_no['          || TO_CHAR(i_route_batch_no)        || '],'
                     || 'i_route_no['                 || i_route_no                       || '])'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed) || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (i_route_batch_no['   || TO_CHAR(i_route_batch_no)   || '],'
                     || 'i_route_no['            || i_route_no                  || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_n can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no['     || i_route_no                || '])'
                   || '  One and only one of these two parameters can have a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['              || i_route_no                     || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END update_float_detail_piece_seq;

PROCEDURE Auto_Gen_Route IS

  l_sysconfig VARCHAR2(30); 
  saverec     NUMBER(3);
  host_str    VARCHAR2(255);
  username    VARCHAR2(15);
  l_route_no route.route_no%type;
  l_truck_no route.truck_no%type;
  l_message       VARCHAR2(356);
  l_context       VARCHAR2(100);
  l_mx_config     VARCHAR2(1);
  l_auto_gen      VARCHAR2(3) := 'Y';
  l_purge_running VARCHAR2(3);
  
  l_ermsg1  VARCHAR2 (256);
  l_ermsg2  VARCHAR2 (256);
  l_ermsg3  VARCHAR2 (256);
  l_hstcl_rc VARCHAR2(500); --return code for Host_Command Call
 
  
  CURSOR gen_route
  IS
    -- query for all the routes to be picked up for auto generate
	  SELECT r.route_no, ri.METHOD_ID,ri.F_DOOR,ri.C_DOOR,ri.D_DOOR
    FROM route_info ri,  route r
    WHERE 1              = 1
    AND ri.route_no      = r.truck_no
    AND ri.auto_gen_flag = 'Y'
   -- AND ri.route_no      ='AGR'
    And R.Status         ='NEW'
    	Union	  	  
   SELECT o.route_no, g.method_id, g.door_no,g.door_no,g.door_no
    FROM ordm o, getmeat_cust_setup g
    Where Pl_Common.F_Get_Syspar('ENABLE_FINISH_GOODS', 'N') = 'Y'
    And O.Cust_Id = G.Cust_Id;
	
	CURSOR finish_cur IS
  SELECT o.route_no, g.method_id, g.door_no 
    FROM ordm o, 
	     getmeat_cust_setup g,
		 route r
    Where Pl_Common.F_Get_Syspar('ENABLE_FINISH_GOODS', 'N') = 'Y'
	AND Pl_Common.F_Get_Syspar('ENABLE_FOOD_PRO', 'N') = 'N'
    And O.Cust_Id = G.Cust_Id
	AND O.route_no = r.route_no
	AND r.status = 'NEW';
    	

  
BEGIN
  FOR finish_rec in finish_cur LOOP
      UPDATE route 
	     SET F_DOOR = finish_rec.door_no,
		     C_DOOR = finish_rec.door_no,
			 D_DOOR = finish_rec.door_no
	   WHERE route_no = finish_rec.route_no;
	   commit;
  END LOOP;
  
  l_message := 'Cannot process Auto Route Generation at this time!' ;
  -- ensure METHOD_ID,F_DOOR,C_DOOR,D_DOOR are all populated for each route in the route_info table
  FOR i IN gen_route
  LOOP

		 
    IF i.METHOD_ID IS NULL OR i.F_DOOR IS NULL OR i.C_DOOR IS NULL OR i.D_DOOR IS NULL THEN
      l_context    := 'Route Info missing';
      pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
	  
      l_auto_gen := 'N';
    END IF;
    --validate_ssl (i.route_no);
    
   BEGIN
    pl_order_processing.validate_ordd_against_ssl ('REG', 'PAL', l_ermsg1, route_no=>i.route_no);
    pl_order_processing.validate_ordd_against_ssl ('REG', 'NOR', l_ermsg2, route_no=>i.route_no);
    pl_order_processing.validate_ordd_against_ssl ('REG', 'UNI', l_ermsg3, route_no=>i.route_no);
    
    l_context   := 'validate_ordd_against_ssl';
    
    IF l_ermsg1 IS NOT NULL THEN
      pl_log.ins_msg('WARNING', l_context, l_ermsg1, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
      l_auto_gen := 'N';
    END IF;
    IF l_ermsg2 IS NOT NULL THEN
      pl_log.ins_msg('WARNING', l_context, l_ermsg2, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
      l_auto_gen := 'N';
    END IF;
    IF l_ermsg3 IS NOT NULL THEN
      pl_log.ins_msg('WARNING', l_context, l_ermsg3, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
      l_auto_gen := 'N';
    END IF;
    --Check_For_Purge;
    l_purge_running := NULL;
    
    SELECT SUBSTR(config_flag_val,1,1)
    INTO l_purge_running
    FROM sys_config
    WHERE config_flag_name = 'CURRENTLY_PURGING_ORDERS';
    
    IF l_purge_running     = 'Y' THEN
      l_context           := 'Order Purge is Running';
      -- insert message in to swms_log
      pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
      l_auto_gen := 'N';
    END IF;
    
  EXCEPTION
  WHEN no_data_found THEN
    -- insert message in to swms_log
    pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
    l_auto_gen := 'N';
  WHEN OTHERS THEN
    NULL;
  END;
  
  BEGIN
  
    SELECT nvl(config_flag_val, 'N')
    INTO l_sysconfig
    FROM sys_config
    WHERE config_flag_name = 'AUTO_GEN_ROUTE_PRCSS';
    
    IF l_sysconfig        <> 'N' THEN
      l_context           := 'CRT AUTO ROUTE GEN Process is Running';
      --insert in to swms_log crt PROCESS IS RUNING ;
      pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
      l_auto_gen := 'N';
    ELSE
      UPDATE sys_config
      SET config_flag_val    = 'Y'
      WHERE config_flag_name = 'AUTO_GEN_ROUTE_PRCSS';
      COMMIT;
      l_auto_gen := 'Y';
    END IF;
    
  EXCEPTION
  WHEN OTHERS THEN
    --insert in to swms_log ;
    l_context := 'Exception checking for Gen route process';
    --insert in to swms_log crt PROCESS IS RUNING ;
    pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
    l_auto_gen := 'N';
  END;
  
  IF pl_matrix_common.chk_matrix_enable = TRUE THEN
    BEGIN
      SELECT config_flag_val
      INTO l_mx_config
      FROM sys_config
      WHERE config_flag_name = 'MX_INV_SYNC_FLAG' FOR UPDATE NOWAIT;
      
      IF l_mx_config         = 'N' THEN
        UPDATE sys_config
        SET config_flag_val    = 'O'
        WHERE config_flag_name = 'MX_INV_SYNC_FLAG';
        COMMIT;
      ELSIF l_mx_config = 'I' THEN
        l_context      := 'Matrix inventory sync is running.';
        --insert in to swms_log crt PROCESS IS RUNING ;
        pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
        l_auto_gen := 'N';
      END IF;
    END;
  END IF;

  BEGIN
    /*
    ** Generate the route.
    */
    IF l_auto_gen = 'Y' THEN
    
      UPDATE sys_config
      SET config_flag_val    = 'N'
      WHERE config_flag_name = 'AUTO_GEN_ROUTE_PRCSS';
      
      COMMIT;
    
      host_str := 'nohup CRT_order_proc ' || '"r" "' || i.route_no || '"' || ' >>/tmp/' || 'SWMS' || '.nohup';
      l_hstcl_rc := DBMS_HOST_COMMAND_FUNC('swms',host_str);
     
      l_context := 'After CRT Order Process return code-'||l_hstcl_rc;
      l_message:= 'Successfully called CRT_order_proc';
   
      pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
      dbms_output.put_line('After CRT Order Process return code-'||l_hstcl_rc);
            
      IF pl_matrix_common.chk_matrix_enable = TRUE THEN
      
         UPDATE sys_config
         SET config_flag_val    = 'N'
         WHERE config_flag_name = 'MX_INV_SYNC_FLAG';
         COMMIT;
      End If;
      
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    l_context := 'Exception when running CRT_order_proc';
    --insert in to swms_log crt PROCESS IS RUNING ;
    pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
    
    IF pl_matrix_common.chk_matrix_enable = TRUE THEN
    
       UPDATE sys_config
       SET config_flag_val    = 'N'
       WHERE config_flag_name = 'MX_INV_SYNC_FLAG';
       COMMIT;
    End If;
    
    UPDATE sys_config
    SET config_flag_val    = 'N'
    WHERE config_flag_name = 'AUTO_GEN_ROUTE_PRCSS';
    
    COMMIT;
    --send email alert...
  END;
END LOOP;
EXCEPTION
WHEN OTHERS THEN
  l_context := 'Exception when running CRT_order_proc';
  --insert in to swms_log crt PROCESS IS RUNING ;
  pl_log.ins_msg('WARNING', l_context, l_message, SQLCODE, SQLERRM, 'ORDER PROCESS', 'PL_Order_Process.AutoGen_Route', 'N');
  
  IF pl_matrix_common.chk_matrix_enable = TRUE THEN
     UPDATE sys_config
     SET config_flag_val    = 'N'
     WHERE config_flag_name = 'MX_INV_SYNC_FLAG';
     COMMIT;
  End If;
  
  
  UPDATE sys_config
  SET config_flag_val    = 'N'
  WHERE config_flag_name = 'AUTO_GEN_ROUTE_PRGS';
  
  COMMIT;
END;


------------------------------------------------------------------
-- Procedure:
--    p_update_meat_ord_cw
--
-- Description:
--    This procedure for meat company will populate catch weight for each item from INV_CASES_HIST for every order in route.
--    Catch weight is populated only if the order is BTP and if the product is Finished Good.
--	  If the inventory location of an item belongs to Rule_id=9, then it's identified as BTP order.
--	  During the order generation, even if the order received partial produced cases from sigma, 
--	  the float is marked as CW "Collected".
--
------------------------------------------------------------------
PROCEDURE p_update_meat_ord_cw(i_route_batch_no route.route_batch_no%TYPE) 
IS

   l_procedure_name VARCHAR2(256) := 'p_update_meat_ord_cw';
   l_message 		swms_log.msg_text%TYPE;
   l_count			NUMBER := 0;
   l_seq_no         NUMBER := 0;
   l_float_qty      NUMBER := 0;
   l_case_count     NUMBER := 0;
   l_temp_count		NUMBER := 0;
   l_case_weight    inv_cases.weight%TYPE;
   l_box_id         inv_cases.box_id%TYPE;
   l_pallet_id      inv_cases.logi_loc%TYPE;
   l_loc            lzone.logi_loc%TYPE;
   l_rule_id        zone.rule_id%TYPE;

    CURSOR c_route 
    IS
    SELECT	r.seq_no, r.route_no, r.status 
      FROM	route r
     WHERE	route_batch_no = i_route_batch_no
     ORDER	BY r.seq_no;

   CURSOR  c_order(p_route_no VARCHAR2) 
   IS
   SELECT  m.route_no, m.order_id, d.prod_id 
     FROM  ordm m, ordd d 
	WHERE  m.ORDER_ID = d.order_id 
	  AND  m.route_no = p_route_no
	  AND  m.cross_dock_type != 'BP' 
    GROUP BY m.route_no, m.order_id, d.prod_id
    ORDER BY m.route_no, m.order_id, prod_id;
    
    CURSOR c_cases(p_order_id VARCHAR2, p_prod_id VARCHAR2) 
    IS 
    SELECT order_id, prod_id, seq_no  
      FROM ordcw
     WHERE order_id = p_order_id 
       AND prod_id = p_prod_id
       AND catch_weight IS NULL
       AND cw_type= 'I'
    ORDER BY order_id, prod_id, seq_no;
    
BEGIN
    pl_log.ins_msg
        (pl_log.ct_info_msg, 'p_update_meat_ord_cw',
         'Starting procedure p_update_meat_ord_cw for i_route_batch_no['
				|| i_route_batch_no || '])',
         NULL, NULL,
         'ORDER PROCESSING', 'pl_order_processing');

    IF pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y' THEN
       FOR r_route IN c_route LOOP
            
            BEGIN
              FOR r_order IN c_order (r_route.route_no) 
              LOOP
                pl_log.ins_msg
                    (pl_log.ct_info_msg, 'p_update_meat_ord_cw',
                    'Entering FOR loop... procedure p_update_meat_ord_cw for route_no['
                        || r_route.route_no || '], OrderId['||r_order.order_id ||']',
                    NULL, NULL,
                    'ORDER PROCESSING', 'pl_order_processing');
        
                    -- Check if the Item is a Finished Good
                    SELECT count(*)
                    INTO l_count  
                    FROM pm 
                    WHERE prod_id = r_order.prod_id
                    AND FINISH_GOOD_IND = 'Y';
                    
                    l_seq_no := 0;
                    IF l_count > 0 THEN
                        pl_log.ins_msg
                        (pl_log.ct_info_msg, 'p_update_meat_ord_cw',
                             'Route[' || r_route.route_no || '], Order['||r_order.order_id ||'], ProdId['||r_order.prod_id||'] is FG Item',
                             NULL, NULL,
                             'ORDER PROCESSING', 'pl_order_processing');
        
                    -- Get catch weight from inv_cases_hist
                    FOR r_cases IN c_cases (r_order.order_id, r_order.prod_id) 
                    LOOP
                    BEGIN					
                        l_seq_no := l_seq_no+1;
						
						SELECT distinct ch.weight, ch.box_id, i.logi_loc, i.plogi_loc, rule_id 
                          INTO l_case_weight, l_box_id, l_pallet_id, l_loc, l_rule_id   
                        FROM inv_cases_hist ch, inv_hist i , zone z, lzone lz  
                        WHERE ch.logi_loc = i.logi_loc 
                         AND ch.order_id=i.inv_ORDER_ID 
						 AND ch.prod_id = i.prod_id 
                         and trunc(i.INV_DEL_DATE)=trunc(sysdate) 
                         AND lz.logi_loc=i.plogi_loc 
						 AND z.zone_id=lz.zone_id   
                         and z.zone_type='PUT' 
						 AND ch.order_id = r_cases.order_id 
                         AND ch.prod_id = r_cases.prod_id
                         AND NVL(ch.allocate_ind,'N') = 'N'
                         AND rownum=1
						ORDER BY ch.box_id;
                        
						pl_log.ins_msg 
						(pl_log.ct_info_msg, 'p_update_meat_ord_cw',
                             'Route[' || r_route.route_no || '], Order['||r_order.order_id ||'], ProdId['||r_order.prod_id||'], box_id['||l_box_id ||'], pallet_id='||l_pallet_id||', loc='||l_loc||', rule_id='||l_rule_id,
                             NULL, NULL,
                             'ORDER PROCESSING', 'pl_order_processing');
						
						IF l_rule_id = 9 THEN
							UPDATE ordcw  
							SET catch_weight = l_case_weight,
								cw_type = 'A' 
							WHERE order_id = r_cases.order_id 
							AND prod_id = r_cases.prod_id
							and seq_no = l_seq_no
							and rownum=1;
	 
							UPDATE inv_cases_hist 
							SET allocate_ind = 'Y'
							WHERE order_id = r_cases.order_id
							AND prod_id = r_cases.prod_id
							AND box_id = l_box_id;
                       
                        -- COMMIT;
						END IF; --end of rule id 
					EXCEPTION 
						WHEN no_data_found THEN
							NULL;
						WHEN OTHERS THEN
						l_message := 'Error updating ordcw.catch_weight or catch_wt_trk or allocated_ind for RouteNo['||r_route.route_no||'], OrderId[' || r_cases.order_id 
									|| '], ProdId['||r_cases.prod_id||'], BoxId['||l_box_id||']';
						pl_log.ins_msg ('FATAL', 'p_update_meat_ord_cw', l_message, 
									SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
            
                    END; -- end of begin cases 
                    END LOOP; --c_cases loop

                    BEGIN -- Update float detail if sigma data received for the produced cases for BTP orders 
                        SELECT COUNT(*) 
                        INTO l_case_count 
                        FROM ordcw
                        WHERE order_id = r_order.order_id 
                        AND prod_id = r_order.prod_id
                        AND catch_weight IS NOT NULL
                        AND cw_type= 'A';
                        
						-- Update the float detail even for partial produced qty received from sigma
                        IF l_case_count > 0 THEN                    
                            UPDATE float_detail fd 
                            SET catch_wt_trk = 'C' -- Set to C so that SOS does not prompt selector to collect cw.
                            WHERE order_id = r_order.order_id
                            AND prod_id = r_order.prod_id 
                            AND catch_wt_trk = 'Y' 
							AND EXISTS
								( SELECT 1 FROM ZONE z, lzone lz, inv_hist i 
									WHERE lz.logi_loc= fd.src_loc 
									AND fd.order_id = r_order.order_id 
									AND z.zone_id=lz.zone_id
									AND z.zone_type = 'PUT'
									AND z.rule_id = 9							
									AND i.plogi_loc = fd.src_loc
									AND i.qoh = fd.qty_order
									AND i.prod_id = fd.prod_id
									AND i.inv_order_id = fd.order_id
									AND i.status != 'CDK'
								); 					                            
                        ELSE
                            l_message := 'WARN: Float details catch weight track is not updated for RouteNo['||r_order.route_no||'], OrderId[' || r_order.order_id 
                                        || '], ProdId['||r_order.prod_id||'], CaseQty['||l_case_count||']';
                            pl_log.ins_msg (pl_log.ct_info_msg, 'p_update_meat_ord_cw', l_message, 
                                        SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
                        END IF;

					EXCEPTION 
						WHEN no_data_found THEN
							NULL;
 						WHEN OTHERS THEN
                        l_message := 'Error updating ordcw.catch_weight for RouteNo['|| r_route.route_no ||']';
                        pl_log.ins_msg ('FATAL', 'p_update_meat_ord_cw', l_message, 
                                SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
                    END; --end of order block
     
                   END IF; --end of l_count IF
                 END LOOP; --c_order loop
			EXCEPTION 
				WHEN no_data_found THEN
					NULL;
             	WHEN OTHERS THEN
                    l_message := 'Error updating ordcw.catch_weight for RouteNo['|| r_route.route_no ||']';
                    pl_log.ins_msg ('FATAL', 'p_update_meat_ord_cw', l_message, 
                                SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
          END; --end of order block
       END LOOP; --- c_route loop
	   COMMIT;
  END IF; --end of syspar check 
  
EXCEPTION WHEN OTHERS THEN
		l_message := 'Error updating ordcw.catch_weight for RouteBatch[' || i_route_batch_no || ']';
		pl_log.ins_msg ('FATAL', 'p_update_meat_ord_cw', l_message, 
				SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
    
END p_update_meat_ord_cw; 


PROCEDURE route_recover_invcases(i_route_no route.route_no%TYPE) 
IS 
   --l_procedure_name VARCHAR2(256) := 'route_recover_invcases';
   l_message 		swms_log.msg_text%TYPE;
   
   CURSOR c_order IS
   SELECT m.order_id  
     FROM ordm m 
	WHERE m.route_no = i_route_no 
    ORDER BY m.order_id;

BEGIN
    IF pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y' THEN
       FOR r_order IN c_order  
          LOOP
            pl_log.ins_msg
                (pl_log.ct_info_msg, 'route_recover_invcases',
                'Entering FOR loop... procedure route_recover_invcases for route_no['
                    || i_route_no || '], OrderId['||r_order.order_id ||']',
                NULL, NULL,
                'ORDER PROCESSING', 'pl_order_processing');
        
          INSERT INTO INV_CASES 
            (PROD_ID ,REC_ID,ORDER_ID,BOX_ID,PACK_DATE,WEIGHT,UPC,LOGI_LOC,ALLOCATE_IND, ADD_USER,ADD_DATE,UPD_USER,UPD_DATE)
          SELECT PROD_ID ,REC_ID,ORDER_ID,BOX_ID,PACK_DATE,WEIGHT,UPC,LOGI_LOC,'N', ADD_USER,ADD_DATE,UPD_USER,UPD_DATE 
            FROM inv_cases_hist  
           WHERE order_id = r_order.order_id
             AND allocate_ind='Y';

         DELETE FROM INV_CASES_HIST 
         WHERE order_id = r_order.order_id
         AND allocate_ind='Y';
         
        END LOOP;
        COMMIT;
        
  		l_message := 'Successfully recovered INV_CASES for Route[' || i_route_no || ']';
		pl_log.ins_msg ('INFO', 'route_recover_invcases', l_message, 
				SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
    END IF;    

EXCEPTION WHEN OTHERS THEN
		l_message := 'Error in recovering INV_CASES for Route[' || i_route_no || ']';
		pl_log.ins_msg ('FATAL', 'route_recover_invcases', l_message, 
				SQLCODE, SQLERRM, 'ORDER PROCESSING', 'pl_order_processing');
END route_recover_invcases;


---------------------------------------------------------------------------
-- Procedure:
--    upd_normal_selection_floats
--
-- Description:
--    This procedure updates any relevant columns for normal selection FLOATS
--    after the float are built and inventory allocated.
--
--    What is updated:
--       floats.is_sleeve_selection
--
-- Parameters:
--    NOTE: One and only one parameter i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    post_float_processing
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/13/20 bben0556 Brian Bent
--                      Created as part of the sleeve selection changes.
---------------------------------------------------------------------------
PROCEDURE upd_normal_selection_floats
         (i_route_batch_no  IN  route.route_batch_no%TYPE    DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE          DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'upd_normal_selection_floats';
   l_message       VARCHAR2(512);  -- Work area

   l_num_records_processed   PLS_INTEGER;   -- Number of records read.  Used in log messages.
   l_num_sleeve_sel_updated  PLS_INTEGER;   -- Number of floats having sleeve selection updated to Y.  Used in log messages.

   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of parameters.

   --
   -- This cursor selects the normal selection FLOATS to update.
   --
   -- Several columns selected to use in log messages.
   --
   CURSOR c_normal_selection_floats(cp_route_batch_no  route.route_batch_no%TYPE,
                                    cp_route_no        route.route_no%TYPE)
   IS
   SELECT r.route_batch_no            route_batch_no,
          r.method_id                 method_id,
          f.batch_no                  batch_no,
          f.float_no                  float_no,
          f.route_no                  route_no,
          f.group_no                  group_no,
          f.comp_code                 comp_code,
          f.door_area                 door_area,
          f.pallet_pull               pallet_pull,
          f.home_slot                 home_slot,
          f.is_sleeve_selection       floats_is_sleeve_selection,
          f.status                    floats_status,
          r.d_door                    d_door,
          r.c_door                    c_door,
          r.f_door                    f_door,
          se.is_sleeve_selection      sel_equip_is_sleeve_selection,     -- Selection equipment setup designates if sleeve selection
          se.no_of_zones              no_of_zones
     FROM floats f,
          route r,
          sel_equip se
    WHERE (   r.route_batch_no    = cp_route_batch_no
           OR f.route_no          = cp_route_no)
      --
      AND f.route_no              = r.route_no
      AND f.pallet_pull           IN ('N')         -- Select only the normal selection batches.
      AND se.equip_id             = f.equip_id
    ORDER BY f.batch_no, f.float_no;

BEGIN
   l_message := 'Starting procedure' || ' (i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
         || 'i_route_no[' || i_route_no || '])'
         || '  This procedure updates any relevant columns for normal selection FLOATS'
         || ' after the floats are built and inventory allocated.';

   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name, l_message, NULL, NULL,
         ct_application_function, gl_pkg_name);

   DBMS_OUTPUT.PUT_LINE(l_message);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_no should be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '])'
                   || '  Before loop to update FLOATS table';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message, pl_exc.ct_data_error, NULL,
                  ct_application_function, gl_pkg_name);

   DBMS_OUTPUT.PUT_LINE(l_message);

   --
   -- Initialization
   --
   l_num_records_processed    := 0;
   l_num_sleeve_sel_updated   := 0;

   --
   -- Loop through the floats updating:  floats.is_sleeve_selections_flag
   --
   FOR r_floats IN c_normal_selection_floats(i_route_batch_no, i_route_no) LOOP

      l_num_records_processed := l_num_records_processed + 1;

      --
      -- Log a bunch of stuff.  Main reason is for trouble shooting.
      --
      l_message :=
           'In loop.  Float info: route batch no[' || r_floats.route_batch_no                 || ']'
           || '  method_id['                       || r_floats.method_id                      || ']'
           || '  batch_no['                        || TO_CHAR(r_floats.batch_no)              || ']'
           || '  float no['                        || TO_CHAR(r_floats.float_no)              || ']'
           || '  route no['                        || r_floats.route_no                       || ']'
           || '  group_no['                        || TO_CHAR(r_floats.group_no)              || ']'
           || '  comp_code['                       || r_floats.comp_code                      || ']'
           || '  door_area['                       || r_floats.door_area                      || ']'
           || '  pallet_pull['                     || r_floats.pallet_pull                    || ']'
           || '  home_slot['                       || r_floats.home_slot                      || ']'
           || '  floats_status['                   || r_floats.floats_status                  || ']'
           || '  floats.is_sleeve_selection['      || r_floats.floats_is_sleeve_selection     || ']'
           || '  d_door['                          || r_floats.d_door                         || ']'
           || '  c_door['                          || r_floats.c_door                         || ']'
           || '  f_door['                          || r_floats.f_door                         || ']'
           || '  sel_equip.is_sleeve_selection['   || r_floats.sel_equip_is_sleeve_selection  || ']'
           || '  sel_equip.no_of_zones['           || TO_CHAR(r_floats.no_of_zones)           || ']';

      
      --
      -- 10/14/20 Brian Bent Don't log each record. It creates too many messages.
      -- pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message, NULL, NULL,
      --                ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_message);

      -- 
      -- Update floats.is_sleeve_selection if the selection equipment is flagged as sleeve selection.
      -- 
      IF (r_floats.sel_equip_is_sleeve_selection = 'Y')
      THEN
         UPDATE floats f
            SET is_sleeve_selection = 'Y'
          WHERE f.float_no = r_floats.float_no;

         l_num_sleeve_sel_updated := l_num_sleeve_sel_updated + 1;
      ELSE
         UPDATE floats f
            SET is_sleeve_selection = 'N'
          WHERE f.float_no = r_floats.float_no;
      END IF;

      --
      -- 01/16/20 Brian Bent  Log if a record not updated.
      --
      IF (SQL%NOTFOUND) THEN
         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'float_no['      || TO_CHAR(r_floats.float_no) || ']'
                                       || '  No FLOATS record updated.  This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      END IF;

   END LOOP;

   l_message := 'i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '])' || '  After floats loop';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message, NULL, NULL, ct_application_function, gl_pkg_name);
   DBMS_OUTPUT.PUT_LINE(l_message);

   l_message := 'i_route_batch_no[' || TO_CHAR(i_route_batch_no) || ']' 
                  || '  Number of floats processed:' || l_num_records_processed
                  || '  Number of floats is_sleeve_selection updated to Y:' || l_num_sleeve_sel_updated;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message, NULL, NULL, ct_application_function, gl_pkg_name);
   DBMS_OUTPUT.PUT_LINE(l_message);

   l_message := 'Ending procedure (i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '])';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message, NULL, NULL, ct_application_function, gl_pkg_name);
   DBMS_OUTPUT.PUT_LINE(l_message);
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_no can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.';

      pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);
   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '])'
                   || '  Error occurred';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END upd_normal_selection_floats;


---------------------------------------------------------------------------
-- Procedure:
--    post_float_processing
--
-- Description:
--    This procedure performs actions needed after ALL the floats are built
--    and inventory is allocated to the floats.
--
-- Parameters:
--    NOTE: One and only one parameter i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    order_proc.poc
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    10/13/20 bben0556 Brian Bent
--                      Project: R44-Jira3222_Sleeve_selection
--                      Created
--                      Initially created to assign value to FLOATS.IS_SLEEVE_SELECTION
--                      Copied and modified the RDC version.
--
--    07/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      Add call to procedure "pl_xdock_op.update_floats" to update the FLOATS
--                      cross_dock_type,  site_from and site_to.  It is far less risky
--                      to have a separate of FLOATS then try do populate these columns
--                      when the float is created.
--
---------------------------------------------------------------------------
PROCEDURE post_float_processing
         (i_route_batch_no  IN  route.route_batch_no%TYPE    DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE          DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'post_float_processing';
   l_message       VARCHAR2(512);  -- Work area

   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of parameters.
BEGIN
   l_message := 'Starting procedure' || ' (i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
         || 'i_route_no[' || i_route_no || '])'
         || '  This procedure performs actions needed after ALL the floats are built'
         || ' and inventory is allocated to the floats.';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  l_message, NULL, NULL, ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_batch_no should
   -- be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Update floats.is_sleeve_selection
   --
   upd_normal_selection_floats(i_route_batch_no => i_route_batch_no, i_route_no => i_route_no);

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Ending procedure'
                  || '  (i_route_batch_no['   || TO_CHAR(i_route_batch_no) || '])',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   --
   -- Update FLOATS for Xdock processing.
   --
   pl_xdock_op.update_floats(i_route_batch_no => i_route_batch_no, i_route_no => i_route_no);
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_no can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.';

      pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);
   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['   || TO_CHAR(i_route_batch_no) || '])',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END post_float_processing;


END pl_order_processing;
/


