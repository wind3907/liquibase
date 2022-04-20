CREATE OR REPLACE PACKAGE  pl_sts_pod_interface_in
AS

   -- sccs_id=@(#) src/schema/plsql/pl_sts_interfaces.sql,
   -----------------------------------------------------------------------------
   -- Package Name:
   --   pl_sts_interfaces
   --
   -- Description:
   --    Processing of Stored procedures and table functions for interfaces(SCI011, SCI012) using staging tables.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    02/09/15 SPOT3255 Created.
   --    03/05/15 AVIJ3336 Added logic to populate the sts outbound staging table.
   --    09/23/15 SPOT3255 Removed column:Notes from cursor:get_stop_record
   --                      to eliminate the duplicated orders on STS.
   --    10/28/15 spot3255 Charm#6000009282: Restricted the route process(P_STS_IMPORT) to SWMS
   --					   if route was already processed

   --   29/10/15 MDEV3739  Charm#6000008485 - Populating the catch weight column and catch_wt_trk in
   --                     the STS_ROUTE_OUT table.
   --   05-Jan-17 jluo6971 CRQ000000017293 Fixed issues on same STS barcode
   --                      piece values for 2+floats/same item
   --                      using bc_st_piece_seq. --- REMOVED the changes done in this CRQ
   --   11/22/16 skam7488  Changes has been doen to format the date while fetching the data from sts_route_out
   --                      CRQ000000017293-Modified the code not to update the sts_process_flag to 'N' if the
   --                      process is already running to avoid duplicate barcode issue.
   --   01/17/17 skam7488  CRQ000000017293-Incorporated the missed date format changes.
   --   02/14/17 avij3336  CRQ000000022702 - 1. Reffer product id as character
   --                           			       2. update STS_PROCESS_RUN_FLAG  to 'N' in exception block
   --                                                             3. Changes in stop record cursor
   --   06/22/17 rrav5434  CRQ000000032720 - Added customer validation for unique stop records
   --   07/20/17 vkal9662  CRQ-31290 GS1 Barcode Flag chnages included
   --   08/02/17 lnic4226
   --			        chyd9155  CRQ34059 -To process the returns record received at stop level from STS
  --									      and send RTN and STC(stop close) at real time
    --   10/13/2017 chyd9155	CRQ-34059- added manifest close validation before adding returns
   --   03/28/2017 chyd9155 CRQ-47055 -Correct duplicate return pickup request for Non-POD customers and POD disabled OPCO
   --   04/13/2018 vkal9662/mpham Jira 399-added validations to handle return duplicates that may occur due to STS process
   --   08/15/2018 mpha8134 Add check if Tripmaster is done (count the CMP status return records). If tripmaster is done,
   --                       don't delete or modify returns. This was added to prevent data deletion when STS uploads multiple times
   --                       after Tripmaster is done.r
   --   08/01/2019 mcha1213 Jira OPCOF-2478 Returned quantity from STS is out of synch with SWMS
   --   10/13/19            Jira OPCOF-2510  10/02/19 take out Michael rs.reason_cd not like 'T%'
   --                          do not send 'STC' with T%, D% until MFC
   --                       in Pod_create_rtn only send to trans if it is route close
   --                       for R% or N% also send RTN to trans
   --   10/25/19            put back no STC for D T N01
   --   10/27/19            modify 'STC'
   --   01/26/20            Jira-2530 Send credit for split of non-splittables from STS to SWMS
   --                       Jira-2604 Missing Pick Up Request between STS and SWMS
   --   03/26/20            Jira- 2766 new pod with barcode, LOAD_RETURNS_BARCODE. For STS client version 6.07.05
   --                       insert into returns table then returns_barcode table
   --                       4/13 make changes after meeting with kiet
   --                       replace second c_stop_records cursor to c_stop_records_to_trans. 4/17 fix 'D' error and quantity
   --                       fix returns table where when do route close if rj already send to sus and no change from stop correction
   --                       don't insert into returns. 4/21 fix the barcode_ref_no seq generation, not generate an extra one.
   --                       4/22 use load_returns_barcode and work on SR 4/28 work on SR for stop close rtn qty = 0
   --                       4/29 do DI and SP 4/30 don't send STC to trans table for SR with D
   --                       5/4/20 works, no cust id in load return, 5/5 debug barcode_ref_no
   --                       5/7/20 fix reverse credit
   --                       5/12/20 do barcode is null exception, 5/13 chk cw in load return, each different barcode should have one barcode ref no
   --                       5/14/20 for route close update manifests.sts_completed_ind. Don't set returns.status to 'ERR'
   --                       5/15/20 for barcode length < 8 don't do immediate return, in cursor c_rj_dtl add wight
   --                               modify 'D' for returns table
   --                       5/16/20 try to fix route 5504 stop3 prod id 2637346 only 1 is in TRans table. this is before fix
   --                           pod_create_rtn add i_barcode parameter, fixed stop 3
   --                               work on stop 1 where cw are all 0. work on load_return proc v_rtn_count
   --                       5/17/20 fix v_stc_count got comment 0ut
   --                       5/18/20 add debug code to load_return see why route 5506 stop 3 not in returns table
   --                       5/19/20 for c_rj cursor rollup by barcode, opco said is ok to sum up cw
   --                       5/21/20 for load_return for l_ret_count take out r.catchweight = rb.catchweight and add one line for update returns 'D'
   --                       5/22/20 modify load_return's l_ret_count
   --                       6/1/20  take out item_id in c_rj cursor group by for checking 'F%' and related code
   --                       6/2/20  work on not allow immediate returns if manifest_dtls.status = 'RTN'
   --                       6/12/20 modify SR status shouldbe 'VAL' and modify returned_prod_id = prod_id if not W10, set rtn_sent_ind to 'N'
   --                       6/17/20 modify pod_create_rtn only get returns record create by STS
   --                       6/25/20 take out some debug msg
   --                       6/30/20 for stop close with no returns still wants to send STC to SUS except for N01, N50, R40
   --                       7/6/20  fix error where route close with one xml with more than 1 route, only the last route get manifests.set_completed_ind = Y
   --                       7/17/20 fix SP return qty
   --                       7/24/20 for SP, the returns table shipped_split_cd should be 0
   --                       9/2/20 fix stop close with event type tag issues
   --						10/6/20 fix SR issue causing inserting instead of updating the return table
   --                       12/7/20 fix duplicate recs in returns add returned_split_cd for duplication check
   --                       2/19/21 fix duplicate recs for different return reason cd in returns
   --                       2/22/21 fix opco 195 issue with SR with stop 1.01 error
   --						2/25/21 fix reverse credit
   --                       3/5/21  fix status not 'F' error
   --						3/15/21	fix duplicate recs due to DCI creates returns from DCI screen
   --                       4/13/21 fix 'D' issue due to barcode
   --                       5/6/21  do not create returns for a item already in returns created by swms user with same invoice no, prod id, stop no, route no
   --                5/11/21  fix issue with 'D' for the same invoice, proc id, return qty and different return reason code
   --                6/1/21   fix ora-01422 exact fetch error for shipped_split_cd
   --                08/27/21 Jira 3592 vkal9662 Add changes related to xdock process
   --                09/21/21 OPCOF-3669 jkar6681 Avoid updating STS_COMPLETED_IND to 'Y' for Manifest containing Xdock orders in Fullfillment Site.
   --                10/19/21 vkal9662 Fix for Jira 3726- failures in Production where all returns are failing when there is an issue in the batch
   -----------------------------------------------------------------------------

-- Table  Function for SCI011


    PROCEDURE P_STS_IMPORT_ASSET (i_route_no     sts_route_in.route_no%TYPE,
     i_cust_id      sts_route_in.cust_id%TYPE,
     i_barcode      sts_route_in.barcode%TYPE,
     i_qty          sts_route_in.quantity%TYPE,
     i_route_date   sts_route_in.route_date%TYPE,
     i_time_stamp   sts_route_in.time_stamp%TYPE,
     i_event_type   sts_route_in.event_type%TYPE,
     o_status       OUT NUMBER);

    PROCEDURE P_STS_IMPORT;

    PROCEDURE POD_create_RTN (
   i_manifest_number     IN   VARCHAR2,
   i_stop_number         IN   NUMBER,
   RTN_process_flag      OUT  BOOLEAN,
   i_cust_id             IN   VARCHAR2,
   i_route_no            in    varchar2,
   i_msg_id              in    varchar2,
   i_barcode           IN VARCHAR2);



   PROCEDURE  LOAD_RETURNS_BARCODE(
    sz_manifest_no IN VARCHAR,
	sz_sts_rec_type IN VARCHAR,
    sz_route_no IN VARCHAR,
    sz_invoice_num IN VARCHAR,
	sz_stop_no IN VARCHAR,
    sz_prod_id IN VARCHAR,
    sz_shipped_qty IN VARCHAR,
    sz_returned_qty IN VARCHAR,
    sz_barcode IN VARCHAR,
    sz_return_reason_cd IN VARCHAR,
    sz_weight IN VARCHAR,
    sz_barcode_refno in number,
	sz_rb_status in varchar,
	sz_msg_text in varchar);

   PROCEDURE LOAD_RETURN        (
    sz_manifest_no IN VARCHAR,
    sz_route_no IN VARCHAR,
    sz_stop_no IN VARCHAR,
    sz_rec_type IN VARCHAR,
    sz_invoice_num IN VARCHAR,
    sz_prod_id IN VARCHAR,
    sz_cust_pref_vendor IN VARCHAR,
    sz_return_reason_cd IN VARCHAR,
    sz_returned_qty IN VARCHAR,
    sz_returned_split_cd IN VARCHAR,
    sz_catchweight IN VARCHAR,
    sz_disposition IN VARCHAR,
    sz_returned_prod_id IN VARCHAR,
    sz_erm_line_id IN VARCHAR,
    sz_shipped_qty IN VARCHAR,
    sz_shipped_split_cd IN VARCHAR,
    sz_cust_id IN VARCHAR,
    sz_temperature IN VARCHAR,
	sz_stop_correction IN VARCHAR,
	sz_multi_pick_ind IN VARCHAR,
    sz_barcode_refno in number,
    sz_sts_rec_type IN VARCHAR,
    sz_status in varchar
    -- take out 5/19 sz_barcode in varchar  -- 5/14/20
  );


END pl_sts_pod_interface_in;
/


CREATE OR REPLACE PACKAGE BODY pl_sts_pod_interface_in AS
---------------------------------------------------------------------------
-- Private Modules
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_sts_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_ROUTE_OUT
--     and sends the result set data for SCI011 to SAP through PI middle ware.
--
-- Parameters:
--      Nonea
--
-- Return Values:
--    SAP_ROUTE_OUT_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/09/15 SPOT3255 Created.
--
--  6/2/20 work on new logic for allow immediate returns for rec in returns table created by CRT
----------------------------------------------------------------------------
/* Formatted on 2015/03/12 17:12 (Formatter Plus v4.8.8) */

    PROCEDURE load_return (
        sz_manifest_no         IN VARCHAR,
        sz_route_no            IN VARCHAR,
        sz_stop_no             IN VARCHAR,
        sz_rec_type            IN VARCHAR,
        sz_invoice_num         IN VARCHAR,
        sz_prod_id             IN VARCHAR,
        sz_cust_pref_vendor    IN VARCHAR,
        sz_return_reason_cd    IN VARCHAR,
        sz_returned_qty        IN VARCHAR,
        sz_returned_split_cd   IN VARCHAR,
        sz_catchweight         IN VARCHAR,
        sz_disposition         IN VARCHAR,
        sz_returned_prod_id    IN VARCHAR,
        sz_erm_line_id         IN VARCHAR,
        sz_shipped_qty         IN VARCHAR,
        sz_shipped_split_cd    IN VARCHAR,
        sz_cust_id             IN VARCHAR,
        sz_temperature         IN VARCHAR,
        sz_stop_correction     IN VARCHAR,
        sz_multi_pick_ind      IN VARCHAR,
        sz_barcode_refno       IN NUMBER,
        sz_sts_rec_type        IN VARCHAR,
        sz_status              IN VARCHAR
        --sz_barcode             in varchar
    ) IS

        i_erm_line_id         NUMBER;
        n_stop_no             NUMBER;
        sz_delivery_doc_num   manifest_stops.invoice_no%TYPE := sz_invoice_num;
        i_dci_rtn_exists      NUMBER;
        l_ret_count           NUMBER;
        v_stc_trans_count     NUMBER;
        v_rtn_count           NUMBER;
        v_cmp_count           NUMBER := 0; -- If count is > 0 then Tripmaster is completed. Do not update/insert
        v_pod_flag            manifest_stops.pod_flag%TYPE;
        status                manifests.manifest_status%TYPE;
        v_pod_rtn_ind         returns.pod_rtn_ind%TYPE := NULL;
        v_rtn_sent_ind        returns.rtn_sent_ind%TYPE := 'N';
        v_org_rsn_cd          returns.org_rtn_reason_cd%TYPE := NULL;
        v_org_catchweight     returns.org_catchweight%TYPE := NULL;
        v_org_qty             returns.org_rtn_qty%TYPE := NULL;

        v_cust_id             sts_route_in.cust_id%type;

        rb_rq                 returns_barcode.returned_qty%type;
        rb_cw                 returns_barcode.catchweight%type;

		l_dci_create_rtn	  number;
        v_opco_pod_flag       sys_config.config_flag_val%TYPE; -- 3/15/21 add

    BEGIN

        dbms_output.put_line('in pl_sts_pod_interface_in.load_return ');

        -- 7/17/20
        pl_log.ins_msg(
                'INFO',
                'LOAD_RETURN',
                'in p_sts_import in load_return with manifest= '||sz_manifest_no||' route= '||sz_route_no||
                ' stop_no = '|| sz_stop_no||' prod_id= '||sz_prod_id||
                    ' sz_returned_qty= '||sz_returned_qty||' sz_return_reason_cd= '||sz_return_reason_cd||
                    ' sz_shipped_qty='||sz_shipped_qty||' sz_shipped_split_cd'||sz_shipped_split_cd||
                    ' sz_catchweight='||sz_catchweight||' sz_barcode_refno'||sz_barcode_refno||
                    ' sz_invoice_num='||sz_invoice_num||' sz_sts_rec_type'||sz_sts_rec_type||
                    ' sz_status'||sz_status||' sz_rec_type= '|| sz_rec_type,
                    sqlcode,
                    sqlerrm,
                    'ORDER PROCESSING',
                    'pl_sts_pod_interface_in',
                    'u');

            -- 3/15/21
        SELECT config_flag_val
        INTO v_opco_pod_flag
        FROM sys_config
        WHERE config_flag_name = 'POD_ENABLE';

                -- add 5/4/20
        select cust_id
        into v_cust_id
        from sts_route_in
        where manifest_no= sz_manifest_no
        and route_no = sz_route_no
        and floor(alt_stop_no) = sz_stop_no -- 2/22/21
        and rownum =1
        and record_type = 'ST';

    -- 3/2/2007 - As per E. Freeman,stop number should be integer portion
        n_stop_no := floor(to_number(sz_stop_no) );
        i_dci_rtn_exists := 0;

    -- Anything other than pickup,get the invoice number from the manifest stop
        IF
            ( sz_rec_type != 'P' )
        THEN
            BEGIN
                SELECT DISTINCT
                    obligation_no
                INTO
                    sz_delivery_doc_num
                FROM
                    manifest_stops
                WHERE
                        manifest_no = sz_manifest_no
                    AND
                        invoice_no = sz_invoice_num
                    AND
                        ROWNUM = 1;

            EXCEPTION
                WHEN no_data_found THEN
                    sz_delivery_doc_num := sz_invoice_num;
            END;
        END IF; -- ( sz_rec_type != 'P' )

    -- CRQ46986 Returns were entered by CRT - Driver check-in clerk
    --			So reject STS upload from Driver which is of low precedence

        BEGIN
        -- CRQ48953 - STS returns issue due to pick up order
        --
            SELECT
                COUNT(*)
            INTO
                v_stc_trans_count
            FROM
                trans
            WHERE
                    rec_id = sz_manifest_no
                AND
                    route_no = sz_route_no
                AND
                    stop_no = sz_stop_no
                AND
                    trans_type = 'STC';

            SELECT
                COUNT(*)
            INTO
                v_rtn_count
            FROM
                returns
            WHERE
                    manifest_no = to_number(sz_manifest_no)
                AND
                    stop_no = n_stop_no
                AND
                    rec_type = sz_rec_type
                AND
                    obligation_no = sz_delivery_doc_num
                AND
                    prod_id = sz_prod_id
                AND
                    cust_pref_vendor = sz_cust_pref_vendor
                AND
                    return_reason_cd = sz_return_reason_cd
                AND
                    shipped_split_cd = sz_shipped_split_cd
                and  catchweight =    sz_catchweight  -- 5/13/20 add
                AND (
                        returned_split_cd IS NULL
                    OR
                        returned_split_cd = sz_returned_split_cd
                );

            SELECT DISTINCT
                nvl(
                    pod_flag,
                    'N'
                )
            INTO
                v_pod_flag
            FROM
                manifest_stops
            WHERE
                    manifest_no = to_number(sz_manifest_no)
                AND
                    stop_no = floor(to_number(sz_stop_no) )
                AND
                    obligation_no = sz_delivery_doc_num;

            SELECT
                manifest_status
            INTO
                status
            FROM
                manifests
            WHERE
                manifest_no = to_number(sz_manifest_no);

        --
        -- If there are any CMP status returns for the manifest,then tripmaster is complete.
        --
            /* 6/2/20 replace with new logic below
            SELECT
                COUNT(*)
            INTO
                v_cmp_count
            FROM
                returns r
            WHERE
                    r.manifest_no = to_number(sz_manifest_no)
                AND
                    r.status = 'CMP';

             */


            SELECT
                COUNT(*)
            INTO
                v_cmp_count
            from manifest_dtls md
            where status = 'RTN'
            and  md.manifest_no = sz_manifest_no
            and  md.stop_no = n_stop_no
            and  md.prod_id = sz_prod_id
            and  md.shipped_qty = sz_shipped_qty
            and  md.obligation_no = sz_delivery_doc_num;  -- sz_invoice_num;



            pl_log.ins_msg(
                'INFO',
                'LOAD_RETURN',
                'in p_sts_import in load_return before if status= OPN and v_cmp_count=0 with v_cmp_count= '||v_cmp_count||
                    ' status= '||status||' manif= '||sz_manifest_no||' route= '||sz_route_no
                            ||' stop_no = '|| n_stop_no||' prod_id= '||sz_prod_id||
                                ' shipped_qty= '||sz_shipped_qty||
                                ' obligation_no= '|| sz_delivery_doc_num,
                    sqlcode,
                    sqlerrm,
                    'ORDER PROCESSING',
                    'pl_sts_pod_interface_in',
                    'u');

        -- Only when manifest status is OPN and manifest_dtls.status != 'RTN'     --tripmaster has not been done yet.

            IF
                (status = 'OPN' AND v_cmp_count = 0)
            THEN


             pl_log.ins_msg(
                'INFO',
                'LOAD_RETURN',
                'in p_sts_import in load_return after if status= OPN and v_cmp_count=0 before if chking for v_pod_flag=  '||v_pod_flag||
                    ' v_stc_trans_count= '||v_stc_trans_count,
                    sqlcode,
                    sqlerrm,
                    'ORDER PROCESSING',
                    'pl_sts_pod_interface_in',
                    'u');

                /* 6/2/20 replace by next if
                IF
                    ( v_pod_flag = 'N' ) OR ( v_stc_trans_count = 0 AND v_pod_flag = 'Y' ) OR (
                        v_pod_flag IS NULL
                    ) OR ( v_stc_trans_count > 0 AND v_pod_flag = 'Y' )
                 */

                if  ( ( sz_sts_rec_type = 'ST' and v_pod_flag = 'Y') or ( sz_sts_rec_type = 'RT') )
                THEN


                    pl_log.ins_msg(
                        'INFO',
                        'LOAD_RETURN',
                        'in p_sts_import in load_return after checking for (v_pod_flag= Y and Stop close) or (route  close)',
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pl_sts_pod_interface_in',
                        'u');

                   /* 6/2/20 take out
                    SELECT
                        COUNT(*)
                    INTO
                        i_dci_rtn_exists
                    FROM
                        returns
                    WHERE
                            manifest_no = to_number(sz_manifest_no)
                        AND
                            nvl(
                                add_source,
                                'STS'
                            ) NOT IN (
                                'STS','MFR'
                            );

                     */

                    i_dci_rtn_exists := 0; -- 6/2/20 add

                    IF
                        ( i_dci_rtn_exists = 0 )
                    THEN
                        dbms_output.put_line('in pl_sts_pod_interface_in.load_return i_dci_rtn_exists is 0 ');

                -- No records in RETURNS by DCI clerk from CRT continue
                -- Attempt to update an existing record
                        IF
                            v_pod_flag <> 'Y'
                        THEN
                            v_org_rsn_cd := NULL;
                            v_org_qty := NULL;
                            v_org_catchweight := NULL;
                        ELSIF v_pod_flag = 'Y' THEN
                            v_org_rsn_cd := sz_return_reason_cd;
                            v_org_qty := to_number(sz_returned_qty);
                            v_org_catchweight := to_number(sz_catchweight);
                            IF
                                v_stc_trans_count > 0
                            THEN
                                dbms_output.put_line('in pl_sts_pod_interface_in.load_return in v_stc_trans_count > 0 ' || 'v_rtn_count= ' || TO_CHAR(v_rtn_count) );
                                IF
                                    v_rtn_count > 0
                                THEN -- If POD,a STC trans exists,and a return record exists,then set indicator to U
                                    v_pod_rtn_ind := 'U';
                                ELSE
                                    v_pod_rtn_ind := 'A';
                                END IF;

                            ELSIF v_stc_trans_count = 0 THEN
                                v_pod_rtn_ind := 'A'; -- This will get updated later to 'S' when the RTN transaction is created
                            ELSE
                                v_pod_rtn_ind := NULL;
                            END IF;  -- v_stc_trans_count > 0

                        END IF;  -- v_pod_flag <> 'Y'

                        dbms_output.put_line('in pl_sts_pod_interface_in.load_return i_dci_rtn_exists is 0 before update returns');
                    --
                    -- Update before trying to insert since Pick ups (rec_type = 'P' and add_source = 'MFR') are inserted into returns
                    -- when SWMS receives the manifest.
                    -- If the customer is NOT on POD,then do not set the POD_RTN_IND,
                    -- else,if the POD_RTN_IND is an 'A',then it should stay as 'A'
                    -- else,check if the new returned_qty is different from the current returned_qty,change the  POD_RTN_IND to 'U'.
                    --



            -- take out 4/7/20    IF SQL%NOTFOUND THEN
                    -- The update failed,so the record does not already exist,therefore insert it.
                        BEGIN

                        -- Find the ermline id
                            IF
                                (
                                    sz_erm_line_id IS NULL
                                )
                            THEN
                                BEGIN
                                    SELECT
                                        nvl(
                                            MAX(erm_line_id),
                                            0
                                        ) + 1
                                    INTO
                                        i_erm_line_id
                                    FROM
                                        returns
                                    WHERE
                                        manifest_no = to_number(sz_manifest_no);

                                END;
                            ELSE
                                i_erm_line_id := to_number(sz_erm_line_id);
                            END IF; -- ( sz_erm_line_id IS NULL

                    --  raise_application_error( -20000,'sz_returned_split_cd = >' || sz_returned_split_cd || '<' );
                                -- Added for CRQ34059 to insert RTN for same prod_id with different reason codes
                /* take out 4/7/20 reinstate on 4/17/20 because if already send to sus and from route close it
                     still got the same rj as stop close we don't want send it again */

                       /* 5/15/20 don't think this works for all cw are 0 or the same
                            SELECT
                                COUNT(*)
                            INTO
                                l_ret_count
                            FROM
                                returns
                            WHERE
                                    manifest_no = sz_manifest_no
                                AND
                                    route_no = sz_route_no
                                AND
                                    stop_no = n_stop_no
                                AND
                                    prod_id = sz_prod_id
                                AND
                                    returned_qty = sz_returned_qty
                                AND
                                    obligation_no = sz_delivery_doc_num
                               and  catchweight =    sz_catchweight
                                AND
                                    return_reason_cd = sz_return_reason_cd;

                            */

                            l_ret_count := 0;  -- 5/16/20
							l_dci_create_rtn :=0; --3/15/21

                            -- 5/22/20 add new way to get l_ret_count


                      select
                       nvl(sum(rb.returned_qty), 0) RQ, nvl(sum(rb.catchweight),0) CWW
                      into rb_rq, rb_cw
                      from returns_barcode rb
                      where rb.manifest_no = sz_manifest_no
                         and rb.route_no = sz_route_no
                         and rb.stop_no =  n_stop_no -- 2/22/21 replace sz_stop_no  with n_stop_no -- 12/7/20 replace n_stop_no with sz_stop_no
                         and rb.prod_id = sz_prod_id
                      -- 2/19/21 take out
                         and rb.return_reason_cd = sz_return_reason_cd
                      --   and rb.returned_qty = sz_returned_qty
                         and rb.obligation_no = sz_delivery_doc_num;

                        SELECT        -- 5/15/20  this is the new to handle cw , chk if returns already has the record we are processing now
                                COUNT(r.barcode_ref_no)
                        INTO
                                l_ret_count
                        FROM
                                returns r,
                                returns_barcode rb
                        WHERE
                                    r.manifest_no = sz_manifest_no
                                and r.manifest_no = rb.manifest_no
                                AND r.route_no = sz_route_no
                                and r.route_no = rb.route_no
                                AND r.stop_no = n_stop_no
                                and r.stop_no = floor(rb.stop_no)   -- 12/7/20 replace rb.stop_no
                                AND r.prod_id = sz_prod_id
                                and r.prod_id = rb.prod_id
                                AND r.returned_qty = sz_returned_qty
                                and r.returned_qty = rb_rq  -- rb.returned_qty take out 5/19/20
                                AND r.obligation_no = sz_delivery_doc_num
                                and r.obligation_no = rb.obligation_no
                               --12/9/20 keit said don't check cw and  r.catchweight =    sz_catchweight
                               --12/9/20 take out and  r.catchweight =  rb_cw    --rb.catchweight -- take out 5/21
                                and r.returned_split_cd = sz_returned_split_cd  -- 12/9/20 kiet said check returned_split_cd
                           -- 2/19/21 take out
                                AND r.return_reason_cd = rb.return_reason_cd;

                        -- and rb.catchweight = sz_catchweight

                            dbms_output.put_line('in pl_sts_pod_interface_in.load_return l_ret_count= ' || TO_CHAR(l_ret_count) );

                        /* 3/15/21 replace by next line
                        pl_log.ins_msg(
                            'INFO',
                            'LOAD_RETURN',
                            'in p_sts_import in load_return l_ret_count= '||l_ret_count||' manif= '||sz_manifest_no||' route= '||sz_route_no
                            ||' stop_no = '|| n_stop_no||' barcode_ref_no= '||sz_barcode_refno||
                                ' sz_catchweight= '||sz_catchweight||
                                ' return_reason_cd= '|| sz_return_reason_cd|| ' prod_id = '||sz_prod_id,
                                 -- take out 5/19 || ' barcode= '||sz_barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );
                        */

                        -- 3/15/21
                        pl_log.ins_msg(
                            'INFO',
                            'LOAD_RETURN',
                            'in p_sts_import in load_return l_ret_count= '||l_ret_count||' v_opco_pod_flag='||v_opco_pod_flag||
                            ' v_pod_flag='||v_pod_flag||' before checking if any returns created by DCI screen l_dci_create_rtn='||l_dci_create_rtn||
                            ' manif= '||sz_manifest_no||' route= '||sz_route_no
                            ||' stop_no = '|| n_stop_no||' barcode_ref_no= '||sz_barcode_refno||
                                ' sz_catchweight= '||sz_catchweight||
                                ' return_reason_cd= '|| sz_return_reason_cd|| ' prod_id = '||sz_prod_id,
                                 -- take out 5/19 || ' barcode= '||sz_barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );


                        -- if item has not been inserted by SWMS process and is non pod customer check if DCI manually created return
                        if ( l_ret_count = 0 ) then
                            --( l_ret_count = 0 and v_opco_pod_flag != 'Y' and v_pod_flag != 'Y') then



							select count(*)
							into l_dci_create_rtn
							from returns r
                            where r.manifest_no = sz_manifest_no
							and r.route_no = sz_route_no
							and r.stop_no = n_stop_no
							and r.prod_id = sz_prod_id
							-- 5/6/21 and (r.returned_qty = sz_returned_qty and sz_shipped_qty >=r.returned_qty)		--3/24/21 change > to >=
							and r.obligation_no = sz_delivery_doc_num
                            --take out on 4/22/21 and r.return_reason_cd = sz_return_reason_cd
                            and r.status = 'PUT';


                        pl_log.ins_msg(
                            'INFO',
                            'LOAD_RETURN',
                            'in p_sts_import in load_return if l_ret_count = 0 and get l_dci_create_rtn= '||l_dci_create_rtn||' manif= '||
                            sz_manifest_no||' route= '||sz_route_no
                            ||' stop_no = '|| n_stop_no||' barcode_ref_no= '||sz_barcode_refno||
                                ' sz_catchweight= '||sz_catchweight||
                                ' return_reason_cd= '|| sz_return_reason_cd|| ' prod_id = '||sz_prod_id,
                                 -- take out 5/19 || ' barcode= '||sz_barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );


                        end if;

                        if  ( l_ret_count = 0  and l_dci_create_rtn=0)
                               --3/15/21 replace by above ( l_ret_count = 0 )
                            THEN


                        pl_log.ins_msg(
                            'INFO',
                            'LOAD_RETURN',
                            'in p_sts_import in load_return in if l_ret_count=0 and l_dci_create_rtn = 0 before insert into returns table '||' manif= '||sz_manifest_no||' route= '||sz_route_no
                            ||' stop_no = '|| n_stop_no||' barcode_ref_no= '||sz_barcode_refno||
                             ' sz_catchweight= '||sz_catchweight||
                                ' return_reason_cd= '|| sz_return_reason_cd|| ' prod_id = '||sz_prod_id,
                                  -- ||' barcode= '||sz_barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                                dbms_output.put_line('in pl_sts_pod_interface_in.load_return before insert into returns ');
                                INSERT INTO returns (
                                    manifest_no,
                                    route_no,
                                    stop_no,
                                    rec_type,
                                    obligation_no,
                                    prod_id,
                                    cust_pref_vendor,
                                    return_reason_cd,
                                    returned_qty,
                                    returned_split_cd,
                                    catchweight,
                                    disposition,
                                    returned_prod_id,
                                    erm_line_id,
                                    shipped_qty,
                                    shipped_split_cd,
                                    cust_id,
                                    temperature,
                                    add_source,
                                    pod_rtn_ind,
                                    rtn_sent_ind,
                                    org_rtn_reason_cd,
                                    org_rtn_qty,
                                    org_catchweight,
                                    barcode_ref_no,
                                    status
                                )
                                            --STOP_CORRECTION)
                                 VALUES (
                                    to_number(sz_manifest_no),
                                    sz_route_no,
                                    n_stop_no,
                                    DECODE(
                                        sz_return_reason_cd,
                                        'T30',
                                        'O',
                                        'W45',
                                        'O',
                                        sz_rec_type
                                    ),
                                    sz_delivery_doc_num,
                                    sz_prod_id,
                                    sz_cust_pref_vendor,
                                    sz_return_reason_cd,
                                    to_number(sz_returned_qty),
                                    sz_returned_split_cd,
                                    to_number(sz_catchweight),
                                    sz_disposition,
                                    sz_returned_prod_id,
                                    i_erm_line_id,
                                    to_number(sz_shipped_qty),
                                    sz_shipped_split_cd,
                                    nvl(sz_cust_id, v_cust_id), --sz_cust_id,
                                    to_number(sz_temperature),
                                    'STS',
                                    DECODE(
                                        v_pod_flag,
                                        'Y',
                                        'A',
                                        NULL
                                    ),  -- pod_rtn_ind
                                    'N',  --rtn_sent_ind
                                    v_org_rsn_cd,
                                    v_org_qty,
                                    v_org_catchweight,
                                    sz_barcode_refno,
                                    sz_status
                                );



                                -- 12/9/20 take it out COMMIT;


                        pl_log.ins_msg(
                            'INFO',
                            'LOAD_RETURN',
                            'in p_sts_import in load_return in if l_ret_count= 0 after insert into returns table and commit '||' manif= '||sz_manifest_no||' route= '||sz_route_no
                            ||' stop_no = '|| n_stop_no||' barcode_ref_no= '||sz_barcode_refno||
                             ' sz_catchweight= '||sz_catchweight||
                                ' return_reason_cd= '|| sz_return_reason_cd|| ' prod_id = '||sz_prod_id,
                                 -- take out 5/19 || ' barcode= '||sz_barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                        /* 4/7/20 take out 4/20 reinstate */
                            ELSE
                                NULL;
                            END IF;  -- (l_ret_count=0)

                        -- 4/20 reinstate*/

                        END;
                         -- 4/7/20  END IF;

                    ELSE --( i_dci_rtn_exists = 0 )
                        pl_log.ins_msg(
                            'I',
                            'LOAD_RETURN',
                            'Returns for Manifest# '
                             || sz_manifest_no
                             || ' Obligation#'
                             || sz_delivery_doc_num
                             || ' Stop# '
                             || n_stop_no
                             || ' Prod_id# '
                             || sz_prod_id
                             || ' has been processed already.',
                            NULL,
                            NULL,
                            'O',
                            'pl_sts_pod_interface_in'
                        );
                    END IF; --( i_dci_rtn_exists = 0 )

                ELSE
                    NULL;
                END IF;  --( ( sz_sts_rec_type = 'ST' and v_pod_flag = 'Y') or ( sz_sts_rec_type = 'RT') )
            ELSE  --IF status='OPN' AND v_cmp_count = 0
                IF
                    v_cmp_count > 0
                THEN
                    pl_log.ins_msg(
                        'I',
                        'LOAD_RETURN',
                        'Manifest_Dtls.Manifest_del_status is RTN',
                        --'Tripmaster has been done for this manifest. Not updating/inserting returns',
                        NULL,
                        NULL,
                        'O',
                        'pl_sts_pod_interface_in'
                    );

                ELSE  --v_cmp_count > 0
                    pl_log.ins_msg(
                        'I',
                        'LOAD_RETURN',
                        'Returns for Manifest# '
                         || sz_manifest_no
                         || ' Obligation#'
                         || sz_delivery_doc_num
                         || ' Stop# '
                         || n_stop_no
                         || ' Prod_id# '
                         || sz_prod_id
                         || 'Cannot be processed.Manifest is already Closed',
                        NULL,
                        NULL,
                        'O',
                        'pl_sts_pod_interface_in'
                    );
                END IF; -- v_cmp_count > 0
            END IF; -- END IF status='OPN' AND v_cmp_count = 0 THEN

        EXCEPTION -- got error
            WHEN no_data_found THEN
                pl_log.ins_msg(
                    'FATAL',
                    'LOAD_RETURN',
                    'Error in LOAD_RETURN first when no_data_found',
                    sqlcode,
                    sqlerrm,
                    'O',
                    'pl_sts_pod_interface_in'
                );

                dbms_output.put_line('error' || sqlcode || sqlerrm);
    --ROLLBACK;
           /* Updating the messgae_id as failed */
        --    UPDATE sts_route_in SET record_status = 'F'
          --                  WHERE msg_id=v_msg_id;
     --COMMIT;
            WHEN OTHERS THEN
                dbms_output.put_line('error' || sqlcode || sqlerrm);
                pl_log.ins_msg(
                    'FATAL',
                    'LOAD_RETURN',
                    'Error in LOAD_RETURN first when others then ',
                    sqlcode,
                    sqlerrm,
                    'O',
                    'pl_sts_pod_interface_in'
                );
                raise;  --3/5/21
        --ROLLBACK;
            /* Updating the messgae_id as failed */
         --   UPDATE sts_route_in SET record_status = 'F'
           --                 WHERE msg_id=v_msg_id;
         --COMMIT;

        END;  -- inner begin

    EXCEPTION
        WHEN no_data_found THEN
            pl_log.ins_msg(
                'FATAL',
                'LOAD_RETURN',
                'Error in LOAD_RETURN when no_data_found',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in'
            );

            dbms_output.put_line('error' || sqlcode || sqlerrm);
    --ROLLBACK;
           /* Updating the messgae_id as failed */
        --    UPDATE sts_route_in SET record_status = 'F'
          --                  WHERE msg_id=v_msg_id;
     --COMMIT;
            raise;  --3/5/21
        WHEN OTHERS THEN
            dbms_output.put_line('error' || sqlcode || sqlerrm);
            pl_log.ins_msg(
                'FATAL',
                'LOAD_RETURN',
                'Error in LOAD_RETURN when others then ',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in'
            );
            raise;  --3/5/21
        --ROLLBACK;
            /* Updating the messgae_id as failed */
         --   UPDATE sts_route_in SET record_status = 'F'
           --                 WHERE msg_id=v_msg_id;
         --COMMIT;

    END load_return;



    PROCEDURE load_returns_barcode (
        sz_manifest_no        IN VARCHAR,
        sz_sts_rec_type       IN VARCHAR,
        sz_route_no           IN VARCHAR,
        sz_invoice_num        IN VARCHAR,
        sz_stop_no            IN VARCHAR,
        sz_prod_id            IN VARCHAR,
        sz_shipped_qty        IN VARCHAR,
        sz_returned_qty       IN VARCHAR,
        sz_barcode            IN VARCHAR,
        sz_return_reason_cd   IN VARCHAR,
        sz_weight             IN VARCHAR,
        sz_barcode_refno      IN NUMBER,
        sz_rb_status          IN VARCHAR,
        sz_msg_text           IN VARCHAR
    )
        IS
    BEGIN
        dbms_output.put_line('in pl_sts_pod_interface_in.load_returns_barcode before insert into returns_barcode for route '
         || sz_route_no
         || ' stop '
         || sz_stop_no
         || ' barcode '
         || sz_barcode
         || ' sz_barcode_refno '
         || sz_barcode_refno);

        INSERT INTO returns_barcode (
            manifest_no,
            sts_rec_type,
            route_no,
            obligation_no,
            stop_no,
            prod_id,
            shipped_qty,
            returned_qty,--refusal_reason_cd,
            barcode,
            return_reason_cd,
            catchweight,
            barcode_ref_no,
            add_date,
            add_user,
            add_source,
            status,
            msg_text
        ) VALUES (
            sz_manifest_no,
            sz_sts_rec_type,
            sz_route_no,
            sz_invoice_num,
            sz_stop_no,
            sz_prod_id,
            sz_shipped_qty,
            sz_returned_qty --,r_rj.refusal_reason_cd
            ,
            sz_barcode,
            sz_return_reason_cd,
            sz_weight,
            sz_barcode_refno,
            SYSDATE,
            'SWMS',
            'STS',
            sz_rb_status,
            sz_msg_text
        );

        dbms_output.put_line('in pl_sts_pod_interface_in.load_returns_barcode after insert into returns_barcode for route '
         || sz_route_no
         || ' stop '
         || sz_stop_no
         || ' barcode '
         || sz_barcode
         || ' sz_barcode_refno '
         || sz_barcode_refno);

    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('pl_sts_pod_interface_in.load_returns_barcode wot error' || sqlcode || sqlerrm);
            pl_log.ins_msg(
                'FATAL',
                'PL_STS_POD_INTERFACE_IN',
                'Error in load_returns_barcode when others then ',
                sqlcode,
                sqlerrm,
                'O',
                'STS_RETURN'
            );
            raise;  --3/5/21
        --ROLLBACK;
            /* Updating the messgae_id as failed */
         --   UPDATE sts_route_in SET record_status = 'F'
           --                 WHERE msg_id=v_msg_id;
         --COMMIT;

    END load_returns_barcode;

    PROCEDURE p_sts_import_asset (
        i_route_no     sts_route_in.route_no%TYPE,
        i_cust_id      sts_route_in.cust_id%TYPE,
        i_barcode      sts_route_in.barcode%TYPE,
        i_qty          sts_route_in.quantity%TYPE,
        i_route_date   sts_route_in.route_date%TYPE,
        i_time_stamp   sts_route_in.time_stamp%TYPE,
        i_event_type   sts_route_in.event_type%TYPE,
        o_status       OUT NUMBER
    ) IS

/******************************************************************************
   NAME:       P_STS_IMPORT_ASSET
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/18/2015   mdev3739       1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     P_STS_IMPORT_ASSET
      Sysdate:         2/18/2015
      Date and Time:   2/18/2015,7:36:12 PM,and 2/18/2015 7:36:12 PM
      Username:        mdev3739 (set in TOAD Options,Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/

        v_qty            sts_equipment.qty%TYPE;
        v_qty_returned   sts_equipment.qty_returned%TYPE;
        v_date           sts_equipment.add_date%TYPE;
        v_remain_qty     sts_equipment.qty%TYPE;
        v_orig_qty       sts_route_in.quantity%TYPE;
        v_truck_no       sts_equipment.truck_no%TYPE;
        CURSOR c_sts_import_asset IS
            SELECT
                qty,
                qty_returned,
                TO_CHAR(
                    add_date,
                    'YYYYMMDDHH24MISS'
                )
            FROM
                sts_equipment
            WHERE
                    route_no = i_route_no
                AND
                    cust_id = i_cust_id
                AND
                    barcode = i_barcode
                AND
                    status = 'D'
                AND (
                    qty - qty_returned > 0
                );

    BEGIN

/* Previous equipment Update */
        IF
            i_event_type = 'P'
        THEN
            OPEN c_sts_import_asset;
            LOOP
                FETCH c_sts_import_asset INTO v_qty,v_qty_returned,v_date;
                EXIT WHEN c_sts_import_asset%notfound;
                IF
                    v_orig_qty > 0
                THEN
                    v_remain_qty := v_qty - v_qty_returned;
                    IF
                        ( v_remain_qty <= v_orig_qty )
                    THEN
                        v_orig_qty := v_orig_qty - v_remain_qty;
                        v_qty_returned := v_qty_returned + v_remain_qty;
                    ELSE
                        v_qty_returned := v_qty_returned + v_orig_qty;
                        v_orig_qty := 0;
                    END IF;

                END IF;

                UPDATE sts_equipment
                    SET
                        qty_returned = v_qty_returned
                WHERE
                        route_no = i_route_no
                    AND
                        cust_id = i_cust_id
                    AND
                        barcode = i_barcode
                    AND
                        add_date = v_date;

            END LOOP;

        END IF;

        SELECT DISTINCT
            truck_no
        INTO
            v_truck_no
        FROM
            sts_items
        WHERE
                route_no = i_route_no
            AND
                route_date = i_route_date
            AND
                ROWNUM = 1;

        INSERT INTO sts_equipment (
            route_no,
            truck_no,
            cust_id,
            barcode,
            status,
            qty,
            qty_returned,
            add_date
        ) VALUES (
            i_route_no,
            v_truck_no,
            i_cust_id,
            i_barcode,
            i_event_type,
            v_orig_qty,
            0,
            i_time_stamp
        );

        o_status := 0; -- Success
    EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('subprogram' || sqlcode || sqlerrm);
            pl_log.ins_msg(
                'FATAL',
                'P_STS_IMPORT_ASSET',
                'Error in processing the sts_route_in records',
                sqlcode,
                sqlerrm,
                'O',
                'STS_RETURN'
            );

            o_status := 1;  -- Failiure
        WHEN OTHERS THEN
            dbms_output.put_line('subprogram' || sqlcode || sqlerrm);
       -- Consider logging the error and then re-raise
            pl_log.ins_msg(
                'FATAL',
                'P_STS_IMPORT_ASSET',
                'Error in processing the sts_route_in records',
                sqlcode,
                sqlerrm,
                'O',
                'STS_RETURN'
            );

            o_status := 1;  -- Failiure
    END p_sts_import_asset;

    PROCEDURE p_sts_import IS
/******************************************************************************
   NAME:       P_STS_IMPORT
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/17/2015   mdev3739       1. Created this procedure.

   NOTES:

   This procedure is common for return,cash/check,assets. We are processing the
   each message_id and inserting into

   Automatically available Auto Replace Keywords:
      Object Name:     P_STS_IMPORT
      Sysdate:         2/17/2015
      Date and Time:   2/17/2015,2:27:42 PM,and 2/17/2015 2:27:42 PM
      Username:        mdev3739 (set in TOAD Options,Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/

        message                   VARCHAR2(2000);
        v_msg_id                  sts_route_in.msg_id%TYPE;
        v_route_sts               sts_route_in.route_no%TYPE;
        v_sts_route               sts_route_in%rowtype;
--v_add_date          sts_route_in.add_date%TYPE;
        v_qty                     sts_route_in.qty_split%TYPE;
        v_check_batch_no          sts_cash_batch.batch_no%TYPE;
        v_route_date              sts_cash_batch.route_date%TYPE;
        v_count_cash              sts_route_in.credit_amt%TYPE;
        v_alt_stop_sts            sts_route_in.alt_stop_no%TYPE;
        v_manifest_no             sts_route_in.manifest_no%TYPE;
        v_up_dt                   sts_route_in.upd_date%TYPE;
        rtn_process_flag          BOOLEAN;
        v_pod_flag                manifest_stops.pod_flag%TYPE;
        v_opco_pod_flag           sys_config.config_flag_val%TYPE;
        v_invoice                 manifest_stops.obligation_no%TYPE;
        status                    VARCHAR2(3);
        v_count_stc               NUMBER;
        v_count                   NUMBER;
        v_count_cmp_rtn           NUMBER;
        v_status                  NUMBER := 0;
        e_failed EXCEPTION;
        v_split_cd                sts_route_in.wms_item_type%TYPE;
        v_orig_split_cd           sts_route_in.orig_wms_item_type%TYPE;
        l_curr_cust_id            sts_route_in.cust_id%TYPE;
        l_prev_cust_id            sts_route_in.cust_id%TYPE;
        l_cash_inc                NUMBER;
        l_check_inc               NUMBER;
        v_count_check             NUMBER;
        l_check_no                VARCHAR2(5);
        l_curr_type               VARCHAR2(15);
        l_prev_type               VARCHAR2(15);
        l_item_seq                NUMBER;
        l_cash_item_seq           NUMBER;
        l_chk_item_seq            NUMBER;
        v_cash_batch_no           sts_cash_batch.batch_no%TYPE;
        l_whole_pallet_reject     VARCHAR2(2);
        l_count                   NUMBER;
        l_rt_count                NUMBER;

        l_manifest_no             sts_route_in.manifest_no%TYPE;

--i                   integer :=0;
        l_whole_pallet_reject_1   VARCHAR2(2);
        v_split_cd_1              sts_route_in.wms_item_type%TYPE;
        v_split_cd_2              sts_route_in.wms_item_type%TYPE;
        i_cnt                     NUMBER; --10/13/19
        i_td_cnt_1                NUMBER; --10/27/19
        i_rn_cnt_1                NUMBER; --10/27/19
        v_return_reason_cd        sts_route_in.return_reason_cd%TYPE;
        v_rec_type                returns_barcode.sts_rec_type%TYPE;
        v_barcode_refno           returns_barcode.barcode_ref_no%TYPE;
--v_stop_correction     returns_barcode.stop_correction_ind%type;
        v_stop_correction         sts_route_in.stop_correction%TYPE;
        v_prod_id                 sts_route_in.prod_id%TYPE;
        v_rtntab_status           returns.status%TYPE;
        v_rb_status               returns_barcode.status%TYPE;
        v_msg_text                returns_barcode.msg_text%TYPE;

        v_count_stc_for_sr_d      number;

        v_barcode                 sts_route_in.barcode%TYPE;
        v_rt_manifest_no          sts_route_in.manifest_no%TYPE;

        v_count_tran              number; -- add 6/30/20
        t_brn                     returns.barcode_ref_no%TYPE; -- 3/8/21

        l_xdock_rtn_cnt           number;
        --vrj_barcode                 sts_route_in.barcode%TYPE;

        l_xdock_ind_s_cnt         number; -- 9/21/2021 : Determine Xdock manifest in Fullfillment Site

    /* Cursor for taking all message id*/
        CURSOR c_sts_route IS
            SELECT DISTINCT
                msg_id
            FROM
                sts_route_in
            WHERE
                record_status = 'N' --5/15/20 test use 'M' to stop processing
            ORDER BY msg_id;

    /* Cursor for processing the message id one by one*/

     --
       CURSOR c_rj ( per_message_id   VARCHAR2 ) IS
                   SELECT
                manifest_no,
                route_no,
                msg_id,
                floor(alt_stop_no) alt_stop_no, -- 2/22/21
                invoice_num,
                record_type,
                return_reason_cd,
                wms_item_type,
                multi_pick_ind,
                prod_id,
                return_prod_id,
                --item_id,
                quantity,
                sum(weight) weight,
                --,sum(quantity) quantity,
                SUM(return_qty) return_qty
            FROM
                sts_route_in
            WHERE
                    msg_id = per_message_id
                AND
                    record_status = 'N'
                AND
                    record_type = 'RJ'
            GROUP BY
                manifest_no,
                route_no,
                msg_id,
                floor(alt_stop_no),
                invoice_num,
                record_type,
                return_reason_cd,
                wms_item_type,
                multi_pick_ind,
                prod_id,
                return_prod_id,
                --item_id,
                quantity;

	-- for Jira #OPCOF-2478
       /* 5/19/20 user said we can sum up diffrent cw
        CURSOR c_rj ( per_message_id   VARCHAR2 ) IS
            SELECT
                manifest_no,
                route_no,
                msg_id,
                alt_stop_no,
                invoice_num,
                record_type,
                return_reason_cd,
                barcode,
                weight,
                wms_item_type,
                multi_pick_ind,
                prod_id,
                return_prod_id,
                item_id,
                quantity,
     -- ,quantity,,return_prod_id,item_id,barcode,stop_correction
    --,sum(quantity) quantity,
                SUM(return_qty) return_qty
            FROM
                sts_route_in
            WHERE
                    msg_id = per_message_id
                AND
                    record_status = 'N'
                AND
                    record_type = 'RJ'
            GROUP BY
                manifest_no,
                route_no,
                msg_id,
                alt_stop_no,
                invoice_num,
                record_type,
                return_reason_cd,
                barcode,
                weight,
                wms_item_type,
                multi_pick_ind,
                prod_id,
                return_prod_id,
                item_id,
                quantity;

          */

    /*
	select manifest_no,route_no, msg_id,alt_stop_no,prod_id,invoice_num,record_type,return_reason_cd, quantity,
    weight,return_prod_id,item_id,wms_item_type,multi_pick_ind,
    --,barcode,stop_correction
	sum(return_qty) return_qty
    from sts_route_in
	WHERE msg_id=per_message_id
    AND record_status = 'N'
    and record_type = 'RJ'
    group by manifest_no,route_no, msg_id,alt_stop_no,prod_id,invoice_num,record_type,return_reason_cd,quantity,
    weight,return_prod_id,item_id,wms_item_type,multi_pick_ind;   --,barcode,stop_correction
    */
	--group by manifest_no,route_no, msg_id,alt_stop_no,prod_id,invoice_num,record_type,return_reason_cd,quantity,
    --weight,return_prod_id,item_id,wms_item_type;

        CURSOR c_rj_dtl (
            per_message_id    VARCHAR2,
            v_barcod_ref_no   VARCHAR2 --,
            --take out 5/19 vrj_barcode      varchar2  -- 5/16/20 add

        ) IS
            SELECT
                sri.manifest_no,
                sri.record_type,
                sri.route_no,
                sri.invoice_num,
                floor(sri.alt_stop_no) alt_stop_no,
                sri.prod_id,
                sri.quantity,
                sri.return_qty,
                sri.refusal_reason_cd,
                sri.barcode,
                sri.return_reason_cd,
                sri.weight,
                r.barcode_ref_no
            FROM
                sts_route_in sri,
                returns r
            WHERE
                    r.route_no = sri.route_no
                AND
                    r.manifest_no = sri.manifest_no
                AND
                    r.stop_no = floor(sri.alt_stop_no)  -- replace 12/7/20
                AND
                    r.prod_id = sri.prod_id  -- add 3/31/20
                AND
                    r.return_reason_cd = sri.return_reason_cd
                AND
                    r.obligation_no = sri.invoice_num
                -- 5/19/20 take out because we roll up cw and r.catchweight = sri.weight -- 5/15/20
                AND
                    sri.record_type = 'RJ'
                AND
                    r.barcode_ref_no = v_barcod_ref_no
                -- take oout 5/19 and sri.barcode = vrj_barcode   -- 5/16/20 add
                AND
                    sri.msg_id = per_message_id;

                --and rownum =1;  -- 5/15/20 add , not wokring

        CURSOR c_sr_dtl (
            per_message_id    VARCHAR2,
            v_barcod_ref_no   VARCHAR2
        ) IS
            SELECT
                sri.manifest_no,
                sri.record_type,
                sri.route_no,
                sri.invoice_num,
                --2/22/21 sri.alt_stop_no,
                floor(sri.alt_stop_no) alt_stop_no,
                sri.prod_id,
                sri.quantity,
                sri.return_qty,
                sri.refusal_reason_cd,
                sri.barcode,
                sri.return_reason_cd,
                sri.weight,
                r.barcode_ref_no
            FROM
                sts_route_in sri,
                returns r
            WHERE
                    r.route_no = sri.route_no
                AND
                    r.manifest_no = sri.manifest_no
                AND
                    r.stop_no = floor(sri.alt_stop_no) -- 2/22/21 add floor
                AND
                    r.prod_id = sri.prod_id  -- add 3/31/20
                AND
                    r.return_reason_cd = sri.return_reason_cd
                AND
                    r.obligation_no = sri.invoice_num
                AND
                    sri.record_type = 'SR'
                AND
                    r.barcode_ref_no = v_barcod_ref_no
                AND
                    sri.msg_id = per_message_id;

        CURSOR c_sts_route_message_id ( per_message_id   VARCHAR2 ) IS
            SELECT
                *
            FROM
                sts_route_in
            WHERE
                    msg_id = per_message_id
                AND
                    record_status = 'N'
            ORDER BY sequence_no;


    /* Cursor to fetch Cash invoice per message id */
    /* Need to process Money Order as Cash record */

        CURSOR c_cash_invoice (
            i_msg_id       sts_route_in.msg_id%TYPE,
            i_route_no     sts_route_in.route_no%TYPE,
            i_route_date   sts_route_in.route_date%TYPE
        )
 --   i_add_date sts_route_in.add_date%TYPE)
         IS
            SELECT
                cust_id,
                credit_amt,
                invoice_num,
                check_no,
                manifest_no,
                event_type
            FROM
                sts_route_in
            WHERE
                    msg_id = i_msg_id
                AND
                    route_no = i_route_no
                AND
                    route_date = i_route_date
                AND
                    record_status = 'N'
                AND
                    record_type = 'IV'
                AND
                    event_type IN (
                        'Money Order','Cash'
                    )
                AND
                    credit_amt <> '0'
    --     and add_date = i_add_date
            ORDER BY cust_id;

        CURSOR c_check_invoice (
            i_msg_id       sts_route_in.msg_id%TYPE,
            i_route_no     sts_route_in.route_no%TYPE,
            i_route_date   sts_route_in.route_date%TYPE
        )
  --  i_add_date sts_route_in.add_date%TYPE)
         IS
            SELECT
                cust_id,
                credit_amt,
                manifest_no,
                invoice_num,
                check_no
            FROM
                sts_route_in
            WHERE
                    msg_id = i_msg_id
                AND
                    route_no = i_route_no
                AND
                    route_date = i_route_date
                AND
                    record_status = 'N'
                AND
                    record_type = 'IV'
                AND
                    event_type = 'Check'
                AND
                    credit_amt <> '0'
     --    and add_date = i_add_date
            ORDER BY cust_id;
 --Added for CRQ34059,cursor to fetch ST records per msg id

        CURSOR c_stop_records ( i_msg_id   sts_route_in.msg_id%TYPE ) IS
            SELECT
                manifest_no,
                cust_id,
                floor(alt_stop_no) alt_stop_no,  --2/21/21
                route_date,
                route_no
            FROM
                sts_route_in
            WHERE
                    msg_id = i_msg_id
                AND
                    record_type = 'ST'
            ORDER BY datetime;

        CURSOR c_return_records (
            i_msg_id    sts_route_in.msg_id%TYPE,
            i_stop_no   sts_route_in.alt_stop_no%TYPE
        ) IS
            SELECT
                invoice_num,
                manifest_no,
                floor(alt_stop_no) --2/22/21
            FROM
                sts_route_in
            WHERE
                    msg_id = i_msg_id
                AND
                    record_type IN (
                        'RJ','SR'
                    )
                AND
                    invoice_num IS NOT NULL
                AND
                    floor(alt_stop_no) = i_stop_no
            ORDER BY datetime;

        CURSOR c_stop_records_to_trans ( i_msg_id   sts_route_in.msg_id%TYPE ) IS
            SELECT
                sri.manifest_no,
                sri.cust_id,
                floor(sri.alt_stop_no) alt_stop_no, --2/22/21
                sri.route_date,
                route_no,
                barcode,  -- 5/16/20
                invoice_num    -- add 6/30/20
            FROM
                sts_route_in sri
            WHERE
                NOT
                    EXISTS (
                        SELECT
                            'x'
                        FROM
                            returns_barcode rb
                        WHERE
                                rb.manifest_no = sri.manifest_no
                            AND
                                floor(rb.stop_no) = floor(sri.alt_stop_no) --2/22/21
                            AND
                                rb.route_no = sri.route_no
                            AND
                                rb.barcode = sri.barcode  -- 5/16/20
                            AND
                                rb.status IS NOT NULL
                    )
                     --and rb.returned_qty > 1)
                AND
                    sri.msg_id = i_msg_id
        --and sri.msg_id = '9B9124DB8E0800AAE0530AF0241300AA' --stop1 close
                AND
                    sri.record_type = 'ST'
            ORDER BY datetime;


     ---xdock related logic  jira 3592
   CURSOR c_xdock_rtns (p_manifest_no VARCHAR2)
