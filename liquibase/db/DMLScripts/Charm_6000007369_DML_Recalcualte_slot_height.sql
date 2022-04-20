Insert into SCRIPTS
   (SCRIPT_NAME, APPLICATION_FUNC, RESTARTABLE, RUN_COUNT,UPDATE_FUNCTION, PRINT_OPTIONS,DISPLAY_HELP, OPTION_NO)
 Values
   ('Recalculate_slot_ht.sh', 'MAINTENANCE', 'Y', 0,'Y', 
    NULL,'This script is used to recalculate the slot height', 202);

commit;
