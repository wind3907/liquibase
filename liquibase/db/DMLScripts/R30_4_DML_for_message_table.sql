/****************************************************************************
** Date:       30-Oct-2015
** File:       R30_4_DML_for_message_table.sql
**
**             Script to 
**             1. Add new message into message_table
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    30-Oct-2015 Chua6448 
**    Charm#6000005004: Route backoutTruck change
**    Charm#6000008962: Missing Labels&Batches
**
**    17-Nov-2015 Chua6448 
**    Charm#6000003010: Modify the Swap logic
**
****************************************************************************/

Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13101,'Are you sure that you want to Backout Route %s1?',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13101,'Etes-vous sur que vous voulez sauvegarder sur la route %s1?',12);

Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13102,'Route Backout cancelled',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13102,'Route de retour sur annulee',12);

Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13103,'Route Backout complete. Please inform SUS/IDS/SAP for their system back out route %s1',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13103,'Route de retour sur complete.Sil vous plait informer SUS/IDS/SAP pour leur systeme reculer route %s1',12);

Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13104,'Error during Route Backout. %s1',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13104,'Erreur lors de la route du retour sur. %s1',12);

Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13105,'Sel JC cannot be blank',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13105,'Sel Sel JC ne peut pas etre vide',12);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13106,'Few selection batches will go missing as print queue in SSL is not configured for SAE directory (%s1). Do you want to stop and configure SSL?  ',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13106,'Quelques lots de selection seront disparaissent comme file dimpression dans SSL est pas configure pour repertoire SAE (%s1). Voulez-vous arreter et configurer SSL?',12);

--Charm 6000003010_Modify the Swap Logic
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13107,'Error. Pending Hold inventory: %s1 in %s2',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13107,'Erreur. En attendant l''inventaire Hold: %s1 dans %s2',12);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13108,'Error. Pending NDM RPL with no pre/new status: %s1 in %s2',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13108,'Erreur. En attendant NDM RPL sans pre/nouveau statut: %s1 dans %s2',12);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13109,'Error. %s1 has other allocation except for NDM RPL',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13109,'Erreur. %s1 a une autre affectation a l''exception des NDM RPL',12);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13110,'Unable to remove NDM RPL for inv %s1',3);
Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE,V_MESSAGE,ID_LANGUAGE) values (13110,'Impossible de supprimer NDM RPL pour inv %s1',12);


COMMIT;