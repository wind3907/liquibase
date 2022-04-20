/********************************************************************
07/27/16 - pkab6563 - add new columns sym05_add_date and 
                      sym05_sequence_number to sos_batch and
                      sos_batch_hist.
*********************************************************************/

ALTER TABLE SOS_BATCH ADD (SYM05_ADD_DATE DATE, SYM05_SEQUENCE_NUMBER NUMBER(10));
ALTER TABLE SOS_BATCH_HIST ADD (SYM05_ADD_DATE DATE, SYM05_SEQUENCE_NUMBER NUMBER(10));
