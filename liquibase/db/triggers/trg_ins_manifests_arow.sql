
/******************************************************************************
  Modification History
  Date      	User   		JIRA CARD              Comment
  06/07/2020	knha8378       	OPCOF-3030             initial version
******************************************************************************/

--
-- Purpose: Some routes are not STS like will-call and immediate routes that will not go through STS return routine.
--	   Therefore, this trigger will update sts_completed_ind to Y or else user will not able to return products
--
CREATE OR REPLACE TRIGGER trg_ins_manifests_arow
 BEFORE INSERT ON MANIFESTS
   FOR EACH ROW

    DECLARE
	l_count_rec     number := 0;
	l_immediate_ind  ORDM.IMMEDIATE_IND%TYPE;

	CURSOR get_ordm IS
	SELECT nvl(immediate_ind,'N') immediate_ind
	FROM  ordm
	WHERE route_no = :new.route_no;

BEGIN
 /* force pickup request would not have record exist in ORDM */
 /* if this is a force pickup by itself then set flag to Y */
 OPEN get_ordm;
 FETCH get_ordm into l_immediate_ind;
 IF get_ordm%FOUND THEN
    CLOSE get_ordm;
    l_count_rec := 0;
    FOR each in get_ordm LOOP
        IF :new.manifest_status <> 'PAD' then
	   IF each.immediate_ind = 'Y' THEN
	      l_count_rec := l_count_rec + 1;
	   END IF;
        ELSE 
           l_count_rec := l_count_rec + 1;
        END IF;
    END LOOP;
    IF  l_count_rec > 0 then
        :new.sts_completed_ind := 'Y';
    ELSE
        :new.sts_completed_ind := 'N';
    END IF;
 ELSE
     CLOSE get_ordm;
     :new.sts_completed_ind := 'Y';
 END IF;

END trg_ins_manifests_arow;
/
