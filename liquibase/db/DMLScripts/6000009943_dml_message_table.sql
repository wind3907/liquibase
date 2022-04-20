/****************************************************************************
** Date:       12-Apr-2016
** File:       DOD_DML_for_message_table.sql
**
**             Script to 
**             1. Add new message into message_table
**
**    - SCRIPTS
**
**    Modification History:
**    Date      	Designer	Comments
**    -----------  	--------	------------------------------------------ **    
**    12-Apr-2016	spot3255 	Charm#6000010228: DOD Labels
**
****************************************************************************/

Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119964, '%s1 DOD Labels will print, Do you want to proceed? ', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119964, '%s1 DOD Labels imprimera , voulez-vous procéder? ', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119965, 'Invalid sequence entered, Range should be from %s1 to %s2', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119965, 'séquence non valide est entré , Range doit être de %s1 à %s2', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119966, 'To Seq should be greater than From Seq', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119966, 'To Seq should be greater than From Seq', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119967, 'Reprint option is not available for multiple route selection', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119967, 'l''option Réimpression ne sont pas disponibles pour la sélection d''itinéraires multiples
', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119968, 'No route selected for reprint', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119968, 'Aucun itinéraire sélectionné pour la réimpression', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119969, 'labels already printed. Please use reprint menu to print again', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119969, 'les étiquettes déjà imprimées. S''il vous plaît utilisez le menu réimpression pour imprimer', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119970, 'Please remove the already printed routes', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119970, 'S''il vous plaît enlever les routes déjà imprimées', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119971, 'Printing the lables to printer: %s1', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119971, 'Impression des lables à l''imprimante: % s1', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119972, 'No labels to print', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119972, 'Aucune étiquette à imprimer', 12);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119973, 'No route selected for print', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119973, 'Aucun itinéraire sélectionné pour l''impression', 12);
COMMIT;
