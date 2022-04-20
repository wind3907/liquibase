SET ECHO OFF
SET SCAN OFF
/*=============================================================================================
  Types for the Live Receiving Query Results
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  30-AUG-2016    bgil6182         Initial Version
  21-OCT-2021    bgil6182         OPCOF-3541: added OS&D reason code to LR_LPN_List_Rec
  =============================================================================================*/

/* Individual attributes of the UPC (Universal Product Code) */

CREATE OR REPLACE
TYPE SWMS.LR_UPC_List_Rec FORCE AS
OBJECT
(
    UPC_Type              VARCHAR2(1 CHAR)    /* Calculated: (?) */
  , UPC_Code              VARCHAR2(14 CHAR)   /* Calculated: (?) */
  , MEMBER PROCEDURE Display( Self      IN OUT NOCOPY SWMS.LR_UPC_List_Rec
                            , New_Line  IN            BOOLEAN               DEFAULT TRUE )
);
/

CREATE OR REPLACE
TYPE BODY SWMS.LR_UPC_List_Rec AS
  MEMBER PROCEDURE Display( Self      IN OUT NOCOPY SWMS.LR_UPC_List_Rec
                          , New_Line  IN            BOOLEAN               DEFAULT TRUE ) IS -- New line for each UPC?
  BEGIN
    DBMS_Output.Put( '( UPC_Type=' || NVL( UPC_Type, 'NULL' ) );
    DBMS_Output.Put( ', UPC_Code=' || NVL( UPC_Code, 'NULL' ) );
    IF New_Line THEN
      DBMS_Output.Put_Line( ' )' );
    ELSE
      DBMS_Output.Put( ' )' );
    END IF;
  END Display;
END;
/
SHOW ERRORS

CREATE OR REPLACE
TYPE SWMS.LR_UPC_List_Table FORCE AS
TABLE OF SWMS.LR_UPC_List_Rec;
/

/* Individual attributes of the LPN */

