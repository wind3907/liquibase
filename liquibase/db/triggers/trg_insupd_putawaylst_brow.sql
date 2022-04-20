/* 23-OCT-2001 prpksn:initial version */
/* This trigger will use the LOC_REFERENCE table and convert  the front */
/* location to the back location */


------------------------------------------------------------------------------
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/16/02 prpbcb   rs239a DN NA  rs239b DN 11062
--                      Added assignment to upd_date and upd_user when
--                      For RDC non-dependent changes.
--                      Took out the WHEN clause and put in an IF statement
--                      and the condition of only firing only on the dest_loc
--                      and moved the logic to the IF statement.
--                      The WHEN clause was:
--                         WHEN (substr(new.rec_id,1,1) not in ('S','D'))
--                      Changed
--           BEFORE INSERT OR UPDATE of dest_loc ON putawaylst for each row
--                      to
--           BEFORE INSERT OR UPDATE ON putawaylst for each row
--    09/30/08 prpakp  changed to make sure that cool_trk is turned off for
--			non-sea food (other than category 04) items.
------------------------------------------------------------------------------

create or replace trigger swms.trg_insupd_putawaylst_brow
 BEFORE INSERT OR UPDATE ON swms.putawaylst for each row
 declare
   l_bck_logi_loc    loc.logi_loc%type;
   l_category        varchar2(2);
   --

begin
   IF (  (INSERTING AND :NEW.dest_loc IS NOT NULL)
       OR (UPDATING AND
           NVL(:old.dest_loc, 'x') != NVL(:new.dest_loc, 'x'))) THEN
      IF (substr(:new.rec_id,1,1) not in ('S','D')) THEN
         if pl_pflow.g_palletflow_enable is null then
            pl_pflow.g_palletflow_enable := 
	       pl_common.f_get_syspar('ENABLE_PALLET_FLOW','N');
         end if;
         if pl_pflow.g_palletflow_enable = 'Y' then
            l_bck_logi_loc := pl_pflow.f_get_back_loc(:new.dest_loc);
            if (l_bck_logi_loc != 'NONE') and (:new.dest_loc != l_bck_logi_loc) then 
	       /* Set the inventory location to inv_dest_loc column */
	       /* then change the dest_loc to the back location */
	       :new.inv_dest_loc := :new.dest_loc;
	       :new.dest_loc := l_bck_logi_loc;
            end if;
         end if;
      END IF;
   END IF;

   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;
   
   IF (:NEW.cool_trk = 'Y') THEN
	BEGIN
	  select substr(category,1,2)
	  into l_category
	  from pm
	  where prod_id = nvl(:new.prod_id,:old.prod_id);
	  exception
		when others then
			l_category := '00';
        END;
   END IF;
   IF (:NEW.cool_trk = 'Y' and l_category != '04') then
       :NEW.cool_trk := 'N';
   END IF;
	
end;
/

