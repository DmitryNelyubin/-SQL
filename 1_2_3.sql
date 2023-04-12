DROP DATABASE IF EXISTS etp;
CREATE DATABASE etp;
USE etp;

-- 
-- Электронные торговые площадки - это сайты, на которых заказчики (государственные или коммерческие организации) размещают информацию о закупках, 
-- а поставщики (любые юридические и физические лица) в рамках конкурентной борьбы участвуют в объявленных конкурсных процедурах: 
-- подают заявки, делают ценовые предложения, заключают контракты.
-- В рамках курсвой работы представлена база данных для ЭТП.
-- Общий(упрощенный) алгоритм работы на ЭТП:
-- 0. Заказчик размещает план-график осуществления закупок на финансовый год планирования
-- 1. Заказчик размешает на площадке извещение о проведении закупки, в соответствии с позицией плана-графика
-- 2. Поставщки изучают извещения и подают заявки на участике в процедуре закупки
-- 3. Заказчик выбирает победителя из поданных заявок и публикует протокол подведения итогов
-- 4. Поставщик(победитель) ознакомляется с протоколом и подписывает контракт с заказчиком 
--
-- Задачи, решаемые БД "ЭТП":
-- 0. Данная база данных решает проблему хранения данных о всех сущностях в рамках проведения закупки
-- 1. Вычисление законтрактованных средств выбранного заказчика (сумма цен всех контрактов заказчика)
-- 2. Вычисление процента выполнения национального проекта (отношение количества контрактов, заключенных по процедурам, опубликованным по позициям всех планов-графиков, относящихся к выбранному
-- национальному проекту, к количеству позиций планов-графиков, относящихся к выбранному национальному проекту)
-- 3. Нахождение количества опубликованных процедур выбранного типа процедуры в рамках холдинга
-- 4. Нахождение заказчика, на процедуру которого было подано наибольшее количество заявок в протоколе подведения итогов
-- 5. Вычисление процента расторгнутых контрактов заказчика (отношение количества контрактов со статусом актуальности = ложь, к общему количеству контрактов заказчика)
-- 


DROP TABLE IF EXISTS national_projects;
CREATE TABLE national_projects (
	id SERIAL PRIMARY KEY,
	code VARCHAR(1) UNIQUE NOT NULL,
	name VARCHAR(64) UNIQUE NOT NULL
);

DROP TABLE IF EXISTS procedure_types;
CREATE TABLE procedure_types (
	id SERIAL PRIMARY KEY,
	code VARCHAR(4) UNIQUE NOT NULL,
	name VARCHAR(64) UNIQUE NOT NULL
);

DROP TABLE IF EXISTS participants;
CREATE TABLE participants (
	id SERIAL PRIMARY KEY,
	firm_name VARCHAR(256) UNIQUE NOT NULL,
	region VARCHAR(64) NOT NULL,
	is_unscurpulous bit DEFAULT 0
);

DROP TABLE IF EXISTS holdings;
CREATE TABLE holdings (
	id SERIAL PRIMARY KEY,
	name VARCHAR(256) UNIQUE NOT NULL,
	region VARCHAR(64) NOT NULL
);

DROP TABLE IF EXISTS organisation_levels;
CREATE TABLE organisation_levels (
	id SERIAL PRIMARY KEY,
	name VARCHAR(64) UNIQUE NOT NULL
);


DROP TABLE IF EXISTS organisators;
CREATE TABLE organisators (
	id SERIAL PRIMARY KEY,
	name VARCHAR(256) UNIQUE NOT NULL,
	organisation_level_id BIGINT UNSIGNED NOT NULL,
	holding_id BIGINT UNSIGNED NOT NULL,
	
	FOREIGN KEY (organisation_level_id) REFERENCES organisation_levels(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (holding_id) REFERENCES holdings(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
	id SERIAL PRIMARY KEY,
	name VARCHAR(256) UNIQUE NOT NULL,
	organisation_level_id BIGINT UNSIGNED NOT NULL,
	organisator_id BIGINT UNSIGNED NOT NULL,
	
	FOREIGN KEY (organisation_level_id) REFERENCES organisation_levels(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (organisator_id) REFERENCES organisators(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS plan_graphs;
CREATE TABLE plan_graphs (
	id SERIAL PRIMARY KEY,
	publish_date DATETIME DEFAULT NOW(),
	finance_year YEAR DEFAULT (YEAR(NOW())),
	customer_id BIGINT UNSIGNED NOT NULL,
	
	FOREIGN KEY (customer_id) REFERENCES customers(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS graph_positions;
CREATE TABLE graph_positions (
	id SERIAL PRIMARY KEY,
	plan_graph_id BIGINT UNSIGNED NOT NULL,
	customer_id BIGINT UNSIGNED NOT NULL,
	national_project_id BIGINT UNSIGNED NOT NULL,
	
	FOREIGN KEY (plan_graph_id) REFERENCES plan_graphs(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (customer_id) REFERENCES customers(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (national_project_id) REFERENCES national_projects(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS procedures;
CREATE TABLE procedures (
	id SERIAL PRIMARY KEY,
	publish_date DATETIME DEFAULT NOW(),
	procedure_type_id BIGINT UNSIGNED NOT NULL,
	customer_id BIGINT UNSIGNED NOT NULL,
	organisator_id BIGINT UNSIGNED NOT NULL,
	graph_position_id BIGINT UNSIGNED NOT NULL UNIQUE,
	
	FOREIGN KEY (procedure_type_id) REFERENCES procedure_types(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (customer_id) REFERENCES customers(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (organisator_id) REFERENCES organisators(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (graph_position_id) REFERENCES graph_positions(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS protocols;
CREATE TABLE protocols (
	id SERIAL PRIMARY KEY,
	requests_count BIGINT UNSIGNED NOT NULL,
	publish_date DATETIME DEFAULT NOW(),
	procedure_id BIGINT UNSIGNED NOT NULL UNIQUE,
	
	FOREIGN KEY (procedure_id) REFERENCES procedures(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS contracts;
CREATE TABLE contracts (
	id SERIAL PRIMARY KEY,
	signed_date DATETIME DEFAULT NOW(),
	price BIGINT NOT NULL,
	protocol_id BIGINT UNSIGNED NOT NULL UNIQUE,
	participant_id BIGINT UNSIGNED NOT NULL,
	is_actual BIT DEFAULT 1,
	
	FOREIGN KEY (protocol_id) REFERENCES protocols(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (participant_id) REFERENCES participants(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TABLE IF EXISTS complains;
CREATE TABLE complains (
	id SERIAL PRIMARY KEY,
	status ENUM('обосновонная', 'не обоснованная', 'отклонена'), 
	publish_date DATETIME DEFAULT NOW(),
	procedure_id BIGINT UNSIGNED NOT NULL,
	
	FOREIGN KEY (procedure_id) REFERENCES procedures(id) ON UPDATE CASCADE ON DELETE CASCADE
);
