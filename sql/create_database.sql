--
-- PostgreSQL database dump
--

-- Dumped from database version 9.1.6
-- Dumped by pg_dump version 9.2.2
-- Started on 2012-12-26 15:15:41 GMT

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 1919 (class 1262 OID 24617)
-- Name: pyppm; Type: DATABASE; Schema: -; Owner: pyppm
--

CREATE DATABASE "pyppm" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_GB.UTF-8' LC_CTYPE = 'en_GB.UTF-8';


ALTER DATABASE "pyppm" OWNER TO "pyppm";

\connect "pyppm"

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 1920 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA "public"; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA "public" IS 'standard public schema';


--
-- TOC entry 173 (class 3079 OID 11645)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "plpgsql" WITH SCHEMA "pg_catalog";


--
-- TOC entry 1922 (class 0 OID 0)
-- Dependencies: 173
-- Name: EXTENSION "plpgsql"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "plpgsql" IS 'PL/pgSQL procedural language';


SET search_path = "public", pg_catalog;

--
-- TOC entry 497 (class 1247 OID 24619)
-- Name: comparator; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "comparator" AS ENUM (
    'lt',
    'eq',
    'gt'
);


ALTER TYPE "public"."comparator" OWNER TO "postgres";

--
-- TOC entry 500 (class 1247 OID 24627)
-- Name: unitandrelaystates; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "unitandrelaystates" AS (
	"identifier" character(16),
	"relaystate" integer
);


ALTER TYPE "public"."unitandrelaystates" OWNER TO "postgres";

