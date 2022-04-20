/******************************************************************************
  @(#) trg_ins_fs_inbound_arow.sql
  @(#) src/schema/triggers/ttrg_ins_fs_inbound_arow, swms, swms.9, 10.1.1 9/8/06 1.4
******************************************************************************/

/******************************************************************************
  Modification History
  Date      User   		Defect 				                       Comment
  04/23/13  bgul2852         					                   initial version
  08/29/13  mdev3739	Relationship Constraint issue between 	   v0.1 for CRQ000000047326)
			            Food_Safety_Inbound and Food_Safety_Child  
  09/09/21  pdas8114    Jira# 3614, Added XN erm type						
******************************************************************************/

--
-- Purpose: To insert child PO's in table food_Safety_inbound_child when 
-- food safety information is collected for the parent PO.
--
--

CREATE OR REPLACE TRIGGER swms.trg_ins_fs_inbound_arow
 AFTER INSERT ON swms.food_safety_inbound
   FOR EACH ROW

        DECLARE

	CURSOR lc_erm_details IS 
	SELECT e.erm_id
	FROM erm e 
	WHERE e.load_no =:NEW.load_no
	AND e.erm_id <> :NEW.erm_id
	AND e.erm_type IN('PO','VN','SN','XN')
	AND nvl(e.food_safety_print_flag,'N')='N'; 
	
BEGIN

                                                    
   	  /* To insert the PO's into the food_safety_inbound_child table having same load_no*/
   		FOR lv_temperature IN lc_erm_details 
	 		LOOP
			  DELETE food_safety_inbound_child
			    WHERE erm_id=lv_temperature.erm_id; /*CRQ000000047326 - Removed the check for load_no in where condition */
			
	 		  INSERT INTO food_safety_inbound_child 
	 		    (load_no,parent_erm_id,erm_id,add_date,add_source,add_user,upd_source,upd_date,upd_user)
	 		  VALUES 
	 		    (:NEW.load_no,:NEW.erm_id,lv_temperature.erm_id,sysdate,:NEW.add_source,REPLACE(user,'OPS$',''),NULL,NULL,NULL);
	 		END LOOP; 
END;
/                        