CREATE OR REPLACE
TYPE SWMS.LR_LPN_List_Rec FORCE AS
OBJECT
(
    Pallet_Id             VARCHAR2(18 CHAR)   /* PUTAWAYLST.PALLET_ID */
  , Erm_Type              VARCHAR2(3 CHAR)    /* ERM.ERM_TYPE */
  , Qty_Expected          NUMBER(8)           /* PUTAWAYLST.QTY_EXPECTED */
  , Qty_Received          NUMBER(8)           /* PUTAWAYLST.QTY_RECEIVED */
  , Exp_Date              VARCHAR2(6 CHAR)    /* Calculated: TO_CHAR(putawaylst.exp_date,G_RF_Date_Format) */
  , Exp_Date_Ind          VARCHAR2(1 CHAR)    /* PUTAWAYLST.EXP_DATE_TRK (Indicator for PUTAWAYLST.EXP_DATE) */
  , Mfg_Date              VARCHAR2(6 CHAR)    /* Calculated: TO_CHAR(putawaylst.mfg_date,G_RF_Date_Format) */
  , Mfg_Date_Ind          VARCHAR2(1 CHAR)    /* PUTAWAYLST.DATE_CODE (Indicator for PUTAWAYLST.MFG_DATE) */
  , Lot_Id                VARCHAR2(120 CHAR)  /* PUTAWAYLST.LOT_ID */
  , Lot_Ind               VARCHAR2(1 CHAR)    /* PUTAWAYLST.LOT_TRK (Indicator for PUTAWAYLST.LOT_ID) */
  , Temp                  NUMBER(6,1)         /* PUTAWAYLST.TEMP (Collected Termperature) */
  , Temp_Ind              VARCHAR2(1 CHAR)    /* PUTAWAYLST.TEMP_TRK (Indicator for PUTAWAYLST.TEMP) */
  , TTI_Value             VARCHAR2(1 CHAR)    /* PUTAWAYLST.TTI (Collected Temperature?, NULL in table, maybe refer to TEMP field instead?) */
  , TTI_Ind               VARCHAR2(1 CHAR)    /* PUTAWAYLST.TTI_TRK (Temperature Tracking Indicator, Indicator for PUTAWAYLST.TTI) */
  , CryoVac_Value         VARCHAR2(1 CHAR)    /* PUTAWAYLST.CRYOVAC (Vaccuum-Packed Bacterial Prevention, Indicator for PUTAWAYLST.TEMP) */
  , Catch_Wt_Ind          VARCHAR2(1 CHAR)    /* PUTAWAYLST.CATCH_WT (Indicator for TMP_WEIGHT.TOTAL_WEIGHT) */
  , Clam_Bed_Ind          VARCHAR2(1 CHAR)    /* PUTAWAYLST.CLAM_BED_TRK (Indicator for TRANS.CLAM_BED_NO & TRANS.EXP_DATE "Harvest_Date") */
  , Cool_Ind              VARCHAR2(1 CHAR)    /* PUTAWAYLST.COOL_TRK (Indicator for Country Of Origin-no actual data field) */
  , Dest_Loc              VARCHAR2(10 CHAR)   /* PUTAWAYLST.DEST_LOC */
  , Status                NUMBER(1)           /* Calculated: DECODE(PUTAWAYLST.PUTAWAY_PUT,'Y',2,DECODE(PUTAWAYLST.STATUS,'CHK',1,'NEW',0,-1)
                                                             WHERE SUBSTR(PUTAWAYLST.REC_ID,1,1) BETWEEN '0' AND '9' */
  , OSD_Reason_Cd         VARCHAR2(3 CHAR)    /* PUTAWAYLST.OSD_LR_REASON_CD (When LR Qty_Ordered<>Qty_Received, reason for delta) */
  , CONSTRUCTOR FUNCTION LR_LPN_List_Rec( Pallet_Id             VARCHAR2
                                        , Erm_Type              VARCHAR2
                                        , Qty_Expected          NUMBER
                                        , Qty_Received          NUMBER
                                        , Exp_Date              VARCHAR2
                                        , Exp_Date_Ind          VARCHAR2
                                        , Mfg_Date              VARCHAR2
                                        , Mfg_Date_Ind          VARCHAR2
                                        , Lot_Id                VARCHAR2
                                        , Lot_Ind               VARCHAR2
                                        , Temp                  NUMBER
                                        , Temp_Ind              VARCHAR2
                                        , TTI_Value             VARCHAR2
                                        , TTI_Ind               VARCHAR2
                                        , CryoVac_Value         VARCHAR2
                                        , Catch_Wt_Ind          VARCHAR2
                                        , Clam_Bed_Ind          VARCHAR2
                                        , Cool_Ind              VARCHAR2
                                        , Dest_Loc              VARCHAR2
                                        , Status                NUMBER
                                        , OSD_Reason_Cd         VARCHAR2
                                        ) RETURN SELF AS RESULT
  , MEMBER PROCEDURE Display( Self     IN OUT NOCOPY SWMS.LR_LPN_List_Rec
                            , New_Line IN            BOOLEAN              DEFAULT TRUE )
);
/

