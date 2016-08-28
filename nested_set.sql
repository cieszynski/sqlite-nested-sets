-- main table
CREATE TABLE tree (
    _id     INTEGER PRIMARY KEY,
    name    TEXT NOT NULL,
    lft     INTEGER NOT NULL,
    rgt     INTEGER NOT NULL
);

-- helper table to store variable
CREATE TABLE p (
	_id	INTEGER,
	rgt	INTEGER,
	lft	INTEGER,
	PRIMARY KEY(_id)
)

-- init table
INSERT INTO tree (_id, name,lft,rgt) VALUES (1, 'root',1,2);

-- trigger to insert, move or delete item/subtree
-- to insert new item: fields name and parent are required
CREATE TRIGGER insert_item AFTER INSERT ON tree
BEGIN
	UPDATE tree SET lft=(SELECT rgt FROM tree WHERE _id=New.parent), 
					rgt=(SELECT rgt FROM tree WHERE _id=New.parent)+1 
		WHERE _id IS NEW._id;
	UPDATE tree SET lft=lft+2 WHERE lft > (SELECT rgt FROM tree WHERE _id=NEW.parent) AND _id IS NOT NEW._id;
	UPDATE tree SET rgt=rgt+2 WHERE rgt >= (SELECT rgt FROM tree WHERE _id=NEW.parent) AND _id IS NOT NEW._id;
END

-- after item is removed: recalculating the tree 
CREATE TRIGGER delete_item AFTER DELETE ON tree
BEGIN
    DELETE FROM tree WHERE lft BETWEEN OLD.lft AND OLD.rgt;
    UPDATE tree SET lft=lft-round((OLD.rgt-OLD.lft+1)) WHERE lft > OLD.rgt;
    UPDATE tree SET rgt=rgt-round((OLD.rgt-OLD.lft+1)) WHERE rgt > OLD.rgt;
END

-- to move item/subtree: new parent id is required
CREATE TRIGGER update_item BEFORE UPDATE OF parent ON tree 
BEGIN
    INSERT OR REPLACE INTO p (_id, lft) VALUES (1, (SELECT lft FROM tree WHERE _id=NEW.parent));
	UPDATE tree
	SET
	    lft = lft + CASE
	        WHEN (SELECT lft FROM p WHERE _id=1) < OLD.lft THEN CASE
	            WHEN lft >= OLD.rgt +1 THEN 0
	            ELSE CASE
                    WHEN lft >= OLD.lft THEN (SELECT lft FROM p WHERE _id=1) - OLD.lft +1
				    ELSE CASE
				        WHEN lft >= (SELECT lft FROM p WHERE _id=1) +1 THEN OLD.rgt - OLD.lft +1
				        ELSE 0
                        END
					END
			    END
		    ELSE CASE
		        WHEN lft >= (SELECT lft FROM p WHERE _id=1) +1 THEN 0
		        ELSE CASE
		            WHEN lft >= OLD.rgt +1 THEN -OLD.rgt + OLD.lft -1
				    ELSE CASE
				        WHEN lft >= OLD.lft THEN (SELECT lft FROM p WHERE _id=1) - OLD.rgt
				        ELSE 0
						END
					END
			     END
		    END,
	    rgt = rgt + CASE
            WHEN (SELECT lft FROM p WHERE _id=1) < OLD.lft THEN CASE
                WHEN rgt >= OLD.rgt +1 THEN 0
                ELSE CASE
                    WHEN rgt >= OLD.lft THEN (SELECT lft FROM p WHERE _id=1) - OLD.lft +1
                    ELSE CASE
                        WHEN rgt >= (SELECT lft FROM p WHERE _id=1) +1 THEN OLD.rgt - OLD.lft +1
                        ELSE 0
	                    END
				    END
		        END
		    ELSE CASE
		        WHEN rgt >= (SELECT lft FROM p WHERE _id=1) +1 THEN 0
                ELSE CASE
                    WHEN rgt >= OLD.rgt +1 THEN -OLD.rgt + OLD.lft -1
			        ELSE CASE
			            WHEN rgt >= OLD.lft THEN (SELECT lft FROM p WHERE _id=1) - OLD.rgt
			            ELSE 0
					    END
				    END
		        END
	        END
	WHERE (SELECT lft FROM p WHERE _id=1) < OLD.lft OR (SELECT lft FROM p WHERE _id=1) > OLD.rgt;
END

-- queries
-- all elements with level
  SELECT n.name,
         COUNT(*)-1 AS level
    FROM tree AS n,
         tree AS p
   WHERE n.lft BETWEEN p.lft AND p.rgt
GROUP BY n.lft
ORDER BY n.lft;

-- all elements with level and children count
  SELECT n.name,
         COUNT(*)-1 AS level,
         ROUND ((n.rgt - n.lft - 1) / 2) AS offspring
    FROM tree AS n,
         tree AS p
   WHERE n.lft BETWEEN p.lft AND p.rgt
GROUP BY n.lft
ORDER BY n.lft;

-- all elements level 1
  SELECT n.name,
         COUNT(*)-1 AS level
    FROM tree AS n,
         tree AS p
   WHERE n.lft BETWEEN p.lft AND p.rgt
GROUP BY n.lft
HAVING level =1
ORDER BY n.lft;

-- subtree(1)
  SELECT n.name,
         COUNT(*)-1 AS level
    FROM tree AS n,
         (SELECT lft, rgt FROM tree WHERE _id=$ID) AS p
   WHERE n.lft BETWEEN p.lft AND p.rgt
GROUP BY n.lft
ORDER BY n.lft;

-- subtree(2)
SELECT node.name, (COUNT(parent._id) - (sub_tree.level + 1)) AS depth
FROM tree AS node,
        tree AS parent,
        tree AS sub_parent,
        (
                SELECT node.name, (COUNT(parent._id) - 1) AS level
                FROM tree AS node,
                        tree AS parent
                WHERE node.lft BETWEEN parent.lft AND parent.rgt
                        AND node._id=$ID
                GROUP BY node._id
                ORDER BY node.lft
        )AS sub_tree
WHERE node.lft BETWEEN parent.lft AND parent.rgt
        AND node.lft BETWEEN sub_parent.lft AND sub_parent.rgt
        AND sub_parent.name = sub_tree.name
GROUP BY node._id
HAVING depth = 1 --WITHOUT ROOT
--HAVING depth <= 1 --WITH ROOT
--HAVING depth >= 1 --WITH CHILDREN
ORDER BY node.lft;