IS
  SELECT MANIFEST_NO,
    STOP_NO,
    REC_TYPE,
    OBLIGATION_NO,
    PROD_ID,
    CUST_PREF_VENDOR,
    SHIPPED_QTY,
    SHIPPED_SPLIT_CD,
    MANIFEST_DTL_STATUS,
    ORIG_INVOICE,
    INVOICE_NO,
    POD_FLAG,
    XDOCK_IND,
    SITE_FROM,
    SITE_TO,
    DELIVERY_DOCUMENT_ID,
    SITE_ID
  FROM MANIFEST_DTLS m
  WHERE MANIFEST_NO = p_manifest_no
  AND xdock_ind     = 'X'
  AND EXISTS
    (SELECT NULL
    FROM RETURNS r
    WHERE r.MANIFEST_NO      = m.MANIFEST_NO
    AND r.STOP_NO            = m.STOP_NO
    AND r.OBLIGATION_NO      = m.OBLIGATION_NO
    AND r.REC_TYPE           = m.REC_TYPE
    AND r.PROD_ID            = m.PROD_ID
    AND r.CUST_PREF_VENDOR   = m.CUST_PREF_VENDOR
    AND (r.SHIPPED_SPLIT_CD IS NULL
    OR r.SHIPPED_SPLIT_CD    = m.SHIPPED_SPLIT_CD)
    AND r.RETURNED_QTY      IS NOT NULL    ) ;


    /*
    cursor c_returns_barcode(i_manif_no sts_route_in.manifest_no%type)
    is
    select manifest_no,
    route_no,
    stop_no,
    rec_type,
    obligation_no,
    prod_id,
    cust_pref_vendor,
    return_reason_cd,
    returned_qty,
    returned_split_cd,
    catchweight,
    disposition,
    returned_prod_id,
    erm_line_id,
    shipped_qty,
    shipped_split_cd,
    cust_id,
    temperature,
    barcode_ref_no,
	stop_correction_ind,
	multi_pick_ind
    from returns_barcode
    where record_status = 'N'
    and manifest_no = i_manif_no
    order by barcode_ref_no;
    */

    BEGIN
        dbms_output.put_line('in pl_sts_pod_interface_in.p_sts_import ');

		/* take out on 6/25/20
        pl_log.ins_msg(
                    'INFO',
                    'pl_sts_pod_interface_in',
                    'in pl_sts_pod_interface_in.p_sts_import before open c_sts_route',
                    sqlcode,
                    sqlerrm,
                    'ORDER PROCESSING',
                    'pl_sts_pod_interface_in.p_sts_import',
                    'u'
                );
	    */

        OPEN c_sts_route; -- get all msg_id
        LOOP
            v_count_cash := 1;
            v_count_check := 1;
            v_count_cmp_rtn := 0;
            l_curr_cust_id := 0;
            l_prev_cust_id :=-1;
            l_cash_inc := 1;
            l_check_inc := 1;
            l_curr_type := 0;
            l_prev_type :=-1;
            l_count := 0;
            FETCH c_sts_route INTO v_msg_id;
   --,v_add_date;
            EXIT WHEN c_sts_route%notfound;

            /* 9/2/20 take out to fix issue with stop close can have event tag, replace by next line
            SELECT
                DECODE(
                    COUNT(*),
                    1,
                    'ST',
                    'RT'
                ) rec_type
            INTO
                v_rec_type  -- if is 1 it is stop close,> 1 it is route close
            FROM
                sts_route_in
            WHERE
                    msg_id = v_msg_id
                AND (
                        record_type = 'ST'
                    OR
                        record_type = 'ET'
                );

           */


            SELECT
                DECODE(
                    COUNT(*),
                    0,
                    'ST',
                    'RT'
                ) rec_type
            INTO
                v_rec_type  -- if is 0 it is stop close,  1 it is route close
            FROM
                sts_route_in
            WHERE
                    msg_id = v_msg_id
                AND record_type = 'RC';


            pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in c_sts_route loop msg_id= '|| v_msg_id ||' v_rec_type= '|| v_rec_type ||
                                 ' ST is stop close, RT is route close ',
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );




		/* for route close do the 'D' in returns table if necessary

            IF
                v_rec_type = 'RT'
            THEN
                dbms_output.put_line('in pl_sts_pod_interface_in.p_sts_import msg_id= ' || v_msg_id || ' and it is Route close msg id before update return pod_rtn_id to D for returns barcode_ref_no also in '
 || ' returns_barcode');

             -- 4/17/20 not correct it also put 'D' in a different barcdoe_ref_no
		     update returns r
             set r.pod_rtn_ind = 'D',
                 r.lock_chg = 'Y'
             where r.barcode_ref_no in ( select rb.barcode_ref_no
                                         from  returns_barcode rb
										 where not exists (select 'x'   -- 4/17/20 during t01 testing change this to not exists
										 from sts_route_in sri
										 WHERE msg_id= v_msg_id
										 and rb.sts_rec_type = sri.record_type
										and sri.record_type in ('RJ','SR')
										AND rb.barcode = sri.barcode) );


                /* 5/7/20 this is wrong put reverse creit in sts_route_message_id loop
                UPDATE returns r
                    SET
                        r.pod_rtn_ind = 'D',
                        r.lock_chg = 'Y'
                WHERE
                    r.returned_qty != (
                        SELECT
                            SUM(sri.return_qty)
                        FROM
                            sts_route_in sri
                        WHERE
                                sri.record_type IN (
                                    'RJ'
                                ) -- 4/28/20 take out ,'SR')
                                     --and r.manifest_no = sri.manifest_no
                            AND
                                r.route_no = sri.route_no
                            AND
                                r.prod_id = sri.prod_id
                            AND
                                sri.msg_id = v_msg_id
                    );

            END IF;

            */


    /* do this in c_rj loop
    if v_rec_type = 'ST' then

       select stop_correction
       into v_stop_correction
       from sts_route_in
       where msg_id = v_msg_id
       and record_type = 'ST';

    end if;
    */

            SELECT DISTINCT
                route_no,
                route_date
            INTO
                v_route_sts,v_route_date
            FROM
                sts_route_in
            WHERE
                    msg_id = v_msg_id
                AND
                    record_type = 'RT';

		/*Jira 399-added validations to handle return duplicates or not creating Returns in the STS process */

            SELECT
                config_flag_val
            INTO
                v_opco_pod_flag
            FROM
                sys_config
            WHERE
                config_flag_name = 'POD_ENABLE';

            IF
                v_opco_pod_flag = 'N'
            THEN
                SELECT
                    COUNT(*)
                INTO
                    l_rt_count
                FROM
                    sts_route_in
                WHERE
                        record_type = 'RT'
                    AND
                        record_status = 'S'
                    AND
                        msg_id = v_msg_id
                    AND
                        route_no = v_route_sts
                    AND
                        route_date = v_route_date;

                IF
                    ( l_rt_count > 0 )
                THEN
	-- Failing the batch as it was already processed to SWMS.
                    UPDATE sts_route_in
                        SET
                            record_status = 'F'
                    WHERE
                            msg_id = v_msg_id
                        AND
                            route_no = v_route_sts
                        AND
                            route_date = v_route_date;

                    COMMIT;
                    continue;
                END IF;

            END IF;
	-- Retrieving the count of ST records that was processed.
  -- Added for CRQ34059


            /* 6/2/20 take it out this is not needed, I will handle correct insert to returns in load_return

            FOR c_available IN c_stop_records(v_msg_id) -- get all ST for a msg_id

             LOOP
                SELECT
                    COUNT(*)
                INTO
                    l_count
                FROM
                    sts_route_in
                WHERE
                        record_type = 'ST'
                    AND
                        record_status = 'S'
                    AND
                        route_no = c_available.route_no
                    AND
                        route_date = c_available.route_date
                    AND
                        alt_stop_no = c_available.alt_stop_no;

                IF
                    ( l_count > 0 )
                THEN
        -- If there are any CMP status returns for the manifest,then tripmaster is complete.
                    SELECT
                        COUNT(*)
                    INTO
                        v_count_cmp_rtn
                    FROM
                        returns r
                    WHERE
                            r.manifest_no = c_available.manifest_no
                        AND
                            r.status = 'CMP';

                    SELECT
                        manifest_status
                    INTO
                        status
                    FROM
                        manifests
                    WHERE
                        manifest_no = c_available.manifest_no;

                    FOR c_avail IN c_return_records(
                        v_msg_id,
                        c_available.alt_stop_no
                    ) -- get all RJ,SR for msg_id,alt_stop_no
                     LOOP
                        SELECT DISTINCT
                            nvl(
                                pod_flag,
                                'N'
                            )
                        INTO
                            v_pod_flag
                        FROM
                            manifest_stops
                        WHERE
                                manifest_no = c_avail.manifest_no
                            AND
                                stop_no = floor(to_number(c_avail.alt_stop_no) )
                            AND
                                obligation_no = c_avail.invoice_num;

            -- Added v_count_cmp_rtn to check if Tripmaster is done. If tripmaster is done,then don't delete anything

                        IF
                            v_pod_flag = 'N' AND status = 'OPN' AND v_count_cmp_rtn = 0
                        THEN
                            DELETE FROM returns WHERE
                                    manifest_no = c_avail.manifest_no
                                AND
                                    stop_no = floor(to_number(c_avail.alt_stop_no) )
                                AND
                                    obligation_no = c_avail.invoice_num;

                            COMMIT;
                        END IF;

                    END LOOP c_return_records;

                END IF;

            END LOOP c_stop_records; --c_available IN c_stop_records(v_msg_id)

            */

            v_return_reason_cd := 'TTT';
            v_prod_id := 'TTT';

            v_barcode := 'TTT'; -- 5/13/20 add

    /* 4/21/20
    select barcode_refno_seq.nextval
    into v_barcode_refno
    from dual;
    */

                   pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in p_sts_import before c_rj loop v_return_reason_cd = '|| v_return_reason_cd||
                                 ' v_prod_id = '||v_prod_id,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

            FOR r_rj IN c_rj(v_msg_id) LOOP

                dbms_output.put_line('in pl_sts_pod_interface_in.p_sts_import c_rj loop ');


                pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in p_sts_import in c_rj loop manif= '||r_rj.manifest_no||' route= '||r_rj.route_no
                            ||' stop_no= '||r_rj.alt_stop_no||
                            ' v_return_reason_cd = '|| v_return_reason_cd||
                                ' r_rj.return_reason_cd= '|| r_rj.return_reason_cd|| ' v_prod_id = '||v_prod_id||' r_rj.prod_id= '||
                                   r_rj.prod_id,  --||' barcode= '||r_rj.barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                v_rtntab_status := 'VAL';

          --if v_rec_type = 'ST' then
                SELECT
                    stop_correction
                INTO
                    v_stop_correction
                FROM
                    sts_route_in
                WHERE
                        msg_id = v_msg_id
                    AND
                    floor(alt_stop_no) = floor(r_rj.alt_stop_no) --2/22/21
                      --  floor(alt_stop_no) = r_rj.alt_stop_no --2/22/21
                    AND
                        record_type = 'ST'
                    and rownum <2;  -- this eliminate fetch more than 1, v_stop_correction is not use anymore

           --end if;

                  dbms_output.put_line('in pl_sts_pod_interface_in.p_sts_import in c_rj loop v_return_reason_cd = '|| v_return_reason_cd||
                    ' r_rj.return_reason_cd= '|| r_rj.return_reason_cd|| ' v_prod_id = '||v_prod_id||' r_rj.prod_id= '||
                    r_rj.prod_id );

                    -- 5/19/20 added
                    SELECT
                        barcode_refno_seq.NEXTVAL
                    INTO
                        v_barcode_refno
                    FROM
                        dual;


               /* take out on 5/19 replace by aboe because each rec from c_rj should have a new barcode_ref_no
                IF
                    ( ( v_return_reason_cd != r_rj.return_reason_cd ) OR ( v_prod_id != r_rj.prod_id ) )
                       -- take out on 5/19 because we sum up cw or ( v_barcode != r_rj.barcode )  )  -- 5/14/20 add v_barcode
                THEN -- add 3/31/20
                    SELECT
                        barcode_refno_seq.NEXTVAL
                    INTO
                        v_barcode_refno
                    FROM
                        dual;


                  dbms_output.put_line('v_barcode_refno = '||to_char(v_barcode_refno));


                    v_return_reason_cd := r_rj.return_reason_cd;
                    v_prod_id := r_rj.prod_id;
                    -- take out on 5/19 v_barcode := r_rj.barcode; -- 5/14/20

                END IF;
               */

	      --i := i+1;

               /* 6/1/20 take out
                SELECT
                    substr(
                        r_rj.item_id,
                        1,
                        1
                    )
                INTO
                    l_whole_pallet_reject_1
                FROM
                    dual;

                dbms_output.put_line('loop in c_rj r_rj.item_id= ' || r_rj.item_id);

                */


                SELECT
                DECODE(r_rj.wms_item_type,'S',1,0)
                INTO
                    v_split_cd_1 -- this is returned_split_cd
                FROM
                    dual;

                   pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in p_sts_import in c_rj loop before call load_return after get v_split_cd_1 manif= '||r_rj.manifest_no||' route= '||r_rj.route_no
                            ||' stop_no= '||r_rj.alt_stop_no||' weight= '||to_char(r_rj.weight)
                            ||' v_return_reason_cd = '|| v_return_reason_cd||
                                ' r_rj.return_reason_cd= '|| r_rj.return_reason_cd|| ' v_prod_id = '||v_prod_id||' r_rj.prod_id= '||
                                   r_rj.prod_id||' v_barcode_refno= '||v_barcode_refno, --||' barcode= '||r_rj.barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                -- 2/25/21 add

               Begin
                   select shipped_split_cd
                    into v_split_cd_2  -- this is shipped_split_cd
                    from manifest_dtls
                    where manifest_no = to_number(r_rj.manifest_no)
                    and stop_no= floor(r_rj.alt_stop_no) -- 2/22/21 add floor
                    and prod_id = r_rj.prod_id
                    and obligation_no = r_rj.invoice_num;
               --     and shipped_qty = r_rj.quantity;  -- 6/1/21 add this to avoid exact fetch error
               exception when others then -- added this exception to resolve Jira 3726
                       v_split_cd_2 :=  v_split_cd_1;

                      pl_log.ins_msg('INFO','p_sts_import','in exception deriving v_split_cd_2 manif= '||r_rj.manifest_no||' route= '||r_rj.route_no
                            ||' stop_no= '||r_rj.alt_stop_no||' weight= '||to_char(r_rj.weight)
                            ||' v_return_reason_cd = '|| v_return_reason_cd||' r_rj.return_reason_cd= '|| r_rj.return_reason_cd|| ' v_prod_id = '||v_prod_id
                            ||' r_rj.prod_id= '||r_rj.prod_id||' v_barcode_refno= '||v_barcode_refno, sqlcode, sqlerrm, 'ORDER PROCESSING','pl_sts_pod_interface_in','u' );
               End;

                    pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in p_sts_import in c_rj loop before call load_return after get v_split_cd_2 manif= '||r_rj.manifest_no||' route= '||r_rj.route_no
                            ||' stop_no= '||r_rj.alt_stop_no||' weight= '||to_char(r_rj.weight)
                            ||' v_return_reason_cd = '|| v_return_reason_cd||
                                ' r_rj.return_reason_cd= '|| r_rj.return_reason_cd|| ' v_prod_id = '||v_prod_id||' r_rj.prod_id= '||
                                   r_rj.prod_id||' v_barcode_refno= '||v_barcode_refno, --||' barcode= '||r_rj.barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                IF
                   1 = 1         -- 6/1/20 take it out l_whole_pallet_reject_1 <> 'F' add 1=1
                THEN
                    -- 6/1/20 take out dbms_output.put_line('loop in c_rj l_whole_pallet_reject_1 <> F');
                    dbms_output.put_line('in pl_sts_pod_interface_in.p_sts_import before call load_returns for route '
                     || r_rj.route_no
                     || ' stop '
                     || r_rj.alt_stop_no); --||' barcode '||r_rj.barcode);

                    pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in p_sts_import in c_rj loop before call load_return manif= '||r_rj.manifest_no||' route= '||r_rj.route_no
                            ||' stop_no= '||r_rj.alt_stop_no||' weight= '||to_char(r_rj.weight)
                            ||' v_return_reason_cd = '|| v_return_reason_cd||
                                ' r_rj.return_reason_cd= '|| r_rj.return_reason_cd|| ' v_prod_id = '||v_prod_id||' r_rj.prod_id= '||
                                   r_rj.prod_id||' v_barcode_refno= '||v_barcode_refno, --||' barcode= '||r_rj.barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                      l_manifest_no := r_rj.manifest_no;

                    load_return(
                        r_rj.manifest_no,
                        r_rj.route_no,
                        r_rj.alt_stop_no,
                        'I',--v_rec_type,--r_rj.record_type,
                        r_rj.invoice_num,
                        r_rj.prod_id,
                        '-',
                        r_rj.return_reason_cd,
                        r_rj.return_qty,
                        v_split_cd_1, -- returned_split_cd
                        r_rj.weight,
                        NULL,
                        r_rj.return_prod_id,
                        NULL,
                        r_rj.quantity,
                        v_split_cd_2, -- shipped_split_cd
                        NULL,
                        NULL,
						--r_rj.barcode,
                        --v_barcode_refno,
                        v_stop_correction,--r_rj.stop_correction,
                        r_rj.multi_pick_ind,
                        v_barcode_refno,
                        v_rec_type,
                        v_rtntab_status  --,
                        --r_rj.barcode
                    );

                    --vrj_barcode := r_rj.barcode; -- 5/16/20 add to fix stop 1 with all cw 0

                    FOR r_rjd IN c_rj_dtl(
                        v_msg_id,
                        v_barcode_refno   --,
                        --vrj_barcode  -- 5/16/20 add to fix stop 1 with all cw 0
                    ) LOOP

                        /* 5/14/20 take it out
                        IF
                            ( r_rjd.return_qty > 1 )
                        THEN
                            v_rb_status := 'ERR';
                            v_msg_text := 'Can not have more than one returned quanity per one barcode';
                            UPDATE returns
                                SET
                                    status = 'ERR'
                            WHERE
                                barcode_ref_no = v_barcode_refno;

                        END IF;

                        */

                        if (r_rjd.barcode is null) then  -- add 5/12/20 to handle barcode is null from sts

                           update returns
                           set barcode_ref_no = null
                           where manifest_no = r_rjd.manifest_no
                           and route_no = r_rjd.route_no
                           and prod_id = r_rjd.prod_id
                           and stop_no = r_rjd.alt_stop_no
                           and return_reason_cd = r_rjd.return_reason_cd
                           and barcode_ref_no = v_barcode_refno;

                        else

                                           pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'in p_sts_import in c_rj_dtl loop before call load_returns_barcode manif= '||r_rjd.manifest_no||' route= '||r_rjd.route_no
                            ||' stop_no= '||r_rjd.alt_stop_no
                               || ' r_rjd.return_reason_cd= '|| r_rjd.return_reason_cd||' r_rjd.prod_id= '||
                                   r_rjd.prod_id||' v_barcode_refno= '||v_barcode_refno, --||' barcode= '||r_rj.barcode,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in',
                            'u'
                        );

                           load_returns_barcode(
                            r_rjd.manifest_no,
                            r_rjd.record_type,
                            r_rjd.route_no,
                            r_rjd.invoice_num,
                            r_rjd.alt_stop_no,
                            r_rjd.prod_id,
                            r_rjd.quantity,
                            r_rjd.return_qty --,r_rj.refusal_reason_cd
                            ,
                            r_rjd.barcode,
                            r_rjd.return_reason_cd,
                            r_rjd.weight,
                            r_rjd.barcode_ref_no,
                            v_rb_status,
                            v_msg_text );

                        end if;   -- (r_rjd.barcode is null)

                    /* 4/22/20 replace by above
		            insert into returns_barcode (
                        manifest_no,sts_rec_type,route_no,obligation_no,stop_no,
                        prod_id,shipped_qty,returned_qty,--refusal_reason_cd,
                        barcode,return_reason_cd,catchweight,
                        barcode_ref_no,add_date,add_user,add_source,status,msg_text)
                    values (r_rjd.manifest_no,r_rjd.record_type,r_rjd.route_no,r_rjd.invoice_num,r_rjd.alt_stop_no,
                        r_rjd.prod_id,r_rjd.quantity,r_rjd.return_qty --,r_rj.refusal_reason_cd
                        ,r_rjd.barcode,r_rjd.return_reason_cd,r_rjd.weight,
                        r_rjd.barcode_ref_no,sysdate,'SWMS' ,'STS',v_rb_status,v_msg_text);
                    */

                    END LOOP r_rjd;

                END IF;

            END LOOP r_rj;

    /* move to above loop
	for r_rj in c_rj_dtl(v_msg_id,v_barcode_refno)
	loop

		insert into returns_barcode (
		         seq_no,manifest_no,sts_rec_type,route_no,obligation_no,stop_no,
	             prod_id,shipped_qty,returned_qty,--refusal_reason_cd,
                 barcode,return_reason_cd,catchweight,
	             barcode_ref_no,add_date,add_user,add_source)
	     values (returns_barcode_seq.nextval,r_rj.manifest_no,r_rj.record_type,r_rj.route_no,r_rj.invoice_num,r_rj.alt_stop_no,
	             r_rj.prod_id,r_rj.quantity,r_rj.return_qty --,r_rj.refusal_reason_cd
                 ,r_rj.barcode,r_rj.return_reason_cd,r_rj.weight,
	             r_rj.barcode_ref_no,sysdate,'SWMS' ,'STS');

    end loop;

    */

    /* Opening the cursor to process the each record */

            OPEN c_sts_route_message_id(v_msg_id);
            LOOP
                FETCH c_sts_route_message_id INTO v_sts_route;
                EXIT WHEN c_sts_route_message_id%notfound;

                --begin -- add 5/7/20

                   IF (v_rec_type = 'RT' ) then



                      pl_log.ins_msg(
                        'INFO',
                        'p_sts_import',
                        'in pls_sts_interface.p_sts_import after fetch c_sts_route_message_id and v_rec_type is RT, route close,  before do reverse credit msg_id= '
                         || v_msg_id|| ' stop_no= '|| v_sts_route.alt_stop_no||' prod_id= '||v_sts_route.prod_id||' return_reason_cd = '||
                         v_sts_route.return_reason_cd,
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pl_sts_pod_interface_in',
                        'u');

					declare

						CURSOR d_cur is --( per_message_id   VARCHAR2 ) IS
							SELECT
								manifest_no,
								route_no,
								--msg_id,
								floor(alt_stop_no) stop_no,
								invoice_num,
								record_type,
								return_reason_cd,
								wms_item_type,
								--multi_pick_ind,
								prod_id,
								--barcode, 4/13/21 take out
								--return_prod_id,
								--item_id,
								quantity,
								sum(weight) weight,
								--,sum(quantity) quantity,
								SUM(return_qty) return_qty
							FROM sts_route_in
							WHERE msg_id = v_msg_id
							AND record_type in ('RJ') -- 3/8/21 ('RJ','SP','SR')
							GROUP BY
								manifest_no,
								route_no,
								--msg_id,
								floor(alt_stop_no),
								invoice_num,
								record_type,
								return_reason_cd,
								wms_item_type,
								--  multi_pick_ind,
								prod_id,
								--barcode, 4/13/21 take out
								--  return_prod_id,
								--item_id,
								quantity;


					begin

						FOR r_cur IN d_cur LOOP

                            -- add 3/8/21
                            begin
                                select barcode_ref_no
                                into t_brn
                                from returns
                                where manifest_no = r_cur.manifest_no
                                and route_no= r_cur.route_no
                                and stop_no = r_cur.stop_no
                                and return_reason_cd = r_cur.RETURN_REASON_CD
                                and prod_id = r_cur.prod_id
                                and returned_qty = r_cur.return_qty
                                and shipped_qty = r_cur.quantity
                                and obligation_no =r_cur.invoice_num -- this will get rid off exact fetch error
                                and status != 'PUT'; -- this will get rid off exact fetch error

                                pl_log.ins_msg(
								'INFO',
								'pl_sts_import',
                                'in d_cur LOOP after select barcode_ref_no from returns t_brn= '||t_brn||
                                ' where msg_id= '||v_msg_id||' manifest_no = '||r_cur.manifest_no||' stop_no= '|| r_cur.stop_no||' prod_id= '||
                                   r_cur.prod_id||' return_reason_cd = '||r_cur.RETURN_REASON_CD||' returned_qty = '||r_cur.return_qty||
                                   ' shipped_qty = '||r_cur.quantity||' obligation_no = '||r_cur.invoice_num,
 								sqlcode,
								sqlerrm,
								'ORDER PROCESSING',
								'pl_sts_pod_interface_in',
								'u'
							    );
                              exception
                                when no_data_found then
                                    --null;
                                    t_brn :=900;
                                when TOO_MANY_ROWS then -- ADD 3/24/21

                                   pl_log.ins_msg(
								   'FATAL',
								   'pl_sts_import',
								   'when too_many_rows error from d_cur LOOP msg_id= '||v_msg_id||
                                   ' manifest_no = '||r_cur.manifest_no||' stop_no= '|| r_cur.stop_no||' prod_id= '||r_cur.prod_id||' return_reason_cd = '||
                                       r_cur.RETURN_REASON_CD||' returned_qty = '||r_cur.return_qty||' shipped_qty = '||r_cur.quantity||
                                       ' obligation_no = '||r_cur.invoice_num||' t_brn= '||t_brn,
								   sqlcode,
								   sqlerrm,
								  'ORDER PROCESSING',
								  'pl_sts_pod_interface_in',
								  'u'
							      );
                                  RAISE;
                              end;

							begin

                            /* this works for change reason code */
								UPDATE returns r
								SET r.pod_rtn_ind = 'D',
									r.lock_chg = 'Y'
								where not exists (select 'x'
                                        from
                                            returns_barcode br
                                        where r.manifest_no = br.manifest_no
                                        and r.manifest_no = r_cur.manifest_no
                                        and r.route_no = br.route_no
                                        and r.route_no = r_cur.route_no
                                        and r.stop_no = br.stop_no
                                        and r.stop_no = r_cur.stop_no
                                        and r.obligation_no = br.obligation_no
                                        and r.obligation_no = r_cur.invoice_num
                                        and r.RETURN_REASON_CD = br.RETURN_REASON_CD
                                        and r.RETURN_REASON_CD = r_cur.RETURN_REASON_CD
                                        and r.prod_id = br.prod_id
                                        and r.prod_id = r_cur.prod_id
                                        and r.shipped_qty = br.shipped_qty
                                        and r.shipped_qty = r_cur.quantity
                                        and r.returned_qty = r_cur.return_qty
                                        --and r.returned_qty = br.returned_qty -- is this causing change quantity not working? yes
                                        --and br.barcode = r_cur.barcode 4/13/21 take out
                                        and r.barcode_ref_no = t_brn  -- 3/8/21 add this
                                        and br.barcode_ref_no = r.barcode_ref_no)
								and r.manifest_no = r_cur.manifest_no
								and r.route_no = r_cur.route_no
								and r.stop_no = r_cur.stop_no
								and r.prod_id = r_cur.prod_id
								and r.obligation_no = r_cur.invoice_num -- add this 3/8/21 ;
                        and (r.barcode_ref_no = t_brn or t_brn = 900) -- 5/11/21 add this
								and r.status != 'PUT'
								and r.pod_rtn_ind = 'S'; -- add 4/13/21

                            --and r.barcode_ref_no != t_brn -- add this 3/8/21
                            --and r.returned_qty = r_cur.return_qty -- add this 3/8/21
                            --and r.prod_id = r_cur.prod_id; -- add this 3/8/21

							--and r.return_reason_cd = r_cur.return_reason_cd
							--and r.returned_qty != r_cur.return_qty;
                           -- */
                                -- this is for return quantity changes
                                /*
                                update returns r
							      set r.pod_rtn_ind = 'D',
                                      r.lock_chg = 'Y'
                                  where r.manifest_no = r_cur.manifest_no
                                  and r.route_no = r_cur.route_no
                                  and r.stop_no = r_cur.stop_no  --;
                                  -- this works for rtn qty chanes and r.returned_qty != r_cur.return_qty
                                  -- see if next line works for both the rtn qty change or rtn reason cd change
                                  and (r.return_reason_cd != r_cur.return_reason_cd
                                       or  r.returned_qty != r_cur.return_qty)
                                  --and r.return_reason_cd = r_cur.return_reason_cd
                                  and r.prod_id = r_cur.prod_id
                                  and r.obligation_no = r_cur.invoice_num;
                            */

								if sql%notfound then
									null;
								end if;

                            EXCEPTION
                                WHEN OTHERS THEN

							      message := 'WOT error from r_cur';
							      dbms_output.put_line('wot error at the r_cur loop update D messag='||message||' sqlcode='||sqlcode||
							        ' sqlerrm='||sqlerrm);

									pl_log.ins_msg(
									'FATAL',
									'p_sts_import',
									message,
									sqlcode,
									sqlerrm,
									'ORDER PROCESSING',
									'pl_sts_pod_interface_in',
									'u'
									);
									raise;

                             end;


						end loop;

					EXCEPTION
						WHEN OTHERS THEN

							message := 'WOT error from reverse credit process';
							--dbms_output.put_line('barcode_ref_no= '||v_barcode_ref_no);

							pl_log.ins_msg(
								'FATAL',
								'p_sts_import',
								message,
								sqlcode,
								sqlerrm,
								'ORDER PROCESSING',
								'pl_sts_pod_interface_in',
								'u'
							);

                           raise;

                      --*/

					end;





                    -- 5/15/20 add 3/25/21 need this for route close with record with RJ in stop close not in route close so need a D

                    UPDATE returns r
                     SET
                        r.pod_rtn_ind = 'D',
                        r.lock_chg = 'Y'
                     where r.barcode_ref_no in (select r1.barcode_ref_no
                                                 from returns r1,
                                                 returns_barcode br
                                                 WHERE not exists ( SELECT 'x'
                                                    FROM sts_route_in sri
                                                  WHERE   sri.msg_id = v_msg_id
                                                 and sri.record_type in ('RJ','SP','SR')
                                                    and r1.manifest_no = sri.manifest_no
                                                     and r1.stop_no = sri.alt_stop_no
                                                     and r1.route_no = sri.route_no
                                                        and   r1.prod_id = sri.prod_id
                                               --5/19/20 take this out replace by below and r1.returned_qty = sri.return_qty
                                               and br.returned_qty = sri.return_qty  -- 5/19/20 add this because in br and sri match not r1 and sri
                                               and  br.catchweight =  sri.weight  -- 5/21 add
                                              -- 2/19/21 take out
                                              and r1.return_reason_cd = sri.return_reason_cd
                                                and sri.barcode = br.barcode)
                                            and r1.manifest_no = v_sts_route.manifest_no
                                            and r1.route_no = v_sts_route.route_no
                                          and r1.barcode_ref_no = br.barcode_ref_no) --;
                   -- 2/19/20 take out
                   and r.pod_rtn_ind = 'S'; -- 4/13/21 add
                     --and r.stop_no = v_sts_route.alt_stop_no
                     --and r.prod_id = v_sts_route.prod_id
                     --and r.return_reason_cd = v_sts_route.return_reason_cd

                   if sql%notfound then
                          null;
                   end if;

                     --commit;


                   END IF;  -- v_rec_type = 'RT'

                --EXCEPTION
                --    WHEN OTHERS THEN

                --        pl_log.ins_msg(
                --            'FATAL',
                --            'pl_sts_pod_interface_in',
                --            'WOT error from reverse credit process',
                --            sqlcode,
                 --           sqlerrm,
                 --           'ORDER PROCESSING',
                --            'pl_sts_pod_interface_in.p_sts_import',
                --            'u'
                --        );

                --END;  -- begin IF v_rec_type = 'RT' then






                IF
                    ( ( v_return_reason_cd != v_sts_route.return_reason_cd ) OR ( v_prod_id != v_sts_route.prod_id ) )
                THEN -- add 3/31/20
                    SELECT
                        barcode_refno_seq.NEXTVAL
                    INTO
                        v_barcode_refno
                    FROM
                        dual;

                    v_return_reason_cd := v_sts_route.return_reason_cd;
                    v_prod_id := v_sts_route.prod_id;
                END IF;


        /* selecting the splic_cd to insert into return table */

                -- 7/17/20 add, CS
                SELECT
                    --DECODE(v_sts_route.wms_item_type,'S', 1, 'CS', 1,0)
                   DECODE(v_sts_route.wms_item_type, 'S', 1, 0)  -- 2/25/21
                INTO
                    v_split_cd
                FROM
                    dual;

                            /* Formatted on 2015/03/27 20:20 (Formatter Plus v4.8.8) */

                SELECT
                    DECODE(
                        v_sts_route.orig_wms_item_type,
                        'S',
                        1,
                        0
                    )
                INTO
                    v_orig_split_cd
                FROM
                    dual;

                      /* for whole pallet reject scenario */

                      /* Formatted on 2015/03/31 11:53 (Formatter Plus v4.8.8) */

                SELECT
                    substr(
                        v_sts_route.item_id,
                        1,
                        1
                    )
                INTO
                    l_whole_pallet_reject
                FROM
                    dual;


                  /*  IF v_sts_route.record_type = 'RT' THEN

                         v_route_sts := v_sts_route.route_no;
                         v_route_date := v_sts_route.route_date;

                    END IF;

                    IF v_sts_route.record_type = 'ST' THEN

                        v_alt_stop_sts := v_sts_route.alt_stop_no;
                        v_manifest_no  := v_sts_route.manifest_no;

                    END IF;*/

             /* putting the rejects,shorts,splits and pickup returns info to the database */

                IF
                    v_sts_route.record_type = 'DI' AND v_sts_route.return_qty > 0
                THEN
                    load_return(
                        v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'I',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.return_reason_cd,
                        v_sts_route.return_qty,
                        v_split_cd,--v_split_cd_1,
                        NULL,--v_sts_route.weight,
                        NULL,--v_sts_route.disposition,
                        NULL,--v_sts_route.return_prod_id,
                        NULL,
                        v_sts_route.quantity,
                        v_split_cd,--v_split_cd_1,
                        NULL,
                        NULL,
                        v_stop_correction,--r_rj.stop_correction,
                        v_sts_route.multi_pick_ind,
                        v_barcode_refno,
                        v_rec_type,
                        v_rtntab_status
                        --take out 5/19 ,v_sts_route.quantity
                    );


     --        IF v_status = 1 THEN
     --               RAISE  e_failed;
     --        END IF;
                ELSIF v_sts_route.record_type = 'SR' THEN


                    -- Update before trying to insert since Pick ups (rec_type = 'P' and add_source = 'MFR') are inserted into returns
                    -- when SWMS receives the manifest.
                    -- If the customer is NOT on POD,then do not set the POD_RTN_IND,
                    -- else,if the POD_RTN_IND is an 'A',then it should stay as 'A'
                    -- else,check if the new returned_qty is different from the current returned_qty,change the  POD_RTN_IND to 'U'.
                    --

					-- 10/6/20
                    select shipped_split_cd
                    into v_split_cd
                    from manifest_dtls
                    where manifest_no = to_number(v_sts_route.manifest_no)
                    and stop_no= floor(v_sts_route.alt_stop_no) -- 2/22/21 add floor
                    and prod_id = v_sts_route.prod_id
                    and obligation_no = v_sts_route.invoice_num;


                    IF
                        ( v_rec_type = 'ST' AND v_sts_route.return_qty = 0 )
                    THEN
                        UPDATE returns   -- see when returns rec created by 'MFR' return_qqty is null
                            SET
                                pod_rtn_ind = 'D',
                                lock_chg = 'Y',
                                returned_qty = v_sts_route.return_qty,
                                returned_split_cd = v_split_cd,
                                catchweight = nvl(
                                    catchweight,
                                    0
                                ),-- 09/12/19 + to_number(sz_catchweight),
                                upd_source = 'STS',
                                status = 'VAL'
                        WHERE
                                manifest_no = to_number(v_sts_route.manifest_no)
                            AND
                                stop_no = floor(v_sts_route.alt_stop_no) --2/22/21
                            AND
                                rec_type = 'P'
                            AND
                                obligation_no = v_sts_route.invoice_num
                            AND
                                prod_id = v_sts_route.prod_id
                            AND
                                cust_pref_vendor = '-'
                            AND
                                return_reason_cd = v_sts_route.return_reason_cd
                            AND
                                shipped_split_cd = v_split_cd
                            AND (
                                    returned_split_cd IS NULL
                                OR
                                    returned_split_cd = v_split_cd
                            );

                    ELSIF ( ( v_rec_type = 'ST' AND v_sts_route.return_qty > 0 ) OR ( v_rec_type = 'RT' ) ) THEN

                        -- 6/12/20 add
                        SELECT DISTINCT
                            nvl(pod_flag, 'N')
                        INTO    v_pod_flag
                        FROM    manifest_stops
                        WHERE manifest_no = to_number(v_sts_route.manifest_no)
                            AND stop_no = floor(v_sts_route.alt_stop_no) -- 2/22/21 add floor
                            AND obligation_no = v_sts_route.invoice_num;


                        UPDATE returns
                            SET
                                pod_rtn_ind = DECODE(
                                    v_pod_flag,
                                    'N',
                                    NULL,
                                    DECODE(
                                        pod_rtn_ind,
                                        'A',
                                        pod_rtn_ind,
                                        DECODE(
                                            returned_qty,
                                            v_sts_route.return_qty,
                                            pod_rtn_ind,
                                            'A'
                                        )
                                    )
                                ),
                                rtn_sent_ind='N', -- 6/12
                                returned_qty = v_sts_route.return_qty,
                                returned_split_cd = v_split_cd,
                                catchweight = nvl(
                                    catchweight,
                                    0
                                ),-- 09/12/19 + to_number(sz_catchweight),
                                upd_source = 'STS',
                                returned_prod_id = decode(v_sts_route.return_reason_cd, 'W10', null, v_sts_route.prod_id), -- 6/12/20 add
                                status = 'VAL' -- 6/12/20 add
                        WHERE
                                manifest_no = to_number(v_sts_route.manifest_no)
                            AND
                                stop_no = floor(v_sts_route.alt_stop_no) --2/22/21 add floor
                            AND
                                rec_type = 'P'
                            AND
                                obligation_no = v_sts_route.invoice_num
                            AND
                                prod_id = v_sts_route.prod_id
                            AND
                                cust_pref_vendor = '-'
                            AND
                                return_reason_cd = v_sts_route.return_reason_cd
                            AND
                                shipped_split_cd = v_split_cd
                            AND (
                                    returned_split_cd IS NULL
                                OR
                                    returned_split_cd = v_split_cd
                            );

                        IF
                            SQL%notfound
                        THEN
                            load_return(
                                v_sts_route.manifest_no,
                                v_sts_route.route_no,
                                floor(v_sts_route.alt_stop_no), --2/22/21
                                'P',--v_rec_type,--r_rj.record_type,
                                v_sts_route.invoice_num,
                                v_sts_route.prod_id,
                                '-',
                                v_sts_route.return_reason_cd,
                                v_sts_route.return_qty,
                                v_split_cd_1, -- 2/25/21 change to v_split_cd_1 from v_split_cd
                                v_sts_route.weight,
                                v_sts_route.disposition,
                                v_sts_route.return_prod_id,
                                NULL,
                                v_sts_route.quantity,
                                v_split_cd,--v_split_cd_1,
                                NULL,
                                NULL,
                                v_stop_correction,--r_rj.stop_correction,
                                v_sts_route.multi_pick_ind,
                                NULL, -- for SR is null v_barcode_refno,
                                v_rec_type,
                                v_rtntab_status
                                -- take out on 5/19 v_sts_route.barcode  -- 5/14/20
                            );

                            pl_log.ins_msg(
                            'INFO',
                            'p_sts_import',
                            'after inserted returns table for manifest= '||v_sts_route.manifest_no||
                            ' stop_no='||floor(v_sts_route.alt_stop_no)||' obligation_no='||v_sts_route.invoice_num||' prod_id='||
                            v_sts_route.prod_id||' return_reason_cd='||v_sts_route.return_reason_cd||
                            ' shipped_split_cd = '||v_split_cd
                            ,
                            sqlcode,
                            sqlerrm,
                            'O',
                            'pl_sts_pod_interface_in');

                        END IF;   -- SQL%NOTFOUND

                       pl_log.ins_msg(
                       'INFO',
                       'p_sts_import',
                        'after updated returns table for SR for rec created by MFR for manifest= '||v_sts_route.manifest_no||
                           ' stop_no='||floor(v_sts_route.alt_stop_no)||' obligation_no='||v_sts_route.invoice_num||' prod_id='||
                           v_sts_route.prod_id||' return_reason_cd='||v_sts_route.return_reason_cd||
                           ' shipped_split_cd = '||v_split_cd
                           ,
                        sqlcode,
                        sqlerrm,
                        'O',
                       'pl_sts_pod_interface_in');


                    END IF;         -- (v_rec_type = 'ST' and v_sts_route.return_qty = 0)


                /*  for SR don't need to insert into returns_barcode

                dbms_output.put_line('in v_sts_route.record_type = ''SR'' v_msg_id= '|| v_msg_id ||' v_barcode_refno= '||v_barcode_refno);

                for r_sr in c_sr_dtl(v_msg_id,v_barcode_refno)
                loop

                    if (r_sr.return_qty > 1 ) then
                        v_rb_status := 'ERR';
                        v_msg_text := 'Can not have more than one returned quanity per one barcode';

                        update returns
                        set status = 'ERR'
                        where barcode_ref_no = v_barcode_refno;


                    end if;

                    load_returns_barcode(r_sr.manifest_no,r_sr.record_type,r_sr.route_no,r_sr.invoice_num,r_sr.alt_stop_no,
                        r_sr.prod_id,r_sr.quantity,r_sr.return_qty --,r_rj.refusal_reason_cd
                        ,r_sr.barcode,r_sr.return_reason_cd,r_sr.weight,
                        r_sr.barcode_ref_no,v_rb_status,v_msg_text);


                end loop r_sr;
                */


               /*
               LOAD_RETURN( v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'P',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.return_reason_cd,
                        v_sts_route.return_qty,
                        v_split_cd,
                        v_sts_route.weight,
                        v_sts_route.disposition,
                        v_sts_route.return_prod_id,
                        NULL,
                        v_sts_route.quantity,
                        v_orig_split_cd,
                        NULL,NULL);

                 */

      --        IF v_status = 1 THEN
      --              RAISE  e_failed;
      --        END IF;
             /*
            ELSIF v_sts_route.record_type = 'RJ' and l_whole_pallet_reject <> 'F' THEN
            dbms_output.put_line('loop in RJ' );
            STS_RETURN( v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'I',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.return_reason_cd,
                        v_sts_route.return_qty,
                        v_split_cd,
                        v_sts_route.weight,
                        NULL,
                        v_sts_route.return_prod_id,
                        NULL,
                        v_sts_route.quantity,
                        v_split_cd,
                        NULL,NULL);
              */
       --      IF v_status = 1 THEN

       --      dbms_output.put_line(v_status );
       --             RAISE  e_failed;

       --      END IF;
                ELSIF v_sts_route.record_type = 'SP' THEN


                    /* 7/17/20 take out
                    IF
                        v_sts_route.hight_qty = 'Y'
                    THEN
                        v_qty := v_sts_route.qty_split;
                    ELSE
                        v_qty := 1;
                    END IF;
                    */

                    v_qty := v_sts_route.return_qty; -- add 7/17/20

           /*
            LOAD_RETURN( v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        v_sts_route.alt_stop_no,
                        'I',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.refusal_reason_cd,
                        v_qty,
                        v_split_cd,
                        v_sts_route.weight_adj,
                        NULL,
                        NULL,
                        NULL,
                        v_sts_route.quantity,
                        v_split_cd,
                        NULL,NULL);

                        */



                    load_return(
                        v_sts_route.manifest_no,
                        v_sts_route.route_no,
                        floor(v_sts_route.alt_stop_no), --2/22/21
                        'I',
                        v_sts_route.invoice_num,
                        v_sts_route.prod_id,
                        '-',
                        v_sts_route.refusal_reason_cd,
                        v_qty,
                        v_split_cd_1, --v_split_cd,
                        v_sts_route.weight_adj,
                        NULL,
                        NULL,
                        NULL,
                        v_sts_route.quantity,
                        '0', --v_split_cd,--v_split_cd_1, -- 7/24/20 for sp should be 0
                        NULL,
                        NULL,
                        v_stop_correction,--r_rj.stop_correction,
                        v_sts_route.multi_pick_ind,
                        v_barcode_refno,
                        v_rec_type,
                        v_rtntab_status
                        -- 5/29 take out for barcode roll up ,v_sts_route.barcode --5/14/20
                    );


           --  IF v_status = 1 THEN
           --         RAISE  e_failed;
          --   END IF;

                END IF;

            /* putting the cash and check info to the database as a each item */


           /* Calling the sts_impor_ Asset Program */

                IF
                    v_sts_route.record_type = 'AT'
                THEN
                    p_sts_import_asset(
                        v_sts_route.route_no,
                        v_sts_route.cust_id,
                        v_sts_route.barcode,
                        v_sts_route.quantity,
                        v_sts_route.route_date,
                        v_sts_route.time_stamp,
                        v_sts_route.event_type,
                        v_status
                    );

                    IF
                        v_status = 1
                    THEN
                        RAISE e_failed;
                    END IF;
                END IF;

            END LOOP;

            CLOSE c_sts_route_message_id;

