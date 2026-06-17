--Joins Refresher: Anti-Join Pattern

SELECT
    a.id,
    a.name
FROM authors AS a
WHERE NOT EXISTS (
    SELECT 1
    FROM books AS b
    WHERE b.author_id = a.id
);

