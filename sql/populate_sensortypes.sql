--
-- PostgreSQL database dump
--

-- Dumped from database version 9.2.2
-- Dumped by pg_dump version 9.2.2
-- Started on 2013-01-20 12:32:04 GMT

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- TOC entry 2011 (class 0 OID 17450)
-- Dependencies: 170
-- Data for Name: alarmtypes; Type: TABLE DATA; Schema: public; Owner: pyppm
--

INSERT INTO alarmtypes (id, title) VALUES (1, 'ceiling');
INSERT INTO alarmtypes (id, title) VALUES (2, 'intermediate');


--
-- TOC entry 2019 (class 0 OID 0)
-- Dependencies: 171
-- Name: alarmtypes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pyppm
--

SELECT pg_catalog.setval('alarmtypes_id_seq', 2, true);


--
-- TOC entry 2013 (class 0 OID 17473)
-- Dependencies: 176
-- Data for Name: sensortypes; Type: TABLE DATA; Schema: public; Owner: pyppm
--

INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (1, 0.1, 0, 100, 'Temperature ˚C', 'Temp ˚C', '˚C', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (3, 0.1, 0, 100, 'Humidity', 'RH', '%RH', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (28, 0.001, 0, 50, 'TVOC', 'TVOC', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (4, 0.001, 0, 10, 'Formaldehyde', 'HCHO', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (20, 0.001, 0, 1, 'Ozone', 'O₃', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (6, 1, 0, 5000, 'Carbon Dioxide', 'CO₂', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (7, 0.001, 0, 100, 'Carbon Monoxide', 'CO', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (18, 0.001, 0, 5, 'Nitrogen Dioxide', 'NO₂', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (26, 0.001, 0, 20, 'TVOC Silver', 'TVOC', 'PPM', '2013-01-03 12:55:08.94304+00', '2013-01-03 12:55:44.988024+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (40, 0.1, 0, 1, 'Smoke', 'Smoke', 'SD', '2013-07-05 17:00:00:00+00', '2013-07-05 17:00:00:00+00');
INSERT INTO sensortypes (sensortypeid, resolution, minrange, maxrange, name, shortname, measurementunit, created_at, last_modified_at) VALUES (42, 0.1, 0, 1, 'PIR Motion', 'PIR', 'Motion', '2013-07-05 17:00:00:00+00', '2013-07-05 17:00:00:00+00');
--
-- TOC entry 2014 (class 0 OID 17481)
-- Dependencies: 177
-- Data for Name: sensortypes_defaultalarmthresholds; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 1, 'gte', 50);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 1, 'gte', 40);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 3, 'gte', 80);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 3, 'gte', 60);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 6, 'gte', 2000);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 6, 'gte', 1600);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 20, 'gte', 0.5);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 20, 'gte', 0.4);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 26, 'gte', 0.5);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 26, 'gte', 0.4);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 28, 'gte', 0.2);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 28, 'gte', 0.3);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 7, 'gte', 2);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 7, 'gte', 1);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 18, 'gte', 0.1);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 18, 'gte', 0.08);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 4, 'gte', 0.2);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 4, 'gte', 0.15);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 40, 'gte', 1);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 40, 'gte', 0.6);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (1, 42, 'gte', 1);
INSERT INTO sensortypes_defaultalarmthresholds (alarmtype_id, sensortype_id, thresholdtype, threshold) VALUES (2, 42, 'gte', 0.6);


-- Completed on 2013-01-20 12:32:04 GMT

--
-- PostgreSQL database dump complete
--

