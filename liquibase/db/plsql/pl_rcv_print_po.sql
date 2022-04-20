
SET LINESIZE 200;
SET TAB OFF;
SET TRIMSPOOl ON;

SET SERVEROUTPUT ON SIZE UNLIMITED;

CREATE OR REPLACE PACKAGE swms.pl_rcv_print_po
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_print_po
--
-- Description:
--    This package has the routines for printing the PO/SN receiving documents.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    12/16/16 bben0556 Bent Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created for Live Receiving.
--                      First use is to print the Receiving Load Worksheet.
--                      Later will add printing of the Worksheet/Labels/Lumper
--                      worksheet which also means other programs will need
--                      changing.
--
--    01/03/17 bben0556 Bent Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Increase size of l_message to 512;
--
--    01/04/17 bben0556 Bent Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Add unit test cases.
--
--    01/04/17 bben0556 Bent Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Previous change broke printing.  Fixed bug.
--
--    01/06/17 bben0556 Bent Bent
--                      Project:
--    R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--    R30.6--WIE#669--CRQ000000008118_Live_receiving_story_236_find_put_dest_loc_when_labels_printed
--
--                      Before printing the PO worksheet and/or labels that has putaway tasks
--                      with dest_loc = 'LR' find the putaway slot before
--                      printing.  This affects reports:
--                         - rp1re Purchase Order Worksheet
--                         - rp1rf Labels
--                         - rp1fl All three
--                         - rp1rg Worksheet/Labels
--
--                      Added:
--                         - TYPE type_rec_id IS TABLE OF putawaylst.rec_id%TYPE;
--                         - FUNCTION find_dest_loc_before_printing
--                         - FUNCTION get_print_query_condition
--                         - FUNCTION is_number
--                         - PROCEDURE assign_putaway_locations
--                         - PROCEDURE special_report_processing
--
--                      Form display_rpt.fmb changed to call procedure
--                      "special_report_processing".
--
--    01/11/17 bben0556 Bent Bent
--                      Check-out then check-in since we have 2 different cards.
--    R30.6--WIE#669--CRQ000000008118_Live_receiving_story_236_find_put_dest_loc_when_labels_printed
--                    
--    01/11/17 bben0556 Bent Bent
--        R30.6--WIE#669--CRQ000000008118_Live_receiving_story_316_move_unit_test_cases_to_test_package
--
--                      ***** Remove unit test cases *****  
--                      They will be put in a separate package.
--                      Make these global because of how we are
--                      doing the unit test cases though making them
--                      global not ideal.
--                         TYPE type_rec_id IS TABLE OF putawaylst.rec_id%TYPE;
--                         TYPE t_r_syspars_po_printers IS RECORD
--                         TYPE t_r_syspars_po_sched_hour IS RECORD
--                         FUNCTION is_number
--                         PROCEDURE get_syspars_po_sched_hour
--                         PROCEDURE log_syspars_po_sched_hour
--                         PROCEDURE get_syspars_po_printers
--                         PROCEDURE log_syspars_po_printers
--                         FUNCTION determine_load_area
--                         FUNCTION get_load_wksht_print_command
--                         PROCEDURE print_load_worksheet
--                         FUNCTION find_dest_loc_before_printing
--                         FUNCTION get_print_query_condition
--                         PROCEDURE assign_putaway_locations
--
--     03/14/17 sont9212 Sunil Ontipalli
--         R30.6--WIE#669--CRQ000000008118_Live_receiving_story_1228
--                       Modified find_dest_loc_before_printing, added new report rp1ro to determine the location 
--                       when printed from form.
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

--
-- For storing PO numbers to process.
--
TYPE type_rec_id IS TABLE OF putawaylst.rec_id%TYPE;

--
-- Relevant printer syspars
--
TYPE t_r_syspars_po_printers IS RECORD
(
   cooler_printer          sys_config.config_flag_val%TYPE  DEFAULT NULL,
   dry_printer             sys_config.config_flag_val%TYPE  DEFAULT NULL
);


--
-- Relevant syspars for printing documents for PO/SN opened by
-- schedule hour.
--
TYPE t_r_syspars_po_sched_hour IS RECORD
(
   open_po_hourly          sys_config.config_flag_val%TYPE,
   open_po_sched_hour      sys_config.config_flag_val%TYPE
);



--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    print_load_worksheets_by_hour (Public)
--
-- Description:
--    The procedure prints the receiving load worksheets for the PO's
--    using the schedule date and hour passed as parameters or if no
--    parameter specified then based on syspars:
--       - OPEN_PO_HOURLY
--       - OPEN_PO_SCHED_HOUR
---------------------------------------------------------------------------
PROCEDURE print_load_worksheets_by_hour
              (i_sched_date     IN DATE      DEFAULT NULL,
               i_sched_hour     IN VARCHAR2  DEFAULT NULL);


---------------------------------------------------------------------------
-- Procedure:
--    print_load_worksheets_sched_po (Public)
--
-- Description:
--    The procedure prints the receiving load worksheets for the PO's
--    for a specified schedule day.
--    
-- Parameters:
--    i_sched_date_start            - Starting schedule date
--    i_sched_date_end              - Ending schedule date
--    i_include_new_sch_status_bln  - Include NEW or SCH status PO's.
---------------------------------------------------------------------------
PROCEDURE print_load_worksheets_sched_po
              (i_sched_date_start           IN DATE,
               i_sched_date_end             IN DATE,
               i_include_new_sch_status_bln IN BOOLEAN DEFAULT TRUE);


