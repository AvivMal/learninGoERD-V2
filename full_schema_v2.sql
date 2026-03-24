\restrict sGXdNkKJb7gIYxn1iz6zTBZcpPPfol4nufK3awcCdHZuEBxFT1OlvELl1nW2xRf
CREATE TYPE public.app_role AS ENUM (
    'ADMIN',
    'USER'
);
CREATE TYPE public.course_status AS ENUM (
    'DRAFT',
    'PROCESSING',
    'GENERATING_STRUCTURE',
    'CREATED',
    'FAILED',
    'COMPLETED'
);
CREATE TYPE public.process_type AS ENUM (
    'PENDING',
    'TEXT',
    'SCANNED'
);
CREATE TYPE public.source_status AS ENUM (
    'UPLOADED',
    'PROCESSED',
    'ERROR',
    'REJECTED',
    'DELETED'
);
CREATE FUNCTION public.assign_default_role() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'USER')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE FUNCTION public.get_ai_cost_daily(p_start timestamp with time zone, p_end timestamp with time zone) RETURNS TABLE(day date, calls bigint, cost numeric)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    DATE(created_at AT TIME ZONE 'UTC') AS day,
    COUNT(*)                            AS calls,
    COALESCE(SUM(
      CASE
        WHEN cost_usd IS NOT NULL THEN cost_usd::numeric
        ELSE (
          COALESCE(tokens_prompt, 0) * CASE
            WHEN model IN ('gpt-4o', 'gpt-4o-2024-08-06', 'gpt-4o-2024-11-20') THEN 2.50
            WHEN model = 'gpt-4o-2024-05-13'                                    THEN 5.00
            WHEN model IN ('gpt-4o-mini', 'gpt-4o-mini-2024-07-18')            THEN 0.15
            WHEN model = 'gpt-4-turbo'                                          THEN 10.00
            WHEN model = 'gpt-4'                                                THEN 30.00
            WHEN model = 'gpt-3.5-turbo'                                        THEN 0.50
            WHEN model = 'gemini-2.5-flash'                                     THEN 0.15
            WHEN model = 'gemini-2.0-flash'                                     THEN 0.10
            WHEN model = 'gemini-1.5-flash'                                     THEN 0.075
            ELSE 2.50
          END
          +
          COALESCE(tokens_completion, 0) * CASE
            WHEN model IN ('gpt-4o', 'gpt-4o-2024-08-06', 'gpt-4o-2024-11-20') THEN 10.00
            WHEN model = 'gpt-4o-2024-05-13'                                    THEN 15.00
            WHEN model IN ('gpt-4o-mini', 'gpt-4o-mini-2024-07-18')            THEN 0.60
            WHEN model = 'gpt-4-turbo'                                          THEN 30.00
            WHEN model = 'gpt-4'                                                THEN 60.00
            WHEN model = 'gpt-3.5-turbo'                                        THEN 1.50
            WHEN model = 'gemini-2.5-flash'                                     THEN 0.60
            WHEN model = 'gemini-2.0-flash'                                     THEN 0.40
            WHEN model = 'gemini-1.5-flash'                                     THEN 0.30
            ELSE 10.00
          END
        ) / 1000000.0
      END
    ), 0) AS cost
  FROM prompt_runs
  WHERE created_at >= p_start
    AND created_at <= p_end
  GROUP BY DATE(created_at AT TIME ZONE 'UTC')
  ORDER BY day;
