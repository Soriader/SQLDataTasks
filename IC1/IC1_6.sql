--authors has a mentor_id . Find every author influenced (transitively) by author 1.

ALTER TABLE authors
ADD COLUMN mentor_id BIGINT REFERENCES authors(id);

WITH RECURSIVE influence_tree AS (
SELECT
	id,
	name,
	mentor_id,
	1 AS depth
FROM authors
Where mentor_id = 1

UNION ALL

SELECT
	a.id,
	a.name,
	a.mentor_id,
	(it.depth + 1) AS depth
FROM authors AS a
JOIN influence_tree AS it ON it.id = a.mentor_id
)
SELECT *
FROM influence_tree
ORDER BY depth, mentor_id, id;