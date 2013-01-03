--
-- PostgreSQL database dump
--

-- Dumped from database version 9.1.6
-- Dumped by pg_dump version 9.2.2
-- Started on 2013-01-03 17:24:13 GMT

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 1946 (class 1262 OID 24617)
-- Name: pyppm; Type: DATABASE; Schema: -; Owner: pyppm
--

CREATE DATABASE pyppm WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_GB.UTF-8' LC_CTYPE = 'en_GB.UTF-8';


ALTER DATABASE pyppm OWNER TO pyppm;

\connect pyppm

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 176 (class 3079 OID 11645)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 1949 (class 0 OID 0)
-- Dependencies: 176
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 502 (class 1247 OID 24619)
-- Name: comparator; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE comparator AS ENUM (
    'lt',
    'lte',
    'eq',
    'gt',
    'gte'
);


ALTER TYPE public.comparator OWNER TO postgres;

--
-- TOC entry 533 (class 1247 OID 24744)
-- Name: timedreadings; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE timedreadings AS (
	reading numeric,
	reading_time timestamp without time zone
);


ALTER TYPE public.timedreadings OWNER TO postgres;

--
-- TOC entry 505 (class 1247 OID 24627)
-- Name: unitandrelaystates; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE unitandrelaystates AS (
	identifier character(16),
	relaystate integer
);


ALTER TYPE public.unitandrelaystates OWNER TO postgres;

