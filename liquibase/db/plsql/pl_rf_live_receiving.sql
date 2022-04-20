SET ECHO OFF
SET SCAN OFF
SET SERVEROUTPUT ON SIZE UNLIMITED

/*******************************************************************************
** Package Specification
********************************************************************************
**  Package:      PL_RF_Live_Receiving
**
**  Description:  This package contains procedures and functions required for
**                the Live Receiving functionality.
**
**  Modification History:
**
**   Date       Designer  CRQ/Project Comments
**  ----------- --------- ----------- -------------------------------------------
**  01-SEP-2016 bgil6182              Initial version
**  12-APR-2017 jdha9548  Story#1300  Door_No scanned with PO, also made Insert_CHK_Trans as public function.
**  19-Mar-2018 Vkal9662  Jira 353    add po type TR in the selection criteria to enable Outside storage POs to be processed
**  22-Jul-2021 mcha1213  Jira 3524   assign user id to LR batch add FUNCTION Receiving_Begin_Batch
**  18-Aug-2021 pkab6563  Jira 3539   Added function Add_LP_to_PO() and related function
                                      Add_LP_to_PO_internal().
**  19-Aug-2021 mcha1213  Jira 3524   function Receiving_Begin_Batch change parameter i_Blind_Pallet_Id to i_Pallet_Id
**  02-Sep-2021 mcha1213  Jira 3524   return RF.STATUS_NO_LM_BATCH_FOUND for no batch exists in Receiving_Begin_Batch
**  16-Sep-2021 bgil6182  OPCOF-3497  Added i_Actual_Door_No RF argument to CheckIn_PO_LPN_List.
**  16-Sep-2021 bgil6182/ OPCOF-3496  Added i_Scan_Method2 and i_Scan_Type2 RF arguments to CheckIn_PO_LPN_List.
                pkab6563
**  27-Sep-2021 bgil6182  OPCOF-3541  Whenever an OpCo receives a pallet, collect an OSD reason code from the RF anytime the
                                      actual quantity received differs from the expected/ordered quantity for the pallet.
**  21-Oct-2021 bgil6182  OPCOF-3541  Missed requirement added: Modify bulk queries for LR_LPN_List_Rec type. This provides
                                      the current setting for the OSandD reason during live receiving to follow the pallet
                                      through the put away process.
**  10-Nov-2021 bgil6182              Ensured that all SOAP services log their invocations to the RF_LOG table.
**
**  12-Jan-2022 mcha1213  OPCOF-3929  Modify receiving_begin_batch
**  26-Jan-2022 mcha1213  			  Modify retrieve_po_lpn_list and add user schedule class flag
**  03-Feb-2022 mcha1213  OPCOF-3941  Per Kiet's instruction Take out and replace with 'and'
**                                    modify checkin_po_lpn_list_internal function for bad location per Brian Bent and Jim's email
**                					  add Labor Management Flag validation
*******************************************************************************/

CREATE OR REPLACE PACKAGE SWMS.PL_RF_Live_Receiving AS

  SUBTYPE   Server_Status   IS  PLS_INTEGER;
  SUBTYPE   Tracking_Flag   IS  VARCHAR2(1);

  G_RF_Date_Format        CONSTANT  VARCHAR2(20) := RF.Serialized_Date_Pattern;

-- Enumerated values for i_Run_Status

  SUBTYPE   RF_Start_Status IS  PLS_INTEGER;

  RF_Status_New           CONSTANT  RF_Start_Status := 0 ;
  RF_Status_Checked       CONSTANT  RF_Start_Status := 1 ;
  RF_Status_Putaway       CONSTANT  RF_Start_Status := 2 ;

  l_error_code            VARCHAR2(4000);
  l_error_msg             VARCHAR2(4000);
--
-- This function is called directly from an RF client via SOAP web service
--
  FUNCTION Retrieve_PO_LPN_List ( i_RF_Log_Init_Record    IN      RF_Log_Init_Record            /* Input: RF device initialization record */
                                , i_ERM_Id                IN      VARCHAR2                      /* Input: Purchase Order ID */
                                , i_Scan_Method           IN      VARCHAR2                      /* Input: (S)can or (K)eyboard */
                                , i_Door_No                  IN   VARCHAR2   DEFAULT NULL       /* Input: Door Number */
                                , o_UPC_Scan_Function        OUT  VARCHAR2                      /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
                                , o_Overage_Flg              OUT  VARCHAR2                      /* Output: RECEIVING.OVERAGE_FLG SysPar */
                                , o_Key_Weight_In_RF_Rcv     OUT  VARCHAR2                      /* Output: RECEIVING.KEY_WEIGHT_IN_RF_RCV SysPar */
                                , o_Load_No                  OUT  VARCHAR2                      /* Output: ERM.LOAD_NO associated with i_ERM_Id */
                                , o_Detail_Collection        OUT  LR_PO_List_Obj )
  RETURN RF.Status ;

--
-- This function is called directly from an RF client via SOAP web service
--
  FUNCTION CheckIn_PO_LPN_List( i_RF_Log_Init_Record     IN     RF_Log_Init_Record  /* Input:  RF device initialization record */
                              , i_Pallet_Id              IN     VARCHAR2            /* Input:  Unique pallet identifier */
                              , i_Qty_Received           IN     NUMBER              /* Input:  Actual item count received */
                              , i_Lot_Id                 IN     VARCHAR2            /* Input:  Lot Identification */
                              , i_Exp_Date               IN     VARCHAR2            /* Input:  Sysco Expiration Date, Format: MMDDYY */
                              , i_Mfg_Date               IN     VARCHAR2            /* Input:  Manufacturer's Expiration Date, Format: MMDDYY */
                              , i_Date_Override          IN     VARCHAR2
                              , i_Temp                   IN     NUMBER              /* Input:  Collected Temperature */
                              , i_Clam_Bed_Num           IN     VARCHAR2            /* Input:  Clam Bed Number */
                              , i_Harvest_Date           IN     VARCHAR2            /* Input:  Clam Harvest Date, Format: MMDDYY */
                              , i_TTI_Value              IN     VARCHAR2            /* Input:  TTI Value */
                              , i_Cryovac_Value          IN     VARCHAR2            /* Input:  CryoVac Value */
                              , i_Run_Status             IN     RF_Start_Status     /* Input:  LP status for RF at start of operation,
                                                                                               should sync with LR_LPN_List_Rec.Status
                                                                                               unless updated by multi-user on PO */
                              , i_Total_Weight           IN     NUMBER              /* Input:  Total PO/Item Weight */
                              , i_Weight_Override        IN     VARCHAR2            /* Input:  Total Weight doesn't pass validation, but the receiver
                                                                                               has validated and is forcing data entry */
                              , i_New_Pallet_Id          IN     VARCHAR2            /* Input:  New unique pallet identifier (Used for blind LR) */
                              , i_New_Pallet_Scan_Method IN     VARCHAR2            /* Input:  Was blind pallet (S)canned or (K)eyed */
                              , i_Actual_Door_No         IN     VARCHAR2            /* Input:  Actual door used for the pallet receive */                 -- OPCOF-3497
                              , i_Scan_Method2           IN     VARCHAR2            /* Input:  Scan Method (K{eyboard}, S{can}) for trans.scan_method2 */ -- OPCOF-3496
                              , i_Scan_Type2             IN     VARCHAR2            /* Input:  Scan Type (UPC/MfgId/Descr) for trans.scan_type2 */        -- OPCOF-3496
                              , i_OSD_Reason_Cd          IN     VARCHAR2            /* Input:  Reason "expected vs received LPN qty" differ */            -- OPCOF-3541
                              , o_Dest_Loc                  OUT VARCHAR2            /* Output: Allocated destination location */
                              , o_LP_Print_Count            OUT PLS_INTEGER         /* Output: Number of license plates to print per pallet */
                              , o_Qty_Max_Overage           OUT PLS_INTEGER         /* Output: Maximum overage allowed for this PO item */
                              , o_Expiration_Warn           OUT Server_Status       /* Output: Expiration exceeded warning (whether EXP_DATE or MFG_DATE) */
                              , o_Harvest_Warn              OUT Server_Status       /* Output: Harvest exceeded warning */
                              , o_UPC_Scan_Function         OUT VARCHAR2            /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
                              , o_Overage_Flg               OUT VARCHAR2            /* Output: RECEIVING.OVERAGE_FLG SysPar */
                              , o_Key_Weight_In_RF_Rcv      OUT VARCHAR2            /* Output: RECEIVING.KEY_WEIGHT_IN_RF_RCV SysPar */
                              , o_Detail_Collection         OUT LR_PO_List_Obj      /* Output: List of PO's within the same truck load */
                              )
  RETURN RF.Status ;

  FUNCTION Validate_Exp_Date( i_Exp_Date_Trk  IN OUT Tracking_Flag
                            , i_Exp_Date      IN     DATE )
  RETURN Server_Status ;

  FUNCTION Validate_Mfr_Date( i_Mfr_Date_Trk  IN OUT  Tracking_Flag
                            , i_Mfr_Date      IN      DATE )
  RETURN Server_Status;

  FUNCTION Validate_Harvest_Date( i_Clam_Bed_Trk  IN OUT  VARCHAR2
                                , i_Harvest_Date  IN      DATE)
  RETURN Server_Status;

  FUNCTION Check_Exp_Date( i_Pallet_Id         IN     putawaylst.pallet_id%TYPE
                         , i_Exp_Date_Trk      IN OUT Tracking_Flag
                         , i_Exp_Date          IN     DATE
                         , i_Cust_Shelf_Life   IN     pm.cust_shelf_life%TYPE   DEFAULT 0 -- Minimum days a customer requires a product to live on their shelf before expiration
                         , i_Sysco_Shelf_Life  IN     pm.sysco_shelf_life%TYPE  DEFAULT 0 -- Maximum additional days a product can live on the warehouse shelf before customer shelf life
                                                                                          -- RULE implemented in data configuration: any product with a customer shelf life MUST have a non-zero Sysco shelf life
                         , i_Mfr_Shelf_Life    IN     pm.mfr_shelf_life%TYPE    DEFAULT 0 -- Total days that a manufacturer will guarantee for their product life
                         , i_Date_Override     IN     VARCHAR2 DEFAULT 'N'
                         )
  RETURN Server_Status;

  FUNCTION Check_Mfr_Date( i_Pallet_Id      IN     putawaylst.pallet_id%TYPE
                         , i_Mfr_Date_Trk   IN OUT Tracking_Flag
                         , i_Mfr_Date       IN     DATE
                         , i_Mfr_Shelf_Life IN     pm.mfr_shelf_life%TYPE   -- Total days that a manufacturer will guarantee for their product life
                         , i_Date_Override  IN     VARCHAR2 DEFAULT 'N'
                         , o_Exp_Date       OUT DATE
                         )
  RETURN Server_Status;
  FUNCTION Within_Warning_Period( i_Exp_Date_Trk  IN  Tracking_Flag   DEFAULT NULL
                                , i_Exp_Date      IN  DATE )
  RETURN BOOLEAN;

  FUNCTION Check_Finish_Good_PO( i_ERM_Id IN VARCHAR2)
  RETURN CHAR;

  FUNCTION Insert_CHK_Trans( i_Pallet_ID              IN  VARCHAR2
                           , i_New_Pallet_Id          IN  VARCHAR2
                           , i_New_Pallet_Scan_Method IN  VARCHAR2
                           , i_Scan_Method2           IN  VARCHAR2
                           , i_Scan_Type2             IN  VARCHAR2
                           )
  RETURN Server_Status;

  FUNCTION PostChkUpdate( i_Pallet_Id      IN  VARCHAR2
                        , i_New_Status     IN  VARCHAR2 DEFAULT NULL
                        , i_New_Pallet_Id  IN  VARCHAR2 DEFAULT NULL
                        , i_Actual_Door_No IN  VARCHAR2
                        )
  RETURN Server_Status;

--
-- This function is called directly from an RF client via SOAP web service
--
  FUNCTION Add_LP_To_PO( i_RF_Log_Init_Record  IN   RF_Log_Init_Record           
                       , i_PO_Id               IN   putawaylst.rec_id%TYPE                             
                       , i_Prod_Id             IN   pm.prod_id%TYPE
                       , i_Cust_Pref_Vendor    IN   pm.cust_pref_vendor%TYPE
                       , i_uom                 IN   putawaylst.uom%TYPE
                       , o_Pallet_Id           OUT  putawaylst.pallet_id%TYPE
                       , o_Detail_Collection   OUT  LR_PO_List_Obj)
  RETURN RF.Status;

  FUNCTION Add_LP_To_PO_Internal(i_PO_Id              IN   putawaylst.rec_id%TYPE                             
                               , i_Prod_Id            IN   pm.prod_id%TYPE
                               , i_Cust_Pref_Vendor   IN   pm.cust_pref_vendor%TYPE
                               , i_uom                IN   putawaylst.uom%TYPE
                               , o_Pallet_Id          OUT  putawaylst.pallet_id%TYPE
                               , o_Detail_Collection  OUT  LR_PO_List_Obj)
  RETURN RF.Status;
  
--
-- This function is called directly from an RF client via SOAP web service
--
  FUNCTION Receiving_Begin_Batch( i_RF_Log_Init_Record  IN     RF_Log_Init_Record  /* Input:  RF device initialization record */
                                , i_Pallet_Id           IN     VARCHAR2            /* Input:  pallet identifier */
                                )
  RETURN RF.Status ;
  
   ---------------------------------------------------------------------------
   -- m.c. 9/23/21
   -- Function:
   --    f_is_lr_active
   --
   -- Description:
   --    This function determines if returns putaway fork lift labor mgmt is active.
   ---------------------------------------------------------------------------
   FUNCTION f_is_lr_active
   RETURN VARCHAR2;  -- RETURN BOOLEAN;

END PL_RF_Live_Receiving;
/

SHOW ERRORS;

/*******************************************************************************
** Package Body
*******************************************************************************/
CREATE OR REPLACE PACKAGE BODY SWMS.PL_RF_Live_Receiving AS
--------------------------------------------------------------------------------
-- Package
--   PL_RF_Live_Receiving
--
-- Description
--   This package contains procedures and functions required for the Live
--   Receiving functionality.
--
-- Modification History
--
--   Date        Designer Comments
--  ----------- --------- ------------------------------------------------------
--  01-SEP-2016 bgil6182  Authored original version.
--------------------------------------------------------------------------------

  G_This_Package        CONSTANT  VARCHAR2(30 CHAR)     := $$PLSQL_UNIT ;

  G_Business_Function   CONSTANT  trans.cmt%TYPE        := 'Live Receiving';
  G_Key_RF_Device       CONSTANT  trans.batch_no%TYPE   := 99;

  G_Trx_Type_Check      CONSTANT  trans.trans_type%TYPE := 'CHK';
  G_Trx_Type_Check_Prod CONSTANT  trans.trans_type%TYPE := 'CHP';
  G_Trx_Type_New        CONSTANT  trans.trans_type%TYPE := 'NEW';

  G_Trk_Collected       CONSTANT  VARCHAR2(1)           := 'C';
  G_Trk_No              CONSTANT  VARCHAR2(1)           := 'N';
  G_Trk_Yes             CONSTANT  VARCHAR2(1)           := 'Y';

  G_Msg_Category        CONSTANT  VARCHAR2(30)          := PL_RCV_Open_PO_Types.CT_Application_Function;

  G_RCV_Option          CONSTANT  PLS_INTEGER           := 2;

  G_This_Load                     erm.load_no%TYPE      := NULL;
  G_This_PO                       erm.erm_id%TYPE       := NULL;
 
  G_Application_Func    CONSTANT  swms_log.application_func%TYPE := 'RECEIVING';

  G_This_Message                  VARCHAR2(4000 CHAR);    -- 7/22/21 mcha1213 add

  G_This_Application    CONSTANT  VARCHAR2(30 CHAR)     := 'RECEIVING' ;  -- 7/22/21 mcha1213 add
  TYPE T_TrxData IS RECORD
  ( Trans_Id          trans.trans_id%TYPE
  , Trans_Type        trans.trans_type%TYPE
  , Trans_Date        trans.trans_date%TYPE
  , User_Id           trans.user_id%TYPE
  , PO_Id             trans.rec_id%TYPE
  , Cust_Pref_Vendor  trans.cust_pref_vendor%TYPE
  , Prod_Id           trans.prod_id%TYPE
  , Pallet_Id         trans.pallet_id%TYPE
  , Qty               trans.qty%TYPE
  , Clam_Bed_No       trans.clam_bed_no%TYPE
  , Exp_Date          trans.exp_date%TYPE
  , Mfr_Date          trans.mfg_date%TYPE
  , Lot_Id            trans.lot_id%TYPE
  , TTI_Value         trans.tti%TYPE
  , Cryovac_Value     trans.cryovac%TYPE
  , Temp              trans.temp%TYPE
  , adj_flag          trans.adj_flag%TYPE
  , UOM               trans.uom%TYPE
  , Batch_No          trans.batch_no%TYPE
  , Reason_Code       trans.reason_code%TYPE
  , Alt_Trans_Id      trans.ref_pallet_id%TYPE
  , Scan_Method       trans.scan_method1%TYPE   /* RDC */
  , Scan_Method2      trans.scan_method2%TYPE   /* OpCo */
  , Scan_Type2        trans.scan_type2%TYPE     /* OpCo */
  );

  G_TrxData                       T_TrxData;

  EXC_DB_Locked_With_NoWait       EXCEPTION;
  EXC_DB_Locked_With_Wait         EXCEPTION;
  EXC_Parameter_Required          EXCEPTION;
  EXC_DB_Failure                  EXCEPTION;
  EXC_Unit_Test_Failed            EXCEPTION;

  PRAGMA EXCEPTION_INIT( EXC_DB_Locked_With_NoWait,    -54 );
  PRAGMA EXCEPTION_INIT( EXC_DB_Locked_With_Wait  , -30006 );
  PRAGMA EXCEPTION_INIT( EXC_Parameter_Required   , -20201 );
  PRAGMA EXCEPTION_INIT( EXC_DB_Failure           , -20202 );
  PRAGMA EXCEPTION_INIT( EXC_Unit_Test_Failed     , -20203 );


  PROCEDURE Initialize_Trans_Storage IS
  BEGIN
    G_TrxData.Trans_Id         := NULL;
    G_TrxData.Trans_Type       := NULL;
    G_TrxData.Trans_Date       := NULL;
    G_TrxData.User_Id          := NULL;
    G_TrxData.PO_Id            := NULL;
    G_TrxData.Cust_Pref_Vendor := NULL;
    G_TrxData.Prod_Id          := NULL;
    G_TrxData.Pallet_Id        := NULL;
    G_TrxData.Qty              := NULL;
    G_TrxData.Clam_Bed_No      := NULL;
    G_TrxData.Exp_Date         := NULL;
    G_TrxData.Mfr_Date         := NULL;
    G_TrxData.Lot_Id           := NULL;
    G_TrxData.TTI_Value        := NULL;
    G_TrxData.Cryovac_Value    := NULL;
    G_TrxData.Temp             := NULL;
    G_TrxData.Adj_Flag         := NULL;
    G_TrxData.UOM              := NULL;
    G_TrxData.Batch_No         := NULL;
    G_TrxData.Reason_Code      := NULL;
    G_TrxData.Alt_Trans_Id     := NULL;
    G_TrxData.Scan_Method      := NULL;
    G_TrxData.Scan_Method2     := NULL;
    G_TrxData.Scan_Type2       := NULL;
    RETURN;
  END Initialize_Trans_Storage;

  PROCEDURE Save_Trans_Id IS
  BEGIN
    G_TrxData.Trans_Id := Trans_Id_Seq.NextVal;
    RETURN;
  END Save_Trans_Id;

  PROCEDURE Save_Trans_Type( i_Trans_Type IN  trans.trans_type%TYPE ) IS
  BEGIN
    G_TrxData.Trans_Type := i_Trans_Type;
    RETURN;
  END Save_Trans_Type;

  PROCEDURE Save_Trans_Date( i_Trans_Date IN  trans.trans_date%TYPE ) IS
  BEGIN
    G_TrxData.Trans_Date := i_Trans_Date;
    RETURN;
  END Save_Trans_Date;

  PROCEDURE Save_User_Id( i_User_Id IN  trans.user_id%TYPE ) IS
  BEGIN
    G_TrxData.User_Id := i_User_Id;
    RETURN;
  END Save_User_Id;

  PROCEDURE Save_PO_Id( i_PO_Id IN  trans.rec_id%TYPE ) IS
  BEGIN
    G_TrxData.PO_Id := i_PO_Id;
    RETURN;
  END Save_PO_Id;

  PROCEDURE Save_Cust_Pref_Vendor( i_Cust_Pref_Vendor IN  trans.cust_pref_vendor%TYPE ) IS
  BEGIN
    G_TrxData.Cust_Pref_Vendor := i_Cust_Pref_Vendor;
    RETURN;
  END Save_Cust_Pref_Vendor;

  PROCEDURE Save_Prod_Id( i_Prod_Id IN  trans.prod_id%TYPE ) IS
  BEGIN
    G_TrxData.Prod_Id := i_Prod_Id;
    RETURN;
  END Save_Prod_Id;

  PROCEDURE Save_Pallet_Id( i_Pallet_Id IN  trans.pallet_id%TYPE ) IS
  BEGIN
    G_TrxData.Pallet_Id := i_Pallet_Id;
    RETURN;
  END Save_Pallet_Id;

  PROCEDURE Save_Qty( i_Qty IN  trans.qty%TYPE ) IS
  BEGIN
    G_TrxData.Qty := i_Qty;
    RETURN;
  END Save_Qty;

  PROCEDURE Save_Clam_Bed_No( i_Clam_Bed_No IN  trans.clam_bed_no%TYPE ) IS
  BEGIN
    G_TrxData.Clam_Bed_No := i_Clam_Bed_No;
    RETURN;
  END Save_Clam_Bed_No;

  PROCEDURE Save_Exp_Date( i_Exp_Date  IN  trans.exp_date%TYPE ) IS
  BEGIN
    G_TrxData.Exp_Date := i_Exp_Date;
    RETURN;
  END Save_Exp_Date;

  PROCEDURE Save_Mfr_Date( i_Mfr_Date IN  trans.mfg_date%TYPE ) IS
  BEGIN
    G_TrxData.Mfr_Date := i_Mfr_Date;
    RETURN;
  END Save_Mfr_Date;

  PROCEDURE Save_Lot_Id( i_Lot_Id IN  trans.lot_id%TYPE ) IS
  BEGIN
    G_TrxData.Lot_Id := i_Lot_Id;
    RETURN;
  END Save_Lot_Id;

  PROCEDURE Save_TTI_Value( i_TTI_Value IN  trans.tti%TYPE ) IS
  BEGIN
    G_TrxData.TTI_Value := i_TTI_Value;
    RETURN;
  END Save_TTI_Value;

  PROCEDURE Save_Cryovac_Value( i_Cryovac_Value IN  trans.cryovac%TYPE ) IS
  BEGIN
    G_TrxData.User_Id := i_Cryovac_Value;
    RETURN;
  END Save_Cryovac_Value;

  PROCEDURE Save_Temp( i_Temp IN  trans.temp%TYPE ) IS
  BEGIN
    G_TrxData.Temp := i_Temp;
    RETURN;
  END Save_Temp;

  PROCEDURE Save_Adj_Flag( i_Adj_Flag in trans.adj_flag%TYPE ) IS
  BEGIN
    G_TrxData.Adj_Flag := i_Adj_Flag;
    RETURN;
  END Save_Adj_Flag;

  PROCEDURE Save_UOM( i_UOM IN  trans.uom%TYPE ) IS
  BEGIN
    G_TrxData.UOM := i_UOM;
    RETURN;
  END Save_UOM;

  PROCEDURE Save_Batch_No( i_Batch_No IN  trans.batch_no%TYPE ) IS
  BEGIN
    G_TrxData.Batch_No := i_Batch_No;
    RETURN;
  END Save_Batch_No;

  PROCEDURE Save_Return_Code( i_Return_Code IN  trans.reason_code%TYPE ) IS
  BEGIN
    G_TrxData.Reason_Code := i_Return_Code;
    RETURN;
  END Save_Return_Code;

  PROCEDURE Save_Alt_Trans_Id( i_Alt_Trans_Id IN  trans.ref_pallet_id%TYPE ) IS
  BEGIN
    G_TrxData.Alt_Trans_Id := i_Alt_Trans_Id;
    RETURN;
  END Save_Alt_Trans_Id;

  PROCEDURE Save_Scan_Method( i_Scan_Method IN  trans.scan_method1%TYPE ) IS
  BEGIN
    G_TrxData.Scan_Method := i_Scan_Method;
    RETURN;
  END Save_Scan_Method;

  PROCEDURE Save_Scan_Method2( i_Scan_Method IN  trans.scan_method2%TYPE ) IS
  BEGIN
    G_TrxData.Scan_Method2 := i_Scan_Method;
    RETURN;
  END Save_Scan_Method2;

  PROCEDURE Save_Scan_Type2( i_Scan_Type IN  trans.scan_type2%TYPE ) IS
  BEGIN
    G_TrxData.Scan_Type2 := i_Scan_Type;
    RETURN;
  END Save_Scan_Type2;

--------------------------------------------------------------------------------
-- Function
--   CountCollectionObjects
--
-- Description
--   This function will generate a string showing the number of POs in the collection
--   and summation counts of the number of items, pallets and UPCs in the underlying
--   tables in the collection. This is meant as a way to determine whether the collection
--   has changed in counts after on-demand pallets may have been added to what is
--   represented in the PUTAWAYLST table.
--
-- Parameters
--    Parameter Name         Data Type      Description
--
--  Input:
--    i_PO_Collection        LR_PO_List_Obj Table structure of one or more POs in a load,
--                                          items in each PO, pallets in each item, and
--                                          UPCs in each item.
--
--  Output:
--    CountCollectionObjects VARCHAR2       Count of objects in the table structure
--
-- Modification History
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 11/10/2021 bgil6182  Authored original version.
--------------------------------------------------------------------------------
  FUNCTION CountCollectionObjects( i_PO_Collection IN LR_PO_List_Obj ) RETURN VARCHAR2 IS
    l_outstring   VARCHAR2(1000 CHAR);
    l_num_po      NATURAL := 0;
    l_num_item    NATURAL := 0;
    l_num_pallet  NATURAL := 0;
    l_num_upc     NATURAL := 0;
  BEGIN
    IF i_PO_Collection IS NOT NULL THEN
      l_num_po := i_PO_Collection.PO_Table.COUNT;
      IF ( l_num_po > 0 ) THEN
        FOR po IN i_PO_Collection.PO_Table.FIRST .. i_PO_Collection.PO_Table.LAST LOOP
          l_num_item   := l_num_item   + i_PO_Collection.PO_Table(po).Item_Table.COUNT;
          IF ( l_num_item > 0 ) THEN
            FOR item IN i_PO_Collection.PO_Table(po).Item_Table.FIRST .. i_PO_Collection.PO_Table(po).Item_Table.LAST LOOP
              l_num_pallet := l_num_pallet + i_PO_Collection.PO_Table(po).Item_Table(item).LPN_Table.COUNT;
              l_num_upc    := l_num_upc    + i_PO_Collection.PO_Table(po).Item_Table(item).UPC_Table.COUNT;
            END LOOP;
          END IF;
        END LOOP;
      END IF;
    END IF;

    l_outstring := TO_CHAR( l_num_po ) || ' PO';
    IF l_num_po > 1 THEN
      l_outstring := l_outstring || 's';
    END IF;
    IF l_num_po > 0 THEN
      l_outstring := l_outstring || ', ' || TO_CHAR( l_num_item ) || ' Item';
      IF l_num_item > 1 THEN
        l_outstring := l_outstring || 's';
      END IF;
      IF l_num_item > 0 THEN
        l_outstring := l_outstring || ', ' || TO_CHAR( l_num_pallet ) || ' Pallet';
        IF l_num_pallet > 1 THEN
          l_outstring := l_outstring || 's';
        END IF;
        l_outstring := l_outstring || ', ' || TO_CHAR( l_num_upc    ) || ' UPC';
        IF l_num_pallet > 1 THEN
          l_outstring := l_outstring || 's';
        END IF;
      END IF;
    END IF;

    RETURN l_outstring;
  END CountCollectionObjects;

--------------------------------------------------------------------------------
--  Function
--    get_Erm_Type
--
--  Description
--    This function will return the ERM_TYPE of the PO.
--------------------------------------------------------------------------------
  FUNCTION get_Erm_Type(i_erm_id IN VARCHAR2)
  RETURN VARCHAR2
  IS
    l_erm_type erm.erm_type%TYPE;
    This_Function   CONSTANT  VARCHAR2(30 CHAR)  := 'get_Erm_Type';
  BEGIN

    IF Check_Finish_Good_PO(i_erm_id) = 'Y' THEN
      pl_log.ins_msg('INFO', This_Function, 'Erm_Type: FG', sqlcode, sqlerrm);
      return 'FG';

    ELSE
      SELECT erm_type INTO l_erm_type
      FROM erm
      WHERE erm_id = i_erm_id;
      pl_log.ins_msg('INFO', This_Function, 'Erm_Type: ' || l_erm_type, sqlcode, sqlerrm);

      return l_erm_type;

    END IF;
  END get_Erm_Type;

--------------------------------------------------------------------------------
-- Function
--   Get_Max_Overage
--
-- Description
--   This function will determine, for the specified product/item on the
--   Purchase Order (PO), the maximum allowable splits quantity (according to
--   system parameter settings) that can be allowed to be received as a
--   variation from the expected quantity. It supports multi-user mode and
--   will include additions/reductions entered on the same item from another
--   receiver on the same truck/load.
--
-- Parameters
--    Parameter Name        Data Type       Description
--
--  Input:
--    i_PO_Id               VARCHAR2        Purchase Order ID
--    i_Prod_Id             VARCHAR2        Product ID
--    i_Cust_Pref_Vendor    VARCHAR2        "Customer Preferred" Vendor
--    i_Pallet_Id           VARCHAR2        Pallet ID
--    i_Overage_Rule        VARCHAR2        'U' = Overage is unlimited
--                                          'P' = Overage cannot exceed one pallet
--                                          'T' = Overage cannot exceed one TI (pallet layer)
--                                          'N' = No overage allowed
--
--  Output:
--    o_Pallet_Limit        PLS_INTEGER     Total product splits per pallet
--    o_Qty_Allowed         PLS_INTEGER     Maximum allowable splits that can be
--                                          accepted for this product for a
--                                          given pallet. This value is based on
--                                          the OVERAGE_FLG system parameter:
--                                          Supported values:
--                                            N - No overages allowed
--                                            T - TI (pallet layer)
--                                            P - Pallet
--                                            U - Unlimited, any amount over
--
--RETURNs:
--      RF_Status           RF.Status       Status of function call. Possible
--                                          values are:
--      RF.Status_Normal    : Normal, successful completion.
--      RF.Status_Inv_ProdId: This item could not be located for this PO.
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 10/18/2016 bgil6182  Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Get_Max_Overage( i_PO_Id             IN     erm.erm_id%TYPE                 /* Input: Purchase Order id */
                          , i_Prod_Id           IN     erd.prod_id%TYPE                /* Input: Item/Product id */
                          , i_Cust_Pref_Vendor  IN     erd.cust_pref_vendor%TYPE       /* Input: "Customer Preferred" Vendor */
                          , i_Pallet_Id         IN     putawaylst.pallet_id%TYPE       /* Input: Pallet id */
                          , i_Overage_Rule      IN     sys_config.config_flag_val%TYPE /* Input: OVERAGE_FLG system parameter setting */
                          , o_Pallet_Limit         OUT NUMBER                          /* Output: Total product splits per pallet */
                          , o_Qty_Allowed          OUT NUMBER                          /* Output: Maximum allowable product splits per pallet */
                          )
  RETURN Server_Status IS
    This_Function       CONSTANT  VARCHAR2(30) := 'Get_Max_Overage';

    cases_per_tier                pm.ti%TYPE;
    cases_high                    pm.hi%TYPE;
    splits_per_case               pm.spc%TYPE;
    splits_per_tier               NUMBER;
    splits_per_pallet             NUMBER;
    splits_overage_limit          NUMBER;
    splits_ordered_qty            erd.qty%TYPE;
    splits_received_qty           erd.qty%TYPE;
    splits_adjusted_qty           NUMBER;
    lp_splits_expected_qty        putawaylst.qty_expected%TYPE;
    lp_splits_received_qty        putawaylst.qty_received%TYPE;
    lp_splits_adjusted_qty        NUMBER;
    splits_overage_left           NUMBER;

    This_Message                  VARCHAR2(2000 CHAR);
    This_Message2                 VARCHAR2(2000 CHAR);

    My_Status                     Server_Status  := PL_SWMS_Error_Codes.Normal ;
  BEGIN
    splits_overage_limit := 0;

    o_Pallet_Limit := 0;
    o_Qty_Allowed  := 0;

-- Get quantity ordered for the PO item
    BEGIN
      SELECT SUM( item.qty )
        INTO splits_ordered_qty
        FROM erd item
       WHERE item.erm_id           = i_PO_Id
         AND item.cust_pref_vendor = i_Cust_Pref_Vendor
         AND item.prod_id          = i_Prod_Id ;
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := 'Unable to fetch ordered item quantity for '
                     ||   'PO='               || i_PO_Id
                     || ', Cust_Pref_Vendor=' || i_Cust_Pref_Vendor
                     || ', Prod_Id='          || i_Prod_Id;
        l_error_code := sqlcode;
        l_error_msg := SUBSTR(SQLERRM, 1, 4000);
        pl_log.ins_msg( 'WARN', This_Function, This_Message  , l_error_code, l_error_msg);
        My_Status    := PL_SWMS_Error_Codes.Inv_ProdId;
    END;

-- If no errors, then calculate sum of quantities received so far for the PO item
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
      BEGIN
        SELECT SUM( pal.qty_received )
          INTO splits_received_qty
          FROM putawaylst pal
         WHERE pal.rec_id           = i_PO_Id
           AND pal.cust_pref_vendor = i_Cust_Pref_Vendor
           AND pal.prod_id          = i_Prod_Id ;
      EXCEPTION
        WHEN OTHERS THEN
          This_Message := 'Unable to fetch received item quantity for '
                       ||   'PO='               || i_PO_Id
                       || ', Cust_Pref_Vendor=' || i_Cust_Pref_Vendor
                       || ', Prod_Id='          || i_Prod_Id;
          l_error_code := sqlcode;
          l_error_msg := SUBSTR(SQLERRM, 1, 4000);
          pl_log.ins_msg( 'WARN', This_Function, This_Message  , l_error_code, l_error_msg);
          My_Status    := PL_SWMS_Error_Codes.Inv_ProdId;
      END;
    END IF;

-- If no errors, then get quantity expected and received for the pallet item
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
      BEGIN
        SELECT pal.qty_expected
             , pal.qty_received
          INTO lp_splits_expected_qty
             , lp_splits_received_qty
          FROM putawaylst pal
         WHERE pal.rec_id           = i_PO_Id
           AND pal.cust_pref_vendor = i_Cust_Pref_Vendor
           AND pal.prod_id          = i_Prod_Id
           AND pal.pallet_id        = i_Pallet_Id ;
      EXCEPTION
        WHEN OTHERS THEN
          This_Message := 'Unable to fetch expected and received pallet quantities for '
                       ||   'PO='               || i_PO_Id
                       || ', Cust_Pref_Vendor=' || i_Cust_Pref_Vendor
                       || ', Prod_Id='          || i_Prod_Id
                       || ', Pallet_Id='        || i_Pallet_Id;
          l_error_code := sqlcode; 
          l_error_msg := SUBSTR(SQLERRM, 1, 4000);
          pl_log.ins_msg( 'WARN', This_Function, This_Message  , l_error_code, l_error_msg);
          My_Status    := RF.STATUS_PALLET_NOT_FOUND;
      END;
    END IF;

-- If no errors, then determine item configuration
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
      BEGIN
        SELECT pm.ti
             , pm.hi
             , pm.spc
          INTO cases_per_tier
             , cases_high
             , splits_per_case
          FROM pm
         WHERE pm.prod_id = i_Prod_Id;
      EXCEPTION
        WHEN OTHERS THEN
          This_Message := 'Unable to fetch TI/HI/SPC quantities for '
                       || 'Prod_Id=' || i_Prod_Id;
          l_error_code := sqlcode;
          l_error_msg := SUBSTR(SQLERRM, 1, 4000);
          pl_log.ins_msg( 'WARN', This_Function, This_Message  , l_error_code, l_error_msg);
          My_Status    := PL_SWMS_Error_Codes.Inv_ProdId;
      END;
    END IF;

-- If no errors, then calculate splits per tier and splits per pallet
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
      splits_per_tier   := cases_per_tier * splits_per_case;
      splits_per_pallet := splits_per_tier * cases_high;
      o_Pallet_Limit    := splits_per_pallet;

-- Now, calculate split boundary based on the system parameter setting
      CASE i_Overage_Rule
        WHEN 'U' THEN splits_overage_limit := 1000000;            -- Unlimited
        WHEN 'P' THEN splits_overage_limit := splits_per_pallet;  -- One Pallet
        WHEN 'T' THEN splits_overage_limit := splits_per_tier;    -- One Tier
        ELSE          splits_overage_limit := 0;                  -- None
      END CASE;

      splits_adjusted_qty    := splits_ordered_qty     - splits_received_qty;
      lp_splits_adjusted_qty := lp_splits_expected_qty - lp_splits_received_qty;
      splits_overage_left    := splits_adjusted_qty    - lp_splits_adjusted_qty + splits_overage_limit;

      This_Message2 :=    'TI='                     || TO_CHAR( cases_per_tier )
                     || ', HI='                     || TO_CHAR( cases_high )
                     || ', SPC='                    || TO_CHAR( splits_per_case )
                     || ', splits_per_tier='        || TO_CHAR( splits_per_tier )
                     || ', splits_per_pallet='      || TO_CHAR( splits_per_pallet )
                     || ', splits_adjusted_qty='    || TO_CHAR( splits_adjusted_qty )
                     || ', lp_splits_adjusted_qty=' || TO_CHAR( lp_splits_adjusted_qty )
                     || ', splits_overage_left='    || TO_CHAR( splits_overage_left );

