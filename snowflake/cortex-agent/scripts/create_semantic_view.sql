-- =============================================================================
-- FULLSTORY SEMANTIC VIEW
-- =============================================================================
--
-- Creates the Snowflake SQL Semantic View that powers the Cortex Agent.
-- This file is processed by the Makefile (make deploy) which substitutes:
--
--   {{DATABASE}}     -> Fullstory source database (e.g. FULLSTORY_READY_TO_ANALYZE)
--   {{SCHEMA}}       -> Fullstory source schema   (e.g. FULLSTORY_DEMO_DATA)
--   {{DEPLOY_DB}}    -> Deployment database        (e.g. FULLSTORY_CORTEX)
--   {{DEPLOY_SCHEMA}}-> Deployment schema          (e.g. SEMANTIC_LAYER)
--   {{SV_NAME}}      -> Semantic view name         (e.g. FULLSTORY_SEMANTIC)
--
-- To run manually without make:
--   Replace the {{...}} placeholders and execute in Snowsight or snow sql.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS {{DEPLOY_DB}};
USE DATABASE {{DEPLOY_DB}};
CREATE SCHEMA IF NOT EXISTS {{DEPLOY_SCHEMA}};
USE SCHEMA {{DEPLOY_SCHEMA}};


CREATE OR REPLACE SEMANTIC VIEW {{DEPLOY_DB}}.{{DEPLOY_SCHEMA}}.{{SV_NAME}}
    TABLES (
        -- =====================================================================
        -- FACT TABLES
        -- =====================================================================
        {{DATABASE}}.{{SCHEMA}}.EVENTS
            PRIMARY KEY (ID)
            COMMENT = 'Central fact table containing all user interactions and system events.',
        {{DATABASE}}.{{SCHEMA}}.CLICKS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Click events including rage clicks, dead clicks, long clicks, and target elements.',
        {{DATABASE}}.{{SCHEMA}}.BACKGROUNDS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Indicates that a mobile app was backgrounded.',
        {{DATABASE}}.{{SCHEMA}}.PAGE_VIEWS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Page views including durations, scroll depth, and engagement time.',
        {{DATABASE}}.{{SCHEMA}}.FORCE_RESTARTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Contains information about force restarts, including the elapsed time in milliseconds.',
        {{DATABASE}}.{{SCHEMA}}.LOADS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Page load events with Core Web Vitals (FCP, LCP, TTFB, TTI, TBT) and DOM timing.',
        {{DATABASE}}.{{SCHEMA}}.CUMULATIVE_LAYOUT_SHIFTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'CLS events - Core Web Vital measuring visual stability.',
        {{DATABASE}}.{{SCHEMA}}.FIRST_INPUT_DELAYS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'FID events - Core Web Vital measuring interactivity (legacy; prefer INP).',
        {{DATABASE}}.{{SCHEMA}}.INTERACTION_TO_NEXT_PAINTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'INP events - Core Web Vital measuring overall interaction responsiveness. Values under 200ms are considered good.',
        {{DATABASE}}.{{SCHEMA}}.CONSENTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'User consent events capturing consent scope, action type, and whether consent was given.',
        {{DATABASE}}.{{SCHEMA}}.COPIES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Copy/clipboard events including the target element and text that was copied.',
        {{DATABASE}}.{{SCHEMA}}.PASTES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Paste/clipboard events including the target element that received the paste.',
        {{DATABASE}}.{{SCHEMA}}.HIGHLIGHTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Text highlight events including the target element and highlighted text.',
        {{DATABASE}}.{{SCHEMA}}.EXCEPTIONS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'JavaScript exceptions including error messages, source file, and handled status.',
        {{DATABASE}}.{{SCHEMA}}.CONSOLE_MESSAGES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Browser console log events, currently capturing error-level messages.',
        {{DATABASE}}.{{SCHEMA}}.NAVIGATES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Page navigation events including the reason for navigation (navigate, reload, back_forward, prerender).',
        {{DATABASE}}.{{SCHEMA}}.FORM_ABANDONS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Form interactions where the user abandoned the form without submitting.',
        {{DATABASE}}.{{SCHEMA}}.FORM_INPUT_CHANGES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Form field change events with suspicious input detection (SQL injection, XSS).',
        {{DATABASE}}.{{SCHEMA}}.MOUSE_THRASHES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Rapid erratic mouse movement events indicating user frustration.',
        {{DATABASE}}.{{SCHEMA}}.ELEMENTS_SEEN
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Watched element visibility events with render and visible duration metrics.',
        {{DATABASE}}.{{SCHEMA}}.CUSTOM_EVENTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Custom events created via Fullstory APIs for conversion and product analytics tracking.',
        {{DATABASE}}.{{SCHEMA}}.REQUESTS
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'HTTP requests with 400 or 500 level status codes.',
        {{DATABASE}}.{{SCHEMA}}.CRASHES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Mobile application crash events.',

        -- =====================================================================
        -- DIMENSION TABLES
        -- =====================================================================
        {{DATABASE}}.{{SCHEMA}}.SOURCE_PROPERTIES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Event source context including location, device, browser, app, and referrer details.',
        {{DATABASE}}.{{SCHEMA}}.USERS
            PRIMARY KEY (ID)
            COMMENT = 'User information including Fullstory ID, customer UID, display names, and emails.',
        {{DATABASE}}.{{SCHEMA}}.PAGE_DEFINITIONS
            PRIMARY KEY (ID)
            COMMENT = 'Customer-defined named pages with their name, description, and active state.',
        {{DATABASE}}.{{SCHEMA}}.ELEMENT_DEFINITIONS
            PRIMARY KEY (ID)
            COMMENT = 'Customer-defined named elements with their name, description, and active state.',
        {{DATABASE}}.{{SCHEMA}}.EVENT_DEFINITIONS
            PRIMARY KEY (ID)
            COMMENT = 'Customer-defined event definitions with their name, description, and active state.',

        -- =====================================================================
        -- SUBDIMENSION TABLES (custom property columns)
        -- =====================================================================
        {{DATABASE}}.{{SCHEMA}}.ELEMENT_PROPERTIES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Element properties set via Fullstory API. Add your custom columns here.',
        {{DATABASE}}.{{SCHEMA}}.PAGE_PROPERTIES
            PRIMARY KEY (EVENT_ID)
            COMMENT = 'Page properties set via Fullstory API. Add your custom columns here.',
        {{DATABASE}}.{{SCHEMA}}.USER_PROPERTIES
            PRIMARY KEY (USER_ID)
            COMMENT = 'User properties set via Fullstory API. Add your custom columns here.'
    )
    RELATIONSHIPS (
        -- Event sub-fact tables join to EVENTS via EVENT_ID
        EVENTS_TO_CLICKS                    AS EVENTS(ID) REFERENCES CLICKS(EVENT_ID),
        EVENTS_TO_BACKGROUNDS               AS EVENTS(ID) REFERENCES BACKGROUNDS(EVENT_ID),
        EVENTS_TO_FORCE_RESTART             AS EVENTS(ID) REFERENCES FORCE_RESTARTS(EVENT_ID),
        EVENTS_TO_PAGE_VIEWS                AS EVENTS(ID) REFERENCES PAGE_VIEWS(EVENT_ID),
        EVENTS_TO_LOADS                     AS EVENTS(ID) REFERENCES LOADS(EVENT_ID),
        EVENTS_TO_CUMULATIVE_LAYOUT_SHIFTS  AS EVENTS(ID) REFERENCES CUMULATIVE_LAYOUT_SHIFTS(EVENT_ID),
        EVENTS_TO_FIRST_INPUT_DELAYS        AS EVENTS(ID) REFERENCES FIRST_INPUT_DELAYS(EVENT_ID),
        EVENTS_TO_INTERACTION_TO_NEXT_PAINTS AS EVENTS(ID) REFERENCES INTERACTION_TO_NEXT_PAINTS(EVENT_ID),
        EVENTS_TO_CONSENTS                  AS EVENTS(ID) REFERENCES CONSENTS(EVENT_ID),
        EVENTS_TO_COPIES                    AS EVENTS(ID) REFERENCES COPIES(EVENT_ID),
        EVENTS_TO_PASTES                    AS EVENTS(ID) REFERENCES PASTES(EVENT_ID),
        EVENTS_TO_HIGHLIGHTS                AS EVENTS(ID) REFERENCES HIGHLIGHTS(EVENT_ID),
        EVENTS_TO_EXCEPTIONS                AS EVENTS(ID) REFERENCES EXCEPTIONS(EVENT_ID),
        EVENTS_TO_CONSOLE_MESSAGES          AS EVENTS(ID) REFERENCES CONSOLE_MESSAGES(EVENT_ID),
        EVENTS_TO_NAVIGATES                 AS EVENTS(ID) REFERENCES NAVIGATES(EVENT_ID),
        EVENTS_TO_FORM_ABANDONS             AS EVENTS(ID) REFERENCES FORM_ABANDONS(EVENT_ID),
        EVENTS_TO_FORM_INPUT_CHANGES        AS EVENTS(ID) REFERENCES FORM_INPUT_CHANGES(EVENT_ID),
        EVENTS_TO_MOUSE_THRASHES            AS EVENTS(ID) REFERENCES MOUSE_THRASHES(EVENT_ID),
        EVENTS_TO_ELEMENTS_SEEN             AS EVENTS(ID) REFERENCES ELEMENTS_SEEN(EVENT_ID),
        EVENTS_TO_CUSTOM_EVENTS             AS EVENTS(ID) REFERENCES CUSTOM_EVENTS(EVENT_ID),
        EVENTS_TO_REQUESTS                  AS EVENTS(ID) REFERENCES REQUESTS(EVENT_ID),
        EVENTS_TO_CRASHES                   AS EVENTS(ID) REFERENCES CRASHES(EVENT_ID),
        EVENTS_TO_SOURCE_PROPERTIES         AS EVENTS(ID) REFERENCES SOURCE_PROPERTIES(EVENT_ID),
        EVENTS_TO_ELEMENT_PROPERTIES        AS EVENTS(ID) REFERENCES ELEMENT_PROPERTIES(EVENT_ID),
        EVENTS_TO_PAGE_PROPERTIES           AS EVENTS(ID) REFERENCES PAGE_PROPERTIES(EVENT_ID),

        -- User joins
        EVENTS_TO_USER_PROPERTIES           AS EVENTS(USER_ID) REFERENCES USER_PROPERTIES(USER_ID),
        EVENTS_TO_USERS                     AS EVENTS(USER_ID) REFERENCES USERS(ID),

        EVENTS_TO_ELEMENT_DEFINITIONS       AS EVENTS(ELEMENT_DEFINITION_ID) REFERENCES ELEMENT_DEFINITIONS(ID),
        EVENTS_TO_EVENT_DEFINITIONS         AS EVENTS(EVENT_DEFINITION_ID) REFERENCES EVENT_DEFINITIONS(ID),
        SOURCE_PROPERTIES_TO_PAGE_DEFS      AS SOURCE_PROPERTIES(PAGE_DEFINITION_ID) REFERENCES PAGE_DEFINITIONS(ID)
    )
    FACTS (
        -- Page engagement
        PAGE_VIEWS.ACTIVE_DURATION_MILLIS AS active_duration_millis
            WITH SYNONYMS = ('active time', 'engagement time')
            COMMENT = 'Milliseconds the user was actively interacting with the page.',
        PAGE_VIEWS.INACTIVE_DURATION_MILLIS AS inactive_duration_millis
            WITH SYNONYMS = ('idle time', 'inactive time')
            COMMENT = 'Milliseconds the page was open but the user was idle.',
        PAGE_VIEWS.DURATION_MILLIS AS duration_millis
            WITH SYNONYMS = ('time on page', 'total page time')
            COMMENT = 'Total time in milliseconds the page was rendered (active + inactive).',
        PAGE_VIEWS.MAX_SCROLL_DEPTH AS max_scroll_depth
            WITH SYNONYMS = ('scroll depth', 'scroll percentage')
            COMMENT = 'Max scroll depth for the page as a ratio (0 to 1.0).',

        -- Core Web Vitals: Loading
        LOADS.FIRST_PAINT_TIME_MILLIS AS first_paint_time_millis
            WITH SYNONYMS = ('fcp', 'first contentful paint')
            COMMENT = 'Time of the First Contentful Paint in ms. Good < 1.8s.',
        LOADS.LARGEST_PAINT_TIME_MILLIS AS largest_paint_time_millis
            WITH SYNONYMS = ('lcp', 'largest contentful paint')
            COMMENT = 'Time of the Largest Contentful Paint in ms. Good < 2.5s.',
        LOADS.TIME_TO_FIRST_BYTE_MILLIS AS time_to_first_byte_millis
            WITH SYNONYMS = ('ttfb', 'server response time')
            COMMENT = 'Time to First Byte in milliseconds. Good < 800ms.',
        LOADS.LOAD_TIME_MILLIS AS load_time_millis
            WITH SYNONYMS = ('page load time', 'full load time')
            COMMENT = 'Time for the page to fully load in milliseconds.',
        LOADS.DOM_CONTENT_TIME_MILLIS AS dom_content_time_millis
            WITH SYNONYMS = ('dom ready', 'dom content loaded')
            COMMENT = 'Time for DOM construction to complete in milliseconds.',
        LOADS.TIME_TO_INTERACTIVE_MILLIS AS time_to_interactive_millis
            WITH SYNONYMS = ('tti', 'time to interactive')
            COMMENT = 'Time until the page becomes fully interactive in ms. Good < 3.8s.',
        LOADS.TOTAL_BLOCKING_TIME_MILLIS AS total_blocking_time_millis
            WITH SYNONYMS = ('tbt', 'blocking time')
            COMMENT = 'Total time the main thread was blocked in ms. Good < 200ms.',

        -- Core Web Vitals: Stability and Interactivity
        CUMULATIVE_LAYOUT_SHIFTS.CUMULATIVE_LAYOUT_SHIFT AS cumulative_layout_shift
            WITH SYNONYMS = ('cls score', 'layout shift score', 'visual stability')
            COMMENT = 'The Cumulative Layout Shift (CLS) score. Good < 0.1.',
        FIRST_INPUT_DELAYS.FIRST_INPUT_DELAY_MILLIS AS first_input_delay_millis
            WITH SYNONYMS = ('fid', 'first input delay')
            COMMENT = 'Time from first user input to browser response in ms. Good < 100ms.',
        INTERACTION_TO_NEXT_PAINTS.INTERACTION_TO_NEXT_PAINT_MILLIS AS interaction_to_next_paint_millis
            WITH SYNONYMS = ('inp', 'interaction to next paint', 'responsiveness')
            COMMENT = 'Time from user interaction to next visual update in ms. Good < 200ms. Replaces FID as the primary interactivity Web Vital.',

        -- Element visibility
        ELEMENTS_SEEN.ELEMENT_RENDER_DURATION_MILLIS AS element_render_duration_millis
            WITH SYNONYMS = ('render time', 'time to render')
            COMMENT = 'Time in milliseconds for the watched element to render.',
        ELEMENTS_SEEN.ELEMENT_VISIBLE_DURATION_MILLIS AS element_visible_duration_millis
            WITH SYNONYMS = ('visibility duration', 'time visible')
            COMMENT = 'Duration in milliseconds the watched element was visible.'
    )
    DIMENSIONS (
        -- =====================================================================
        -- EVENTS (central fact)
        -- =====================================================================
        EVENTS.ELEMENT_DEFINITION_ID AS ELEMENT_DEFINITION_ID
            WITH SYNONYMS = ('element definition id', 'named element id')
            COMMENT = 'The id of the most specific Named Element matched as the target of the event.',
        EVENTS.EVENT_DEFINITION_ID AS EVENT_DEFINITION_ID
            WITH SYNONYMS = ('event definition id', 'defined event id')
            COMMENT = 'The id of the most specific Defined Event that matched this event.',
        EVENTS.EVENT_TYPE AS EVENT_TYPE
            WITH SYNONYMS = ('event category', 'type of event')
            COMMENT = 'The type of the event (click, page_view, navigate, change, load, etc.).',
        EVENTS.ID AS ID
            WITH SYNONYMS = ('event id', 'event identifier')
            COMMENT = 'A unique identifier for each event.',
        EVENTS.SESSION_ID AS SESSION_ID
            WITH SYNONYMS = ('session id', 'session identifier')
            COMMENT = 'A unique id corresponding to a single session.',
        EVENTS.USER_ID AS USER_ID
            WITH SYNONYMS = ('user id', 'user identifier')
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        EVENTS.EVENT_TIME AS EVENT_TIME
            WITH SYNONYMS = ('event timestamp', 'time of event')
            COMMENT = 'The timestamp when the event occurred, per device clock.',

        -- =====================================================================
        -- CLICKS
        -- =====================================================================
        CLICKS.EVENT_ID AS event_id
            WITH SYNONYMS = ('click id')
            COMMENT = 'Foreign key referencing the events fact table.',
        CLICKS.FS_DEAD_COUNT AS fs_dead_count
            WITH SYNONYMS = ('dead count', 'dead clicks')
            COMMENT = 'The number of dead clicks (no response) detected in this event.',
        CLICKS.FS_RAGE_COUNT AS fs_rage_count
            WITH SYNONYMS = ('rage count', 'rage clicks')
            COMMENT = 'The number of rage clicks (rapid repeated clicks) detected in this event.',
        CLICKS.FS_ERROR_KIND AS fs_error_kind
            WITH SYNONYMS = ('click error type', 'error kind')
            COMMENT = 'If present, the type of error associated with the click: unknown, console, or exception.',
        CLICKS.IS_CLICK_LONG AS is_click_long
            WITH SYNONYMS = ('long press', 'long click')
            COMMENT = 'True if this was a long-press/long-click interaction.',
        CLICKS.IS_CLICK_UNHANDLED AS is_click_unhandled
            WITH SYNONYMS = ('unhandled click')
            COMMENT = 'True if the click had no registered event handler.',
        CLICKS.TARGET_TEXT AS target_text
            WITH SYNONYMS = ('button text', 'element text', 'clicked text')
            COMMENT = 'The visible text content of the clicked element.',
        CLICKS.TARGET_RAW_SELECTOR AS target_raw_selector
            WITH SYNONYMS = ('click selector', 'element selector')
            COMMENT = 'The full CSS selector path to the clicked element.',
        CLICKS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        CLICKS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        CLICKS.EVENT_TIME AS event_time
            WITH SYNONYMS = ('click time')
            COMMENT = 'The time in UTC that the click event occurred.',

        -- =====================================================================
        -- PAGE_VIEWS
        -- =====================================================================
        PAGE_VIEWS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        PAGE_VIEWS.PAGE_NAME AS page_name
            WITH SYNONYMS = ('page title', 'screen name')
            COMMENT = 'The name of the page, set via Fullstory API.',
        PAGE_VIEWS.START_TIME AS start_time
            WITH SYNONYMS = ('page load timestamp')
            COMMENT = 'Timestamp when the page started loading.',
        PAGE_VIEWS.END_TIME AS end_time
            WITH SYNONYMS = ('page unload timestamp', 'page exit time')
            COMMENT = 'Timestamp when the page was unloaded.',
        PAGE_VIEWS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        PAGE_VIEWS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        PAGE_VIEWS.VIEW_ID AS view_id
            COMMENT = 'Unique id associating events to a single page load.',
        PAGE_VIEWS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the page view event occurred.',

        -- =====================================================================
        -- BACKGROUNDS
        -- =====================================================================
        BACKGROUNDS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        BACKGROUNDS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        BACKGROUNDS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        BACKGROUNDS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the page load event occurred.',
       
        -- =====================================================================
        -- FORCE RESTARTS
        -- =====================================================================
        FORCE_RESTARTS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        FORCE_RESTARTS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        FORCE_RESTARTS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        FORCE_RESTARTS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the page load event occurred.',
        FORCE_RESTARTS.ELAPSED_MILLIS as elapsed_millis
            COMMENT = 'The number of milliseconds between when the app was backgrounded and when it was started.',
        -- =====================================================================
        -- LOADS
        -- =====================================================================
        LOADS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        LOADS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        LOADS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        LOADS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the page load event occurred.',

        -- =====================================================================
        -- CUMULATIVE_LAYOUT_SHIFTS
        -- =====================================================================
        CUMULATIVE_LAYOUT_SHIFTS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        CUMULATIVE_LAYOUT_SHIFTS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        CUMULATIVE_LAYOUT_SHIFTS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        CUMULATIVE_LAYOUT_SHIFTS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the CLS event occurred.',

        -- =====================================================================
        -- FIRST_INPUT_DELAYS
        -- =====================================================================
        FIRST_INPUT_DELAYS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        FIRST_INPUT_DELAYS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        FIRST_INPUT_DELAYS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        FIRST_INPUT_DELAYS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the FID event occurred.',

        -- =====================================================================
        -- INTERACTION_TO_NEXT_PAINTS (INP) — 
        -- =====================================================================
        INTERACTION_TO_NEXT_PAINTS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        INTERACTION_TO_NEXT_PAINTS.EVENT_NAME AS inp_event_name
            WITH SYNONYMS = ('inp trigger', 'interaction type')
            COMMENT = 'The browser event that triggered INP measurement (e.g. keydown, mouseover).',
        INTERACTION_TO_NEXT_PAINTS.TARGET_TEXT AS inp_target_text
            WITH SYNONYMS = ('inp element text')
            COMMENT = 'The visible text of the element that triggered the INP interaction.',
        INTERACTION_TO_NEXT_PAINTS.TARGET_RAW_SELECTOR AS inp_target_selector
            WITH SYNONYMS = ('inp element selector')
            COMMENT = 'The CSS selector of the element that triggered the INP interaction.',
        INTERACTION_TO_NEXT_PAINTS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        INTERACTION_TO_NEXT_PAINTS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        INTERACTION_TO_NEXT_PAINTS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the INP event occurred.',

        -- =====================================================================
        -- EXCEPTIONS
        -- =====================================================================
        EXCEPTIONS.EVENT_ID AS event_id
            WITH SYNONYMS = ('exception id')
            COMMENT = 'Foreign key referencing the events fact table.',
        EXCEPTIONS.EXCEPTION_COUNT AS exception_count
            WITH SYNONYMS = ('burst count')
            COMMENT = 'Times this exception fired within a given burst window.',
        EXCEPTIONS.EXCEPTION_SOURCE_FILE AS exception_source_file
            WITH SYNONYMS = ('file path', 'source file')
            COMMENT = 'The source file that produced the exception.',
        EXCEPTIONS.IS_EXCEPTION_HANDLED AS is_exception_handled
            WITH SYNONYMS = ('caught', 'handled')
            COMMENT = 'Whether the exception is caught (handled) or uncaught (unhandled).',
        EXCEPTIONS.MESSAGE AS message
            WITH SYNONYMS = ('error text', 'exception message', 'error message')
            COMMENT = 'The message associated with the exception.',
        EXCEPTIONS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        EXCEPTIONS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        EXCEPTIONS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the exception event occurred.',

        -- =====================================================================
        -- CONSOLE_MESSAGES
        -- =====================================================================
        CONSOLE_MESSAGES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        CONSOLE_MESSAGES.CONSOLE_MESSAGE_LEVEL AS console_message_level
            WITH SYNONYMS = ('log level', 'console level')
            COMMENT = 'The severity level of the console message (e.g. error).',
        CONSOLE_MESSAGES.MESSAGE AS console_message
            WITH SYNONYMS = ('console error text', 'console log text')
            COMMENT = 'The text content of the console message.',
        CONSOLE_MESSAGES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        CONSOLE_MESSAGES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        CONSOLE_MESSAGES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the console message occurred.',

        -- =====================================================================
        -- NAVIGATES
        -- =====================================================================
        NAVIGATES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        NAVIGATES.NAVIGATE_REASON AS navigate_reason
            WITH SYNONYMS = ('navigation type', 'nav reason')
            COMMENT = 'Why the navigation occurred: navigate, reload, back_forward, or prerender.',
        NAVIGATES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        NAVIGATES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        NAVIGATES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the navigation event occurred.',

        -- =====================================================================
        -- FORM_ABANDONS
        -- =====================================================================
        FORM_ABANDONS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        FORM_ABANDONS.TARGET_RAW_SELECTOR AS form_abandon_selector
            WITH SYNONYMS = ('form field selector', 'abandoned field selector')
            COMMENT = 'The CSS selector path to the form field that was abandoned.',
        FORM_ABANDONS.TARGET_TEXT AS form_abandon_target_text
            WITH SYNONYMS = ('abandoned field text')
            COMMENT = 'The text of the form element that was abandoned.',
        FORM_ABANDONS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        FORM_ABANDONS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        FORM_ABANDONS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the form abandon event occurred.',

        -- =====================================================================
        -- FORM_INPUT_CHANGES
        -- =====================================================================
        FORM_INPUT_CHANGES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        FORM_INPUT_CHANGES.TARGET_RAW_SELECTOR AS form_input_selector
            WITH SYNONYMS = ('input field selector')
            COMMENT = 'The CSS selector path to the form input that changed.',
        FORM_INPUT_CHANGES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        FORM_INPUT_CHANGES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        FORM_INPUT_CHANGES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the form input change occurred.',

        -- =====================================================================
        -- MOUSE_THRASHES
        -- =====================================================================
        MOUSE_THRASHES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        MOUSE_THRASHES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        MOUSE_THRASHES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        MOUSE_THRASHES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the mouse thrash event occurred.',

        -- =====================================================================
        -- ELEMENTS_SEEN
        -- =====================================================================
        ELEMENTS_SEEN.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        ELEMENTS_SEEN.ELEMENT_TYPE AS element_type
            WITH SYNONYMS = ('watched element type')
            COMMENT = 'The classification of the watched element.',
        ELEMENTS_SEEN.ELEMENT_START_TYPE AS element_start_type
            WITH SYNONYMS = ('element state', 'element visibility state')
            COMMENT = 'The state when the element was observed: rendered, visible, or end.',
        ELEMENTS_SEEN.TARGET_TEXT AS elements_seen_target_text
            WITH SYNONYMS = ('watched element text')
            COMMENT = 'The visible text of the watched element.',
        ELEMENTS_SEEN.TARGET_RAW_SELECTOR AS elements_seen_selector
            WITH SYNONYMS = ('watched element selector')
            COMMENT = 'The CSS selector path to the watched element.',
        ELEMENTS_SEEN.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        ELEMENTS_SEEN.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        ELEMENTS_SEEN.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the element seen event occurred.',

        -- =====================================================================
        -- CUSTOM_EVENTS
        -- =====================================================================
        CUSTOM_EVENTS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        CUSTOM_EVENTS.EVENT_NAME AS event_name
            WITH SYNONYMS = ('action name', 'custom event name', 'conversion event name')
            COMMENT = 'The customer-defined name of the custom event.',
        CUSTOM_EVENTS.EVENT_PROPERTIES AS event_properties
            WITH SYNONYMS = ('attributes', 'payload', 'custom properties')
            COMMENT = 'Customer-defined event properties stored as JSON.',
        CUSTOM_EVENTS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        CUSTOM_EVENTS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        CUSTOM_EVENTS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the custom event occurred.',

        -- =====================================================================
        -- REQUESTS
        -- =====================================================================
        REQUESTS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        REQUESTS.REQUEST_DURATION_MILLIS AS request_duration_millis
            WITH SYNONYMS = ('latency', 'api latency', 'request latency')
            COMMENT = 'The duration of the HTTP request in milliseconds.',
        REQUESTS.REQUEST_METHOD AS request_method
            WITH SYNONYMS = ('http method', 'verb')
            COMMENT = 'The HTTP method (GET, POST, PUT, DELETE, etc.).',
        REQUESTS.REQUEST_STATUS AS request_status
            WITH SYNONYMS = ('error code', 'http status', 'status code')
            COMMENT = 'The HTTP status code (4xx client errors, 5xx server errors).',
        REQUESTS.REQUEST_URL_FULL_URL AS request_url_full_url
            WITH SYNONYMS = ('endpoint', 'full url', 'api url')
            COMMENT = 'The full URL of the failed HTTP request.',
        REQUESTS.REQUEST_URL_HOST AS request_url_host
            WITH SYNONYMS = ('api host', 'request host')
            COMMENT = 'The host/domain component of the request URL.',
        REQUESTS.REQUEST_URL_PATH AS request_url_path
            WITH SYNONYMS = ('api path', 'request path', 'endpoint path')
            COMMENT = 'The path component of the request URL.',
        REQUESTS.REQUEST_URL_QUERY AS request_url_query
            WITH SYNONYMS = ('query string', 'request query params')
            COMMENT = 'The query string parameters of the request URL.',
        REQUESTS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        REQUESTS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        REQUESTS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the failed request event occurred.',

        -- =====================================================================
        -- CRASHES
        -- =====================================================================
        CRASHES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        CRASHES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        CRASHES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        CRASHES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the crash event occurred.',

        -- =====================================================================
        -- CONSENTS
        -- =====================================================================
        CONSENTS.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        CONSENTS.IS_CONSENT_GIVEN AS is_consent_given
            WITH SYNONYMS = ('consent granted', 'user consented')
            COMMENT = 'True if the user granted consent, false if denied or revoked.',
        CONSENTS.CONSENT_SCOPE AS consent_scope
            WITH SYNONYMS = ('consent type', 'consent category')
            COMMENT = 'The scope or category of consent (e.g. analytics, marketing).',
        CONSENTS.CONSENT_ACTION_TYPE AS consent_action_type
            WITH SYNONYMS = ('consent action', 'consent event type')
            COMMENT = 'The type of consent action taken (e.g. granted, denied, revoked).',
        CONSENTS.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        CONSENTS.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        CONSENTS.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the consent event occurred.',

        -- =====================================================================
        -- COPIES 
        -- =====================================================================
        COPIES.EVENT_ID AS event_id,
        COPIES.SESSION_ID AS session_id,
        COPIES.USER_ID AS user_id,
        COPIES.EVENT_TIME AS event_time,

        -- =====================================================================
        -- PASTES
        -- =====================================================================
        PASTES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        PASTES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        PASTES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        PASTES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the paste event occurred.',

        -- =====================================================================
        -- HIGHLIGHTS 
        -- =====================================================================
        HIGHLIGHTS.EVENT_ID AS event_id,
        HIGHLIGHTS.SESSION_ID AS session_id,
        HIGHLIGHTS.USER_ID AS user_id,
        HIGHLIGHTS.EVENT_TIME AS event_time,

        -- =====================================================================
        -- SOURCE_PROPERTIES
        -- =====================================================================
        SOURCE_PROPERTIES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',

        -- Page and URL context
        SOURCE_PROPERTIES.TITLE AS page_title  -- column is null in this dataset
            WITH SYNONYMS = ('html title', 'document title')
            COMMENT = 'The HTML page title at the time of the event.',
        SOURCE_PROPERTIES.URL_FULL_URL AS url_full_url
            WITH SYNONYMS = ('current url', 'page url', 'full url')
            COMMENT = 'The complete URL of the page when the event occurred.',
        SOURCE_PROPERTIES.URL_HOST AS url_host
            WITH SYNONYMS = ('domain', 'hostname')
            COMMENT = 'The host/domain portion of the page URL.',
        SOURCE_PROPERTIES.URL_PATH AS url_path
            WITH SYNONYMS = ('page path', 'url path')
            COMMENT = 'The path portion of the page URL.',
        SOURCE_PROPERTIES.PAGE_DEFINITION_ID AS page_definition_id
            WITH SYNONYMS = ('named page id', 'defined page id')
            COMMENT = 'The ID of the Fullstory Named Page that matched this event.',

        -- Referrer
        SOURCE_PROPERTIES.INITIAL_REFERRER_FULL_URL AS initial_referrer_full_url
            WITH SYNONYMS = ('referrer url', 'referring url', 'traffic source url')
            COMMENT = 'The full referrer URL from the first navigation of the session.',
        SOURCE_PROPERTIES.INITIAL_REFERRER_HOST AS initial_referrer_host
            WITH SYNONYMS = ('referrer host', 'referring domain', 'traffic source domain')
            COMMENT = 'The host/domain of the session referrer.',
        SOURCE_PROPERTIES.INITIAL_REFERRER_PATH AS initial_referrer_path
            WITH SYNONYMS = ('referrer path')
            COMMENT = 'The path component of the session referrer URL.',

        -- Geography
        SOURCE_PROPERTIES.LOCATION_CITY AS location_city
            WITH SYNONYMS = ('city')
            COMMENT = 'The city associated with the user IP address.',
        SOURCE_PROPERTIES.LOCATION_COUNTRY AS location_country
            WITH SYNONYMS = ('country')
            COMMENT = 'The country associated with the user IP address.',
        SOURCE_PROPERTIES.LOCATION_REGION AS location_region
            WITH SYNONYMS = ('region', 'state', 'province')
            COMMENT = 'The region or state associated with the user IP address.',
        SOURCE_PROPERTIES.LOCATION_LAT_LONG AS location_lat_long
            WITH SYNONYMS = ('coordinates', 'lat long', 'geo coordinates')
            COMMENT = 'Latitude and longitude coordinates derived from the IP address.',

        -- Browser and device
        SOURCE_PROPERTIES.USER_AGENT_BROWSER AS user_agent_browser
            WITH SYNONYMS = ('browser', 'browser name')
            COMMENT = 'The browser used (Chrome, Safari, Firefox, Edge, etc.).',
        SOURCE_PROPERTIES.USER_AGENT_BROWSER_VERSION AS user_agent_browser_version
            WITH SYNONYMS = ('browser version')
            COMMENT = 'The version string of the browser.',
        SOURCE_PROPERTIES.USER_AGENT_DEVICE AS user_agent_device
            WITH SYNONYMS = ('device type', 'form factor')
            COMMENT = 'The type of device: Desktop, Mobile, or Tablet.',
        SOURCE_PROPERTIES.USER_AGENT_OPERATING_SYSTEM AS user_agent_operating_system
            WITH SYNONYMS = ('operating system', 'os', 'platform')
            COMMENT = 'The operating system of the device (Windows, OS X, iOS, Android, etc.).',
        SOURCE_PROPERTIES.DEVICE_MANUFACTURER AS device_manufacturer
            WITH SYNONYMS = ('manufacturer', 'device brand')
            COMMENT = 'The manufacturer of the device (Apple, Samsung, Google, etc.).',
        SOURCE_PROPERTIES.DEVICE_MODEL AS device_model
            WITH SYNONYMS = ('model', 'phone model', 'device model')
            COMMENT = 'The model of the device (e.g. iPhone 15, Pixel 8).',
        SOURCE_PROPERTIES.DEVICE_SCREEN_WIDTH AS device_screen_width
            WITH SYNONYMS = ('screen width')
            COMMENT = 'The screen width of the device in pixels.',
        SOURCE_PROPERTIES.DEVICE_SCREEN_HEIGHT AS device_screen_height
            WITH SYNONYMS = ('screen height')
            COMMENT = 'The screen height of the device in pixels.',
        SOURCE_PROPERTIES.DEVICE_VIEWPORT_WIDTH AS device_viewport_width
            WITH SYNONYMS = ('viewport width', 'browser width')
            COMMENT = 'The width of the browser viewport in pixels.',
        SOURCE_PROPERTIES.DEVICE_VIEWPORT_HEIGHT AS device_viewport_height
            WITH SYNONYMS = ('viewport height', 'browser height')
            COMMENT = 'The height of the browser viewport in pixels.',
        SOURCE_PROPERTIES.DEVICE_OPERATING_SYSTEM AS device_operating_system
            WITH SYNONYMS = ('device os')
            COMMENT = 'The operating system reported by the device.',

        -- Mobile app context
        SOURCE_PROPERTIES.APP_NAME AS app_name
            WITH SYNONYMS = ('mobile app name', 'application name')
            COMMENT = 'The name of the mobile application.',
        SOURCE_PROPERTIES.APP_VERSION AS app_version
            WITH SYNONYMS = ('app build', 'mobile app version')
            COMMENT = 'The version string of the mobile application.',
        SOURCE_PROPERTIES.APP_PACKAGE_NAME AS app_package_name
            WITH SYNONYMS = ('bundle id', 'package name')
            COMMENT = 'The package name of the mobile app (e.g. com.company.app).',

        -- Integration context
        SOURCE_PROPERTIES.ENTRYPOINT AS entrypoint
            WITH SYNONYMS = ('event origin', 'capture method')
            COMMENT = 'How the event entered Fullstory: web client, FS trackEvent, POST /v2/users, etc.',
        SOURCE_PROPERTIES.ORIGIN AS origin
            WITH SYNONYMS = ('capture origin', 'event source origin')
            COMMENT = 'The origin of the event capture: dom or server.',
        SOURCE_PROPERTIES.INTEGRATION AS integration
            WITH SYNONYMS = ('sdk integration', 'capture integration')
            COMMENT = 'The integration that captured the event: fs, dlo, segment, zendesk, etc.',

        SOURCE_PROPERTIES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the event occurred.',

        -- =====================================================================
        -- USERS
        -- =====================================================================
        USERS.ID AS id
            WITH SYNONYMS = ('fullstory id', 'fs_uid', 'fullstory user id')
            COMMENT = 'Unique id assigned by Fullstory.',
        USERS.UID AS uid
            WITH SYNONYMS = ('app user id', 'customer user id', 'external id', 'identified user id')
            COMMENT = 'Unique id provided by the customer application (set via identify API).',
        USERS.USER_DISPLAY_NAME AS user_display_name
            WITH SYNONYMS = ('display name', 'name', 'username')
            COMMENT = 'The display name for the user, set via Fullstory API.',
        USERS.USER_EMAIL AS user_email
            WITH SYNONYMS = ('email', 'email address')
            COMMENT = 'The email address for the user, set via Fullstory API.',
        USERS.LAST_UPDATED_TIME AS last_updated_time
            WITH SYNONYMS = ('last active', 'last seen', 'last updated')
            COMMENT = 'The time the user record was last updated.',

        -- =====================================================================
        -- PAGE_DEFINITIONS 
        -- =====================================================================
        PAGE_DEFINITIONS.ID AS page_definition_lookup_id
            COMMENT = 'Unique identifier for the Named Page definition.',
        PAGE_DEFINITIONS.NAME AS page_definition_name
            WITH SYNONYMS = ('named page', 'page definition name', 'defined page name')
            COMMENT = 'The customer-defined name for this page.',
        PAGE_DEFINITIONS.DESCRIPTION AS page_definition_description
            COMMENT = 'A description of the Named Page.',
        PAGE_DEFINITIONS.STATE AS page_definition_state
            WITH SYNONYMS = ('page definition status')
            COMMENT = 'Whether the page definition is active or inactive.',

        -- =====================================================================
        -- ELEMENT_DEFINITIONS 
        -- =====================================================================
        ELEMENT_DEFINITIONS.ID AS element_definition_lookup_id
            COMMENT = 'Unique identifier for the Named Element definition.',
        ELEMENT_DEFINITIONS.NAME AS element_definition_name
            WITH SYNONYMS = ('named element', 'element definition name', 'defined element name')
            COMMENT = 'The customer-defined name for this element.',
        ELEMENT_DEFINITIONS.DESCRIPTION AS element_definition_description
            COMMENT = 'A description of the Named Element.',
        ELEMENT_DEFINITIONS.STATE AS element_definition_state
            WITH SYNONYMS = ('element definition status')
            COMMENT = 'Whether the element definition is active or inactive.',

        -- =====================================================================
        -- EVENT_DEFINITIONS 
        -- =====================================================================
        EVENT_DEFINITIONS.ID AS event_definition_lookup_id
            COMMENT = 'Unique identifier for the Defined Event.',
        EVENT_DEFINITIONS.NAME AS event_definition_name
            WITH SYNONYMS = ('defined event', 'event definition name', 'named event')
            COMMENT = 'The customer-defined name for this event definition.',
        EVENT_DEFINITIONS.DESCRIPTION AS event_definition_description
            COMMENT = 'A description of the Defined Event.',
        EVENT_DEFINITIONS.STATE AS event_definition_state
            WITH SYNONYMS = ('event definition status')
            COMMENT = 'Whether the event definition is active or inactive.',

        -- =====================================================================
        -- ELEMENT_PROPERTIES / PAGE_PROPERTIES / USER_PROPERTIES
        -- =====================================================================
        ELEMENT_PROPERTIES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        ELEMENT_PROPERTIES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the event occurred.',

        PAGE_PROPERTIES.EVENT_ID AS event_id
            COMMENT = 'Foreign key referencing the events fact table.',
        PAGE_PROPERTIES.SESSION_ID AS session_id
            COMMENT = 'A unique id corresponding to a single session.',
        PAGE_PROPERTIES.USER_ID AS user_id
            COMMENT = 'A unique id assigned to the user by Fullstory.',
        PAGE_PROPERTIES.EVENT_TIME AS event_time
            COMMENT = 'The time in UTC that the event occurred.',

        USER_PROPERTIES.USER_ID AS user_id
            WITH SYNONYMS = ('user identifier')
            COMMENT = 'Unique id for the related user.',
        USER_PROPERTIES.LAST_UPDATED_TIME AS last_updated_time
            COMMENT = 'The most recent time a user property was updated.'
    )
    METRICS (
        -- =====================================================================
        -- EVENTS
        -- =====================================================================
        EVENTS.EVENT_COUNT AS COUNT(ID)
            WITH SYNONYMS = ('number of events', 'total events', 'event volume')
            COMMENT = 'Total count of all events.',

        -- =====================================================================
        -- CLICKS
        -- =====================================================================
        CLICKS.CLICK_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('number of clicks', 'total clicks')
            COMMENT = 'Total count of click events.',
        CLICKS.RAGE_CLICK_COUNT AS SUM(fs_rage_count)
            WITH SYNONYMS = ('frustrated clicks', 'total rage clicks')
            COMMENT = 'Total count of rage click events (user frustration signal).',
        CLICKS.DEAD_CLICK_COUNT AS SUM(fs_dead_count)
            WITH SYNONYMS = ('unresponsive clicks', 'total dead clicks')
            COMMENT = 'Total count of dead click events (broken element signal).',
        CLICKS.LONG_CLICK_COUNT AS COUNT(CASE WHEN is_click_long = true THEN 1 END)
            WITH SYNONYMS = ('long press count')
            COMMENT = 'Count of long-press/long-click interactions.',
        CLICKS.UNHANDLED_CLICK_COUNT AS COUNT(CASE WHEN is_click_unhandled = true THEN 1 END)
            WITH SYNONYMS = ('no-handler clicks')
            COMMENT = 'Count of clicks on elements with no registered event handler.',

        -- =====================================================================
        -- PAGE_VIEWS
        -- =====================================================================
        PAGE_VIEWS.PAGE_VIEW_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('pvs', 'total page views', 'number of page views')
            COMMENT = 'Total count of page view events.',
        PAGE_VIEWS.AVG_TIME_ON_PAGE AS AVG(duration_millis)
            COMMENT = 'Average total time spent on a page in milliseconds.',
        PAGE_VIEWS.AVG_ACTIVE_TIME_ON_PAGE AS AVG(active_duration_millis)
            WITH SYNONYMS = ('average engagement time', 'avg active time')
            COMMENT = 'Average active (non-idle) time spent on a page in milliseconds.',
        PAGE_VIEWS.AVG_SCROLL_DEPTH AS AVG(max_scroll_depth)
            COMMENT = 'Average maximum scroll depth (0-1.0).',

        -- =====================================================================
        -- LOADS (Core Web Vitals: Loading)
        -- =====================================================================
        LOADS.AVG_LCP AS AVG(largest_paint_time_millis)
            WITH SYNONYMS = ('average largest contentful paint', 'average lcp')
            COMMENT = 'Average LCP in ms. Good < 2500ms.',
        LOADS.AVG_FCP AS AVG(first_paint_time_millis)
            WITH SYNONYMS = ('average first contentful paint', 'average fcp')
            COMMENT = 'Average FCP in ms. Good < 1800ms.',
        LOADS.AVG_TTFB AS AVG(time_to_first_byte_millis)
            WITH SYNONYMS = ('average time to first byte', 'average ttfb')
            COMMENT = 'Average TTFB in ms. Good < 800ms.',
        LOADS.AVG_TTI AS AVG(time_to_interactive_millis)
            WITH SYNONYMS = ('average time to interactive', 'average tti')
            COMMENT = 'Average TTI in ms. Good < 3800ms.',
        LOADS.AVG_TBT AS AVG(total_blocking_time_millis)
            WITH SYNONYMS = ('average total blocking time', 'average tbt')
            COMMENT = 'Average TBT in ms. Good < 200ms.',
        LOADS.AVG_DOM_CONTENT_TIME AS AVG(dom_content_time_millis)
            WITH SYNONYMS = ('average dom ready time')
            COMMENT = 'Average time for DOM construction to complete in ms.',
        LOADS.AVG_LOAD_TIME AS AVG(load_time_millis)
            WITH SYNONYMS = ('average page load time')
            COMMENT = 'Average full page load time in milliseconds.',
        LOADS.LOAD_EVENT_COUNT AS COUNT(event_id)
            COMMENT = 'Total count of page load events.',

        -- =====================================================================
        -- CORE WEB VITALS: Stability & Interactivity
        -- =====================================================================
        CUMULATIVE_LAYOUT_SHIFTS.AVG_CLS AS AVG(cumulative_layout_shift)
            WITH SYNONYMS = ('average cls', 'average cumulative layout shift')
            COMMENT = 'Average CLS score. Good < 0.1.',
        CUMULATIVE_LAYOUT_SHIFTS.MAX_CLS AS MAX(cumulative_layout_shift)
            WITH SYNONYMS = ('worst cls', 'maximum cls')
            COMMENT = 'Maximum (worst) CLS score recorded.',
        FIRST_INPUT_DELAYS.AVG_FID AS AVG(first_input_delay_millis)
            WITH SYNONYMS = ('average first input delay', 'average fid')
            COMMENT = 'Average FID in ms. Good < 100ms.',
        INTERACTION_TO_NEXT_PAINTS.AVG_INP AS AVG(interaction_to_next_paint_millis)
            WITH SYNONYMS = ('average inp', 'average interaction to next paint', 'average responsiveness')
            COMMENT = 'Average INP in ms. Good < 200ms. Primary interactivity Web Vital.',
        INTERACTION_TO_NEXT_PAINTS.MAX_INP AS MAX(interaction_to_next_paint_millis)
            WITH SYNONYMS = ('worst inp', 'maximum inp')
            COMMENT = 'Maximum (worst) INP recorded.',
        INTERACTION_TO_NEXT_PAINTS.INP_EVENT_COUNT AS COUNT(event_id)
            COMMENT = 'Total count of INP measurement events.',
        INTERACTION_TO_NEXT_PAINTS.POOR_INP_COUNT AS COUNT(CASE WHEN interaction_to_next_paint_millis > 500 THEN 1 END)
            WITH SYNONYMS = ('slow interactions', 'poor responsiveness count')
            COMMENT = 'Count of INP events exceeding 500ms (poor threshold).',

        -- =====================================================================
        -- FRUSTRATION SIGNALS
        -- =====================================================================
        MOUSE_THRASHES.MOUSE_THRASH_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('thrash count', 'total mouse thrashes', 'erratic mouse events')
            COMMENT = 'Total count of mouse thrash events (frustration signal).',
        FORM_ABANDONS.FORM_ABANDON_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('abandonments', 'total form abandons', 'form dropout count')
            COMMENT = 'Total count of form abandonment events.',
        FORM_INPUT_CHANGES.FORM_INPUT_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('total form inputs', 'form interaction count')
            COMMENT = 'Total count of form input change events.',

        -- =====================================================================
        -- ERRORS
        -- =====================================================================
        EXCEPTIONS.EXCEPTION_EVENT_COUNT AS COUNT(event_id)
            COMMENT = 'Total count of exception event records.',
        EXCEPTIONS.TOTAL_EXCEPTION_OCCURRENCES AS SUM(exception_count)
            WITH SYNONYMS = ('total errors thrown', 'total exceptions')
            COMMENT = 'Total exceptions thrown, accounting for batched bursts.',
        EXCEPTIONS.UNHANDLED_EXCEPTION_COUNT AS COUNT(CASE WHEN is_exception_handled = false THEN 1 END)
            WITH SYNONYMS = ('crashes', 'uncaught exceptions', 'unhandled errors')
            COMMENT = 'Count of unhandled (uncaught) exception events.',
        CONSOLE_MESSAGES.CONSOLE_MESSAGE_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('total console messages', 'console log count')
            COMMENT = 'Total count of browser console message events.',
        CRASHES.CRASH_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('total crashes', 'app crash count', 'mobile crashes')
            COMMENT = 'Total count of mobile application crash events.',
        REQUESTS.CLIENT_ERROR_COUNT AS COUNT(CASE WHEN STARTSWITH(request_status, '4') THEN 1 END)
            WITH SYNONYMS = ('4xx errors', 'client errors')
            COMMENT = 'Count of failed requests with 4xx client error status codes.',
        REQUESTS.SERVER_ERROR_COUNT AS COUNT(CASE WHEN STARTSWITH(request_status, '5') THEN 1 END)
            WITH SYNONYMS = ('5xx errors', 'server errors')
            COMMENT = 'Count of failed requests with 5xx server error status codes.',
        REQUESTS.TOTAL_FAILED_REQUESTS AS COUNT(event_id)
            WITH SYNONYMS = ('error count', 'failed request count', 'total api errors')
            COMMENT = 'Total count of failed HTTP requests (4xx and 5xx).',

        -- =====================================================================
        -- NAVIGATION
        -- =====================================================================
        NAVIGATES.NAVIGATE_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('total navigations', 'navigation count')
            COMMENT = 'Total count of navigation events.',
        NAVIGATES.RELOAD_COUNT AS COUNT(CASE WHEN navigate_reason = 'reload' THEN 1 END)
            WITH SYNONYMS = ('page reloads', 'total reloads')
            COMMENT = 'Count of page reload navigations.',
        NAVIGATES.BACK_FORWARD_COUNT AS COUNT(CASE WHEN navigate_reason = 'back_forward' THEN 1 END)
            WITH SYNONYMS = ('back button count', 'browser back count')
            COMMENT = 'Count of back/forward browser navigations.',

        -- =====================================================================
        -- ELEMENTS SEEN
        -- =====================================================================
        ELEMENTS_SEEN.ELEMENT_SEEN_COUNT AS COUNT(event_id)
           WITH SYNONYMS = ('total elements seen', 'watched element views')
           COMMENT = 'Total count of watched element visibility events.',
        ELEMENTS_SEEN.AVG_ELEMENT_RENDER_DURATION AS AVG(element_render_duration_millis)
           WITH SYNONYMS = ('average render time')
           COMMENT = 'Average time for watched elements to render in milliseconds.',
        ELEMENTS_SEEN.AVG_ELEMENT_VISIBLE_DURATION AS AVG(element_visible_duration_millis)
           WITH SYNONYMS = ('average visibility duration')
           COMMENT = 'Average time watched elements were visible in milliseconds.',

        -- =====================================================================
        -- CUSTOM EVENTS
        -- =====================================================================
        CUSTOM_EVENTS.CUSTOM_EVENT_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('total custom events', 'conversion event count')
            COMMENT = 'Total count of custom (conversion/product analytics) events.',

        -- =====================================================================
        -- DEVICE SEGMENTATION
        -- =====================================================================
        SOURCE_PROPERTIES.DESKTOP_EVENT_COUNT AS COUNT(CASE WHEN user_agent_device = 'Desktop' THEN 1 END)
            COMMENT = 'Count of events from desktop devices.',
        SOURCE_PROPERTIES.MOBILE_EVENT_COUNT AS COUNT(CASE WHEN user_agent_device IN ('Mobile', 'Tablet') THEN 1 END)
            COMMENT = 'Count of events from mobile and tablet devices.',

        -- =====================================================================
        -- USERS
        -- =====================================================================
        USERS.USER_COUNT AS COUNT(id)
            WITH SYNONYMS = ('total users', 'visitor count', 'unique users')
            COMMENT = 'Total count of unique user records.',
        USERS.IDENTIFIED_USER_COUNT AS COUNT(uid)
            WITH SYNONYMS = ('logged in users', 'identified users', 'known users')
            COMMENT = 'Count of users with a customer-provided UID (identified/logged-in users).',

        -- =====================================================================
        -- CLIPBOARD & INTERACTION
        -- =====================================================================
        -- COPIES.CLIPBOARD_COPY_COUNT AS COUNT(event_id),
        PASTES.PASTE_COUNT AS COUNT(event_id)
            WITH SYNONYMS = ('total pastes', 'clipboard paste count')
            COMMENT = 'Total count of paste events.',
        -- HIGHLIGHTS.HIGHLIGHT_COUNT AS COUNT(event_id),

        -- =====================================================================
        -- CONSENT
        -- =====================================================================
        CONSENTS.CONSENT_GIVEN_COUNT AS COUNT(CASE WHEN is_consent_given = true THEN 1 END)
            WITH SYNONYMS = ('consents granted', 'accepted consents')
            COMMENT = 'Count of consent events where the user granted consent.',
        CONSENTS.CONSENT_DENIED_COUNT AS COUNT(CASE WHEN is_consent_given = false THEN 1 END)
            WITH SYNONYMS = ('consents denied', 'rejected consents')
            COMMENT = 'Count of consent events where the user denied or revoked consent.',

        -- =====================================================================
        -- CORE WEB VITALS: INP 
        -- =====================================================================
        INTERACTION_TO_NEXT_PAINTS.P75_INP AS PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY interaction_to_next_paint_millis),

        -- =====================================================================
        -- PROPERTY TABLES
        -- =====================================================================
        ELEMENT_PROPERTIES.PROPERTY_UPDATE_COUNT AS COUNT(event_id)
            COMMENT = 'Total count of element property events.',
        PAGE_PROPERTIES.PAGE_PROPERTY_UPDATE_COUNT AS COUNT(event_id)
            COMMENT = 'Total count of page property events.',
        USER_PROPERTIES.USER_PROPERTY_COUNT AS COUNT(user_id)
            COMMENT = 'Total count of users in the properties table.'
    )
    COMMENT = 'Semantic model for Fullstory behavioral analytics data. Analyze user behavior, page performance (Core Web Vitals), frustration signals, errors, navigation, conversions, and session data across web and mobile.';

SELECT 'Semantic view created: {{DEPLOY_DB}}.{{DEPLOY_SCHEMA}}.{{SV_NAME}}' AS result;