CREATE OR REPLACE
TYPE BODY SWMS.LR_LPN_List_Rec AS
  CONSTRUCTOR FUNCTION LR_LPN_List_Rec( Pallet_Id             VARCHAR2
                                      , Erm_Type              VARCHAR2
                                      , Qty_Expected          NUMBER
                                      , Qty_Received          NUMBER
                                      , Exp_Date              VARCHAR2
                                      , Exp_Date_Ind          VARCHAR2
                                      , Mfg_Date              VARCHAR2
                                      , Mfg_Date_Ind          VARCHAR2
                                      , Lot_Id                VARCHAR2
                                      , Lot_Ind               VARCHAR2
                                      , Temp                  NUMBER
                                      , Temp_Ind              VARCHAR2
                                      , TTI_Value             VARCHAR2
                                      , TTI_Ind               VARCHAR2
                                      , CryoVac_Value         VARCHAR2
                                      , Catch_Wt_Ind          VARCHAR2
                                      , Clam_Bed_Ind          VARCHAR2
                                      , Cool_Ind              VARCHAR2
                                      , Dest_Loc              VARCHAR2
                                      , Status                NUMBER
                                      , OSD_Reason_Cd         VARCHAR2
                                      ) RETURN SELF AS RESULT IS
  BEGIN
      SELF.Pallet_Id     := Pallet_Id;
      SELF.Erm_Type      := Erm_Type;
      SELF.Qty_Expected  := NVL(Qty_Expected,0);
      SELF.Qty_Received  := NVL(Qty_Received,0);
      SELF.Exp_Date      := Exp_Date;
      SELF.Exp_Date_Ind  := Exp_Date_Ind;
      SELF.Mfg_Date      := Mfg_Date;
      SELF.Mfg_Date_Ind  := Mfg_Date_Ind;
      SELF.Lot_Id        := Lot_Id;
      SELF.Lot_Ind       := Lot_Ind;
      SELF.Temp          := NVL(Temp,0);
      SELF.Temp_Ind      := Temp_Ind;
      SELF.TTI_Value     := TTI_Value;
      SELF.TTI_Ind       := TTI_Ind;
      SELF.CryoVac_Value := CryoVac_Value;
      SELF.Catch_Wt_Ind  := Catch_Wt_Ind;
      SELF.Clam_Bed_Ind  := Clam_Bed_Ind;
      SELF.Cool_Ind      := Cool_Ind;
      SELF.Dest_Loc      := Dest_Loc;
      SELF.Status        := NVL(Status,0);
      SELF.OSD_Reason_Cd := OSD_Reason_Cd;
      RETURN;
  END;
  MEMBER PROCEDURE Display( Self     IN OUT NOCOPY SWMS.LR_LPN_List_Rec
                          , New_Line IN            BOOLEAN              DEFAULT TRUE ) IS -- New line for each pallet?
  BEGIN
    DBMS_Output.Put( '( Pallet_Id='     || NVL(         Pallet_Id    , 'NULL' ) );
    DBMS_Output.Put( ', Qty_Expected='  || NVL( TO_CHAR(Qty_Expected), 'NULL' ) );
    DBMS_Output.Put( ', Qty_Received='  || NVL( TO_CHAR(Qty_Received), 'NULL' ) );
    DBMS_Output.Put( ', Exp_Date='      || NVL(         Exp_Date     , 'NULL' ) );
    DBMS_Output.Put( ', Exp_Date_Ind='  || NVL(         Exp_Date_Ind , 'NULL' ) );
    DBMS_Output.Put( ', Mfg_Date='      || NVL(         Mfg_Date     , 'NULL' ) );
    DBMS_Output.Put( ', Mfg_Date_Ind='  || NVL(         Mfg_Date_Ind , 'NULL' ) );
    DBMS_Output.Put( ', Lot_Id='        || NVL(         Lot_Id       , 'NULL' ) );
    DBMS_Output.Put( ', Lot_Ind='       || NVL(         Lot_Ind      , 'NULL' ) );
    DBMS_Output.Put( ', Temp='          || NVL( TO_CHAR(Temp        ), 'NULL' ) );
    DBMS_Output.Put( ', Temp_Ind='      || NVL(         Temp_Ind     , 'NULL' ) );
    DBMS_Output.Put( ', TTI='           || NVL(         TTI_Value    , 'NULL' ) );
    DBMS_Output.Put( ', TTI_Ind='       || NVL(         TTI_Ind      , 'NULL' ) );
    DBMS_Output.Put( ', CryoVac='       || NVL(         CryoVac_Value, 'NULL' ) );
    DBMS_Output.Put( ', Catch_Wt_Ind='  || NVL(         Catch_Wt_Ind , 'NULL' ) );
    DBMS_Output.Put( ', Clam_Bed_Ind='  || NVL(         Clam_Bed_Ind , 'NULL' ) );
    DBMS_Output.Put( ', Cool_Ind='      || NVL(         Cool_Ind     , 'NULL' ) );
    DBMS_Output.Put( ', Dest_Loc='      || NVL(         Dest_Loc     , 'NULL' ) );
    DBMS_Output.Put( ', Status='        || NVL( TO_CHAR(Status      ), 'NULL' ) );
    DBMS_Output.Put( ', OSD_Reason_Cd=' || NVL(         OSD_Reason_Cd, 'NULL' ) );
    IF New_Line THEN
      DBMS_Output.Put_Line( ' )' );
    ELSE
      DBMS_Output.Put( ' )' );
    END IF;
  END Display;