--      o_Qty_Allowed := MIN( splits_per_pallet, ( lp_splits_expected_qty + splits_overage_left ) );
      IF ( splits_per_pallet <= ( lp_splits_expected_qty + splits_overage_left ) ) THEN
        o_Qty_Allowed := splits_per_pallet;
      ELSE
        o_Qty_Allowed := ( lp_splits_expected_qty + splits_overage_left );
      END IF;
    END IF;

    IF ( My_Status <> PL_SWMS_Error_Codes.Normal ) THEN
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      This_Message := '( i_PO_Id='             || i_PO_Id
                   || ', i_Prod_Id='           || i_Prod_Id
                   || ': i_Cust_Pref_Vendor='  || i_Cust_Pref_Vendor
                   || ', i_Pallet_Id='         || i_Pallet_Id
                   || ', i_Overage_Rule='      || i_Overage_Rule
                   || ' ) = '                  || TO_CHAR( My_Status )
                   || ' (Return_Status).';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
    ELSE
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message2
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
      This_Message := '( i_PO_Id='             || i_PO_Id
                   || ', i_Prod_Id='           || i_Prod_Id
                   || ', i_Pallet_Id='         || i_Pallet_Id
                   || ': i_Cust_Pref_Vendor='  || i_Cust_Pref_Vendor
                   || ', i_Overage_Rule='      || i_Overage_Rule
                   || ', o_Pallet_Limit='      || TO_CHAR( o_Pallet_Limit )
                   || ', o_Qty_Allowed='       || TO_CHAR( o_Qty_Allowed )
                   || ' ) = '                  || TO_CHAR( My_Status )
                   || ' (Return_Status).';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
    END IF;

    RETURN( My_Status );
  END Get_Max_Overage;

--------------------------------------------------------------------------------
-- Function
--   Validate_Exp_Date
--
-- Description
--   This function will determine validity for the Expiration Date associated
--   with a given pallet item. The validity is determined by existence and range
--   checking.
--
--   Expiration Date-specific validation rules:
--     1. If tracking flag = Y then expiration date is required (cannot be NULL).
--     2. The expiration date MUST be in the future.
--
-- Parameters
--   Type   Name               Data Type     Description
--   ------ ------------------ ------------- -----------------------------------
--   In/Out i_Exp_Date_Trk     Tracking_Flag Boolean (Y/N) flag to determine whether
--                                           expiration date is mandatory.
--   Input  i_Exp_Date         DATE          Expiration date to be validated.
--
--   Return RF_Status          RF.Status     Return code/status of function call.
--                                           Complete status list in PL_Swms_Error_Codes.
--                                           Possible values returned:
--      Normal                    Expiration date is valid.
--      Invalid_Exp_Date          Expiration date is in the past or not provided
--      Data_Error                Oracle error occurred.
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 11/02/2016 bgil6182  Authored original version.
-- 01/03/2019 xzhe5043  Added a warning for invalid exp date GREATER than 10 YEARS
--------------------------------------------------------------------------------

  FUNCTION Validate_Exp_Date( i_Exp_Date_Trk  IN OUT Tracking_Flag
                            , i_Exp_Date      IN     DATE )
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30)  := 'Validate_Exp_Date';

    My_Status                 Server_Status;
    This_Message              VARCHAR2(2000);
  BEGIN
    My_Status      := PL_SWMS_Error_Codes.Normal ;
    i_Exp_Date_Trk := NVL( UPPER( i_Exp_Date_Trk ), G_Trk_No );

    -- If expiration date was already collected/validated, but user provided another
    -- expiration date value, then reset tracking flag to uncollected/unvalidated.
    IF ( i_Exp_Date_Trk = G_Trk_Collected AND i_Exp_Date IS NOT NULL ) THEN
      i_Exp_Date_Trk := G_Trk_Yes;
    END IF;

    -- If expiration date needs to be validated
    IF ( i_Exp_Date_Trk = G_Trk_Yes ) THEN

      -- If mandatory expiration date not provided OR expiration date is before today
      IF ( TRUNC( NVL( i_Exp_Date, SYSDATE-1 ) ) < TRUNC( SYSDATE ) ) THEN
        My_Status := PL_SWMS_Error_Codes.Invalid_Exp_Date ;
      END IF;

         -- If expiration date is GREATER than 10 YEARS from NOW
       If ( Trunc( Nvl( I_Exp_Date, Sysdate-1 ) ) > Add_Months(Sysdate, +(12 * 10))  ) Then
        My_Status := Pl_Swms_Error_Codes.Invalid_Exp_Date ;
      End If;

    END IF;

    RETURN( My_Status );
  EXCEPTION
    WHEN OTHERS THEN
      -- Got an oracle error.  Log a message and return error code.
      This_Message := '(i_Exp_Date_Trk=[' || NVL( UPPER( i_Exp_Date_Trk ), G_Trk_No )               || ']'
                   || ',i_Exp_Date=['     || NVL( TO_CHAR( i_Exp_Date, G_RF_Date_Format ), 'NULL' ) || ']'
                   || ')  Failed to validate expiration date.' ;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RETURN( PL_SWMS_Error_Codes.Data_Error );
  END Validate_Exp_Date;

--------------------------------------------------------------------------------
-- Function:
--   Validate_Mfr_Date
--
-- Description
--   This function will determine validity for the Manufacturer's expiration
--   date associated with a given pallet item. The validity is determined by
--   existence and range checking.
--
--   Manufacturer's Expiration Date-specific validation rules:
--     1. If tracking flag = Y then mfr expiration date is required (cannot be NULL).
--     2. The mfr expiration date MUST be in the future.
--
-- Parameters
--   Type   Name               Data Type     Description
--   ------ ------------------ ------------- -----------------------------------
--   In/Out i_Mfr_Date_Trk     Tracking_Flag Boolean (Y/N) flag to determine whether
--                                           manufacturer's expiration date is mandatory.
--   Input  i_Mfr_Date         DATE          Manufacturer's expiration date to be validated.
--
--   Return RF_Status          RF.Status     Return code/status of function call.
--                                           Complete status list in PL_Swms_Error_Codes.
--                                           Possible values returned:
--      Normal                    Manufacturer's expiration date is valid.
--      Invalid_Mfg_Date          Manufacturer's expiration date is in the past or not provided
--      Data_Error                Oracle error occurred.
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 11/02/2016 bgil6182  Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Validate_Mfr_Date( i_Mfr_Date_Trk  IN OUT  Tracking_Flag
                            , i_Mfr_Date      IN      DATE )
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30)  := 'Validate_Mfr_Date';

    My_Status                 Server_Status;
    This_Message              VARCHAR2(2000);
  BEGIN
    My_Status      := PL_SWMS_Error_Codes.Normal ;
    i_Mfr_Date_Trk := NVL( UPPER( i_Mfr_Date_Trk ), G_Trk_No );

    -- If manufactured date was already collected/validated, but user provided another
    -- manufactured date value, then reset tracking flag to uncollected/unvalidated.
    IF ( i_Mfr_Date_Trk = G_Trk_Collected AND i_Mfr_Date IS NOT NULL ) THEN
      i_Mfr_Date_Trk := G_Trk_Yes;
    END IF;

    -- If expiration date needs to be validated
    IF ( i_Mfr_Date_Trk = G_Trk_Yes ) THEN

      -- If mandatory manufactured date not provided OR manufactured date is after today
      IF ( TRUNC( NVL( i_Mfr_Date, SYSDATE+1 ) ) > TRUNC( SYSDATE ) ) THEN
        My_Status := PL_SWMS_Error_Codes.Invalid_Mfg_Date ;
      END IF;
    END IF;

    RETURN( My_Status );
  EXCEPTION
    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and return error code.
      This_Message := '(i_Mfr_Date_Trk=[' || NVL( UPPER( i_Mfr_Date_Trk ), G_Trk_No )               || ']'
                   || ',i_Mfr_Date=['     || NVL( TO_CHAR( i_Mfr_Date, G_RF_Date_Format ), 'NULL' ) || ']'
                   || ')  Failed to validate manufactured date.' ;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RETURN( PL_SWMS_Error_Codes.Data_Error );
  END Validate_Mfr_Date;

--------------------------------------------------------------------------------
-- Function:
--   Validate_Harvest_Date
--
-- Description
--   This function will determine validity for the clam Harvest date
--   associated with a given pallet item. The validity is determined by
--   existence and range checking.
--
-- Clam-Bed Harvest Date-specific validation rules:
--     1. If tracking flag = Y then harvest date is required (cannot be NULL).
--     2. The harvest date MUST be in the past
--
-- Parameters
--   Type   Name               Data Type     Description
--   ------ ------------------ ------------- -----------------------------------
--   In/Out i_Clam_Bed_Trk     Tracking_Flag Boolean (Y/N) flag to determine whether
--                                           harvest date is mandatory.
--   Input  i_Harvest_Date     DATE          Harvest date to be validated.
--
--   Return My_Status          Server_Status Return code/status of function call.
--                                           Complete status list in PL_Swms_Error_Codes.
--                                           Possible values returned:
--      Normal                    Harvest expiration date is valid.
--      Invalid_Hrv_Date          Harvest date is in the future or not provided
--      Data_Error                Oracle error occurred.
--
--   Harvest Date-specific validation rules:
--     1. The harvest date is required (cannot be NULL).
--     2. The harvest date MUST be in the past.
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 11/02/2016 bgil6182  Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Validate_Harvest_Date( i_Clam_Bed_Trk  IN OUT  VARCHAR2
                                , i_Harvest_Date  IN      DATE)
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30)  := 'Validate_Harvest_Date';

    My_Status                 Server_Status;
    This_Message              VARCHAR2(2000);
  BEGIN
    My_Status      := PL_SWMS_Error_Codes.Normal ;
    i_Clam_Bed_Trk := NVL( UPPER( i_Clam_Bed_Trk ), G_Trk_No );

    -- If harvest date was already collected/validated, but user provided another
    -- harvest date value, then reset tracking flag to uncollected/unvalidated.
    IF ( i_Clam_Bed_Trk = G_Trk_Collected AND i_Harvest_Date IS NOT NULL ) THEN
      i_Clam_Bed_Trk := G_Trk_Yes;
    END IF;

    -- If expiration date needs to be validated
    IF ( i_Clam_Bed_Trk = G_Trk_Yes ) THEN

      -- If mandatory manufactured date not provided OR manufactured date is after today
      IF ( TRUNC( NVL( i_Harvest_Date, SYSDATE-1 ) ) > TRUNC( SYSDATE ) ) THEN
        My_Status := PL_SWMS_Error_Codes.Invalid_Hrv_Date ;
      END IF;
    END IF;

    RETURN( My_Status );
  EXCEPTION
    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and return error code.
      This_Message := '(i_Clam_Bed_Trk=[' || NVL( UPPER( i_Clam_Bed_Trk ), G_Trk_No )                   || ']'
                   || ',i_Harvest_Date=[' || NVL( TO_CHAR( i_Harvest_Date, G_RF_Date_Format ), 'NULL' ) || ']'
                   || ')  Failed to validate harvest date.' ;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RETURN( PL_SWMS_Error_Codes.Data_Error );
  END Validate_Harvest_Date;
--------------------------------------------------------------------------------
-- Function:
--   Insert_RHB_Trans
--
-- Description
--   This function will Insert/Update Clam_bed_No and Harvest Date
--
-- Parameters
--   Type   Name               Data Type     Description
--   ------ ------------------ ------------- -----------------------------------
--   Input  i_pallet_id        VARCHAR2      Pallet Id
--
--   Input  i_Harvest_Date     DATE          Harvest date to be Inserted/Updated.
--
--   Input  i_Clam_Bed_Num     VARCHAR2      Clam Bed No
--
--   Input  i_Temp             NUMBER        Temperature.
--
--   Return My_Status          Server_Status Return code/status of function call.
--                                           Complete status list in PL_Swms_Error_Codes.
--                                           Possible values returned:
--      Normal                    Harvest date UPDATED successfully.
--      PUTAWAYLST_UPDATE_FAIL    failed to update putawaylst table
--      SEL_PUTAWAYLST_FAIL       failed to query putawaylst table
--      SEL_TRN_FAIL              failed to query trans table
--      SEL_SEQ_FAIL              falied to generate sequence
--      SEL_ERM_FAIL              failed to update ERM table
--      TRANS_INSERT_FAILED       failed to update/Insert on Trans table
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 02/02/2017 aalb7675  Authored original version.
--------------------------------------------------------------------------------
  FUNCTION Insert_RHB_Trans( i_pallet_id    IN  putawaylst.pallet_id%TYPE
                           , i_Harvest_Date IN  DATE
                           , i_Clam_Bed_Num IN  VARCHAR2
                           , i_Temp         IN  NUMBER )
    RETURN Server_Status IS
    This_Function CONSTANT  VARCHAR2(50) := 'Insert_RHB_Trans';
    l_tot_qty               putawaylst.qty_received%TYPE;
    l_trans_id              trans.trans_id%TYPE;
    l_po_seq_id             NUMBER;
    l_rec_date              erm.rec_date%TYPE;
    l_prod_id               putawaylst.prod_id%TYPE;
    l_cust_pref_vendor      putawaylst.cust_pref_vendor%TYPE;
    l_uom                   putawaylst.uom%TYPE;
    l_rec_id                putawaylst.rec_id%TYPE;
    My_Status               Server_Status  := PL_SWMS_Error_Codes.Normal ;
    log_message             VARCHAR2(2000);
    This_Message            VARCHAR2(4000);
    l_Exp_Date              DATE;
  BEGIN
    log_message := '( i_pallet_id=['    || NVL( i_pallet_id                                , 'NULL' ) || ']'
                || ', i_Exp_Date=['     || NVL( TO_CHAR( i_Harvest_Date, G_RF_Date_Format ), 'NULL' ) || ']'
                || ', i_Clam_Bed_Num=[' || NVL( i_Clam_Bed_Num                             , 'NULL' ) || ']'
                || ', i_Temp=['         || NVL( TO_CHAR( i_Temp )                          , 'NULL' ) || ']';
    BEGIN
      SELECT prod_id, cust_pref_vendor, uom, rec_id
        INTO l_prod_id, l_cust_pref_vendor, l_uom, l_rec_id
        FROM putawaylst
       WHERE pallet_id = i_pallet_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        This_Message := log_message || ')  SELECT of PUTAWAYLST for qty sum failed.' ;
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        RETURN( RF.Status_Sel_PutAwayLst_Fail );
    END;

    BEGIN
      SELECT trans_id
        INTO l_trans_id
        FROM trans
       WHERE rec_id = l_rec_id -- rec_id from putawaylst
         AND prod_id = l_prod_id
         AND cust_pref_vendor = l_cust_pref_vendor
         AND trans_type = 'RHB'
         AND uom = l_uom
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        This_Message := log_message || ')  SELECT of RHB transaction failed.' ;
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
    END;

 /* Get the total # of quantity (in splits) received for the item, */
 /* including multiple pallet IDs for an item */

    BEGIN
      SELECT TO_CHAR( SUM( NVL( qty_received, 0 ) ) )
        INTO l_tot_qty
        FROM putawaylst
       WHERE rec_id = l_rec_id
         AND prod_id = l_prod_id
         AND cust_pref_vendor = l_cust_pref_vendor
         AND uom = l_uom;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        This_Message := log_message || ')  SELECT of PUTAWAYLST for qty sum failed.' ;
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        RETURN( RF.Status_Sel_PutAwayLst_Fail );
    END;

    BEGIN
      SELECT lot_id
        INTO l_po_seq_id
        FROM trans
       WHERE prod_id = l_prod_id
         AND cust_pref_vendor = l_cust_pref_vendor
         AND TRUNC( exp_date ) = TRUNC( i_Harvest_Date )
         AND clam_bed_no = i_Clam_Bed_Num
         AND trans_type = 'RHB'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := log_message || ')  SELECT of RHB transaction PO sequence ID failed.' ;
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        BEGIN
          SELECT TO_CHAR( po_seq_id_seq.NEXTVAL )
            INTO l_po_seq_id
            FROM DUAL;
        EXCEPTION
          WHEN OTHERS THEN
            This_Message := log_message || ')  SELECT of PO next sequence failed.' ;
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => TRUE
                                , i_ProgramName => G_This_Package
                                );
            RETURN( RF.Status_Sel_Seq_Fail );
        END;
    END;

    BEGIN
      SELECT TRUNC( rec_date )
        INTO l_rec_date
        FROM erm
       WHERE erm_id = l_rec_id;
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := log_message || ')  SELECT of ERM for rec_date failed.' ;
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        RETURN( RF.Status_Sel_ERM_Fail );
    END;

    /* RHB transaction is found. Just update the transaction with the */
    /* latest information along with the found or generated PO */
    /* sequence ID */

    BEGIN
      SELECT Exp_Date
        INTO l_Exp_Date
        FROM Trans
       WHERE trans_id = l_trans_id
      FOR UPDATE OF Exp_Date WAIT 5;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        This_Message := log_message || ')  Select of ''RHB'' TRANS failed.' ;
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
      WHEN EXC_DB_Locked_With_NoWait OR
           EXC_DB_Locked_With_Wait   THEN
        This_Message := 'Failed to update Trans table for trans_id ' || TO_CHAR( l_trans_id )
                     || ' due to the pallet being locked by someone else.';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => FALSE
                            , i_ProgramName => G_This_Package
                            );
        RETURN( PL_SWMS_Error_Codes.Lock_PO );
    END;

    BEGIN
      UPDATE trans
         SET mfg_date    = l_rec_date
           , exp_date    = i_Harvest_Date
           , user_id     = USER
           , trans_date  = SYSDATE
           , clam_bed_no = i_clam_bed_num
           , uom         = l_uom
           , qty         = l_tot_qty
           , temp        = i_Temp
           , lot_id      = l_po_seq_id
           , batch_no    = 99
       WHERE trans_id = l_trans_id;
      IF SQL%NotFound THEN
        /* RHB transaction corresponding to the pallet ID is not found. Need */
        /* to insert a new transaction */
        BEGIN
          INSERT INTO trans( trans_id         , trans_type, trans_date
                           , rec_id           , user_id   , prod_id
                           , cust_pref_vendor , exp_date  , mfg_date
                           , clam_bed_no      , lot_id    , qty
                           , uom              , temp      , batch_no
                           , cmt )
            SELECT Trans_Id_Seq.NextVal, 'RHB'         , SYSDATE
                 , l_rec_id            , USER          , l_prod_id
                 , l_cust_pref_vendor  , i_Harvest_Date, TRUNC( l_rec_date )
                 , i_Clam_Bed_Num      , l_po_seq_id   , l_tot_qty
                 , l_uom               , i_Temp        , 99
                 , 'PO SEQ ID = LOT #, REC DAT = MFG DATE, HRVST DAT = EXP DATE'
              FROM DUAL;
        END;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := log_message || ')  Failed to update Trans table for trans_id ' || TO_CHAR( l_trans_id );
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        RETURN( RF.Status_Trans_Insert_Failed );
    END;
    RETURN( My_Status );
  END Insert_RHB_Trans;

  FUNCTION Insert_DTO_Trans( i_Pallet_ID IN  VARCHAR2, i_exp_date IN  DATE, i_mfr_date IN  DATE DEFAULT NULL)
    RETURN Server_Status
  IS
    This_Function CONSTANT  VARCHAR2(50) := 'Insert_DTO_Trans';
    This_Message            VARCHAR2(4000);
    l_prod_id               putawaylst.prod_id%TYPE;
    l_cust_pref_vendor      putawaylst.cust_pref_vendor%TYPE;
    l_rec_id                putawaylst.rec_id%TYPE;
    l_trans_type            trans.trans_type%TYPE := 'DTO';
    This_Status               Server_Status := PL_SWMS_Error_Codes.Normal;
  BEGIN
    SELECT prod_id, cust_pref_vendor, rec_id
          INTO l_prod_id, l_cust_pref_vendor,  l_rec_id
          FROM putawaylst
         WHERE pallet_id = i_pallet_id;

      INSERT INTO trans( trans_id         , trans_type, trans_date, user_id
                       , rec_id           , pallet_id , prod_id   , cust_pref_vendor
                       , qty ,        mfg_date   , exp_date  , batch_no, cmt )
                 SELECT Trans_Id_Seq.NextVal, l_trans_type , SYSDATE   , USER
                      , l_rec_id            , i_pallet_id  , l_prod_id , l_cust_pref_vendor
                      , G_TrxData.Qty, i_mfr_date, i_exp_date, 99 ,'Overrided EXP DATE'
                 FROM DUAL;

     This_Message := ' transaction ' || l_trans_type ||' successfully entered for Pallet# ' || i_Pallet_Id || '.';
     PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                         , i_ModuleName  => This_Function
                         , i_Message     => This_Message
                         , i_Category    => G_Msg_Category
                         , i_Add_DB_Msg  => FALSE
                         , i_ProgramName => G_This_Package
                         );
      RETURN PL_SWMS_Error_Codes.Normal;
  EXCEPTION
        WHEN OTHERS THEN
          This_Message := 'Failed to create ' || l_trans_type || ' transaction for Pallet ' || i_Pallet_Id || '.';
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => TRUE
                              , i_ProgramName => G_This_Package
                              );
          RETURN PL_SWMS_Error_Codes.Trans_Insert_Failed;
  END Insert_DTO_Trans;
------------------------------------------------------------------------------
-- Function:
--   Check_Exp_Date
--
-- Description
--   This function range checks the expiration date entered for a LP during
--   receiving check-in.
--
--  Expiration Date-specific validation rules:
--    1. The expiration date needs to be >= current date.
--
--   This function will determine validity for the expiration date
--   associated with a given pallet item. The validity is determined by
--   existence and range checking.
--
--   Expiration Date-specific validation rules:
--     1. If the expiration date is tracked then the expiration date is required (cannot be NULL).
--     2. If tracked, then the expiration date MUST be in the future.
--
-- Parameters
--   Type   Name               Data Type     Description
--   ------ ------------------ ------------- -----------------------------------
--   Input  i_Pallet_Id        VARCHAR2      Reference to an existing pallet. If
--                                           the Exp_Date_Trk column = 'Y'es, then
--                                           the Exp_Date_Trk column will be
--                                           updated to 'C'omplete.
--
--   Input  i_Exp_Date         DATE          Expiration date to be validated.
--
--   Return RF_Status          RF.Status     Return code/status of function call.
--                                           Complete status list in PL_Swms_Error_Codes.
--                                           Possible values returned:
--      Normal                    Harvest date is valid.
--      Invalid_Hrv_Date          Harvest date is in the future or not provided
--      Data_Error                Oracle error occurred.
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 11/02/2016 bgil6182  Authored original version.
--------------------------------------------------------------------------------
  FUNCTION Check_Exp_Date( i_Pallet_Id         IN     putawaylst.pallet_id%TYPE
                         , i_Exp_Date_Trk      IN OUT Tracking_Flag
                         , i_Exp_Date          IN     DATE
                         , i_Cust_Shelf_Life   IN     pm.cust_shelf_life%TYPE   DEFAULT 0 -- Minimum days a customer requires a product to live on their shelf before expiration
                         , i_Sysco_Shelf_Life  IN     pm.sysco_shelf_life%TYPE  DEFAULT 0 -- Maximum additional days a product can live on the warehouse shelf before customer shelf life
                                                                                          -- RULE implemented in data configuration: any product with a customer shelf life MUST have a non-zero Sysco shelf life
                         , i_Mfr_Shelf_Life    IN     pm.mfr_shelf_life%TYPE    DEFAULT 0 -- Total days that a manufacturer will guarantee for their product life
                         , i_Date_Override     IN     VARCHAR2                  DEFAULT 'N'
                         )
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30)  := 'Check_Exp_Date';
    This_Data_Item  CONSTANT  VARCHAR2(30)  := 'Expiration Date';

    This_Message              VARCHAR2(2000);
    My_Status                 Server_Status;
    My_Trk_Flag               Tracking_Flag;
    l_exp_date                putawaylst.exp_date%type;
  BEGIN
    My_Status      := PL_SWMS_Error_Codes.Normal ;
    i_Exp_Date_Trk := NVL( UPPER( i_Exp_Date_Trk ), G_Trk_No );

    -- If expiration date was already collected/validated, but user provided another
    -- expiration date value, then reset tracking flag to uncollected/unvalidated.
    IF ( i_Exp_Date_Trk = G_Trk_Collected AND i_Exp_Date IS NOT NULL ) THEN
      i_Exp_Date_Trk := G_Trk_Yes;
    END IF;

    -- If expiration date needs to be validated
    IF ( i_Exp_Date_Trk = G_Trk_Yes ) THEN

      My_Status := Validate_Exp_Date( i_Exp_Date_Trk, i_Exp_Date );

      -- If we passed basic validation, proceed to context validation
      IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN

        -- Business Rule: If product has non-zero customer and Sysco shelf lives defined, then...
        IF ( NVL( i_Sysco_Shelf_Life, 0 ) > 0 AND NVL( i_Cust_Shelf_Life, 0 ) > 0 ) THEN

          -- Verify that the expiration date has not exceeded the sum of today and both shelf lives (days)
          IF ( TRUNC( i_Exp_Date ) - TRUNC( SYSDATE ) ) <= ( i_Sysco_Shelf_Life + i_Cust_Shelf_Life ) THEN
            IF NVL( i_Date_Override, 'N' ) = 'N' THEN
              My_Status := PL_SWMS_Error_Codes.Sys_Cust_Warn;
              This_Message := This_Data_Item || ' falls outside of shelf lives, '
                           || 'Customer=('  || TO_CHAR( i_Cust_Shelf_Life )
                           || ') + Sysco=(' || TO_CHAR( i_Sysco_Shelf_Life )
                           || ').';
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                  , i_ModuleName  => This_Function
                                  , i_Message     => This_Message
                                  , i_Category    => G_Msg_Category
                                  , i_Add_DB_Msg  => FALSE
                                  , i_ProgramName => G_This_Package
                                  );
            ELSIF NVL( i_Date_Override, 'N' ) = 'Y' THEN
               My_Status := Insert_DTO_Trans (i_Pallet_Id, i_exp_date);
               This_Message := This_Data_Item || ' overrided for pallet# '||i_Pallet_Id ;
               PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            End IF;
          END IF;
        ELSIF ( NVL( i_Mfr_Shelf_Life, 0 ) > 0 ) THEN
          -- Either the Sysco or Customer shelf life (or both) were not defined.
          -- Now, check the the manufacturer's shelf life.
          IF ( ( TRUNC( i_Exp_Date ) - TRUNC( SYSDATE ) ) <= i_Mfr_Shelf_Life ) THEN

             IF NVL( i_Date_Override, 'N' ) = 'N' THEN
               My_Status := PL_SWMS_Error_Codes.Mfr_Shelf_Warn;
               This_Message := This_Data_Item || ' falls outside of shelf life, '
                         || 'Manufacturer=('  || TO_CHAR( i_Mfr_Shelf_Life )
                         || ').';
               PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
             ELSIF  NVL( i_Date_Override, 'N' ) = 'Y' THEN
               My_Status := Insert_DTO_Trans (i_Pallet_Id, i_exp_date);
               This_Message := This_Data_Item || ' overrided for pallet# '||i_Pallet_Id ;
               PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
             END IF;
         END IF;
--        -- Following validation not performed in Pro*C
--        ELSE
--          This_Message := This_Data_Item || ' tracking is enabled but product has no shelf lives defined'
--                       || ' for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
--          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
--                              , i_ModuleName  => This_Function
--                              , i_Message     => This_Message
--                              , i_Category    => G_Msg_Category
--                              , i_Add_DB_Msg  => FALSE
--                              , i_ProgramName => G_This_Package
--                              );
        END IF;

        -- Validation has passed, update the tracking flag as "collected"
        -- First, attempt an exclusive lock on the pallet.
        IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
          Save_Exp_Date( i_Exp_Date );
          BEGIN
            SELECT Exp_Date_Trk, Exp_Date
              INTO My_Trk_Flag, l_Exp_Date
              FROM putawaylst
             WHERE Pallet_Id = i_Pallet_Id
            FOR UPDATE OF Exp_Date_Trk, Exp_Date WAIT 5;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              This_Message := 'Specified pallet ' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                  , i_ModuleName  => This_Function
                                  , i_Message     => This_Message
                                  , i_Category    => G_Msg_Category
                                  , i_Add_DB_Msg  => FALSE
                                  , i_ProgramName => G_This_Package
                                  );
              My_Status := RF.STATUS_PALLET_NOT_FOUND ;
            WHEN EXC_DB_Locked_With_NoWait OR
                 EXC_DB_Locked_With_Wait   THEN
              This_Message := 'Failed to update ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                           || ' due to the pallet being locked by someone else.';
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                  , i_ModuleName  => This_Function
                                  , i_Message     => This_Message
                                  , i_Category    => G_Msg_Category
                                  , i_Add_DB_Msg  => FALSE
                                  , i_ProgramName => G_This_Package
                                  );
              My_Status := PL_SWMS_Error_Codes.Lock_PO ;
          END;

          -- If exclusive lock was received, then update the pallet.
          IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
            BEGIN
              UPDATE putawaylst
                 SET Exp_Date_Trk = G_Trk_Collected
                   , Exp_Date     = i_Exp_Date
               WHERE Pallet_Id = i_Pallet_Id;
            EXCEPTION
              WHEN OTHERS THEN
                This_Message := 'Failed to update ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id );
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => TRUE
                                    , i_ProgramName => G_This_Package
                                    );
                My_Status := PL_SWMS_Error_Codes.Update_Fail ;
            END;
          END IF;
        END IF;
      END IF;
    END IF;

    RETURN( My_Status );
  EXCEPTION
    WHEN OTHERS THEN
      -- Got an Oracle error.  Log a message and return error code.
      This_Message :=    '(i_Exp_Date_Trk=['     || NVL( UPPER( i_Exp_Date_Trk ), G_Trk_No )                    || ']'
                      || ',i_Exp_Date=['         || NVL( TO_CHAR( i_Exp_Date, 'MM/DD/YYYY HH24:MI:SS'), 'NULL') || ']'
                      || ',i_Cust_Shelf_Life=['  || NVL( TO_CHAR( i_Cust_Shelf_Life ), 'NULL')                  || ']'
                      || ',i_Sysco_Shelf_Life=[' || NVL( TO_CHAR( i_Sysco_Shelf_Life ), 'NULL')                 || ']'
                      || ',i_Mfr_Shelf_Life=['   || NVL( TO_CHAR( i_Mfr_Shelf_Life ), 'NULL')                   || ']'
                      || ')  Error checking the expiration date. Returning pl_swms_error_codes.data_error';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RETURN( PL_SWMS_Error_Codes.Data_Error );
  END Check_Exp_Date;

--------------------------------------------------------------------------------
-- Function:
--    Within_Warning_Period
--
-- Description:
--    This function is used during receiving to determine whether the
--    expiration of the pallet is within or beyond the warning period. The
--    warning period is defined by the EXPIR_WARN_DAYS system parameter.
--
-- Parameters:
--    i_Exp_Date_Trk - The expiration date tracking flag, default = FALSE
--    i_Exp_Date     - The expiration date to check.
--
-- Return Value:
--    TRUE           - The expiration date is within or beyond the warning period.
--    FALSE          - The expiration date is not yet within the warning period.
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - i_exp_date is null.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    -
--
-- Modification History:
--    Date       Designer Description
--    ---------- -------- ------------------------------------------------------
--    11/07/2016 bgil6182 Jim Gilliam authored.
--------------------------------------------------------------------------------

  FUNCTION Within_Warning_Period( i_Exp_Date_Trk  IN  Tracking_Flag   DEFAULT NULL
                                , i_Exp_Date      IN  DATE )
  RETURN BOOLEAN IS
    This_Function           CONSTANT  VARCHAR2(30) := 'Within_Warning_Period';
    This_Data_Item          CONSTANT  VARCHAR2(30) := 'Warning Date';

    Expiration_Warning_Days           sys_config.config_flag_val%TYPE;
    This_Message                      VARCHAR2(2000);
    My_Exp_Date_Trk                   Tracking_Flag;
    Tracking_Enabled                  BOOLEAN;
  BEGIN
    My_Exp_Date_Trk := NVL( UPPER( i_Exp_Date_Trk ), G_Trk_No );
    -- If expiration date has already been collected and
    -- the expiration date is not provided, then skip the check
    IF ( My_Exp_Date_Trk = G_Trk_Collected ) THEN
      IF ( i_Exp_Date IS NULL ) THEN
        RETURN( FALSE );  -- do nothing
      ELSE
        -- If already collected and capable of revalidation, assume revalidation/recollection
        My_Exp_Date_Trk := G_Trk_Yes;
      END IF;
    END IF;

    Tracking_Enabled  := ( My_Exp_Date_Trk = G_Trk_Yes );
    IF NOT Tracking_Enabled THEN
      RETURN( FALSE );   -- tracking is disabled
    ELSIF ( i_Exp_Date IS NULL ) THEN -- i_Exp_Date needs a value.
      RAISE EXC_Parameter_Required;
    ELSE
      Expiration_Warning_Days := PL_Common.F_Get_SysPar( i_Config_Flag_Name  => 'EXPIR_WARN_DAYS'
                                                       , i_Value_If_Null     => '0' );
      RETURN( ( TRUNC( i_Exp_Date ) - TRUNC( SYSDATE ) ) < TO_NUMBER( Expiration_Warning_Days ) );
    END IF;
  EXCEPTION
    WHEN EXC_Parameter_Required THEN
      -- i_Exp_Date is a mandatory parameter, it MUST have a value.
      -- Log a message and raise a more general exception.
      This_Message := '(i_Exp_Date=[' || NVL( TO_CHAR( i_Exp_Date, 'MM/DD/YYYY HH24:MI:SS' ), 'NULL' ) || ']'
                   || ')  Is a required parameter.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
      Raise_Application_Error( PL_Exc.CT_Data_Error
                             ,    G_This_Package || '.'
                               || This_Function  || '-'
                               || G_Msg_Category || ': '
                               || This_Message
                             );
    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and raise an exception.
      This_Message := '(i_Exp_Date=[' || NVL( TO_CHAR( i_Exp_Date, 'MM/DD/YYYY HH24:MI:SS' ), 'NULL' ) || ']'
                   || ')  Error occurred.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      Raise_Application_Error( PL_Exc.CT_Database_Error
                             ,    G_This_Package || '.'
                               || This_Function  || '-'
                               || G_Msg_Category || ': '
                               || This_Message
                             );
  END Within_Warning_Period;