$$;
CREATE FUNCTION public.get_ai_cost_summary(p_start timestamp with time zone, p_end timestamp with time zone) RETURNS TABLE(total_cost numeric, total_calls bigint, prompt_tokens bigint, completion_tokens bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    COALESCE(SUM(
      CASE
        WHEN cost_usd IS NOT NULL THEN cost_usd::numeric
        ELSE (
          COALESCE(tokens_prompt, 0) * CASE
            WHEN model IN ('gpt-4o', 'gpt-4o-2024-08-06', 'gpt-4o-2024-11-20') THEN 2.50
            WHEN model = 'gpt-4o-2024-05-13'                                    THEN 5.00
            WHEN model IN ('gpt-4o-mini', 'gpt-4o-mini-2024-07-18')            THEN 0.15
            WHEN model = 'gpt-4-turbo'                                          THEN 10.00
            WHEN model = 'gpt-4'                                                THEN 30.00
            WHEN model = 'gpt-3.5-turbo'                                        THEN 0.50
            WHEN model = 'gemini-2.5-flash'                                     THEN 0.15
            WHEN model = 'gemini-2.0-flash'                                     THEN 0.10
            WHEN model = 'gemini-1.5-flash'                                     THEN 0.075
            ELSE 2.50
          END
          +
          COALESCE(tokens_completion, 0) * CASE
            WHEN model IN ('gpt-4o', 'gpt-4o-2024-08-06', 'gpt-4o-2024-11-20') THEN 10.00
            WHEN model = 'gpt-4o-2024-05-13'                                    THEN 15.00
            WHEN model IN ('gpt-4o-mini', 'gpt-4o-mini-2024-07-18')            THEN 0.60
            WHEN model = 'gpt-4-turbo'                                          THEN 30.00
            WHEN model = 'gpt-4'                                                THEN 60.00
            WHEN model = 'gpt-3.5-turbo'                                        THEN 1.50
            WHEN model = 'gemini-2.5-flash'                                     THEN 0.60
            WHEN model = 'gemini-2.0-flash'                                     THEN 0.40
            WHEN model = 'gemini-1.5-flash'                                     THEN 0.30
            ELSE 10.00
          END
        ) / 1000000.0
      END
    ), 0)                                            AS total_cost,
    COUNT(*)                                         AS total_calls,
    COALESCE(SUM(COALESCE(tokens_prompt, 0)), 0)     AS prompt_tokens,
    COALESCE(SUM(COALESCE(tokens_completion, 0)), 0) AS completion_tokens
  FROM prompt_runs
  WHERE created_at >= p_start
    AND created_at <= p_end;
$$;
CREATE FUNCTION public.get_user_course_count(u_id uuid) RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COUNT(*)::integer
  FROM courses
  WHERE created_by_user_id = u_id
    AND status != 'FAILED';
$$;
CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''));
  RETURN NEW;
END;
$$;
CREATE FUNCTION public.has_role(_user_id uuid, _role public.app_role) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;
CREATE FUNCTION public.match_course_chunks(query_embedding extensions.vector, p_course_id uuid, match_threshold double precision DEFAULT 0.78, match_count integer DEFAULT 8) RETURNS TABLE(id uuid, chunk_text text, metadata jsonb, similarity double precision)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    ckc.id,
    ckc.chunk_text,
    ckc.metadata,
    (1 - (ckc.embedding OPERATOR(extensions.<=>) query_embedding))::float AS similarity
  FROM public.course_knowledge_chunk ckc
  WHERE ckc.course_id = p_course_id
    AND (1 - (ckc.embedding OPERATOR(extensions.<=>) query_embedding)) > match_threshold
  ORDER BY ckc.embedding OPERATOR(extensions.<=>) query_embedding
  LIMIT match_count;