---------------------------------------------------------------------------
-- Procedure:
--    special_report_processing
--
-- Description:
--    This procedure does any special processing required before printing
--    a receiving report.
---------------------------------------------------------------------------
PROCEDURE special_report_processing
              (i_report_name        IN print_reports.report%TYPE,
               i_print_query        IN VARCHAR2);


---------------------------------------------------------------------------
-- Function:
--    is_number
--
-- Description:
--    This function determines if a string is a number.
--    NULL is not considered a number.
---------------------------------------------------------------------------
FUNCTION is_number(i_string IN VARCHAR2)
RETURN BOOLEAN;

---------------------------------------------------------------------------
-- Procedure:
--    get_syspars_po_sched_hour (Public)
--
-- Description:
--    The procedure retrieves the syspars relevant to opening a PO
--    by the schedule hour.
---------------------------------------------------------------------------
PROCEDURE get_syspars_po_sched_hour
             (io_r_syspars_po_sched_hour  OUT NOCOPY t_r_syspars_po_sched_hour);


---------------------------------------------------------------------------
-- Procedure:
--    log_syspars_po_sched_hour
--
-- Description:
--    The procedure logs the schedule hour syspars.
---------------------------------------------------------------------------
PROCEDURE log_syspars_po_sched_hour
             (i_r_syspars_po_sched_hour  IN t_r_syspars_po_sched_hour);


---------------------------------------------------------------------------
-- Procedure:
--    get_syspars_po_printers (Public)
--
-- Description:
--    The procedure retrieves the syspars that designate what printer to
--    print the receiving documents on.
---------------------------------------------------------------------------
PROCEDURE get_syspars_po_printers
             (io_r_syspars_po_printers  OUT NOCOPY t_r_syspars_po_printers);


---------------------------------------------------------------------------
-- Procedure:
--    log_syspars_po_printers
--
-- Description:
--    The procedure logs the PO printers syspars.
---------------------------------------------------------------------------
PROCEDURE log_syspars_po_printers
             (i_r_syspars_po_printers IN t_r_syspars_po_printers);


---------------------------------------------------------------------------
-- Function:
--    determine_load_area
--
-- Description:
--    Determine the "area" of the load which determintes if the
--    receiving load worksheet is printed on the syspar defined
--    dry printer or the syspar defined cooler printer.
--
--    The area will be the area of the putaway location of the MIN
--    (putawaylst.rec_id || putawaylst.seq_no) on the load.
--
--    If the putaway location is not a valid location which it will
--    not be if it is '*' or 'LR' then function
--    is called "pl_common.f_get_first_pick_slot" which will return
--    the caes home slot of the item or if a floating item then the
--    location of the oldest LP.  The area of this location is then
--    used for the area of the load.
---------------------------------------------------------------------------
FUNCTION determine_load_area(i_load_no IN  erm.load_no%TYPE)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    get_load_wksht_print_command
--
-- Description:
--    This function builds the "swmsprtrpt" command to print the
--    receiving load worksheet rp1rn.
---------------------------------------------------------------------------
FUNCTION get_load_wksht_print_command
               (i_load_no               IN erm.load_no%TYPE,
                i_load_area             IN swms_sub_areas.area_code%TYPE,
                i_r_syspars_po_printers IN t_r_syspars_po_printers)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Procedure:
--    print_load_worksheet
--
-- Description:
--    The procedure prints the receiving load worksheet for a specified load.
--    The report name is rp1rn.sql
---------------------------------------------------------------------------
PROCEDURE print_load_worksheet
              (i_load_no               IN erm.load_no%TYPE,
               i_r_syspars_po_printers IN t_r_syspars_po_printers);


---------------------------------------------------------------------------
-- Function:
--    find_dest_loc_before_printing
--
-- Description:
--    This function determines if the PUTAWAY.DEST_LOC should be found
--    before printing a receiving document report that prints the
--    worksheet and/or labels.
---------------------------------------------------------------------------
FUNCTION find_dest_loc_before_printing
              (i_report_name IN print_reports.report%TYPE)
RETURN BOOLEAN;



---------------------------------------------------------------------------
-- Function:
--    get_print_query_condition
--
-- Description:
--    This function returns PRINT_QUERY.CONDITION
--    for a specified print query sequence.
---------------------------------------------------------------------------
FUNCTION get_print_query_condition
              (i_print_query_seq IN print_query.print_query_seq%TYPE)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Procedure:
--    assign_putaway_locations
--
-- Description:
--    The procedure assigns the destination location for putawaylst tasks
--    with PUTAWYLST.DEST_LOC = 'LR' for the PO's designated by the
--    condition in "i_print_query".
---------------------------------------------------------------------------
PROCEDURE assign_putaway_locations
              (i_print_query    IN VARCHAR2);

END pl_rcv_print_po;
/


CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_print_po
AS
---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------