---------------------------------------------------------------------------
-- Procedure:
--    Check_Mfr_Date
--
-- Description:
--    This function checks the manufacturer's creation date entered for an LP
--    during receiving check-in against the manufacturer shelf life.
--    It should only be called for a mfg date tracked item.
--
-- Parameters:
--    Direction Parameter Name    Data Type       Description
--    --------- ----------------- --------------- ------------------------------
--    Input     i_Mfr_Date_Trk    Tracking_Flag   Y/N, is this item being tracked
--                                                by manufacturer's creation date
--                                                and manufacturer's shelf life?
--    Input     i_Mfr_Date        DATE            The date this item was created
--    Input     i_Mfr_Shelf_Life  DATE            Total days that a manufacturer
--                                                guarantees for the item life
--    Output    o_Exp_Date        DATE            The expiration date to use for
--                                                updating PUTAWAYLST.EXP_DATE.
--                                                The caller MUST perform the
--                                                update. Only valid when function
--                                                returns Normal.
-- Returns:
--              My_Status         Server_Status   Function will return one of the
--                                                following statuses:
--              Normal            Manufacturer's date is defined and valid.
--              Invalid_Mfg_Date  Manufacturer's date is undefined or less than
--                                today.
--              Past_Shelf_Warn   The sum of Manufacturer's date and Mfr shelf
--                                life is greater than today.
--              Exp_Warn          Manufacturer's date is defined and valid, but
--                                within the pre-expiration warning period.
--              Data_Error        Oracle error occurred.
--
-- Exceptions raised:
--      PL_Exc.CT_Database_Error  Received a database error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    11/10/16 bgil6182 Jim Gilliam, authored
--------------------------------------------------------------------------------

  FUNCTION Check_Mfr_Date( i_Pallet_Id      IN     putawaylst.pallet_id%TYPE
                         , i_Mfr_Date_Trk   IN OUT Tracking_Flag
                         , i_Mfr_Date       IN     DATE
                         , i_Mfr_Shelf_Life IN     pm.mfr_shelf_life%TYPE   -- Total days that a manufacturer will guarantee for their product life
                         , i_Date_Override  IN     VARCHAR2 DEFAULT 'N'
                         , o_Exp_Date       OUT DATE
                         )
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30)  := 'Check_Mfr_Date';
    This_Data_Item  CONSTANT  VARCHAR2(30)  := 'Manufactured Date';

    This_Message              VARCHAR2(2000);
    My_Status                 Server_Status;
    My_Trk_Flag               Tracking_Flag;
    l_Exp_Date                PutAwayLst.Exp_Date%TYPE;
    l_Mfr_Date                PutAwayLst.Mfg_Date%TYPE;
    l_Mfr_Date_Trk            PutAwayLst.Date_Code%TYPE;
  BEGIN
    o_Exp_Date := NULL;
    My_Status  := PL_SWMS_Error_Codes.Normal ;
    i_Mfr_Date_Trk := NVL( UPPER( i_Mfr_Date_Trk ), G_Trk_No );

    -- If manufactured date was already collected/validated, but user provided another
    -- manufactured date value, then reset tracking flag to uncollected/unvalidated.
    IF ( i_Mfr_Date_Trk = G_Trk_Collected AND i_Mfr_Date IS NOT NULL ) THEN
      i_Mfr_Date_Trk := G_Trk_Yes;
    END IF;

    -- If manufactured date needs to be validated
    IF ( i_Mfr_Date_Trk = G_Trk_Yes ) THEN

      My_Status := Validate_Mfr_Date( i_Mfr_Date_Trk, i_Mfr_Date );
      IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN  -- This item is being manufacturer date tracked?

        IF ( NVL( i_Mfr_Shelf_Life, 0 ) > 0 ) THEN           -- Do we have a Manufacturer's shelf life defined?

          IF ( TRUNC( SYSDATE ) > ( TRUNC( i_Mfr_Date ) + i_Mfr_Shelf_Life ) ) THEN
            -- The item has lived beyond its shelf life.
            IF NVL(i_Date_Override,'N') = 'N' THEN
              My_Status := PL_SWMS_Error_Codes.Mfr_Shelf_Warn;
              This_Message := This_Data_Item || ' has exceeded shelf life, '
                           || 'Manufacturer=(' || TO_CHAR( i_Mfr_Shelf_Life )
                           || ' i_Date_Override = ' || i_Date_Override
                           || ').';
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            ELSIF NVL(i_Date_Override,'N') = 'Y' THEN
                o_Exp_Date := TRUNC(SYSDATE);
                My_Status := Insert_DTO_Trans (i_Pallet_Id, o_Exp_Date, i_Mfr_Date);
                This_Message := This_Data_Item || 'Expiration date derived from mfr_date is overrided for pallet# '||i_Pallet_Id ;
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => FALSE
                                    , i_ProgramName => G_This_Package
                                    );
            END IF;
          ELSE
           o_Exp_Date := i_Mfr_Date + i_Mfr_Shelf_Life;
           This_Message := 'Expiration date derived from ' || This_Data_Item || ' as ' || TO_CHAR( o_Exp_Date, 'DD-Mon-YYYY' ) || '.';
           PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                               , i_ModuleName  => This_Function
                               , i_Message     => This_Message
                               , i_Category    => G_Msg_Category
                               , i_Add_DB_Msg  => FALSE
                               , i_ProgramName => G_This_Package

                               );

          END IF;
        ELSE

          IF NVL(i_Date_Override,'N') = 'N' THEN
              My_Status := PL_SWMS_Error_Codes.Mfr_Shelf_Warn;
              This_Message := This_Data_Item || ' tracking is enabled but product has no shelf life is defined'
                        || ' for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
             PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                               , i_ModuleName  => This_Function
                               , i_Message     => This_Message
                               , i_Category    => G_Msg_Category
                               , i_Add_DB_Msg  => FALSE
                               , i_ProgramName => G_This_Package
                               );
            ELSIF NVL(i_Date_Override,'N') = 'Y' THEN
            -- Calculate the Manufacturer's expiration date
            o_Exp_Date := i_Mfr_Date + i_Mfr_Shelf_Life;
            This_Message := 'Overrided expiration date derived from ' || This_Data_Item || ' as ' || TO_CHAR( o_Exp_Date, 'DD-Mon-YYYY' )
                    ||' for a product that has no shelf life defined '|| '.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            END IF;
        END IF;

        Save_Mfr_Date( i_Mfr_Date );

        -- Now update the tracking flag from (Y)es to (C)omplete
        BEGIN
          SELECT Date_Code, Mfg_Date, Exp_Date
            INTO l_Mfr_Date_Trk, l_Mfr_Date, l_Exp_Date
            FROM putawaylst
           WHERE Pallet_Id = i_Pallet_Id
          FOR UPDATE OF Date_Code, Mfg_Date, Exp_Date WAIT 5;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            This_Message := 'Specified pallet ' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Inv_Label ;
          WHEN EXC_DB_Locked_With_NoWait OR
               EXC_DB_Locked_With_Wait   THEN
            This_Message := 'Failed to update ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                         || ' due to the pallet being locked by someone else.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Lock_PO ;
        END;

        IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
          BEGIN
            UPDATE putawaylst
               SET Date_Code = G_Trk_Collected
                 , Mfg_Date  = i_Mfr_Date
                 , Exp_Date  = o_Exp_Date
             WHERE Pallet_Id = i_Pallet_Id;

            This_Message := 'Saved ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id ) ;
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => TRUE
                                , i_ProgramName => G_This_Package
                                );
          EXCEPTION
            WHEN OTHERS THEN
              This_Message := 'Failed to update ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id ) ;
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                  , i_ModuleName  => This_Function
                                  , i_Message     => This_Message
                                  , i_Category    => G_Msg_Category
                                  , i_Add_DB_Msg  => TRUE
                                  , i_ProgramName => G_This_Package
                                  );
              My_Status := PL_SWMS_Error_Codes.Update_Fail ;
          END;
        END IF;
      END IF;
    END IF;

    RETURN( My_Status );
  EXCEPTION
    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and return error code.
      This_Message := '(i_Pallet_Id=['      || NVL( UPPER( i_Pallet_Id ), 'NULL' )                            || ']'
                   || '(i_Mfr_Date_Trk=['   || NVL( UPPER( i_Mfr_Date_Trk ), 'NULL' )                         || ']'
                   || ',i_Mfr_Date=['       || NVL( TO_CHAR( i_Mfr_Date, 'MM/DD/YYYY HH24:MI:SS' ), 'NULL' )  || ']'
                   || ',i_Mfr_Shelf_Life=[' || NVL( TO_CHAR( i_Mfr_Shelf_Life ), 'NULL' )                     || ']'
                   || ',o_Exp_Date=['       || NVL( TO_CHAR( o_Exp_Date, 'MM/DD/YYYY HH24:MI:SS' ), 'NULL' )  || ']'
                   || ') =[' || TO_CHAR( My_Status ) || '] (Return_Status).'
                   || '  Error calculating the expiration based on the manufacturer''s date.'
                   || '  Returning pl_swms_error_codes.data_error';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      My_Status := PL_SWMS_Error_Codes.Data_Error;
      RETURN( My_Status );
  END Check_Mfr_Date;


--------------------------------------------------------------------------------
-- Procedure:
--    Check_Harvest_Date
--
-- Description:
--    This function checks the manufacturer's date range entered for an LP
--    during receiving check-in against:
--    1. the manufacturer shelf life.
--    2. the putawaylst mfg date
--    3. the putawaylst exp date
--
--    This procedure should only be called for a harvest date tracked item.
--
-- Parameters:
--    i_Clam_Bed_Trk   - The clam bed tracking flag.
--    i_Harvest_Date   - The harvest date to check.
--    i_Mfr_Shelf_Life - The manufacturer shelf life to check against.
--    i_Mfg_Date       - The manufacturer date to check i_harvest_date against.
--                       From PUTAWAYLST.MFG_DATE
--    i_Exp_Date       - The expiration date to check i_harvest_date against.
--                       From PUTAWAYLST.EXP_DATE
--
-- Returns:
--         Server_Status     Function will return one of the following values:
--         Normal            Harvest date is defined and valid.
--         Invalid_Hrv_Date  Harvest date is less than today.
--         Past_Shelf_Warn   Harvest date and Mfr shelf life is less than today.
--         Hrv_Date_Warn     Harvest date is less than the mfg date or greater
--                           than the expiration date.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------------
--    11/10/16 bgil6182 Jim Gilliam, authored
--------------------------------------------------------------------------------

  FUNCTION Check_Harvest_Date( i_Clam_Bed_Trk         IN  OUT VARCHAR2
                             , i_Clam_Bed_No          IN      trans.clam_bed_no%TYPE
                             , i_Harvest_Date         IN      DATE
                             , i_Mfr_Shelf_Life       IN      pm.mfr_shelf_life%TYPE
                             , i_Mfg_Date             IN      DATE
                             , i_Exp_Date             IN      DATE
                             , O_Hrv_warn                 OUT Server_Status
                             )
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30)  := 'Check_Harvest_Date';
    This_Data_Item  CONSTANT  VARCHAR2(50)  := 'Clam Bed Number and Harvest Date';

    This_Message              VARCHAR2(2000);
    My_Status                 Server_Status;
  BEGIN
    -- Validate_Harvest_Date will return invalid harvest date if
    -- i_harvest_date is greater than today
    My_Status := Validate_Harvest_Date( i_Clam_Bed_Trk, i_Harvest_Date );
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
      -- Has receiver requested tracking for a clam bed item?
      IF ( UPPER( NVL( i_Clam_Bed_Trk, 'N' ) ) <> G_Trk_No ) THEN
        -- Check the harvest date against the mfr shelf life, only if i_mfr_shelf_life > 0.
        IF ( NVL( i_Mfr_Shelf_Life, 0 ) > 0) THEN
          -- Check the harvest date against the mfg shelf life.
          -- The harvest date MUST be greater than today plus the mfg shelf life (in days).
          IF ( ( TRUNC( i_Harvest_Date ) + i_Mfr_Shelf_Life ) < TRUNC( SYSDATE ) ) THEN
            -- The item is past its shelf life.
            O_Hrv_warn := PL_SWMS_Error_Codes.Past_Shelf_Warn;
          END IF;
        END IF;
      END IF;

      -- As long as no errors have occurred, then check the harvest date
      -- against the putawaylst mfg date but only when the mfg_date is not null.
      -- The harvest date should not be less than the mfg date.
      IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
        Save_Clam_Bed_No( i_Clam_Bed_No );
        Save_Exp_Date( i_Harvest_Date );

        IF ( i_Mfg_Date IS NOT NULL AND TRUNC( i_Harvest_Date ) < TRUNC( i_Mfg_Date ) ) THEN
          -- The harvest date is less than the mfg date.
          O_Hrv_warn := PL_SWMS_Error_Codes.Hrv_Date_Warn;
        ELSIF ( i_Exp_Date IS NOT NULL AND TRUNC( i_Harvest_Date ) > TRUNC( i_Exp_Date ) ) THEN
          -- Check the harvest date against the putawaylst exp date.
          -- The harvest date should not be greater than the expiration date.
          O_Hrv_warn := PL_SWMS_Error_Codes.Hrv_Date_Warn;
        END IF;
      END IF;
    END IF;

    RETURN( My_Status );
  EXCEPTION
    WHEN OTHERS THEN
      -- Got some oracle error.  Log a message and return error code.
      This_Message := '(i_Clam_Bed_Trk=['   || UPPER( NVL( i_Clam_Bed_Trk, 'N') )                               || ']'
                   || ',i_Harvest_Date=['   || NVL( TO_CHAR( i_Harvest_Date, 'MM/DD/YYYY HH24:MI:SS'), 'NULL' ) || ']'
                   || ',i_Mfr_Shelf_Life=[' || NVL( TO_CHAR( i_Mfr_Shelf_Life ), 'NULL' )                       || ']'
                   || ',i_Mfg_Date=['       || NVL( TO_CHAR( i_Mfg_Date, 'MM/DD/YYYY HH24:MI:SS'), 'NULL' )     || ']'
                   || ',i_Exp_Date=['       || NVL( TO_CHAR( i_Exp_Date, 'MM/DD/YYYY HH24:MI:SS'), 'NULL' )     || ']'
                   || ') = [' || TO_CHAR( My_Status ) || ']  Error validating the harvest date.'
                   || '  Returning PL_SWMS_Error_Codes.Data_Error';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RETURN( PL_SWMS_Error_Codes.Data_Error );
  END Check_Harvest_Date;

--------------------------------------------------------------------------------
-- Function
--   Get_UPC_List_Within_Item
--
-- Description
--   This function is intended to return a table/list of external UPC's that
--   are included on this product.
--
-- Parameters
--    Parameter Name         Data Type      Description
--
--  Input:
--    i_Prod_Id              VARCHAR2       Product ID
--
--  Output:
--    None.
--
--RETURNs:
--    UPC_Tbl                LR_UPC_List_Ta List of all UPCs associated with
--                           ble            this product.
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 09/20/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Get_UPC_List_Within_Item( i_Prod_Id IN VARCHAR2, i_Cust_Pref_Vendor IN VARCHAR2 )
  RETURN LR_UPC_List_Table IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Get_UPC_List_Within_Item' ;
    This_Message              VARCHAR2(2000 CHAR);

    UPC_Tbl                   LR_UPC_List_Table;
  BEGIN
    SELECT LR_UPC_List_Rec( upc_type, upc_code )
    BULK COLLECT INTO UPC_Tbl
      FROM ( SELECT DISTINCT 'E' upc_type, external_upc upc_code
               FROM pm_upc
              WHERE prod_id = i_Prod_Id
                AND cust_pref_vendor = i_Cust_Pref_Vendor
                AND external_upc != '00000000000000'
                AND external_upc != 'XXXXXXXXXXXXXX'
             ORDER BY external_upc ) ;

    This_Message := NVL( TO_CHAR(UPC_Tbl.LAST-UPC_Tbl.FIRST+1), 0 ) || ' UPCs returned for '
                    || '(Prod_Id=' || i_Prod_Id
                    || ',Cust_Pref_Vendor=' || i_Cust_Pref_Vendor
                    || ').';
    PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => G_Msg_Category
                        , i_Add_DB_Msg  => FALSE
                        , i_ProgramName => G_This_Package
                        );

    RETURN( UPC_Tbl );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of external UPCs.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RAISE;
  END Get_UPC_List_Within_Item;

--------------------------------------------------------------------------------
-- Function
--   Get_LPN_List_Within_Item
--
-- Description
--   This function is intended to return a table/list of LPNs/pallets that
--   are included on this Purchase Orader (PO).
--
-- Parameters
--    Parameter Name         Data Type      Description
--    ---------------------- -------------- ------------------------------------
--
--  Input:
--    i_PO_Id                VARCHAR2       Purchase Order ID (ERM_ID)
--    i_Prod_Id              VARCHAR2       Product ID
--    i_Cust_Pref_Vendor     VARCHAR2       Customer Preferred Vendor
--
--  Output:
--    None.
--
--RETURNs:
--    LPN_Tbl                LR_LPN_List_Ta List of all LPNs associated with
--                           ble            this PO.
--
-- Modification History
--
-- Date       User      CRQ #      Description
-- ---------- --------- ---------- ---------------------------------------------
-- 09/21/2016 bgil6182  00008118   Authored original version.
-- 10/21/2021 bgil6182  OPCOF-3541 Missed requirement added: Modify bulk queries
--                                 for LR_LPN_List_Rec type. This provides the
--                                 current setting for the OSandD reason during
--                                 live receiving to follow the pallet through
--                                 the put away process.
--------------------------------------------------------------------------------

  FUNCTION Get_LPN_List_Within_Item( i_PO_Id            IN VARCHAR2
                                   , i_Prod_Id          IN VARCHAR2
                                   , i_Cust_Pref_Vendor IN VARCHAR2 )
  RETURN LR_LPN_List_Table IS
    This_Function       CONSTANT  VARCHAR2(30 CHAR)                 := 'Get_LPN_List_Within_Item' ;
    Overage_Param_Name  CONSTANT  sys_config.config_flag_name%TYPE  := 'OVERAGE_FLG' ;

    This_Message                  VARCHAR2(2000 CHAR);
    LPN_Tbl                       LR_LPN_List_Table;
    Pallet_Id                     putawaylst.pallet_id%TYPE;
    Pallet_Limit                  NUMBER;
    Qty_Allowed                   NUMBER;
    Overage_Rule                  sys_config.config_flag_val%TYPE;
    l_Erm_Type                    erm.erm_type%TYPE;
  BEGIN

-- Get value of system parameter
    BEGIN
      SELECT UPPER( sc.config_flag_val )
        INTO Overage_Rule
        FROM sys_config sc
       WHERE sc.config_flag_name = Overage_Param_Name;

-- Validate acceptable values
      CASE Overage_Rule
        WHEN 'U' THEN NULL;
        WHEN 'P' THEN NULL;
        WHEN 'T' THEN NULL;
        ELSE Overage_Rule := 'N';
      END CASE;
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := 'Exception: Failed to lookup ' || Overage_Param_Name || ' system parameter.';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        Overage_Rule := 'N';
    END;

    -- Get the erm type for this PO.
    l_Erm_Type := get_Erm_Type(i_PO_Id);

    IF pl_common.f_is_internal_production_po(i_PO_Id) THEN
        -- Set all data collection indicator/flags to 'N'. We do not want to prompt for finish good POs
        -- Set the status to NEW (RF_Status_New) since the pallets have been pre-received/auto-confirmed
        -- (putaway_put is already 'Y') and we want them to be able to check-in the items as they are produced.
        SELECT LR_LPN_List_Rec( Pallet_Id
                              , Erm_Type
                              , Qty_Expected , Qty_Received
                              , Exp_Date     , Exp_Date_Ind
                              , Mfg_Date     , Mfg_Date_Ind
                              , Lot_Id       , Lot_Ind
                              , Temp         , Temp_Ind
                              , TTI_Value    , TTI_Ind
                              , Cryovac_Value
                              , Catch_Wt_Ind
                              , Clam_Bed_Ind
                              , Cool_Ind
                              , Dest_Loc
                              , Status
                              , OSD_Reason_Cd
                              )
        BULK COLLECT INTO LPN_Tbl
          FROM ( SELECT DISTINCT
                    lp.pallet_id                              Pallet_Id
                  , l_Erm_Type                                Erm_Type
                  , lp.qty_expected                           Qty_Expected
                  , NVL(lp.qty_produced, 0)                   Qty_Received
                  , TO_CHAR( lp.exp_date, G_RF_Date_Format )  Exp_Date
                  , 'N'                                       Exp_Date_Ind
                  , TO_CHAR( lp.mfg_date, G_RF_Date_Format )  Mfg_Date
                  , 'N'                                       Mfg_Date_Ind
                  , lp.lot_id                                 Lot_Id
                  , 'N'                                       Lot_Ind
                  , NVL(lp.temp,0)                            Temp
                  , 'N'                                       Temp_Ind
                  , lp.tti                                    TTI_Value
                  , 'N'                                       TTI_Ind
                  , lp.cryovac                                Cryovac_Value
                  , 'N'                                       Catch_Wt_Ind
                  , 'N'                                       Clam_Bed_Ind
                  , 'N'                                       Cool_Ind
                  , lp.dest_loc                               Dest_Loc
                  , DECODE( lp.qty_expected   -- If qty expected is equal to qty_produced, show Checked status
                          , lp.qty_produced, RF_Status_Checked
                          , RF_Status_New )                   Status
                  , lp.OSD_LR_Reason_Cd                       OSD_Reason_Cd
               FROM putawaylst lp
              WHERE lp.rec_id             = i_PO_Id
                AND lp.prod_id            = i_Prod_Id
                AND lp.cust_pref_vendor   = i_Cust_Pref_Vendor
             ORDER BY lp.pallet_id );

    ELSE

        SELECT LR_LPN_List_Rec( Pallet_Id
                              , Erm_Type
                              , Qty_Expected , Qty_Received
                              , Exp_Date     , Exp_Date_Ind
                              , Mfg_Date     , Mfg_Date_Ind
                              , Lot_Id       , Lot_Ind
                              , Temp         , Temp_Ind
                              , TTI_Value    , TTI_Ind
                              , Cryovac_Value
                              , Catch_Wt_Ind
                              , Clam_Bed_Ind
                              , Cool_Ind
                              , Dest_Loc
                              , Status
                              , OSD_Reason_Cd
                              )
        BULK COLLECT INTO LPN_Tbl
          FROM ( SELECT DISTINCT
                    lp.pallet_id                              Pallet_Id
                  , l_Erm_Type                                Erm_Type
                  , lp.qty_expected                           Qty_Expected
                  , lp.qty_received                           Qty_Received
                  , TO_CHAR( lp.exp_date, G_RF_Date_Format )  Exp_Date
                  , lp.exp_date_trk                           Exp_Date_Ind
                  , TO_CHAR( lp.mfg_date, G_RF_Date_Format )  Mfg_Date
                  , lp.date_code                              Mfg_Date_Ind
                  , lp.lot_id                                 Lot_Id
                  , lp.lot_trk                                Lot_Ind
                  , lp.temp                                   Temp
                  , lp.temp_trk                               Temp_Ind
                  , lp.tti                                    TTI_Value
                  , lp.tti_trk                                TTI_Ind
                  , lp.cryovac                                Cryovac_Value
                  , lp.catch_wt                               Catch_Wt_Ind
                  , lp.clam_bed_trk                           Clam_Bed_Ind
                  , lp.cool_trk                               Cool_Ind
                  , lp.dest_loc                               Dest_Loc
                  , DECODE( lp.putaway_put
                          , 'Y', RF_Status_Putaway
                          , DECODE( lp.status
                                  , G_Trx_Type_Check, RF_Status_Checked
                                  , G_Trx_Type_New  , RF_Status_New     ) ) Status
                  , lp.OSD_LR_Reason_Cd                       OSD_Reason_Cd
               FROM putawaylst lp
              WHERE lp.rec_id           = i_PO_Id
                AND lp.prod_id          = i_Prod_Id
                AND lp.cust_pref_vendor = i_Cust_Pref_Vendor
             ORDER BY lp.pallet_id );
    END IF;

    This_Message := NVL( TO_CHAR(LPN_Tbl.COUNT), 0 ) || ' pallets returned for '
                    || '( PO_Id='            || i_PO_Id
                    || ', Prod_Id='          || i_Prod_Id
                    || ', Cust_Pref_Vendor=' || i_Cust_Pref_Vendor
                    || ' ).';
    PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => G_Msg_Category
                        , i_Add_DB_Msg  => FALSE
                        , i_ProgramName => G_This_Package
                        );

    RETURN( LPN_Tbl );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of LPNs/pallets.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RAISE;
  END Get_LPN_List_Within_Item;


--------------------------------------------------------------------------------
-- Function
--   Get_LPN_List_Within_Item
--
-- Description
--   This function is intended to return a table/list of LPNs/pallets that
--   are included on this Purchase Orader (PO).
--
-- Parameters
--    Parameter Name         Data Type      Description
--
--  Input:
--    i_PO_Id                VARCHAR2       Purchase Order ID (ERM_ID)
--    i_Prod_Id              VARCHAR2       Product ID
--    i_Cust_Pref_Vendor     VARCHAR2       Customer Preferred Vendor
--    i_Split_Uom       VARCHAR2     UOM for the each item
--
--  Output:
--    None.
--
--RETURNs:
--    LPN_Tbl                LR_LPN_List_Ta List of all LPNs associated with
--                           ble            this PO.
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 08/28/2020 sban3548 OPCOF-3178 Added UOM for SAP (Brakes) opco only to avoid duplicate LPNs in RF LR check-in
--
--------------------------------------------------------------------------------

  FUNCTION Get_LPN_List_Within_Item( i_PO_Id            IN VARCHAR2
                                   , i_Prod_Id          IN VARCHAR2
                                   , i_Cust_Pref_Vendor IN VARCHAR2
                   , i_Split_Uom    IN NUMBER)
  RETURN LR_LPN_List_Table IS
    This_Function       CONSTANT  VARCHAR2(30 CHAR)                 := 'Get_LPN_List_Within_Item' ;
    Overage_Param_Name  CONSTANT  sys_config.config_flag_name%TYPE  :=  'OVERAGE_FLG' ;

    This_Message                  VARCHAR2(2000 CHAR);
    LPN_Tbl                       LR_LPN_List_Table;
    Pallet_Id                     putawaylst.pallet_id%TYPE;
    Pallet_Limit                  NUMBER;
    Qty_Allowed                   NUMBER;
    Overage_Rule                  sys_config.config_flag_val%TYPE;
    l_Erm_Type                    erm.erm_type%TYPE;
  BEGIN

-- Get value of system parameter
    BEGIN
      SELECT UPPER( sc.config_flag_val )
        INTO Overage_Rule
        FROM sys_config sc
       WHERE sc.config_flag_name = Overage_Param_Name;

-- Validate acceptable values
      CASE Overage_Rule
        WHEN 'U' THEN NULL;
        WHEN 'P' THEN NULL;
        WHEN 'T' THEN NULL;
        ELSE Overage_Rule := 'N';
      END CASE;
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := 'Exception: Failed to lookup ' || Overage_Param_Name || ' system parameter.';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        Overage_Rule := 'N';
    END;

    -- Get the erm type for this PO.
    l_Erm_Type := get_Erm_Type(i_PO_Id);

    IF pl_common.f_is_internal_production_po(i_PO_Id) THEN
        -- Set all data collection indicator/flags to 'N'. We do not want to prompt for finish good POs
        -- Set the status to NEW (RF_Status_New) since the pallets have been pre-received/auto-confirmed
        -- (putaway_put is already 'Y') and we want them to be able to check-in the items as they are produced.
        SELECT LR_LPN_List_Rec( Pallet_Id
                              , Erm_Type
                              , Qty_Expected , Qty_Received
                              , Exp_Date     , Exp_Date_Ind
                              , Mfg_Date     , Mfg_Date_Ind
                              , Lot_Id       , Lot_Ind
                              , Temp         , Temp_Ind
                              , TTI_Value    , TTI_Ind
                              , Cryovac_Value
                              , Catch_Wt_Ind
                              , Clam_Bed_Ind
                              , Cool_Ind
                              , Dest_Loc
                              , Status
                              , OSD_Reason_Cd
                              )
        BULK COLLECT INTO LPN_Tbl
          FROM ( SELECT DISTINCT
                    lp.pallet_id                              Pallet_Id
                  , l_Erm_Type                                Erm_Type
                  , lp.qty_expected                           Qty_Expected
                  , NVL(lp.qty_produced, 0)                   Qty_Received
                  , TO_CHAR( lp.exp_date, G_RF_Date_Format )  Exp_Date
                  , 'N'                                       Exp_Date_Ind
                  , TO_CHAR( lp.mfg_date, G_RF_Date_Format )  Mfg_Date
                  , 'N'                                       Mfg_Date_Ind
                  , lp.lot_id                                 Lot_Id
                  , 'N'                                       Lot_Ind
                  , NVL(lp.temp,0)                            Temp
                  , 'N'                                       Temp_Ind
                  , lp.tti                                    TTI_Value
                  , 'N'                                       TTI_Ind
                  , lp.cryovac                                Cryovac_Value
                  , 'N'                                       Catch_Wt_Ind
                  , 'N'                                       Clam_Bed_Ind
                  , 'N'                                       Cool_Ind
                  , lp.dest_loc                               Dest_Loc
                  , DECODE( lp.qty_expected   -- If qty expected is equal to qty_produced, show Checked status
                          , lp.qty_produced, RF_Status_Checked
                          , RF_Status_New )                   Status
                  , lp.OSD_LR_Reason_Cd                       OSD_Reason_Cd
               FROM putawaylst lp
              WHERE lp.rec_id             = i_PO_Id
                AND lp.prod_id            = i_Prod_Id
                AND lp.cust_pref_vendor   = i_Cust_Pref_Vendor
             ORDER BY lp.pallet_id );

    ELSE

        SELECT LR_LPN_List_Rec( Pallet_Id
                              , Erm_Type
                              , Qty_Expected , Qty_Received
                              , Exp_Date     , Exp_Date_Ind
                              , Mfg_Date     , Mfg_Date_Ind
                              , Lot_Id       , Lot_Ind
                              , Temp         , Temp_Ind
                              , TTI_Value    , TTI_Ind
                              , Cryovac_Value
                              , Catch_Wt_Ind
                              , Clam_Bed_Ind
                              , Cool_Ind
                              , Dest_Loc
                              , Status
                              , OSD_Reason_Cd
                              )
        BULK COLLECT INTO LPN_Tbl
          FROM ( SELECT DISTINCT
                    lp.pallet_id                              Pallet_Id
                  , l_Erm_Type                                Erm_Type
                  , lp.qty_expected                           Qty_Expected
                  , lp.qty_received                           Qty_Received
                  , TO_CHAR( lp.exp_date, G_RF_Date_Format )  Exp_Date
                  , lp.exp_date_trk                           Exp_Date_Ind
                  , TO_CHAR( lp.mfg_date, G_RF_Date_Format )  Mfg_Date
                  , lp.date_code                              Mfg_Date_Ind
                  , lp.lot_id                                 Lot_Id
                  , lp.lot_trk                                Lot_Ind
                  , lp.temp                                   Temp
                  , lp.temp_trk                               Temp_Ind
                  , lp.tti                                    TTI_Value
                  , lp.tti_trk                                TTI_Ind
                  , lp.cryovac                                Cryovac_Value
                  , lp.catch_wt                               Catch_Wt_Ind
                  , lp.clam_bed_trk                           Clam_Bed_Ind
                  , lp.cool_trk                               Cool_Ind
                  , lp.dest_loc                               Dest_Loc
                  , DECODE( lp.putaway_put
                          , 'Y', RF_Status_Putaway
                          , DECODE( lp.status
                                  , G_Trx_Type_Check, RF_Status_Checked
                                  , G_Trx_Type_New  , RF_Status_New     ) ) Status
                  , lp.OSD_LR_Reason_Cd                       OSD_Reason_Cd
               FROM putawaylst lp
              WHERE lp.rec_id           = i_PO_Id
                AND lp.prod_id          = i_Prod_Id
                AND lp.cust_pref_vendor = i_Cust_Pref_Vendor
        AND lp.uom        = i_Split_Uom
             ORDER BY lp.pallet_id );
    END IF;

    This_Message := NVL( TO_CHAR(LPN_Tbl.COUNT), 0 ) || ' pallets returned for '
                 || '( PO_Id='            || NVL( i_PO_Id           , 'NULL' )
                 || ', Prod_Id='          || NVL( i_Prod_Id         , 'NULL' )
                 || ', Cust_Pref_Vendor=' || NVL( i_Cust_Pref_Vendor, 'NULL' )
                 || ', Split_Uom='        || NVL( i_Split_Uom       , 'NULL' )
                 || ' ).';
    PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => G_Msg_Category
                        , i_Add_DB_Msg  => FALSE
                        , i_ProgramName => G_This_Package
                        );

    RETURN( LPN_Tbl );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of LPNs/pallets.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RAISE;
  END Get_LPN_List_Within_Item;



--------------------------------------------------------------------------------
-- Function
--   Get_Item_List_Within_Load
--
-- Description
--   This function is intended to return a table/list of detailed product
--   items that are included on this PO.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_PO_Id                VARCHAR2       Purchase Order ID
--
--  Output:
--    None.
--
--RETURNs:
--    Item_Table             LR_Item_List_T List of all Items associated with
--                           able           this PO.
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 09/20/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Get_Item_List_Within_Load( i_PO_id IN VARCHAR2, Table_Status OUT Server_Status )
  RETURN LR_Item_List_Table IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Get_Item_List_Within_Load' ;
    This_Message              VARCHAR2(2000 CHAR);

    Item_Tbl                 LR_Item_List_Table;
    item                     LR_Item_List_Rec;
    num_pallets              PLS_INTEGER;
    is_table_empty           BOOLEAN;
    l_prod_PO                char;
  BEGIN
    Table_Status:= PL_SWMS_Error_Codes.Normal;

    IF pl_common.f_is_internal_production_po(i_PO_id) THEN
      l_prod_PO := 'Y';
    ELSE
      l_prod_PO := 'N';
    END IF;

    SELECT LR_Item_List_Rec( "Prod_Id"            , "Sysco_Shelf_Life" , "Max_Temp"
                           , "Min_Temp"           , "Ti"               , "Hi"
                           , "Pallet_Type"        , "Cust_Pref_Vendor" , "UOM"
                           , "Spc"                , "Cust_Shelf_Life"  , "Mfr_Shelf_Life"
                           , "UPC_Comp_Flag"      , "Clam_Bed_Num"     , "Harvest_Date"
                           , "Total_Cases"        , "Total_Splits"     , "Total_Wt"
                           , "Default_Weight_Unit", "Descrip"          , "Mfg_SKU"
                           , "Pack"               , "Prod_Size"        , "UCN"
                           , "Pick_Loc"           , "Message_Fld"      , "Brand"
                           , LR_LPN_List_Table()  , LR_UPC_List_Table() )
    BULK COLLECT INTO Item_Tbl
      FROM ( SELECT DISTINCT
                    pm.prod_id                            "Prod_Id"
                  , TO_CHAR( pm.sysco_shelf_life )        "Sysco_Shelf_Life"
                  , NVL(pm.max_temp,0)                    "Max_Temp"
                  , NVL(pm.min_temp,0)                    "Min_Temp"
                  , NVL(pm.ti,0)                          "Ti"
                  , NVL(pm.hi,0)                          "Hi"
                  , pm.pallet_type                        "Pallet_Type"
                  , pm.cust_pref_vendor                   "Cust_Pref_Vendor"
                  , lp.uom                                "UOM"
                  , pm.spc                                "Spc"
                  , TO_CHAR( pm.cust_shelf_life )         "Cust_Shelf_Life"
                  , TO_CHAR( pm.mfr_shelf_life )          "Mfr_Shelf_Life"
                  , DECODE( pm.finish_good_ind
                          , 'Y', 'Y'  -- Don't need to prompt for UPC collect for finish good items
                          , pl_common.Check_UPC( pm.prod_id, po.erm_id, G_RCV_Option )
                          )                               "UPC_Comp_Flag"
                  , trans.clam_bed_no                     "Clam_Bed_Num"
                  , TO_CHAR( trans.exp_date
                           , G_RF_Date_Format )           "Harvest_Date"
                  , NVL(tmp_weight.total_cases,0)         "Total_Cases"
                  , NVL(tmp_weight.total_splits,0)        "Total_Splits"
                  , NVL(tmp_weight.total_weight,0)        "Total_Wt"
                  , pm.default_weight_unit                "Default_Weight_Unit"
                  , pm.descrip                            "Descrip"
                  , pm.mfg_sku                            "Mfg_SKU"
                  , pm.pack                               "Pack"
                  , pm.prod_size                          "Prod_Size"
                  , SUBSTR(pm.external_upc,9,14-9+1)      "UCN"
                  , loc.logi_loc                          "Pick_Loc"
                  , TO_CHAR( NULL )                       "Message_Fld"
                  , pm.brand                              "Brand"
               FROM          erm po
             LEFT OUTER JOIN putawaylst lp ON ( po.erm_id = lp.rec_id )
                  INNER JOIN pm            ON ( lp.prod_id = pm.prod_id )
             LEFT OUTER JOIN tmp_weight    ON ( tmp_weight.erm_id = lp.rec_id and tmp_weight.prod_id = lp.prod_id and tmp_weight.cust_pref_vendor = pm.cust_pref_vendor )
             LEFT OUTER JOIN trans         ON ( trans.rec_id = po.erm_id and trans.prod_id = lp.prod_id and trans.cust_pref_vendor = pm.cust_pref_vendor
                                                and trans.trans_type = 'RHB' and ROWNUM = 1 )
             LEFT OUTER JOIN loc           ON ( loc.prod_id = lp.prod_id and loc.cust_pref_vendor = pm.cust_pref_vendor and loc.uom in ( 0, 2 ) and loc.rank = 1 )
              WHERE po.erm_type in ('TR', 'PO', 'FG')
                --AND po.status IN ( 'OPN' )
                AND
                (
                  po.status in ('OPN')
                  OR
                  (po.status in ('OPN', 'XXCLO') and l_prod_PO = 'Y')  /* knha8378 Nov 5, 2019 put XX to not allow CLO status to treat like normal PO */
                )
                AND po.erm_id = i_PO_Id
             ORDER BY pm.prod_id ) ;

      Is_Table_empty := Item_Tbl IS EMPTY;

      IF Is_Table_empty THEN
        Table_Status := RF.STATUS_INV_PO;
         This_Message := 'No items returned for '
                      || '(PO_Id=' || i_PO_Id
                      || ').';

         PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                             , i_ModuleName  => This_Function
                             , i_Message     => This_Message
                             , i_Category    => G_Msg_Category
                             , i_Add_DB_Msg  => FALSE
                             , i_ProgramName => G_This_Package );
      END IF;

      IF NOT is_table_empty THEN
        This_Message := NVL( TO_CHAR(Item_Tbl.LAST-Item_Tbl.FIRST+1), 0 ) || ' items returned for '
                          || '(PO_Id=' || i_PO_Id
                          || ').';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );

        FOR item IN Item_Tbl.First..Item_Tbl.Last LOOP
          IF NVL( PL_Common.F_Get_SysPar( 'HOST_TYPE' ), 'N' ) = 'SAP' THEN
            Item_Tbl(item).LPN_Table := Get_LPN_List_Within_Item( i_PO_Id, Item_Tbl(item).Prod_Id, Item_Tbl(item).Cust_Pref_Vendor, Item_Tbl(item).uom );
          ELSE
            Item_Tbl(item).LPN_Table := Get_LPN_List_Within_Item( i_PO_Id, Item_Tbl(item).Prod_Id, Item_Tbl(item).Cust_Pref_Vendor );
          END IF;

          num_pallets := Item_Tbl(item).LPN_Table.COUNT;
          IF ( num_pallets = 0 ) THEN
            Item_Tbl(item).UPC_Table := LR_UPC_List_Table();
          ELSE
            Item_Tbl(item).UPC_Table := Get_UPC_List_Within_Item( Item_Tbl(item).Prod_Id, Item_Tbl(item).Cust_Pref_Vendor );
          END IF;

        END LOOP;
      END IF;

    RETURN( Item_Tbl );

  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of Product/Items.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RAISE;
  END Get_Item_List_Within_Load;

