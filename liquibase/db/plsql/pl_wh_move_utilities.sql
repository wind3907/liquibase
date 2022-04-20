CREATE OR REPLACE PACKAGE swms.pl_wh_move_utilities
AUTHID CURRENT_USER
AS
-- sccs_id=%Z% %W% %G% %I%
-----------------------------------------------------------------------------
-- Package Name:
--   
--
-- Description:
--    Package for warehouse move utilities that are ** NOT ** referencing
--    any objects in the WHMOVE schema.
--
--    This package is for objects associated with a warehouse move and are
--    NOT referencing any WHMOVE schema objects.  The package is intended
--    to be used in the SWMS everyday processing by forms, etc that are
--    also used in the warehouse move processing.  Such as the 
--    proforma correction form rp1sd.
--
--    The reason for having the package is so that we do not have to
--    worry about grants to the WHMOVE schema except during a warehouse
--    move.
--
--    This package was created by copying pl_wh_move.sql and removing all
--    objects except for:
--       - Function get_syspar_warehouse_move_type
--       - Function is_new_warehouse_user
--
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    06/20/11 prpbcb   Remedy Problem: 3209
--                      Clearcase Activty:
--                         PBI3209-Identifying_new_warehouse user
--                
--                      Created by copy pl_wh_move.sql and removing all
--                      objects except for:
--                         - Function get_syspar_warehouse_move_type
--                         - Function is_new_warehouse_user
--                         - Function get_temp_new_wh_loc
--                      So, right now these functions exist in two
--                      packages.  At some point SWMS will get changed
--                      to use the packages in this package.
--                      I will change the functions in pl_whmove to be
--                      pass through functions that will call the functions
--                      in this package.
--                     
--
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    get_syspar_warehouse_move_type
--
-- Description:
--    This function returns the value of syspar "WAREHOUSE_MOVE_TYPE"
--    FROM THE SWMS SCHEMA.  The setting in the swms schema is the
--    driving value.  We do not check what the setting is in the
--    whmove schema.
---------------------------------------------------------------------------
FUNCTION get_syspar_warehouse_move_type
RETURN sys_config.config_flag_val%TYPE;