gl_pkg_name   CONSTANT VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
                                              -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function CONSTANT VARCHAR2(16) := 'RECEIVING';


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
--    is_number
--
-- Description:
--    This function determines if a string is a number.
--    NULL is not considered a number.
--    
-- Parameters:
--    i_string
--
-- Return Values:
--    TRUE  - i_string is a number
--    FALSE - i_string is not a number
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
--    01/08/17 bben0556 Brian Bent
--                      Project:
--       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--
--                      Created.
---------------------------------------------------------------------------
FUNCTION is_number(i_string IN VARCHAR2)
RETURN BOOLEAN
IS
   l_number        NUMBER;   -- Work area
   l_return_value  BOOLEAN;
   l_sqlcode       VARCHAR2(20);
BEGIN
   BEGIN
      IF (i_string IS NULL) THEN
         -- NULL is not considered a number.
         l_return_value := FALSE;
      ELSE
         l_number := to_number(i_string);
         l_return_value := TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         l_sqlcode := SQLCODE;

         IF (l_sqlcode = -6502) then
            l_return_value := FALSE;
         ELSE
            RAISE;
         END IF;
   END;

   RETURN(l_return_value);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, 'is_number',
                     'is_number(i_string[' || i_string || ']  Error occurred',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE('is_number:' || SQLERRM);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              'is_number: ' || SQLERRM);
END is_number;


---------------------------------------------------------------------------
-- Procedure:
--    get_syspars_po_sched_hour (Public)
--
-- Description:
--    The procedure retrieves the syspars relevant to opening a PO
--    by the schedule hour.
--    
-- Parameters:
--    io_r_syspars_po_sched_hour - PLSQL record to store the syspars.
--
-- Called by:
--    print_load_worksheets_by_hour
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/14/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE get_syspars_po_sched_hour
             (io_r_syspars_po_sched_hour  OUT NOCOPY t_r_syspars_po_sched_hour)
IS
BEGIN
   io_r_syspars_po_sched_hour.open_po_hourly      := pl_common.f_get_syspar('OPEN_PO_HOURLY', NULL);
   io_r_syspars_po_sched_hour.open_po_sched_hour  := pl_common.f_get_syspar('OPEN_PO_SCHED_HOUR', NULL);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, 'get_syspars_po_sched_hour',
                     'get_syspars_po_sched_hour(io_r_syspars_po_sched_hour)  Error occurred',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE('get_syspars_po_sched_hour:' || SQLERRM);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              'get_syspars_po_sched_hour' || ': ' || SQLERRM);
END get_syspars_po_sched_hour;


---------------------------------------------------------------------------
-- Procedure:
--    log_syspars_po_sched_hour
--
-- Description:
--    The procedure logs the schedule hour syspars.
--    
-- Parameters:
--    i_r_syspars_po_printers
--
-- Called by:
--    print_load_worksheets_by_hour
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/07/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE log_syspars_po_sched_hour
             (i_r_syspars_po_sched_hour  IN t_r_syspars_po_sched_hour)
IS
   l_object_name  VARCHAR2(30) := 'log_syspars_po_sched_hour';
BEGIN
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Syspar Settings:'
      || '  OPEN_PO_HOURLY['     || i_r_syspars_po_sched_hour.open_po_hourly        || ']'
      || '  OPEN_PO_SCHED_HOUR[' || i_r_syspars_po_sched_hour.open_po_sched_hour    || ']',
      NULL, NULL,
      pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_object_name || '(i_r_syspars_po_sched_hour)  Error occurred',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ': ' || SQLERRM);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END log_syspars_po_sched_hour;


---------------------------------------------------------------------------
-- Procedure:
--    get_syspars_po_printers (Public)
--
-- Description:
--    The procedure retrieves the syspars that designate what printer to
--    print the receiving documents on.
--    
-- Parameters:
--    io_r_syspars_po_printers - Record to hold the printers.  One field
--                               for dry printer and on field for
--                               cooler(freezer) printer.
--
-- Called by:
--    print_load_worksheet
--    print_load_worksheets_sched_po
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/07/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE get_syspars_po_printers
             (io_r_syspars_po_printers  OUT NOCOPY t_r_syspars_po_printers)
IS
BEGIN
   io_r_syspars_po_printers.cooler_printer := pl_common.f_get_syspar('COOLER_PRINTER', NULL);
   io_r_syspars_po_printers.dry_printer    := pl_common.f_get_syspar('DRY_PRINTER', NULL);

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, 'get_syspars_po_printers',
                     'Error occurred',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE('get_syspars_po_printers: ' || SQLERRM);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              'get_syspars_po_printers' || ': ' || SQLERRM);
END get_syspars_po_printers;


---------------------------------------------------------------------------
-- Procedure:
--    log_syspars_po_printers
--
-- Description:
--    The procedure logs the PO printers syspars.
--    
-- Parameters:
--    i_r_syspars_po_printers
--
-- Called by:
--    print_load_worksheet
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/07/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE log_syspars_po_printers
             (i_r_syspars_po_printers IN t_r_syspars_po_printers)
IS
   l_object_name  VARCHAR2(30) := 'log_syspars_po_printers';
BEGIN
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Syspar Settings:'
      || '  COOLER_PRINTER['   || i_r_syspars_po_printers.cooler_printer        || ']'
      || '  DRY_PRINTER['      || i_r_syspars_po_printers.dry_printer           || ']',
      NULL, NULL,
      pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     'Error occurred',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ': ' || SQLERRM);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END log_syspars_po_printers;


