CREATE TABLE swms.forklift_task_priority (
	forklift_task_type	VARCHAR2 (3) NOT NULL,
	severity			VARCHAR2 (16) NOT NULL,
	priority			NUMBER (2) NOT NULL,
	remarks				VARCHAR2 (1024) NOT NULL,
	CONSTRAINT pk_forklift_task_priority
	PRIMARY KEY (forklift_task_type, severity))
/

CREATE PUBLIC SYNONYM forklift_task_priority
   FOR	swms.forklift_task_priority
/

GRANT SELECT, INSERT, UPDATE, DELETE
   ON swms.forklift_task_priority
   TO swms_user
/

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'DMD', 'CRITICAL', 5,
'Selection batch for this item is active or complete. The user has shorted this item.');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'NDM', 'CRITICAL', 7,
'A selector has shorted this item. Non Demand replenishment is forced from the short screen');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'BLK', 'CRITICAL', 10,
'At least one of the selection batches completed for this truck has a stop number lower than the stop number for this bulk pull');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'DMD', 'URGENT', 15,
'Selection batch for this item is active or complete. The user has not picked this item yet or fully picked this item. So, another user may get a short soon.');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'BLK', 'URGENT', 20,
'At least one of the selection batches for this truck is in complete status');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'DMD', 'HIGH', 25,
'Selection batch for this item is not active yet. There is a miniload replenishment depending on this');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'DMD', 'MEDIUM', 35,
'Selection batch for this item is not active yet. There is a split home replenishment depending on this');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'DMD', 'NORMAL', 45,
'All other demand replenishments');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'BLK', 'NORMAL', 50,
'All other bulk pulls');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'NDM', 'URGENT', 55,
'Non Demand replenishment for an actual order for the day');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'NDM', 'HIGH', 60,
'Non Demand replenishment for anticipated orders for the day');

INSERT INTO swms.forklift_task_priority (forklift_task_type, severity, priority, remarks)
VALUES ( 'NDM', 'NORMAL', 75,
'User created Non Demand replenishments (Using Min/Max, Location cube etc.)');

