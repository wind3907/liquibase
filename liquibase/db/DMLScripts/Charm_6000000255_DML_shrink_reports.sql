Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, PRINT_OPTIONS, OPTION_NO)
 Values
   ('sos_short.sh', 'Order Processing', 'Y', 0, 
    '-z1 -p12', 151);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('sos_scan_analysis.sh', 'Order Processing', 'Y', 0, 
    'N', '-z1 -p12', 152);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('rem_shlf_lf_rpt.sh', 'Inventory', 'Y', 0, 
    'N', '-z1 -p12', 147);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, PRINT_OPTIONS, OPTION_NO)
 Values
   ('mispicks_shorts.sh', 'Order Processing', 'Y', 0, 
    '-z1 -p12', 154);


Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, PRINT_OPTIONS, OPTION_NO)
 Values
   ('expiration_warning_report.sh', 'INVENTORY', 'Y', 0, 
    ' -z1 -p12', 155);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('dmnd_status_rpt.sh', 'Inventory', 'Y', 0, 
    'N', '-z1 -p12', 153);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('show_old_po_rpt.sh', 'Order Processing', 'Y', 0, 
    'N', '-z1 -p12', 156);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('trk_damage_rpt.sh', 'Order Processing', 'Y', 0, 
    'N', '-z1 -p12', 157);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('pik_resrv_slot_rpt.sh', 'Inventory', 'Y', 0, 
    'N', '-z1 -p12', 158);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('Fifo_trk_rpt.sh', 'MAINTENANCE', 'Y', 0, 
    'N', '-z1 -p12', 159);

Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT, UPDATE_FUNCTION, PRINT_OPTIONS, OPTION_NO)
 Values
   ('item_on_hld_rpt.sh', 'Inventory', 'Y', 0, 
    'N', '-z1 -p12', 160);
commit;