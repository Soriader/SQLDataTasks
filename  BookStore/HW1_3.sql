--Given employees(id, manager_id, name, salary):
--list every employee with their full management chain, total team salary if they’re a manage

WITH RECURSIVE manager_chain AS (
SELECT
    id,
    manager_id,
    name,
    salary,
	0 AS depth,
	name AS management_chain
FROM employees
WHERE manager_id IS NULL

UNION ALL

SELECT
    workers.id,
    workers.manager_id,
    workers.name,
    workers.salary,
	(manager.depth + 1) AS depth,
	manager.management_chain || ' > ' || workers.name AS management_chain
FROM employees AS workers
JOIN manager_chain AS manager ON manager.id = workers.manager_id
),

total_team_salary AS(
SELECT
    manager.id AS root_manager_id,
	workers.id AS subordinate_id,
	workers.salary as subordinate_salary
FROM employees AS workers
JOIN employees AS manager ON manager.id = workers.manager_id

UNION ALL
SELECT
    previous.root_manager_id,
    workers.id AS subordinate_id,
    workers.salary AS subordinate_salary
FROM employees AS workers
JOIN total_team_salary AS previous
    ON workers.manager_id = previous.subordinate_id
),

sum_of_total_team_salary AS (

SELECT
    root_manager_id,
    SUM(subordinate_salary) AS total_team_salary
FROM total_team_salary
GROUP BY root_manager_id
)

SELECT
    mc.id,
    mc.name,
    mc.salary,
    mc.depth,
    mc.management_chain,
    tts.total_team_salary
FROM manager_chain AS mc
LEFT JOIN sum_of_total_team_salary AS tts
    ON tts.root_manager_id = mc.id
ORDER BY mc.depth, mc.id;