--------------------------------------------------------------------------------
-- Function
--   Get_PO_List_Within_Load
--
-- Description
--   This function is intended to return a table/list of detailed purchase
--   orders (PO) that are included on the same load (truck). If the specified
--   PO is not associated with a load, then the single PO will be returned in
--   the list..
--
--   The intention here is that as a Receiver unloads a truck with their
--   forklift, (s)he just sees a list of items on pallets and may choose to
--   unload pallets that are not necessarily in PO order.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_PO_Id                VARCHAR2       Purchase Order ID
--
--  Output:
--    o_Load_No              VARCHAR2       ERM.LOAD_NO associated with i_PO_Id
--
--RETURNs:
--    lr_po_list_table       LR_PO_List_Ta List of all POs associated with the
--                           ble           same truck.
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 09/20/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Get_PO_List_Within_Load( i_PO_id IN VARCHAR2 )
  RETURN SWMS.LR_PO_List_Table IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Get_PO_List_Within_Load' ;
    This_Message              VARCHAR2(2000 CHAR);

    PO_Tbl                   LR_PO_List_Table;

  BEGIN

    SELECT LR_PO_List_Rec( PO_Lst.ERM_Id, TO_CHAR( PO_Lst.Rec_Date, G_RF_Date_Format ), LR_Item_List_Table())
    BULK COLLECT INTO PO_Tbl
      FROM erm PO
     INNER JOIN erm PO_Lst ON ( PO.Load_No = PO_Lst.Load_No )
     WHERE PO_Lst.ERM_Type IN ( 'TR', 'PO', 'FG' )
       --AND PO_Lst.Status IN ( 'OPN' )
       AND (    PO_Lst.Status IN ( 'OPN' )
             OR ( PO_Lst.Status IN ( 'OPN', 'XXCLO' ) AND
                  Check_Finish_Good_PO( PO_Lst.erm_id ) = 'Y' ) --knha8378 put XX to not allow CLO status to process for finish good
           )
       AND REPLACE( PO.Load_No, CHR(0), '' ) IS NOT NULL  -- Patch where SUS may send us a string of NULL characters with a non-zero length.
       AND PO.ERM_Id = i_PO_Id
    ORDER BY PO_Lst.ERM_Id;

    This_Message := TO_CHAR( PO_Tbl.COUNT ) || ' POs returned for '
                 || '( Load_Id=' || NVL( G_This_Load, 'NULL' )
                 || ' ).';
    PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => G_Msg_Category
                        , i_Add_DB_Msg  => FALSE
                        , i_ProgramName => G_This_Package
                        );

    G_This_PO := i_PO_id;
    RETURN( PO_Tbl );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of POs.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      RAISE;
  END Get_PO_List_Within_Load;


--------------------------------------------------------------------------------
-- Function
--   Retrieve_PO_LPN_List_Internal
--
-- Description
--   This function is intended to return a list of items, belonging to the
--   specified customer PO.
--
--   This function actually return a list of items associated with all PO's on
--   the same truck (load). Receivers already have the ability to partially
--   receive a set of pallets from one order, interrupted by a pallet from
--   another order. This functionality will be extended by returning all items
--   associated with every PO included in the truck load.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_ERM_Id               VARCHAR2       Purchase Order ID
--    i_cache_flag           VARCHAR2       Cache Flag
--    i_Door_No              VARCHAR2       Door to be used for labor metrics starting point
--
--  Output:
--    o_UPC_Scan_Function    VARCHAR2       SysPar General/UPC_Scan_Function
--    o_Overage_Flg          VARCHAR2       SysPar Receiving/Overage_Flg
--    o_Key_Weight_In_RF_Rcv VARCHAR2       SysPar Receiving/Key_Weight_In_RF_RCV
--    o_Load_No              VARCHAR2       ERM.LOAD_NO associated with i_ERM_Id
--    o_Detail_Collection    LR_PO_List_Obj List of all items associated with the same truck.
--
-- Modification History
--
-- Date       User      Project       Description
-- ---------- --------- ------------- -----------------------------------------
-- 09/01/2016 bgil6182  CRQ #00008118 Authored original version.
-- 09/13/2021 bgil6182  OPCOF-3497    Due to modernization/blue yonder projects,
--                                    adding i_door_no argument back in (which was
--                                    dropped in LR merge from RDC). The door# will
--                                    be used as starting point in forklift labor
--                                    metrics.
--------------------------------------------------------------------------------

  FUNCTION Retrieve_PO_LPN_List_Internal( i_PO_Id                 IN     VARCHAR2         /* Input: Purchase Order ID */
                                        , i_cache_flag            IN     VARCHAR2         /* Input: Cache flag*/
                                        , i_Door_No               IN     VARCHAR2         /* Input: Door Number */
                                        , o_UPC_Scan_Function        OUT VARCHAR2         /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
                                        , o_Overage_Flg              OUT VARCHAR2         /* Output: RECEIVING.OVERAGE_FLG SysPar */
                                        , o_Key_Weight_In_RF_Rcv     OUT VARCHAR2         /* Output: RECEIVING.KEY_WEIGHT_IN_RF_RCV SysPar */
                                        , o_Load_No                  OUT VARCHAR2         /* Output: ERM.LOAD_NO associated with i_ERM_Id */
                                        , o_Detail_Collection        OUT LR_PO_List_Obj ) /* Output: returned table of items/pallets within the PO */
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Retrieve_PO_LPN_List_Internal' ;
    This_Message              VARCHAR2(2000 CHAR);

    l_Status                  Server_Status := PL_SWMS_Error_Codes.Normal;
    This_Load_No              ERM.Load_No%TYPE;
    l_count                   NATURAL;
    l_is_rdc                  sys_config.config_flag_val%TYPE := PL_Common.F_Get_SysPar( 'Is_RDC', 'N' );
    l_door_no                 door.door_no%TYPE;
    PO_Tbl                    LR_PO_List_Table;
    po                        LR_PO_List_Rec;
    e_fail                    EXCEPTION;
  BEGIN

-- Initialize logging
    PL_Sysco_Msg.Enable_Media( PL_Sysco_Msg.MedMeth_Window );
    PL_Sysco_Msg.Enable_Media( PL_Sysco_Msg.MedMeth_DB_Table, i_Domain => 'SWMS', i_Name => 'SWMS_LOG' );

-- Initialize for RF return

    o_UPC_Scan_Function     := NVL( PL_Common.F_Get_SysPar( 'UPC_Scan_Function' ), 'N' );
    o_Overage_Flg           := RF.NoNull( PL_Common.F_Get_SysPar( 'Overage_Flg' ) );
    o_Key_Weight_In_RF_Rcv  := RF.NoNull( PL_Common.F_Get_SysPar( 'Key_Weight_In_RF_Rcv' ) );
    o_Detail_Collection     := LR_PO_List_Obj( LR_PO_List_Table() );

-- Initialize caching
    BEGIN
      PL_RF_CACHING.Get_Cache_data(i_PO_Id);
    EXCEPTION
      WHEN OTHERS THEN
        PL_Log.Ins_Msg( 'INFO', This_Function, 'Exception occured while calling Get_Cache_data for PO#'|| nvl(i_PO_Id,'null')
                      , NULL, NULL, PL_RCV_Open_PO_Types.CT_Application_Function, G_This_Package, 'N' );
    END;

    -- Validate the door # entered on the RF
    IF UPPER( l_is_rdc ) = 'Y' THEN
      -- Validate the RDC i_Door_No against the Door master table
      -- NOTE: This code could wait for RDC/OpCo SWMS merge, but being completed now for developer understanding.
      --       This section of code will not be activated in the OpCo, unless the SysPar IS_RDC is set to Y.
      IF i_Door_No IS NULL THEN
        This_Message := /*RDC*/ 'Door number is a required parameter.';
        l_Status := PL_SWMS_Error_Codes.Inv_Location ;
      ELSE
        SELECT COUNT(*)
          INTO l_count
          FROM loc l
         WHERE l.slot_type = 'DOR'
           AND UPPER( l.logi_loc ) = i_Door_No;

        IF l_count = 0 THEN
          This_Message := /*RDC*/ 'Door_No=' || NVL( i_Door_No, 'NULL' ) || ' could not be found.';
          Pl_Log.Ins_Msg( Pl_Log.CT_Warn_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
          l_Status := PL_SWMS_Error_Codes.Inv_Location ;
        END IF;
      END IF;
    ELSE
      -- Validate the OpCo i_Door_No depending on whether forklift labor is active.
      IF PL_LMF.F_Forklift_Active THEN
        -- Did the forklift driver enter the door?
        IF ( i_Door_No IS NOT NULL ) THEN
          l_door_no := i_Door_No;
          -- If the explicit door can't be located...
          IF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN
            -- Be helpful and try to locate the door by translating alias name/number to explicit door
            l_door_no := PL_LMF.F_Get_FK_Door_No( l_door_no );
            -- If the alias door was translated successfully, then validate that door
            IF l_door_no IS NOT NULL THEN   -- alias door passed translation
              IF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN  -- validate the translated door
                This_Message := /*OpCo*/ 'Door=[' || NVL( i_Door_No, 'NULL' ) || '] could not be found.';
                l_Status := PL_SWMS_Error_Codes.Inv_Location ;
              END IF;
            ELSE
              This_Message := /*OpCo*/ 'Door=[' || NVL( i_Door_No, 'NULL' ) || '] could not be found.';
              l_Status := PL_SWMS_Error_Codes.Inv_Location ;
            END IF;
          END IF; -- explicit door was located
        ELSE  -- i_Door_No is NULL
          This_Message := /*OpCo*/ 'Door number is a required parameter.';
          l_Status := PL_SWMS_Error_Codes.Inv_Location ;
        END IF;
      ELSE  -- forklift labor is not active
        IF ( i_Door_No IS NULL ) THEN
          This_Message := /*OpCo*/ 'Door number is a required parameter.';
          l_Status := PL_SWMS_Error_Codes.Inv_Location ;
        END IF;
      END IF;
    END IF;

    IF ( l_Status <> PL_SWMS_Error_Codes.Normal ) THEN
      -- If an error occurred above, then output the saved message
      Pl_Log.Ins_Msg( Pl_Log.CT_Warn_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );
    ELSE
      -- Find the load associated with this po
      BEGIN
        -- Check if it's a finish good PO (the function also checks the finish good syspar)
        -- Added for Jira OPCOF-803 to receive a pallet from the production room
        IF pl_common.f_is_internal_production_po(i_PO_Id) THEN
          SELECT erm.load_no
            INTO This_Load_no
            FROM erm
           WHERE erm.erm_type in ('PO', 'FG') -- Internal production POs (aka Finished Good POs) can be either PO or FG erm_types. They are defined by the erm.source_id existing in the vendor_pit_zone table.
             AND erm.status IN ('OPN', 'XXCLO') --  On Nov 5, 2019 knha8378 adds XX to not allow CLO changes for LR
             AND REPLACE( erm.load_no, CHR(0), '') IS NOT NULL -- Patch where SUS may send us a string of NULL characters with a non-zero length.
             AND erm.erm_id = i_PO_Id;
        ELSE
          SELECT erm.load_no
            INTO This_Load_No
            FROM erm
           WHERE erm.erm_type in ('TR', 'PO')
             AND erm.status IN ( 'OPN' )
             AND REPLACE( erm.load_no, CHR(0), '' ) IS NOT NULL -- Patch where SUS may send us a string of NULL characters with a non-zero length.
             AND erm.erm_id = i_PO_Id;
        END IF;

        o_Load_No := This_Load_No;
        G_This_Load := This_Load_No;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          This_Message := 'Failed to locate PO #' || i_PO_Id || '.';
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => TRUE
                              , i_ProgramName => G_This_Package
                              );
          o_Load_No := NULL;
          l_Status := PL_SWMS_Error_Codes.Inv_PO;
      END;

      IF i_cache_flag = 'Y' THEN
        l_status := RF.STATUS_NO_NEW_TASK;  -- PL_SWMS_Error_Codes.No_New_Task isn't defined
        RAISE e_fail;
      ELSE
        -- Build table of just this PO (on this load) along with all items in this PO
        IF ( l_Status = PL_SWMS_Error_Codes.Normal ) THEN
          PO_Tbl := Get_PO_List_Within_Load( i_PO_Id );

          FOR po IN NVL(PO_Tbl.First,0)..NVL(PO_Tbl.Last,-1) LOOP
            This_Message := 'PO(' || TO_CHAR(po) || ').ERM_Id=' || PO_Tbl(po).ERM_Id || ', .Rec_Date=' || PO_Tbl(po).Rec_Date ;
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );

            PO_Tbl(po).Item_Table := Get_Item_List_Within_Load( PO_Tbl(po).ERM_Id, l_Status );

            IF ( l_Status <> PL_SWMS_Error_Codes.Normal ) THEN
              RAISE e_fail;
            END IF;

            This_Message := 'PO(' || TO_CHAR(po) || ').Item_Table Count=' || ( PO_Tbl(po).Item_Table.Last - PO_Tbl(po).Item_Table.First + 1 );
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
          END LOOP;

          o_Detail_Collection := LR_PO_List_Obj( PO_Tbl );
        END IF;
      END IF;
    END IF;

-- Disable logging
    PL_Sysco_Msg.Disable_Media( PL_Sysco_Msg.MedMeth_DB_Table );
    PL_Sysco_Msg.Disable_Media( PL_Sysco_Msg.MedMeth_Window );

    RETURN( l_Status );
  EXCEPTION
    WHEN e_fail THEN
      RETURN( l_Status );
    WHEN OTHERS THEN
      This_Message := 'Exception: BULK COLLECT getting list of POs.';
      l_error_code := sqlcode;
      l_error_msg := SUBSTR(SQLERRM, 1, 4000);
      pl_log.ins_msg( 'WARN', This_Function, This_Message  , l_error_code, l_error_msg);
      PL_Sysco_Msg.Disable_Media( PL_Sysco_Msg.MedMeth_DB_Table );
      PL_Sysco_Msg.Disable_Media( PL_Sysco_Msg.MedMeth_Window );
      RAISE;
  END Retrieve_PO_LPN_List_Internal;

--------------------------------------------------------------------------------
-- Function
--   Retrieve_PO_LPN_List
--
-- Description
--   This function return a list of items, referenced by the given customer PO.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_RF_Log_Init_Record   RF_Log_Init_Re RF device initialization record
--                           cord
--    i_ERM_Id               VARCHAR2       SN/PO #
--    i_Scan_Method          VARCHAR2       'S' for Scan OR 'K' for Keyboard
--
--  Output:
--    o_UPC_Scan_Function    VARCHAR2       SysPar General/UPC_Scan_Function
--    o_Overage_Flg          VARCHAR2       SysPar Receiving/Overage_Flg
--    o_Key_Weight_In_RF_Rcv VARCHAR2       SysPar Receiving/Key_Weight_In_RF_RCV
--    o_Detail_Collection    LR_PO_List_Obj
--
-- Modification History
--
-- Date       User      Project       Description
-- ---------- --------- ------------- -----------------------------------------
-- 09/01/2016 bgil6182  CRQ #00008118 Authored original version.
-- 09/13/2021 bgil6182  OPCOF-3497    Due to modernization/blue yonder projects,
--                                    adding i_door_no argument back in (which was
--                                    dropped in LR merge from RDC). The door# will
--                                    be used as starting point in forklift labor
--                                    metrics.
-- 01/26/2022 mcha1213 OPCOF-3939     add validation for LR function and Labor group and job class status
-- 									  add Labor Magement Flag validation 2/3/22
--------------------------------------------------------------------------------

  -- This function is called directly from an RF client via SOAP web service

  FUNCTION Retrieve_PO_LPN_List ( i_RF_Log_Init_Record    IN      RF_Log_Init_Record    /* Input: RF device initialization record */
                                , i_ERM_Id                IN      VARCHAR2              /* Input: Purchase Order ID */
                                , i_Scan_Method           IN      VARCHAR2              /* Input: (S)can or (K)eyboard */
                                , i_Door_No               IN      VARCHAR2 DEFAULT NULL /* Input: Door Number */
                                , o_UPC_Scan_Function        OUT  VARCHAR2              /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
                                , o_Overage_Flg              OUT  VARCHAR2              /* Output: RECEIVING.OVERAGE_FLG SysPar */
                                , o_Key_Weight_In_RF_Rcv     OUT  VARCHAR2              /* Output: RECEIVING.KEY_WEIGHT_IN_RF_RCV SysPar */
                                , o_Load_No                  OUT  VARCHAR2              /* Output: ERM.LOAD_NO associated with i_ERM_Id */
                                , o_Detail_Collection        OUT  LR_PO_List_Obj )
  RETURN RF.Status IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR) := 'Retrieve_PO_LPN_List';
    This_Message              VARCHAR2(2000 CHAR);

    RF_Status                 RF.Status     := RF.Status_Normal;
    l_server_status           Server_Status := PL_SWMS_Error_Codes.Normal;
    l_load_no                 erm.load_no%TYPE;
	
	v_lbr_grp_cnt             number;  -- 1/12/22 mcha1213

  BEGIN

    -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().

    o_UPC_Scan_Function     := RF.NoNull( '' );
    o_Overage_Flg           := RF.NoNull( '' );
    o_Key_Weight_In_RF_Rcv  := RF.NoNull( '' );
    o_Load_No               := RF.NoNull( '' );
    o_Detail_Collection     := LR_PO_List_Obj( LR_PO_List_Table( ) );

    -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

    RF_Status := RF.Initialize( i_RF_Log_Init_Record );

    -- Record input from RF device to web service

    This_Message := 'Input from RF'
                 || ': ERM_Id='      || NVL( i_ERM_Id, 'NULL' )
                 || ', Scan_Method=' || NVL( i_Scan_Method, 'NULL' )
                 || ', Door_No='     || NVL( i_Door_No, 'NULL' );
    RF.LogMsg( Message_Priority => RF.Log_Debug
             , Message_Text     => G_This_Package || '.'
                                || This_Function  || '-'
                                || G_Msg_Category || ': '
                                || This_Message );
    Pl_Log.Ins_Msg( Pl_Log.CT_Debug_Msg, This_Function, This_Message
                  , NULL, NULL, G_Msg_Category, G_This_Package );
				  
	if f_is_lr_active = 'LMN' then  -- 2/3/22 add
		G_This_Message := 'Labor Management Flag not active';
		PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                            , NULL, NULL, G_Business_Function, G_This_Package );
		RF_Status := RF.STATUS_LM_NOT_ACTIVE;
	end if;		
	

    -- Rather than removing DEFAULT NULL from wsdl, just include an extra check to disable calls with no door
    IF i_Door_No IS NULL THEN
      This_Message := 'Door number is a required parameter.';
      RF_Status := RF.Status_Inv_Location ;
    END IF;
	

	
	IF (RF_Status = RF.Status_Normal and f_is_lr_active = 'LRY') THEN

    --
    -- Announce start of call
    --
		G_This_Message := 'In RF_Status is Normal and create lr batch flag is Y';
             --      || '( i_Pallet_Id=' || NVL( i_Pallet_Id, 'NULL' )
               --    || ' )';
    --8/25/21 replace by next line PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, G_This_Message
      --            , NULL, NULL, G_This_Application, G_This_Package );

		PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, G_This_Message
                  , NULL, NULL, G_Business_Function, G_This_Package );


	-- checking for labor group

		begin

			G_This_Message := 'Checking labor group for useer_id ' || user;
			PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                            , NULL, NULL, G_Business_Function, G_This_Package );

			
			select count(*)
			into v_lbr_grp_cnt
			from usr u, sched s
			where u.user_id = user
			and   nvl(u.lgrp_lbr_grp,'XXXX')  = s.SCHED_LGRP_LBR_GRP
			and   nvl(s. SCHED_ACTV_FLAG,'N') = 'Y'
			and  s.SCHED_JBCL_JOB_CLASS in ('DM','CM','FM')  ;

			if v_lbr_grp_cnt != 3 then
			
			   G_This_Message := 'Labor group, job class DM, CM, FM is not active for user_id';
			   PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                            , NULL, NULL, G_Business_Function, G_This_Package );
			   RF_Status := RF.STATUS_LM_INV_LBR_GRP;
			end if;

							
		exception
		    /*
			WHEN NO_DATA_FOUND THEN -- modify on 1/19/22
			G_This_Message :='Bad User ID or No labor group find for useer_id '|| user;
			PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, G_This_Message
                    , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );
			G_This_Message :='Bad User ID or No labor group find for useer_id '|| user||' befre RETURN RF.STATUS_LM_INV_LBR_GRP' ;
			PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                    , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );

			RF_Status := RF.STATUS_LM_INV_LBR_GRP;
			*/
			
			when others then
			    This_Message := 'Unknown exception while checking Labor group, job class DM, CM, FM activation';
				l_error_code := sqlcode;
				l_error_msg := SUBSTR(SQLERRM, 1, 4000);
				Pl_Log.Ins_Msg( Pl_Log.CT_Warn_Msg, This_Function, This_Message, SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
				RF.LogException( );     -- log it
				raise;

		end; 	
	-- end checking for labor group	
	
	end if;

    IF ( RF_Status = RF.Status_Normal ) THEN
      -- main business logic BEGINs...

-- Door validation removed and added to Retrieve_PO_LPN_List_Internal()

      l_server_status := Retrieve_PO_LPN_List_Internal( i_ERM_Id
                                                      , 'N'
                                                      , i_Door_No               -- added OPCOF-3497
                                                      , o_UPC_Scan_Function
                                                      , o_Overage_Flg
                                                      , o_Key_Weight_In_RF_Rcv
                                                      , l_load_no
                                                      , o_Detail_Collection
                                                      );
      o_Load_No := RF.NoNull( l_load_no );
      RF_Status := l_server_status;
    END IF;
/*
 NOTE: The "Scan Method" parameter is currently not being saved anywhere on the
       database, If it needs to be in the future, this is where the modification
       should be made.
*/

    This_Message := 'Output from RF'
                 || ': UPC_Scan_Function='    || CASE o_UPC_Scan_Function    IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || o_UPC_Scan_Function    || '"' END
                 || ', Overage_Flg='          || CASE o_Overage_Flg          IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || o_Overage_Flg          || '"' END
                 || ', Key_Weight_In_RF_Rcv=' || CASE o_Key_Weight_In_RF_Rcv IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || o_Key_Weight_In_RF_Rcv || '"' END
                 || ', Load_No='              || CASE o_Load_No              IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || o_Load_No              || '"' END
                 || ', Detail_Collection=( '  || CountCollectionObjects( o_Detail_Collection ) || ' )' ;
    RF.LogMsg( Message_Priority => RF.Log_Debug
             , Message_Text     => G_This_Package || '.'
                                || This_Function  || '-'
                                || G_Msg_Category || ': '
                                || This_Message );

    RF.Complete( RF_Status );
    RETURN( RF_Status );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Unknown exception while getting the list of POs.';
      l_error_code := sqlcode;
      l_error_msg := SUBSTR(SQLERRM, 1, 4000);
      Pl_Log.Ins_Msg( Pl_Log.CT_Warn_Msg, This_Function, This_Message, SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
      RF.LogException( );     -- log it
      RAISE;
  END Retrieve_PO_LPN_List;

  FUNCTION Get_PO_Qty_Ordered( i_PO_Id            IN erm.erm_id%TYPE
                             , i_Prod_Id          IN pm.prod_id%TYPE
                             , i_Cust_Pref_Vendor IN pm.cust_pref_vendor%TYPE )
    RETURN NUMBER IS
    l_ordered_qty      erd.qty%TYPE;
  BEGIN

    -- Made changes as per issue noted at Jira 355 change done as sum(qty)instead of qty to avoid partial pallet check in issues

    SELECT sum(qty)
      INTO l_ordered_qty
      FROM erd
     WHERE erm_id = i_PO_Id
       AND prod_id = i_Prod_Id;

    RETURN l_ordered_qty;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END Get_PO_Qty_Ordered;

--------------------------------------------------------------------------------
-- Function
--   Collect_CountryOfOrigin
--
-- Description
--   This function will collect the country of origin for a pallet. The country
--   of origin is not actually stored anywhere, but if the user enables the
--   tracking flag, we just update it to reflect that it has been collected.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_Pallet_Id            VARCHAR2       Existing pallet id
--  Output:
--    None.
--
--  Returns RF.Status, possible values are:
--      0 = Normal, Successful completion
--     11 = Update_Fail, Database update failed with DB error set
--     39 = Inv_Label, Specified pallet could not be located
--     94 = Put_Done, Specified pallet has already been put away
--    112 = Lock_PO, Pallet currently locked by another user
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 11/15/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Collect_CountryOfOrigin( i_Pallet_Id  IN putawaylst.pallet_id%TYPE
                                  , i_Cool_Trk   IN Tracking_Flag
                                  ) RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30) := 'Collect_CountryOfOrigin';
    This_Data_Item  CONSTANT  VARCHAR2(30) := 'Country Of Origin';

    This_Message              VARCHAR2(2000 CHAR);
    New_Cool_Trk              Tracking_Flag;
    Lock_Cool_Trk             Tracking_Flag;
    My_Status                 Server_Status;
  BEGIN
    My_Status := PL_SWMS_Error_Codes.Normal ;

    -- Apply standard style
    New_Cool_Trk := NVL( UPPER( i_Cool_Trk ), G_Trk_No );

    -- If already collected, assume request to revalidate/recollect
    IF ( New_Cool_Trk = G_Trk_Collected ) THEN
      New_Cool_Trk := G_Trk_Yes;
    END IF;

    -- Only if tracking the country of origin, should we validate
    IF ( New_Cool_Trk = G_Trk_Yes ) THEN

-- Attempt to reserve an exclusive lock on the pallet

      BEGIN
        SELECT pal.Cool_Trk
          INTO Lock_Cool_Trk
          FROM putawaylst pal
        WHERE pal.pallet_id = i_Pallet_Id
        FOR UPDATE OF pal.Cool_Trk WAIT 5;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          This_Message := 'Specified pallet #' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => FALSE
                              , i_ProgramName => G_This_Package
                              );
          My_Status := PL_SWMS_Error_Codes.Inv_Label ;
        WHEN EXC_DB_Locked_With_NoWait OR
             EXC_DB_Locked_With_Wait   THEN
          This_Message := 'Failed to collect ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                       || ' due to the pallet being locked by someone else.';
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => FALSE
                              , i_ProgramName => G_This_Package
                              );
          My_Status := PL_SWMS_Error_Codes.Lock_PO ;
      END;

      IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
        BEGIN
          UPDATE putawaylst pal
             SET pal.cool_trk = G_Trk_Collected
           WHERE pallet_id = i_Pallet_Id;

          This_Message := This_Data_Item || ' has been collected for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => FALSE
                              , i_ProgramName => G_This_Package
                              );
        EXCEPTION
          WHEN OTHERS THEN
            This_Message := 'Failed to successfully update the ' || This_Data_Item || ' for pallet #' || i_Pallet_Id || '.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => TRUE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Update_Fail;
        END;
      END IF;
    ELSE
      This_Message := This_Data_Item || ' is not being tracked for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
    END IF;

    RETURN( My_Status );
  END Collect_CountryOfOrigin;


-------------------------------------------------------------------------------
-- Function
--   Collect_Lot
--
-- Description
--   This function will associate/disassociate a lot number with a pallet.
--   To disassociate a lot number with the pallet, p_RF_Lot_Id should be NULL
--   or call the function without the p_RF_Lot_Id argument.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_Pallet_Id            VARCHAR2       Existing pallet id
--    i_Lot_Trk              VARCHAR2       Boolean indicator flag specifying
--                                          whether the Lot Id needs to be
--                                          collected.
--    i_Lot_Id               VARCHAR2       Lot number to be associated with
--                                          the pallet. Should be NULL value
--                                          or not provided to disassociate.
--  Output:
--    None.
--
--  Returns RF.Status, possible values are:
--      0 = Normal, Successful completion
--     11 = Update_Fail, Database update failed with DB error set
--     39 = Inv_Label, Specified pallet could not be located
--     94 = Put_Done, Specified pallet has already been put away
--    112 = Lock_PO, Pallet currently locked by another user
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 09/01/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Collect_Lot( i_Pallet_Id  IN putawaylst.pallet_id%TYPE
                      , i_Lot_Trk    IN Tracking_Flag
                      , i_Lot_Id     IN putawaylst.lot_id%TYPE     DEFAULT NULL
                      ) RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30) := 'Collect_Lot';
    This_Data_Item  CONSTANT  VARCHAR2(30) := 'Lot Value';

    This_Message              VARCHAR2(2000 CHAR);

    New_Lot_Trk               Tracking_Flag;
    Lock_Lot_Trk              Tracking_Flag;

    New_Lot_Id                putawaylst.lot_id%TYPE;
    Lock_Lot_Id               putawaylst.lot_id%TYPE;

    My_Status                 Server_Status;
  BEGIN
    My_Status := PL_SWMS_Error_Codes.Normal ;

    -- Apply standard style
    New_Lot_Trk := NVL( UPPER( i_Lot_Trk ), G_Trk_No );
    New_Lot_Id  := TRIM( i_Lot_Id );

    -- If already collected, assume request to revalidate/recollect
    IF ( New_Lot_Trk = G_Trk_Collected ) THEN
      New_Lot_Trk := G_Trk_Yes;
    END IF;

    -- Only if tracking the lot number, should we validate
    IF ( New_Lot_Trk = G_Trk_Yes ) THEN

-- Attempt to reserve an exclusive lock on the pallet

      IF ( LENGTH( New_Lot_Id ) = 0 ) THEN
        This_Message := This_Data_Item || ' is required for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => FALSE
                            , i_ProgramName => G_This_Package
                            );
        My_Status := PL_SWMS_Error_Codes.Inv_Lot;
      ELSE
        Save_Lot_Id( New_Lot_Id );

-- Determine whether the user provided a valid pallet
        BEGIN
          SELECT pal.lot_trk, pal.lot_id
            INTO Lock_Lot_Trk, Lock_Lot_Id
            FROM putawaylst pal
           WHERE pal.pallet_id = i_Pallet_Id
          FOR UPDATE OF pal.lot_trk, pal.lot_id WAIT 5;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            This_Message := 'Specified pallet #' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Inv_Label ;
          WHEN EXC_DB_Locked_With_NoWait OR
               EXC_DB_Locked_With_Wait   THEN
            This_Message := 'Failed to collect ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                         || ' due to the pallet being locked by someone else.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Lock_PO ;
        END;

        IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
          BEGIN
            UPDATE putawaylst
               SET lot_trk   = G_Trk_Collected
                 , lot_id    = New_Lot_Id
             WHERE pallet_id = i_Pallet_Id ;

            This_Message := This_Data_Item || ' has been collected for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
          EXCEPTION
            WHEN OTHERS THEN
              This_Message := 'Failed to successfully update ' || This_Data_Item || ' on pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                  , i_ModuleName  => This_Function
                                  , i_Message     => This_Message
                                  , i_Category    => G_Msg_Category
                                  , i_Add_DB_Msg  => TRUE
                                  , i_ProgramName => G_This_Package
                                  );
              My_Status := PL_SWMS_Error_Codes.Update_Fail;
          END;
        END IF;
      END IF;
    ELSE
      This_Message := This_Data_Item || ' is not being tracked for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
    END IF;

    RETURN( My_Status );
  END Collect_Lot;


-------------------------------------------------------------------------------
-- Function
--   Collect_Temperature
--
-- Description
--   This function will collect the temperature associated with a pallet,
--   if any of multiple conditions are met.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_Pallet_Id            VARCHAR2       Existing pallet id
--    i_Temp_Trk             VARCHAR2       Boolean indicator flag specifying
--                                          whether the temperature needs to
--                                          be collected.
--    i_TTI_Trk              VARCHAR2       Boolean indicator flag specifying
--                                          whether temperature tracking is
--                                          enabled.
--    i_CryoVac              VARCHAR2       CryoVac Value
--    i_TTI_Value            VARCHAR2       TTI Value
--    i_Temp                 VARCHAR2       Lot number to be associated with
--                                          the pallet. Should be NULL value
--                                          or not provided to disassociate.
--  Output:
--    None.
--
--  Returns RF.Status, possible values are:
--      0 = Normal, Successful completion
--     11 = Update_Fail, Database update failed with DB error set
--     39 = Inv_Label, Specified pallet could not be located
--     94 = Put_Done, Specified pallet has already been put away
--    112 = Lock_PO, Pallet currently locked by another user
--
-- Modification History
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 09/01/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------

  FUNCTION Collect_Temperature( i_Pallet_Id     IN putawaylst.pallet_id%TYPE
                              , i_Temp_Trk      IN Tracking_Flag
                              , i_TTI_Trk       IN Tracking_Flag
                              , i_CryoVac_Value IN putawaylst.cryovac%TYPE
                              , i_TTI_Value     IN putawaylst.TTI%TYPE
                              , i_Temp_Value    IN putawaylst.temp%TYPE
                              ) RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30) := 'Collect_Temperature';
    This_Data_Item  CONSTANT  VARCHAR2(30) := 'Temperature';

    This_Message              VARCHAR2(2000 CHAR);
    Is_Temp_Reqd              BOOLEAN := FALSE;

    New_Temp_Trk              Tracking_Flag;
    New_TTI_Trk               Tracking_Flag;
    New_TTI_Value             putawaylst.tti%TYPE;
    New_CryoVac_Value         putawaylst.cryovac%TYPE;
    New_Temp_Value            putawaylst.temp%TYPE;

    Lock_Temp_Trk             Tracking_Flag;
    Lock_TTI_Trk              Tracking_Flag;
    Lock_TTI_Value            putawaylst.tti%TYPE;
    Lock_CryoVac_Value        putawaylst.cryovac%TYPE;
    Lock_Temp_Value           putawaylst.temp%TYPE;

    My_Status                 Server_Status;
  BEGIN
    My_Status := PL_SWMS_Error_Codes.Normal ;

    -- Apply standard style
    New_Temp_Trk      := NVL( UPPER( i_Temp_Trk ), G_Trk_No );
    New_TTI_Trk       := TRIM( i_TTI_Trk );
    New_TTI_Value     := NVL( UPPER( i_TTI_Value ), G_Trk_No );
    New_CryoVac_Value := NVL( UPPER( i_CryoVac_Value ), G_Trk_No );
    New_Temp_Value    := i_Temp_Value;

    -- If already collected, assume request to revalidate/recollect
    IF ( New_Temp_Trk = G_Trk_Collected ) THEN
      New_Temp_Trk := G_Trk_Yes;
    END IF;

    IF ( New_TTI_Trk = G_Trk_Collected ) THEN
      New_TTI_Trk := G_Trk_Yes;
    END IF;

    -- Only if tracking the temperature, should we validate
    IF ( ( New_Temp_Trk = G_Trk_Yes ) OR ( New_TTI_Trk = G_Trk_Yes ) ) THEN

-- Provide debug info on which tracking fields are driving temperature collection

      This_Message := '... ' || This_Data_Item || ' collection is required via ';
      IF ( New_Temp_Trk = G_Trk_Yes ) THEN
        This_Message := This_Message || 'Temperature ';
        -- If temperature tracking is enabled (whether TTI tracking is enabled or not) then temperature value is required.
        Is_Temp_Reqd := TRUE;
        IF ( New_TTI_Trk = G_Trk_Yes ) THEN
          This_Message := This_Message || 'and TTI ';
        END IF;
      ELSIF ( New_TTI_Trk = G_Trk_Yes ) THEN
        This_Message := This_Message || 'TTI ';
        -- If TTI tracking is enabled then one and only one of TTI/Cryovac values are required along with temperature value.
        Is_Temp_Reqd := ( ( New_TTI_Value = G_Trk_Yes OR New_Cryovac_Value = G_Trk_Yes ) AND
                          ( New_TTI_Value <> New_Cryovac_Value ) );
      END IF;
      This_Message := This_Message || 'tracking.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );

      IF Is_Temp_Reqd THEN
        IF New_Temp_Value IS NULL THEN
          This_Message := This_Data_Item || ' tracking has been enabled, but temperature measurement was not provided.';
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => FALSE
                              , i_ProgramName => G_This_Package
                              );
          My_Status := RF.Status_Temp_Required;
        END IF;
      END IF;

      -- If no errors have occurred, then attempt to get an exclusive lock on the pallet
      IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
        Save_TTI_Value( New_TTI_Value );
        Save_Cryovac_Value( New_CryoVac_Value );
        Save_Temp( New_Temp_Value );

        BEGIN
          SELECT pal.Temp_Trk, pal.TTI_Trk, pal.CryoVac, pal.TTI, pal.Temp
            INTO Lock_Temp_Trk, Lock_TTI_Trk, Lock_CryoVac_Value, Lock_TTI_Value, Lock_Temp_Value
            FROM putawaylst pal
           WHERE pal.pallet_id = i_Pallet_Id
          FOR UPDATE OF pal.Temp_Trk, pal.TTI_Trk, pal.CryoVac, pal.TTI, pal.Temp WAIT 5;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            This_Message := 'Specified pallet #' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Inv_Label ;
          WHEN EXC_DB_Locked_With_NoWait OR
               EXC_DB_Locked_With_Wait   THEN
            This_Message := 'Failed to collect ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                         || ' due to the pallet being locked by someone else.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
            My_Status := PL_SWMS_Error_Codes.Lock_PO ;
        END;

        IF ( My_Status = PL_SWMS_Error_Codes.Normal ) Then
          BEGIN
            UPDATE putawaylst pal
               SET pal.Temp_Trk = DECODE( New_Temp_Trk, G_Trk_Yes, G_Trk_Collected, G_Trk_No )
                 , pal.TTI_Trk  = DECODE( New_TTI_Trk , G_Trk_Yes, G_Trk_Collected, G_Trk_No )
                 , pal.TTI      = New_TTI_Value
                 , pal.CryoVac  = New_CryoVac_Value
                 , pal.Temp     = New_Temp_Value
             WHERE Pallet_Id = i_Pallet_Id;

            This_Message := This_Data_Item || ' has been collected for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
            PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                                , i_ModuleName  => This_Function
                                , i_Message     => This_Message
                                , i_Category    => G_Msg_Category
                                , i_Add_DB_Msg  => FALSE
                                , i_ProgramName => G_This_Package
                                );
          EXCEPTION
            WHEN OTHERS THEN
              This_Message := 'Failed to update ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
              PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                  , i_ModuleName  => This_Function
                                  , i_Message     => This_Message
                                  , i_Category    => G_Msg_Category
                                  , i_Add_DB_Msg  => TRUE
                                  , i_ProgramName => G_This_Package
                                  );
              My_Status := PL_SWMS_Error_Codes.Update_Fail;
          END;
        END IF;
      END IF;
    ELSE
      This_Message := This_Data_Item || ' is not being tracked for pallet #' || TO_CHAR( i_Pallet_Id ) || '.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
    END IF;

    RETURN( My_Status );
  END Collect_Temperature;


