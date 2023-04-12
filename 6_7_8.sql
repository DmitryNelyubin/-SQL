USE etp;

-- 1.1 Вычисление законтрактованных средств выбранного заказчика (сумма цен всех контрактов заказчика с id = 29) - JOIN
SELECT SUM(c.price) FROM contracts c 
JOIN protocols p ON c.protocol_id = p.id 
JOIN procedures p2 ON p.procedure_id = p2.id
WHERE p2.customer_id = 29;

-- 1.2 Вычисление законтрактованных средств выбранного заказчика (сумма цен всех контрактов заказчика)
SELECT SUM(price) FROM contracts
WHERE protocol_id IN (
	SELECT id FROM protocols
	WHERE procedure_id IN (
		SELECT id FROM procedures
		WHERE customer_id = 29
	)
);

-- 2.1 Нахождение количества опубликованных процедур выбранного типа процедуры в рамках холдинга - JOIN
SELECT COUNT(*) FROM procedures p 
JOIN procedure_types pt ON p.procedure_type_id = pt.id 
JOIN organisators o ON p.organisator_id = o.id 
WHERE o.holding_id = 71 AND pt.name LIKE '%конкурс';

-- 2.2 Нахождение количества опубликованных процедур выбранного типа процедуры в рамках холдинга 
SELECT COUNT(*) FROM procedures
WHERE procedure_type_id IN (
	SELECT id FROM procedure_types
	WHERE name LIKE '%конкурс'
) AND organisator_id IN (
	SELECT id FROM organisators
	WHERE holding_id = 71
);

-- 3.1 Нахождение заказчика, на процедуру которого было подано наибольшее количество заявок в протоколе подведения итогов - JOIN
SELECT c.name AS customer_name FROM protocols p 
JOIN procedures p2 ON p.procedure_id = p2.id 
JOIN customers c ON p2.customer_id = c.id 
ORDER BY p.requests_count DESC
LIMIT 1;

-- 3.2 Нахождение заказчика, на процедуру которого было подано наибольшее количество заявок в протоколе подведения итогов 
SELECT 
	requests_count,
	(SELECT name FROM customers WHERE id = (
		SELECT customer_id FROM procedures WHERE procedure_id = procedures.id
	)) AS customer_id 
FROM protocols
ORDER BY requests_count DESC
LIMIT 1;


-- Представления:
-- 1. Для каждой организации выводим холдинг
CREATE OR REPLACE VIEW v_organisators_holdings AS
SELECT 
	o.id AS organisator_id, 
	o.name AS organisator_name, 
	o.holding_id AS holding_id,
	h.name AS holding_name,
	h.region AS region
FROM organisators o 
JOIN holdings h ON o.holding_id = h.id;

-- 2. Для каждой процедуры выводим её код типа процедуры и наименование типа процедуры
CREATE OR REPLACE VIEW v_procedure_code AS
SELECT
	p.id AS procedure_id,
	pt.code AS procedure_code,
	pt.name AS  procedure_type_name
FROM procedures p 
JOIN procedure_types pt ON p.procedure_type_id = pt.id; 


-- Триггеры 
-- 1. Создаем архивную таблицу логов и вставляем в неё данные при добавлении новой процедуры
DROP TABLE IF EXISTS procedure_logs;
CREATE TABLE procedure_logs (
	procedure_id BIGINT NOT NULL,
	procedure_code VARCHAR(4) NOT NULL,
	customer_name VARCHAR(64) NOT NULL,
	organisator_name VARCHAR(64) NOT NULL
) ENGINE = ARCHIVE;

DROP TRIGGER IF EXISTS procedure_logging;
DELIMITER $$
$$
CREATE TRIGGER procedure_logging
AFTER INSERT
ON procedures FOR EACH ROW
BEGIN 
	INSERT INTO procedure_logs VALUES (
	NEW.id, 
	(SELECT code FROM procedure_types WHERE NEW.procedure_type_id = id), 
	(SELECT name FROM customers WHERE NEW.customer_id = id), 
	(SELECT name FROM organisators WHERE NEW.organisator_id = id)
);
END
$$
DELIMITER ;

-- 2. Создаем архивную таблицу логов и вставляем в неё данные при добавлении нового заказчика
DROP TABLE IF EXISTS customer_logs;
CREATE TABLE customer_logs (
	customer_id BIGINT NOT NULL,
	organisator_name VARCHAR(64) NOT NULL,
	holding_name VARCHAR(64) NOT NULL,
	customer_level_name VARCHAR(64) NOT NULL
) ENGINE = ARCHIVE;

DROP TRIGGER IF EXISTS customer_logging;
DELIMITER $$
$$
CREATE TRIGGER customer_logging
AFTER INSERT
ON customers FOR EACH ROW
BEGIN 
	INSERT INTO customer_logs VALUES (
	NEW.id,
	(SELECT name FROM organisators WHERE NEW.organisator_id = id),
	(SELECT 
		(SELECT name FROM holdings WHERE id = organisators.holding_id) 
	FROM organisators
	WHERE NEW.organisator_id = id), 
	(SELECT name FROM organisation_levels WHERE NEW.organisation_level_id = id)
);
END
$$
DELIMITER ;


-- Функции/процедуры
-- 1. Вычисление процента расторгнутых контрактов заказчика (отношение количества контрактов со статусом актуальности = ложь, к общему количеству контрактов заказчика)
DROP FUNCTION IF EXISTS etp.not_actual_percent;

DELIMITER $$
$$
CREATE FUNCTION etp.not_actual_percent(customer_id BIGINT)
RETURNS INT READS SQL DATA
BEGIN
	DECLARE total_contracts BIGINT DEFAULT 0;
	DECLARE not_actual_count BIGINT DEFAULT 0;

	SET total_contracts = (
		SELECT COUNT(*) FROM contracts c
		JOIN protocols p ON c.protocol_id = p.id 
		JOIN procedures p2 ON p.procedure_id = p2.id 
		WHERE p2.customer_id = customer_id
	);

	SET not_actual_count = (
		SELECT COUNT(*) FROM contracts c
		JOIN protocols p ON c.protocol_id = p.id 
		JOIN procedures p2 ON p.procedure_id = p2.id 
		JOIN customers c2 ON p2.customer_id = c2.id 
		WHERE c2.id = customer_id AND c.is_actual = b'0'
	);

	RETURN not_actual_count / total_contracts * 100;
END$$
DELIMITER ;

SELECT not_actual_percent(59);

-- 2. Вычисление процента выполнения национального проекта (отношение количества контрактов, 
-- заключенных по процедурам, опубликованным по позициям всех планов-графиков, относящихся к выбранному
-- национальному проекту, к количеству позиций планов-графиков, относящихся к выбранному национальному проекту)
DROP FUNCTION IF EXISTS etp.national_project_percent;

DELIMITER $$
$$
CREATE FUNCTION etp.national_project_percent(national_project_id BIGINT)
RETURNS INT READS SQL DATA
BEGIN
	DECLARE graph_position_count INT;
	DECLARE contract_count INT;

	SET contract_count = (
		SELECT COUNT(*) FROM contracts c
		JOIN protocols p ON c.protocol_id = p.id 
		JOIN procedures p2 ON p.procedure_id = p2.id 
		JOIN graph_positions gp ON p2.graph_position_id = gp.id 
		WHERE gp.national_project_id = national_project_id
	);

	SET graph_position_count = (
		SELECT COUNT(*) FROM graph_positions gp
		WHERE gp.national_project_id = national_project_id 
	);

	RETURN contract_count / graph_position_count * 100;
END$$
DELIMITER ;

SELECT national_project_percent(1);