END;
/
SHOW ERRORS

CREATE OR REPLACE
TYPE SWMS.LR_LPN_List_Table FORCE AS
TABLE OF SWMS.LR_LPN_List_Rec;
/

/* Individual attributes of the Item/Product */
/*   NOTE:  Original Pro*C code implemented with NUMBER(4) for the three shelf lives.
            Since the RF code performs differently when these values are not set (NULL),
            and the WSDL servicing defaults NULL automatically to 0, we changed to a STRING representation */

CREATE OR REPLACE
TYPE SWMS.LR_Item_List_Rec FORCE AS
OBJECT
(
    Prod_Id               VARCHAR2(9 CHAR)    /* PM.PROD_ID */
  , Sysco_Shelf_Life      VARCHAR2(4 CHAR)    /* PM.SYSCO_SHELF_LIFE */
  , Max_Temp              NUMBER(6,1)         /* PM.MAX_TEMP */
  , Min_Temp              NUMBER(6,1)         /* PM.MIN_TEMP */
  , TI                    NUMBER(4)           /* PM.TI */
  , HI                    NUMBER(4)           /* PM.HI */
  , Pallet_Type           VARCHAR2(2 CHAR)    /* PM.PALLET_TYPE */
  , Cust_Pref_Vendor      VARCHAR2(10 CHAR)   /* PM.CUST_PREF_VENDOR */
  , UOM                   NUMBER(2)           /* LP.UOM (Unit Of Measure) */
  , SPC                   NUMBER(4)           /* PM.SPC (Splits Per Case) */
  , Cust_Shelf_Life       VARCHAR2(4 CHAR)    /* PM.CUST_SHELF_LIFE */
  , Mfr_Shelf_Life        VARCHAR2(4 CHAR)    /* PM.MFR_SHELF_LIFE */
  , UPC_Comp_Flag         VARCHAR2(1 CHAR)    /* Calculated Check_UPC_Data_Collection */
  , Clam_Bed_Num          VARCHAR2(10 CHAR)   /* TRANS.CLAM_BED_NO */
  , Harvest_Date          VARCHAR2(6 CHAR)    /* Calculated: TO_CHAR(trans.exp_date,G_RF_Date_Format) */
  , Total_Cases           NUMBER(7)           /* TMP_WEIGHT.TOTAL_CASES */
  , Total_Splits          NUMBER(7)           /* TMP_WEIGHT.TOTAL_SPLITS */
  , Total_Wt              NUMBER(9,3)         /* TMP_WEIGHT.TOTAL_WEIGHT */
  , Default_Weight_Unit   VARCHAR2(2 CHAR)    /* PM.DEFAULT_WEIGHT_UNIT */
  , Descrip               VARCHAR2(100 CHAR)  /* PM.DESCRIP VARCHAR2(30) extended for possible XML character translations */
  , Mfg_SKU               VARCHAR2(14 CHAR)   /* PM.MFG_SKU */
  , Pack                  VARCHAR2(4 CHAR)    /* PM.PACK */
  , Prod_Size             VARCHAR2(6 CHAR)    /* PM.PROD_SIZE */
  , UCN                   VARCHAR2(6 CHAR)    /* SUBSTR(PM.EXTERNAL_UPC,9,14-9+1) */
  , Pick_Loc              VARCHAR2(10 CHAR)   /* LOC.LOGI_LOC */
  , Message_Fld           VARCHAR2(100 CHAR)  /* Calculated? */
  , Brand                 VARCHAR2(7 CHAR)    /* PM.BRAND */
--  , Catch_Wt_Trk          VARCHAR2(1 CHAR)    /* PM.CATCH_WT_TRK (Is catch weight required for this product?) */
  , LPN_Table              SWMS.LR_LPN_List_Table
  , UPC_Table              SWMS.LR_UPC_List_Table
  , MEMBER PROCEDURE Display( Self     IN OUT NOCOPY SWMS.LR_Item_List_Rec
                            , New_Line IN            BOOLEAN                DEFAULT TRUE )
);
/