-------------------------------------------------------------------------------
-- Function
--   Check_Temp_Out_of_Range
--
-- Description
--   This function will check if a product's temperature is out of range of its
--   min_temp and max_temp from the Product Master (PM) table when Temp_Trk is Y
--
-- Parameters
--  Parameter Name    Data Type    Description
-- Input:
--  i_Product_Id      VARCHAR2(9)  Unique Product ID
--  i_Temp            NUMBER       Internal Product Temperature
--
-- Output:
--   None.
--
-- Returns Server_Status possible values are:
--    0 = Normal, Successful completion
--   42 = INV_PRODID, Invalid Product ID (Prod_Id on PM Table)
--
-- Modification History
--
-- Date       User      Jira Story  Description
-- ---------- --------- ----------- -----------------------------------------------
-- 01/26/2021 mche6435  OPCOF-3209  Authored original Version
--------------------------------------------------------------------------------
  FUNCTION Check_Temp_Out_of_Range( i_Product_Id       IN pm.prod_id%TYPE
                                  , i_Temp             IN putawaylst.temp%type
                                  , i_Cust_Pref_Vendor IN putawaylst.cust_pref_vendor%TYPE
                                  )
  return Server_Status is
    This_Function      constant  VARCHAR2(30) := 'Check_Temp_Out_of_Range';

    This_Status        server_status := PL_SWMS_Error_Codes.Normal ;
    This_Message       VARCHAR2(2000 char);

    l_Min_Temp         pm.min_temp%type;
    l_Max_Temp         pm.max_temp%type;
    l_Temp_Trk         pm.temp_trk%type;
  BEGIN
    BEGIN
      -- Compare to impossible values to cause a report to be generated
      SELECT NVL(min_temp, 999), NVL(max_temp, -999), NVL(temp_trk, 'N')
      INTO l_Min_Temp, l_Max_Temp, l_Temp_Trk
      FROM pm
      WHERE pm.prod_id = i_Product_Id AND pm.cust_pref_vendor = i_Cust_Pref_Vendor;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- Fail if item does not exist in the pm table
        This_Message := 'Product ID: ' || i_Product_Id || ' not found in PM table';
        PL_Sysco_Msg.Msg_Out( i_level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_modulename  => This_Function
                            , i_message     => This_Message
                            , i_category    => G_Msg_Category
                            , i_add_db_msg  => TRUE
                            , i_programname => G_This_Package
                            );
        RETURN PL_SWMS_Error_Codes.INV_PRODID;
    END;

    -- For Debugging Purposes
    This_Message := 'DEBUG VALUES |'
                 || ' i_Product_Id: '         || i_Product_Id
                 || ', i_Cust_Pref_Vendor: '  || i_Cust_Pref_Vendor
                 || ', Temp_Trk: '            || l_Temp_Trk
                 || ', Min_Temp: '            || l_Min_Temp
                 || ', Max_Temp: '            || l_Max_Temp
                 || ', i_Temp: '              || i_Temp;

    PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => G_Msg_Category
                        , i_Add_DB_Msg  => TRUE
                        , i_ProgramName => G_This_Package
                        );

    -- Only apply this change if temperature tracking is enabled
    IF ( l_Temp_Trk = 'Y' ) THEN
      This_Message := 'Temp track is enabled, checking if temperature is out of range';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );

      IF ( i_Temp < l_Min_Temp OR i_Temp > l_Max_Temp) THEN
        -- Temperature is out of range, save that it is out of range
        Save_Adj_Flag('O');
      END IF;
    END IF;
    RETURN( This_Status );
  END Check_Temp_Out_of_Range;

-------------------------------------------------------------------------------
-- Function
--   Collect_Reqd_Data
--
-- Description
--   This function will group all data collection associated with a pallet
--   beyond the expiration, manufactured, and harvest dates.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_Pallet_Id            VARCHAR2       Existing unique pallet id
--    i_Prod_Id              VARCHAR2       Unique product id
--    i_Exp_Date_Trk         Tracking_Flag  Tracking flag for Sysco expiration
--                                          date
--    i_Exp_Date             VARCHAR2       Sysco expiration date
--    i_Cust_Shelf_Life      NUMBER         Minimum Customer-required days of
--                                          shelf life
--    i_Sysco_Shelf_Life     NUMBER         Minimum Sysco-required days of shelf
--                                          life
--    i_Mfr_Date_Trk         Tracking_Flag  Tracking flag for Manufacturer
--                                          expiration date
--    i_Mfr_Date             VARCHAR2       Manufacturer expiration date
--    i_Mfr_Shelf_Life       NUMBER         Minimum Manufacturer-required days
--                                          of shelf life
--    i_Cool_Trk             Tracking_Flag  Tracking flag for Country of origin
--    i_Lot_Trk              Tracking_Flag  Tracking flag for Lot number
--    i_Lot_Id               VARCHAR2       Lot number
--    i_Temp_Trk             Tracking_Flag  Tracking flag for internal product
--                                          temperature
--    i_CryoVac              VARCHAR2       Tracking flag for meat product
--    i_Temp                 NUMBER         Internal product temperature
--    i_TTI_Trk              Tracking_Flag  Tracking flag for Temperature
--                                          Tracking Indicator (product
--                                          transport compartment)
--                                          compartment
--    i_TTI                  VARCHAR2       Temperature Tracking Indicator
--    i_Clam_Bed_Trk         Tracking_Flag  Tracking flag for Clam_Bed
--    i_Harvest_Date         VARCHAR2       Clam Harvest Date
--    i_Clam_Bed_Num         VARCHAR2       Clam Bed Identifier
--  Output:
--    o_Expiration_Warn      Server_Status  Warning flag for expiration date
--    o_Harvest_Warn         Server_Status  Warning flag for clam harvest date
--
--  Returns Server_Status, possible values are:
--      0 = Normal, Successful completion
--     11 = Update Failure, database update failed with DB error set
--
-- Modification History:
--
-- Date       User      CRQ #    Description
-- ---------- --------- -------- -----------------------------------------------
-- 11/15/2016 bgil6182  00008118 Authored original version.
--------------------------------------------------------------------------------
  FUNCTION Collect_Reqd_Data( i_Pallet_Id         IN      putawaylst.pallet_id%TYPE
                            , i_Prod_Id           IN      pm.prod_id%TYPE
                            , i_Exp_Date_Trk      IN OUT  Tracking_Flag
                            , i_Exp_Date          IN      putawaylst.exp_date%TYPE
                            , i_Date_Override     IN      VARCHAR2
                            , i_Cust_Shelf_Life   IN      pm.cust_shelf_life%TYPE
                            , i_Sysco_Shelf_Life  IN      pm.sysco_shelf_life%TYPE
                            , i_Mfr_Date_Trk      IN OUT  Tracking_Flag
                            , i_Mfr_Date          IN      putawaylst.mfg_date%TYPE
                            , i_Mfr_Shelf_Life    IN      pm.mfr_shelf_life%TYPE
                            , i_Cool_Trk          IN OUT  Tracking_Flag
                            , i_Lot_Trk           IN OUT  Tracking_Flag
                            , i_Lot_Id            IN      putawaylst.lot_id%TYPE
                            , i_Temp_Trk          IN OUT  Tracking_Flag
                            , i_CryoVac           IN      putawaylst.cryovac%TYPE
                            , i_Temp              IN      putawaylst.temp%TYPE
                            , i_TTI_Trk           IN OUT  Tracking_Flag
                            , i_TTI               IN      putawaylst.TTI%TYPE
                            , i_Clam_Bed_Trk      IN OUT  Tracking_Flag
                            , i_Harvest_Date      IN      VARCHAR2        /* Input:  Clam Harvest Date, Format: MMDDYY */
                            , i_Clam_Bed_Num      IN      VARCHAR2
                            , o_Expiration_Warn       OUT Server_Status
                            , o_Harvest_Warn          OUT Server_Status
                            ) RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30) := 'Collect_Reqd_Data';

    This_Data_Item            VARCHAR2(50);
    My_Status                 Server_Status;
    Derived_Exp_Date          PutAwayLst.Exp_Date%TYPE;
    l_Derived_Exp_hrv_Date    PutAwayLst.Exp_Date%TYPE;
    New_Exp_Date_Trk          Tracking_Flag;
    New_Mfr_Date_Trk          Tracking_Flag;
    Lock_Date                 PutAwayLst.Exp_Date%TYPE;
    This_Message              VARCHAR2(2000 CHAR);
    My_Msg_Level              PL_Sysco_Msg.MessageLevelType := PL_Sysco_Msg.MsgLvl_Default ;
    Add_DB_Errors             BOOLEAN;
    Lock_Clam_Bed_Trk         putawaylst.clam_bed_trk%TYPE;
    PO_Id                     putawaylst.rec_id%TYPE;
    l_Hrv_Warn                Server_Status;
    language_id               NUMBER;
  BEGIN
    My_Status := PL_SWMS_Error_Codes.Normal;

    This_Message := '( i_Pallet_Id='        || NVL( i_Pallet_Id                            , 'NULL' )
                 || ', i_Prod_Id='          || NVL( i_Prod_Id                              , 'NULL' )
                 || ', i_Exp_Date_Trk='     || NVL( i_Exp_Date_Trk                         , 'NULL' )
                 || ', i_Exp_Date='         || NVL( TO_CHAR( i_Exp_Date, G_Rf_Date_Format ), 'NULL' )
                 || ', i_Date_Override='    || NVL( i_Date_Override                        , 'NULL' )
                 || ', i_Cust_Shelf_Life='  || NVL( TO_CHAR( i_Cust_Shelf_Life )           , 'NULL' )
                 || ', i_Sysco_Shelf_Life=' || NVL( TO_CHAR( i_Sysco_Shelf_Life )          , 'NULL' )
                 || ', i_Mfr_Date_Trk='     || NVL( i_Mfr_Date_Trk                         , 'NULL' )
                 || ', i_Mfr_Date='         || NVL( TO_CHAR( i_Mfr_Date, G_Rf_Date_Format ), 'NULL' )
                 || ', i_Mfr_Shelf_Life='   || NVL( TO_CHAR( i_Mfr_Shelf_Life )            , 'NULL' )
                 || ', i_Cool_Trk='         || NVL( i_Cool_Trk                             , 'NULL' )
                 || ', i_Lot_Trk='          || NVL( i_Lot_Trk                              , 'NULL' )
                 || ', i_Lot_Id='           || NVL( i_Lot_Id                               , 'NULL' )
                 || ', i_Temp_Trk='         || NVL( i_Temp_Trk                             , 'NULL' )
                 || ', i_CryoVac='          || NVL( i_CryoVac                              , 'NULL' )
                 || ', i_Temp='             || NVL( TO_CHAR( i_Temp )                      , 'NULL' )
                 || ', i_TTI_Trk='          || NVL( i_TTI_Trk                              , 'NULL' )
                 || ', i_TTI='              || NVL( i_TTI                                  , 'NULL' )
                 || ' )';
    PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                        , This_Function
                        , This_Message
                        , G_Msg_Category
                        , FALSE
                        , G_This_Package );

    o_Expiration_Warn := PL_SWMS_Error_Codes.Normal;
    o_Harvest_Warn    := PL_SWMS_Error_Codes.Normal;

    New_Exp_Date_Trk  := NVL( UPPER( i_Exp_Date_Trk), G_Trk_No );
    New_Mfr_Date_Trk  := NVL( UPPER( i_Mfr_Date_Trk), G_Trk_No );

    IF ( New_Exp_Date_Trk = G_Trk_Collected ) THEN
      New_Exp_Date_Trk := G_Trk_Yes;
    END IF;

    IF ( New_Mfr_Date_Trk = G_Trk_Collected ) THEN
      New_Mfr_Date_Trk := G_Trk_Yes;
    END IF;

/*******************/
/* Expiration Date */
/*******************/
    -- If the receiver has enabled expiration date tracking, then validate the expiration date
    IF ( New_Exp_Date_Trk = G_Trk_Yes ) THEN
      This_Data_Item := 'Expiration Date';
      My_Status := Check_Exp_Date( i_Pallet_Id      , i_Exp_Date_Trk    , i_Exp_Date
                                 , i_Cust_Shelf_Life, i_Sysco_Shelf_Life, i_Mfr_Shelf_Life, i_Date_Override );
      IF ( My_Status = PL_SWMS_Error_Codes.Invalid_Exp_Date ) THEN
        -- Exp_Date either fails the assumed format requirements or unrelated DB error
        This_Message := This_Data_Item || ' failed validation for pallet #' || TO_CHAR( i_Pallet_Id );
        RF.LogMsg( Message_Priority => RF.Log_Err
                 , Message_Text     => G_This_Package || '.'
                                    || This_Function  || '-'
                                    || G_Msg_Category || ': '
                                    || This_Message );
        PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                            , This_Function
                            , This_Message
                            , G_Msg_Category
                            , TRUE
                            , G_This_Package );
      ELSIF ( My_Status = PL_SWMS_Error_Codes.Sys_Cust_Warn ) THEN
        -- Exp_Date does not meet Sysco/Customer shelf life minimums
        This_Message := This_Data_Item || ' has exceeded Customer and Sysco shelf lives for pallet #' || TO_CHAR( i_Pallet_Id );
        RF.LogMsg( Message_Priority => RF.Log_Err
                 , Message_Text     => G_This_Package || '.'
                                    || This_Function  || '-'
                                    || G_Msg_Category || ': '
                                    || This_Message );
        PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                            , This_Function
                            , This_Message
                            , G_Msg_Category
                            , FALSE
                            , G_This_Package );
      ELSIF ( My_Status = PL_SWMS_Error_Codes.Mfr_Shelf_Warn ) THEN
        -- Exp_Date does not meet manufacturer shelf life minimums
        This_Message := This_Data_Item || ' has exceeded manufacturer shelf life for pallet #' || TO_CHAR( i_Pallet_Id );
        RF.LogMsg( Message_Priority => RF.Log_Err
                 , Message_Text     => G_This_Package || '.'
                                    || This_Function  || '-'
                                    || G_Msg_Category || ': '
                                    || This_Message );
        PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                            , This_Function
                            , This_Message
                            , G_Msg_Category
                            , FALSE
                            , G_This_Package );
        ELSIF ( My_Status = PL_SWMS_Error_Codes.Trans_Insert_Failed ) THEN
        -- Failed to create DTO transaction while overriding exp date
        This_Message := This_Data_Item || ' Failed to create DTO transaction for Pallet  ' || i_Pallet_Id || '.';
        RF.LogMsg( Message_Priority => RF.Log_Err
                 , Message_Text     => G_This_Package || '.'
                                    || This_Function  || '-'
                                    || G_Msg_Category || ': '
                                    || This_Message );
        PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                            , This_Function
                            , This_Message
                            , G_Msg_Category
                            , FALSE
                            , G_This_Package );
      ELSE
        -- If expiration date is within configured warning days from expiration, then notify receiver.
        IF Within_Warning_Period( i_Exp_Date_Trk, i_Exp_Date ) THEN
          This_Message := This_Data_Item || ' falls within the warning period for pallet #' || TO_CHAR( i_Pallet_Id );
          RF.LogMsg( Message_Priority => RF.Log_Warning
                   , Message_Text     => G_This_Package || '.'
                                      || This_Function  || '-'
                                      || G_Msg_Category || ': '
                                      || This_Message );
          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Warning
                              , This_Function
                              , This_Message
                              , G_Msg_Category
                              , FALSE
                              , G_This_Package );
          o_Expiration_Warn := PL_SWMS_Error_Codes.Exp_Warn;  -- Notify RF device also.
--        ELSE
--          This_Message := This_Data_Item || ' has passed validation.';
--          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
--                              , This_Function
--                              , This_Message
--                              , G_Msg_Category
--                              , FALSE
--                              , G_This_Package );
        END IF; /* Within_Warning_Period */
      END IF; /* Check_Exp_Date was successful */

      IF ( My_Status != PL_SWMS_Error_Codes.Invalid_Exp_Date ) THEN
        -- If exp date is valid, check if exp date is > sysdate + 7days
        IF i_Exp_Date > trunc(sysdate + 7) THEN
          select rec_id
          into PO_Id
          from putawaylst
          where pallet_id = i_Pallet_Id;

          select config_flag_val into language_id
          from sys_config
          where config_flag_name = 'LANGUAGE_ENABLE';

          STRING_TRANSLATION.SET_CURRENT_LANGUAGE(language_id);

          --Insert a message into swms_failure_event to send an expiration date alert email
          pl_event.ins_failure_event(
            'EXPIRATION_DATE',
            'Q',
            'WARN',
            i_Prod_Id,
            STRING_TRANSLATION.GET_STRING(120119, i_Prod_Id, i_Pallet_Id, Po_Id),
            STRING_TRANSLATION.GET_STRING(120116, i_Prod_Id, i_Pallet_Id, Po_Id, to_char(i_Exp_Date, 'DD-MON-YYYY')));
        END IF;
      END IF;

    END IF; /* Tracking by expiration date? */

/*********************/
/* Manufactured Date */
/*********************/
    -- If the receiver has enabled manufacturer's expiration date tracking, then validate the manufacturer's expiration date
    IF ( New_Mfr_Date_Trk = G_Trk_Yes ) THEN
      This_Data_Item := 'Manufactured Date';
      IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
        -- Since Exp and Mfr dates share the same status parameter, if not already set then perform the Mfr date check
        IF ( o_Expiration_Warn = PL_SWMS_Error_Codes.Normal ) THEN
          My_Status := Check_Mfr_Date( i_Pallet_Id     , i_Mfr_Date_Trk  , i_Mfr_Date
                                    , i_Mfr_Shelf_Life, i_Date_Override, Derived_Exp_Date );
          IF ( My_Status = PL_SWMS_Error_Codes.Invalid_Mfg_Date ) THEN
            -- Mfr_Date either fails the assumed format requirements or unrelated DB error
            This_Message := This_Data_Item || ' has failed validation for pallet #' || TO_CHAR( i_Pallet_Id );
            RF.LogMsg( Message_Priority => RF.Log_Err
                     , Message_Text     => G_This_Package || '.'
                                        || This_Function  || '-'
                                        || G_Msg_Category || ': '
                                        || This_Message );
            PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                                , This_Function
                                , This_Message
                                , G_Msg_Category
                                , TRUE
                                , G_This_Package );
          ELSIF ( My_Status = PL_SWMS_Error_Codes.Mfr_Shelf_Warn ) THEN
            -- Mfr_Date does not meet manufacturer shelf life minimum
            This_Message := This_Data_Item || ' has exceeded the shelf life, (Manufacturer=' || TO_CHAR( i_Mfr_Date, 'DD-Mon-YYYY' ) || ') for pallet #' || TO_CHAR( i_Pallet_Id )
                            || ', i_Date_Override = '|| NVL(i_Date_Override,'N');
            RF.LogMsg( Message_Priority => RF.Log_Err
                     , Message_Text     => G_This_Package || '.'
                                        || This_Function  || '-'
                                        || G_Msg_Category || ': '
                                        || This_Message );
            PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                                , This_Function
                                , This_Message
                                , G_Msg_Category
                                , FALSE
                                , G_This_Package );
          ELSE
            This_Message := This_Data_Item || ' passed validation. Updating pallet#' || TO_CHAR( i_Pallet_Id ) || 'with derived expiration date.';
            PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                                , This_Function
                                , This_Message
                                , G_Msg_Category
                                , FALSE
                                , G_This_Package );

            -- Attempt to place an exclusive lock on the pallet's expiration date field.
            BEGIN
              SELECT pal.Exp_Date
                INTO Lock_Date
                FROM PutAwayLst pal
               WHERE pal.Pallet_Id = i_Pallet_Id
              FOR UPDATE OF pal.Exp_Date WAIT 5;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                This_Message := 'Specified pallet ' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => FALSE
                                    , i_ProgramName => G_This_Package
                                    );
                My_Status := PL_SWMS_Error_Codes.Inv_Label ;
              WHEN EXC_DB_Locked_With_NoWait OR
                   EXC_DB_Locked_With_Wait   THEN
                This_Message := 'Failed to save ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                             || ' due to the pallet being locked by someone else.';
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => FALSE
                                    , i_ProgramName => G_This_Package
                                    );
                My_Status := PL_SWMS_Error_Codes.Lock_PO ;
            END;

            IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
              BEGIN
                -- We have the lock in place. Now, update the pallet.
                UPDATE PutAwayLst pal
                   SET pal.Exp_Date = Derived_Exp_Date
                 WHERE pal.pallet_id = i_Pallet_Id;
              EXCEPTION
                WHEN OTHERS THEN
                  This_Message := 'Failed to successfully update the ' || This_Data_Item || ' for pallet ' || i_Pallet_Id || '.';
                  PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                      , i_ModuleName  => This_Function
                                      , i_Message     => This_Message
                                      , i_Category    => G_Msg_Category
                                      , i_Add_DB_Msg  => TRUE
                                      , i_ProgramName => G_This_Package
                                      );
                  My_Status := PL_SWMS_Error_Codes.Update_Fail;
              END;
            END IF;

            -- If manufacturer's expiration date is within configured warning days from expiration, then notify receiver.
            IF Within_Warning_Period( i_Mfr_Date_Trk, Derived_Exp_Date ) THEN
              This_Message := This_Data_Item || ' falls within the warning period for pallet #' || TO_CHAR( i_Pallet_Id );
              RF.LogMsg( Message_Priority => RF.Log_Warning
                       , Message_Text     => G_This_Package || '.'
                                          || This_Function  || '-'
                                          || G_Msg_Category || ': '
                                          || This_Message );
              PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Warning
                                  , This_Function
                                  , This_Message
                                  , G_Msg_Category
                                  , FALSE
                                  , G_This_Package );
              o_Expiration_Warn := PL_SWMS_Error_Codes.Past_Shelf_Warn ;    -- Notify RF device also.
            -- ELSE
            --   This_Message := 'Manufacturing date has passed validation.';
            --   PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
            --                       , This_Function
            --                       , This_Message
            --                       , G_Msg_Category
            --                       , FALSE
            --                       , G_This_Package );
            END IF;   -- Check_Mfr_Date returned an error
          END IF;
        ELSE
          This_Message := 'Check_Exp_Date() call succeeded but raised a shared warning flag. Skipping validation of the ' || This_Data_Item || '.';
          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                              , This_Function
                              , This_Message
                              , G_Msg_Category
                              , FALSE
                              , G_This_Package );
        END IF;   -- o_Expiration_Warn was not already set by Check_Exp_Date()
      ELSE
        This_Message := 'Check_Exp_Date() call failed. Skipping validation of the ' || This_Data_Item || ' call failed. Skipping validation for Pallet# ' || TO_CHAR( i_Pallet_Id ) || '.';
        PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                            , This_Function
                            , This_Message
                            , G_Msg_Category
                            , FALSE
                            , G_This_Package );
      END IF; /* Error occurred on expiration date. Sharing warning flag, so skip the manufacturer date. */
    END IF; /* Tracking by manufacturer date? */

/****************/
/* Harvest Date */
/****************/
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
      -- If pallet is being reprocessed, reset tracking flag from collected to yes.
      IF ( i_Clam_Bed_Trk = G_Trk_Collected AND i_Harvest_Date IS NOT NULL ) THEN
        i_Clam_Bed_Trk := G_Trk_Yes;
      END IF;

      -- If Harvest date needs to be validated
      IF ( i_Clam_Bed_Trk = G_Trk_Yes ) THEN
        This_Message := 'Calling Check_Harvest_Date() to validate harvest date for pallet #' || TO_CHAR( i_Pallet_Id ) ;
        PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                            , This_Function
                            , This_Message
                            , G_Msg_Category
                            , FALSE
                            , G_This_Package
                            );

        This_Data_Item := 'Harvest Date';
        My_Status := Check_Harvest_Date( i_Clam_Bed_Trk
                                       , i_Clam_Bed_Num
                                       , TO_DATE( i_Harvest_Date, G_RF_Date_Format )
                                       , i_Mfr_Shelf_Life
                                       , i_Mfr_Date
                                       , i_Exp_Date
                                       , l_Hrv_Warn
                                       );

        IF ( My_Status = PL_SWMS_Error_Codes.Invalid_Hrv_Date ) THEN
          -- Harvest_Date either fails the assumed format requirements or unrelated DB error
          This_Message := This_Data_Item || ' Invalid_Hrv_Date failed validation for pallet #' || TO_CHAR( i_Pallet_Id );
          RF.LogMsg( Message_Priority => RF.Log_Err
                   , Message_Text     => G_This_Package || '.'
                                      || This_Function  || '-'
                                      || G_Msg_Category || ': '
                                      || This_Message );
          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                              , This_Function
                              , This_Message
                              , G_Msg_Category
                              , TRUE
                              , G_This_Package );
        ELSIF ( My_Status = PL_SWMS_Error_Codes.Hrv_Date_Warn AND i_Mfr_Date IS NOT NULL ) THEN
          -- The harvest date is less than the mfg date.
          This_Message := This_Data_Item || ' The harvest date is less than the mfg date for pallet #' || TO_CHAR( i_Pallet_Id );
          RF.LogMsg( Message_Priority => RF.Log_Err
                   , Message_Text     => G_This_Package || '.'
                                      || This_Function  || '-'
                                      || G_Msg_Category || ': '
                                      || This_Message );
          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                              , This_Function
                              , This_Message
                              , G_Msg_Category
                              , FALSE
                              , G_This_Package );
        ELSIF ( My_Status = PL_SWMS_Error_Codes.Hrv_Date_Warn AND i_Exp_Date IS NOT NULL ) THEN
          -- The harvest date should not be greater than the expiration date.
          This_Message := This_Data_Item || ' The harvest date should not be greater than the expiration date for pallet #' || TO_CHAR( i_Pallet_Id );
          RF.LogMsg( Message_Priority => RF.Log_Err
                   , Message_Text     => G_This_Package || '.'
                                      || This_Function  || '-'
                                      || G_Msg_Category || ': '
                                      || This_Message );
          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                              , This_Function
                              , This_Message
                              , G_Msg_Category
                              , FALSE
                              , G_This_Package );
        ELSIF ( My_Status = PL_SWMS_Error_Codes.Past_Shelf_Warn ) THEN
          -- The item is past its shelf life
          This_Message := This_Data_Item || ' has exceeded the shelf life, (Harvest Date =' || TO_CHAR( to_date(i_Harvest_Date,G_RF_Date_Format), 'DD-Mon-YYYY' ) || ') for pallet #' || TO_CHAR( i_Pallet_Id );
          RF.LogMsg( Message_Priority => RF.Log_Err
                   , Message_Text     => G_This_Package || '.'
                                      || This_Function  || '-'
                                      || G_Msg_Category || ': '
                                      || This_Message );
          PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Error
                              , This_Function
                              , This_Message
                              , G_Msg_Category
                              , FALSE
                              , G_This_Package );
        ELSE
          My_Status := Insert_RHB_Trans( i_Pallet_Id, TO_DATE( i_Harvest_Date, G_RF_Date_Format ), i_Clam_Bed_Num, i_Temp ) ;
          IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
            BEGIN
              SELECT pal.clam_bed_trk
                INTO Lock_Clam_Bed_Trk
                FROM PutAwayLst pal
               WHERE pal.Pallet_Id = i_Pallet_Id
              FOR UPDATE OF pal.Exp_Date WAIT 5;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                This_Message := 'Specified pallet ' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => FALSE
                                    , i_ProgramName => G_This_Package
                                    );
                My_Status := PL_SWMS_Error_Codes.Inv_Label ;
              WHEN EXC_DB_Locked_With_NoWait OR
                   EXC_DB_Locked_With_Wait   THEN
                This_Message := 'Failed to save ' || This_Data_Item || ' for pallet #' || TO_CHAR( i_Pallet_Id )
                             || ' due to the pallet being locked by someone else.';
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => FALSE
                                    , i_ProgramName => G_This_Package
                                    );
                My_Status := PL_SWMS_Error_Codes.Lock_PO ;
            END;
          END IF;
          IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
            BEGIN
              -- We have the lock in place. Now, update the pallet.
              UPDATE PutAwayLst pal
                 SET clam_bed_trk = G_Trk_Collected
              WHERE pal.pallet_id = i_Pallet_Id;
            EXCEPTION
              WHEN OTHERS THEN
                This_Message := 'Failed to successfully update the ' || This_Data_Item || ' for pallet ' || i_Pallet_Id || '.';
                PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                                    , i_ModuleName  => This_Function
                                    , i_Message     => This_Message
                                    , i_Category    => G_Msg_Category
                                    , i_Add_DB_Msg  => TRUE
                                    , i_ProgramName => G_This_Package
                                    );
                My_Status := PL_SWMS_Error_Codes.Update_Fail;
            END;
          END IF;

          IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
            -- If harvest date is within configured warning days, then notify receiver.
            IF NVL( l_Hrv_Warn, 0 ) > 0 THEN
              This_Message := This_Data_Item || ' falls within the warning period for pallet #' || TO_CHAR( i_Pallet_Id );
              RF.LogMsg( Message_Priority => RF.Log_Warning
                       , Message_Text     => G_This_Package || '.'
                                          || This_Function  || '-'
                                          || G_Msg_Category || ': '
                                          || This_Message );
              PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Warning
                                  , This_Function
                                  , This_Message
                                  , G_Msg_Category
                                  , FALSE
                                  , G_This_Package );
              o_Harvest_Warn := l_Hrv_Warn;  -- Notify RF device also.
            END IF; /* Harvest warning set? */
          END IF; /* Harvest date tracking flag updated? */
        END IF; /* Check_Harvest_Date successful? */
      END IF; /* Tracking by harvest date? */
    END IF; /* No previous errors occurred? */

/*********************/
/* Country of Origin */
/*********************/
    IF ( My_Status = PL_SWMS_Error_Codes.Normal ) THEN
    -- Second, perform data collection of all necessary configured items
      My_Msg_Level   := PL_Sysco_Msg.MsgLvl_Error;
      Add_DB_Errors  := TRUE;
      This_Data_Item := 'Country Of Origin';
      My_Status := Collect_CountryOfOrigin( i_Pallet_Id, i_Cool_Trk );
      IF ( My_Status <> PL_SWMS_Error_Codes.Normal ) THEN
        This_Message := 'Failed to collect ' || This_Data_Item;
      ELSE
/**********/
/* Lot Id */
/**********/
        This_Data_Item := 'Lot Value';
        My_Status := Collect_Lot( i_Pallet_Id, i_Lot_Trk, i_Lot_Id );
        IF ( My_Status <> PL_SWMS_Error_Codes.Normal ) THEN
          This_Message := 'Failed to collect ' || This_Data_Item;
        ELSE
/***************/
/* Temperature */
/***************/
          This_Data_Item := 'Temperature';
          My_Status := Collect_Temperature( i_Pallet_Id, i_Temp_Trk, i_TTI_Trk
                                          , i_CryoVac, i_TTI, i_Temp );
          IF ( My_Status <> PL_SWMS_Error_Codes.Normal ) THEN
            This_Message := 'Failed to collect ' || This_Data_Item;
          ELSE
            My_Status := Check_Temp_Out_of_Range( i_Prod_ID, i_Temp, G_TrxData.Cust_Pref_Vendor );
            IF ( My_Status <> PL_SWMS_Error_Codes.Normal ) THEN
              This_Message := 'Failed to check if temperature is out of range';
            ELSE
/**********/
/* Weight */
/**********/
--            This_Data_Item := 'Weight';
--            My_Status := Collect_Weight( i_Pallet_Id );
--            IF ( My_Status <> PL_SWMS_Error_Codes.Normal ) THEN
--              This_Message := 'Failed to collect ' || This_Data_Item;
--            ELSE
              This_Message := 'All data collected';
              My_Msg_Level := PL_Sysco_Msg.MsgLvl_Info;
              Add_DB_Errors := FALSE;
--            END IF;
            END IF;
          END IF; /* Temperature collected successfully? */
        END IF; /* Lot Id collected successfully? */
      END IF; /* Country Of Origin collected successfully? */

      PL_Sysco_Msg.Msg_Out( My_Msg_Level
                          , This_Function
                          , This_Message || ' successfully for pallet ' || TO_CHAR( i_Pallet_Id ) || '.'
                          , G_Msg_Category
                          , Add_DB_Errors
                          , G_This_Package );
    END IF;

    This_Message := '( o_Expiration_Warn='  || NVL( TO_CHAR( o_Expiration_Warn ), 'NULL' )
                 || ', o_Harvest_Warn='     || NVL( TO_CHAR( o_Harvest_Warn )   , 'NULL' )
                 || ' )';
    PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                        , This_Function
                        , This_Message
                        , G_Msg_Category
                        , FALSE
                        , G_This_Package );

    RETURN( My_Status );
  END Collect_Reqd_Data;
