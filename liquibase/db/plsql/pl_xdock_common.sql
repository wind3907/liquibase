CREATE OR REPLACE PACKAGE pl_xdock_common
AS
  /************************************************************************
  -- pl_xdock_common
  --
  -- Description:  Common Package for XDOCK functionality related to Launchpad
  --
  --
  -- Modification log: jira 3394
  --
  -- Date         Developer     Change
  -- ------------------------------------------------------------------
  -- 22-Jun-2021  vkal9662      Initial version.
  --
  -- 12-Jul-2021  mche6435      Add call message hub for staging out to staging in
  --                            communications.
  --
  -- 18-Aug-2021  pdas8114      Jira-3569, added prcocedure Get_xdock_route_status,
  --                              It returns status for fulfillment/last mile
  --
  -- 20-Aug-2021  mche6435      Add generate_parent_pallet_id.
  *************************************************************************/
  ----------------------
  -- Package constants
  ----------------------
  PACKAGE_NAME       CONSTANT swms_log.program_name%TYPE     := 'PL_XDOCK_COMMON';
  APPLICATION_FUNC   CONSTANT swms_log.application_func%TYPE := 'XDOCK';

  ---------------------------------
  -- function/procedure signatures
  ---------------------------------
  FUNCTION Get_batch_id
    RETURN VARCHAR2;

  PROCEDURE call_message_hub(
    i_route_no     IN route.route_no%TYPE,
    i_batch_id     IN VARCHAR2,
    i_stg_tbl_name IN all_tables.table_name%TYPE
  );
  
  PROCEDURE Get_xdock_route_status(
        i_route_no          IN route.route_no%TYPE,
      -- i_obligation_no     IN route.invoice_no%TYPE,
        i_cross_dock_type   IN ordm.cross_dock_type%TYPE,
       o_xdock_status  OUT xdock_order_xref.x_lastmile_status%TYPE
	   );

  FUNCTION generate_parent_pallet_id
  RETURN VARCHAR2;

  FUNCTION get_xdk_route_for_xsn_pallet (
    parent_pallet IN VARCHAR2,
    out_status OUT VARCHAR2
  ) RETURN VARCHAR2;

  FUNCTION is_route_selection_started (
      parent_pallet   IN          VARCHAR2,
      out_status      OUT         VARCHAR2
  ) RETURN BOOLEAN;
  --   ====================================end specs==========================================================