---------------------------------------------------------------------------
-- Function:
--    determine_load_area
--
-- Description:
--    Determine the "area" of the load which determintes if the
--    receiving load worksheet is printed on the syspar defined
--    dry printer or the syspar defined cooler printer.
--
--    The area will be the area of the putaway location of the MIN
--    (putawaylst.rec_id || putawaylst.seq_no) on the load.
--
--    If the putaway location is not a valid location which it will
--    not be if it is '*' or 'LR' then function
--    is called "pl_common.f_get_first_pick_slot" which will return
--    the caes home slot of the item or if a floating item then the
--    location of the oldest LP.  The area of this location is then
--    used for the area of the load.
--    
-- Parameters:
--    load_no
--
-- Return Values:
--    Area
--    NULL will be returned if the area cannot be determined.
--
-- Called by:
--    print_load_worksheet
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/07/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
FUNCTION determine_load_area(i_load_no IN  erm.load_no%TYPE)
RETURN VARCHAR2
IS
   l_object_name  VARCHAR2(30) := 'determine_load_area';
   l_message      VARCHAR2(512);

   l_area  swms_sub_areas.area_code%TYPE;

   --
   -- This cursor selects the area for the load.
   --
   CURSOR c_load_area(cp_load_no  erm.load_no%TYPE)
   IS
   SELECT ssa.area_code
     FROM swms_sub_areas ssa,
          aisle_info ai,
          putawaylst put,
          erm
    WHERE erm.load_no         = cp_load_no
      AND put.rec_id          = erm.erm_id
      AND ssa.sub_area_code   = ai.sub_area_code
      --
      AND ai.name  = DECODE(put.dest_loc, '*',  SUBSTR(pl_common.f_get_first_pick_slot(put.prod_id, put.cust_pref_vendor), 1, 2),
                                          'LR', SUBSTR(pl_common.f_get_first_pick_slot(put.prod_id, put.cust_pref_vendor), 1, 2),
                                          SUBSTR(put.dest_loc, 1, 2))
      --
      AND put.rec_id || LPAD(TO_CHAR(put.seq_no) , 6, '0') IN
               (SELECT MIN(put2.rec_id || LPAD(TO_CHAR(put2.seq_no), 6, '0'))
                  FROM putawaylst put2,
                       erm erm2
                 WHERE put2.rec_id   = erm2.erm_id
                   AND erm2.load_no  = erm.load_no);
BEGIN
   --
   -- Log starting the function.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Starting function (i_load_no[' || i_load_no || '])',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   DBMS_OUTPUT.PUT_LINE('Starting ' || l_object_name
                  || '  i_load_no[' || i_load_no || ']');

   OPEN c_load_area(i_load_no);
   FETCH c_load_area INTO l_area;

   IF (c_load_area%NOTFOUND) THEN
      --
      -- Did not find the area.  Set the return value to NULL and log a message.
      -- The calling object will need to decide what to do when NULL is
      -- returned.
      --
      l_area := NULL;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'i_load_no[' || i_load_no || '])'
                  || '  Cound not determine the area for the load.'
                  || '  Setting the return value to NULL.',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
   END IF;

   CLOSE c_load_area;

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Ending function (i_load_no[' || i_load_no || '])'
                  || '  Area return value[' || l_area || ']',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   DBMS_OUTPUT.PUT_LINE('Ending ' || l_object_name
                  || '  i_load_no[' || i_load_no || ']'
                  || '  Returning[' || l_area || ']');

   RETURN(l_area);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     '(i_load_no[ ' || i_load_no || ']  Error occurred',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END determine_load_area;


---------------------------------------------------------------------------
-- Function:
--    get_load_wksht_print_command
--
-- Description:
--    This function builds the "swmsprtrpt" command to print the
--    receiving load worksheet rp1rn.
--
-- Parameters:
--    i_load_no
--    i_r_syspars_po_printers
--
-- Return Values:
--    "swmsprtrpt" command to print the receiving load worksheet (rp1rn)
--
-- Called by:
--    print_load_worksheet
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/04/17 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
FUNCTION get_load_wksht_print_command
               (i_load_no               IN erm.load_no%TYPE,
                i_load_area             IN swms_sub_areas.area_code%TYPE,
                i_r_syspars_po_printers IN t_r_syspars_po_printers)
RETURN VARCHAR2
IS
   l_printer           VARCHAR2(30);  -- What printer
   l_print_command     VARCHAR2(200);
   l_query_seq         NUMBER;