--
-- TOC entry 192 (class 1255 OID 24628)
-- Name: AddReading(character, character, integer, integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "AddReading"(unitname character, unitidentifier character, relaycount integer, relaystate integer, sensortypeid integer, reading numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
  _unit_id   integer;
  _sensor_id integer;
  _current_time timestamp with time zone;
  _sensortype_defaultalarmthreshold sensortypes_defaultalarmthresholds%ROWTYPE;
BEGIN
  -- Insert or update unit.
  _current_time := current_timestamp; -- So that all times are the same.
  _unit_id := id 
  FROM units
  WHERE "name" = unitname AND "identifier" = unitidentifier;

  IF _unit_id IS NULL THEN
    INSERT INTO Units("name", "identifier", "created_at", "last_modified_at")
    VALUES(unitname, unitidentifier, _current_time, _current_time)
    RETURNING id INTO _unit_id;

    IF relaycount > 0 THEN
      INSERT INTO relays("unit_id", "position", "state", "created_at", "last_modified_at")
      VALUES(_unit_id, 1, SIGN(relaystate & 32)::int::bit, _current_time, _current_time);
    END IF;

    IF relaycount > 1 THEN
      INSERT INTO relays("unit_id", "position", "state", "created_at", "last_modified_at")
      VALUES(_unit_id, 2, SIGN(relaystate & 64)::int::bit, _current_time, _current_time);
    END IF;

    IF relayCount > 2 THEN
      INSERT INTO relays("unit_id", "position", "state", "created_at", "last_modified_at")
      VALUES(_unit_id, 3, SIGN(relaystate & 128)::int::bit, _current_time, _current_time);
    END IF;
  ELSE
    UPDATE units
    SET last_modified_at = _current_time
    WHERE id = _unit_id;
  END IF;

  -- Insert or update sensor
  _sensor_id := id
  FROM sensors
  WHERE type_id = sensortypeid
  AND unit_id = _unit_id;

  IF _sensor_id IS NULL THEN
    INSERT INTO sensors(unit_id, type_id, created_at, last_modified_at)
    VALUES(_unit_id, sensortypeid, _current_time, _current_time)
    RETURNING id INTO _sensor_id;

    -- Loop through each alarm type and add an alarm.
    FOR _sensortype_defaultalarmthreshold IN SELECT * FROM sensortypes_defaultalarmthresholds WHERE sensortype_id = sensortypeid LOOP
	INSERT INTO alarms(alarmtype_id, sensor_id, threshold, thresholdtype, relay_id, created_at, last_modified_at)
	VALUES(_sensortype_defaultalarmthreshold.alarmtype_id, _sensor_id, _sensortype_defaultalarmthreshold.threshold, _sensortype_defaultalarmthreshold.thresholdtype, NULL, current_timestamp, current_timestamp);
    END LOOP;    
  ELSE
    UPDATE sensors 
    SET last_modified_at = _current_time
    WHERE unit_id = _unit_id AND type_id = sensortypeid;
  END IF;

  -- Insert Reading
  INSERT INTO readings(sensor_id, reading, created_at, last_modified_at)
  VALUES(_sensor_id, reading, _current_time, _current_time);
  PERFORM "UpdateRelaysForReading"(_sensor_id, reading);

  RETURN 42;
END
$$;


ALTER FUNCTION public."AddReading"(unitname character, unitidentifier character, relaycount integer, relaystate integer, sensortypeid integer, reading numeric) OWNER TO pyppm;

--
-- TOC entry 189 (class 1255 OID 24748)
-- Name: GetReadingsForSensor(integer, character); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "GetReadingsForSensor"(sensorid integer, readinginterval character) RETURNS SETOF timedreadings
    LANGUAGE plpgsql
    AS $$
BEGIN
 SELECT AVG(reading) AS reading, date_trunc('minute', created_at AT TIME ZONE 'UTC') AS reading_time 
  FROM readings 
  WHERE sensor_id = sensorid
  AND date_trunc('minute', created_at AT TIME ZONE 'UTC') >= current_timestamp AT TIME ZONE 'UTC' - "INTERVAL"(readinginterval)
  GROUP BY reading_time
  ORDER BY reading_time;
END
$$;


ALTER FUNCTION public."GetReadingsForSensor"(sensorid integer, readinginterval character) OWNER TO pyppm;

--
-- TOC entry 190 (class 1255 OID 24750)
-- Name: GetReadingsForSensor(integer, integer); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "GetReadingsForSensor"(sensorid integer, intervalhours integer) RETURNS SETOF timedreadings
    LANGUAGE plpgsql
    AS $$
BEGIN
 RETURN query SELECT AVG(reading) AS reading, date_trunc('minute', created_at AT TIME ZONE 'UTC') AS reading_time 
  FROM readings 
  WHERE sensor_id = sensorid
  AND date_trunc('minute', created_at AT TIME ZONE 'UTC') >= current_timestamp AT TIME ZONE 'UTC' - intervalhours * INTERVAL '1 hour'
  GROUP BY reading_time
  ORDER BY reading_time;
END
$$;


ALTER FUNCTION public."GetReadingsForSensor"(sensorid integer, intervalhours integer) OWNER TO pyppm;

--
-- TOC entry 188 (class 1255 OID 24629)
-- Name: GetRelayStates(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "GetRelayStates"() RETURNS SETOF unitandrelaystates
    LANGUAGE sql
    AS $$
  SELECT u.identifier AS identifier, SUM(r.state::int * 16 * (2 ^ r.position))::int as relaystate
  FROM relays r

  INNER JOIN units u
  ON r.unit_id = u.id

  GROUP BY u.identifier;
$$;


ALTER FUNCTION public."GetRelayStates"() OWNER TO postgres;

--
-- TOC entry 191 (class 1255 OID 24630)
-- Name: UpdateRelaysForReading(integer, numeric); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "UpdateRelaysForReading"(sensorid integer, reading numeric) RETURNS void
    LANGUAGE sql
    AS $_$
UPDATE relays 
SET state = 1::bit, last_modified_at = current_timestamp 
WHERE state = 0::bit AND id IN (
SELECT relay_id
FROM alarms a
INNER JOIN sensors s
ON s.id = a.sensor_id
WHERE s.id = $1
AND (a.thresholdtype = 'gt' AND $2 > a.threshold)
OR  (a.thresholdtype = 'eq' AND $2 = a.threshold)
OR  (a.thresholdtype = 'lt' AND $2 < a.threshold));

UPDATE relays 
SET state = 0::bit, last_modified_at = current_timestamp 
WHERE state = 1::bit AND id IN (
SELECT relay_id
FROM alarms a
INNER JOIN sensors s
ON s.id = a.sensor_id
WHERE s.id = $1
AND (a.thresholdtype = 'gt' AND $2 <  a.threshold)
OR  (a.thresholdtype = 'eq' AND $2 != a.threshold)
OR  (a.thresholdtype = 'lt' AND $2 >  a.threshold));
$_$;


ALTER FUNCTION public."UpdateRelaysForReading"(sensorid integer, reading numeric) OWNER TO pyppm;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 162 (class 1259 OID 24631)
-- Name: alarms; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE alarms (
    alarmtype_id integer NOT NULL,
    sensor_id integer NOT NULL,
    threshold numeric NOT NULL,
    thresholdtype comparator NOT NULL,
    relay_id integer,
    created_at timestamp with time zone,
    last_modified_at timestamp with time zone
);


ALTER TABLE public.alarms OWNER TO pyppm;

--
-- TOC entry 163 (class 1259 OID 24637)
-- Name: alarmtypes; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE alarmtypes (
    id integer NOT NULL,
    title character varying(255) NOT NULL
);


ALTER TABLE public.alarmtypes OWNER TO pyppm;

--
-- TOC entry 164 (class 1259 OID 24640)
-- Name: alarmtypes_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE alarmtypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alarmtypes_id_seq OWNER TO pyppm;

--
-- TOC entry 1950 (class 0 OID 0)
-- Dependencies: 164
-- Name: alarmtypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE alarmtypes_id_seq OWNED BY alarmtypes.id;


--
-- TOC entry 165 (class 1259 OID 24642)
-- Name: readings; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE readings (
    id integer NOT NULL,
    sensor_id integer NOT NULL,
    reading numeric NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_modified_at timestamp with time zone NOT NULL
);


ALTER TABLE public.readings OWNER TO pyppm;

--
-- TOC entry 166 (class 1259 OID 24648)
-- Name: readings_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE readings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.readings_id_seq OWNER TO pyppm;

--
-- TOC entry 1951 (class 0 OID 0)
-- Dependencies: 166
-- Name: readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE readings_id_seq OWNED BY readings.id;


--
-- TOC entry 167 (class 1259 OID 24650)
-- Name: relays; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE relays (
    id integer NOT NULL,
    unit_id integer NOT NULL,
    "position" smallint NOT NULL,
    state bit(1) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_modified_at timestamp with time zone NOT NULL
);


ALTER TABLE public.relays OWNER TO pyppm;

--
-- TOC entry 168 (class 1259 OID 24653)
-- Name: relays_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE relays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.relays_id_seq OWNER TO pyppm;

--
-- TOC entry 1952 (class 0 OID 0)
-- Dependencies: 168
-- Name: relays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE relays_id_seq OWNED BY relays.id;


--
-- TOC entry 169 (class 1259 OID 24655)
-- Name: sensors; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE sensors (
    id integer NOT NULL,
    unit_id integer NOT NULL,
    type_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_modified_at timestamp with time zone NOT NULL
);


ALTER TABLE public.sensors OWNER TO pyppm;

--
-- TOC entry 1953 (class 0 OID 0)
-- Dependencies: 169
-- Name: COLUMN sensors.type_id; Type: COMMENT; Schema: public; Owner: pyppm
--

COMMENT ON COLUMN sensors.type_id IS 'This will be a foreign key once the unit types table is written.';


--
-- TOC entry 170 (class 1259 OID 24658)
-- Name: sensors_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE sensors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sensors_id_seq OWNER TO pyppm;

--
-- TOC entry 1954 (class 0 OID 0)
-- Dependencies: 170
-- Name: sensors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE sensors_id_seq OWNED BY sensors.id;


--
-- TOC entry 174 (class 1259 OID 24830)
-- Name: sensortypes; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE sensortypes (
    sensortypeid integer NOT NULL,
    resolution numeric NOT NULL,
    minrange integer NOT NULL,
    maxrange integer NOT NULL,
    name character varying(255) NOT NULL,
    shortname character varying(32) NOT NULL,
    measurementunit character varying(16) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_modified_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sensortypes OWNER TO pyppm;

--
-- TOC entry 175 (class 1259 OID 24862)
-- Name: sensortypes_defaultalarmthresholds; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensortypes_defaultalarmthresholds (
    alarmtype_id integer NOT NULL,
    sensortype_id integer NOT NULL,
    thresholdtype comparator NOT NULL,
    threshold numeric
);


ALTER TABLE public.sensortypes_defaultalarmthresholds OWNER TO postgres;

--
-- TOC entry 1955 (class 0 OID 0)
-- Dependencies: 175
-- Name: TABLE sensortypes_defaultalarmthresholds; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensortypes_defaultalarmthresholds IS 'This table holds the default alarm thresholds for each alarm type. These are copied to the alarms table for a sensor type when a sensor of that type appears and is added to the alarms table. ';


--
-- TOC entry 171 (class 1259 OID 24660)
-- Name: units; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE units (
    id integer NOT NULL,
    name character(10) NOT NULL,
    identifier character(16) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_modified_at timestamp with time zone NOT NULL
);


ALTER TABLE public.units OWNER TO pyppm;

--
-- TOC entry 172 (class 1259 OID 24663)
-- Name: units_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.units_id_seq OWNER TO pyppm;

--
-- TOC entry 1956 (class 0 OID 0)
-- Dependencies: 172
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE units_id_seq OWNED BY units.id;


--
-- TOC entry 1908 (class 2604 OID 24665)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarmtypes ALTER COLUMN id SET DEFAULT nextval('alarmtypes_id_seq'::regclass);


--
-- TOC entry 1909 (class 2604 OID 24666)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY readings ALTER COLUMN id SET DEFAULT nextval('readings_id_seq'::regclass);


--
-- TOC entry 1910 (class 2604 OID 24667)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY relays ALTER COLUMN id SET DEFAULT nextval('relays_id_seq'::regclass);


--
-- TOC entry 1911 (class 2604 OID 24668)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors ALTER COLUMN id SET DEFAULT nextval('sensors_id_seq'::regclass);


--
-- TOC entry 1912 (class 2604 OID 24669)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY units ALTER COLUMN id SET DEFAULT nextval('units_id_seq'::regclass);


--
-- TOC entry 1916 (class 2606 OID 24671)
-- Name: pk_alarms; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT pk_alarms PRIMARY KEY (alarmtype_id, sensor_id);


--
-- TOC entry 1918 (class 2606 OID 24673)
-- Name: pk_alarmtypes; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY alarmtypes
    ADD CONSTRAINT pk_alarmtypes PRIMARY KEY (id);


--
-- TOC entry 1920 (class 2606 OID 24675)
-- Name: pk_readings; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY readings
    ADD CONSTRAINT pk_readings PRIMARY KEY (id);


--
-- TOC entry 1923 (class 2606 OID 24677)
-- Name: pk_relays; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT pk_relays PRIMARY KEY (id);


--
-- TOC entry 1926 (class 2606 OID 24679)
-- Name: pk_sensors; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT pk_sensors PRIMARY KEY (id);


--
-- TOC entry 1930 (class 2606 OID 24837)
-- Name: pk_sensortypes; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY sensortypes
    ADD CONSTRAINT pk_sensortypes PRIMARY KEY (sensortypeid);


--
-- TOC entry 1932 (class 2606 OID 24873)
-- Name: pk_sensortypes_defaultalarmthresholds; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensortypes_defaultalarmthresholds
    ADD CONSTRAINT pk_sensortypes_defaultalarmthresholds PRIMARY KEY (alarmtype_id, sensortype_id);


--
-- TOC entry 1928 (class 2606 OID 24681)
-- Name: pk_units; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY units
    ADD CONSTRAINT pk_units PRIMARY KEY (id);


--
-- TOC entry 1924 (class 1259 OID 24843)
-- Name: fki_pk_sensor_sensortypes; Type: INDEX; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE INDEX fki_pk_sensor_sensortypes ON sensors USING btree (type_id);


--
-- TOC entry 1921 (class 1259 OID 24741)
-- Name: readings_minute; Type: INDEX; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE INDEX readings_minute ON readings USING btree (date_trunc('minute'::text, timezone('UTC'::text, created_at)));


--
-- TOC entry 1933 (class 2606 OID 24682)
-- Name: fk_alarms_alarmtype; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT fk_alarms_alarmtype FOREIGN KEY (alarmtype_id) REFERENCES alarmtypes(id);


--
-- TOC entry 1934 (class 2606 OID 24687)
-- Name: fk_alarms_relay; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT fk_alarms_relay FOREIGN KEY (relay_id) REFERENCES relays(id);


--
-- TOC entry 1935 (class 2606 OID 24692)
-- Name: fk_alarms_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT fk_alarms_sensor FOREIGN KEY (sensor_id) REFERENCES sensors(id);


--
-- TOC entry 1937 (class 2606 OID 24697)
-- Name: fk_relays_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT fk_relays_unit FOREIGN KEY (unit_id) REFERENCES units(id);


--
-- TOC entry 1936 (class 2606 OID 24702)
-- Name: fk_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY readings
    ADD CONSTRAINT fk_sensor FOREIGN KEY (sensor_id) REFERENCES sensors(id);


--
-- TOC entry 1941 (class 2606 OID 24879)
-- Name: fk_sensortypes_defaultalarmthresholds_alarmtypes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensortypes_defaultalarmthresholds
    ADD CONSTRAINT fk_sensortypes_defaultalarmthresholds_alarmtypes FOREIGN KEY (alarmtype_id) REFERENCES alarmtypes(id);


--
-- TOC entry 1940 (class 2606 OID 24874)
-- Name: fk_sensortypes_defaultalarmthresholds_sensortypes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensortypes_defaultalarmthresholds
    ADD CONSTRAINT fk_sensortypes_defaultalarmthresholds_sensortypes FOREIGN KEY (sensortype_id) REFERENCES sensortypes(sensortypeid);


--
-- TOC entry 1938 (class 2606 OID 24707)
-- Name: fk_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT fk_unit FOREIGN KEY (unit_id) REFERENCES units(id);


--
-- TOC entry 1939 (class 2606 OID 24838)
-- Name: pk_sensor_sensortypes; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT pk_sensor_sensortypes FOREIGN KEY (type_id) REFERENCES sensortypes(sensortypeid);


--
-- TOC entry 1948 (class 0 OID 0)
-- Dependencies: 6
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO pyppm;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2013-01-03 17:24:18 GMT

--
-- PostgreSQL database dump complete
--

