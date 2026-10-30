--
-- PostgreSQL database dump
--
-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
-- SET transaction_timeout = 0;  -- Commented out: PostgreSQL 17+ only, not supported in PostgreSQL 15
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: access_control_type_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.access_control_type_enum AS ENUM (
    'public',
    'restricted'
);

--
-- Name: audit_status_type_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.audit_status_type_enum AS ENUM (
    'success',
    'failure'
);

--
-- Name: auth_type_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.auth_type_enum AS ENUM (
    'oauth2',
    'api_key'
);


--
-- Name: owner_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.owner_enum AS ENUM (
    'citizen'
);


--
-- Name: source_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.source_enum AS ENUM (
    'primary',
    'fallback'
);


--
-- Name: status_type_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.status_type_enum AS ENUM (
    'pending',
    'rejected',
    'approved'
);


--
-- Name: version_type_enum; Type: TYPE; Schema: public; Owner: exchange
--

CREATE TYPE public.version_type_enum AS ENUM (
    'active',
    'deprecated'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: application_submissions; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.application_submissions (
                                                submission_id character varying(255) NOT NULL,
                                                previous_application_id text,
                                                application_name text NOT NULL,
                                                application_description text,
                                                status public.status_type_enum NOT NULL,
                                                created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                                updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                                review text,
                                                member_id character varying(255) NOT NULL,
                                                selected_fields jsonb NOT NULL
);


ALTER TABLE public.application_submissions OWNER TO exchange;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.applications (
                                     application_id character varying(255) NOT NULL,
                                     application_name text NOT NULL,
                                     application_description text,
                                     version public.version_type_enum NOT NULL,
                                     created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                     updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                     selected_fields jsonb NOT NULL,
                                     member_id character varying(255) NOT NULL
);


ALTER TABLE public.applications OWNER TO exchange;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.audit_logs (
                                   id uuid DEFAULT gen_random_uuid() NOT NULL,
                                   "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
                                   status public.audit_status_type_enum NOT NULL,
                                   requested_data text NOT NULL,
                                   application_id character varying(255) NOT NULL,
                                   schema_id character varying(255) NOT NULL,
                                   consumer_id character varying(255),
                                   provider_id character varying(255),
                                   CONSTRAINT audit_logs_status_check CHECK (((status)::text = ANY (ARRAY[('success'::character varying)::text, ('failure'::character varying)::text])))
);


ALTER TABLE public.audit_logs OWNER TO exchange;

--
-- Name: TABLE audit_logs; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON TABLE public.audit_logs IS 'Audit logs for tracking data access requests across the system';


--
-- Name: COLUMN audit_logs.id; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN public.audit_logs.id IS 'Unique identifier for the audit log entry';


--
-- Name: COLUMN audit_logs."timestamp"; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN public.audit_logs."timestamp" IS 'When the request was made';


--
-- Name: COLUMN audit_logs.requested_data; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN public.audit_logs.requested_data IS 'The GraphQL query that was requested';


--
-- Name: COLUMN audit_logs.application_id; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN public.audit_logs.application_id IS 'ID of the consumer application making the request';


--
-- Name: COLUMN audit_logs.schema_id; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN public.audit_logs.schema_id IS 'ID of the provider scherma serving the request';


--
-- Name: schemas; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.schemas (
                                schema_id character varying(255) NOT NULL,
                                schema_name text NOT NULL,
                                sdl text NOT NULL,
                                endpoint text NOT NULL,
                                version public.version_type_enum NOT NULL,
                                schema_description text,
                                created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                member_id character varying(255) NOT NULL,
                                auth_type public.auth_type_enum,
                                api_key_name text,
                                api_key_value text,
                                client_id text,
                                client_secret text,
                                token_url text,
                                refresh_token_url text,
                                CONSTRAINT check_name CHECK (((auth_type IS NULL) OR ((auth_type = 'api_key'::public.auth_type_enum) AND (api_key_name IS NOT NULL) AND (api_key_value IS NOT NULL)) OR ((auth_type = 'oauth2'::public.auth_type_enum) AND (client_id IS NOT NULL) AND (client_secret IS NOT NULL) AND (token_url IS NOT NULL))))
);


ALTER TABLE public.schemas OWNER TO exchange;

--
-- Name: audit_logs_with_provider_consumer; Type: VIEW; Schema: public; Owner: exchange
--

CREATE VIEW public.audit_logs_with_provider_consumer AS
SELECT audit_logs.id,
       audit_logs."timestamp",
       audit_logs.status,
       audit_logs.requested_data,
       audit_logs.application_id,
       audit_logs.schema_id,
       applications.member_id AS consumer_id,
       schemas.member_id AS provider_id
FROM ((public.audit_logs
    JOIN public.schemas USING (schema_id))
    JOIN public.applications USING (application_id));


ALTER VIEW public.audit_logs_with_provider_consumer OWNER TO exchange;

--
-- Name: members; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.members (
                                member_id character varying(255) NOT NULL,
                                name text NOT NULL,
                                email text NOT NULL,
                                phone_number text NOT NULL,
                                created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                idp_user_id text NOT NULL
);


ALTER TABLE public.members OWNER TO exchange;

--
-- Name: policy_metadata; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.policy_metadata (
                                        id uuid DEFAULT gen_random_uuid() NOT NULL,
                                        schema_id character varying(255) NOT NULL,
                                        field_name text NOT NULL,
                                        display_name text,
                                        description text,
                                        source public.source_enum DEFAULT 'fallback'::public.source_enum NOT NULL,
                                        is_owner boolean DEFAULT false NOT NULL,
                                        access_control_type public.access_control_type_enum DEFAULT 'restricted'::public.access_control_type_enum NOT NULL,
                                        allow_list jsonb DEFAULT '{}'::jsonb NOT NULL,
                                        created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
                                        updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
                                        owner public.owner_enum,
                                        CONSTRAINT policy_metadata_owner_requirements CHECK ((((is_owner = true) AND (owner IS NULL)) OR ((is_owner = false) AND (owner IS NOT NULL))))
);


ALTER TABLE public.policy_metadata OWNER TO exchange;

--
-- Name: COLUMN policy_metadata.allow_list; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON COLUMN public.policy_metadata.allow_list IS 'HashMap having key:application_id value:Object having two attributes such as expired_at, updated_at';


--
-- Name: CONSTRAINT policy_metadata_owner_requirements ON policy_metadata; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON CONSTRAINT policy_metadata_owner_requirements ON public.policy_metadata IS 'Ensures owner is specified when is_owner is false, and owner is not specified when is_owner is true';


--
-- Name: schema_submissions; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.schema_submissions (
                                           submission_id character varying(255) NOT NULL,
                                           previous_schema_id text,
                                           schema_name text NOT NULL,
                                           schema_description text,
                                           sdl text NOT NULL,
                                           schema_endpoint text NOT NULL,
                                           status public.status_type_enum NOT NULL,
                                           created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                           updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
                                           review text,
                                           member_id character varying(255) NOT NULL
);


ALTER TABLE public.schema_submissions OWNER TO exchange;

--
-- Name: schema_versions; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.schema_versions (
                                        id integer NOT NULL,
                                        from_version character varying(50),
                                        to_version character varying(50) NOT NULL,
                                        change_type character varying(20) NOT NULL,
                                        changes jsonb,
                                        created_at timestamp with time zone DEFAULT now(),
                                        created_by character varying(255) NOT NULL
);


ALTER TABLE public.schema_versions OWNER TO exchange;

--
-- Name: schema_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: exchange
--

CREATE SEQUENCE public.schema_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.schema_versions_id_seq OWNER TO exchange;

--
-- Name: schema_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: exchange
--

ALTER SEQUENCE public.schema_versions_id_seq OWNED BY public.schema_versions.id;


--
-- Name: unified_schemas; Type: TABLE; Schema: public; Owner: exchange
--

CREATE TABLE public.unified_schemas (
                                        id character varying(36) NOT NULL,
                                        version character varying(50) NOT NULL,
                                        sdl text NOT NULL,
                                        status character varying(20) DEFAULT 'inactive'::character varying NOT NULL,
                                        description text,
                                        created_at timestamp with time zone DEFAULT now(),
                                        updated_at timestamp with time zone DEFAULT now(),
                                        created_by character varying(100),
                                        checksum character varying(64) NOT NULL,
                                        is_active boolean DEFAULT false
);


ALTER TABLE public.unified_schemas OWNER TO exchange;

--
-- Name: schema_versions id; Type: DEFAULT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schema_versions ALTER COLUMN id SET DEFAULT nextval('public.schema_versions_id_seq'::regclass);


--
-- Data for Name: application_submissions; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.application_submissions (submission_id, previous_application_id, application_name, application_description, status, created_at, updated_at, review, member_id, selected_fields) FROM stdin;
sub_1a3f54ee-39c8-4c5e-ba11-efa5be29e48f	\N	Test App		pending	2025-10-31 13:01:57.301412+00	2025-10-31 13:23:28.768317+00	\N	mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7	[{"schemaId": "drp-schema-v1", "fieldName": "personInfo.fullName"}, {"schemaId": "dmt-schema-v1", "fieldName": "vehicle.make"}, {"schemaId": "dmt-schema-v1", "fieldName": "vehicle.class.className"}, {"schemaId": "dmt-schema-v1", "fieldName": "vehicle.class.classCode"}]
\.


--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.applications (application_id, application_name, application_description, version, created_at, updated_at, selected_fields, member_id) FROM stdin;
passport-app	Passport Application Web App	\N	active	2025-11-01 12:52:46.808564+00	2025-11-01 12:52:46.808564+00	[{"schemaId": "abc-212", "fieldName": "getPersonInfo.birthDate"}, {"schemaId": "drp-schema-v1", "fieldName": "person.permanentAddress"}, {"schemaId": "drp-schema-v1", "fieldName": "person.fullName"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.name"}, {"schemaId": "drp-schema-v1", "fieldName": "person.otherNames"}, {"schemaId": "drp-schema-v1", "fieldName": "person.profession"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.sex"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.brNo"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.birthPlace"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.district"}]	mem_cc93641c-b357-4b19-bcfd-13c497d710d7
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.audit_logs (id, "timestamp", status, requested_data, application_id, schema_id, consumer_id, provider_id) FROM stdin;
dfcd576f-cf45-40ce-aca1-c5cd02250983	2025-10-21 03:29:02.811146+00	success	query { testQuery }	passport-app	abc-212	\N	\N
295dabf3-22b5-4460-ba00-d42efeb1e811	2025-10-21 03:32:10.137349+00	failure	query { testWithValidIds }	passport-app	abc-212	\N	\N
44e297bf-3166-4f5f-ace2-13cb76106359	2025-10-21 03:33:22.697695+00	success	{"query": "query { testUpdatedMiddleware }"}	passport-app	drp-schema-v1	\N	\N
\.

--
-- Data for Name: members; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.members (member_id, name, email, phone_number, created_at, updated_at, idp_user_id) FROM stdin;
mem_4e3ef278-5850-4bef-9f1b-4e41766999ec	Registrar General's Department	rgd@ndx.fl	+100112234567	2025-10-01 12:23:50.06+00	2025-10-01 12:23:52.879+00	4e3ef278-5850-4bef-9f1b-4e41766999ec
mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7	Department for Registration of Persons	drp@ndx.fl	+100113985890	2025-10-02 16:19:29.138385+00	2025-10-08 09:38:31.592445+00	0e3057ad-b110-4696-bdbf-fab6c5189343
mem_cc93641c-b357-4b19-bcfd-13c497d710d7	Department of Immigration & Emigration	die@ndx.fl	+100113985890	2025-10-07 16:46:52.590874+00	2025-10-22 17:09:10.797397+00	ff0c95f4-233d-449a-97e5-536e15af1847
mem_47578e70-2a1b-417c-b5f0-cb7819c59817	ORG 1	org1@ndx.fl	+100113985890	2025-10-30 06:03:37.499741+00	2025-10-30 06:03:37.499741+00	fadebe20-b5db-4593-adec-99b9518746c0
\.


--
-- Data for Name: policy_metadata; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.policy_metadata (id, schema_id, field_name, display_name, description, source, is_owner, access_control_type, allow_list, created_at, updated_at, owner) FROM stdin;
488e0205-3949-4460-b3d2-5403d2b82ea6	drp-schema-v1	person.permanentAddress	Residing Address	Person's Residential Address	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-28 14:01:48.915218+00	2025-10-28 14:01:48.915218+00	citizen
ae05f09b-432e-4473-8da1-9633c3da9c72	abc-212	getPersonInfo.district	Birth District of Person	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
2cf4f41f-7934-4a49-9a03-9f851f395436	abc-212	getPersonInfo.birthPlace	Birth Place of Person	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
5719f279-ee92-4536-9e0b-5443aa064cf8	abc-212	getPersonInfo.brNo	Birth Registration Number	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
171584a4-36ed-4989-a8cf-da292d908bb6	abc-212	getPersonInfo.birthDate	Birth Date	Person's Birth Date	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-28 14:01:48.915218+00	2025-10-28 14:01:48.915218+00	citizen
8180a601-b67d-400b-8528-012797d9d6d8	abc-212	getPersonInfo.sex	Person's Sex	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
10d4da3e-8d7d-42bb-97ca-30429ef895cd	drp-schema-v1	person.profession	Your Profession	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:10:48.459932+00	2025-10-30 04:10:48.459932+00	citizen
8c07811e-6573-4826-bcb3-8f36a52bb810	drp-schema-v1	person.otherNames	Person's Other Names	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:10:48.459932+00	2025-10-30 04:10:48.459932+00	citizen
96c4cce8-5a0a-42cb-9698-910c4ec45305	abc-212	getPersonInfo.name	Person's Name	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
d45c4b6c-8bbd-4ee8-9acd-0b71015aaeb9	drp-schema-v1	person.fullName	Full Name	Person's Full Name	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-28 14:01:48.915218+00	2025-10-28 14:01:48.915218+00	citizen
\.


--
-- Data for Name: schema_submissions; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.schema_submissions (submission_id, previous_schema_id, schema_name, schema_description, sdl, schema_endpoint, status, created_at, updated_at, review, member_id) FROM stdin;
sub_fe507219-5f41-4485-aedf-407e6827ac7b	\N	Person Information		directive @accessControl(type: String) on FIELD_DEFINITION\n\ndirective @source(value: String) on FIELD_DEFINITION\n\ndirective @isOwner(value: Boolean) on FIELD_DEFINITION\n\ndirective @owner(value: String) on FIELD_DEFINITION\n\ndirective @description(value: String) on FIELD_DEFINITION\n\ntype BirthInfo {\n  birthCertificateID: ID! @accessControl(type: "public") @source(value: "primary") @isOwner(value: true)\n  birthPlace: String! @accessControl(type: "restricted") @source(value: "primary") @isOwner(value: false) @owner(value: "citizen")\n  birthDate: String! @accessControl(type: "restricted") @source(value: "primary") @isOwner(value: false) @owner(value: "citizen")\n}\n\ntype User {\n  id: ID! @accessControl(type: "public") @source(value: "primary") @isOwner(value: true)\n  name: String! @accessControl(type: "public") @source(value: "primary") @isOwner(value: false) @owner(value: "citizen")\n  email: String! @accessControl(type: "restricted") @source(value: "fallback")\n  birthInfo: BirthInfo @description(value: "Default Description")\n}\n\ntype Query {\n  getUser(id: ID!): User @description(value: "Default Description")\n  getBirthInfo(userId: ID!): BirthInfo @description(value: "Default Description")\n}	https://abvdsfkj.jbdavsvjkhb	pending	2025-10-30 16:48:31.746275+00	2025-10-30 16:48:31.746275+00	\N	mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7
\.


--
-- Data for Name: schema_versions; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.schema_versions (id, from_version, to_version, change_type, changes, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: schemas; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.schemas (schema_id, schema_name, sdl, endpoint, version, schema_description, created_at, updated_at, member_id, auth_type, api_key_name, api_key_value, client_id, client_secret, token_url, refresh_token_url) FROM stdin;
abc-212	RGD Schema	"Date (isoformat)"\nscalar Date\n\ntype Father {\n  name: String!\n  nic: String!\n  birthDate: Date!\n  birthPlace: String!\n  race: String!\n}\n\ntype Informant {\n  signature: String!\n  fullName: String!\n  residence: String!\n  relationshipToBaby: String!\n  nic: String!\n}\n\ntype Mother {\n  name: String!\n  nic: String!\n  birthDate: Date!\n  birthPlace: String!\n  race: String!\n  ageAtBirth: Int!\n}\n\ntype PersonData {\n  id: Int!\n  brNo: String!\n  nic: ID!\n  district: String!\n  division: String!\n  birthDate: Date!\n  birthPlace: String!\n  name: String!\n  sex: String!\n  areParentsMarried: Boolean!\n  isGrandfatherBornInSriLanka: Boolean!\n  father: Father!\n  mother: Mother!\n  dateOfRegistration: Date!\n  registrarSignature: String!\n  informant: Informant!\n}\n\ntype Query {\n  "Get person information by NIC"\n  healthCheck: String!\n  "Get person information by NIC"\n  getPersonInfo(nic: ID!): PersonData\n}	http://test.com	active	Test Schema	2025-10-16 02:17:32.4963+00	2025-10-16 02:17:32.4963+00	mem_4e3ef278-5850-4bef-9f1b-4e41766999ec	oauth2	\N	\N	test_client	test_secret	http://host.docker.internal:8080/oauth/token	\N
drp-schema-v1	DRP Schema	scalar ID\nscalar String\nscalar Boolean\n\ntype PersonData {\n  nic: ID!\n  fullName: String!\n  otherNames: String!\n  permanentAddress: String!\n  profession: String!\n  photo: String!\n}\n\ntype Query {\n  person(nic: ID!): PersonData\n}	http://host.docker.internal:9091	active	Test Schema	2025-10-16 02:17:32.4963+00	2025-10-16 02:17:32.4963+00	mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7	api_key	Choreo-API-Key	demo-drp-api-key	\N	\N	\N	\N
\.


--
-- Data for Name: unified_schemas; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.unified_schemas (id, version, sdl, status, description, created_at, updated_at, created_by, checksum, is_active) FROM stdin;
\.


--
-- Name: schema_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: exchange
--

SELECT pg_catalog.setval('public.schema_versions_id_seq', 1, false);


--
-- Name: application_submissions application_submissions_pk; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.application_submissions
    ADD CONSTRAINT application_submissions_pk UNIQUE (application_name, member_id);


--
-- Name: application_submissions application_submissions_pk_2; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.application_submissions
    ADD CONSTRAINT application_submissions_pk_2 PRIMARY KEY (submission_id);


--
-- Name: applications applications_pk; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pk UNIQUE (application_name, member_id);


--
-- Name: applications applications_pk_2; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pk_2 PRIMARY KEY (application_id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: members members_pk; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pk UNIQUE (email);


--
-- Name: members members_pk_2; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pk_2 PRIMARY KEY (member_id);


--
-- Name: members members_pk_3; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pk_3 UNIQUE (idp_user_id);


--
-- Name: policy_metadata policy_metadata_pk; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.policy_metadata
    ADD CONSTRAINT policy_metadata_pk PRIMARY KEY (id);


--
-- Name: policy_metadata policy_metadata_schema_field_unique; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.policy_metadata
    ADD CONSTRAINT policy_metadata_schema_field_unique UNIQUE (schema_id, field_name);


--
-- Name: CONSTRAINT policy_metadata_schema_field_unique ON policy_metadata; Type: COMMENT; Schema: public; Owner: exchange
--

COMMENT ON CONSTRAINT policy_metadata_schema_field_unique ON public.policy_metadata IS 'Ensures unique combination of schema_id and field_name';


--
-- Name: schema_submissions schema_submissions_pk; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schema_submissions
    ADD CONSTRAINT schema_submissions_pk UNIQUE (schema_name, member_id);


--
-- Name: schema_submissions schema_submissions_pk_2; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schema_submissions
    ADD CONSTRAINT schema_submissions_pk_2 PRIMARY KEY (submission_id);


--
-- Name: schema_versions schema_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schema_versions
    ADD CONSTRAINT schema_versions_pkey PRIMARY KEY (id);


--
-- Name: schemas schemas_pk; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schemas
    ADD CONSTRAINT schemas_pk UNIQUE (schema_name, member_id);


--
-- Name: schemas schemas_pk_2; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schemas
    ADD CONSTRAINT schemas_pk_2 PRIMARY KEY (schema_id);


--
-- Name: unified_schemas unified_schemas_pkey; Type: CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.unified_schemas
    ADD CONSTRAINT unified_schemas_pkey PRIMARY KEY (id);


--
-- Name: idx_audit_logs_consumer_id; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_consumer_id ON public.audit_logs USING btree (application_id);


--
-- Name: idx_audit_logs_consumer_provider_timestamp; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_consumer_provider_timestamp ON public.audit_logs USING btree (consumer_id, provider_id, "timestamp" DESC);


--
-- Name: idx_audit_logs_consumer_timestamp; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_consumer_timestamp ON public.audit_logs USING btree (application_id, "timestamp" DESC);


--
-- Name: idx_audit_logs_provider_id; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_provider_id ON public.audit_logs USING btree (schema_id);


--
-- Name: idx_audit_logs_provider_timestamp; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_provider_timestamp ON public.audit_logs USING btree (schema_id, "timestamp" DESC);


--
-- Name: idx_audit_logs_status; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_status ON public.audit_logs USING btree (status);


--
-- Name: idx_audit_logs_timestamp; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_audit_logs_timestamp ON public.audit_logs USING btree ("timestamp");


--
-- Name: idx_policy_metadata_schema_field; Type: INDEX; Schema: public; Owner: exchange
--

CREATE INDEX idx_policy_metadata_schema_field ON public.policy_metadata USING btree (schema_id, field_name);


--
-- Name: application_submissions application_submissions_applications_application_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.application_submissions
    ADD CONSTRAINT application_submissions_applications_application_id_fk FOREIGN KEY (previous_application_id) REFERENCES public.applications(application_id);


--
-- Name: application_submissions application_submissions_members_member_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.application_submissions
    ADD CONSTRAINT application_submissions_members_member_id_fk FOREIGN KEY (member_id) REFERENCES public.members(member_id);


--
-- Name: applications applications_members_member_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_members_member_id_fk FOREIGN KEY (member_id) REFERENCES public.members(member_id);


--
-- Name: audit_logs audit_logs_consumer_applications_application_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_consumer_applications_application_id_fk FOREIGN KEY (application_id) REFERENCES public.applications(application_id);


--
-- Name: audit_logs audit_logs_provider_schemas_schema_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_provider_schemas_schema_id_fk FOREIGN KEY (schema_id) REFERENCES public.schemas(schema_id);


--
-- Name: policy_metadata policy_metadata_provider_schemas_schema_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.policy_metadata
    ADD CONSTRAINT policy_metadata_provider_schemas_schema_id_fk FOREIGN KEY (schema_id) REFERENCES public.schemas(schema_id);


--
-- Name: schema_submissions schema_submissions_members_member_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schema_submissions
    ADD CONSTRAINT schema_submissions_members_member_id_fk FOREIGN KEY (member_id) REFERENCES public.members(member_id);


--
-- Name: schema_submissions schema_submissions_schemas_schema_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schema_submissions
    ADD CONSTRAINT schema_submissions_schemas_schema_id_fk FOREIGN KEY (previous_schema_id) REFERENCES public.schemas(schema_id);


--
-- Name: schemas schemas_members_member_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: exchange
--

ALTER TABLE ONLY public.schemas
    ADD CONSTRAINT schemas_members_member_id_fk FOREIGN KEY (member_id) REFERENCES public.members(member_id);


--
-- PostgreSQL database dump complete
--

-- \unrestrict command removed for compatibility