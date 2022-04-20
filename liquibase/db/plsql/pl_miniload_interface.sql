CREATE OR REPLACE PACKAGE swms.pl_miniload_interface
AS
-- sccs_id=@(#) src/schema/plsql/pl_miniload_interface.sql, swms, swms.9, 10.1.1 11/3/08 1.3
-----------------------------------------------------------------------------
-- Package Name:
--   pl_miniload_interface
--
-- Description:
--    This package will perform the functions necessary to interface
--    with the miniloader HDO and HOI tables.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    03/02/07 prpbcb   DN: 12214
--                      Ticket: 326211
--                      Project: 326211-Miniload Induction Qty Incorrect
--
--                      Created this package.
--                      Moved procedures p_check_hdo and p_insert_hoi
--                      in pl_miniload_processing to this package.
--                      Changed the appropriate packaged procedures, shell
--                      scripts, etc to reflect this.
--			
--    12/12/07 ctvgg000 Made changes 					
--			
--    03/02/07 prpbcb   DN: 12434
--                      Project:
--                        CRQ000000001006-Embed meaningful messages in miniload
--
--                      New indexes were created on the MINILOAD_MESSAGE and
--                      MINILOAD_ORDER status and source system columns.
--                      Changed cursor c_msgs_to_miniload to use hints to
--                      use the indexes so we stop doing full table scans.
--                      I could not get the cursor to use the indexes without
--                      the hints.
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------

   --------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------
   ct_program_code   CONSTANT VARCHAR2 (50) := 'MLIT';

--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------

   --------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------

   --------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------
   PROCEDURE p_check_hdo;

   PROCEDURE p_insert_hoi;
END pl_miniload_interface;
/


SHOW ERRORS

CREATE OR REPLACE PACKAGE BODY swms.pl_miniload_interface
AS
---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2 (30) := 'pl_miniload_interface';   -- Package name.

   --  Used in error messages.

   --------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

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

   -------------------------------------------------------------------------
-- Procedure:
--    p_check_hdo
--
-- Description:
--     The procedure processes messages in HDO table and moves the
--     new messages to miniload message/miniload_order tables
--
-- Parameters:
--
-- Exceptions Raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/08/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_check_hdo
   IS
      l_miniload_info   pl_miniload_processing.t_miniload_info := NULL;
      lv_msg_type       VARCHAR2 (50)                          := NULL;
      ln_status         NUMBER (1)       := pl_miniload_processing.ct_success;
      --Hold return status of functions
      lv_msg_text       VARCHAR2 (1500);
      lv_fname          VARCHAR2 (50)                        := 'P_CHECK_HDO';
      lb_log_flag       BOOLEAN;

      CURSOR c_hdo_rec IS
         SELECT   hdo_id, LENGTH, DATA, ml_system
             FROM HDO
         ORDER BY hdo_id;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_interface.p_check_hdo');
      lb_log_flag := FALSE;
      DBMS_OUTPUT.PUT_LINE ('Start read');
	  
      --
      -- Retrieve the data from the HDO table into the cursor c_hdo_rec.
      --
      FOR c1 IN c_hdo_rec
      LOOP
            
         lv_msg_type :=
            RTRIM (SUBSTR (c1.DATA, 1,
                           pl_miniload_processing.ct_msg_type_size));
         DBMS_OUTPUT.PUT_LINE (   ' Fetched record: '
                               || lv_msg_type
                               || '-'
                               || c1.DATA);		
			
		                              
         l_miniload_info :=                          
            pl_miniload_processing.f_parse_message (c1.DATA,
                                                    lv_msg_type,
                                                    lb_log_flag);

         /* copy the miniload identifier to miniload message and miniload order 
          -- CTVGG000 for HK Integration*/
         l_miniload_info.v_ml_system := c1.ml_system;                  
         
         -- Write into miniload_order for order related messages and for other
         -- message write into miniload_message. The source system will 'MNL'.
         DBMS_OUTPUT.PUT_LINE (   ' Fetched record 2: '
                               || lv_msg_type
                               || '-'
                               || c1.DATA);

         IF (lv_msg_type = pl_miniload_processing.ct_ship_ord_status)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Error in executing p_insert_miniload_order';
            pl_miniload_processing.p_insert_miniload_order (l_miniload_info,
                                                            lv_msg_type,
                                                            ln_status,
                                                            lb_log_flag);
         ELSIF (lv_msg_type IN
                   (pl_miniload_processing.ct_exp_rec_comp,
                    pl_miniload_processing.ct_inv_adj_inc,
                    pl_miniload_processing.ct_inv_arr,
                    pl_miniload_processing.ct_inv_adj_dcr,
                    pl_miniload_processing.ct_inv_plan_mov,
                    pl_miniload_processing.ct_inv_lost,
                    pl_miniload_processing.ct_message_status))
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Error in executing p_insert_miniload_message';
            DBMS_OUTPUT.PUT_LINE (' Call in_mlmsg ' || c1.DATA);
            pl_miniload_processing.p_insert_miniload_message (l_miniload_info,
                                                              lv_msg_type,
                                                              ln_status,
                                                              lb_log_flag);
         ELSE
            ln_status := pl_miniload_processing.ct_failure;
            lv_msg_text :=
                  'Prog Code: '
               || pl_miniload_processing.ct_program_code
               || ' Invalid msg type in hdo table: '
               || lv_msg_type;
         END IF;

         IF (ln_status = pl_miniload_processing.ct_failure)
         THEN
            Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
         ELSE
            DELETE FROM HDO
                  WHERE hdo_id = c1.hdo_id;

            COMMIT;

            IF (SQL%ROWCOUNT = 0)
            THEN
               lv_msg_text :=
                     'Prog Code: '
                  || pl_miniload_processing.ct_program_code
                  || ' Deletion from HDO failed'
                  || ' HDO Id : '
                  || c1.hdo_id;
               Pl_Text_Log.ins_msg ('FATAL',
                                    lv_fname,
                                    lv_msg_text,
                                    SQLCODE,
                                    SQLERRM);
            END IF;
         END IF;

         COMMIT;
      END LOOP;

      IF c_hdo_rec%ISOPEN
      THEN
         CLOSE c_hdo_rec;
      END IF;

      -- Commit is used to end the distributed transaction
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF c_hdo_rec%ISOPEN
         THEN
            CLOSE c_hdo_rec;
         END IF;

         ROLLBACK;
         lv_msg_text :=
                   'Prog Code: ' || ct_program_code || ' Error in p_check_hdo';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
   END p_check_hdo;

-------------------------------------------------------------------------
-- Procedure:
--    p_insert_hoi
--
-- Description:
--    This procedure inserts the messages into the HOI table. It takes
--    the input from the miniload_message and miniload_order table.
--    the records with the status 'N' or 'F' with source system as 'SWM'
--    are selected and are inserted into the mini-load table (HOI).
--
-- Parameters:
--
-- Called by:
--    It is a batch process running priodically to check the
--    miniload_message and miniload_order table.
--
-- Exceptions raised:
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/21/05          Created as part of the mini-load changes
---------------------------------------------------------------------------
   PROCEDURE p_insert_hoi
   IS
      lv_msg_text          VARCHAR2 (1500);
      lv_fname             VARCHAR2 (50)                  := 'P_INSERT_HOI';
      ln_status            NUMBER (1)    := pl_miniload_processing.ct_success;
      lv_msg_status        miniload_message.status%TYPE;
      lb_log_flag          BOOLEAN;
      ln_rec_count         NUMBER                         := 0;


    CURSOR c_msgs_to_miniload IS
         SELECT /*+ index(miniload_message i_mlm_status_src_system) */
                    message_id, message_type, add_date, ml_data_len, ml_data,
                  status, ml_system
             FROM miniload_message
             WHERE source_system IN ('SWM', 'SUS') AND status IN ('N')
         UNION ALL
         SELECT  /*+ index(miniload_order i_mlo_status_src_system) */
                  message_id, message_type, add_date, ml_data_len, ml_data,
                  status, ml_system
             FROM miniload_order
            WHERE source_system IN ('SWM', 'SUS') AND status IN ('N')
         ORDER BY message_id, add_date;

      r_msgs_to_miniload   c_msgs_to_miniload%ROWTYPE;
   BEGIN
      Pl_Text_Log.init ('pl_miniload_interface.p_insert_hoi');
      lb_log_flag := FALSE;

      --Open the cursor as follows:
      IF NOT c_msgs_to_miniload%ISOPEN
      THEN
         OPEN c_msgs_to_miniload;
      END IF;

      --
      -- Fetch all the records that are to be sent to mini-load with status
      -- as New or Fail by using the cursor c_msgs_to_miniload.
      --
      LOOP
         FETCH c_msgs_to_miniload
          INTO r_msgs_to_miniload;

         --For each record fetched, insert the record into the HOI table
         EXIT WHEN c_msgs_to_miniload%NOTFOUND;
         ln_rec_count := ln_rec_count + 1;

         BEGIN
            SAVEPOINT s;

	/*	HOI_ID will not be used anymore and message_id from the miniload_message table will be copied to 
		the HOI table.
    
		    INSERT INTO HOI
                        (hoi_id, creation_timestamp,
                         LENGTH,
                         DATA,
                         ml_system
                        )
                 VALUES (hoi_id_seq.NEXTVAL, SYSDATE,
                         r_msgs_to_miniload.ml_data_len,
                         r_msgs_to_miniload.ml_data,
                         r_msgs_to_miniload.ml_system);
	*/                        
		        INSERT INTO HOI
                        (hoi_id, creation_timestamp,
                         LENGTH,
                         DATA,
                         ml_system)
                 VALUES (r_msgs_to_miniload.message_id, SYSDATE,
                         r_msgs_to_miniload.ml_data_len,
                         r_msgs_to_miniload.ml_data,
                         r_msgs_to_miniload.ml_system);


            COMMIT;

            IF ((RTRIM(SUBSTR (r_msgs_to_miniload.ml_data,
                                  1,
                                  pl_miniload_processing.ct_msg_type_size))
                            <> pl_miniload_processing.ct_ship_ord_inv)
                OR (MOD (ln_rec_count, 100) = 0)) THEN
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Message Inserted in hoi: '
                  || r_msgs_to_miniload.message_type
                  || ' Msg id: '
                  || r_msgs_to_miniload.message_id;
               Pl_Text_Log.ins_msg ('WARNING',
                                    lv_fname,
                                    lv_msg_text,
                                    NULL,
                                    NULL);
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               ROLLBACK TO s;
               lv_msg_text :=
                     'Prog Code: '
                  || ct_program_code
                  || ' Error inserting into HOI';
               Pl_Text_Log.ins_msg ('FATAL',
                                    lv_fname,
                                    lv_msg_text,
                                    SQLCODE,
                                    SQLERRM);
               ln_status := pl_miniload_processing.ct_failure;
         END;

         IF (ln_status = pl_miniload_processing.ct_failure)
         THEN
            lv_msg_status := 'F';
         ELSIF (ln_status = pl_miniload_processing.ct_success)
         THEN
            lv_msg_status := 'S';
         END IF;

         -- update the status in the miniload_message.
         pl_miniload_processing.p_upd_status (r_msgs_to_miniload.message_id,
                                              r_msgs_to_miniload.message_type,
                                              lv_msg_status,
                                              ln_status,
                                              lb_log_flag);

         IF (ln_status = pl_miniload_processing.ct_failure)
         THEN
            lv_msg_text :=
                  'Prog Code: '
               || ct_program_code
               || ' Error in updating status'
               || ' Msg Type: '
               || r_msgs_to_miniload.message_type
               || ' Msg id: '
               || r_msgs_to_miniload.message_id;
            Pl_Text_Log.ins_msg ('FATAL',
                                 lv_fname,
                                 lv_msg_text,
                                 SQLCODE,
                                 SQLERRM);
         END IF;
      END LOOP;

      IF c_msgs_to_miniload%ISOPEN
      THEN
         CLOSE c_msgs_to_miniload;
      END IF;

      -- Commit is used to end the distributed transaction
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF c_msgs_to_miniload%ISOPEN
         THEN
            CLOSE c_msgs_to_miniload;
         END IF;

         ROLLBACK TO s;
         lv_msg_text :=
                  'Prog Code: ' || ct_program_code || ' Error in p_insert_hoi';
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE,
                              SQLERRM);
   END p_insert_hoi;
END pl_miniload_interface;
/