END pl_xdock_common;
/
CREATE OR REPLACE PACKAGE BODY pl_xdock_common
AS
  /************************************************************************
  -- pl_xdock_common
  --
  -- Description:  Common Package body for XDOCK functionality related to Launchpad
  --
  --
  -- Modification log: jira 3394
  --
  -- Date         Developer     Change
  -- ------------------------------------------------------------------
  -- 22-JUN-2021  vkal9662      Initial version.
  --
  *************************************************************************/
  FUNCTION Get_batch_id  RETURN VARCHAR2  IS
    /************************************************************************
    --  FUNCTION Get_batch_id
    --
    -- Description:  prepares batch_id for xdock staging tables
    --
    -- Return/output: Batch_id
    --
    -- Modification log: jira 3394
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 22-JUN-2021  vkal9662      Initial version.
    --
    *************************************************************************/
    l_batch_id VARCHAR2(9);
    o_batch_id VARCHAR2(14);
    l_opco_num VARCHAR2(6);
    l_msg swms_log.msg_text%TYPE;
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'GET_BATCH_ID';
  BEGIN
  
    BEGIN
    
      SELECT XDOCK_BATCH_SEQ.nextval INTO l_batch_id FROM dual;
      
      SELECT SUBSTR(ATTRIBUTE_VALUE,1, instr(ATTRIBUTE_VALUE,':')-1)
      INTO l_opco_num
      FROM maintenance b
      WHERE b.APPLICATION = 'SWMS'
      AND b.COMPONENT     = 'COMPANY'
      AND b.ATTRIBUTE     = 'MACHINE' ;
      o_batch_id         := l_opco_num||'-'||l_batch_id;
      
    EXCEPTION
    WHEN No_data_found THEN
      l_msg := 'No data found when deriving OpcoNumber in the Maintenance Table' ;
      pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      
      Return l_batch_id;
    WHEN OTHERS THEN
      l_msg := 'Encountered error when trying to derive OpcoNumber in the Maintenance Table';
      pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      
      Return  l_batch_id;
    END;
    
    RETURN o_batch_id;
    
  END Get_batch_id;
  
  /************************************************************************
  --
  --  PROCEDUE:     call_message_hub
  --
  --  Description:  Calls the message hub for cross database communication.
  --
  --                This assumes that the route given is a cross dock order.
  --
  --  Modification log: JIRA - OPCOF-3507
  --
  --  Date         Developer     Change
  --  ------------------------------------------------------------------
  --  08-JUL-2021  mche6435      Initial version (Ticket: Jira - OPCOF-3507).
  --
  *************************************************************************/
  PROCEDURE call_message_hub(
    i_route_no     IN route.route_no%TYPE,
    i_batch_id     IN VARCHAR2,
    i_stg_tbl_name IN all_tables.table_name%TYPE
  ) AS
    l_proc_name VARCHAR2(50) := 'call_message_hub';

    bad_msg_hub_response    EXCEPTION;

    l_site_from   ordm.site_from%TYPE;
    l_site_to     ordm.site_to%TYPE;

    l_msg_hub_response   PLS_INTEGER;
  BEGIN
    pl_log.ins_msg('DEBUG', l_proc_name,
      'Starting ' || l_proc_name
      || ', batch_id: ' || i_batch_id
      || ', route_no:: ' || i_route_no
      || ', staging table: ' || i_stg_tbl_name,
    sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    ---- Get site from and site to. There should only be 1.
    BEGIN
      SELECT DISTINCT site_from, site_to
      INTO l_site_from, l_site_to
      FROM ordm
      WHERE route_no = i_route_no;
    EXCEPTION
      WHEN TOO_MANY_ROWS THEN
        pl_log.ins_msg(
          'FATAL',
          l_proc_name,
          'More than one set of "Site From" and "Site To" was found with the same route_no. There should only be 1, route_no: ' || i_route_no,
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE;
      WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg(
          'FATAL',
          l_proc_name,
          'No data found in float where route_no: ' || i_route_no,
          sqlcode,
          sqlerrm,
          APPLICATION_FUNC,
          PACKAGE_NAME
        );
        RAISE;
    END;

    l_msg_hub_response := PL_MSG_HUB_UTLITY.insert_meta_header(
      i_batch_id,
      i_stg_tbl_name,
      l_site_from,
      l_site_to
    );

    IF l_msg_hub_response != 0 THEN
      RAISE bad_msg_hub_response;
    END IF;

    pl_log.ins_msg('DEBUG', l_proc_name, 'Ending ' || l_proc_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
    WHEN bad_msg_hub_response THEN
      pl_log.ins_msg(
        'FATAL',
        l_proc_name,
        'Bad response code from PL_MSG_HUB_UTLITY, Response Code: ' || l_msg_hub_response,
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        PACKAGE_NAME
      );
      RAISE;
    WHEN OTHERS THEN
      pl_log.ins_msg(
        'FATAL',
        l_proc_name,
        'Call to' || l_proc_name || 'failed, batch_id: ' || i_batch_id,
        sqlcode,
        sqlerrm,
        APPLICATION_FUNC,
        PACKAGE_NAME
      );
      RAISE;
  END call_message_hub;
  
  PROCEDURE Get_xdock_route_status(
        i_route_no          IN route.route_no%TYPE,
        i_cross_dock_type   IN ordm.cross_dock_type%TYPE,
       o_xdock_status  OUT xdock_order_xref.x_lastmile_status%TYPE
	   ) AS
    /************************************************************************
    --  FUNCTION Get_xdock_route_status
    --
    -- Description:  returns xdock route status from xdock_order_xref table
    --
    -- Return/output: xdock_status
    --
    -- Modification log: Jira-3569 Do Not Allow Route to Close if not ready and prevent xdock orders 
	--                             for Pick Adjustment on Catch-Weight and Deletion
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 11-AUG-2021  pdas8114      Initial version.
    -- 01-SEP-2021
    *************************************************************************/
    l_x_lastmile_status VARCHAR2(30);
	l_xdock_status   VARCHAR2(30);

    l_msg swms_log.msg_text%TYPE;
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'GET_XDOCK_ROUTE_STATUS';
    /* knha8378 changed on Oct 14, 2021 to use cursor so that the order by query NEW status first */
    CURSOR get_status IS
	 SELECT xdock_status
	  FROM xdock_order_xref xord, xdock_status_maintenance xsm
	 WHERE DECODE(i_cross_dock_type,'X' ,route_no_to, 'S',route_no_from ) = i_route_no --Jira#3651
	  AND xsm.status_type = DECODE(i_cross_dock_type,'X' ,'LASTMILE', 'S', 'FULLFILLMENT')
	  AND xsm.xdock_status = DECODE(i_cross_dock_type, 'X', xord.x_lastmile_status, 'S',xord.s_fullfillment_status)
      ORDER BY xsm.sort_by;

  BEGIN

    BEGIN
         open get_status;
         fetch get_status into l_xdock_status;
         if get_status%FOUND then
	    o_xdock_status := l_xdock_status;
	 else
	  	l_xdock_status := '';
      		l_msg := 'No data found when deriving status from xdock_order_xref' ;
      		pl_log.ins_msg('INFO', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
         end if;
         close get_status;
  

    EXCEPTION WHEN OTHERS THEN
	  l_xdock_status := '';
      l_msg := 'Encountered error when trying to derive status from xdock_order_xref';
      pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END;

  END Get_xdock_route_status;

  /*************************************************************************
    Function:
      generate_parent_pallet_id
    Description:
      Method to generate a parent pallet id

    Return Value:
      VARCHAR2 - The parent pallet id

    Designer    date      version
    mche6435    08/19/21  v1.0
  **************************************************************************/
  FUNCTION generate_parent_pallet_id
  RETURN VARCHAR2 AS
    l_func_name VARCHAR2(50) := 'generate_parent_pallet_id';

    l_parent_pallet_id  VARCHAR2(20);
  BEGIN
    pl_log.ins_msg('DEBUG', l_func_name, 'Starting ' || l_func_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);

    l_parent_pallet_id := pl_common.get_company_no || lpad(pl_common.f_get_new_pallet_id, 15, '0');

    pl_log.ins_msg('DEBUG', l_func_name, 'Ending ' || l_func_name, sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
    RETURN l_parent_pallet_id;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', l_func_name, 'Call to ' || l_func_name || ' failed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
      RAISE;
  END generate_parent_pallet_id;

  /*************************************************************************
    Function: get_xdock_route_no_given_xsn_plt
    Description: This funciton gives the relevent xdock route no 
    (outgoing route from site 2) that a received xsn pallet belongs to

    Return Value:
      VARCHAR2 - Site 2 Route No 

    Designer    date      version
    apri0734    25/01/22  v1.0
  **************************************************************************/
  FUNCTION get_xdk_route_for_xsn_pallet (
    parent_pallet IN VARCHAR2,
    out_status OUT VARCHAR2
  ) RETURN VARCHAR2 AS
    func_name           VARCHAR2(60) := 'pl_xdock_common.get_xdk_route_for_xsn_pallet';
    xdock_route_no      VARCHAR2(10) := '-1';
  BEGIN
    pl_text_log.ins_msg_async('INFO', func_name, 'Starting to find xdock route no for given parent_pallet_id: ' || parent_pallet, sqlcode, sqlerrm); 
    BEGIN
      SELECT route_no_to 
      INTO xdock_route_no
      FROM xdock_order_xref 
      WHERE order_id_to IN (
          SELECT order_id 
          FROM xdock_float_detail_in 
          WHERE float_no IN (
              SELECT float_no 
              FROM xdock_floats_in 
              WHERE parent_pallet_id = parent_pallet
          )
      )
      AND ROWNUM = 1;
      
      pl_text_log.ins_msg_async('INFO', func_name, 'Found xdock route no:' || xdock_route_no || ' for given parent_pallet_id: ' || parent_pallet, sqlcode, sqlerrm); 
      
      IF xdock_route_no IS NULL THEN
        pl_text_log.ins_msg_async('WARN', func_name, 'Error finding xdock route for given parent_pallet_id: ' || parent_pallet, sqlcode, sqlerrm);  
        out_status := 'FAILURE';
        xdock_route_no := '-1';
      END IF;
      RETURN xdock_route_no;
    END;
  EXCEPTION
    WHEN OTHERS THEN
    pl_text_log.ins_msg_async('WARN', func_name, 'Exception Raised while finding xdock route no for parent pallet: ' || parent_pallet, sqlcode, sqlerrm);
    out_status := 'FAILURE';
    RETURN xdock_route_no;
  END get_xdk_route_for_xsn_pallet;


  /*************************************************************************
    Function: is_route_selection_started
    Inputs : XSN Pallet number
    Description: This funciton tells if selection has started or not of
                 the route where the input xsn pallet belongs at site2
    Return Value: VARCHAR2 - TRUE or FALSE

    Designer    date      version
    apri0734    26/01/22  v1.0
  **************************************************************************/

  FUNCTION is_route_selection_started (
      parent_pallet   IN          VARCHAR2,
      out_status      OUT         VARCHAR2
  ) RETURN BOOLEAN AS
      func_name               VARCHAR2(60) := 'pl_xdock_common.is_route_selection_started';
      xdock_route_no          VARCHAR2(10);
      active_batch_no         VARCHAR2(13);
      number_of_sos_batches   NUMBER;
      sos_started             BOOLEAN := FALSE;
      FAILURE                 VARCHAR2(7) := 'FAILURE';

      CURSOR c_float_selection_batches IS
      SELECT DISTINCT(batch_no)
      FROM floats
      WHERE route_no = xdock_route_no
      AND pallet_pull = 'N';  -- N indicates that they are normal selection batches (not bulk or pallet pull)

      CURSOR c_bulk_pull_floats IS
      SELECT DISTINCT(float_no)
      FROM floats
      WHERE route_no = xdock_route_no
      AND pallet_pull != 'N';
  BEGIN
    xdock_route_no :=  get_xdk_route_for_xsn_pallet(parent_pallet, out_status);

    IF out_status = FAILURE THEN
        RETURN sos_started;
    END IF;

    BEGIN
        FOR selection_batch_rec in c_float_selection_batches LOOP BEGIN
            SELECT batch_no
            INTO active_batch_no
            FROM sos_batch
            WHERE batch_no = selection_batch_rec.batch_no
            AND status in ('A', 'C')
            AND ROWNUM = 1;

            IF active_batch_no is not null THEN
              pl_text_log.ins_msg_async('WARN', func_name, 'Found active or closed sos batch: '|| active_batch_no || ' for route: ' || xdock_route_no, NULL, NULL);
              out_status := 'SUCCESS';
              sos_started := TRUE;
              RETURN sos_started;
            END IF;

        EXCEPTION  --when no data found exception, do nothing. because we need to check all the batches coming from c_float_selection_batches cursor
        WHEN No_data_found THEN
            pl_text_log.ins_msg_async('INFO', func_name,'sos_batch: ' || selection_batch_rec.batch_no || ' is not active or closed' , sqlcode, sqlerrm);
        END;
        END LOOP;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        pl_text_log.ins_msg_async('WARN', func_name, 'No Active or closed SOS batches for xdock route: ' || xdock_route_no, NULL, NULL);
        pl_text_log.ins_msg_async('WARN', func_name, 'Checking if xdock route: ' || xdock_route_no || ' is all bulk pulls.', NULL, NULL);

        SELECT count(float_no)
        INTO number_of_sos_batches
        FROM floats
        WHERE route_no = xdock_route_no
        AND pallet_pull = 'N';    -- pallet_pull N indicates it a sos batch (Y or B indicates pallet pull or bulk pull)

        IF number_of_sos_batches = 0 THEN
            pl_text_log.ins_msg_async('WARN', func_name, 'xdock route: ' || xdock_route_no || 
            ' have only bulk pulls, so checking if any of these bulk pull batches have started', NULL, NULL);

            FOR blk_flt_rec in c_bulk_pull_floats LOOP BEGIN
                SELECT batch_no
                INTO active_batch_no
                FROM Batch
                WHERE (batch_no = 'FR' || blk_flt_rec.float_no   -- when pallet_pull is R, batches start with FR
                OR batch_no = 'FU' || blk_flt_rec.float_no)      -- when pallet_pyll is B, batches start with FU
                AND status in ('A', 'C')
                and ROWNUM = 1;

                IF active_batch_no is not null THEN
                  pl_text_log.ins_msg_async('WARN', func_name, 'Found active or closed batch: '|| active_batch_no || ' for route: ' || xdock_route_no, NULL, NULL);
                  out_status := 'SUCCESS';
                  sos_started := TRUE;
                  RETURN sos_started;
                END IF;
            EXCEPTION
            WHEN No_data_found THEN
                pl_text_log.ins_msg_async('INFO', func_name,'No any A or C status of bulk pull batches for route: ' || xdock_route_no , sqlcode, sqlerrm);
                sos_started := FALSE;
                RETURN sos_started;
            END;
            END LOOP;

            IF active_batch_no is null THEN
              pl_text_log.ins_msg_async('WARN', func_name, 'No any active or closed bulkpull batchs found for route: ' || xdock_route_no, sqlcode, sqlerrm);
              out_status := 'SUCCESS';
              sos_started := FALSE;
              RETURN sos_started;
            END IF;
        END IF;

      WHEN OTHERS THEN
        pl_text_log.ins_msg_async('WARN', func_name, 'Error selecting from SOS_BATCH table for xdock route: ' || xdock_route_no, sqlcode, sqlerrm);
        out_status := FAILURE;
        sos_started := FALSE;
        RETURN sos_started;
    END;
    RETURN sos_started;
  EXCEPTION
  WHEN OTHERS THEN
    pl_text_log.ins_msg_async('WARN', func_name, 'Error getting XDK route for XSN Pallet: ' || parent_pallet, sqlcode, sqlerrm);
    out_status := FAILURE;
    sos_started := FALSE;
    RETURN sos_started;
  END is_route_selection_started;

END pl_xdock_common;
/
CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_common FOR swms.pl_xdock_common;
GRANT EXECUTE ON swms.pl_xdock_common TO swms_user;
