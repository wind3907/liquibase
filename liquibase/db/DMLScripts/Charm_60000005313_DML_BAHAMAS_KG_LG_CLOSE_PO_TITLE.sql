--Changes for R_30_1 for printing the Catchweight Exception Receiving report automatically once a PO is closed--

--Insertions in the global report dictionary to capture the title in lpstat --

  Insert into SWMS.GLOBAL_REPORT_DICT
   (LANG_ID, REPORT_NAME, FLD_LBL_NAME, FLD_LBL_DESC, MAX_LEN,ADD_USER, ADD_DATE, UPDATE_USER, UPDATE_DATE, FLD_LBL_NO)
 Values
   (3, 'rp4rb', 'TITLE', 'Catch Weight Exception Receiving Report', 50,NULL, NULL, NULL, NULL, NULL);

Insert into SWMS.GLOBAL_REPORT_DICT
   (LANG_ID, REPORT_NAME, FLD_LBL_NAME, FLD_LBL_DESC, MAX_LEN,ADD_USER, ADD_DATE, UPDATE_USER, UPDATE_DATE, FLD_LBL_NO)
 Values
   (12, 'rp4rb', 'TITLE', 'Rapport de Réception d''exception Poids Variable', 50,NULL, NULL, NULL, NULL, NULL);

COMMIT; 