---------------------------------------------------------------------------
-- Function:
--    is_new_warehouse_user
--
-- Description:
--    This procedure returns TRUE if the user is a new warehouse user
--    otherwise FALSE is returned. 
---------------------------------------------------------------------------
FUNCTION is_new_warehouse_user(i_user_id  IN usr.user_id%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Function:
--    get_temp_new_wh_loc
--
-- Description:
--    This function returns the temporary new warehouse location when
--    passed the actual location in the new warehouse.
--
--    Table WHMVELOC_AREA_XREF is to determine the temporary new
--    warehouse location.
---------------------------------------------------------------------------
FUNCTION get_temp_new_wh_loc(i_actual_new_wh_loc  IN loc.logi_loc%TYPE)
RETURN VARCHAR2;



END pl_wh_move_utilities;
/


SHOW ERRORS


CREATE OR REPLACE PACKAGE BODY swms.pl_wh_move_utilities
AS
-- sccs_id=%Z% %W% %G% %I%

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_wh_move_utilities';   -- Package name.
                                              -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(10) := 'INVENTORY';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Function:
--    get_syspar_warehouse_move_type
--
-- Description:
--    This function returns the value of syspar "WAREHOUSE_MOVE_TYPE"
--    FROM THE SWMS SCHEMA.  The setting in the swms schema is the
--    driving value.  We do not check what the setting is in the
--    whmove schema.
--    
-- Parameters:
--    None
--
-- Return Values:
--    Setting for syspar WAREHOUSE_MOVE_TYPE.
--    If the syspar does not exist then null is returned.
--
-- Called by:
--      Form mw1sa.fmb
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/15/08 prpbcb   Created.
---------------------------------------------------------------------------
FUNCTION get_syspar_warehouse_move_type
RETURN sys_config.config_flag_val%TYPE
IS
   l_config_flag_val    sys_config.config_flag_val%TYPE;
   l_object_name        VARCHAR2(61);
BEGIN
   BEGIN
      SELECT s.config_flag_val
        INTO l_config_flag_val
        FROM swms.sys_config s   -- Look at the swms schema
       WHERE s.config_flag_name  = 'WAREHOUSE_MOVE_TYPE';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        --
        -- Syspar not found.  Return null.  The calling program will need
        -- to check for null.
        --
        l_config_flag_val := NULL;
   END;

   RETURN l_config_flag_val;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := gl_pkg_name || '.get_syspar_warehouse_move_type';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, 'Error',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END get_syspar_warehouse_move_type;




---------------------------------------------------------------------------
-- Function:
--    is_new_warehouse_user
--
-- Description:
--    This procedure returns TRUE if the user is a new warehouse user
--    otherwise FALSE is returned. 
--
-- Parameters:
--    i_user_id    - User to check.
--
-- Return Values:
--    TRUE  - The user is a new warehouse user.
--    FALSE - The user is not new warehouse user.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    -  Trigger trg_insupd_swms_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/10/09 prpbcb   Created
--    07/27/11 prpbcb   Changed to look at table NEW_WAREHOUSE_USR.
---------------------------------------------------------------------------
FUNCTION is_new_warehouse_user(i_user_id  IN usr.user_id%TYPE)
RETURN BOOLEAN
IS
   l_object_name   VARCHAR2(61);
   l_message       VARCHAR2(256);    -- Message buffer
   l_dummy         VARCHAR2(1);

   l_return_value  BOOLEAN;
BEGIN
   BEGIN
      --
      -- Don't worry about using an index on the table since the table will
      -- only have few records.
      --
      SELECT 'x'
        INTO l_dummy
        FROM new_warehouse_usr
       WHERE REPLACE(user_id, 'OPS', '') =  REPLACE(i_user_id, 'OPS$', '');

      -- If this point reached then the user is a new warehouse user.
      l_return_value := TRUE; 
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         -- If this point reached then the user is not a new warehouse user.
         l_return_value := FALSE;
   END;

   RETURN(l_return_value);
   
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'is_new_warehouse_user';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                 'ERROR: Failed to determine if new warehouse user.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END is_new_warehouse_user;



---------------------------------------------------------------------------
-- Function:
--    get_temp_new_wh_loc
--
-- Description:
--    This function returns the temporary new warehouse location when
--    passed the actual location in the new warehouse.
--
--    If the location is already the temporary location then the
--    location parameter is returned unchanged.
--    If the no new location s found then the
--    location parameter is returned unchanged.
--
--    Table WHMVELOC_AREA_XREF is to determine the temporary new 
--    warehouse location;
--
--    Example:
--       The record in table WHMVELOC_AREA_XREF is:
--          Column                      Value
--          -------------------------   -----
--          TMP_NEW_WH_AREA               Z
--          ORIG_OLD_WH_AREA              F
--          PUTBACK_WH_AREA               F
--          TMP_FR_OLD_TO_NEW_PASS        0
--          TMP_FR_OLD_TO_NEW_FAIL        M
--       The actual location in the new warehouse is FA11A1.
--       This function will return ZA11A1 when called with FA11A1.
--       This function will return ZA11A1 when called with ZA11A1.
--
-- Parameters:
--    i_actual_loc - The actual location in the new warehouue.
--  
-- Return Values:
--    The temporary new warehouse location.
--
-- Called By:
--    Database trigger trg_insupd_ml_mesg_whmove.
--    
-- Exceptions Raised:
--    pl_exc.e_data_error      - The area for i_actual_loc was not in
--                               WHMVELOC_AREA_XREF.
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/21/08 prpbcb   Created for the warehouse move changes moving to
--                      a new warehouse with a miniloader.
--                    
--    07/28/08 prpbcb   Created to return i_actual_new_wh_loc if unable
--                      to convert to the temp warehouse location.
--                      This means exception e_no_location will not get
--                      raised.
--
--    07/27/11 prpbcb   Copied from pl_wh_move.sql
---------------------------------------------------------------------------
FUNCTION get_temp_new_wh_loc(i_actual_new_wh_loc  IN loc.logi_loc%TYPE)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(61);

   l_count             PLS_INTEGER;       -- Work area
   l_temp_new_wh_loc   loc.logi_loc%TYPE; -- The temporary location

   e_no_location    EXCEPTION;  -- Could not determine the temporary location

   --
   -- This cursor checks if the i_actual_new_wh_loc is a temporary location.
   -- Perform a count to make the checking a little easier.
   --
   CURSOR c_check_if_temp_loc IS
      SELECT COUNT(*)
        FROM whmveloc_area_xref xref
       WHERE xref.tmp_new_wh_area = SUBSTR(i_actual_new_wh_loc, 1, 1);

   --
   -- This cursor converts the location to the temporary location.
   --
   CURSOR c_temp_loc IS
      SELECT xref.tmp_new_wh_area || SUBSTR(i_actual_new_wh_loc, 2) temp_loc
        FROM whmveloc_area_xref xref
       WHERE xref.putback_wh_area = SUBSTR(i_actual_new_wh_loc, 1, 1);
BEGIN
   --
   -- Checks if the i_actual_new_wh_loc is a temporary location.
   -- and if so return the location unchanged.
   --
   OPEN c_check_if_temp_loc;
   FETCH c_check_if_temp_loc INTO l_count;
   CLOSE c_check_if_temp_loc;

   IF (l_count > 0 ) THEN
      --
      -- i_actual_new_wh_loc is a temporary location.
      -- Return it back.
      --
      l_temp_new_wh_loc := i_actual_new_wh_loc;
   ELSE
      --
      -- i_actual_new_wh_loc is the actual location
      -- in the new warehouse.  Determine the temporary
      -- location.
      OPEN c_temp_loc;
      FETCH c_temp_loc INTO l_temp_new_wh_loc;
      IF (c_temp_loc%NOTFOUND) THEN
         --
         -- Could not determine the temporary location.
         -- Return i_actual_new_wh_loc unchanged.
         -- This will happen when the miniloader is moving
         -- a carrier from the induction location because the ML induction
         -- location will not be in SWMS.
         -- 
         l_temp_new_wh_loc := i_actual_new_wh_loc;
      END IF;

      CLOSE c_temp_loc;
   END IF;

   RETURN l_temp_new_wh_loc;
   
EXCEPTION
   WHEN e_no_location THEN
      --
      -- Could not determine the temporary location.
      -- 
      l_object_name := 'get_temp_new_wh_loc';
      l_message := l_object_name
          || '  TABLE=whmveloc_area_xref  ACTION=SELECT'
          || '  i_actual_new_wh_loc[' || i_actual_new_wh_loc || ']'
          || '  MESSAGE="Found no matching putback_wh_area for the location.'
          || '  Could be because of a missing record in the'
          || ' WHMVELOC_AREA_XREF table or i_actual_new_wh_loc is not a'
          || ' valid location in the new warehouse."';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      l_object_name := 'get_temp_new_wh_loc';
      l_message := l_object_name || ' i_actual_new_wh_loc[' 
                  || i_actual_new_wh_loc || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' ||  SQLERRM);
END get_temp_new_wh_loc;



END pl_wh_move_utilities;
/

SHOW ERRORS