-------------------------------------------------------------------------------
-- Function   PostQtyReceived
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 06/12/2019 xzhe5043  JIRA:OPCOF-2217 update qty_received with qty_produced
--                                      putaway status ='CHK'
--------------------------------------------------------------------------------
  FUNCTION PostQtyReceived( i_Pallet_Id     IN  VARCHAR2
                          , i_Qty_Received  IN  NUMBER
                          )
    RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR)  := 'PostQtyReceived' ;

    This_Message              VARCHAR2(2000 CHAR);

    This_Status               Server_Status := PL_SWMS_Error_Codes.Normal;
    l_Qty_Received            putawaylst.qty_received%TYPE;
    l_Qty_Produced            inv.qty_produced%TYPE;
    l_Finish_Good_Ind         pm.finish_good_ind%TYPE;
    l_Dest_Loc                putawaylst.dest_loc%TYPE;
    l_Inv_Dest_Loc            putawaylst.inv_dest_loc%TYPE;
    l_Home_Slot_Flag          CHAR := 'N';
  BEGIN
    This_Message := 'Adjustment necessary between expected vs. received quantities.' ;
    PL_Sysco_Msg.Msg_Out( PL_Sysco_Msg.MsgLvl_Debug
                        , This_Function
                        , This_Message
                        , G_Msg_Category
                        , FALSE
                        , G_This_Package
                        );

    IF (pl_common.f_is_internal_production_po(G_TrxData.PO_Id)) THEN
      -- Attempt to place an exclusive lock on the pallet/inventory to record quantity produced, give 5 seconds
      SELECT pal.qty_produced, pal.dest_loc, NVL(pal.inv_dest_loc, 'NULL')
        INTO l_Qty_Produced, l_Dest_loc, l_Inv_Dest_Loc
        FROM putawaylst pal
       WHERE pal.pallet_id = i_Pallet_Id
         FOR UPDATE OF qty_produced WAIT 5;

      BEGIN
        SELECT 'Y'
        INTO l_Home_Slot_Flag
        FROM inv
        WHERE logi_loc = DECODE(l_Inv_Dest_Loc, 'NULL', l_Dest_loc, l_Inv_Dest_Loc)
        AND plogi_loc = logi_loc;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_Home_Slot_Flag := 'N';
      END;

      -- Exclusive lock is held, now let's perform the update.
      UPDATE putawaylst pal
         SET pal.qty_produced = i_Qty_Received,
         pal.qty_received = i_Qty_Received,
         pal.status = 'CHK'
       WHERE pal.pallet_id = i_Pallet_Id;

      UPDATE inv
         SET qty_produced = i_Qty_Received
       WHERE logi_loc = DECODE( -- Update inv using dest loc (home slot) or update using the pallet_id
                          l_Home_Slot_Flag, 'N', i_Pallet_Id,
                          DECODE(l_Inv_Dest_Loc, 'NULL', l_Dest_loc, l_Inv_Dest_Loc));


    ELSE
      -- Attempt to place an exclusive lock on this pallet to record quantity received, give 5 seconds
      This_Message := 'Updating PutAwayLst.Qty_Received';
      PL_Log.Ins_Msg( i_msg_type         => Pl_Log.CT_Info_Msg
                    , i_procedure_name   => This_Function
                    , i_msg_text         => This_Message
                    , i_msg_no           => NULL
                    , i_sql_err_msg      => NULL
                    , i_application_func => G_Msg_Category
                    , i_program_name     => G_This_Package
                    );
      SELECT pal.qty_received
        INTO l_Qty_Received
        FROM putawaylst pal
      WHERE pal.pallet_id = i_Pallet_Id
        FOR UPDATE OF qty_received WAIT 5;

      -- Exclusive lock is held, now let's perform the update.
      UPDATE putawaylst pal
        SET pal.qty_received = i_Qty_Received
      WHERE pal.pallet_id = i_Pallet_Id;

    END IF;

    RETURN( This_Status );

  EXCEPTION
    WHEN EXC_DB_Locked_With_NoWait OR
         EXC_DB_Locked_With_Wait   THEN
      -- Exclusive lock could not be acquired. Likely held by a forms user.
      This_Message := 'Failed to lock Pallet ' || i_Pallet_Id || ' to apply quantity adjustment' ;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      This_Status := PL_SWMS_Error_Codes.Lock_PO;
      RETURN( This_Status );
    WHEN OTHERS THEN
      This_Message := This_Function || ' EXCEPTION:' ;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      This_Status := pl_swms_error_codes.UPDATE_FAIL;
      RETURN( This_Status );
  END PostQtyReceived;

  FUNCTION Insert_CHK_Trans( i_Pallet_ID              IN  VARCHAR2
                           , i_New_Pallet_Id          IN  VARCHAR2
                           , i_New_Pallet_Scan_Method IN  VARCHAR2
                           , i_Scan_Method2           IN  VARCHAR2
                           , i_Scan_Type2             IN  VARCHAR2
                           )
    RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR)  := 'Insert_CHK_Trans' ;

    This_Message              VARCHAR2(2000 CHAR);

    This_Status               Server_Status := PL_SWMS_Error_Codes.Normal;
    b_Is_RDC                  BOOLEAN := ( UPPER( PL_Common.F_Get_SysPar( 'IS_RDC', 'N' )) = 'Y' );
  BEGIN
    This_Message :=                                'Starting ( i_Pallet_ID='              || NVL( i_Pallet_ID             , 'NULL' )
                 || CASE b_Is_RDC WHEN TRUE  THEN NULL ELSE ', i_New_Pallet_ID='          || NVL( i_New_Pallet_ID         , 'NULL' ) END
                 || CASE b_Is_RDC WHEN TRUE  THEN NULL ELSE ', i_New_Pallet_Scan_Method=' || NVL( i_New_Pallet_Scan_Method, 'NULL' ) END
                 || CASE b_Is_RDC WHEN FALSE THEN NULL ELSE ', i_Scan_Method2='           || NVL( i_Scan_Method2          , 'NULL' ) END
                 || CASE b_Is_RDC WHEN FALSE THEN NULL ELSE ', i_Scan_Type2='             || NVL( i_Scan_Type2            , 'NULL' ) END
                 ||                                         ' )' ;
    PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                        , i_ModuleName  => This_Function
                        , i_Message     => This_Message
                        , i_Category    => G_Msg_Category
                        , i_Add_DB_Msg  => TRUE
                        , i_ProgramName => G_This_Package
                        );
    /* Setup hardcoded fields on the CHK transaction */
    Save_Trans_Id;

    -- If this is a finish good PO, then use the CHP trans_type;
    IF pl_common.f_is_internal_production_po(G_TrxData.PO_Id) THEN
      Save_Trans_Type(G_Trx_Type_Check_Prod);
    ELSE
      -- Normal check-in
      Save_Trans_Type(G_Trx_Type_Check);
    END IF;

    Save_Trans_Date( SYSDATE );
    Save_User_Id( USER );
    Save_Batch_No( G_Key_RF_Device );

    IF ( b_Is_RDC ) THEN
       Save_Pallet_ID( i_New_Pallet_Id);
       Save_Alt_Trans_Id( i_Pallet_ID );
       Save_Scan_Method( i_New_Pallet_Scan_Method );
    ELSE  /* OpCo */
       Save_Pallet_ID( i_Pallet_ID);
       Save_Scan_Method2( i_Scan_Method2 );
       Save_Scan_Type2( i_Scan_Type2 );
    END IF;


    BEGIN
      INSERT INTO trans( trans_id         , trans_type  , rec_id
                       , cust_pref_vendor , prod_id     , pallet_id
                       , batch_no         , trans_date  , user_id
                       , qty              , cmt
                       , exp_date         , mfg_date    , temp
                       , lot_id           , tti         , cryovac
                       , uom              , reason_code , scan_method1
                       , ref_pallet_id    , adj_flag
                       , scan_method2     , scan_type2
                       )
        VALUES ( G_TrxData.Trans_Id         , G_TrxData.Trans_Type  , G_TrxData.PO_Id
               , G_TrxData.Cust_Pref_Vendor , G_TrxData.Prod_Id     , G_TrxData.Pallet_Id
               , G_TrxData.Batch_No         , G_TrxData.Trans_Date  , G_TrxData.User_Id
               , G_TrxData.Qty              , G_Business_Function
               , G_TrxData.Exp_Date         , G_TrxData.Mfr_Date    , G_TrxData.Temp
               , G_TrxData.Lot_Id           , G_TrxData.TTI_Value   , G_TrxData.CryoVac_Value
               , G_TrxData.UOM              , G_TrxData.Reason_Code , G_TrxData.Scan_Method
               , G_TrxData.Alt_Trans_Id     , G_TrxData.Adj_Flag
               , G_TrxData.Scan_Method2     , G_TrxData.Scan_Type2
               );

      This_Message := G_Trx_Type_Check || ' transaction successfully entered for Pallet ' || i_Pallet_Id || '.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );

      This_Message := 'Leaving ' || This_Function ;
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Debug
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
    EXCEPTION
      WHEN OTHERS THEN
        This_Message := 'Failed to create ' || G_Trx_Type_Check || ' transaction for Pallet ' || i_Pallet_Id || '.';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        This_Status := PL_SWMS_Error_Codes.Trans_Insert_Failed;
    END;
    RETURN( This_Status );
  END Insert_CHK_Trans;


/*******************************************************************************
**  Name:     PostChkUpdate
**  Purpose:  To finalize any remaining database updates to the pallet. If the
**            pallet status needs to be updated, then it will be addressed.
**            Also, if blind pallets are enabled, then the assigned scanned
**            pallet id must rename the temporary pallet id.
*******************************************************************************/

  FUNCTION PostChkUpdate( i_Pallet_Id      IN  VARCHAR2
                        , i_New_Status     IN  VARCHAR2 DEFAULT NULL
                        , i_New_Pallet_Id  IN  VARCHAR2 DEFAULT NULL
                        , i_Actual_Door_No IN  VARCHAR2 )
    RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR)  := 'PostChkUpdate' ;

    This_Message              VARCHAR2(2000 CHAR);
    Field_Names               VARCHAR2(100 CHAR);

    This_Status               Server_Status := PL_SWMS_Error_Codes.Normal;
    Orig_Pallet_Id            putawaylst.pallet_id%TYPE;
    Orig_Status               putawaylst.status%TYPE;
    Orig_DoorNo               putawaylst.door_no%TYPE;
    Pallet_Status             putawaylst.status%TYPE;
    Is_RDC                    sys_config.config_flag_val%TYPE;
    Status_Update             BOOLEAN;
    Pallet_Update             BOOLEAN;
    l_Qty_Expected            putawaylst.qty_received%TYPE;
    l_Qty_Produced            inv.qty_produced%TYPE;

  BEGIN
    Field_Names := NULL;
    BEGIN
      SELECT pal.status, pal.qty_expected, pal.qty_produced
        INTO Orig_Status, l_Qty_Expected, l_Qty_Produced
        FROM putawaylst pal
       WHERE pal.pallet_id = i_Pallet_Id;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        This_Message := 'Cannot locate pallet ' || i_Pallet_Id || ' for update.';
        PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                            , i_ModuleName  => This_Function
                            , i_Message     => This_Message
                            , i_Category    => G_Msg_Category
                            , i_Add_DB_Msg  => TRUE
                            , i_ProgramName => G_This_Package
                            );
        This_Status := pl_swms_error_codes.UPDATE_FAIL;
    END;

    -- i_Actual_Door_No is a mandatory parameter
    IF TRIM( i_Actual_Door_No ) IS NULL THEN
      This_Message := 'Actual Door used to unload pallet ' || i_Pallet_Id || ' is a required parameter.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => TRUE
                          , i_ProgramName => G_This_Package
                          );
      This_Status := PL_SWMS_Error_Codes.Update_Fail;
    END IF;

    -- For finish good POs, only update to putawaylst status to CHK when the produced quantity
    -- reaches the qty_expected
    IF (pl_common.f_is_internal_production_po(G_TrxData.PO_Id)) THEN
      Status_Update := (l_Qty_Produced >= l_Qty_Expected);
    ELSE
      Status_Update := ( ( LENGTH( TRIM( i_New_Status ) ) > 0 ) AND ( Orig_Status <> i_New_Status ) );
    END IF;

-- Update status, if needed.
    IF ( This_Status = PL_SWMS_Error_Codes.Normal AND Status_Update ) THEN
      BEGIN
        -- Attempt to place an exclusive lock on this pallet to change status to "Checked"
        SELECT pal.status, pal.door_no
          INTO Orig_Status, Orig_DoorNo
          FROM putawaylst pal
         WHERE pal.pallet_id = i_Pallet_Id
        FOR UPDATE OF status WAIT 5;

        -- Exclusive lock is held, now let's perform the update.
        UPDATE putawaylst pal
           SET pal.status = i_New_Status
             , pal.door_no = i_Actual_Door_No
         WHERE pal.pallet_id = i_Pallet_Id;

        Field_Names := 'Status, Door_No';

      EXCEPTION
        WHEN EXC_DB_Locked_With_NoWait OR
             EXC_DB_Locked_With_Wait   THEN
          -- Exclusive lock could not be acquired. Likely held by a forms user.
          This_Message := 'Failed to lock pallet ' || i_Pallet_Id || ' for updating status to ' || i_New_Status;
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => FALSE
                              , i_ProgramName => G_This_Package
                              );
          This_Status := PL_SWMS_Error_Codes.Lock_PO;
        WHEN OTHERS THEN
          This_Message := This_Function || ' exception occurred while attempting to update pallet status:' ;
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => TRUE
                              , i_ProgramName => G_This_Package
                              );
          This_Status := pl_swms_error_codes.UPDATE_FAIL;
      END;
    END IF;

-- Determine whether we have blind pallets enabled.
    Is_RDC := UPPER( PL_Common.F_Get_SysPar( 'Is_RDC', 'N' ) );
    Pallet_Update := ( ( TRIM( i_New_Pallet_Id ) IS NOT NULL ) AND ( Is_RDC = 'Y' ) );

-- Update pallet Id, if needed.
    IF ( This_Status = PL_SWMS_Error_Codes.Normal AND Pallet_Update ) THEN
      BEGIN
        -- Attempt to place an exclusive lock on this pallet to change status to "Checked"
        SELECT pal.pallet_id
          INTO Orig_Pallet_Id
          FROM putawaylst pal
         WHERE pal.pallet_id = i_Pallet_Id
        FOR UPDATE OF pallet_id WAIT 5;

        -- Exclusive lock is held, now let's perform the update.
        UPDATE putawaylst pal
           SET pal.pallet_id = i_New_Pallet_Id
         WHERE pal.pallet_id = i_Pallet_Id;

        --Also update the temp table for caching
          UPDATE USER_DOWNLOADED_PO
             set pallet_id = i_New_Pallet_Id
           WHERE pallet_id = i_Pallet_Id
             and user_id = (select user from dual);

        IF Field_Names IS NULL THEN
          Field_Names := 'Blind Pallet Id';
        ELSE
          Field_Names := Field_Names || ' and Blind Pallet Id';
        END IF;
      EXCEPTION
        WHEN EXC_DB_Locked_With_NoWait OR
             EXC_DB_Locked_With_Wait   THEN
          -- Exclusive lock could not be acquired. Likely held by a forms user.
          This_Message := 'Failed to lock blind pallet ' || i_Pallet_Id || ' for updating Pallet_Id to ' || i_New_Pallet_Id;
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => FALSE
                              , i_ProgramName => G_This_Package
                              );
          This_Status := PL_SWMS_Error_Codes.Lock_PO;
        WHEN OTHERS THEN
          This_Message := This_Function || ' exception occurred while attempting to update pallet id from ' || i_Pallet_Id || ' to ' || i_New_Pallet_Id;
          PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Error
                              , i_ModuleName  => This_Function
                              , i_Message     => This_Message
                              , i_Category    => G_Msg_Category
                              , i_Add_DB_Msg  => TRUE
                              , i_ProgramName => G_This_Package
                              );
          This_Status := pl_swms_error_codes.UPDATE_FAIL;
      END;
    END IF;

    IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
      This_Message := Field_Names || ' for pallet ' || i_Pallet_Id || ' is successfully updated.';
      PL_Sysco_Msg.Msg_Out( i_Level       => PL_Sysco_Msg.MsgLvl_Info
                          , i_ModuleName  => This_Function
                          , i_Message     => This_Message
                          , i_Category    => G_Msg_Category
                          , i_Add_DB_Msg  => FALSE
                          , i_ProgramName => G_This_Package
                          );
    END IF;
    RETURN( This_Status );
  END PostChkUpdate;


  FUNCTION Check_Finish_Good_PO( i_ERM_Id IN VARCHAR2 )
  RETURN CHAR IS
  BEGIN
    IF pl_common.f_is_internal_production_po(i_ERM_Id) THEN
      return 'Y';
    ELSE
      return 'N';
    END IF;
  END Check_Finish_Good_PO;



--------------------------------------------------------------------------------
-- Function
--   CheckIn_PO_LPN_List_Internal
--
-- Description
--   This function is intended to update the received quantity for the pallet
--   (to the actual quantity passed in the parameter). The location will also be
--   allocated to the pallet and the pallet status will be changed from NEW to
--   CHK. Finally, this routine will refresh the PO List structure that is
--   output to the RF gun. The refresh will include the allocated location and
--   the pallet status.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_Pallet_Id           VARCHAR2        Unique identifier for the pallet
--    i_Qty_Received        NUMBER          Actual received quantity of the
--                                          item on the pallet.
--
--  Output:
--    o_Pick_Loc            VARCHAR2        Newly allocated pick slot location
--    o_Detail_Collection   LR_PO_List_Obj  Refreshed PO List
--
-- Modification History
--
-- Date       User      CRQ#/Project Description
-- ---------- --------- ------------ -------------------------------------------
-- 09/30/2016 bgil6182  00008118     Authored original version.
-- 08/23/2021 bgil6182  OPCOF-3497   Added i_Actual_Door_No RF argument to CheckIn_PO_LPN_List.
-- 09/02/2021 bgil6182/ OPCOF-3496   Added i_Scan_Method2 and i_Scan_Type2 RF arguments to CheckIn_PO_LPN_List.
--            pkab6563
-- 09/27/2021 bgil6182  OPCOF-3541   Whenever an OpCo receives a pallet, collect an OSD reason code from the RF anytime the
--                                   actual quantity received differs from the expected/ordered quantity for the pallet.
-- 01/24/2022 mc1213    OPCOF-3941   comment out validation for door number per Brian Bent
-- 02/22/2022 bgil6182  OPCOF-3934   Removed hardcoding of the v_OSD_Collect_Flag to synchronize LR logic with RF screen (OPCOF-4004).
--------------------------------------------------------------------------------

  FUNCTION CheckIn_PO_LPN_List_Internal( i_Pallet_Id              IN     VARCHAR2        /* Input:  Unique pallet identifier */
                                       , i_Qty_Received           IN     NUMBER          /* Input:  Actual item count received */
                                       , i_Lot_Id                 IN     VARCHAR2        /* Input:  Lot Identification */
                                       , i_Exp_Date               IN     VARCHAR2        /* Input:  Sysco Expiration Date, Format: MMDDYY */
                                       , i_Mfg_Date               IN     VARCHAR2        /* Input:  Manufacturer's Expiration Date, Format: MMDDYY */
                                       , i_Date_Override          IN     VARCHAR2
                                       , i_Temp                   IN     NUMBER          /* Input:  Collected Temperature */
                                       , i_Clam_Bed_Num           IN     VARCHAR2        /* Input:  Clam Bed Number */
                                       , i_Harvest_Date           IN     VARCHAR2        /* Input:  Clam Harvest Date, Format: MMDDYY */
                                       , i_TTI_Value              IN     VARCHAR2        /* Input:  TTI Value */
                                       , i_Cryovac_Value          IN     VARCHAR2        /* Input:  CryoVac Value */
                                       , i_Run_Status             IN     RF_Start_Status /* Input:  LP status for RF at start of operation,
                                                                                                    should sync with LR_LPN_List_Rec.Status
                                                                                                    unless updated by multi-user on PO */
                                       , i_Total_Weight           IN     NUMBER          /* Input:  Total PO/Item Weight */
                                       , i_Weight_Override        IN     VARCHAR2        /* Input:  Total Weight doesn't pass validation, but the receiver
                                                                                                    has validated and is forcing data entry */
                                       , i_New_Pallet_Id          IN     VARCHAR2        /* Input:  New unique pallet identifier (Used for blind LR) */
                                       , i_New_Pallet_Scan_Method IN     VARCHAR2        /* Input:  Was blind pallet (S)canned or (K)eyed */
                                       , i_Actual_Door_No         IN     VARCHAR2        /* Input:  Actual door used for the pallet receive */                 -- OPCOF-3497
                                       , i_Scan_Method2           IN     VARCHAR2        /* Input:  Scan Method (K{eyboard}, S{can}) for trans.scan_method2 */ -- OPCOF-3496
                                       , i_Scan_Type2             IN     VARCHAR2        /* Input:  Scan Type (UPC/MfgId/Descr) for trans.scan_type2 */        -- OPCOF-3496
                                       , i_OSD_Reason_Cd          IN     VARCHAR2        /* Input:  Reason "expected vs received LPN qty" differ */            -- OPCOF-3541
                                       , o_Dest_Loc                  OUT VARCHAR2        /* Output: Allocated destination location */
                                       , o_LP_Print_Count            OUT PLS_INTEGER     /* Output: Number of license plates to print per pallet */
                                       , o_Qty_Max_Overage           OUT PLS_INTEGER     /* Output: Maximum overage allowed for this PO item */
                                       , o_Expiration_Warn           OUT Server_Status   /* Output: Expiration exceeded warning */
                                       , o_Harvest_Warn              OUT Server_Status   /* Output: Harvest exceeded warning */
                                       , o_UPC_Scan_Function         OUT VARCHAR2        /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
                                       , o_Overage_Flg               OUT VARCHAR2        /* Output: RECEIVING.OVERAGE_FLG SysPar */
                                       , o_Key_Weight_In_RF_Rcv      OUT VARCHAR2        /* Output: RECEIVING.KEY_WEIGHT_IN_RF_RCV SysPar */
                                       , o_Detail_Collection         OUT LR_PO_List_Obj  /* Output: List of PO's within the same truck load */
                                       )
  RETURN Server_Status IS
    This_Function   CONSTANT  VARCHAR2(30 CHAR)  := 'CheckIn_PO_LPN_List_Internal' ;
    This_Data_Item1 CONSTANT  VARCHAR2(30 CHAR)  := 'adjusted quantity received' ;
    This_Data_Item2 CONSTANT  VARCHAR2(30 CHAR)  := 'pallet status' ;

    This_Message              VARCHAR2(2000 CHAR);

    This_Status               Server_Status := PL_SWMS_Error_Codes.Normal;
    LP_Tbl                    LR_PO_List_Table;
    LP_Status                 NUMBER;
    PO_Id                     erm.erm_id%TYPE;
    Load_No                   erm.load_no%TYPE;
    po                        PLS_INTEGER;
    l_Exp_Date                DATE;
    l_Mfr_Date                DATE;
    l_Qty_Expected            putawaylst.qty_expected%TYPE;
    l_Qty_Received            putawaylst.qty_received%TYPE;
    Previous_Qty_received     putawaylst.qty_received%TYPE;
    l_UOM                     putawaylst.uom%TYPE;
    l_Demand_Flag             putawaylst.demand_flag%TYPE;
    Qty_Adjust                NUMBER;
    Tot_Qty_Ordered           NUMBER;
    Prod_Id                   putawaylst.prod_id%TYPE;
    Cust_Pref_Vendor          putawaylst.cust_pref_vendor%TYPE;
    Pallet_Limit              NUMBER;
    v_Prod_Id                 putawaylst.prod_id%TYPE;
    v_Exp_Date_Trk            putawaylst.exp_date_trk%TYPE;
    n_Cust_Shelf_Life         pm.cust_shelf_life%TYPE;
    n_Sysco_Shelf_Life        pm.sysco_shelf_life%TYPE;
    v_Mfr_Date_Trk            putawaylst.date_code%TYPE;
    n_Mfr_Shelf_Life          pm.mfr_shelf_life%TYPE;
    v_Cool_Trk                putawaylst.cool_trk%TYPE;
    v_Lot_Trk                 putawaylst.lot_trk%TYPE;
    v_Temp_Trk                putawaylst.temp_trk%TYPE;
    v_TTI_Trk                 putawaylst.tti_trk%TYPE;
    v_Clam_Bed_Trk            putawaylst.clam_bed_trk%TYPE;
    l_is_rdc                  sys_config.config_flag_val%TYPE := PL_Common.F_Get_SysPar( 'Is_RDC', 'N' );
    l_cache_flag              VARCHAR2(1);
    n_LM_RecordsProcessed     PLS_INTEGER;
    n_LM_BatchesCreated       PLS_INTEGER;
    n_LM_BatchesExisting      PLS_INTEGER;
    n_LM_Errors               PLS_INTEGER;
    l_count                   NATURAL;
    l_door_no                 door.door_no%TYPE;
  BEGIN
    This_Message := '( i_Pallet_Id='              || NVL( i_Pallet_Id              , 'NULL' )
                 || ', i_Qty_Received='           || NVL( TO_CHAR( i_Qty_Received ), 'NULL' )
                 || ', i_Lot_Id='                 || NVL( i_Lot_Id                 , 'NULL' )
                 || ', i_Exp_Date='               || NVL( i_Exp_Date               , 'NULL' )
                 || ', i_Mfg_Date='               || NVL( i_Mfg_Date               , 'NULL' )
                 || ', i_Temp='                   || NVL( TO_CHAR( i_Temp )        , 'NULL' )
                 || ', i_Clam_Bed_Num='           || NVL( i_Clam_Bed_Num           , 'NULL' )
                 || ', i_Harvest_Date='           || NVL( i_Harvest_Date           , 'NULL' )
                 || ', i_TTI_Value='              || NVL( i_TTI_Value              , 'NULL' )
                 || ', i_Cryovac_Value='          || NVL( i_Cryovac_Value          , 'NULL' )
                 || ', i_Run_Status='             || NVL( TO_CHAR( i_Run_Status )  , 'NULL' )
                 || ', i_Total_Weight='           || NVL( TO_CHAR( i_Total_Weight ), 'NULL' )
                 || ', i_Weight_Override='        || NVL( i_Weight_Override        , 'NULL' )
                 || ', i_New_Pallet_Id='          || NVL( i_New_Pallet_Id          , 'NULL' )
                 || ', i_New_Pallet_Scan_Method=' || NVL( i_New_Pallet_Scan_Method , 'NULL' )
                 || ', i_Actual_Door_No='         || NVL( i_Actual_Door_No         , 'NULL' )
                 || ', i_Scan_Method2='           || NVL( i_Scan_Method2           , 'NULL' )
                 || ', i_Scan_Type2='             || NVL( i_Scan_Type2             , 'NULL' )
                 || ', i_OSD_Reason_Cd='          || NVL( i_OSD_Reason_Cd          , 'NULL' )
                 || ' )';
    PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                  , NULL, NULL, G_Msg_Category, G_This_Package );

-- Initialize for RF return
    Initialize_Trans_Storage;
    o_Dest_Loc              := ' ';
    o_LP_Print_Count        := 1;
    o_Qty_Max_Overage       := 0;
    o_Expiration_Warn       := PL_SWMS_Error_Codes.Normal;
    o_Harvest_Warn          := PL_SWMS_Error_Codes.Normal;
    o_UPC_Scan_Function     := PL_Common.F_Get_SysPar( 'UPC_Scan_Function'   , 'N' );
    o_Overage_Flg           := PL_Common.F_Get_SysPar( 'Overage_Flg'         , 'N' );
    o_Key_Weight_In_RF_Rcv  := PL_Common.F_Get_SysPar( 'Key_Weight_In_RF_Rcv', 'N' );

-- Verify whether RF pallet start status agrees with DB pallet status.
-- If not, then DB pallet has been updated by another user.

    BEGIN
      SELECT lp.qty_expected , NVL( qty_received, 0 )
           , DECODE( lp.putaway_put
                   , 'Y', RF_Status_Putaway
                   , DECODE( lp.status
                           , G_Trx_Type_Check , RF_Status_Checked
                           , G_Trx_Type_New   , RF_Status_New     ) ) lp_status
           , lp.dest_loc
           , lp.rec_id
           , lp.prod_id
           , lp.cust_pref_vendor
           , lp.uom
           , DECODE( lp.demand_flag, 'Y', 'O', lp.demand_flag )   -- if on-demand pallet, then mark OSD reason code with (O)verage
        INTO l_Qty_Expected, Previous_Qty_received, LP_Status, o_Dest_Loc
           , PO_Id, Prod_Id, Cust_Pref_Vendor, l_UOM, l_Demand_Flag
        FROM putawaylst lp
       WHERE lp.pallet_id = i_Pallet_Id;

      Save_UOM( l_UOM );
      Save_Return_Code( l_Demand_Flag );

-- From this point until the Find_Putaway_Location() call, o_Dest_Loc may be set to NULL.
-- Any early terminations need to reset with RF.NoNull call to prevent problems for the RF device.

-- If the pallet has already been put away, receiver is disallowed from changing the quantity received
      Qty_Adjust := i_Qty_Received - Previous_Qty_received;
      IF ( LP_Status = RF_Status_Putaway ) AND ( Qty_Adjust <> 0 ) THEN
        This_Message := 'Pallet ' || i_Pallet_Id || ' has already been put away. Cannot update quantity.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
        This_Status := PL_SWMS_Error_Codes.Put_Done;
        o_Dest_Loc  := RF.NoNull( o_Dest_Loc );
      ELSIF ( ( i_Run_Status = RF_Status_New ) AND ( LP_Status <> RF_Status_New ) ) THEN
        This_Message := 'Another receiver has already checked in Pallet ' || i_Pallet_Id || '.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
        This_Status := PL_SWMS_Error_Codes.Alrdy_ChkIn;
        o_Dest_Loc  := RF.NoNull( o_Dest_Loc );
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        IF l_is_rdc = 'Y' THEN
          This_Status := PL_SWMS_Error_Codes.Alrdy_ChkIn;
          o_Dest_Loc  := RF.NoNull( o_Dest_Loc );
        ELSE
          This_Status := PL_SWMS_Error_Codes.Inv_PO;
          o_Dest_Loc  := RF.NoNull( o_Dest_Loc );
        END IF;
      WHEN OTHERS THEN
        o_Dest_Loc := RF.NoNull( o_Dest_Loc );
        RAISE;
    END;

-- If no errors have occurred yet, then let's validate the actual door submitted for checking in this pallet.

    IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
      Save_PO_Id( PO_Id );
      Save_Cust_Pref_Vendor( Cust_Pref_Vendor );
      Save_Prod_Id( Prod_Id );
      Save_Pallet_Id( i_Pallet_Id );

    -- The actual door entered may have been abbreviated with only the door number (missing area and aisle).
    -- If so, then translate the abbreviated door to the actual door name.
      BEGIN   /* Door validation */
        IF UPPER( l_is_rdc ) = 'Y' THEN /* RDC door validation */
          -- Validate the RDC door against the Door master table
          -- NOTE: This code could wait for RDC/OpCo SWMS merge, but being completed now for developer understanding.
          --       This section of code will not be activated in the OpCo, unless the SysPar IS_RDC is set to Y.
          IF i_Actual_Door_No IS NULL THEN
            This_Message := /*RDC*/ 'Door number is a required parameter.' ;
            This_Status := PL_SWMS_Error_Codes.Inv_Location ;
          ELSE
            SELECT COUNT(*)
              INTO l_count
              FROM loc l
             WHERE l.slot_type = 'DOR'
               AND UPPER( l.logi_loc ) = i_Actual_Door_No;

            IF l_count = 0 THEN
              This_Message := /*RDC*/ 'Door_No=' || NVL( i_Actual_Door_No, 'NULL' ) || ' could not be found.';
              Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                            , NULL, NULL, G_Msg_Category, G_This_Package );
              This_Status := PL_SWMS_Error_Codes.Inv_Location ;
            ELSE  /* Door found, save validated door */
              l_door_no := i_Actual_Door_No;
            END IF; /* Door not found */
          END IF; /* Door provided */
        ELSE /* OpCo door validation */
          -- Validate the OpCo door depending on whether forklift labor is active.
          IF PL_LMF.F_Forklift_Active() THEN
            -- Did the forklift driver enter the door?
            IF ( i_Actual_Door_No IS NOT NULL ) THEN
              l_door_no := i_Actual_Door_No;  -- initialize the validated door
              -- If the forklift door name can't be located...
              IF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN
                -- Try to locate the forklift door by translating door number to door name
                l_door_no := PL_LMF.F_Get_FK_Door_No( l_door_no );
                -- If the forklift door was translated successfully, then validate that door
                IF l_door_no IS NOT NULL THEN   -- door passed translation
                  IF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN  -- validate the translated door
                    This_Message := /*OpCo*/ 'Door=[' || NVL( i_Actual_Door_No, 'NULL' ) || '] could not be found.';
                    This_Status := PL_SWMS_Error_Codes.Inv_Location ;
                  END IF;
                ELSE -- forklift door name not found AND door number translation failed
                  This_Message := /*OpCo*/ 'Door=[' || NVL( i_Actual_Door_No, 'NULL' ) || '] could not be found.';
                  This_Status := PL_SWMS_Error_Codes.Inv_Location ;
                END IF;
              END IF; -- forklift door was located
            ELSE  -- i_Actual_Door_No is NULL
              This_Message := /*OpCo*/ 'Door number is a required parameter.';
              This_Status := PL_SWMS_Error_Codes.Inv_Location ;
            END IF;
          ELSE  -- forklift labor is not active
            IF ( i_Actual_Door_No IS NULL ) THEN
              This_Message := /*OpCo*/ 'Door number is a required parameter.';
              This_Status := PL_SWMS_Error_Codes.Inv_Location ;
            --Jira 3941 comment this out per Brian Bent ELSIF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN -- we can't validate the explicit door entered
            --  This_Message := /*OpCo*/ 'Door=[' || NVL( i_Actual_Door_No, 'NULL' ) || '] could not be found.';
            --  This_Status := PL_SWMS_Error_Codes.Inv_Location ;
            ELSE  -- Save validated door name
              l_door_no := i_Actual_Door_No;
            END IF;
          END IF; /* validate door whether forklift is active or not */
        END IF; /* validate door whether RDC or OpCo */

        IF This_Status <> PL_SWMS_Error_Codes.Normal THEN  -- If door was not validated, then notify with preset error message
          Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
        END IF;
      END;  /* Door validation */

      -- From this point forward, do not use the "i_Actual_Door_No" parameter.
      -- Instead, always reference "l_door_no" which is the validated door name.

-- If no errors have occurred yet, then let's calculate the maximum allowable adjustment for this product.

      IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
        This_Message := 'Calling Get_Max_Overage() to determine adjustment span.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );

        This_Status := Get_Max_Overage( PO_Id, Prod_Id, Cust_Pref_Vendor, i_Pallet_Id
                                      , o_Overage_Flg, Pallet_Limit, o_Qty_Max_Overage );
        o_Qty_Max_Overage := RF.NoNull( o_Qty_Max_Overage );

        -- If error occurred while calculating maximum adjustment...

        IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
          This_Message := 'Failed to fetch maximum overage quantity for Pallet ' || i_Pallet_Id || '.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
          o_Dest_Loc := RF.NoNull( o_Dest_Loc );

        -- Otherwise, if we have an adjustment...
        ELSIF ( Qty_Adjust <> 0 ) THEN
          This_Message := 'Adjustment of ' || TO_CHAR( Qty_Adjust )
                       || ' needed for pallet=' || CASE i_Pallet_Id IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || I_Pallet_Id || '"' END;
          PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message, NULL, NULL, G_Msg_Category, G_This_Package );

          -- Did our absolute adjustment exceed the absolute maximum adjustment?
          IF ( ABS( i_Qty_Received ) > ABS( o_Qty_Max_Overage ) ) THEN
            This_Message := 'The quantity received, ' || TO_CHAR( i_Qty_Received )
                        || ', exceeds the maximum allowable adjustment, ' || TO_CHAR( o_Qty_Max_Overage )
                        || '.';
            PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );
            This_Status := PL_SWMS_Error_Codes.Qty_Over;
            o_Dest_Loc := RF.NoNull( o_Dest_Loc );

          ELSE  -- Need to lock the pallet and update the received quantity.
            This_Message := 'Calling PostQtyReceived for pallet #' || TO_CHAR( i_Pallet_Id );
            PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );

            This_Status := PostQtyReceived( i_Pallet_Id, i_Qty_Received );
            IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
              o_Dest_Loc := RF.NoNull( o_Dest_Loc );
            END IF; /* Posting adjustment quantity */
          END IF; /* Calculate maximum overage AND quantity is within maximum */

-- OPCOF-3541 begin
          IF UPPER( l_is_rdc ) <> 'Y' THEN  /* OpCo OSD reason collection */
            DECLARE
              v_OSD_Collect_Flag  sys_config.config_flag_val%TYPE  := PL_Common.F_Get_SysPar( 'OSD_OPCO_SWMS', 'N' );
              v_OSD_Reason_Code   putawaylst.osd_lr_reason_cd%TYPE := NVL( i_OSD_Reason_Cd
                                                                         , CASE l_Demand_Flag
                                                                              WHEN 'O' THEN l_Demand_Flag /* Default to Overage for an on-demand pallet */
                                                                              ELSE NULL                   /* Should never happen, either RF sends the OSD reason code, or we have an on-demand pallet */
                                                                           END
                                                                         );
              l_Reason_Code       putawaylst.osd_lr_reason_cd%TYPE;
            BEGIN
              IF ( v_OSD_Collect_Flag = 'Y' ) THEN  -- Is this OpCo configured to display and collect an OSD reason?
                ---------------------------------------------------------
                -- Save i_OSD_Reason_Cd in PutAwayLst.OSD_LR_Reason_Cd --
                ---------------------------------------------------------
                
                -- First, notify the log if this ever occurs
                IF ( v_OSD_Reason_Code IS NULL ) THEN
                  This_Message := 'CheckIn for pallet#' || NVL( TO_CHAR( i_Pallet_Id ), 'NULL' ) || ' received no OSD reason code argument and this pallet is not on-demand. Contact support to investigate.';
                  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, This_Message
                                , NULL, NULL, G_Msg_Category, G_This_Package );
                  -- Just continue with a NULL OSD reason code
                END IF;
                BEGIN   -- Place an exclusive lock on pallet putaway record, but timeout in 5 seconds if already locked
                  SELECT OSD_LR_Reason_Cd
                    INTO l_Reason_Code
                    FROM putawaylst
                   WHERE Pallet_Id = i_Pallet_Id
                  FOR UPDATE OF OSD_LR_Reason_Cd WAIT 5;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    This_Message := 'Failed to find pallet ' || NVL( TO_CHAR( i_Pallet_Id ), 'NULL' ) || ' to save OSD reason.';
                    PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                                  , NULL, NULL, G_Msg_Category, G_This_Package );
                    This_Status := RF.STATUS_PALLET_NOT_FOUND ;
                  WHEN EXC_DB_Locked_With_NoWait OR
                       EXC_DB_Locked_With_Wait   THEN
                    This_Message := 'Failed to update OSD reason for pallet #' || NVL( TO_CHAR( i_Pallet_Id ), 'NULL' )
                                 || ' due to the pallet being locked by someone else.';
                    PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                                  , NULL, NULL, G_Msg_Category, G_This_Package );
                    This_Status := PL_SWMS_Error_Codes.Lock_PO ;
                END;

                -- If exclusive lock was received, then update the pallet.
                IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
                  BEGIN
                    UPDATE putawaylst
                       SET OSD_LR_Reason_Cd = v_OSD_Reason_Code
                     WHERE Pallet_Id = i_Pallet_Id;
                  EXCEPTION
                    WHEN OTHERS THEN
                      This_Message := 'Failed to update OSD reason for pallet #' || TO_CHAR( i_Pallet_Id );
                      PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                                    , SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
                      This_Status := PL_SWMS_Error_Codes.Update_Fail ;
                  END;
                END IF;
                
                -------------------------------------------------------------
                -- Create VAR transaction to record the receiving variance --
                -------------------------------------------------------------
                BEGIN
                  INSERT INTO trans( trans_id , trans_type  , trans_date      , prod_id
                                   , rec_id   , qty_expected, qty             , user_id
                                   , cmt      , reason_code , cust_pref_vendor, po_no
                                   , pallet_id )
                    VALUES( Trans_Id_Seq.NextVal   /*trans_id*/
                          , 'VAR'                  /*trans_type*/
                          , SYSDATE                /*trans_date*/
                          , Prod_Id                /*prod_id*/
                          , PO_Id                  /*rec_id*/
                          , l_Qty_Expected         /*qty_expected*/
                          , Qty_Adjust             /*qty*/
                          , USER                   /*user_id*/
                          , 'Receiving Variance'   /*cmt*/
                          , v_OSD_Reason_Code      /*reason_code*/
                          , Cust_Pref_Vendor       /*cust_pref_vendor*/
                          , PO_Id                  /*po_no*/
                          , i_Pallet_Id            /*pallet_id*/
                          );
                EXCEPTION
                  WHEN OTHERS THEN
                    This_Message := 'Failed to create VAR transaction for pallet #' || NVL( TO_CHAR( i_Pallet_Id ), 'NULL' );
                    PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                                  , SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
                    This_Status := PL_SWMS_Error_Codes.Update_Fail ;
                END;
              END IF;
            END;
          END IF;
        ELSE
          This_Message := 'No adjustment needed for pallet=' || CASE i_Pallet_Id IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || I_Pallet_Id || '"' END;
          PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message, NULL, NULL, G_Msg_Category, G_This_Package );
        END IF; /* If non-zero adjustment */
      END IF; /* Successfully passed prerequisites */