CREATE OR REPLACE
TYPE BODY SWMS.LR_Item_List_Rec AS
  MEMBER PROCEDURE Display( Self     IN OUT NOCOPY SWMS.LR_Item_List_Rec
                          , New_Line IN            BOOLEAN                DEFAULT TRUE ) IS -- New line for each item?
    lpn PLS_INTEGER;
    upc PLS_INTEGER;
  BEGIN
    DBMS_Output.Put( '( Prod_Id='             || NVL(         Prod_Id             , 'NULL' ) );
    DBMS_Output.Put( ', Sysco_Shelf_Life='    || NVL( TO_CHAR(Sysco_Shelf_Life   ), 'NULL' ) );
    DBMS_Output.Put( ', Max_Temp='            || NVL( TO_CHAR(Max_Temp           ), 'NULL' ) );
    DBMS_Output.Put( ', Min_Temp='            || NVL( TO_CHAR(Min_Temp           ), 'NULL' ) );
    DBMS_Output.Put( ', TI='                  || NVL( TO_CHAR(TI                 ), 'NULL' ) );
    DBMS_Output.Put( ', HI='                  || NVL( TO_CHAR(HI                 ), 'NULL' ) );
    DBMS_Output.Put( ', Pallet_Type='         || NVL(         Pallet_Type         , 'NULL' ) );
    DBMS_Output.Put( ', Cust_Pref_Vendor='    || NVL(         Cust_Pref_Vendor    , 'NULL' ) );
    DBMS_Output.Put( ', UOM='                 || NVL( TO_CHAR(UOM                ), 'NULL' ) );
    DBMS_Output.Put( ', SPC='                 || NVL( TO_CHAR(SPC                ), 'NULL' ) );
    DBMS_Output.Put( ', Cust_Shelf_Life='     || NVL( TO_CHAR(Cust_Shelf_Life    ), 'NULL' ) );
    DBMS_Output.Put( ', Mfr_Shelf_Life='      || NVL( TO_CHAR(Mfr_Shelf_Life     ), 'NULL' ) );
    DBMS_Output.Put( ', UPC_Comp_Flag='       || NVL(         UPC_Comp_Flag       , 'NULL' ) );
    DBMS_Output.Put( ', Clam_Bed_Num='        || NVL(         Clam_Bed_Num        , 'NULL' ) );
    DBMS_Output.Put( ', Harvest_Date='        || NVL(         Harvest_Date        , 'NULL' ) );
    DBMS_Output.Put( ', Total_Cases='         || NVL( TO_CHAR(Total_Cases        ), 'NULL' ) );
    DBMS_Output.Put( ', Total_Splits='        || NVL( TO_CHAR(Total_Splits       ), 'NULL' ) );
    DBMS_Output.Put( ', Total_Wt='            || NVL( TO_CHAR(Total_Wt           ), 'NULL' ) );
    DBMS_Output.Put( ', Default_Weight_Unit=' || NVL(         Default_Weight_Unit , 'NULL' ) );
    DBMS_Output.Put( ', Descrip='             || NVL(         Descrip             , 'NULL' ) );
    DBMS_Output.Put( ', Mfg_SKU='             || NVL(         Mfg_SKU             , 'NULL' ) );
    DBMS_Output.Put( ', Pack='                || NVL(         Pack                , 'NULL' ) );
    DBMS_Output.Put( ', Prod_Size='           || NVL(         Prod_Size           , 'NULL' ) );
    DBMS_Output.Put( ', UCN='                 || NVL(         UCN                 , 'NULL' ) );
    DBMS_Output.Put( ', Pick_Loc='            || NVL(         Pick_Loc            , 'NULL' ) );
    DBMS_Output.Put( ', Message_Fld='         || NVL(         Message_Fld         , 'NULL' ) );
    DBMS_Output.Put( ', Brand='               || NVL(         Brand               , 'NULL' ) );
