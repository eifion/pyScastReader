--
-- PostgreSQL database dump
--

-- Dumped from database version 9.2.2
-- Dumped by pg_dump version 9.2.2
-- Started on 2013-01-20 12:30:28 GMT

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 2048 (class 1262 OID 17420)
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
-- TOC entry 183 (class 3079 OID 11769)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2051 (class 0 OID 0)
-- Dependencies: 183
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 530 (class 1247 OID 17422)
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
-- TOC entry 569 (class 1247 OID 17656)
-- Name: timedreadings; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE timedreadings AS (
	reading numeric,
	reading_time timestamp with time zone
);


ALTER TYPE public.timedreadings OWNER TO postgres;

--
-- TOC entry 533 (class 1247 OID 17438)
-- Name: unitandrelaystates; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE unitandrelaystates AS (
	identifier character(16),
	relaystate integer
);


ALTER TYPE public.unitandrelaystates OWNER TO postgres;

--
-- TOC entry 199 (class 1255 OID 17439)
-- Name: AddReading(character, character, integer, integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "AddReading"(unitname character, unitidentifier character, relaycount integer, relaystate integer, sensortypeid integer, reading numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
    _id             integer;
    _unit_id        integer;
    _sensor_id      integer;
    _current_time   timestamp with time zone;
    _current_minute timestamp with time zone;
    _new_average    numeric;
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
  _current_minute = date_trunc('minute', _current_time);
  _new_average = AVG(readings_for_minute) FROM (
    SELECT UNNEST(readings || reading) readings_for_minute
    FROM readings
    WHERE reading_time = _current_minute
    AND sensor_id = _sensor_id
  ) r;

  UPDATE readings 
  SET readings = readings || reading,
      average_reading = _new_average,
      last_modified_at = _current_time
  WHERE reading_time = _current_minute
  AND sensor_id = _sensor_id
  RETURNING id into _id;

  IF _id IS NULL THEN
    INSERT INTO readings(sensor_id, readings, average_reading, reading_time, created_at, last_modified_at)
    VALUES(_sensor_id, ARRAY[reading], reading, _current_minute, _current_time, _current_time)
    RETURNING id INTO _id;
  END IF;
  
  PERFORM "UpdateRelaysForReading"(_sensor_id, reading);

  RETURN _id;
END
$$;


ALTER FUNCTION public."AddReading"(unitname character, unitidentifier character, relaycount integer, relaystate integer, sensortypeid integer, reading numeric) OWNER TO pyppm;

--
-- TOC entry 198 (class 1255 OID 17657)
-- Name: GetReadingsForSensor(integer, integer); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "GetReadingsForSensor"(sensorid integer, intervalhours integer) RETURNS SETOF timedreadings
    LANGUAGE plpgsql
    AS $$
BEGIN
 RETURN query 
  SELECT average_reading, reading_time 
  FROM readings 
  WHERE sensor_id = sensorid
  AND reading_time >= current_timestamp - intervalhours * INTERVAL '1 hour'
  ORDER BY reading_time;
END
$$;


ALTER FUNCTION public."GetReadingsForSensor"(sensorid integer, intervalhours integer) OWNER TO pyppm;

--
-- TOC entry 196 (class 1255 OID 17442)
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
-- TOC entry 197 (class 1255 OID 17443)
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
-- TOC entry 169 (class 1259 OID 17444)
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
-- TOC entry 170 (class 1259 OID 17450)
-- Name: alarmtypes; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE alarmtypes (
    id integer NOT NULL,
    title character varying(255) NOT NULL
);


ALTER TABLE public.alarmtypes OWNER TO pyppm;

--
-- TOC entry 171 (class 1259 OID 17453)
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
-- TOC entry 2052 (class 0 OID 0)
-- Dependencies: 171
-- Name: alarmtypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE alarmtypes_id_seq OWNED BY alarmtypes.id;


--
-- TOC entry 181 (class 1259 OID 17609)
-- Name: readings; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE readings (
    id integer NOT NULL,
    sensor_id integer NOT NULL,
    readings numeric[] NOT NULL,
    average_reading numeric NOT NULL,
    reading_time timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_modified_at timestamp with time zone NOT NULL
);


ALTER TABLE public.readings OWNER TO pyppm;

--
-- TOC entry 180 (class 1259 OID 17607)
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
-- TOC entry 2053 (class 0 OID 0)
-- Dependencies: 180
-- Name: readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE readings_id_seq OWNED BY readings.id;


--
-- TOC entry 172 (class 1259 OID 17463)
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
-- TOC entry 173 (class 1259 OID 17466)
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
-- TOC entry 2054 (class 0 OID 0)
-- Dependencies: 173
-- Name: relays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE relays_id_seq OWNED BY relays.id;


--
-- TOC entry 174 (class 1259 OID 17468)
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
-- TOC entry 2055 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN sensors.type_id; Type: COMMENT; Schema: public; Owner: pyppm
--

COMMENT ON COLUMN sensors.type_id IS 'This will be a foreign key once the unit types table is written.';


--
-- TOC entry 175 (class 1259 OID 17471)
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
-- TOC entry 2056 (class 0 OID 0)
-- Dependencies: 175
-- Name: sensors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE sensors_id_seq OWNED BY sensors.id;


--
-- TOC entry 176 (class 1259 OID 17473)
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
-- TOC entry 177 (class 1259 OID 17481)
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
-- TOC entry 2057 (class 0 OID 0)
-- Dependencies: 177
-- Name: TABLE sensortypes_defaultalarmthresholds; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensortypes_defaultalarmthresholds IS 'This table holds the default alarm thresholds for each alarm type. These are copied to the alarms table for a sensor type when a sensor of that type appears and is added to the alarms table. ';


--
-- TOC entry 178 (class 1259 OID 17487)
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
-- TOC entry 179 (class 1259 OID 17490)
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
-- TOC entry 2058 (class 0 OID 0)
-- Dependencies: 179
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE units_id_seq OWNED BY units.id;


--
-- TOC entry 2011 (class 2604 OID 17492)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarmtypes ALTER COLUMN id SET DEFAULT nextval('alarmtypes_id_seq'::regclass);


--
-- TOC entry 2017 (class 2604 OID 17612)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY readings ALTER COLUMN id SET DEFAULT nextval('readings_id_seq'::regclass);


--
-- TOC entry 2012 (class 2604 OID 17494)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY relays ALTER COLUMN id SET DEFAULT nextval('relays_id_seq'::regclass);


--
-- TOC entry 2013 (class 2604 OID 17495)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors ALTER COLUMN id SET DEFAULT nextval('sensors_id_seq'::regclass);


--
-- TOC entry 2016 (class 2604 OID 17496)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY units ALTER COLUMN id SET DEFAULT nextval('units_id_seq'::regclass);


--
-- TOC entry 2019 (class 2606 OID 17498)
-- Name: pk_alarms; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT pk_alarms PRIMARY KEY (alarmtype_id, sensor_id);


--
-- TOC entry 2021 (class 2606 OID 17500)
-- Name: pk_alarmtypes; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY alarmtypes
    ADD CONSTRAINT pk_alarmtypes PRIMARY KEY (id);


--
-- TOC entry 2034 (class 2606 OID 17617)
-- Name: pk_readings; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY readings
    ADD CONSTRAINT pk_readings PRIMARY KEY (id);


--
-- TOC entry 2023 (class 2606 OID 17504)
-- Name: pk_relays; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT pk_relays PRIMARY KEY (id);


--
-- TOC entry 2026 (class 2606 OID 17506)
-- Name: pk_sensors; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT pk_sensors PRIMARY KEY (id);


--
-- TOC entry 2028 (class 2606 OID 17508)
-- Name: pk_sensortypes; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY sensortypes
    ADD CONSTRAINT pk_sensortypes PRIMARY KEY (sensortypeid);


--
-- TOC entry 2030 (class 2606 OID 17510)
-- Name: pk_sensortypes_defaultalarmthresholds; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensortypes_defaultalarmthresholds
    ADD CONSTRAINT pk_sensortypes_defaultalarmthresholds PRIMARY KEY (alarmtype_id, sensortype_id);


--
-- TOC entry 2032 (class 2606 OID 17512)
-- Name: pk_units; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY units
    ADD CONSTRAINT pk_units PRIMARY KEY (id);


--
-- TOC entry 2024 (class 1259 OID 17513)
-- Name: fki_pk_sensor_sensortypes; Type: INDEX; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE INDEX fki_pk_sensor_sensortypes ON sensors USING btree (type_id);


--
-- TOC entry 2035 (class 2606 OID 17515)
-- Name: fk_alarms_alarmtype; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT fk_alarms_alarmtype FOREIGN KEY (alarmtype_id) REFERENCES alarmtypes(id);


--
-- TOC entry 2036 (class 2606 OID 17520)
-- Name: fk_alarms_relay; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT fk_alarms_relay FOREIGN KEY (relay_id) REFERENCES relays(id);


--
-- TOC entry 2037 (class 2606 OID 17525)
-- Name: fk_alarms_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY alarms
    ADD CONSTRAINT fk_alarms_sensor FOREIGN KEY (sensor_id) REFERENCES sensors(id);


--
-- TOC entry 2043 (class 2606 OID 17618)
-- Name: fk_readings_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY readings
    ADD CONSTRAINT fk_readings_sensor FOREIGN KEY (sensor_id) REFERENCES sensors(id);


--
-- TOC entry 2038 (class 2606 OID 17530)
-- Name: fk_relays_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT fk_relays_unit FOREIGN KEY (unit_id) REFERENCES units(id);


--
-- TOC entry 2041 (class 2606 OID 17540)
-- Name: fk_sensortypes_defaultalarmthresholds_alarmtypes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensortypes_defaultalarmthresholds
    ADD CONSTRAINT fk_sensortypes_defaultalarmthresholds_alarmtypes FOREIGN KEY (alarmtype_id) REFERENCES alarmtypes(id);


--
-- TOC entry 2042 (class 2606 OID 17545)
-- Name: fk_sensortypes_defaultalarmthresholds_sensortypes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensortypes_defaultalarmthresholds
    ADD CONSTRAINT fk_sensortypes_defaultalarmthresholds_sensortypes FOREIGN KEY (sensortype_id) REFERENCES sensortypes(sensortypeid);


--
-- TOC entry 2039 (class 2606 OID 17550)
-- Name: fk_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT fk_unit FOREIGN KEY (unit_id) REFERENCES units(id);


--
-- TOC entry 2040 (class 2606 OID 17555)
-- Name: pk_sensor_sensortypes; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT pk_sensor_sensortypes FOREIGN KEY (type_id) REFERENCES sensortypes(sensortypeid);


--
-- TOC entry 2050 (class 0 OID 0)
-- Dependencies: 6
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO pyppm;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2013-01-20 12:30:28 GMT

--
-- PostgreSQL database dump complete
--