-- OPCOF-3541 end

      -- If this item required weight collection, then validate the weight entered
      IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
        Save_Qty( i_Qty_Received );
        IF o_Key_Weight_In_RF_Rcv = 'Y' AND NVL(i_Qty_Received,0) <> 0 THEN
          This_Message := 'Calling validate_weight() to collect any tracked weight for pallet #' || TO_CHAR( i_Pallet_Id );
          PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );

          Tot_Qty_Ordered := Get_PO_Qty_Ordered( PO_Id, Prod_Id, Cust_Pref_Vendor );     -- sum all pallet quantities for this item
          This_Status := PL_Weight_Validation.Validate_Weight( Prod_Id, Cust_Pref_Vendor ,PO_Id
                                                             , Tot_Qty_Ordered, i_Total_Weight, i_Weight_Override );
        END IF; /* Collecting weight during receiving? */
      END IF; /* Passed bounds check on adjustment successfully? */

      -- If no errors have occurred, then collect the tracking flags and shelf life for this item
      IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
        BEGIN
          This_Message := 'Querying data item tracking flags and shelf life minimums for the item.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );

          SELECT pal.prod_id
               , NVL( UPPER( pal.exp_date_trk ), 'N' )  exp_date_trk
               , pm.cust_shelf_life
               , pm.sysco_shelf_life
               , pal.date_code
               , pm.mfr_shelf_life
               , NVL( UPPER( pal.cool_trk ), 'N' )      cool_trk
               , NVL( UPPER( pal.lot_trk ), 'N' )       lot_trk
               , NVL( UPPER( pal.temp_trk ), 'N' )      temp_trk
               , NVL( UPPER( pal.tti_trk ), 'N' )       tti_trk
               , NVL( UPPER( pal.clam_bed_trk), 'N' )   clam_bed_trk
            INTO v_Prod_Id
               , v_Exp_Date_Trk
               , n_Cust_Shelf_Life
               , n_Sysco_Shelf_Life
               , v_Mfr_Date_Trk
               , n_Mfr_Shelf_Life
               , v_Cool_Trk
               , v_Lot_Trk
               , v_Temp_Trk
               , v_TTI_Trk
               , v_Clam_Bed_Trk
            FROM putawaylst pal
               , pm
          WHERE pal.prod_id   = pm.prod_id
            AND pal.pallet_id = i_Pallet_Id;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            This_Message := 'Specified pallet ' || TO_CHAR( i_Pallet_Id ) || ' does not exist.';
            PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );
            This_Status := PL_SWMS_Error_Codes.Inv_Label;
          WHEN OTHERS THEN
            This_Message := 'Failed to fetch data collection fields for pallet ' || TO_CHAR( i_Pallet_Id ) || '.';
            PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                          , SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
            This_Status := PL_SWMS_Error_Codes.Data_Error;
        END;

        -- If any tracking is enabled for this pallet, then we need to validate the collected data from the RF user
        IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
          l_Exp_Date := TO_DATE( i_Exp_Date, G_RF_Date_Format );
          l_Mfr_Date := TO_DATE( i_Mfg_Date, G_RF_Date_Format );

          IF NVL(i_Qty_Received,0) <> 0 THEN
            This_Message := 'Calling Collect_Reqd_Data() to collect all configured data items for the pallet.' ;
            PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );

            This_Status := Collect_Reqd_Data( i_Pallet_Id      , v_Prod_Id
                                            , v_Exp_Date_Trk   , l_Exp_Date ,i_Date_Override , n_Cust_Shelf_Life, n_Sysco_Shelf_Life
                                            , v_Mfr_Date_Trk   , l_Mfr_Date, n_Mfr_Shelf_Life
                                            , v_Cool_Trk
                                            , v_Lot_Trk        , i_Lot_Id
                                            , v_Temp_Trk       , i_Cryovac_Value, i_Temp
                                            , v_TTI_Trk        , i_TTI_Value
                                            , v_Clam_Bed_Trk   , i_Harvest_Date, i_Clam_Bed_Num
                                            , o_Expiration_Warn, o_Harvest_Warn );

            IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
              This_Message := 'Successfully collected data for Pallet ' || i_Pallet_Id || '.';
              PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                            , NULL, NULL, G_Msg_Category, G_This_Package );
            ELSE
              This_Message := 'Failed to successfully collect all data for Pallet ' || i_Pallet_Id || '.';
              PL_Log.Ins_Msg( PL_Log.CT_Warn_Msg, This_Function, This_Message
                            , NULL, NULL, G_Msg_Category, G_This_Package );
            END IF;
          ELSE
            This_Message := 'Zero quantity pallet, skipping call to Collect_Reqd_Data().' ;
            PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );
          END IF; /* Non-zero pallet quantity received */
        END IF; /* Collected data for pallet is validated */
      END IF; /* Successful item/pallet weight collection */

      -- If no errors have occurred, we are now ready to assign an available warehouse location
      IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
        This_Message := 'Calling Find_Putaway_Location() to ensure the physical location for the pallet.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );

        PL_RCV_Open_PO_LR.Find_Putaway_Location( i_Pallet_Id, o_Dest_Loc, o_LP_Print_Count, This_Status );

        IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
          This_Message := 'Pallet ' || i_Pallet_Id || ' location has been assigned to "' || o_Dest_Loc || '".';
          PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
        ELSIF ( This_Status = PL_SWMS_Error_Codes.Inv_Label ) THEN
          This_Message := 'Pallet ' || i_Pallet_Id || ' could not be found for location assignment.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
        ELSE
          /* If a warehouse does not have enough available space, or possibly zoning configuration prevents those spaces
             from being accessed, then notify the user.

             This might later be expanded to generating an alert for a warehouse supervisor of the need for manual location assignment
          */
          This_Message := 'Available warehouse location was not be found for pallet=' || NVL( i_Pallet_Id, 'NULL' )
                       || ', status returned=' || NVL( TO_CHAR( This_Status ), 'NULL' ) || '.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Warn_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
        END IF; /* Assigned waarehouse location made for pallet */
      END IF; /* Successful data collection */

      -- Record the CHK transaction for this pallet
      IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
        This_Message := 'Recording check transaction for pallet=' || NVL( i_Pallet_Id, 'NULL' ) || '.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );

        This_Status := Insert_CHK_Trans( i_Pallet_Id, i_New_Pallet_Id, i_New_Pallet_Scan_Method, i_Scan_Method2, i_Scan_Type2 );

        IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
          This_Message := 'Failed to create ' || G_Trx_Type_Check || ' transaction for pallet=' || NVL( i_Pallet_Id, 'NULL' ) || '.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
          o_Dest_Loc := RF.NoNull( o_Dest_Loc );
        ELSE
          -- Perform final updates on the putawaylst table
          This_Message := 'to update putaway status, assign actual door used';
          IF UPPER( l_is_rdc ) = 'Y' THEN
            This_Message := This_Message || ' and to replace blind pallet';
          END IF;
          Pl_Log.Ins_Msg( Pl_Log.CT_Debug_Msg, This_Function, 'Calling PostChkStatus ' || This_Message || '.'
                        , NULL, NULL, G_Msg_Category, G_This_Package );

          This_Status := PostChkUpdate( i_Pallet_Id, G_Trx_Type_Check, i_New_Pallet_Id, l_door_no );

          IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
            This_Message := 'Failed ' || This_Message || ' for pallet ' || NVL( i_Pallet_Id, 'NULL' ) || '.' ;
            Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );
          END IF; /* PostChkUpdate failed */
        END IF; /* Successful PostChkUpdate */
      END IF; /* Successful Insert_CHK_Trans */
    END IF; /* Successful multi-user test for pallet */

-- Refresh the PO List after all changes applied
    IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
      COMMIT;

      This_Message := '( o_Dest_Loc='               || NVL( o_Dest_Loc                  , 'NULL' )
                   || ', o_LP_Print_Count='         || NVL( TO_CHAR( o_LP_Print_Count  ), 'NULL' )
                   || ', o_Qty_Max_Overage='        || NVL( TO_CHAR( o_Qty_Max_Overage ), 'NULL' )
                   || ', o_Expiration_Warn='        || NVL( TO_CHAR( o_Expiration_Warn ), 'NULL' )
                   || ', o_Harvest_Warn='           || NVL( TO_CHAR( o_Harvest_Warn    ), 'NULL' )
                   || ', o_UPC_Scan_Function='      || NVL( o_UPC_Scan_Function         , 'NULL' )
                   || ', o_Overage_Flg='            || NVL( o_Overage_Flg               , 'NULL' )
                   || ', o_Key_Weight_In_RF_Rcv='   || NVL( o_Key_Weight_In_RF_Rcv      , 'NULL' )
                   || ', o_Detail_Collection=( '    || CountCollectionObjects( o_Detail_Collection ) || ' )'
                   || ' )';
      Pl_Log.Ins_Msg( Pl_Log.CT_Debug_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );

-- Create a labor management batch for the pallet just processed...
      This_Message := 'Creating putaway batch for pallet=' || NVL( i_Pallet_Id, 'NULL' ) || '.';
      Pl_Log.Ins_Msg( Pl_Log.CT_Debug_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );

      PL_LMF.Create_PutAway_Batch_For_LP( i_Pallet_Id                   => i_Pallet_Id
                                        , i_Dest_Loc                    => o_Dest_Loc
                                        , o_No_Records_Processed        => n_LM_RecordsProcessed
                                        , o_No_Batches_Created          => n_LM_BatchesCreated
                                        , o_No_Batches_Existing         => n_LM_BatchesExisting
                                        , o_No_Not_Created_Due_To_Error => n_LM_Errors
                                        );

-- Refresh the RF structure after changes made and also check whether refresh is need with cache logic.
      BEGIN
        IF l_is_rdc = 'Y' THEN
          l_cache_flag := PL_RF_CACHING.Calculate_cache_flag( i_New_Pallet_Id );
        ELSE
          l_cache_flag := PL_RF_CACHING.Calculate_cache_flag( i_Pallet_Id );
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          This_Message := 'Exception occurred while calling Calculate_cache_flag for Pallet Id#' || NVL( i_Pallet_Id, 'NULL' ) || '.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                        , SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
      END;

-- Refresh the RF data structure for the RF.
      DECLARE
        Retrieve_Status   Server_Status := PL_SWMS_Error_Codes.Normal ;
      BEGIN
        This_Message := 'Calling Retrieve_PO_LPN_List_Internal for PO=' || NVL( PO_Id, 'NULL') || ' to refresh list for RF.';
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
        Retrieve_Status := Retrieve_PO_LPN_List_Internal( PO_Id
                                                        , l_cache_flag
                                                        , l_door_no
                                                        , o_UPC_Scan_Function
                                                        , o_Overage_Flg
                                                        , o_Key_Weight_In_RF_Rcv
                                                        , Load_No
                                                        , o_Detail_Collection );
        IF ( Retrieve_Status = RF.Status_No_New_Task ) THEN
          This_Status := Retrieve_Status;
        END IF;
      END;
    ELSE  -- some type of show-stopper error occurred, rollback all previous changes to the pallet.
      ROLLBACK;

      This_Message := 'Changes have been rolled back for pallet=' || NVL( i_Pallet_Id, 'NULL' ) || '.';
      Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );
    END IF;

    RETURN( This_Status );
  EXCEPTION
    WHEN OTHERS THEN
      This_Message := 'Catch-All exception caught while checking in pallet=' || NVL( i_Pallet_Id, NULL ) || '.' ;
      l_error_code := SQLCODE;
      l_error_msg := SUBSTR( SQLERRM, 1, 4000 );
      Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                    , SQLCODE, SQLERRM, G_Msg_Category, G_This_Package );
      RAISE;
  END CheckIn_PO_LPN_List_Internal;

--------------------------------------------------------------------------------
--  Function
--    ChkIn_FG_PO_LPN_List_Internal
--
--  Description
--    This function is used to update the produced quantity for this pallet.
--    During the Retrieve LPN list function that the RF client calls, we send it
--    the expected quantity as well as the quantity that's been produced so far.
--    THe RF client will do the calculation based on the quantity that's been
--    produced vs what's expected and send the server the total quantity
--    that's been produced. The qty_produced will be updated in the INV table.
--
--    Since there's no data collection on finished good POs, there is no need
--    to check/validate like it does in CheckIn_PO_LPN_List_Internal
--
--  Input:
--    i_pallet_id           VARCHAR2        Unique id for the pallet
--    i_qty_produced        NUMBER          The total number of cases that's been
--                                          produced for this pallet.
--
--  Output:
--    o_detail_collection   LR_PO_List_Obj  Refreshed PO List
--
-- Modification History
--
-- Date       User      CRQ#/Project Description
-- ---------- --------- ------------ -------------------------------------------
-- 08/23/2021 bgil6182  OPCOF-3497   Added i_Actual_Door_No argument.
--------------------------------------------------------------------------------
  FUNCTION ChkIn_FG_PO_LPN_List_Internal (
    i_Pallet_Id             IN  VARCHAR2,
    i_Qty_Produced          IN  NUMBER, -- Total number of cases produced so far for this pallet
    i_Actual_Door_No        IN  VARCHAR2,        /* Input:  Actual door used for the pallet unload */
    i_Scan_Method2          IN  VARCHAR2,        /* Input:  Scan Method (K{eyboard}, S{can}) for trans.scan_method2 */ -- OPCOF-3496
    i_Scan_Type2            IN  VARCHAR2,        /* Input:  Scan Type (UPC/MfgId/Descr) for trans.scan_type2 */        -- OPCOF-3496
    o_Dest_Loc              OUT VARCHAR2,
    o_LP_Print_Count        OUT PLS_INTEGER,
    o_Qty_Max_Overage       OUT PLS_INTEGER,
    o_UPC_Scan_Function     OUT VARCHAR2,        /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
    o_Overage_Flg           OUT VARCHAR2,        /* Output: RECEIVING.OVERAGE_FLG SysPar */
    o_Key_Weight_In_RF_Rcv  OUT VARCHAR2,
    o_Detail_Collection     OUT LR_PO_List_Obj)

  RETURN RF.Status IS

    This_Function   CONSTANT  VARCHAR2(30 CHAR)  := 'ChkIn_FG_PO_LPN_List_Internal';
    This_Message              VARCHAR2(2000 CHAR);
    This_Status               Server_Status := PL_SWMS_Error_Codes.Normal;

    l_qty_expected            putawaylst.qty_expected%TYPE;
    l_qty_produced            inv.qty_produced%TYPE;
    l_rec_id                  putawaylst.rec_id%TYPE;
    l_prod_id                 putawaylst.prod_id%TYPE;
    l_cust_pref_vendor        putawaylst.cust_pref_vendor%TYPE;
    l_uom                     putawaylst.uom%TYPE;
    l_is_rdc                  sys_config.config_flag_val%TYPE := PL_Common.F_Get_SysPar( 'Is_RDC', 'N' );
    l_cache_flag              VARCHAR2(1);
    Load_No                   erm.load_no%TYPE;
    l_door_no                 door.door_no%TYPE;
    l_count                   NATURAL;

  BEGIN
    This_Message := 'Starting ( i_Pallet_Id='      || NVL( i_Pallet_Id              , 'NULL' )
                 ||          ', i_Qty_Produced='   || NVL( TO_CHAR( i_Qty_Produced ), 'NULL' )
                 ||          ', i_Actual_Door_No=' || NVL( i_Actual_Door_No         , 'NULL' )
                 ||          ' )';

    PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                  , NULL, NULL, G_Msg_Category, G_This_Package );

    -- Initialize for RF return
    Initialize_Trans_Storage;
    o_Dest_Loc              := ' ';
    o_LP_Print_Count        := 1;
    o_Qty_Max_Overage       := 0;
    o_UPC_Scan_Function     := PL_Common.F_Get_SysPar( 'UPC_Scan_Function'   , 'N' );
    o_Overage_Flg           := PL_Common.F_Get_SysPar( 'Overage_Flg'         , 'N' );
    o_Key_Weight_In_RF_Rcv  := PL_Common.F_Get_SysPar( 'Key_Weight_In_RF_Rcv', 'N' );

    -- Make sure production for this pallet is not already completed.
    --STATUS_ALRDY_CHKIN
    BEGIN
      SELECT p.qty_expected
           , NVL( p.qty_produced, 0 )
           , p.dest_loc
           , p.rec_id
           , p.prod_id
           , p.cust_pref_vendor
           , p.uom
        INTO l_qty_expected
           , l_qty_produced
           , o_Dest_Loc
           , l_rec_id
           , l_prod_id
           , l_cust_pref_vendor
           , l_uom
        FROM putawaylst p
       WHERE p.pallet_id = i_Pallet_Id;

      Save_UOM(l_uom);
      Save_Return_Code(null);

      IF l_qty_produced >= l_qty_expected THEN
        -- The production for this pallet has already been completed.
        This_Message := 'Another receiver has already checked in Pallet ' || i_Pallet_Id || '.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
        This_Status := PL_SWMS_Error_Codes.Alrdy_ChkIn;
        o_Dest_Loc  := RF.NoNull(o_Dest_Loc);
      END IF;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        This_Status := PL_SWMS_Error_Codes.Inv_Po;
        o_Dest_Loc := RF.NoNull(o_Dest_Loc);

      WHEN OTHERS THEN
        o_Dest_Loc := RF.NoNull( o_Dest_Loc );
        RAISE;
    END;

    -- The actual door entered may have been abbreviated with only the door number (missing area and aisle).
    -- If so, then translate the abbreviated door to the actual door name.
    BEGIN   /* Door validation */
      IF UPPER( l_is_rdc ) = 'Y' THEN
        -- Validate the RDC door against the Door master table
        -- NOTE: This code could wait for RDC/OpCo SWMS merge, but being completed now for developer understanding.
        --       This section of code will not be activated in the OpCo, unless the SysPar IS_RDC is set to Y.
        IF i_Actual_Door_No IS NULL THEN
          This_Message := /*RDC*/ 'Door number is a required parameter.' ;
          This_Status := PL_SWMS_Error_Codes.Inv_Location ;
        ELSE
          SELECT COUNT(*)
            INTO l_count
            FROM loc l
           WHERE l.slot_type = 'DOR'
             AND UPPER( l.logi_loc ) = i_Actual_Door_No;

          IF l_count = 0 THEN
            This_Message := /*RDC*/ 'Door_No=' || NVL( i_Actual_Door_No, 'NULL' ) || ' could not be found.';
            Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                          , NULL, NULL, G_Msg_Category, G_This_Package );
            This_Status := PL_SWMS_Error_Codes.Inv_Location ;
          ELSE  /* Door found, save validated door */
            l_door_no := i_Actual_Door_No;
          END IF; /* Door not found */
        END IF; /* Door provided */
      ELSE /* OpCo door validation */
        -- Validate the OpCo door depending on whether forklift labor is active.
        IF PL_LMF.F_Forklift_Active() THEN
          -- Did the forklift driver enter the door?
          IF ( i_Actual_Door_No IS NOT NULL ) THEN
            l_door_no := i_Actual_Door_No;  -- initialize the validated door
            -- If the forklift door name can't be located...
            IF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN
              -- Try to locate the forklift door by translating door number to door name
              l_door_no := PL_LMF.F_Get_FK_Door_No( l_door_no );
              -- If the forklift door was translated successfully, then validate that door
              IF l_door_no IS NOT NULL THEN   -- door passed translation
                IF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN  -- validate the translated door
                  This_Message := /*OpCo*/ 'Door=[' || NVL( i_Actual_Door_No, 'NULL' ) || '] could not be found.';
                  This_Status := PL_SWMS_Error_Codes.Inv_Location ;
                END IF;
              ELSE -- forklift door name not found AND door number translation failed
                This_Message := /*OpCo*/ 'Door=[' || NVL( i_Actual_Door_No, 'NULL' ) || '] could not be found.';
                This_Status := PL_SWMS_Error_Codes.Inv_Location ;
              END IF;
            END IF; -- forklift door was located
          ELSE  -- i_Actual_Door_No is NULL
            This_Message := /*OpCo*/ 'Door number is a required parameter.';
            This_Status := PL_SWMS_Error_Codes.Inv_Location ;
          END IF;
        ELSE  -- forklift labor is not active
          IF ( i_Actual_Door_No IS NULL ) THEN
            This_Message := /*OpCo*/ 'Door number is a required parameter.';
            This_Status := PL_SWMS_Error_Codes.Inv_Location ;
          ELSIF NOT PL_LMF.F_Valid_FK_Door_No( l_door_no ) THEN -- we can't validate the explicit door entered
            This_Message := /*OpCo*/ 'Door=[' || NVL( i_Actual_Door_No, 'NULL' ) || '] could not be found.';
            This_Status := PL_SWMS_Error_Codes.Inv_Location ;
          ELSE  -- Save validated door name
            l_door_no := i_Actual_Door_No;
          END IF;
        END IF; /* validate door whether forklift is active or not */
      END IF; /* validate door whether RDC or OpCo */

      IF This_Status <> PL_SWMS_Error_Codes.Normal THEN  -- If door was not validated, then notify with preset error message
        Pl_Log.Ins_Msg( Pl_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
      END IF;
    END;  /* Door validation */

    -- From this point forward, do not use the "i_Actual_Door_No" parameter.
    -- Instead, always reference "l_door_no" which is the validated door name.

    -- Updated Qty_Ordered
    IF (This_Status = PL_SWMS_Error_Codes.Normal) THEN

      Save_PO_Id(l_rec_id);
      Save_Cust_Pref_Vendor(l_cust_pref_vendor);
      Save_Prod_Id(l_prod_id);
      Save_Pallet_Id(i_pallet_id);
      Save_Qty(i_Qty_Produced);

      IF (ABS(i_Qty_Produced) > ABS(l_qty_expected)) THEN
        This_Message := 'The quantity produced: '                  || NVL( TO_CHAR( i_Qty_Produced ), 'NULL' )
                     || ' exceeds the quantity ordered/expected: ' || NVL( TO_CHAR( l_qty_expected ), 'NULL' );

        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
        This_Status := PL_SWMS_Error_Codes.Qty_Over;
        o_Dest_Loc := RF.NoNull( o_Dest_Loc );

      ELSE

        This_Message := 'Calling PostQtyReceived for pallet #' || TO_CHAR( i_Pallet_Id );
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );

        This_Status := PostQtyReceived(i_Pallet_Id, i_Qty_Produced);

        IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
          o_Dest_Loc := RF.NoNull( o_Dest_Loc );
        END IF; /* Posting adjustment quantity */

      END IF;
    END IF;

    -- If no errors have occurred, then assign the putaway location
    IF (This_Status = PL_SWMS_Error_Codes.Normal) THEN
      This_Message := 'Calling Find_Putaway_Location() to assign the warehouse location for the pallet.' ;
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );

      PL_RCV_Open_PO_LR.Find_Putaway_Location( i_Pallet_Id, o_Dest_Loc, o_LP_Print_Count, This_Status );

      IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
        This_Message := 'Pallet ' || i_Pallet_Id || ' location has been assigned to "' || o_Dest_Loc || '".';
        PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
      ELSIF ( This_Status = PL_SWMS_Error_Codes.Inv_Label ) THEN
        This_Message := 'Pallet ' || i_Pallet_Id || ' could not be found for location assignment.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
      ELSE
        This_Message := 'Data error occurred while processing location assignment for Pallet ' || i_Pallet_Id || '.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
      END IF;
    END IF;

    IF ( This_Status = PL_SWMS_Error_Codes.Normal ) THEN
      This_Message := 'Calling Insert_CHK_Trans';
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );

      This_Status := Insert_CHK_Trans(i_Pallet_Id, NULL, NULL, i_Scan_Method2, i_Scan_Type2 );

      IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
        This_Message := 'Failed to create ' || G_Trx_Type_Check || ' transaction for pallet ' || i_Pallet_Id || '.' ;
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );
        o_Dest_Loc := RF.NoNull( o_Dest_Loc );
      ELSE
        This_Message := 'Calling PostChkStatus';
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );

        This_Status := PostChkUpdate( i_Pallet_Id, G_Trx_Type_Check, NULL, l_door_no );

        IF ( This_Status <> PL_SWMS_Error_Codes.Normal ) THEN
          This_Message := 'Failed to update to ' || G_Trx_Type_Check || ' status for pallet ' || i_Pallet_Id || '.' ;
          PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, This_Message
                        , NULL, NULL, G_Msg_Category, G_This_Package );
        END IF;
      END IF;
    END IF;

    IF (This_Status = PL_SWMS_Error_Codes.Normal) THEN
      COMMIT;

      This_Message := '( o_Dest_Loc='               || NVL( o_Dest_Loc                  , 'NULL' )
                   || ', o_LP_Print_Count='         || NVL( TO_CHAR( o_LP_Print_Count  ), 'NULL' )
                   || ', o_Qty_Max_Overage='        || NVL( TO_CHAR( o_Qty_Max_Overage ), 'NULL' )
--                   || ', o_Expiration_Warn='        || NVL( TO_CHAR( o_Expiration_Warn ), 'NULL' )
--                   || ', o_Harvest_Warn='           || NVL( TO_CHAR( o_Harvest_Warn    ), 'NULL' )
                   || ', o_UPC_Scan_Function='      || NVL( o_UPC_Scan_Function         , 'NULL' )
                   || ', o_Overage_Flg='            || NVL( o_Overage_Flg               , 'NULL' )
                   || ', o_Key_Weight_In_RF_Rcv='   || NVL( o_Key_Weight_In_RF_Rcv      , 'NULL' )
                   || ', o_Detail_Collection=( '    || CountCollectionObjects( o_Detail_Collection ) || ' )'
                   || ' )';
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );

      This_Message := 'Successfully saved changes for pallet #' || i_Pallet_Id || '.';
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, This_Message
                      , NULL, NULL, G_Msg_Category, G_This_Package );

      BEGIN
        l_cache_flag := PL_RF_CACHING.Calculate_cache_flag(i_Pallet_Id);
      EXCEPTION
        WHEN OTHERS THEN
          PL_Log.Ins_Msg( 'INFO', This_Function, 'Exception occurred while calling Calculate_cache_flag for Pallet Id#'|| nvl(i_Pallet_Id,'null'), NULL, NULL
                        , PL_RCV_Open_PO_Types.CT_Application_Function, G_This_Package, 'N' );
      END;

      DECLARE
        Retrieve_Status RF.Status         := RF.Status_Normal;
      BEGIN
        Retrieve_Status := Retrieve_PO_LPN_List_Internal( l_rec_id
                                                        , l_cache_flag
                                                        , l_door_no
                                                        , o_UPC_Scan_Function
                                                        , o_Overage_Flg
                                                        , o_Key_Weight_In_RF_Rcv
                                                        , Load_No
                                                        , o_Detail_Collection );

        IF ( Retrieve_Status = RF.Status_No_New_Task ) THEN
          RETURN( Retrieve_Status );
        END IF;

      END;

    ELSE
      ROLLBACK;

      This_Message := 'Changes have been rolled back for pallet #' || i_Pallet_Id || '.';
      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, This_Message
                    , NULL, NULL, G_Msg_Category, G_This_Package );
    END IF;

    RETURN This_Status;

  END ChkIn_FG_PO_LPN_List_Internal;

--------------------------------------------------------------------------------
-- Function
--   CheckIn_PO_LPN_List
--
-- Description
--   This function return a list of items, referenced by the given customer PO.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_RF_Log_Init_Record   RF_Log_Init_R  RF device initialization record
--    i_Pallet_Id            VARCHAR2       Pallet #
--    i_Qty_Received         NUMBER         Actual physical quantity for item
--
--  Output:
--    o_Pick_Loc             VARCHAR2       Pick slot allocated for putaway
--    o_Detail_Collection    LR_PO_List_Obj Refreshed PO List
--
-- Modification History
--
-- Date       User      CRQ#/Project Description
-- ---------- --------- ------------ -------------------------------------------
-- 09/30/2016 bgil6182  00008118     Authored original version.
-- 08/23/2021 bgil6182  OPCOF-3497   Added i_Actual_Door_No RF argument to CheckIn_PO_LPN_List.
-- 09/27/2021 bgil6182  OPCOF-3541   Whenever an OpCo receives a pallet, collect an OSD reason code from the RF anytime the
--                                   actual quantity received differs from the expected/ordered quantity for the pallet.
--------------------------------------------------------------------------------
  FUNCTION CheckIn_PO_LPN_List( i_RF_Log_Init_Record     IN     RF_Log_Init_Record  /* Input:  RF device initialization record */
                              , i_Pallet_Id              IN     VARCHAR2            /* Input:  Unique pallet identifier */
                              , i_Qty_Received           IN     NUMBER              /* Input:  Actual item count received */
                              , i_Lot_Id                 IN     VARCHAR2            /* Input:  Lot Identification */
                              , i_Exp_Date               IN     VARCHAR2            /* Input:  Sysco Expiration Date, Format: MMDDYY */
                              , i_Mfg_Date               IN     VARCHAR2            /* Input:  Manufacturer's Expiration Date, Format: MMDDYY */
                              , i_Date_Override          IN     VARCHAR2
                              , i_Temp                   IN     NUMBER              /* Input:  Collected Temperature */
                              , i_Clam_Bed_Num           IN     VARCHAR2            /* Input:  Clam Bed Number */
                              , i_Harvest_Date           IN     VARCHAR2            /* Input:  Clam Harvest Date, Format: MMDDYY */
                              , i_TTI_Value              IN     VARCHAR2            /* Input:  TTI Value */
                              , i_Cryovac_Value          IN     VARCHAR2            /* Input:  CryoVac Value */
                              , i_Run_Status             IN     RF_Start_Status     /* Input:  LP status for RF at start of operation,
                                                                                               should sync with LR_LPN_List_Rec.Status
                                                                                               unless updated by multi-user on PO */
                              , i_Total_Weight           IN     NUMBER              /* Input:  Total PO/Item Weight */
                              , i_Weight_Override        IN     VARCHAR2            /* Input:  Total Weight doesn't pass validation, but the receiver
                                                                                               has validated and is forcing data entry */
                              , i_New_Pallet_Id          IN     VARCHAR2            /* Input:  New unique pallet identifier (Used for blind LR) */
                              , i_New_Pallet_Scan_Method IN     VARCHAR2            /* Input:  Was blind pallet (S)canned or (K)eyed */
                              , i_Actual_Door_No         IN     VARCHAR2            /* Input:  Actual door used for the pallet receive */                 -- OPCOF-3497
                              , i_Scan_Method2           IN     VARCHAR2            /* Input:  Scan Method (K{eyboard}, S{can}) for trans.scan_method2 */ -- OPCOF-3496
                              , i_Scan_Type2             IN     VARCHAR2            /* Input:  Scan Type (UPC/MfgId/Descr) for trans.scan_type2 */        -- OPCOF-3496
                              , i_OSD_Reason_Cd          IN     VARCHAR2            /* Input:  Reason "expected vs received LPN qty" differ */            -- OPCOF-3541
                              , o_Dest_Loc                  OUT VARCHAR2            /* Output: Allocated destination location */
                              , o_LP_Print_Count            OUT PLS_INTEGER         /* Output: Number of license plates to print per pallet */
                              , o_Qty_Max_Overage           OUT PLS_INTEGER         /* Output: Maximum overage allowed for this PO item */
                              , o_Expiration_Warn           OUT Server_Status       /* Output: Expiration exceeded warning (whether EXP_DATE or MFG_DATE) */
                              , o_Harvest_Warn              OUT Server_Status       /* Output: Harvest exceeded warning */
                              , o_UPC_Scan_Function         OUT VARCHAR2            /* Output: GENERAL.UPC_SCAN_FUNCTION SysPar */
                              , o_Overage_Flg               OUT VARCHAR2            /* Output: RECEIVING.OVERAGE_FLG SysPar */
                              , o_Key_Weight_In_RF_Rcv      OUT VARCHAR2            /* Output: RECEIVING.KEY_WEIGHT_IN_RF_RCV SysPar */
                              , o_Detail_Collection         OUT LR_PO_List_Obj      /* Output: List of PO's within the same truck load */
                              )
  RETURN RF.Status IS
    This_Function CONSTANT  VARCHAR2(30)   := 'CheckIn_PO_LPN_List';

    RF_Status               RF.Status  := RF.Status_Normal;
    l_erm_id                ERM.erm_id%TYPE;

  BEGIN
    -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().

    o_Dest_Loc              := RF.NoNull( '' );
    o_LP_Print_Count        := RF.NoNull( 0 );
    o_Qty_Max_Overage       := RF.NoNull( 0 );
    o_Expiration_Warn       := RF.NoNull( PL_SWMS_Error_Codes.Normal );
    o_Harvest_Warn          := RF.NoNull( PL_SWMS_Error_Codes.Normal );
    o_UPC_Scan_Function     := RF.NoNull( '' );
    o_Overage_Flg           := RF.NoNull( '' );
    o_Key_Weight_In_RF_Rcv  := RF.NoNull( '' );
    o_Detail_Collection     := LR_PO_List_Obj( LR_PO_List_Table( ) );

    -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

    RF_Status := RF.Initialize( i_RF_Log_Init_Record );

    IF ( RF_Status = RF.Status_Normal ) THEN
      --         main business logic BEGINs...

      -- Record input from RF device to web service

      RF.LogMsg(RF.Log_Info, This_Function || ': Input from RF'
                             || ': LPN='                  || NVL( i_Pallet_Id              , 'NULL' )
                             || ', Rcv_Qty='              || NVL( TO_CHAR( i_Qty_Received ), 'NULL' )
                             || ', Lot#='                 || NVL( i_Lot_Id                 , 'NULL' )
                             || ', Exp_Date='             || NVL( i_Exp_Date               , 'NULL' )
                             || ', Mfg_Date='             || NVL( i_Mfg_Date               , 'NULL' )
                             || ', Temp='                 || NVL( TO_CHAR( i_Temp )        , 'NULL' )
                             || ', Clam_Bed_Num='         || NVL( i_Clam_Bed_Num           , 'NULL' )
                             || ', Harvest_Date='         || NVL( i_Harvest_Date           , 'NULL' )
                             || ', TTI='                  || NVL( i_TTI_Value              , 'NULL' )
                             || ', Cryovac='              || NVL( i_Cryovac_Value          , 'NULL' )
                             || ', Run_Status='           || NVL( TO_CHAR( i_Run_Status )  , 'NULL' )
                             || ', Total_Weight='         || NVL( TO_CHAR( i_Total_Weight ), 'NULL' )
                             || ', Weight_Override='      || NVL( i_Weight_Override        , 'NULL' )
                             || ', Upd_Pallet_Id='        || NVL( i_New_Pallet_Id          , 'NULL' )
                             || ', Upd_Pallet_In_Method=' || NVL( i_New_Pallet_Scan_Method , 'NULL' )
                             || ', Actual_Door_No='       || NVL( i_Actual_Door_No         , 'NULL' )
                             || ', Scan_Method2='         || NVL( i_Scan_Method2           , 'NULL' )
                             || ', Scan_Type2='           || NVL( i_Scan_Type2             , 'NULL' )
                             || ', OSD_Reason='           || NVL( i_OSD_Reason_Cd          , 'NULL' )
               );

      BEGIN
        SELECT rec_id
        INTO l_erm_id
        FROM putawaylst
        WHERE pallet_id = i_pallet_id;
      EXCEPTION
        WHEN OTHERS THEN
          pl_log.ins_msg(
            'FATAL',
            This_Function,
            'Unable to putawaylst.rec_id using pallet_id [' || i_pallet_Id || ']',
            sqlcode,
            SQLERRM);
      END;

      IF pl_common.f_is_internal_production_po(l_erm_id) THEN

        RF_Status := ChkIn_FG_PO_LPN_List_Internal( i_Pallet_id        , i_Qty_Received  , i_Actual_Door_No
                                                  , i_Scan_Method2     , i_Scan_Type2
                                                  , o_Dest_Loc         , o_LP_Print_Count, o_Qty_Max_Overage
                                                  , o_UPC_Scan_Function, o_Overage_Flg   , o_Key_Weight_In_RF_Rcv
                                                  , o_Detail_Collection
                                                  );

      ELSE

        RF_Status := CheckIn_PO_LPN_List_Internal( i_Pallet_Id             , i_Qty_Received        , i_Lot_Id
                                                 , i_Exp_Date              , i_Mfg_Date            , i_Date_Override
                                                 , i_Temp                  , i_Clam_Bed_Num        , i_Harvest_Date
                                                 , i_TTI_Value             , i_Cryovac_Value       , i_Run_Status
                                                 , i_Total_Weight          , i_Weight_Override     , i_New_Pallet_Id
                                                 , i_New_Pallet_Scan_Method, i_Actual_Door_No      , i_Scan_Method2
                                                 , i_Scan_Type2            , i_OSD_Reason_Cd
                                                 , o_Dest_Loc              , o_LP_Print_Count      , o_Qty_Max_Overage
                                                 , o_Expiration_Warn       , o_Harvest_Warn        , o_UPC_Scan_Function
                                                 , o_Overage_Flg           , o_Key_Weight_In_RF_Rcv, o_Detail_Collection
                                                 );
      END IF;

      RF.LogMsg(RF.Log_Info, This_Function || ': Output to RF'
                             || ': Dest_Loc='             || NVL( o_Dest_Loc, 'NULL' )
                             || ', LP_Print_Count='       || NVL( TO_CHAR( o_LP_Print_Count ), 'NULL' )
                             || ', Qty_Max_Overage='      || NVL( TO_CHAR( o_Qty_Max_Overage ), 'NULL' )
                             || ', Expiration_Warn='      || NVL( TO_CHAR( o_Expiration_Warn ), 'NULL' )
                             || ', Harvest_Warn='         || NVL( TO_CHAR( o_Harvest_Warn ), 'NULL' )
                             || ', UPC_Scan_Function='    || NVL( o_UPC_Scan_Function, 'NULL' )
                             || ', Overage_Flg='          || NVL( o_Overage_Flg, 'NULL' )
                             || ', Key_Weight_In_RF_Rcv=' || NVL( o_Key_Weight_In_RF_Rcv, 'NULL' )
                             || ', DetailCollection=( '   || CountCollectionObjects( o_Detail_Collection ) || ' )'
               );

    END IF;

    RF.Complete( RF_Status );
    RETURN( RF_Status );
  EXCEPTION
    WHEN OTHERS THEN
      RF.LogException( );     -- log it
      RAISE;
  END CheckIn_PO_LPN_List;