END;
$$;
CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
CREATE FUNCTION public.validate_system_log_level() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.level NOT IN ('INFO', 'WARN', 'ERROR') THEN
    RAISE EXCEPTION 'Invalid log level: %. Must be INFO, WARN, or ERROR.', NEW.level;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TABLE public.chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thread_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    mode text DEFAULT 'strict'::text,
    related_user_message_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chat_messages_mode_check CHECK ((mode = ANY (ARRAY['strict'::text, 'general'::text]))),
    CONSTRAINT chat_messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text, 'system'::text])))
);
CREATE TABLE public.chat_threads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    user_id uuid NOT NULL,
    title text DEFAULT ''::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.course_knowledge_chunk (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    source_id uuid,
    chunk_index integer NOT NULL,
    chunk_text text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    embedding extensions.vector(1536) NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.course_sources (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    file_name text NOT NULL,
    file_type text NOT NULL,
    status public.source_status DEFAULT 'UPLOADED'::public.source_status NOT NULL,
    process_type public.process_type DEFAULT 'PENDING'::public.process_type NOT NULL,
    file_url text,
    extracted_text_url text,
    uploaded_by_user_id uuid NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    error_message text,
    file_size_bytes bigint
);
CREATE TABLE public.course_sub_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    sub_unit_index text NOT NULL,
    sub_unit_title text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    content_type text,
    content_weights jsonb
);
CREATE TABLE public.course_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    unit_index integer NOT NULL,
    unit_title text NOT NULL,
    unit_description text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.courses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_by_user_id uuid NOT NULL,
    status public.course_status DEFAULT 'DRAFT'::public.course_status NOT NULL,
    title text,
    description text,
    user_preferences jsonb DEFAULT '{}'::jsonb,
    exam_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    knowledge_pack_json jsonb,
    blueprint_json jsonb,
    course_goal text,
    course_difficulty text DEFAULT 'בינוני'::text NOT NULL,
    course_notes text,
    error_message text,
    overload_confirmed boolean DEFAULT false NOT NULL,
    generation_status text DEFAULT 'idle'::text NOT NULL,
    deleted_at timestamp with time zone,
    completed_at timestamp with time zone,
    completion_source text
);
CREATE TABLE public.error_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid,
    page_path text NOT NULL,
    screen_name text,
    issue_category text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    severity text DEFAULT 'HIGH'::text NOT NULL,
    status text DEFAULT 'OPEN'::text NOT NULL,
    screenshot_url text,
    browser_info jsonb DEFAULT '{}'::jsonb NOT NULL,
    app_context jsonb DEFAULT '{}'::jsonb NOT NULL,
    theme_mode text,
    language_code text,
    membership_type text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.final_exam_seen_questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    question_hash text NOT NULL,
    original_question jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.final_exams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    questions jsonb DEFAULT '[]'::jsonb NOT NULL,
    score integer,
    passed boolean DEFAULT false NOT NULL,
    status text DEFAULT 'ACTIVE'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);
CREATE TABLE public.hobbies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name_he text NOT NULL,
    slug text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_custom boolean DEFAULT false NOT NULL,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);