--
-- TOC entry 185 (class 1255 OID 24628)
-- Name: AddReading(character, character, integer, integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "AddReading"("unitname" character, "unitidentifier" character, "relaycount" integer, "relaystate" integer, "sensortypeid" integer, "reading" numeric) RETURNS integer
    LANGUAGE "plpgsql"
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
  PERFORM "UpdateRelaysForReading"(_sensor_id, reading);

  RETURN 42;
END
$$;


ALTER FUNCTION "public"."AddReading"("unitname" character, "unitidentifier" character, "relaycount" integer, "relaystate" integer, "sensortypeid" integer, "reading" numeric) OWNER TO "pyppm";

--
-- TOC entry 186 (class 1255 OID 24629)
-- Name: GetRelayStates(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "GetRelayStates"() RETURNS SETOF "unitandrelaystates"
    LANGUAGE "sql"
    AS $$
  SELECT u.identifier AS identifier, SUM(r.state::int * 16 * (2 ^ r.position))::int as relaystate
  FROM relays r

  INNER JOIN units u
  ON r.unit_id = u.id

  GROUP BY u.identifier;
$$;


ALTER FUNCTION "public"."GetRelayStates"() OWNER TO "postgres";

--
-- TOC entry 187 (class 1255 OID 24630)
-- Name: UpdateRelaysForReading(integer, numeric); Type: FUNCTION; Schema: public; Owner: pyppm
--

CREATE FUNCTION "UpdateRelaysForReading"("sensorid" integer, "reading" numeric) RETURNS "void"
    LANGUAGE "sql"
    AS $_$
UPDATE relays 
SET state = 1::bit, last_modified_at = current_timestamp 
WHERE state = 0::bit AND id IN (
SELECT relay_id
FROM alarms a
INNER JOIN sensors s
ON s.id = a.sensor_id
WHERE s.id = $1
AND (a.triggertype = 'gt' AND $2 > a.triggerlevel)
OR  (a.triggertype = 'eq' AND $2 = a.triggerlevel)
OR  (a.triggertype = 'lt' AND $2 < a.triggerlevel));

UPDATE relays 
SET state = 0::bit, last_modified_at = current_timestamp 
WHERE state = 1::bit AND id IN (
SELECT relay_id
FROM alarms a
INNER JOIN sensors s
ON s.id = a.sensor_id
WHERE s.id = $1
AND (a.triggertype = 'gt' AND $2 <  a.triggerlevel)
OR  (a.triggertype = 'eq' AND $2 != a.triggerlevel)
OR  (a.triggertype = 'lt' AND $2 >  a.triggerlevel));
$_$;


ALTER FUNCTION "public"."UpdateRelaysForReading"("sensorid" integer, "reading" numeric) OWNER TO "pyppm";

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 162 (class 1259 OID 24631)
-- Name: alarms; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE "alarms" (
    "alarmtype_id" integer NOT NULL,
    "sensor_id" integer NOT NULL,
    "triggerlevel" numeric NOT NULL,
    "triggertype" "comparator" NOT NULL,
    "relay_id" integer,
    "created_at" timestamp with time zone,
    "last_modified_at" timestamp with time zone
);


ALTER TABLE "public"."alarms" OWNER TO "pyppm";

--
-- TOC entry 163 (class 1259 OID 24637)
-- Name: alarmtypes; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE "alarmtypes" (
    "id" integer NOT NULL,
    "title" character varying(255) NOT NULL
);


ALTER TABLE "public"."alarmtypes" OWNER TO "pyppm";

--
-- TOC entry 164 (class 1259 OID 24640)
-- Name: alarmtypes_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE "alarmtypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."alarmtypes_id_seq" OWNER TO "pyppm";

--
-- TOC entry 1923 (class 0 OID 0)
-- Dependencies: 164
-- Name: alarmtypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE "alarmtypes_id_seq" OWNED BY "alarmtypes"."id";


--
-- TOC entry 165 (class 1259 OID 24642)
-- Name: readings; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE "readings" (
    "id" integer NOT NULL,
    "sensor_id" integer NOT NULL,
    "reading" numeric NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "last_modified_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."readings" OWNER TO "pyppm";

--
-- TOC entry 166 (class 1259 OID 24648)
-- Name: readings_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE "readings_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."readings_id_seq" OWNER TO "pyppm";

--
-- TOC entry 1924 (class 0 OID 0)
-- Dependencies: 166
-- Name: readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE "readings_id_seq" OWNED BY "readings"."id";


--
-- TOC entry 167 (class 1259 OID 24650)
-- Name: relays; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE "relays" (
    "id" integer NOT NULL,
    "unit_id" integer NOT NULL,
    "position" smallint NOT NULL,
    "state" bit(1) NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "last_modified_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."relays" OWNER TO "pyppm";

--
-- TOC entry 168 (class 1259 OID 24653)
-- Name: relays_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE "relays_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."relays_id_seq" OWNER TO "pyppm";

--
-- TOC entry 1925 (class 0 OID 0)
-- Dependencies: 168
-- Name: relays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE "relays_id_seq" OWNED BY "relays"."id";


--
-- TOC entry 169 (class 1259 OID 24655)
-- Name: sensors; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE "sensors" (
    "id" integer NOT NULL,
    "unit_id" integer NOT NULL,
    "type_id" integer NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "last_modified_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."sensors" OWNER TO "pyppm";

--
-- TOC entry 1926 (class 0 OID 0)
-- Dependencies: 169
-- Name: COLUMN "sensors"."type_id"; Type: COMMENT; Schema: public; Owner: pyppm
--

COMMENT ON COLUMN "sensors"."type_id" IS 'This will be a foreign key once the unit types table is written.';


--
-- TOC entry 170 (class 1259 OID 24658)
-- Name: sensors_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE "sensors_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."sensors_id_seq" OWNER TO "pyppm";

--
-- TOC entry 1927 (class 0 OID 0)
-- Dependencies: 170
-- Name: sensors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE "sensors_id_seq" OWNED BY "sensors"."id";


--
-- TOC entry 171 (class 1259 OID 24660)
-- Name: units; Type: TABLE; Schema: public; Owner: pyppm; Tablespace: 
--

CREATE TABLE "units" (
    "id" integer NOT NULL,
    "name" character(10) NOT NULL,
    "identifier" character(16) NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "last_modified_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."units" OWNER TO "pyppm";

--
-- TOC entry 172 (class 1259 OID 24663)
-- Name: units_id_seq; Type: SEQUENCE; Schema: public; Owner: pyppm
--

CREATE SEQUENCE "units_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."units_id_seq" OWNER TO "pyppm";

--
-- TOC entry 1928 (class 0 OID 0)
-- Dependencies: 172
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pyppm
--

ALTER SEQUENCE "units_id_seq" OWNED BY "units"."id";


--
-- TOC entry 1892 (class 2604 OID 24665)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "alarmtypes" ALTER COLUMN "id" SET DEFAULT "nextval"('"alarmtypes_id_seq"'::"regclass");


--
-- TOC entry 1893 (class 2604 OID 24666)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "readings" ALTER COLUMN "id" SET DEFAULT "nextval"('"readings_id_seq"'::"regclass");


--
-- TOC entry 1894 (class 2604 OID 24667)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "relays" ALTER COLUMN "id" SET DEFAULT "nextval"('"relays_id_seq"'::"regclass");


--
-- TOC entry 1895 (class 2604 OID 24668)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "sensors" ALTER COLUMN "id" SET DEFAULT "nextval"('"sensors_id_seq"'::"regclass");


--
-- TOC entry 1896 (class 2604 OID 24669)
-- Name: id; Type: DEFAULT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "units" ALTER COLUMN "id" SET DEFAULT "nextval"('"units_id_seq"'::"regclass");


--
-- TOC entry 1898 (class 2606 OID 24671)
-- Name: pk_alarms; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY "alarms"
    ADD CONSTRAINT "pk_alarms" PRIMARY KEY ("alarmtype_id", "sensor_id");


--
-- TOC entry 1900 (class 2606 OID 24673)
-- Name: pk_alarmtypes; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY "alarmtypes"
    ADD CONSTRAINT "pk_alarmtypes" PRIMARY KEY ("id");


--
-- TOC entry 1902 (class 2606 OID 24675)
-- Name: pk_readings; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY "readings"
    ADD CONSTRAINT "pk_readings" PRIMARY KEY ("id");


--
-- TOC entry 1904 (class 2606 OID 24677)
-- Name: pk_relays; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY "relays"
    ADD CONSTRAINT "pk_relays" PRIMARY KEY ("id");


--
-- TOC entry 1906 (class 2606 OID 24679)
-- Name: pk_sensors; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY "sensors"
    ADD CONSTRAINT "pk_sensors" PRIMARY KEY ("id");


--
-- TOC entry 1908 (class 2606 OID 24681)
-- Name: pk_units; Type: CONSTRAINT; Schema: public; Owner: pyppm; Tablespace: 
--

ALTER TABLE ONLY "units"
    ADD CONSTRAINT "pk_units" PRIMARY KEY ("id");


--
-- TOC entry 1909 (class 2606 OID 24682)
-- Name: fk_alarms_alarmtype; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "alarms"
    ADD CONSTRAINT "fk_alarms_alarmtype" FOREIGN KEY ("alarmtype_id") REFERENCES "alarmtypes"("id");


--
-- TOC entry 1910 (class 2606 OID 24687)
-- Name: fk_alarms_relay; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "alarms"
    ADD CONSTRAINT "fk_alarms_relay" FOREIGN KEY ("relay_id") REFERENCES "relays"("id");


--
-- TOC entry 1911 (class 2606 OID 24692)
-- Name: fk_alarms_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "alarms"
    ADD CONSTRAINT "fk_alarms_sensor" FOREIGN KEY ("sensor_id") REFERENCES "sensors"("id");


--
-- TOC entry 1913 (class 2606 OID 24697)
-- Name: fk_relays_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "relays"
    ADD CONSTRAINT "fk_relays_unit" FOREIGN KEY ("unit_id") REFERENCES "units"("id");


--
-- TOC entry 1912 (class 2606 OID 24702)
-- Name: fk_sensor; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "readings"
    ADD CONSTRAINT "fk_sensor" FOREIGN KEY ("sensor_id") REFERENCES "sensors"("id");


--
-- TOC entry 1914 (class 2606 OID 24707)
-- Name: fk_unit; Type: FK CONSTRAINT; Schema: public; Owner: pyppm
--

ALTER TABLE ONLY "sensors"
    ADD CONSTRAINT "fk_unit" FOREIGN KEY ("unit_id") REFERENCES "units"("id");


--
-- TOC entry 1921 (class 0 OID 0)
-- Dependencies: 6
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA "public" FROM PUBLIC;
REVOKE ALL ON SCHEMA "public" FROM "postgres";
GRANT ALL ON SCHEMA "public" TO "postgres";
GRANT ALL ON SCHEMA "public" TO "pyppm";
GRANT ALL ON SCHEMA "public" TO PUBLIC;


-- Completed on 2012-12-26 15:15:45 GMT

--
-- PostgreSQL database dump complete
--