/*-----------------------------------------------------------------------------
-- Add_LP_To_PO()
--
-- Description:
--   Called from the RF client to create a pallet ID for an extra pallet of
--   product due to an overage that exceeds the item ti/hi and that requires a
--   separate pallet. This function will create a pallet ID for the pallet
--   and insert a row into putawaylst after some validation. It will then
--   return the pallet ID and a refreshed PO list.
--
--   Add_LP_To_PO_Internal() will be called to do the business logic.
--
-- Input:
--   i_RF_Log_Init_Record: common RF client related init record.
--   i_PO_Id: PO#
--   i_Prod_Id: Item#
--   i_Cust_Pref_Vendor,
--   i_uom: uom (0 = case, 1 = split)
--
-- Output:
--   o_Pallet_Id: pallet ID created for pallet.
--   o_Detail_Collection: refreshed PO list.
--
-- Modification Log:
--
--   Date          Author     Comment
--   --------------------------------------------------------------------------
--   18-Aug-2021   pkab6563   Initial version - Jira 3539.
--
-------------------------------------------------------------------------------*/

  FUNCTION Add_LP_To_PO( i_RF_Log_Init_Record IN   RF_Log_Init_Record           
                       , i_PO_Id              IN   putawaylst.rec_id%TYPE                             
                       , i_Prod_Id            IN   pm.prod_id%TYPE
                       , i_Cust_Pref_Vendor   IN   pm.cust_pref_vendor%TYPE
                       , i_uom                IN   putawaylst.uom%TYPE
                       , o_Pallet_Id          OUT  putawaylst.pallet_id%TYPE
                       , o_Detail_Collection  OUT  LR_PO_List_Obj)
  RETURN RF.Status IS

    l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'Add_LP_To_PO';
    l_status               rf.status := rf.status_normal;
    l_msg                  swms_log.msg_text%TYPE;
  
  BEGIN
    
      -- Initialize OUT parameters (cannot be null or ora-01405 will result).
      -- This must be done before calling rf.Initialize().

      o_Pallet_Id          := RF.NoNull('');
      o_Detail_Collection  := LR_PO_List_Obj(LR_PO_List_Table());
        
      -- Call rf.Initialize().  If successful then continue with main business logic.

      l_status := RF.Initialize(i_RF_Log_Init_Record);
        
      -- Record input from RF device to web service

      RF.LogMsg( RF.Log_Info, l_func_name || ': Input from RF'
                                          || ': PO_No='            || CASE i_PO_Id            IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || i_PO_Id            || '"' END
                                          || ', Prod_Id='          || CASE i_Prod_Id          IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || i_Prod_Id          || '"' END
                                          || ', Cust_Pref_Vendor=' || CASE i_Cust_Pref_Vendor IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || i_Cust_Pref_Vendor || '"' END
                                          || ', UOM='              || CASE i_uom              IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || TO_CHAR( i_UOM )   || '"' END
               );

      -- Record input from RF device

      l_msg := 'Input from RF client: i_PO_Id [' 
            || i_PO_Id
            || '] i_Prod_Id ['
            || i_Prod_Id
            || '] i_Cust_Pref_Vendor ['
            || i_Cust_Pref_Vendor
            || '] i_uom ['
            || i_uom
            || ']';
              
      pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, G_Application_Func, G_This_Package);
                                                                  
      IF  l_status = rf.status_normal THEN
          l_status := Add_LP_To_PO_Internal(i_PO_Id 
                                          , i_Prod_Id
                                          , i_Cust_Pref_Vendor 
                                          , i_uom
                                          , o_Pallet_Id 
                                          , o_Detail_Collection);
      END IF;  
     
      -- Record output from RF device to web service

      RF.LogMsg( RF.Log_Info, l_func_name || ': Output from RF'
                              || ': Pallet_Id='          || CASE o_Pallet_Id IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || o_Pallet_Id || '"' END
                              || ', DetailCollection=( ' || CountCollectionObjects( o_Detail_Collection ) || ' )'
               );

      RF.Complete(l_status);
      RETURN(l_status);
     
  EXCEPTION
      WHEN OTHERS THEN
          l_msg := 'Unexpected ERROR encountered.';
          pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
          RF.LogException(); 
          RAISE;
     
  END Add_LP_To_PO;

/*-----------------------------------------------------------------------------
-- Add_LP_To_PO_Internal()
--
-- Description:
--   This is the business logic for Add_LP_To_PO().
--   Called by Add_LP_To_PO() to create a pallet ID for an extra pallet of
--   product due to an overage that exceeds the item ti/hi and that requires a
--   separate pallet. This function will create a pallet ID for the pallet
--   and insert a row into putawaylst after some validation. It will then
--   return the pallet ID and a refreshed PO list.
--
-- Input:
--   i_PO_Id: PO#
--   i_Prod_Id: Item#
--   i_Cust_Pref_Vendor,
--   i_uom: uom (0 = case, 1 = split)
--
-- Output:
--   o_Pallet_Id: pallet ID created for pallet.
--   o_Detail_Collection: refreshed PO list.
--
-- Modification Log:
--
--   Date          Author     Comment
--   --------------------------------------------------------------------------
--   18-Aug-2021   pkab6563   Initial version - Jira 3539.
--
-------------------------------------------------------------------------------*/

  FUNCTION Add_LP_To_PO_Internal(i_PO_Id              IN   putawaylst.rec_id%TYPE                             
                               , i_Prod_Id            IN   pm.prod_id%TYPE
                               , i_Cust_Pref_Vendor   IN   pm.cust_pref_vendor%TYPE
                               , i_uom                IN   putawaylst.uom%TYPE
                               , o_Pallet_Id          OUT  putawaylst.pallet_id%TYPE
                               , o_Detail_Collection  OUT  LR_PO_List_Obj)
  RETURN RF.Status IS

    l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'Add_LP_To_PO_Internal';
    l_status               rf.status := rf.status_normal;
    l_msg                  swms_log.msg_text%TYPE;
    Max_seq_For_PO         putawaylst.seq_no%TYPE;
    l_category             pm.category%TYPE;
    l_clam_bed_trk         VARCHAR2(1);
    l_tti_trk              VARCHAR2(1);
    l_r_syspars            pl_rcv_open_po_types.t_r_putaway_syspars;    
    l_erm_line_id          erd.erm_line_id%TYPE;
    l_door_no              putawaylst.door_no%TYPE;    
    l_temp_trk             pm.temp_trk%TYPE;
    l_catch_wt_trk         pm.catch_wt_trk%TYPE;         
    l_lot_trk              pm.lot_trk%TYPE;
    l_exp_date_trk         pm.exp_date_trk%TYPE;
    l_mfg_date_trk         pm.mfg_date_trk%TYPE;
    l_pallet_id            putawaylst.pallet_id%TYPE;
    l_PO_Tbl               LR_PO_List_Table;
    l_table_status         Server_Status;
    e_fail                 EXCEPTION;
    
  BEGIN

    -- Initialize OUT parameters (cannot be null or ora-01405 will result).
    -- This must be done before calling rf.Initialize().

        o_Pallet_Id          := RF.NoNull('');
        o_Detail_Collection  := LR_PO_List_Obj(LR_PO_List_Table());
  
    -- Validate PO, line item
    
    BEGIN
        SELECT erd.erm_line_id
          INTO l_erm_line_id
        FROM   erm, erd
        WHERE  erm.erm_id = i_PO_Id
          AND  erm.erm_type IN ('PO', 'RA')
          AND  erm.status = 'OPN'
          AND  erd.erm_id = erm.erm_id
          AND  erd.prod_id = i_prod_id
          AND  erd.cust_pref_vendor = i_Cust_Pref_Vendor
          AND  erd.uom = i_uom
          AND  ROWNUM = 1;
  
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_msg := 'PO# [' 
                  || i_PO_Id  
                  || '] not in OPN status or line item [' 
                  || i_prod_id 
                  || '] CPV [' 
                  || i_Cust_Pref_Vendor
                  || '] UOM ['
                  || i_uom
                  || '] NOT FOUND';
            pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
            l_status := RF.Status_Inv_Po;
            
        WHEN OTHERS THEN
            l_msg := 'Unexpected ERROR while validating PO and line item';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
            l_status := RF.Status_Data_Error;
            RAISE;
            
    END; -- validate PO

    -- Get seq#
    IF l_status = rf.status_normal THEN
        BEGIN
            SELECT MAX(seq_no) + 1
              INTO Max_seq_For_PO
              FROM putawaylst
            WHERE  rec_id = i_PO_Id;
  
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_msg := 'i_PO_Id[' || i_PO_Id || '] not found in PUTAWAYLST';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Inv_Po;
            
            WHEN OTHERS THEN
                l_msg := 'Error selecting max(seq_no) from PUTAWAYLST';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Data_Error;
                RAISE;
        END;  -- get seq#
    END IF;
     
    -- Get next pallet ID available to use
    IF l_status = rf.status_normal THEN
        BEGIN
            o_pallet_id := pl_common.f_get_new_pallet_id;
            l_pallet_id := o_pallet_id;
            
        EXCEPTION
            WHEN OTHERS THEN
                l_msg := 'Unexpected ERROR while trying to get next available pallet ID';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Data_Error;
                RAISE;
        END;
    END IF;  -- Get next pallet ID available to use

    -- Get needed item attributes
    
    IF l_status = rf.status_normal THEN
        BEGIN
            SELECT category, nvl(temp_trk, 'N'), nvl(catch_wt_trk, 'N'), nvl(lot_trk, 'N'), 
                   nvl(exp_date_trk, 'N'), nvl(mfg_date_trk, 'N')
              INTO l_category, l_temp_trk, l_catch_wt_trk, l_lot_trk, l_exp_date_trk, l_mfg_date_trk
            FROM   pm
            WHERE  prod_id          = i_prod_id
               AND cust_pref_vendor = i_cust_pref_vendor;
               
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_msg := 'Item[' || i_prod_id || '] CPV[' || i_cust_pref_vendor || '] does not exist in PM.';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Inv_ProdId;
                
            WHEN OTHERS THEN
                l_msg := 'Unexpected ERROR while selecting item[' || i_prod_id || '] CPV[' || i_cust_pref_vendor || '] from PM.';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Data_Error;
                RAISE;
        END;    
    END IF;  -- Get needed item attributes
    
    -- Verify the item, PO is in PUTAWAYLST
  
    IF l_status = rf.status_normal THEN
        BEGIN
            SELECT door_no
              INTO l_door_no
            FROM   putawaylst
            WHERE  rec_id           = i_PO_Id
              AND  prod_id          = i_prod_id
              AND  cust_pref_vendor = i_cust_pref_vendor
              AND  ROWNUM = 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_msg := 'Item[' || i_prod_id || '] CPV[' || i_cust_pref_vendor || '] rec_id[' || i_po_id || '] not in PUTAWAYLST.';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Inv_ProdId;
                
            WHEN OTHERS THEN
                l_msg := 'Unexpected ERROR while selecting item[' || i_prod_id || '] CPV[' || i_cust_pref_vendor || '] rec_id[' || i_po_id || '] from PUTAWAYLST.';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Data_Error;
                RAISE;
        END; 
    END IF; -- Verify the item, PO is in PUTAWAYLST
    
    
    -- Set l_tti_trk and l_clam_bed_trk
    IF l_status = rf.status_normal THEN
        IF (pl_putaway_utilities.f_is_tti_tracked_item (i_prod_id, i_cust_pref_vendor) = TRUE) THEN
            l_tti_trk := 'Y';
        ELSE
            l_tti_trk := 'N';
        END IF;

        IF ( pl_putaway_utilities.f_is_clam_bed_tracked_item( l_category, l_r_syspars.clam_bed_tracked ) = TRUE ) THEN
            l_clam_bed_trk := 'Y';
        ELSE
            l_clam_bed_trk := 'N';
        END IF;
    END IF;  -- Set l_tti_trk and l_clam_bed_trk

    -- Insert putawaylst rec
    
    IF l_status = rf.status_normal THEN
        BEGIN
            INSERT INTO putawaylst(rec_id, 
                                   prod_id,
                                   cust_pref_vendor,
                                   dest_loc,
                                   qty,
                                   uom,                                  
                                   status,
                                   inv_status,
                                   pallet_id,
                                   door_no,
                                   qty_expected, 
                                   qty_received,                                  
                                   temp_trk,
                                   tti_trk,
                                   clam_bed_trk, 
                                   catch_wt,
                                   lot_trk,
                                   exp_date_trk,
                                   date_code,
                                   equip_id,
                                   rec_lane_id,
                                   seq_no,
                                   putaway_put,
                                   sn_no,
                                   po_no,
                                   po_line_id,
                                   erm_line_id,
                                   reason_code,
                                   demand_flag,
                                   exp_date,
                                   osd_lr_reason_cd)
                           VALUES (i_po_id, 
                                   i_prod_id,
                                   i_cust_pref_vendor,
                                   'LR', 
                                   0,
                                   i_uom, 
                                   'NEW',
                                   'AVL',
                                   l_pallet_id,
                                   l_door_no, 
                                   0, 
                                   0, 
                                   l_temp_trk,
                                   l_tti_trk, 
                                   l_clam_bed_trk,
                                   l_catch_wt_trk,
                                   l_lot_trk,
                                   l_exp_date_trk, 
                                   l_mfg_date_trk, 
                                   ' ', 
                                   ' ', 
                                   Max_seq_For_PO, 
                                   'N',
                                   null, 
                                   i_po_id,
                                   null, 
                                   l_erm_line_id,
                                   null, 
                                   'Y', 
                                   TRUNC(SYSDATE),
                                   'O');
                                   
            -- Ensure that 1 and only 1 record was inserted
            
            IF sql%rowcount = 1 THEN
                l_msg := 'Pallet addition to PO SUCCESSFUL for PO# [' 
                      || i_PO_Id  
                      || '] item [' 
                      || i_prod_id 
                      || '] CPV [' 
                      || i_Cust_Pref_Vendor
                      || '] UOM ['
                      || i_uom
                      || '] Pallet ID ['
                      || l_pallet_id
                      || ']';                      
                pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, G_Application_Func, G_This_Package);
            ELSE
                l_msg := 'NO RECORD INSERTED into PUTAWAYLST for PO# [' 
                      || i_PO_Id  
                      || '] item [' 
                      || i_prod_id 
                      || '] CPV [' 
                      || i_Cust_Pref_Vendor
                      || '] UOM ['
                      || i_uom
                      || '] Pallet ID ['
                      || l_pallet_id
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, G_Application_Func, G_This_Package);
                l_status := RF.Status_Data_Error;            
            END IF;  -- Ensure that 1 and only 1 record was inserted
                                   
        EXCEPTION
            WHEN OTHERS THEN
                l_msg := 'Unexpected ERROR during PUTAWAYLST INSERT for PO# [' 
                      || i_PO_Id  
                      || '] item [' 
                      || i_prod_id 
                      || '] CPV [' 
                      || i_Cust_Pref_Vendor
                      || '] UOM ['
                      || i_uom
                      || '] Pallet ID ['
                      || l_pallet_id
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
                l_status := RF.Status_Data_Error;
                ROLLBACK;
                RAISE;
        END; 
    END IF;  -- Insert putawaylst rec
    
    PL_LM_Rcv.Create_Receiver_Batches(i_pallet_id => l_pallet_id);
    
    -- Get refreshed PO list to send to RF client
    IF l_status = rf.status_normal THEN
        l_PO_Tbl := Get_PO_List_Within_Load(i_PO_Id);
        
        FOR po IN NVL(l_PO_Tbl.First, 0)..NVL(l_PO_Tbl.Last, -1) LOOP
          l_PO_Tbl(po).Item_Table := Get_Item_List_Within_Load(l_PO_Tbl(po).ERM_Id, l_table_status);
          IF l_table_status <>  RF.Status_Normal THEN
            l_status := l_table_status;
            RAISE e_fail;
          END IF;
        END LOOP;

        o_Detail_Collection := LR_PO_List_Obj(l_PO_Tbl);
    END IF; -- Get refreshed PO list to send to RF client

    l_msg := 'l_status at the end of ' || l_func_name || ' was [' || l_status || '].';
    pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, G_Application_Func, G_This_Package);
    
    RETURN(l_status);
    
    EXCEPTION
        WHEN e_fail THEN
            l_msg := 'ERROR while collecting PO detail list. Error code: [' || l_status || ']';
            pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, G_Application_Func, G_This_Package);
            RETURN(l_status);
            
        WHEN OTHERS THEN
            l_status := RF.Status_Data_Error;
            l_msg := 'Unexpected ERROR';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), G_Application_Func, G_This_Package);
            RAISE;
                        
  END Add_LP_To_PO_Internal;
  
  
  
   -- m.c. 9/23/21 modify on 2/3/22
   FUNCTION f_is_lr_active
   RETURN VARCHAR2    --BOOLEAN
   IS
      l_create_batch_flag  lbr_func.create_batch_flag%TYPE := NULL;
      l_lr_active    BOOLEAN;  -- Designates if returns putaway
                                            -- labor mgmt is active.
      l_lbr_mgmt_flag      sys_config.config_flag_val%TYPE := NULL;
      l_object_name        VARCHAR2(30) := 'f_is_lr_active';
      l_sqlerrm            VARCHAR2(500);  -- SQLERRM

      l_return_value VARCHAR2(3); --VARCHAR2(1);

      -- This cursor selects the create batch flag for lr labor mgmt.
      CURSOR c_lbr_func_returns IS
         SELECT create_batch_flag
           FROM swms.lbr_func
          WHERE lfun_lbr_func = 'LR';

   BEGIN
      l_lbr_mgmt_flag := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
	  
	  

      IF (l_lbr_mgmt_flag = 'Y') THEN
         -- Labor mgmt is on.
         
         OPEN c_lbr_func_returns;
         FETCH c_lbr_func_returns INTO l_create_batch_flag;

         IF (c_lbr_func_returns%NOTFOUND) THEN

            l_return_value := 'LRN';
         END IF;

         CLOSE c_lbr_func_returns;

         IF  (l_create_batch_flag = 'Y') THEN
            
            l_return_value := 'LRY';
         ELSE
           
            l_return_value := 'LRN';
         END IF;
      ELSE
        
         l_return_value := 'LMN';
      END IF;

     
      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         l_sqlerrm := SQLERRM;  -- Save mesg in case cursor cleanup fails.

         IF (c_lbr_func_returns%ISOPEN) THEN   -- Cursor cleanup.
            CLOSE c_lbr_func_returns;
         END IF;

         RAISE_APPLICATION_ERROR(-20001, l_object_name||' Error: ' ||
                                 l_sqlerrm);
   END f_is_lr_active;

  
      --------------------------------------------------------------------------------
-- Function
--   Receiving_Begin_Batch
--
-- Description
--   This SOAP web service is intended to mark the beginning of work for a given
--   pallet. It will be used to stop any active labor batch, if it exists. Then it
--   will initiate the labor batch for the given pallet to make it active.
--
-- Parameters
--    Parameter Name         Data Type      Description
--  Input:
--    i_RF_Log_Init_Record   RF_Log_Init_R  RF device initialization record
--    i_Pallet_Id      VARCHAR2       pallet identifier
--
--  Output:
--    None.
--
--  Status Returns:
--    RF.Status                      Description
--    ------------------------------ -------------------------------------------
--    Status_Normal                  Normal successful operation
--
-- Modification History
--
-- Date       User      Description
-- ---------- --------- --------------------------------------------------------
-- 07/22/22 mcha1213    add Receiving_Begin_Batch to this package for assign user id to LR batch
-- 08/19/22 mcha1213    change i_Blind_Pallet_Id to i_Pallet_Id
-- 09/02/21 mcha1213 return RF.STATUS_NO_LM_BATCH_FOUND for no batch exists in Receiving_Begin_Batch
-- 25-Sep-2021 mcha1213  Jira 3524 Added function f_is_lr_active to check lbr_func table for LR create_batch_flag
-- 01/12/22 mcha1213     Jira 3929  add more changes on 01/19/22 
--------------------------------------------------------------------------------
  FUNCTION Receiving_Begin_Batch( i_RF_Log_Init_Record  IN     RF_Log_Init_Record  /* Input:  RF device initialization record */
                                , i_Pallet_Id           IN     VARCHAR2            /* Input:  pallet identifier */
                                )
  RETURN RF.Status IS
   This_Function      CONSTANT all_source.name%TYPE := 'Receiving_Begin_Batch';

   RF_Status                   RF.Status := RF.Status_Normal;
   b_already_active            BOOLEAN := FALSE;

   l_batch_no                  arch_batch.batch_no%TYPE;
   l_user_id                   usr.user_id%TYPE;
   v_batch_status              batch.status%TYPE;

   l_kvi_cube                  NUMBER;
   l_kvi_wt                    NUMBER;
   l_kvi_no_pallet             NUMBER;
   l_kvi_no_item               NUMBER;
   l_kvi_no_data_capture       NUMBER;
   l_kvi_no_po                 NUMBER;
   l_kvi_no_case               NUMBER;

   l_kvi_cube_val              NUMBER;
   l_kvi_wt_val                NUMBER;
   l_kvi_no_pallet_val         NUMBER;
   l_kvi_no_item_val           NUMBER;
   l_kvi_no_data_capture_val   NUMBER;
   l_kvi_no_po_val             NUMBER;
   l_kvi_no_case_val           NUMBER;
--pd

BEGIN
  -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
  -- This must be done before calling rf.Initialize().

  NULL;

  -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

  RF_Status := RF.Initialize (i_RF_Log_Init_Record);

  -- Record input from RF device to web service

  RF.LogMsg( RF.Log_Info, This_Function || ': Input from RF'
                                        || ': Pallet_Id=' || CASE i_Pallet_Id IS NULL WHEN TRUE THEN 'NULL' ELSE '"' || i_Pallet_Id || '"' END
           );

  G_This_Message := 'Starting'
                   || '( i_Pallet_Id=' || NVL( i_Pallet_Id, 'NULL' )
                   || ' )';
    --8/25/21 replace by next line PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, G_This_Message
      --            , NULL, NULL, G_This_Application, G_This_Package );

   PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, G_This_Message
                  , NULL, NULL, G_Business_Function, G_This_Package );




	if (RF_Status = RF.Status_Normal) then -- add 1/19/2022
	
		G_This_Message := 'Passed validation of labor group assignment call PL_LM_Rcv.Create_Receiver_Batches next';
        PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                            , NULL, NULL, G_Business_Function, G_This_Package ); 
	
		begin
		
      
			PL_LM_Rcv.Create_Receiver_Batches( i_pallet_id => i_Pallet_Id ); -- 9/8/21 
      
			SELECT REPLACE (USER, 'OPS$'), pal.lm_rcv_batch_no
			INTO l_user_id, l_batch_no
			FROM putawaylst pal
			WHERE pal.pallet_id = i_Pallet_Id;

		exception  
         -- 9/2/21 mc add 
			WHEN NO_DATA_FOUND THEN
				G_This_Message :='No lm_rcv_batch_no data found error in putawaylst table for pallet id '|| NVL (i_Pallet_Id, 'NULL');
				PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, G_This_Message
                    , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );

				--RETURN RF.STATUS_NO_LM_BATCH_FOUND; 
				RF_Status := RF.STATUS_NO_LM_BATCH_FOUND;				
		end; 

    -- Lookup batch status. If already exists past future status, then create suffix batch and update batch_no with suffix before next call.
		BEGIN
			SELECT b.status
			INTO v_batch_status
			FROM batch b
			WHERE b.batch_no = l_batch_no;

			-- If batch status = "F"uture, then everything is good.
			-- Otherwise, search batch number for maximum suffix and add one to it.
			IF v_batch_status <> 'F' THEN
			DECLARE
				v_max_suffix      arch_batch.batch_no%TYPE;
				v_last_suffix     arch_batch.batch_no%TYPE;
				v_next_suffix     arch_batch.batch_no%TYPE;
				v_prefix          VARCHAR (20);
				v_last_char       VARCHAR2 (1);
				v_next_char       VARCHAR2 (1);
				v_orig_batch_no   arch_batch.batch_no%TYPE := l_batch_no;
			BEGIN

				SELECT MAX (b.batch_no)
				INTO v_max_suffix
				FROM batch b
				WHERE b.batch_no LIKE l_batch_no || '%';

				SELECT SUBSTR (v_max_suffix, LENGTH (l_batch_no) + 1)
				INTO v_last_suffix
				FROM DUAL;

				SELECT SUBSTR (v_last_suffix, 1, LENGTH (v_last_suffix) - 1)
				INTO v_prefix
				FROM DUAL;

				SELECT SUBSTR (v_last_suffix, LENGTH (v_last_suffix), 1)
				INTO v_last_char
				FROM DUAL;

				SELECT NVL (CHR (ASCII (v_last_char) + 1), 'A')
				INTO v_next_char
				FROM DUAL;

				l_batch_no := l_batch_no || v_next_char;

				-- if any change then create new batch and null old goal time on the batch,
				-- if decode 1 meaning equal to old data, 0 for all new kvi's, so goal time will be 0

				SELECT   SUM( DECODE( pal.uom, 1, NVL( pal.qty_received, pal.qty_expected ) * p.split_cube, 0 ) )  --  split_cube
                 + SUM( DECODE( pal.uom, 1, 0, ( NVL( pal.qty_received, pal.qty_expected ) / NVL ( p.spc, 1 ) ) * p.case_cube ) ) kvi_cube_val
                 --
               , DECODE( SUM( DECODE( pal.uom, 1, NVL( pal.qty_received, pal.qty_expected ) * p.split_cube, 0 ) )  --  split_cube
                 + SUM( DECODE( pal.uom, 1, 0, ( NVL( pal.qty_received, pal.qty_expected ) / NVL( p.spc, 1 ) ) * p.case_cube ) ), kvi_cube, 1, 2 ) kvi_cube
               , (   SUM( DECODE( pal.uom, 1, NVL( pal.qty_received, pal.qty_expected ) * ( p.g_weight / NVL( p.spc, 1 ) ), 0 ) )
                   + SUM( DECODE( pal.uom, 1, 0, NVL( pal.qty_received, pal.qty_expected ) * ( p.g_weight / NVL( p.spc, 1 ) ) ) ) ) kvi_wt_val2
                 --
               , DECODE( ( SUM( DECODE( pal.uom, 1, NVL( pal.qty_received, pal.qty_expected ) * ( p.g_weight / NVL( p.spc, 1 ) ), 0 ) )
                         + SUM( DECODE( pal.uom, 1, 0, NVL( pal.qty_received, pal.qty_expected ) * ( p.g_weight / NVL( p.spc, 1 ) ) ) ) ), kvi_wt, 1, 2 ) kvi_wt
                 --
               , COUNT( DISTINCT pal.rec_id ) kvi_no_pallet_val
               , DECODE( COUNT( DISTINCT pal.rec_id ), kvi_no_pallet, 1, 2 ) kvi_no_pallet
                 --
               , COUNT( DISTINCT pal.prod_id || '.' || pal.cust_pref_vendor ) kvi_no_item_val
               , DECODE( COUNT( DISTINCT pal.prod_id || '.' || pal.cust_pref_vendor ), kvi_no_item, 1, 2 ) kvi_no_item
                 --
               , ( SUM( DECODE( pal.exp_date_trk, 'Y', 1, 'C', 1, 0 ) ) --  num_dc_exp_date
                 + SUM( DECODE( pal.date_code   , 'Y', 1, 'C', 1, 0 ) ) --  num_dc_mfg_date
                 + SUM( DECODE( pal.lot_trk     , 'Y', 1, 'C', 1, 0 ) ) --  num_dc_lot_trk
                 + SUM( DECODE( pal.temp_trk    , 'Y', 1, 'C', 1, 0 ) ) --  num_dc_temp
                 + 1 ) kvi_no_data_capture_val
               , DECODE( ( SUM( DECODE( pal.exp_date_trk, 'Y', 1, 'C', 1, 0 ) ) --  num_dc_exp_date
                         + SUM( DECODE( pal.date_code   , 'Y', 1, 'C', 1, 0 ) ) --  num_dc_mfg_date
                         + SUM( DECODE( pal.lot_trk     , 'Y', 1, 'C', 1, 0 ) ) --  num_dc_lot_trk
                         + SUM( DECODE( pal.temp_trk    , 'Y', 1, 'C', 1, 0 ) ) --  num_dc_temp
                         + 1 )                     /* inbound pallet scan */
                       , kvi_no_data_capture, 1, 2 ) kvi_no_data_capture
                 --
               , COUNT( DISTINCT pal.rec_id ) kvi_no_po_val
               , DECODE( COUNT( DISTINCT pal.rec_id ), kvi_no_po, 1, 2 ) kvi_no_po
                 --
               , SUM( DECODE( pal.uom, 1, NVL( pal.qty_received, pal.qty_expected )
                                     , TRUNC( NVL( pal.qty_received, pal.qty_expected ) / NVL( p.spc, 1 ) ) ) ) kvi_no_case_val
               , DECODE( SUM( DECODE( pal.uom, 1, NVL( pal.qty_received, pal.qty_expected )
                                             , TRUNC( NVL( pal.qty_received, pal.qty_expected ) / NVL( p.spc, 1 ) ) ) )
                       , b.kvi_no_case, 1, 2 ) kvi_no_case
                 --
				INTO l_kvi_cube_val
               , l_kvi_cube
               , l_kvi_wt_val
               , l_kvi_wt
               , l_kvi_no_pallet_val
               , l_kvi_no_pallet
               , l_kvi_no_item_val
               , l_kvi_no_item
               , l_kvi_no_data_capture_val
               , l_kvi_no_data_capture
               , l_kvi_no_po_val
               , l_kvi_no_po
               , l_kvi_no_case_val
               , l_kvi_no_case
				FROM putawaylst pal
               , pm p
               , batch b
				WHERE b.batch_no = pal.lm_rcv_batch_no
				AND pal.lm_rcv_batch_no = v_orig_batch_no
				AND pal.prod_id = p.prod_id
				AND pal.cust_pref_vendor = p.cust_pref_vendor
				GROUP BY kvi_no_case
                 , kvi_cube
                 , kvi_wt
                 , kvi_no_item
                 , kvi_no_data_capture
                 , kvi_no_pallet
                 , batch_no
                 , jbcd_job_code
                 , kvi_no_po
                 , ref_no;

				IF ( l_kvi_cube            = 2 OR
               l_kvi_wt              = 2 OR
               l_kvi_no_pallet       = 2 OR
               l_kvi_no_item         = 2 OR
               l_kvi_no_data_capture = 2 OR
               l_kvi_no_po           = 2 OR
               l_kvi_no_case         = 2 ) THEN
				--Create with new kvi values and update old kvi values to null,
				--calculate goal time and send to flex, lxli_send_flag = NULL
				BEGIN

					G_This_Message :='Starting insert batch ' || l_kvi_no_case || ' ' || v_orig_batch_no ;
					PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                            , NULL, NULL, G_Business_Function, G_This_Package );

					UPDATE batch
					SET kvi_cube             = 0
                   , kvi_wt               = 0
                   , kvi_no_pallet        = 0
                   , kvi_no_item          = 0
                   , kvi_no_data_capture  = 0
                   , kvi_no_po            = 0
                   , kvi_no_case          = 0
                   , goal_time            = 0
                   , target_time          = 0
                   , lxli_send_flag       = NULL
					WHERE batch_no LIKE v_orig_batch_no || '%'
					AND batch_no NOT IN ( l_batch_no );

					INSERT INTO batch( batch_no           , batch_date, status      , jbcd_job_code, user_id
                               , ref_no             , kvi_cube  , kvi_wt      , kvi_no_pallet, kvi_no_item
                               , kvi_no_data_capture, kvi_no_po , kvi_no_case )
					SELECT l_batch_no
                     , TRUNC( SYSDATE )
                     , 'X'
                     , jbcd_job_code
                     , NULL
                     , ref_no
                     , l_kvi_cube_val
                     , l_kvi_wt_val
                     , l_kvi_no_pallet_val
                     , l_kvi_no_item_val
                     , l_kvi_no_data_capture_val
                     , l_kvi_no_po_val
                     , l_kvi_no_case_val
					FROM batch b
					WHERE b.batch_no = v_orig_batch_no;

				EXCEPTION
					WHEN OTHERS THEN
						G_This_Message := 'Error creating/updating new/old batch.' || l_batch_no;
						PL_Log.Ins_Msg( PL_Log.CT_Warn_Msg, This_Function, G_This_Message
                              , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );
				END;

				PL_LM_Time.Load_GoalTime (l_batch_no);

			ELSE
            -- Now, create the new live-receiving labor batch
				BEGIN

					G_This_Message := 'Starting new LR batch with no change insert batch ' || l_kvi_no_case || ' ' || v_orig_batch_no ;
					PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, G_This_Message
                            , NULL, NULL, G_Business_Function, G_This_Package );

					INSERT INTO batch( batch_no           , batch_date, status      , jbcd_job_code, user_id
                               , ref_no             , kvi_cube  , kvi_wt      , kvi_no_pallet, kvi_no_item
                               , kvi_no_data_capture, kvi_no_po , kvi_no_case )
					SELECT l_batch_no         -- batch_no
                     , TRUNC( SYSDATE )   -- batch_date
                     , 'X'                -- status
                     , jbcd_job_code      -- jbcd_job_code
                     , NULL               -- user_id
                     , ref_no             -- ref_no
                     , 0                  -- kvi_cube
                     , 0                  -- kvi_wt
                     , 0                  -- kvi_no_pallet
                     , 0                  -- kvi_no_item
                     , 0                  -- kvi_no_data_capture
                     , 0                  -- kvi_no_po
                     , 0                  -- kvi_no_case
					FROM batch b
					WHERE b.batch_no = v_orig_batch_no;
				EXCEPTION
					WHEN OTHERS THEN
					G_This_Message := 'Exception occurred while creating new labor batch=' || NVL( l_batch_no, 'NULL' ) || '.' ;
					PL_Log.Ins_Msg( PL_Log.CT_Warn_Msg, This_Function, G_This_Message
                              , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );
				END;

            PL_LM_Time.Load_GoalTime (l_batch_no);
          END IF;

        END;
      END IF;
    EXCEPTION
      -- 9/2/21 mc add 
      WHEN NO_DATA_FOUND THEN
        G_This_Message :='No data found error in batch table for batch '|| NVL (l_batch_no, 'NULL');
        PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, G_This_Message
                    , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );
        RETURN RF.STATUS_NO_LM_BATCH_FOUND;
      WHEN OTHERS THEN
        G_This_Message := 'Unexpected error occurred while validating labor batch existence.';
        PL_Log.Ins_Msg( PL_Log.CT_Warn_Msg, This_Function, G_This_Message
                      , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );
        RAISE;
    END;

   
    
    G_This_Message :='PL_LMC.SignOn_To_Batch'|| '( i_user_id='|| NVL (l_user_id, 'NULL')|| ', i_new_batch='|| NVL (l_batch_no, 'NULL')|| ' )';
    PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, G_This_Message
                  , NULL, NULL, G_Business_Function, G_This_Package );


    PL_LMC.SignOn_To_Batch( i_user_id   => l_user_id
                          , i_new_batch => l_batch_no );
	end if; -- add 1/19/2022
	


  -- Record output to RF device via web service
/*
  RF.LogMsg( RF.Log_Info, This_Function || ': Output from RF'
  -- no outputs
           );
*/

  G_This_Message := 'Returning with status=' || NVL( TO_CHAR( RF_Status ), 'NULL' );
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, G_This_Message
                , NULL, NULL, G_Business_Function, G_This_Package );
  RF.Complete( RF_Status );
  RETURN( RF_Status );
EXCEPTION
  WHEN OTHERS THEN
    G_This_Message := 'Error occurred while activating live receiving labor batch for  pallet=['|| NVL (i_Pallet_Id, 'NULL')|| ']';
    PL_Log.Ins_Msg( PL_Log.CT_Warn_Msg, This_Function, G_This_Message
                  , SQLCODE, SQLERRM, G_Business_Function, G_This_Package );
    RF.LogException();                                             -- log it
    RAISE;
END Receiving_Begin_Batch;
  

END PL_RF_Live_Receiving;
/

SHOW ERRORS;

--ALTER PACKAGE SWMS.PL_RF_Live_Receiving COMPILE PLSQL_CODE_TYPE = INTERPRETED /*NATIVE*/;

GRANT EXECUTE ON SWMS.PL_RF_Live_Receiving TO SWMS_User;

CREATE OR REPLACE PUBLIC SYNONYM PL_RF_Live_Receiving FOR SWMS.PL_RF_Live_Receiving;
