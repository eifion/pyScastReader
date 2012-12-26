--
-- PostgreSQL database dump
--

-- Dumped from database version 9.2.2
-- Dumped by pg_dump version 9.2.2
-- Started on 2012-12-26 10:31:47 GMT

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 1995 (class 1262 OID 16987)
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
-- TOC entry 176 (class 3079 OID 11769)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 1998 (class 0 OID 0)
-- Dependencies: 176
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 189 (class 1255 OID 17043)
-- Name: AddReading(character, character, integer, integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "AddReading"(unitname character, unitidentifier character, relaycount integer, relaystate integer, sensortypeid integer, reading numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
  _unit_id   integer;
  _sensor_id integer;
  _current_time timestamp with time zone;
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
  ELSE
    UPDATE sensors 
    SET last_modified_at = _current_time
    WHERE unit_id = _unit_id AND type_id = sensortypeid;
  END IF;

  -- Insert Reading
  INSERT INTO readings(sensor_id, reading, created_at, last_modified_at)
  VALUES(_sensor_id, reading, _current_time, _current_time);

  RETURN 42;
END
$$;


ALTER FUNCTION public."AddReading"(unitname character, unitidentifier character, relaycount integer, relaystate integer, sensortypeid integer, reading numeric) OWNER TO pyppm;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 168 (class 1259 OID 16989)
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
-- TOC entry 169 (class 1259 OID 16995)
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
-- TOC entry 1999 (class 0 OID 0)
-- Dependencies: 169
-- Name: readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE readings_id_seq OWNED BY readings.id;


--
-- TOC entry 175 (class 1259 OID 17028)
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
-- TOC entry 174 (class 1259 OID 17026)
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
-- TOC entry 2000 (class 0 OID 0)
-- Dependencies: 174
-- Name: relays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE relays_id_seq OWNED BY relays.id;


--
-- TOC entry 170 (class 1259 OID 16997)
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
-- TOC entry 2001 (class 0 OID 0)
-- Dependencies: 170
-- Name: COLUMN sensors.type_id; Type: COMMENT; Schema: public; Owner: pyppm
--

COMMENT ON COLUMN sensors.type_id IS 'This will be a foreign key once the unit types table is written.';


--
-- TOC entry 171 (class 1259 OID 17000)
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
-- TOC entry 2002 (class 0 OID 0)
-- Dependencies: 171
-- Name: sensors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE sensors_id_seq OWNED BY sensors.id;


--
-- TOC entry 172 (class 1259 OID 17002)
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
-- TOC entry 173 (class 1259 OID 17005)
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
-- TOC entry 2003 (class 0 OID 0)
-- Dependencies: 173
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE units_id_seq OWNED BY units.id;


--
-- TOC entry 1976 (class 2604 OID 17007)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY readings ALTER COLUMN id SET DEFAULT nextval('readings_id_seq'::regclass);


--
-- TOC entry 1979 (class 2604 OID 17031)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY relays ALTER COLUMN id SET DEFAULT nextval('relays_id_seq'::regclass);


--
-- TOC entry 1977 (class 2604 OID 17008)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors ALTER COLUMN id SET DEFAULT nextval('sensors_id_seq'::regclass);


--
-- TOC entry 1978 (class 2604 OID 17009)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY units ALTER COLUMN id SET DEFAULT nextval('units_id_seq'::regclass);


--
-- TOC entry 1981 (class 2606 OID 17011)
-- Name: pk_readings; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY readings
    ADD CONSTRAINT pk_readings PRIMARY KEY (id);


--
-- TOC entry 1987 (class 2606 OID 17033)
-- Name: pk_relays; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT pk_relays PRIMARY KEY (id);


--
-- TOC entry 1983 (class 2606 OID 17013)
-- Name: pk_sensors; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT pk_sensors PRIMARY KEY (id);


--
-- TOC entry 1985 (class 2606 OID 17015)
-- Name: pk_units; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY units
    ADD CONSTRAINT pk_units PRIMARY KEY (id);


--
-- TOC entry 1990 (class 2606 OID 17034)
-- Name: fk_relays_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT fk_relays_unit FOREIGN KEY (unit_id) REFERENCES units(id);


--
-- TOC entry 1988 (class 2606 OID 17016)
-- Name: fk_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY readings
    ADD CONSTRAINT fk_sensor FOREIGN KEY (sensor_id) REFERENCES sensors(id);


--
-- TOC entry 1989 (class 2606 OID 17021)
-- Name: fk_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT fk_unit FOREIGN KEY (unit_id) REFERENCES units(id);


--
-- TOC entry 1997 (class 0 OID 0)
-- Dependencies: 6
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO pyppm;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2012-12-26 10:31:47 GMT

--
-- PostgreSQL database dump complete
--