/* CASH processing */

       /* To check whether batch existing or not for cash/check upload for the same route date*/
            SELECT
                COUNT(1)
            INTO
                v_count
            FROM
                sts_cash_batch
            WHERE
                    ROWNUM = 1
                AND
                    upload_time IS NULL
                AND
                    route_no = 'CASH'
                AND
                    route_date = v_route_date;
--                                FOR UPDATE NOWAIT;

            IF
                v_count > 0
            THEN

         /* Formatted on 2015/03/27 20:25 (Formatter Plus v4.8.8) */
                    SELECT
                        batch_no
                    INTO
                        v_cash_batch_no
                    FROM
                        sts_cash_batch
                    WHERE
                            ROWNUM = 1
                        AND
                            upload_time IS NULL
                        AND
                            route_no = 'CASH'
                        AND
                            route_date = v_route_date
                FOR UPDATE NOWAIT;

        /* Formatted on 2015/03/27 20:28 (Formatter Plus v4.8.8) */

                SELECT
                    nvl(
                        MAX(item_seq),
                        0
                    )
                INTO
                    l_cash_item_seq
                FROM
                    sts_cash_item
                WHERE
                    batch_no = v_cash_batch_no;

                l_cash_item_seq := l_cash_item_seq + 1;
            END IF;


        /* Insert entry into CASH_BATCH table for CASH */

         /* putting the cash and check info to the database as a batch */

            IF
                v_cash_batch_no IS NULL
            THEN
                SELECT
                    sts_cash_batch_no_seq.NEXTVAL
                INTO
                    v_cash_batch_no
                FROM
                    dual;

                INSERT INTO sts_cash_batch (
                    batch_no,
                    route_no,
                    route_date,
                    total_items
                ) VALUES (
                    v_cash_batch_no,
                    'CASH',
                    v_route_date,
                    v_count_cash
                );

                l_cash_item_seq := 1;
            END IF;

            FOR r_cash_invoice IN c_cash_invoice(
                v_msg_id,
                v_route_sts,
                v_route_date
            ) LOOP
                l_curr_cust_id := r_cash_invoice.cust_id;
                l_curr_type := r_cash_invoice.event_type;
                IF
                    l_curr_cust_id = l_prev_cust_id AND l_curr_type = l_prev_type
                THEN
                    l_cash_inc := l_cash_inc + 1;
                END IF;

                l_check_no := 'CASH';

         /* Formatted on 2015/03/26 21:21 (Formatter Plus v4.8.8) */
                INSERT INTO sts_cash_item (
                    batch_no,
                    item_seq,
                    cust_id,
                    amount,
                    invoice_num,
                    invoice_date,
                    check_num,
                    manifest_no
                ) VALUES (
                    v_cash_batch_no,
                    l_cash_item_seq,
                    r_cash_invoice.cust_id,
                    r_cash_invoice.credit_amt,
                    r_cash_invoice.invoice_num,
                    SYSDATE,
                    lpad(
                        l_check_no || l_cash_inc,
                        8,
                        ' '
                    ),
                    r_cash_invoice.manifest_no
                );

