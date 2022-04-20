/**************************************************************************
**    Update message_table for 13106 FOR charm No: 6000008962
***************************************************************************/

UPDATE message_table set V_MESSAGE = 'Selection batches will be MISSING . SAE directory set up missing for %s1 . Do you want to stop route generation?'
where ID_MESSAGE = '13106' and ID_LANGUAGE = 3;

UPDATE message_table set V_MESSAGE = 'Quelques lots de selection seront disparaissent comme file dimpression dans SSL est pas configure pour repertoire SAE (%s1). Voulez-vous arreter et configurer SSL?'
where ID_MESSAGE = '13106' and ID_LANGUAGE = 12;

COMMIT;
