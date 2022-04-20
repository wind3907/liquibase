/****************************************************************************
** File:
**    R47_DML_xdock_Jira3380_OP_site_1_build_pallets.sql
**
** Description:
**    Project: R1 Cross Docking  (Xdock)
**             R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
**
**    This script performs the DML for this card. which consists of:
**       - Adding syspar XDOCK_BREAK_FLOAT_ON_STOP_RNGE
**         Records are inserted into tables:
**            - SYS_CONFIG
**            - SYS_CONFIG_VALID_VALUES
**
**    -------------------------------------------
**    -- Syspar XDOCK_BREAK_FLOAT_ON_STOP_RNGE
**    -------------------------------------------
**    At Site 1 we want to control for the crossed docked pallets if the pallet is built
**    by stop or a combination of multiple stops.  A new syspar called
**    "XDOCK_BREAK_FLOAT_ON_STOP_RNGE" will control this.  The syspar is numeric
**    and the value designates how for the stops are apart before breaking
**    to a new float.
**    Examples: (all stops could fit in the same float)
**        Stops on the Cross Dock Route        Syspar Value    Float Stops
**        ---------------------------------------------------------------------------------------------------
**        1, 2, 3, 4                               1           Each stop will
**                                                             be on a separate flost
**
**        1, 2, 3, 4                               2           All the stops will be on the same float.
**
**        1,    3, 4                               2           Stop 1 will be on it's own float.
**                                                             Stop 3 and 4 will be on a different float.
**
**        1,    3, 4                               3           All the stops will be on the same float.
**
**        1, 2, 3, 4, 6, 8                         2           Stops 1, 2, 3 and 4 will be on the same float.
**                                                             Stop 6 will be on it's own float.
**                                                             Stop 8 will be on it's own float.
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    07/05/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
**                      Created.
**
**
****************************************************************************/


/********************************************************************
**    Insert the syspar(s)
********************************************************************/

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar XDOCK_BREAK_FLOAT_ON_STOP_RNGE
********************************************************************/
INSERT INTO sys_config
   (seq_no,
    application_func,
    config_flag_name, 
    config_flag_desc,
    config_flag_val,
    value_required,
    value_updateable,
    value_is_boolean,
    data_type,
    data_precision,
    data_scale,
    sys_config_list,
    validation_type,
    range_low,
    range_high,
    sys_config_help)
SELECT
   (SELECT MAX(seq_no) maxseq_no FROM sys_config ) + 1,
   'ORDER PROCESSING'                  application_func, 
   'XDOCK_BREAK_FLOAT_ON_STOP_RNGE'    config_flag_name,
   'Xdock Break Float on Stop Rnge'    config_flag_desc,
   '999'                               config_flag_val,      -- Initial value is 999 so practically speaking we will not break by stop
   'Y'                                 value_required,
   'Y'                                 value_updateable,
   'N'                                 value_is_boolean,
   'NUMBER'                            data_type,
   3                                   data_precision,
   NULL                                data_scale,
   'R'                                 sys_config_list,
   'RANGE'                             validation_type,
   1                                   range_low,
   999                                 range_high,
'Cross dock order at the fulfillment site break to a new float
--------------------------------------------------------------
This syspar controls how far apart the stops can be on Cross Dock orders at the fulfillment site 
before breaking to a new float.'
|| chr(10) || chr(10) ||
'***** This applies only at the fulfillment site *****'
|| chr(10) || chr(10) ||
'Examples:'
|| chr(10) || chr(10) ||
'A cross dock route has stops 1, 2, 3, 4 and 5 on five cross dock orders.
The total cube for all stops can fit on the same float.
If this syspar is set to 1 then each stop will be on a different float.
If this syspar is set to 2 then all stops will be on the same float.'
|| chr(10) || chr(10) ||
'A cross dock route has stops 1, 2, 3 and 8 on four cross dock order.
The total cube for all stops can fit on the same float.
If this syspar is set to 1 then each stop will be on a different float.
If this syspar is set to 2 then stops 1, 2 and 3 will be on the same float.  Stop 8 will be on a different float.
If this syspar is set to 5 then stops 1, 2 and 3 will be on the same float.  Stop 8 will be on a different float.
If this syspar is set to 6 then stops 1, 2, 3, and 8 will be on the same float.' sys_config_help
  FROM DUAL
 WHERE NOT EXISTS
      (SELECT 'x'
         FROM sys_config
        WHERE config_flag_name = 'XDOCK_BREAK_FLOAT_ON_STOP_RNGE')
/


COMMIT;