--           v_count_cash := v_count_cash+1;

                l_prev_cust_id := l_curr_cust_id;
                l_prev_type := l_curr_type;
                l_cash_item_seq := l_cash_item_seq + 1;
            END LOOP;

       /* CHECK processing */

       /* To check whether batch existing or not for cash/check upload for the same route date*/

            SELECT
                COUNT(1)
            INTO
                v_count
            FROM
                sts_cash_batch
            WHERE
                    ROWNUM = 1
                AND
                    upload_time IS NULL
                AND
                    route_no = 'CHEC'
                AND
                    route_date = v_route_date;
--                                FOR UPDATE NOWAIT;

            IF
                v_count > 0
            THEN

         /* Formatted on 2015/03/27 20:25 (Formatter Plus v4.8.8) */
                    SELECT
                        batch_no
                    INTO
                        v_check_batch_no
                    FROM
                        sts_cash_batch
                    WHERE
                            ROWNUM = 1
                        AND
                            upload_time IS NULL
                        AND
                            route_no = 'CHEC'
                        AND
                            route_date = v_route_date
                FOR UPDATE NOWAIT;

        /* Formatted on 2015/03/27 20:28 (Formatter Plus v4.8.8) */

                SELECT
                    nvl(
                        MAX(item_seq),
                        0
                    )
                INTO
                    l_chk_item_seq
                FROM
                    sts_cash_item
                WHERE
                    batch_no = v_check_batch_no;

                l_chk_item_seq := l_chk_item_seq + 1;
            END IF;


        /* Insert entry into CASH_BATCH table for CASH */

         /* putting the cash and check info to the database as a batch */

            IF
                v_check_batch_no IS NULL
            THEN
                SELECT
                    sts_cash_batch_no_seq.NEXTVAL
                INTO
                    v_check_batch_no
                FROM
                    dual;

                INSERT INTO sts_cash_batch (
                    batch_no,
                    route_no,
                    route_date,
                    total_items
                ) VALUES (
                    v_check_batch_no,
                    'CHEC',
                    v_route_date,
                    v_count_check
                );

                l_chk_item_seq := 1;
            END IF;

            FOR r_check_invoice IN c_check_invoice(
                v_msg_id,
                v_route_sts,
                v_route_date
            ) LOOP
                INSERT INTO sts_cash_item (
                    batch_no,
                    item_seq,
                    cust_id,
                    amount,
                    invoice_num,
                    invoice_date,
                    check_num,
                    manifest_no
                ) VALUES (
                    v_check_batch_no,
                    l_chk_item_seq,
                    r_check_invoice.cust_id,
                    r_check_invoice.credit_amt,
                    r_check_invoice.invoice_num,
                    SYSDATE,
                    substr(
                        r_check_invoice.check_no,
                        1,
                        8
                    ),
                    r_check_invoice.manifest_no
                );