CREATE TABLE public.learning_interactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    sub_unit_id uuid,
    interaction_type text NOT NULL,
    content_type text,
    content_item_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    display_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    hobby text DEFAULT ''::text,
    learning_preferences jsonb DEFAULT '{}'::jsonb,
    avatar_url text,
    membership_type text DEFAULT 'TIER_FREE'::text NOT NULL,
    lifetime_courses_created integer DEFAULT 0 NOT NULL,
    subscribe boolean DEFAULT false NOT NULL,
    current_period_end timestamp with time zone,
    stripe_customer_id text,
    stripe_subscription_id text,
    is_onboarded boolean DEFAULT false NOT NULL,
    email text,
    user_status text DEFAULT 'ACTIVE'::text NOT NULL,
    last_login_at timestamp with time zone
);
CREATE TABLE public.prompt_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid,
    source_ids jsonb,
    prompt_key text NOT NULL,
    template_version integer NOT NULL,
    model text NOT NULL,
    input_variables jsonb DEFAULT '{}'::jsonb NOT NULL,
    raw_response_text text,
    parsed_json jsonb,
    validation_passed boolean DEFAULT false NOT NULL,
    error_message text,
    tokens_prompt integer,
    tokens_completion integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cost_usd numeric(10,6)
);
CREATE TABLE public.prompt_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    prompt_key text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    language text DEFAULT 'he'::text NOT NULL,
    model text DEFAULT 'gpt-4o'::text NOT NULL,
    temperature double precision DEFAULT 0.2 NOT NULL,
    max_tokens integer DEFAULT 4096 NOT NULL,
    system_template text NOT NULL,
    user_template text NOT NULL,
    output_schema_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.study_plan_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    sub_unit_index text NOT NULL,
    title text NOT NULL,
    scheduled_date text NOT NULL,
    time_slot text NOT NULL,
    allocated_minutes integer DEFAULT 30 NOT NULL,
    is_split boolean DEFAULT false NOT NULL,
    session_sequence_id integer,
    status text DEFAULT 'PENDING'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_revision boolean DEFAULT false NOT NULL
);
CREATE TABLE public.study_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    schedule_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.sub_unit_chunk_classifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sub_unit_id uuid NOT NULL,
    chunk_id text NOT NULL,
    content_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.sub_unit_flashcards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    sub_unit_id uuid NOT NULL,
    cards jsonb DEFAULT '[]'::jsonb NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    generation_order integer,
    retry_count integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone
);
CREATE TABLE public.sub_unit_quizzes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    sub_unit_id uuid NOT NULL,
    questions jsonb DEFAULT '[]'::jsonb NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    generation_order integer,
    retry_count integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone
);
CREATE TABLE public.sub_unit_summaries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    sub_unit_id uuid NOT NULL,
    summary_json jsonb,
    status text DEFAULT 'PENDING'::text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    generation_order integer,
    retry_count integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    used_chunk_ids text[] DEFAULT '{}'::text[],
    CONSTRAINT sub_unit_summaries_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'GENERATING'::text, 'READY'::text, 'FAILED'::text])))
);
CREATE TABLE public.system_logs (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    level text NOT NULL,
    event_type text NOT NULL,
    source text NOT NULL,
    entity_type text,
    entity_id uuid,
    user_id uuid,
    course_id uuid,
    message text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);
CREATE SEQUENCE public.system_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.system_logs_id_seq OWNED BY public.system_logs.id;
CREATE TABLE public.unit_exams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    questions jsonb DEFAULT '[]'::jsonb NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.unit_generation_locks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    unit_id uuid NOT NULL,
    course_id uuid NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    current_sub_unit_index integer DEFAULT 0 NOT NULL,
    total_sub_units integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    error_message text,
    created_by_user_id uuid NOT NULL
);
CREATE TABLE public.user_course_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    last_unit_id uuid,
    last_sub_unit_id uuid,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.user_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    user_agent text,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.user_feedback (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid,
    sub_unit_id uuid,
    feedback_type text NOT NULL,
    feedback_value jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'OPEN'::text NOT NULL,
    severity text DEFAULT 'LOW'::text NOT NULL,
    internal_note text
);
CREATE TABLE public.user_hobbies (
    user_id uuid NOT NULL,
    hobby_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.user_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    study_days text[] DEFAULT '{}'::text[] NOT NULL,
    daily_duration text DEFAULT '30-60'::text NOT NULL,
    preferred_time text DEFAULT 'morning'::text NOT NULL,
    content_types text[] DEFAULT '{}'::text[] NOT NULL,
    ai_instructions text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    theme_mode text DEFAULT 'system'::text NOT NULL,
    language_code text DEFAULT 'he'::text NOT NULL
);
CREATE TABLE public.user_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role public.app_role DEFAULT 'USER'::public.app_role NOT NULL
);
CREATE TABLE public.user_subunit_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    sub_unit_id uuid NOT NULL,
    quiz_completed boolean DEFAULT false NOT NULL,
    quiz_score integer,
    flashcard_best_score integer,
    state text DEFAULT 'LOCKED'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.user_unit_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    exam_score integer,
    state text DEFAULT 'LOCKED'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE ONLY public.system_logs ALTER COLUMN id SET DEFAULT nextval('public.system_logs_id_seq'::regclass);
\unrestrict sGXdNkKJb7gIYxn1iz6zTBZcpPPfol4nufK3awcCdHZuEBxFT1OlvELl1nW2xRf