--    DBMS_Output.Put( ', Catch_Wt_Trk='        || Catch_Wt_Trk );

    DBMS_Output.Put( ', ' );            -- Separate next object
    IF ( LPN_Table IS NULL ) THEN
      DBMS_Output.Put( 'LPN_Table is uninitialized' );
    ELSE
      IF ( LPN_Table.First IS NULL OR LPN_Table.Last IS NULL ) THEN
        DBMS_Output.Put( 'LPN_Table is empty' );
      ELSE
        FOR lpn IN NVL(LPN_Table.First,0)..NVL(LPN_Table.Last,-1) LOOP
          IF ( lpn = LPN_Table.First ) THEN
            DBMS_Output.Put( '{ ' );    -- Open group
          ELSE
            DBMS_Output.Put( ', ' );    -- Separate next element
          END IF;
          DBMS_Output.Put( 'LPN_Table(' || TO_CHAR(lpn) || ')=' ); LPN_Table(lpn).Display( FALSE );
        END LOOP;
      END IF;
    END IF;
    DBMS_Output.Put( ' }' );            -- Close Group

    DBMS_Output.Put( ', ' );            -- Separate next object
    IF ( UPC_Table IS NULL ) THEN
      DBMS_Output.Put( 'UPC_Table is uninitialized' );
    ELSE
      IF ( UPC_Table.First IS NULL OR UPC_Table.Last IS NULL ) THEN
        DBMS_Output.Put( 'UPC_Table is empty' );
      ELSE
        FOR upc IN NVL(UPC_Table.First,0)..NVL(UPC_Table.Last,-1) LOOP
          IF ( upc = UPC_Table.First ) THEN
            DBMS_Output.Put( '{ ' );    -- Open group
          ELSE
            DBMS_Output.Put( ', ' );    -- Separate next element
          END IF;
          DBMS_Output.Put( 'UPC_Table(' || TO_CHAR(upc) || ')=' ); UPC_Table(upc).Display( FALSE );
        END LOOP;
        IF New_Line THEN                  -- Close group
          DBMS_Output.Put_Line( ' }' );
        ELSE
          DBMS_Output.Put( ' }' );
        END IF;
     END IF;
   END IF;
  END Display;
END;
/
SHOW ERRORS

CREATE OR REPLACE
TYPE      SWMS.LR_Item_List_Table FORCE
    AS TABLE OF SWMS.LR_Item_List_Rec;
/

/* Individual attributes of the PO (Purchase Order) */

CREATE OR REPLACE
TYPE      SWMS.LR_PO_List_Rec FORCE AS OBJECT
(
    Erm_Id                VARCHAR2(12 CHAR)   /* ERM.ERM_ID */
  , Rec_Date              VARCHAR2(10 CHAR)   /* ERM.REC_DATE, Format: MMDDYY */
  , Item_Table            SWMS.LR_Item_List_Table
  , MEMBER PROCEDURE Display( Self      IN OUT NOCOPY SWMS.LR_PO_List_Rec
                            , New_Line  IN            BOOLEAN             DEFAULT TRUE )
);
/

