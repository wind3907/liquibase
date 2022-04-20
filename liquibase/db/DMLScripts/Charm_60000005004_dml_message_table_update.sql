
/**************************************************************************
**    Update message_table for 13103 FOR charm No: 6000005004
***************************************************************************/
UPDATE message_table SET v_message='Please ensure route is cancelled in host system ( SUS / IDS / SAP /NAV) ' 
WHERE ID_MESSAGE='13103' and ID_LANGUAGE='3';

UPDATE message_table SET v_message='Sil vous plait informer route  est annulé  dans la hôte système (SUS / IDS / SAP /NAV) ' 
WHERE ID_MESSAGE='13103' and ID_LANGUAGE='12';

COMMIT;