--          v_count_check := v_count_check+1;

                l_chk_item_seq := l_chk_item_seq + 1;
            END LOOP r_check_invoice;

            dbms_output.put_line('value of v_status' || v_status);

             ---  jira 3592 - update the created returns record's 3 xdock columns with correct values



 FOR i IN c_xdock_rtns (l_manifest_no)  LOOP

 Begin
  UPDATE returns r
  SET xdock_ind            = i.xdock_ind,
    r.site_from            = i.site_from,
    r.site_to              = i.site_to
  WHERE r.manifest_no      = i.manifest_no
  AND r.STOP_NO            = i.STOP_NO
  AND r.OBLIGATION_NO      = i.OBLIGATION_NO
  AND r.REC_TYPE           = i.REC_TYPE
  AND r.PROD_ID            = i.PROD_ID
  AND r.CUST_PREF_VENDOR   = i.CUST_PREF_VENDOR
  AND (r.SHIPPED_SPLIT_CD IS NULL
  OR r.SHIPPED_SPLIT_CD    = i.SHIPPED_SPLIT_CD)
  AND r.RETURNED_QTY      IS NOT NULL  ;
Exception when others then
  Null;
End ;
END LOOP;



     /* Updating the messgae_id as completed */
            UPDATE sts_route_in
                SET
                    record_status = 'S'
            WHERE
                msg_id = v_msg_id
                and record_status = 'N'; --5/15/20  add for some rec like barcode less 8 or null we have 'x'  to not process it.

            IF
                v_status = 0
            THEN
                COMMIT;
            END IF;

    /* add 3/9/20 -- disable it on 3/30

    for c_rb in c_returns_barcode(v_sts_route.manifest_no)
    loop

          load_return(
      c_rb.manifest_no,
    c_rb.route_no,
    c_rb.stop_no,
    c_rb.rec_type,
    c_rb.obligation_no,--  c_rb.invoice_no,
    c_rb.prod_id,
    c_rb.cust_pref_vendor,
    c_rb.return_reason_cd,
    c_rb.returned_qty,
    c_rb.returned_split_cd,
    c_rb.catchweight,
    c_rb.disposition,
    c_rb.returned_prod_id,
    c_rb.erm_line_id,
    c_rb.shipped_qty,
    c_rb.shipped_split_cd,
    c_rb.cust_id,
    c_rb.temperature,
	c_rb.barcode_ref_no,
	c_rb.stop_correction_ind,
	c_rb.multi_pick_ind);



       end loop;

     */

    --Added for CRQ34059,to process returns if customer level POD flag and syspar POD_ENABLE
    --is turned ON
            SELECT DISTINCT
                manifest_no,
                TO_DATE('01-JAN-1980','DD-MON-YYYY')
            INTO
                v_manifest_no,v_up_dt
            FROM
                sts_route_in
            WHERE
                    msg_id = v_msg_id
                AND
                    record_type = 'ST';

    -- 4/14/20 replace with below FOR c_available in c_stop_records (v_msg_id)

            FOR c_srtt IN c_stop_records_to_trans(v_msg_id) LOOP
                SELECT
                    config_flag_val
                INTO
                    v_opco_pod_flag
                FROM
                    sys_config
                WHERE
                    config_flag_name = 'POD_ENABLE';

                SELECT DISTINCT
                    pod_flag
                INTO
                    v_pod_flag
                FROM
                    manifest_stops
                WHERE
                        manifest_no = v_manifest_no
                    AND
                        stop_no = floor(to_number(c_srtt.alt_stop_no) )
                    AND
                        customer_id = c_srtt.cust_id;

                SELECT
                    COUNT(*)
                INTO
                    i_cnt
                FROM
                    sts_route_in
                WHERE
                        alt_stop_no = floor(to_number(c_srtt.alt_stop_no) )
                    AND
                        msg_id = v_msg_id
                    AND (
                        (
                            return_reason_cd LIKE 'T%'
                        ) OR (
                            return_reason_cd LIKE 'D%'
                        ) OR (
                            return_reason_cd = 'N01'
                        )
                    );

                dbms_output.put_line('before checking v_pod_flag and v_opco_pod_flag if y call pod_create_rtn');

                       pl_log.ins_msg(
                        'INFO',
                        'p_sts_import',
                        'in pls_sts_interface.p_sts_import see if should call pod_create_rtn v_pod_flag= '|| v_pod_flag||
                        ' v_opco_pod_flag= '||v_opco_pod_flag||' v_rec_type= '||v_rec_type||
                        ' manifest_no ='
                        || v_manifest_no
                        || ' alt_stop_no '
                        || floor(c_srtt.alt_stop_no)
                        || ' cust_id '
                        || c_srtt.cust_id
                        || ' route no '
                        || c_srtt.route_no
                        || ' barcode '
                        || c_srtt.barcode --5/16/20
                        || ' v_rec_type= '|| v_rec_type  -- 6/12/20 add
                        || 'msg id '
                        || v_msg_id,
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pl_sts_pod_interface_in',
                        'u'
                    );


                IF
                   ( v_pod_flag = 'Y' AND v_opco_pod_flag = 'Y' and v_rec_type = 'ST' )  -- 6/12/20 add and v_rec_type = 'ST'
                THEN

                   pl_log.ins_msg(
                        'INFO',
                        'p_sts_import',
                        'in pls_sts_interface.p_sts_import before call pod_create_rtn manifest_no '
                        || v_manifest_no
                        || 'alt_stop_no '
                        || floor(c_srtt.alt_stop_no)
                        || 'cust_id '
                        || c_srtt.cust_id
                        || 'route no '
                        || c_srtt.route_no
                        || 'barcode '
                        || c_srtt.barcode --5/16/20
                        || 'v_rec_type= '|| v_rec_type  -- 6/12/20 add
                        || 'msg id '
                        || v_msg_id,
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pl_sts_pod_interface_in',
                        'u'
                    );

                    dbms_output.put_line('before call pod_create_rtn manifest_no '
                     || v_manifest_no
                     || 'alt_stop_no '
                     || floor(c_srtt.alt_stop_no)
                     || 'cust_id '
                     || c_srtt.cust_id
                     || 'route no '
                     || c_srtt.route_no
                     || 'barcode '
                     || c_srtt.barcode --5/16/20
                     || 'v_rec_type= '|| v_rec_type  -- 6/12/20 add
                     || 'msg id '
                     || v_msg_id);

                    pod_create_rtn(
                        v_manifest_no,
                        floor(c_srtt.alt_stop_no), --2/22/21
                        rtn_process_flag,
                        c_srtt.cust_id,
                        c_srtt.route_no,
                        v_msg_id,
                        c_srtt.barcode
                    );
    --insert stop close(STC) after successful processing of item returns.

                    v_count_stc := 0;
                    SELECT
                        COUNT(*)
                    INTO
                        v_count_stc
                    FROM
                        trans
                    WHERE
                            trans_type = 'STC'
                        AND
                            stop_no = floor(to_number(c_srtt.alt_stop_no) )
                        AND
                            cust_id = c_srtt.cust_id
                        AND
                            route_no = c_srtt.route_no
                        AND
                            rec_id = v_manifest_no;


                    -- add 6/30/20 to prevent N01, N50 put STC in trans table
                    v_count_tran := 0;

                    SELECT COUNT(*)
                    INTO  v_count_tran
                    FROM
                        sts_route_in
                    WHERE
                         manifest_no = v_manifest_no
                        AND alt_stop_no = floor(to_number(c_srtt.alt_stop_no) )
                        AND record_status = 'X'
                        AND route_no = c_srtt.route_no
                        and record_type = 'RJ'
                        and return_reason_cd in (select reason_cd
                                                 from reason_cds rc
							                     where rc.reason_cd_type = 'RTN'
							                     and nvl(rc.suppress_imm_credit, 'N') = 'Y' );




                        --and invoice_num = c_srtt.invoice_num;

                   -- 4/29/20 add this to prevent 'SR' returns.pod_rtn_ind = 'D' due to return qty is 0
                   -- when MFR created rec in returns has return qty = null
                   --to have STC inserts into TRANS table

                -- wrong this is > 0 if STC is not in trans table for the SR then we don't want to insert into trans table
                -- this is 0 if RTN is not in trans table for the SR then we don't want to insert into trans table

                              -- this get 1 means we want to create STC



                    SELECT count(t.trans_id)
                    into v_count_stc_for_sr_d
                    FROM
                        trans t, returns r
                    WHERE
                            t.trans_type = 'RTN' --'STC'
                        AND t.stop_no = floor(to_number(c_srtt.alt_stop_no) )
                        and t.stop_no = r.stop_no
                        --AND t.cust_id = c_srtt.cust_id
                        AND r.cust_id = c_srtt.cust_id
                        --and   t.cust_id = r.cust_id -- t.cust_id is null for 'RTN'
                        AND t.route_no = c_srtt.route_no
                        and t.route_no = r.route_no
                        and t.rec_id = to_char(r.manifest_no)
                        and r.pod_rtn_ind  != 'D';

	    --10/27
                   /*
                    SELECT
                        COUNT(*)
                    INTO
                        i_td_cnt_1
                    FROM
                        sts_route_in
                    WHERE
           --record_status = 'N'
		   --and route_no = i_route_no --msg_id = t_msg_id
		   --and
                            msg_id = v_msg_id
                        AND (
                            (
                                return_reason_cd LIKE 'T%'
                            ) OR (
                                return_reason_cd LIKE 'D%'
                            ) OR (
                                return_reason_cd = 'N01'
                            )
                        );

                    pl_log.ins_msg(
                        'INFO',
                        'pl_sts_pod_interface_in',
                        'in pls_sts_interface.p_sts_import before insert STC msg_id= '
                         || v_msg_id
                         || ' i_td_cnt_1 = '
                         || TO_CHAR(i_td_cnt_1),
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pls_sts_interface.pod_create_rtn',
                        'u'
                    );

                    SELECT
                        COUNT(*)
                    INTO
                        i_rn_cnt_1
                    FROM
                        sts_route_in
                    WHERE
                            msg_id = v_msg_id
                        AND (
                            (
                                return_reason_cd LIKE 'R%'
                            ) OR (
                                return_reason_cd LIKE 'W%'
                            ) OR (
                                    return_reason_cd LIKE 'N%'
                                AND
                                    return_reason_cd != 'N01'
                            )
                        );

                    pl_log.ins_msg(
                        'INFO',
                        'pl_sts_pod_interface_in',
                        'in pls_swms_interface.p_sts_import before insert STC msg_id= '
                         || v_msg_id
                         || ' i_rn_cnt_1 = '
                         || TO_CHAR(i_rn_cnt_1),
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pls_sts_interface.pod_create_rtn',
                        'u'
                    );


                  */


        pl_log.ins_msg(
            'INFO',
            'p_sts_import',
            'in pl_sts_pod_interface_in.p_sts_import before insert STC to Trans msg_id= '
             || v_msg_id
             || ' v_count_stc = '
             || TO_CHAR(v_count_stc)
             || ' v_count_stc_for_sr_d = '
             || TO_CHAR(v_count_stc_for_sr_d)
             || ' v_count_tran = '
             || TO_CHAR(v_count_tran)
             ,
            sqlcode,
            sqlerrm,
            'ORDER PROCESSING',
            'pl_sts_pod_interface_in',
            'u'
        );

                    IF
                        -- 6/30/20 need STC if stop close has no returns, replace with below((v_count_stc > 0) or (v_count_stc_for_sr_d < 1 ) )
                       ( (v_count_stc > 0) or (v_count_tran > 0) )
                    THEN
                        NULL;
                    ELSE
                        IF
                          -- 6/30/20 need STC if stop close has no returns, replace with below ( rtn_process_flag = true )
                          ( ( rtn_process_flag = true ) or (v_count_stc_for_sr_d < 1 ) )
                        THEN
	--  if (RTN_process_flag=TRUE and i_cnt = 0) THEN --10/13/19
	  --if ( (RTN_process_flag=TRUE and i_td_cnt_1 = 0) -- take out 10/29/19
        --     or (RTN_process_flag=TRUE and i_rn_cnt_1 > 0)) THEN
	--  if ( (RTN_process_flag=TRUE) and (i_td_cnt_1 = 0)) THEN
                            BEGIN


                               SELECT COUNT(*)
                               INTO l_xdock_rtn_cnt
                               FROM Returns r
                               WHERE r.manifest_no = v_manifest_no
                               AND stop_no         = floor(to_number(c_srtt.alt_stop_no) )
                               AND xdock_ind       ='X';

                            If nvl(l_xdock_rtn_cnt,0) = 0 then

                                INSERT INTO trans (
                                    trans_id,
                                    trans_type,
                                    trans_date,
                                    batch_no,
                                    route_no,
                                    stop_no,
                                    rec_id,
                                    upload_time,
                                    user_id,
                                    cust_id,
                                    adj_flag
                                ) VALUES (
                                    trans_id_seq.NEXTVAL,
                                    'STC',
                                    SYSDATE,
                                    '88',
                                    c_srtt.route_no,
                                    floor(to_number(c_srtt.alt_stop_no) ),
                                    v_manifest_no,
                                    v_up_dt,
                                    'SWMS',
                                    c_srtt.cust_id,
                                    NULL                );
                               End If;

                                pl_log.ins_msg(
                                    'INFO',
                                    'p_sts_import',
                                    'rtn_process_flag is TRUE inserted to trans for STC for manifest='
                                     || v_manifest_no
                                     || ' stop '
                                     || floor(to_number(c_srtt.alt_stop_no) ),
                                    sqlcode,
                                    sqlerrm,
                                    'ORDER PROCESSING',
                                    'pl_sts_pod_interface_in',
                                    'u'
                                );

                                  pl_rtn_xdock_interface.Populate_imdt_rtns_out(v_manifest_no,  c_srtt.alt_stop_no) ;  -- Jira 3592 xdock change

                                UPDATE manifest_stops
                                    SET
                                        pod_status_flag = 'S'
                                WHERE
                                        stop_no = floor(to_number(c_srtt.alt_stop_no) )
                                    AND
                                        manifest_no = v_manifest_no;

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    message := 'Insert STC into Trans Failed';
                                    pl_log.ins_msg(
                                        'FATAL',
                                        'p_sts_import',
                                        message,
                                        sqlcode,
                                        sqlerrm,
                                        'ORDER PROCESSING',
                                        'pl_sts_pod_interface_in',
                                        'u'
                                    );

                            END;

                        ELSE
                            UPDATE manifest_stops
                                SET
                                    pod_status_flag = 'F'
                            WHERE
                                    stop_no = floor(to_number(c_srtt.alt_stop_no) )
                                AND
                                    manifest_no = v_manifest_no;

                            COMMIT;
                        END IF; -- ( rtn_process_flag = true )

                    END IF;  -- v_count_stc > 0

                END IF;

            END LOOP c_srtt; --c_stop_records_2nd;


            begin

		    /*    take out 6/25/20
            pl_log.ins_msg(
                'INFO',
                'pl_sts_pod_interface_in',
                'after end loop c_sts_route before do update manifests.sts_completed_ind for route close v_rec_type= '||v_rec_type  ,
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in');
            */


               if (v_rec_type = 'RT') then --(v_rec_type > 1) then

                     pl_log.ins_msg(
                       'INFO',
                       'p_sts_import',
                        'after end loop c_srtt in update manifests.sts_completed_ind for route close v_rec_type= '||v_rec_type ,
                        sqlcode,
                        sqlerrm,
                        'O',
                       'pl_sts_pod_interface_in');

                     select manifest_no
                     into v_rt_manifest_no
                     from sts_route_in
                     where msg_id = v_msg_id
                    and record_type = 'ST'
                    and rownum = 1    ;

                    BEGIN
                        SELECT COUNT(*)
                        INTO l_xdock_ind_s_cnt
                        FROM manifests m, manifest_dtls md
                        WHERE m.manifest_no =  md.manifest_no
                        AND m.manifest_no = v_rt_manifest_no
                        AND md.xdock_ind = 'S';

                    EXCEPTION WHEN OTHERS THEN
                        pl_log.ins_msg(
                            'WARN',
                            'p_sts_import',
                            'Failed to retrieve xdock_ind = S count for the given manifest: '||
                            v_rt_manifest_no,
                            sqlcode,
                            sqlerrm,
                            'O',
                            'pl_sts_pod_interface_in');
                    END;

                    /* OPCOF-3669: Avoid updating STS_COMPLETED_IND to 'Y' for Manifest containing Xdock orders in Fullfillment Site. */
                    IF nvl(l_xdock_ind_s_cnt, 0) > 0 THEN
                      pl_log.ins_msg(
                        'INFO',
                        'p_sts_import',
                        'Fullfillment site manifest contains xdock orders. Therefore not updating manifests.sts_completed_ind. [manifest]: '||
                        v_rt_manifest_no,
                        sqlcode,
                        sqlerrm,
                        'O',
                        'pl_sts_pod_interface_in');
                    ELSE
                     update manifests
                        set STS_COMPLETED_IND = 'Y'
                     where manifest_no = v_rt_manifest_no;

                     pl_log.ins_msg(
                        'INFO',
                       'p_sts_import',
                        'Updated manifests.sts_completed_ind for route close updated manifests sts_completed_ind to Y for manifest '||
                       v_rt_manifest_no,
                        sqlcode,
                       sqlerrm,
                       'O',
                        'pl_sts_pod_interface_in');
                    END IF;

                end if;

            exception
                WHEN OTHERS THEN
               --dbms_output.put_line('error' || sqlcode || sqlerrm);
                pl_log.ins_msg(
                'FATAL',
                'p_sts_import',
                'Error from wot in update manifests.sts_completed_ind block',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in');

            end;


        END LOOP c_sts_route;

        -- 5/14/20 add and 7/6/20 move the whole block between 'END LOOP c_srtt;' and 'END LOOP c_sts_route;' to fix error
        -- where route close with one xml with more than 1 route, only the last route get manifests.set_completed_ind = Y

        /* 7/6/20 move up this block
        begin

		    --    take out 6/25/20
            --pl_log.ins_msg(
              --  'INFO',
              --  'pl_sts_pod_interface_in',
              --  'after end loop c_sts_route before do update manifests.sts_completed_ind for route close v_rec_type= '||v_rec_type  ,
              --  sqlcode,
              --  sqlerrm,
              --  'O',
              --  'pl_sts_pod_interface_in');



           if (v_rec_type = 'RT') then --(v_rec_type > 1) then

             pl_log.ins_msg(
                'INFO',
                'pl_sts_pod_interface_in',
                'after end loop c_sts_route in update manifests.sts_completed_ind for route close v_rec_type= '||v_rec_type ,
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in');

             select manifest_no
             into v_rt_manifest_no
             from sts_route_in
             where msg_id = v_msg_id
             and record_type = 'ST'
             and rownum = 1    ;

             update manifests
             set STS_COMPLETED_IND = 'Y'
             where manifest_no = v_rt_manifest_no;

             pl_log.ins_msg(
                'INFO',
                'pl_sts_pod_interface_in',
                'Updated manifests.sts_completed_ind for route close updated manifests sts_completed_ind to Y for manifest '||
                   v_rt_manifest_no,
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in');

           end if;

        exception
            WHEN OTHERS THEN
               --dbms_output.put_line('error' || sqlcode || sqlerrm);
            pl_log.ins_msg(
                'FATAL',
                'pl_sts_pod_interface_in',
                'Error in update manifests.sts_completed_ind',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in');

        end;
        */

        CLOSE c_sts_route;
    EXCEPTION
        WHEN e_failed THEN
            pl_log.ins_msg(
                'FATAL',
                'p_sts_import',
                'Error from exception after close c_sts_route when e_failed ',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in'
            );

            dbms_output.put_line('error' || sqlcode || sqlerrm);
            ROLLBACK;
       /* Updating the messgae_id as failed */
            UPDATE sts_route_in
                SET
                    record_status = 'F'
            WHERE
                msg_id = v_msg_id;

            COMMIT;
        WHEN no_data_found THEN
            pl_log.ins_msg(
                'FATAL',
                'p_sts_import',
                'Error from exception after close c_sts_route when no_data_found',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in'
            );

            dbms_output.put_line('error' || sqlcode || sqlerrm);
            ROLLBACK;
           /* Updating the messgae_id as failed */
            UPDATE sts_route_in
                SET
                    record_status = 'F'
            WHERE
                msg_id = v_msg_id;

            COMMIT;
        WHEN OTHERS THEN
            dbms_output.put_line('error' || sqlcode || sqlerrm);
            pl_log.ins_msg(
                'FATAL',
                'p_sts_import',
                'Error from exception after close c_sts_route wot',
                sqlcode,
                sqlerrm,
                'O',
                'pl_sts_pod_interface_in'
            );

            ROLLBACK;
            /* Updating the messgae_id as failed */
            UPDATE sts_route_in
                SET
                    record_status = 'F'
            WHERE
                msg_id = v_msg_id;

            COMMIT;
    END p_sts_import;

    PROCEDURE pod_create_rtn (
        i_manifest_number   IN VARCHAR2,
        i_stop_number       IN NUMBER,
        rtn_process_flag    OUT BOOLEAN,
        i_cust_id           IN VARCHAR2,
        i_route_no          IN VARCHAR2,
        i_msg_id            IN VARCHAR2,
        i_barcode           IN VARCHAR2
    ) IS

        v_reason_group    VARCHAR2(3);
        status            VARCHAR2(3);
        v_rc              VARCHAR2(3);
        v_up_dt           DATE;
        v_route           VARCHAR2(10) := NULL; -- D#10516 Added
        v_orig_inv        VARCHAR2(16) := NULL; -- D#10516 Added
        l_success_flag    BOOLEAN := true;
        message           VARCHAR2(2000);
        v_returns_count   NUMBER := 0;
        v_rtn_count       NUMBER := 0;
        v_count           NUMBER := 0;
        v_stc_count       NUMBER := 0;
        i_pod_cnt         NUMBER; --10/13/19
        i_rn_cnt          NUMBER; --10/18/19
        i_td_cnt          NUMBER; --10/26/19

        CURSOR rtns_cursor (
            manifest_number   NUMBER,
            stop_number       NUMBER,
            customer_id       VARCHAR2
        ) IS
            SELECT distinct  -- 5/16/20 add distinct
                r.manifest_no,
                r.route_no,
                r.stop_no,
                r.rec_type,
                r.obligation_no,
                r.prod_id,
                r.cust_pref_vendor,
                r.return_reason_cd,
                r.returned_qty,
                r.returned_split_cd,
                catchweight,
                temperature,
                disposition,
                r.returned_prod_id,
                erm_line_id,
                reason_group,
                p.catch_wt_trk,
                DECODE(
                    r.obligation_no,
                    NULL,
                    r.obligation_no,
                    DECODE(
                        instr(
                            r.obligation_no,
                            'L'
                        ),
                        0,
                        r.obligation_no,
                        substr(
                            r.obligation_no,
                            1,
                            instr(
                                r.obligation_no,
                                'L'
                            ) - 1
                        )
                    )
                ) ob_no,
                r.xdock_ind
            FROM
                returns r,
                reason_cds rc,
                pm p,
                manifest_stops m
            WHERE
                    r.manifest_no = manifest_number
                AND
                    r.manifest_no = m.manifest_no
                AND
                    rc.reason_cd_type = 'RTN'
                AND
                    rc.reason_cd = r.return_reason_cd
         -- 10/2 AND    (rc.reason_cd not like 'T%' AND rc.reason_group != 'DMG')
                AND
                    r.prod_id = p.prod_id
                AND
                    r.cust_pref_vendor = p.cust_pref_vendor
                AND
                    r.stop_no = floor(to_number(stop_number) )
                AND
                    m.stop_no = r.stop_no
                AND
                    m.customer_id = customer_id
                AND
                    r.pod_rtn_ind != 'D'  -- add 4/29/20 don't send 'D' to trans table
         --and r.status != 'ERR'   -- add 4/13/20  -- 4/14/20 replace by cursor c_stop_records_to_trans
                and r.add_source = 'STS'  -- add 6/17/20
                and r.status = 'VAL' -- add 6/17/20
            ORDER BY
                obligation_no,
                rec_type,
                r.prod_id;

    BEGIN
        SELECT
            manifest_status,
            route_no
        INTO
            status,v_route
        FROM
            manifests
        WHERE
            manifest_no = i_manifest_number;

         /*  10/16/19 take out
        select count(*)
		into i_pod_cnt
		from sts_route_in
		where alt_stop_no = floor( to_number(i_stop_number) )
        and manifest_no = i_manifest_number
		--and msg_id=v_msg_id
		and (return_reason_cd like 'T%' or return_reason_cd like 'D%');
        */

        SELECT
            COUNT(*)
        INTO
            i_pod_cnt  -- if is 1 it is stop close,> 1 it is route close
        FROM
            sts_route_in
        WHERE
                msg_id = i_msg_id
		   --take out 10/25/19 and record_status = 'N'
		   --and route_no = i_route_no --msg_id = t_msg_id
		   --and msg_id = i_msg_id
            AND (
                    record_type = 'ST'
                OR
                    record_type = 'ET'
            );

        pl_log.ins_msg(
            'INFO',
            'pl_sts_pod_interface_in',
            'in pl_sts_pod_interface_in.pod_create_rtn msg_id= '
             || i_msg_id
             || ' i_pod_cnt = '
             || TO_CHAR(i_pod_cnt),
            sqlcode,
            sqlerrm,
            'ORDER PROCESSING',
            'pl_sts_pod_interface_in.pod_create_rtn',
            'u'
        );
        /*
	    select count(*)
		   into i_rn_cnt
           from sts_route_in
           where
           --record_status = 'N'
		   --and route_no = i_route_no --msg_id = t_msg_id
		   --and
           msg_id = i_msg_id
		   and ( (return_reason_cd like 'R%') or
		         (return_reason_cd like 'W%') or
		         (return_reason_cd like 'N%' and return_reason_cd != 'N01') );


           	   pl_log.ins_msg ('INFO',
                      'pl_sts_pod_interface_in',
                      'in pls_sts_interface.pod_create_rtn msg_id= '||i_msg_id||
                      ' i_rn_cnt = '||to_char(i_rn_cnt),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );

		select count(*)
			into i_td_cnt
			from sts_route_in
			WHERE msg_id = i_msg_id
			and ((return_reason_cd like 'D%') or (return_reason_cd like 'T%') or (return_reason_cd = 'N01'));

        pl_log.ins_msg ('INFO',
                      'pl_sts_pod_interface_in',
                      'in pls_sts_interface.pod_create_rtn msg_id= '||i_msg_id||
                      ' i_td_cnt = '||to_char(i_td_cnt),
                      SQLCODE,
                      SQLERRM,
                      'ORDER PROCESSING',
                      'pls_sts_interface.pod_create_rtn',
                      'u'
                     );
             */

        IF
            status = 'CLS'
        THEN
            message := 'Manifest is already Closed';
            pl_log.ins_msg(
                'FATAL',
                'pl_sts_pod_interface_in',
                message,
                sqlcode,
                sqlerrm,
                'ORDER PROCESSING',
                'pl_sts_pod_interface_in.pod_create_rtn',
                'u'
            );

        ELSE
            IF
                status = 'PAD'
            THEN
                v_up_dt := NULL;
            ELSE
                v_up_dt := TO_DATE('01-JAN-1980','DD-MON-YYYY');
            END IF;

            FOR rtns_rec IN rtns_cursor(
                i_manifest_number,
                i_stop_number,
                i_cust_id
            ) LOOP
                BEGIN
                    v_returns_count := v_returns_count + 1;
                    l_success_flag := true;
                    v_rc := rtns_rec.return_reason_cd;
                    SELECT
                        reason_group
                    INTO
                        v_reason_group
                    FROM
                        reason_cds
                    WHERE
                            reason_cd = v_rc
                        AND
                            reason_cd_type = 'RTN';

                EXCEPTION
                    WHEN no_data_found THEN
                        l_success_flag := false;
                        message := 'Invalid Reason Code';
                        pl_log.ins_msg(
                            'FATAL',
                            'pl_sts_pod_interface_in',
                            message,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in.pod_create_rtn',
                            'u'
                        );

                END;

                IF
                    rtns_rec.rec_type = 'I'
                THEN
                    IF
                        v_rc IN (
                            'MPR','MPK'
                        )
                    THEN
                        IF
                            rtns_rec.returned_prod_id IS NULL
                        THEN
                            l_success_flag := false;
                            message := 'Mispick item is missing for invoice';
                            pl_log.ins_msg(
                                'FATAL',
                                'pl_sts_pod_interface_in',
                                message,
                                sqlcode,
                                sqlerrm,
                                'ORDER PROCESSING',
                                'pl_sts_pod_interface_in.pod_create_rtn',
                                'u'
                            );

                        ELSIF nvl(
                            rtns_rec.returned_qty,
                            0
                        ) = 0 THEN
                            l_success_flag := false;
                            message := ' Mispick quantity is missing for invoice ';
                            pl_log.ins_msg(
                                'FATAL',
                                'pl_sts_pod_interface_in',
                                message,
                                sqlcode,
                                sqlerrm,
                                'ORDER PROCESSING',
                                'pl_sts_pod_interface_in.pod_create_rtn',
                                'u'
                            );

                        END IF; -- rtns_rec.returned_prod_id

                    ELSIF nvl(
                        rtns_rec.returned_qty,
                        0
                    ) = 0 THEN
                        l_success_flag := false;
                        message := 'Returned Quantity should be greater than 0';
                        pl_log.ins_msg(
                            'FATAL',
                            'pl_sts_pod_interface_in',
                            message,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in.pod_create_rtn',
                            'u'
                        );

                    END IF; -- v_rc IN ('MPR','MPK')

                END IF;  -- rtns_rec.rec_type = 'I'

                v_orig_inv := NULL;
                IF
                    rtns_rec.rec_type IN (
                        'P','D'
                    )
                THEN
                    BEGIN
                        SELECT
                            DECODE(
                                instr(
                                    orig_invoice,
                                    'L'
                                ),
                                0,
                                orig_invoice,
                                substr(
                                    orig_invoice,
                                    1,
                                    instr(
                                        orig_invoice,
                                        'L'
                                    ) - 1
                                )
                            )
                        INTO
                            v_orig_inv
                        FROM
                            manifest_dtls
                        WHERE
                                manifest_no = i_manifest_number
                            AND
                                prod_id = rtns_rec.prod_id
                            AND
                                rec_type IN (
                                    'P','D'
                                )
                            AND
                                obligation_no = rtns_rec.obligation_no;

                    EXCEPTION
                        WHEN no_data_found THEN
                            NULL;
                        WHEN too_many_rows THEN
                            NULL;
                    END;
                END IF;  -- rtns_rec.rec_type IN ('P','D')

      --
      -- if we have an overage situation,the invoice
      -- is accurate don?t bother letting systar know
      -- (i.e. we don?t need to write a trans record.).
      -- DN#4121:acpjjs:Trans required for all returns.
      -- DN#5233:acpjjs:Manifest_no is loaded into REC_ID.
      -- DN#10516:Added orig_invoice to lot_id. If no route,use route
      --          from MANIFESTS. Put returned_prod_id to CMT for W10
      --          reason code. Added order_line_id.
      -- DN#10537: Added temperature

                BEGIN


                    SELECT
                        COUNT(t.trans_id)
                    INTO
                        v_count
                    FROM
                        trans t,
                        returns_barcode rb,
                        returns r
                    WHERE
                            t.rec_id = i_manifest_number
                        AND
                            t.order_id = DECODE(
                                instr(
                                rtns_rec.obligation_no,
                                    'L'
                                ),
                                0,
                               rtns_rec.obligation_no,
                                substr(
                                    rtns_rec.obligation_no,
                                    1,
                                    instr(
                                        rtns_rec.obligation_no,
                                        'L'
                                    ) - 1
                                )
                            )
                        AND
                            t.prod_id = rtns_rec.prod_id
                        and t.prod_id = rb.prod_id
                        and rb.prod_id = r.prod_id
                        AND t.stop_no =rtns_rec.stop_no
                        and t.stop_no = rb.stop_no
                        and t.stop_no = r.stop_no
                        AND
                            t.reason_code = rtns_rec.return_reason_cd
                        and t.reason_code = rb.return_reason_cd
                        and t.reason_code = r.return_reason_cd
                        and r.barcode_ref_no = rb.barcode_ref_no
                        and rb.barcode =  rtns_rec.obligation_no
                        and rb.catchweight = t.weight
                        AND t.trans_type in ('RTX', 'RTN');  --xdock chnage for jira 3592



                /* 5/16/20 replace by above
                    SELECT
                        COUNT(*)
                    INTO
                        v_count
                    FROM
                        trans
                    WHERE
                            rec_id = i_manifest_number
                        AND
                            order_id = DECODE(
                                instr(
                                    rtns_rec.obligation_no,
                                    'L'
                                ),
                                0,
                                rtns_rec.obligation_no,
                                substr(
                                    rtns_rec.obligation_no,
                                    1,
                                    instr(
                                        rtns_rec.obligation_no,
                                        'L'
                                    ) - 1
                                )
                            )
                        AND
                            prod_id = rtns_rec.prod_id
                        AND
                            stop_no = rtns_rec.stop_no
                        AND
                            reason_code = rtns_rec.return_reason_cd
                        AND
                            trans_type = 'RTN';

                      */

                    SELECT
                        COUNT(*)
                    INTO
                        v_stc_count
                    FROM
                        trans
                    WHERE
                            rec_id = i_manifest_number
                        AND
                            trans_type = 'STC'
                        AND
                            stop_no = rtns_rec.stop_no;

                     pl_log.ins_msg(
                        'INFO',
                        'pl_sts_pod_interface_in',
                        'in pl_sts_pod_interface_in.p_sts_import before insert RTN to TRANS msg_id= '
                         || i_msg_id
                         || ' v_count = '
                         || TO_CHAR(v_count)
                         || ' v_stc_count = '
                         || TO_CHAR(v_stc_count),
                        sqlcode,
                        sqlerrm,
                        'ORDER PROCESSING',
                        'pl_sts_pod_interface_in.pod_create_rtn',
                        'u'
                    );




                    IF
                        v_count > 0 OR v_stc_count > 0
                    THEN
                        NULL;
                    ELSE  -- 4/7/20 add back and take out below line
			   --elsif ( (i_pod_cnt > 1 and i_td_cnt =0 ) or
			     --      (i_pod_cnt = 1 and i_rn_cnt >0 ) )then --10/25/19
			   --elsif ( i_rn_cnt >0 )then --10/13/19
                        INSERT INTO trans (
                            trans_id,
                            trans_type,
                            trans_date,
                            batch_no,
                            route_no,
                            stop_no,
                            order_id,
                            prod_id,
                            cust_pref_vendor,
                            rec_id,
                            weight,
                            temp,
                            qty,
                            uom,
                            reason_code,
                            lot_id,
                            order_type,
                            order_line_id,
                            returned_prod_id,
                            upload_time,
                            cmt,
                            user_id,
                            adj_flag
                        ) VALUES (
                            trans_id_seq.NEXTVAL,
                            decode(rtns_rec.xdock_ind, 'X', 'RTX','RTN'), -- xdock related chnage for jira 3592
                            SYSDATE,
                            '88',
                            nvl(
                                rtns_rec.route_no,
                                v_route
                            ),
                            rtns_rec.stop_no,
                            DECODE(
                                instr(
                                    rtns_rec.obligation_no,
                                    'L'
                                ),
                                0,
                                rtns_rec.obligation_no,
                                substr(
                                    rtns_rec.obligation_no,
                                    1,
                                    instr(
                                        rtns_rec.obligation_no,
                                        'L'
                                    ) - 1
                                )
                            ),
                            rtns_rec.prod_id,
                            rtns_rec.cust_pref_vendor,
                            i_manifest_number,
                            rtns_rec.catchweight,
                            rtns_rec.temperature,
                            rtns_rec.returned_qty,
                            rtns_rec.returned_split_cd,
                            rtns_rec.return_reason_cd,
                            v_orig_inv,
                            rtns_rec.rec_type,
                            rtns_rec.erm_line_id,
                            rtns_rec.returned_prod_id,
                            decode(rtns_rec.xdock_ind,'X', NULL,v_up_dt),
                            'Return created from STS.' || DECODE(
                                rtns_rec.return_reason_cd,
                                'W10',
                                ' Returned item #' || rtns_rec.returned_prod_id,
                                NULL
                            ),
                            'SWMS',
                            'A'
                        );

                        pl_log.ins_msg(
                            'INFO',
                            'pl_sts_pod_interface_in',
                            'in pl_sts_pod_interface_in.pod_create_rtn inserted to trans for RTN for rec_id='
                             || i_manifest_number
                             || ' stop '
                             || rtns_rec.stop_no
                             || ' route= '
                             || nvl(
                                rtns_rec.route_no,
                                v_route
                            )
                             || 'prod_id ='
                             || rtns_rec.prod_id,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in.pod_create_rtn',
                            'u'
                        );


                -- Update rtn_sent_ind to Y if the RTN trans is created

                        UPDATE returns
                            SET
                                rtn_sent_ind = 'Y',
                                pod_rtn_ind = 'S'
                        WHERE
                                manifest_no = i_manifest_number
                            AND
                                route_no = nvl(
                                    rtns_rec.route_no,
                                    v_route
                                )
                            AND
                                stop_no = rtns_rec.stop_no
                            AND
                                prod_id = rtns_rec.prod_id
                            AND
                                returned_qty = rtns_rec.returned_qty
                            AND
                                obligation_no = DECODE(
                                    instr(
                                        rtns_rec.obligation_no,
                                        'L'
                                    ),
                                    0,
                                    rtns_rec.obligation_no,
                                    substr(
                                        rtns_rec.obligation_no,
                                        1,
                                        instr(
                                            rtns_rec.obligation_no,
                                            'L'
                                        ) - 1
                                    )
                                )
                            AND
                                return_reason_cd = rtns_rec.return_reason_cd;

                    END IF;  -- v_count > 0 or v_stc_count > 0

                EXCEPTION
                    WHEN OTHERS THEN
                        l_success_flag := false;
                        message := 'Insert RTN into Trans Failed';
                        pl_log.ins_msg(
                            'FATAL',
                            'pl_sts_pod_interface_in',
                            message,
                            sqlcode,
                            sqlerrm,
                            'ORDER PROCESSING',
                            'pl_sts_pod_interface_in.pod_create_rtn',
                            'u'
                        );
                        raise;  --3/5/21

                END;

                IF
                    l_success_flag = true
                THEN
                    COMMIT;
                    v_rtn_count := v_rtn_count + 1;
                ELSE
                    ROLLBACK;
                END IF;  --l_success_flag = TRUE

            END LOOP;  -- RTNS_REC IN RTNS_CURSOR

            IF
                v_returns_count = v_rtn_count
            THEN
                rtn_process_flag := true;

	   --10/13/19
                pl_log.ins_msg(
                    'INFO',
                    'pl_sts_pod_interface_in',
                    'in pl_sts_pod_interface_in.pod_create_rtn before return RTN_process_flag= TRUE',
                    sqlcode,
                    sqlerrm,
                    'ORDER PROCESSING',
                    'pl_sts_pod_interface_in.pod_create_rtn',
                    'u'
                );

            ELSE
                rtn_process_flag := false;

	       -- 10/13/19
                pl_log.ins_msg(
                    'INFO',
                    'pl_sts_pod_interface_in',
                    'in pl_sts_pod_interface_in.pod_create_rtn before return RTN_process_flag= FALSE',
                    sqlcode,
                    sqlerrm,
                    'ORDER PROCESSING',
                    'pl_sts_pod_interface_in.pod_create_rtn',
                    'u'
                );

            END IF;  -- v_returns_count = v_RTN_count

        END IF;  -- status = 'CLS'

    END pod_create_rtn;

END pl_sts_pod_interface_in;
/