CREATE OR REPLACE
TYPE BODY SWMS.LR_PO_List_Rec AS
  MEMBER PROCEDURE Display( Self      IN OUT NOCOPY SWMS.LR_PO_List_Rec
                          , New_Line  IN            BOOLEAN             DEFAULT TRUE ) IS  -- New line for each purchase order?
    item PLS_INTEGER;
  BEGIN
    DBMS_Output.Put( '( ERM_Id='    || NVL( ERM_Id, 'NULL' ) );
    DBMS_Output.Put( ', Rec_Date='  || NVL( Rec_Date, 'NULL' ) );
    DBMS_Output.Put( ', ' );
    IF ( Item_Table IS NULL ) THEN
      DBMS_Output.Put( 'Item_Table is uninitialized' );
    ELSE
      IF ( Item_Table.First IS NULL OR Item_Table.Last IS NULL ) THEN
        DBMS_Output.Put( 'Item_Table is empty' );
      ELSE
        FOR item IN NVL(Item_Table.First,0)..NVL(Item_Table.Last,-1) LOOP
          IF ( item = Item_Table.First ) THEN
            DBMS_Output.Put( '{ ' );    -- Open group
          ELSE
            DBMS_Output.Put( ', ' );    -- Separate next element
          END IF;
          DBMS_Output.Put( 'Item_Table(' || TO_CHAR(item) || ')=' ); Item_Table(item).Display( FALSE );
        END LOOP;
        IF New_Line THEN                  -- Close group
          DBMS_Output.Put_Line( ' }' );
        ELSE
          DBMS_Output.Put( ' }' );
        END IF;
      END IF;
    END IF;
  END Display;
END;
/
SHOW ERRORS

CREATE OR REPLACE
TYPE      SWMS.LR_PO_List_Table FORCE
    AS TABLE OF SWMS.LR_PO_List_Rec;
/

CREATE OR REPLACE
TYPE      SWMS.LR_PO_List_Obj FORCE AS OBJECT
(
    PO_Table    SWMS.LR_PO_List_Table
  , MEMBER PROCEDURE Display( Self      IN OUT NOCOPY SWMS.LR_PO_List_Obj
                            , New_Line  IN            BOOLEAN             DEFAULT TRUE )
);
/

CREATE OR REPLACE
TYPE BODY SWMS.LR_PO_List_Obj IS
  MEMBER PROCEDURE Display( Self      IN OUT NOCOPY SWMS.LR_PO_List_Obj
                          , New_Line  IN            BOOLEAN             DEFAULT TRUE ) IS
    po PLS_INTEGER;
  BEGIN
    DBMS_Output.Put( '( ' );      -- Open object
    IF ( PO_Table IS NULL ) THEN
      DBMS_Output.Put( 'PO_Table is uninitialized' );
    ELSE
      IF ( PO_Table.First IS NULL OR PO_Table.Last IS NULL ) THEN
        DBMS_Output.Put( 'PO_Table is empty' );
      ELSE
        FOR po IN NVL(PO_Table.First,0)..NVL(PO_Table.Last,-1) LOOP
          IF ( po = PO_Table.First ) THEN
            DBMS_Output.Put( '{ ' );    -- Open group
          ELSE
            DBMS_Output.Put( ', ' );    -- Separate next element
          END IF;
          DBMS_Output.Put( 'PO_Table(' || TO_CHAR(po) || ')=' ); PO_Table(po).Display( FALSE );
        END LOOP;
        DBMS_Output.Put( ' }' );       -- Close group
      END IF;
    END IF;
    IF New_Line THEN                -- Close group
      DBMS_Output.Put_Line( ' )' );
    ELSE
      DBMS_Output.Put( ' )' );
    END IF;
  END Display;
END;
/
SHOW ERRORS

GRANT EXECUTE ON SWMS.LR_UPC_List_Rec TO SWMS_User;
GRANT EXECUTE ON SWMS.LR_LPN_List_Rec TO SWMS_User;
GRANT EXECUTE ON SWMS.LR_Item_List_Rec TO SWMS_User;
GRANT EXECUTE ON SWMS.LR_PO_List_Rec TO SWMS_User;
GRANT EXECUTE ON SWMS.LR_PO_List_Obj TO SWMS_User;