BEGIN
   IF (i_load_area IN ('C', 'F')) THEN
      l_printer := i_r_syspars_po_printers.cooler_printer;
   ELSE 
      l_printer := i_r_syspars_po_printers.dry_printer;
   END IF;

   BEGIN
      SELECT print_query_seq.nextval INTO l_query_seq FROM DUAL;

      INSERT INTO print_query(print_query_seq, condition) 
         values(l_query_seq, 'load_no = ''' || i_load_no || '''');
      COMMIT;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'get_load_wksht_print_command',
                     '(i_load_no[ ' || i_load_no || ']; Unable to select print query sequence',
                     SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);
         RAISE;
      WHEN DUP_VAL_ON_INDEX THEN
         update print_query
            set condition = 'load_no = ''' || i_load_no || ''''
         where print_query_seq = l_query_seq;
         COMMIT;
      WHEN OTHERS THEN
         RAISE;
      END;

   l_print_command :=
      'swmsprtrpt -c ' || l_query_seq || ' -P ' || l_printer || ' -w rp1rn';

   RETURN(l_print_command);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'get_load_wksht_print_command',
                     '(i_load_no[ ' || i_load_no || ']  Error occurred',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            'get_load_wksht_print_command' || ': ' || SQLERRM);
END get_load_wksht_print_command;


---------------------------------------------------------------------------
-- Procedure:
--    print_load_worksheet
--
-- Description:
--    The procedure prints the receiving load worksheet for a specified load.
--    The report name is rp1rn.sql
--    
-- Parameters:
--    i_load_no               - The load to print.
--    i_r_syspars_po_printers - The printer to print to.
--
-- Called by:
--    print_load_worksheets_sched_po
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/07/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE print_load_worksheet
              (i_load_no               IN erm.load_no%TYPE,
               i_r_syspars_po_printers IN t_r_syspars_po_printers)
IS
   l_message      VARCHAR2(512);
   l_object_name  VARCHAR2(30) := 'print_load_worksheet';

   l_dest_printer           VARCHAR2(30);
   l_host_cmd               VARCHAR2(256);
   l_load_area              swms_sub_areas.area_code%TYPE;
   l_rc                     VARCHAR2(500);
   l_r_syspars_po_printers  t_r_syspars_po_printers;
BEGIN
   --
   -- Log starting the procedure.
   --
   l_message := 'Starting procedure '
         || '(i_load_no[' || i_load_no || '],'
         || 'i_r_syspars_po_printers.cooler_printer[' || i_r_syspars_po_printers.cooler_printer || '],'
         || 'i_r_syspars_po_printers.dry_printer['    || i_r_syspars_po_printers.dry_printer    || '])';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   --
   -- Initialization
   --
   l_r_syspars_po_printers := i_r_syspars_po_printers;

   --
   -- If the printer syspars are null then retrieve them.
   -- This procedure can be called from different places which
   -- may or may not pass the printer syspars as a parameter.
   --
   IF (    l_r_syspars_po_printers.cooler_printer IS NULL
       AND l_r_syspars_po_printers.dry_printer    IS NULL)
   THEN
      get_syspars_po_printers(l_r_syspars_po_printers);
      log_syspars_po_printers(l_r_syspars_po_printers);
   END IF;

   --
   -- Printer to use depends on the area the load is for.
   --
   l_load_area := determine_load_area(i_load_no);

   --
   -- Build the print command.
   --
   l_host_cmd := get_load_wksht_print_command
                              (i_load_no               => i_load_no,
                               i_load_area             => l_load_area,
                               i_r_syspars_po_printers => l_r_syspars_po_printers);

   l_message :=    'i_load_no[' || i_load_no || ']'
                 || '  l_host_cmd[' || l_host_cmd || ']'
                 || '  Before host command call to print load worksheet';

   DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' || l_message);

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   l_rc := DBMS_HOST_COMMAND_FUNC(LOWER(REPLACE(USER, 'OPS$', NULL)), l_host_cmd);

   l_message :=     'i_load_no[' || i_load_no || ']'
                 || '  l_host_cmd[' || l_host_cmd || ']'
                 || '  After host command call to print load worksheet';

   DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' || l_message);

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Ending procedure',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     '(i_load_no[ ' || i_load_no || '],'
                     || 'i_r_syspars_po_printers.cooler_printer[' || i_r_syspars_po_printers.cooler_printer || '],'
                     || 'i_r_syspars_po_printers.dry_printer['    || i_r_syspars_po_printers.dry_printer    || '])'
                     || '  Error occurred',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END print_load_worksheet;


---------------------------------------------------------------------------
-- Procedure:
--    print_load_worksheets_sched_po
--
-- Description:
--    The procedure prints the receiving load worksheets for the PO's
--    for a specified schedule day.
--    
-- Parameters:
--    i_sched_date_start            - Starting schedule date
--    i_sched_date_end              - Ending schedule date
--    i_include_new_sch_status_bln  - Include NEW or SCH status PO's.
--                                    The default is TRUE.
--
-- Called by:
--    print_load_worksheets_by_hour
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/08/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE print_load_worksheets_sched_po
              (i_sched_date_start           IN DATE,
               i_sched_date_end             IN DATE,
               i_include_new_sch_status_bln IN BOOLEAN DEFAULT TRUE)
IS
   l_message            VARCHAR2(512);
   l_object_name        VARCHAR2(30) := 'print_load_worksheets_sched_po';

   l_include_new_sch_status_flag  VARCHAR2(1);          -- Populated using i_include_new_sch_status_bln
   l_r_syspars_po_printers        t_r_syspars_po_printers;
  
   --
   -- This cursor selects the loads to print for the sched date.
   -- 12/8/16 Brian Bent--Not sure about the sorting as this time.
   --
   CURSOR c_load(cp_sched_date_start             DATE,
                 cp_sched_date_end               DATE,
                 cp_include_new_sch_status_flag  VARCHAR2)
   IS
   SELECT DISTINCT e.load_no
     FROM erm e
    WHERE e.sched_date BETWEEN cp_sched_date_start
                           AND cp_sched_date_end
      AND e.warehouse_id    = '000'
      --
      AND (   e.status                       NOT IN ('NEW', 'SCH')
           OR cp_include_new_sch_status_flag = 'Y')
      --
    ORDER BY e.load_no;
BEGIN
   --
   -- Always log an info message.
   --
   l_message := 'Starting procedure'
         || ' (i_sched_date_start[' || TO_CHAR(i_sched_date_start, 'DD-MON-YYYY HH24:MI:SS') || ']'
         || ',i_sched_date_end['    || TO_CHAR(i_sched_date_end,   'DD-MON-YYYY HH24:MI:SS') || ']'
         || ',i_include_new_sch_status_bln[' || pl_common.f_boolean_text(i_include_new_sch_status_bln) || '])'
         || '  The receiving load worksheet will be printed for each load for POs regardless of status with a'
         || ' schedule date between i_sched_date_start and i_sched_date_end.'
         || '  Parameter "i_include_new_sch_status_bln" can be set to FALSE which will then exclude NEW/SCH POs'
         || ' when selecting the loads to print';

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   DBMS_OUTPUT.PUT_LINE(l_object_name || ':' || l_message);

   --
   -- Since we cannot use boolean parameter "i_include_new_sch_status_bln" in a select stmt
   -- set a local varchar variable.
   --
   IF (i_include_new_sch_status_bln = TRUE) THEN
      l_include_new_sch_status_flag := 'Y';
   ELSE
      l_include_new_sch_status_flag := 'N';
   END IF;

   --
   -- Get the printers.
   --
   get_syspars_po_printers(l_r_syspars_po_printers);
   log_syspars_po_printers(l_r_syspars_po_printers);

   FOR r_load IN c_load(i_sched_date_start, i_sched_date_end, l_include_new_sch_status_flag)
   LOOP
      print_load_worksheet
             (i_load_no               => r_load.load_no,
              i_r_syspars_po_printers => l_r_syspars_po_printers);
   END LOOP;

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Ending procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     '   (i_sched_date_start[' || TO_CHAR(i_sched_date_start, 'DD-MON-YYYY HH24:MI:SS') || ']'
                     || ',i_sched_date_end['   || TO_CHAR(i_sched_date_end,   'DD-MON-YYYY HH24:MI:SS') || '])'
                     || '  Error occurred',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END print_load_worksheets_sched_po;


---------------------------------------------------------------------------
-- Procedure:
--    print_load_worksheets_by_hour
--
-- Description:
--    The procedure prints the receiving load worksheets for the PO's
--    using the schedule date and hour passed as parameters or if no
--    parameter specified then based on syspars:
--       - OPEN_PO_HOURLY
--       - OPEN_PO_SCHED_HOUR
--    
-- Parameters:
--    i_sched_date 
--    i_sched_hour
--
-- Called by:
--    TP_wk_sheet.pc
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/08/16 bben0556 Brian Bent
--                      Project:
--     R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE print_load_worksheets_by_hour
              (i_sched_date     IN DATE      DEFAULT NULL,
               i_sched_hour     IN VARCHAR2  DEFAULT NULL)
IS
   l_message                  VARCHAR2(512);
   l_object_name              VARCHAR2(30) := 'print_load_worksheets_by_hour';

   l_sched_date_start         DATE;
   l_sched_date_end           DATE;
   l_r_syspars_po_sched_hour  t_r_syspars_po_sched_hour;

BEGIN
   --
   -- Always log an info message.
   --
   l_message := 'Starting procedure'
         || ' (i_sched_date[' || TO_CHAR(i_sched_date, 'DD-MON-YYYY HHAM:MI:SS') || ']'
         || ',i_sched_hour[' || i_sched_hour || '])'
         || '  Print receiving load worksheets by date and hour.'
         || '  If the schedule date and hour not passed as parameters or one is NULL'
         || ' then use syspars OPEN_PO_HOURLY and OPEN_PO_SCHED_HOUR to determine the schedule hour.'
         || '  The schedule date will be the current date.';


   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   DBMS_OUTPUT.PUT_LINE(l_message);

   --
   -- If one of the parameters passed is null then use the syspar values for the scheduled hour.
   --
   IF (   i_sched_date IS NULL 
       OR i_sched_hour IS NULL)
   THEN
      --
      -- No parameters passed or at least one is NULL. 
      -- Use the syspars to determine the schedule hour.
      -- The schedule date will be the current date.
      --
      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                     'Schedule date or hour not passed as parameters or one is NULL.'
                     || '  Use the syspars to determine the schedule hour.'
                     || '  The schedule date will be the current date.',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      get_syspars_po_sched_hour(l_r_syspars_po_sched_hour);
      log_syspars_po_sched_hour(l_r_syspars_po_sched_hour);

      l_sched_date_start := TRUNC(SYSDATE);

      IF (l_r_syspars_po_sched_hour.open_po_hourly = 'Y')
      THEN
         l_sched_date_end := TO_DATE(TO_CHAR(l_sched_date_start, 'MM/DD/YYYY') || ' ' || l_r_syspars_po_sched_hour.open_po_sched_hour, 'MM/DD/YYYY HHAM');
      ELSE
         l_sched_date_end := TO_DATE(TO_CHAR(l_sched_date_start, 'MM/DD/YYYY') || ' 23:59:59', 'MM/DD/YYYY HH24:MI:SS');
      END IF;
   ELSE
      --
      -- Use the parameters.
      --
      l_sched_date_start := TRUNC(i_sched_date);
      l_sched_date_end   := TO_DATE(TO_CHAR(i_sched_date, 'MM/DD/YYYY') || ' ' || i_sched_hour, 'MM/DD/YYYY HHAM');
   END IF;


   DBMS_OUTPUT.PUT_LINE(l_object_name 
         || '  l_sched_date_start[' || TO_CHAR(l_sched_date_start, 'DD-MON-YYYY HH24:MI:SS') || ']'
         || '  l_sched_date_end '   || TO_CHAR(l_sched_date_end,   'DD-MON-YYYY HH24:MI:SS') || ']');


   print_load_worksheets_sched_po
              (i_sched_date_start => l_sched_date_start,
               i_sched_date_end   => l_sched_date_end);

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Ending procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      l_message := l_object_name
         || '(i_sched_date[' || TO_CHAR(i_sched_date, 'DD-MON-YYYY HHAM:MI:SS') || ']'
         || ',i_sched_hour[' || i_sched_hour || '])';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END print_load_worksheets_by_hour;


---------------------------------------------------------------------------
-- Function:
--    find_dest_loc_before_printing
--
-- Description:
--    This function determines if the PUTAWAY.DEST_LOC should be found
--    before printing a receiving document report that prints the
--    worksheet and/or labels.
--   
--    
-- Parameters:
--    i_report_name
--
-- Return Values:
--    TRUE  - Find the putaway destination location for putawaylst tasks
--            with PUTAWAY.DEST_LOC = 'LR'.
--    FALSE - Do not find the destination location.
--
-- Called by:
--    special_report_processing
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/08/17 bben0556 Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--
--                      Created.
--
--                      Before printing the PO worksheet and/or labels find
--                      the putaway slot before print for any putaway tasks
--                      with dest_loc = 'LR'.
---------------------------------------------------------------------------
FUNCTION find_dest_loc_before_printing
              (i_report_name IN print_reports.report%TYPE)
RETURN BOOLEAN
IS
BEGIN
   --
   --  - rp1re Purchase Order Worksheet
   --  - rp1rf Labels
   --  - rp1fl All three
   --  - rp1rg Worksheet/Labels
   --  - rp1ro Worksheet/Pallet Worksheet
   --
   IF (i_report_name IN ('rp1re', 'rp1rf', 'rp1fl', 'rp1rg', 'rp1ro')) THEN
      RETURN(TRUE);
   ELSE
      RETURN(FALSE);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'find_dest_loc_before_printing',
                     'i_report_name [' || i_report_name || ']  Error',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            'find_dest_loc_before_printing: ' || SQLERRM);
END find_dest_loc_before_printing;


---------------------------------------------------------------------------
-- Function:
--    get_print_query_condition
--
-- Description:
--    This function returns PRINT_QUERY.CONDITION
--    for a specified print query sequence.
--    
-- Parameters:
--    i_print_query_seq
--
-- Return Values:
--    PRINT_QUERY.CONDITION
--
-- Called by:
--    assign_putaway_locations
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/08/17 bben0556 Brian Bent
--                      Project:
--       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--
--                      Created.
---------------------------------------------------------------------------
FUNCTION get_print_query_condition
              (i_print_query_seq IN print_query.print_query_seq%TYPE)
RETURN VARCHAR2
IS
   l_print_query_condition  VARCHAR2(2000);
BEGIN
   BEGIN
      SELECT pq.condition 
        INTO l_print_query_condition
        FROM print_query pq
       WHERE pq.print_query_seq = i_print_query_seq;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_print_query_condition := NULL;
   END;

   --
   -- Debug stuff
   --
   DBMS_OUTPUT.PUT_LINE('get_print_query_condition: l_print_query_condition['
                         || l_print_query_condition || ']');

   RETURN(l_print_query_condition);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'get_print_query_condition',
                     'Error',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            'get_print_query_condition: ' || SQLERRM);
END get_print_query_condition;


---------------------------------------------------------------------------
-- Procedure:
--    assign_putaway_locations
--
-- Description:
--    The procedure assigns the destination location for putawaylst tasks
--    with PUTAWYLST.DEST_LOC = 'LR' for the PO's designated by the
--    condition in "i_print_query".
--
-- Parameters:
--    i_print_query   - Either the print query sequence or the actual condition.
--                      If it is the print query sequence then the corresponding
--                      condtion is select from table PRINT_QUERY.  It will be 
--                      considered the print query sequence if it is a number.
--
-- Called by:
--    special_report_processing
--
-- Exceptions raised:
--    pl_exc.ct_database_error - oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/06/17 bben0556 Brian Bent
--                      Project:
--       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--
--                      Created.
--
--                      Before printing the PO worksheet and/or labels that
--                      has putaway tasks with dest_loc = 'LR' find the putaway
--                      slot before printing.
---------------------------------------------------------------------------
PROCEDURE assign_putaway_locations
              (i_print_query    IN VARCHAR2)
IS
   l_message      VARCHAR2(2000);
   l_object_name  VARCHAR2(30) := 'assign_putaway_locations';

   coll_rec_id              type_rec_id;  -- To hold the PO's to process

   l_print_query_condition  VARCHAR2(2000);
   l_sql_stmt               VARCHAR2(2000);
   l_status                 PLS_INTEGER;

   --
   -- Counts when creating forklift labor putaway batches.
   --
   l_no_records_processed      NUMBER;
   l_no_batches_created        NUMBER;
   l_no_batches_existing       NUMBER;
   l_no_batches_not_created    NUMBER;
BEGIN
   --
   -- Log starting the procedure.
   --
   l_message := 'Starting procedure ';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   --
   -- Validate the parameters.
   -- i_print_query is required.
   --
   IF (i_print_query IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   IF (is_number(i_print_query) = TRUE) THEN
      l_print_query_condition := get_print_query_condition(i_print_query);
   ELSE
      l_print_query_condition := i_print_query;
   END IF;

   --
   -- Build the statement that selects the PO's to process.
   -- Only select the PO's that have at least one putaway task with
   -- dest_loc = 'LR'.
   --
   l_sql_stmt :=     'SELECT DISTINCT rec_id FROM putawaylst'
                  || ' WHERE rec_id IN'
                  || ' (SELECT erm_id FROM erm WHERE ' || l_print_query_condition || ')'
                  || ' AND EXISTS (SELECT 0 FROM putawaylst put2 WHERE put2.rec_id = putawaylst.rec_id AND put2.dest_loc = ''LR'')'
                  || ' ORDER BY rec_id';

   DBMS_OUTPUT.PUT_LINE('[' || l_sql_stmt || ']');  -- Debug stuff

   --
   -- Select the PO's to process.
   --
   EXECUTE IMMEDIATE l_sql_stmt BULK COLLECT INTO coll_rec_id;

   DBMS_OUTPUT.PUT_LINE('coll_rec_id.count[' || coll_rec_id.count || ']');  -- Debug stuff

   --
   -- Process the PO's.
   --
   FOR i IN 1..coll_rec_id.count LOOP
      DBMS_OUTPUT.PUT_LINE(coll_rec_id(i));  -- Debug stuff

      pl_rcv_open_po_lr.find_putaway_location
           (i_erm_id                 => coll_rec_id(i),
            o_status                 => l_status);

      --
      -- Create the forklift labor mgmt batches.
      --
      pl_lmf.create_putaway_batches_for_po
             (coll_rec_id(i),
              l_no_records_processed,
              l_no_batches_created,
              l_no_batches_existing,
              l_no_batches_not_created);

      --
      -- Debug stuff
      --
      DBMS_OUTPUT.PUT_LINE(
                  'po no[' || coll_rec_id(i) || ']'
             || '  l_no_records_processed['   || to_char(l_no_records_processed)   || ']'
             || '  l_no_batches_created['     || to_char(l_no_batches_created)     || ']'
             || '  l_no_batches_existing['    || to_char(l_no_batches_existing)    || ']'
             || '  l_no_batches_not_created[' || to_char(l_no_batches_not_created) || ']');


   END LOOP;
      
   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Ending procedure',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
EXCEPTION
   WHEN gl_e_parameter_null THEN
      --
      -- Required parameter null.
      --
      l_message := l_object_name
         || '(i_print_query['  || i_print_query  || '],'
         || ' i_print_query is required)';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                              l_object_name || ': ' || SQLERRM);

   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     '  Error occurred',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END assign_putaway_locations;


---------------------------------------------------------------------------
-- Procedure:
--    special_report_processing
--
-- Description:
--    This procedure does any special processing required before printing
--    a receiving report.
--    
-- Parameters:
--    i_report_name     - Report to print
--    i_print_query     - Either the print query sequence or the actual condition.
--                        If it is the print query sequence then the corresponding
--                        condtion is select from table PRINT_QUERY.  It will be 
--                        considered the print query sequence if it is a number.
--
-- Called by:
--    Form display_rpt.fmb
--
-- Exceptions raised:
--    pl_exc.ct_database_error - oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/06/17 bben0556 Brian Bent
--                      Project:
--       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--
--                      Created.
--
--                      Before printing the PO worksheet and/or labels for
--                      the putaway tasks with dest_loc = 'LR' find the putaway
--                      slot before printing.
---------------------------------------------------------------------------
PROCEDURE special_report_processing
              (i_report_name        IN print_reports.report%TYPE,
               i_print_query        IN VARCHAR2)
IS
   l_message      VARCHAR2(2000);
   l_object_name  VARCHAR2(30) := 'special_report_processing';
BEGIN
   --
   -- Log starting the procedure.
   --
   l_message := 'Starting procedure'
         || ' (i_report_name[' || i_report_name || ']'
         || ',i_print_query(first 600 chars)[' || SUBSTR(i_print_query, 1, 600) || '])'
         || '  sys_context(module)[' || SYS_CONTEXT('USERENV', 'MODULE') || ']'
         || '  This procedure does any special processing required before printing'
         || ' a receiving report.';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);


   --
   -- 01/11/2017  Live Receiving
   -- Special processing required for reports that print the receiving worksheet
   -- and/or the receiving labels.  If there are any putawaylst records with
   -- dest_loc = 'LR' then find the putaway slot before printing.
   -- 
   IF (find_dest_loc_before_printing(i_report_name) = TRUE) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Special processing required for this report.'
                  ||'  If there are any putawaylst records with'
                  || ' dest_loc = ''LR'' then find the putaway slot before printing.',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

      assign_putaway_locations(i_print_query => i_print_query);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     '  Error occurred',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END special_report_processing;

END pl_rcv_print_po;
/


CREATE OR REPLACE PUBLIC SYNONYM pl_rcv_print_po FOR swms.pl_rcv_print_po
/

GRANT EXECUTE ON pl_rcv_print_po TO swms_user
/


