/****************************************************************************
** Date:       28-Jun-2016
** File:       6000012905_dml_insert_message_table.sql
**
** Insert new system parameter for DOD project.
**
** Records are inserted into tables:
**    - MESSAGE_TABLE
**
** Modification History:
**    Date     Developer Comments
**    -------- --------  ---------------------------------------------------
**    06/28/16 KRAJ6630  Initial version created. Charm 6000012905
**                       Insert 119975 and Message  For Charm 6000012905
****************************************************************************/
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119975, 'Cannot close route. Catchweights entered for warehouse out items. Delete catchweights for the items.', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119975, 'Impossible de fermer la Itiniraire.Poids variables entrees pour lentrepot des articles.Supprimer poids variables pour ces articles.', 12);
COMMIT;

-- Messages for validate SSl
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119976, 'The PIK Zones listed below are not included in this SSL. This may cause Order Generation to fail. Please add these to the SSL.', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119976, 'Les zones PIK énumérées ci-dessous ne sont pas inclus dans cette SSL . Cela peut provoquer la génération ordonner à l''échec. S''il vous plaît ajouter à la SSL .', 12);
COMMIT;
/
