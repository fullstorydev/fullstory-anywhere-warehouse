"""Marketing attribution dashboard over fct_marketing_attribution.

Runs as a Streamlit in Snowflake app and uses get_active_session() for all
queries.

Tabs:
  Overview    — KPIs, daily revenue trend, source / medium split
  Channels    — top campaigns, model comparison, source x model pivot
  Paths       — top conversion paths, path-length and time-to-convert
                histograms, channel Sankey
  Conversions — conversion log with Fullstory session-replay links
"""

from datetime import date, timedelta

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
from snowflake.snowpark.context import get_active_session

# ── Page config ───────────────────────────────────────────────────────────────

st.set_page_config(
    page_title="Marketing Attribution",
    page_icon="📊",
    layout="wide",
)

MODELS = [
    "Linear",
    "First Touch",
    "Last Touch",
    "40-20-40 U-Shaped",
    "Full Credit",
]

MEDIUM_COLORS = {
    "cpc": "#EF553B",
    "organic": "#00CC96",
    "referral": "#AB63FA",
    "direct": "#636EFA",
}

# ── Session ───────────────────────────────────────────────────────────────────

session = get_active_session()


@st.cache_data(ttl=3600, show_spinner="Querying Snowflake…")
def run_query(sql: str) -> pd.DataFrame:
    """Run a query and return it with lowercase column names."""
    df = session.sql(sql).to_pandas()
    df.columns = df.columns.str.lower()
    return df


# ── Sidebar ───────────────────────────────────────────────────────────────────

with st.sidebar:
    st.title("Marketing Attribution")
    st.divider()

    today = date.today()
    date_range = st.date_input(
        "Conversion Date Range",
        value=(today - timedelta(days=30), today),
        max_value=today,
    )
    if len(date_range) != 2:
        st.stop()
    start_date, end_date = date_range

    model = st.selectbox("Attribution Model", MODELS)

    st.divider()
    fs_org_id = st.text_input(
        "Fullstory Org ID",
        placeholder="ACME-AB12C",
        help="Enables 'View Session' links in the Conversions tab.",
    )

# ── SQL queries ───────────────────────────────────────────────────────────────
# Dates and the model name come from controlled UI widgets — no user free-text input.

_DATE_FILTER = (
    f"converted_at::DATE >= '{start_date}' AND converted_at::DATE <= '{end_date}'"
)

FACT_SQL = f"""
SELECT
    user_id,
    session_id,
    session_start_time,
    converted_at,
    source,
    medium,
    campaign,
    total_sessions_for_conversion,
    session_number,
    is_conversion_session,
    attribution_model,
    attributed_revenue
FROM fs_marketing.marts.fct_marketing_attribution
WHERE attribution_model = '{model}'
  AND {_DATE_FILTER}
ORDER BY converted_at DESC, user_id, session_number
"""

COMPARE_SQL = f"""
SELECT
    attribution_model,
    medium,
    source,
    SUM(attributed_revenue) AS attributed_revenue
FROM fs_marketing.marts.fct_marketing_attribution
WHERE {_DATE_FILTER}
GROUP BY attribution_model, medium, source
"""

# Linear model is used for paths because it includes every contributing session.
# First/Last Touch only return the single credited session, making path
# reconstruction impossible for multi-touch journeys.
PATHS_SQL = f"""
SELECT
    user_id,
    session_id,
    session_start_time,
    converted_at,
    source,
    medium,
    campaign,
    total_sessions_for_conversion,
    session_number,
    is_conversion_session
FROM fs_marketing.marts.fct_marketing_attribution
WHERE attribution_model = 'Linear'
  AND {_DATE_FILTER}
ORDER BY user_id, converted_at, session_number
"""

# ── Load data ─────────────────────────────────────────────────────────────────

df = run_query(FACT_SQL)
df_compare = run_query(COMPARE_SQL)
df_paths = run_query(PATHS_SQL)

if df.empty:
    st.warning("No attribution data for the selected date range and model.")
    st.stop()

for _col in ["session_start_time", "converted_at"]:
    df[_col] = pd.to_datetime(df[_col])
    if not df_paths.empty:
        df_paths[_col] = pd.to_datetime(df_paths[_col])

df["converted_date"] = df["converted_at"].dt.date

# ── Pre-compute paths (shared by Paths + Conversions tabs) ────────────────────

paths_lookup: pd.DataFrame | None = None
first_touch_df: pd.DataFrame | None = None
avg_days_to_convert: float | None = None
df_paths_sorted: pd.DataFrame | None = None

if not df_paths.empty:
    df_paths_sorted = df_paths.sort_values(
        ["user_id", "converted_at", "session_number"]
    ).copy()
    df_paths_sorted["channel"] = (
        df_paths_sorted["source"] + "/" + df_paths_sorted["medium"]
    )

    paths_lookup = (
        df_paths_sorted.groupby(["user_id", "converted_at"], sort=False)["channel"]
        .agg(" → ".join)
        .reset_index(name="path")
    )

    first_touch_df = (
        df_paths_sorted.groupby(["user_id", "converted_at"])["session_start_time"]
        .min()
        .reset_index(name="first_touch_time")
    )
    first_touch_df["days_to_convert"] = (
        pd.to_datetime(first_touch_df["converted_at"])
        - first_touch_df["first_touch_time"]
    ).dt.total_seconds() / 86400
    avg_days_to_convert = first_touch_df["days_to_convert"].mean()

# ── KPI metrics ───────────────────────────────────────────────────────────────

# Count every conversion once regardless of model. Filtering on
# is_conversion_session would drop multi-touch conversions under First Touch,
# which only keeps the first session.
total_conversions = len(df.drop_duplicates(["user_id", "converted_at"]))
total_revenue = df["attributed_revenue"].sum()
avg_path_len = (
    df.groupby(["user_id", "converted_at"])["total_sessions_for_conversion"]
    .first()
    .mean()
)

# ── Header ────────────────────────────────────────────────────────────────────

st.title("Marketing Attribution Dashboard")
st.caption(
    f"**{model}** model  ·  {start_date:%b %d} – {end_date:%b %d, %Y}"  # noqa: RUF001
)
if model == "Full Credit":
    st.info(
        "Full Credit gives every channel in a path the full order value, so "
        "Attributed Revenue is higher than actual revenue. Use it to compare "
        "channels, not to report totals."
    )

k1, k2, k3, k4 = st.columns(4)
k1.metric("Conversions", f"{total_conversions:,}")
k2.metric("Attributed Revenue", f"${total_revenue:,.0f}")
k3.metric(
    "Avg Path Length",
    f"{avg_path_len:.1f} sessions" if pd.notna(avg_path_len) else "—",
)
k4.metric(
    "Avg Days to Convert",
    f"{avg_days_to_convert:.1f}"
    if avg_days_to_convert is not None and pd.notna(avg_days_to_convert)
    else "—",
)

st.divider()

tab_overview, tab_channels, tab_paths, tab_log = st.tabs(
    ["Overview", "Channels", "Paths", "Conversions"]
)

# ── Tab: Overview ─────────────────────────────────────────────────────────────

with tab_overview:
    daily = df.groupby("converted_date")["attributed_revenue"].sum().reset_index()
    fig_daily = px.bar(
        daily,
        x="converted_date",
        y="attributed_revenue",
        title="Daily Attributed Revenue",
        labels={"converted_date": "", "attributed_revenue": "Revenue ($)"},
        template="plotly_white",
    )
    st.plotly_chart(fig_daily, use_container_width=True)

    col_left, col_right = st.columns(2)

    with col_left:
        by_src = (
            df.groupby("source")["attributed_revenue"].sum().sort_values().reset_index()
        )
        fig_src = px.bar(
            by_src,
            x="attributed_revenue",
            y="source",
            orientation="h",
            title="Revenue by Source",
            labels={"attributed_revenue": "Revenue ($)", "source": ""},
            template="plotly_white",
        )
        st.plotly_chart(fig_src, use_container_width=True)

    with col_right:
        by_med = (
            df.groupby("medium")["attributed_revenue"]
            .sum()
            .sort_values(ascending=False)
            .reset_index()
        )
        fig_med = px.pie(
            by_med,
            values="attributed_revenue",
            names="medium",
            title="Revenue by Medium",
            template="plotly_white",
            hole=0.4,
            color="medium",
            color_discrete_map=MEDIUM_COLORS,
        )
        st.plotly_chart(fig_med, use_container_width=True)

# ── Tab: Channels ─────────────────────────────────────────────────────────────

with tab_channels:
    top_camps = (
        df.groupby("campaign")["attributed_revenue"]
        .sum()
        .nlargest(15)
        .sort_values()
        .reset_index()
    )
    fig_camps = px.bar(
        top_camps,
        x="attributed_revenue",
        y="campaign",
        orientation="h",
        title="Top 15 Campaigns by Attributed Revenue",
        labels={"attributed_revenue": "Revenue ($)", "campaign": ""},
        template="plotly_white",
    )
    st.plotly_chart(fig_camps, use_container_width=True)

    if not df_compare.empty:
        st.subheader("Model Comparison by Medium")
        st.caption(
            "Same date range, all attribution models. "
            "Shows how model choice shifts credit between channels."
        )
        model_med = (
            df_compare.groupby(["attribution_model", "medium"])["attributed_revenue"]
            .sum()
            .reset_index()
        )
        fig_cmp = px.bar(
            model_med,
            x="medium",
            y="attributed_revenue",
            color="attribution_model",
            barmode="group",
            title="Attributed Revenue by Medium — All Models",
            labels={
                "attributed_revenue": "Revenue ($)",
                "medium": "Medium",
                "attribution_model": "Model",
            },
            template="plotly_white",
        )
        st.plotly_chart(fig_cmp, use_container_width=True)

        st.subheader("Revenue by Source x Model")
        pivot = (
            df_compare.groupby(["source", "attribution_model"])["attributed_revenue"]
            .sum()
            .unstack("attribution_model")
            .fillna(0)
            .round(0)
            .astype(int)
        )
        st.dataframe(pivot, use_container_width=True)

# ── Tab: Paths ────────────────────────────────────────────────────────────────

with tab_paths:
    if paths_lookup is None or paths_lookup.empty:
        st.info("No path data available for this period.")
    else:
        st.subheader("Top Conversion Paths")
        path_counts = paths_lookup["path"].value_counts().head(20).reset_index()
        path_counts.columns = ["path", "conversions"]
        path_counts["share %"] = (
            path_counts["conversions"] / path_counts["conversions"].sum() * 100
        ).round(1)
        st.dataframe(path_counts, use_container_width=True, hide_index=True)

        col_h1, col_h2 = st.columns(2)

        with col_h1:
            path_len_data = (
                df_paths.groupby(["user_id", "converted_at"])[
                    "total_sessions_for_conversion"
                ]
                .first()
                .reset_index()
            )
            fig_plen = px.histogram(
                path_len_data,
                x="total_sessions_for_conversion",
                title="Path Length Distribution",
                labels={
                    "total_sessions_for_conversion": "Touchpoints before Conversion",
                    "count": "Conversions",
                },
                template="plotly_white",
                nbins=20,
            )
            st.plotly_chart(fig_plen, use_container_width=True)

        with col_h2:
            if first_touch_df is not None:
                fig_ttc = px.histogram(
                    first_touch_df,
                    x="days_to_convert",
                    title="Days from First Touch to Conversion",
                    labels={"days_to_convert": "Days", "count": "Conversions"},
                    template="plotly_white",
                    nbins=30,
                )
                st.plotly_chart(fig_ttc, use_container_width=True)

        # Channel flow Sankey — position-aware nodes prevent self-loop blobs.
        # Each node is "{medium} · step {N}" so direct→direct becomes two
        # distinct columns and the graph flows strictly left-to-right.
        st.subheader("Channel Flow")
        st.caption(
            "Each column is one step in the conversion path. "
            "Capped at the first 5 touchpoints."
        )

        MAX_STEPS = 5
        CONVERSION_NODE = "Conversion"
        transitions: list[tuple[str, str]] = []
        for _, grp in df_paths_sorted.groupby(["user_id", "converted_at"], sort=False):
            meds = grp["medium"].tolist()[:MAX_STEPS]
            for i in range(len(meds) - 1):
                src_node = f"{meds[i]}  ·  step {i + 1}"
                tgt_node = f"{meds[i + 1]}  ·  step {i + 2}"
                transitions.append((src_node, tgt_node))
            # Terminal link: last step → Conversion
            last_step = len(meds)
            transitions.append((f"{meds[-1]}  ·  step {last_step}", CONVERSION_NODE))

        if transitions:
            t_df = pd.DataFrame(transitions, columns=["from", "to"])
            t_agg = t_df.groupby(["from", "to"]).size().reset_index(name="count")

            # Build ordered node list — channel·step nodes sort by step number,
            # Conversion node is pinned last.
            channel_nodes = [
                n
                for n in dict.fromkeys(t_agg["from"].tolist() + t_agg["to"].tolist())
                if n != CONVERSION_NODE
            ]
            channel_nodes.sort(key=lambda n: int(n.split("step ")[-1]))
            all_nodes = [*channel_nodes, CONVERSION_NODE]
            node_idx = {n: i for i, n in enumerate(all_nodes)}

            def node_color(label: str) -> str:
                """Return the medium color for a node, green for Conversion."""
                if label == CONVERSION_NODE:
                    return "#2CA02C"  # green = goal
                for med, color in MEDIUM_COLORS.items():
                    if label.startswith(med):
                        return color
                return "#888888"

            fig_sankey = go.Figure(
                go.Sankey(
                    arrangement="snap",
                    # Plotly's default label halo is built for dark themes and
                    # blurs the text on a white background.
                    textfont={"color": "#1f2937", "size": 12, "shadow": "none"},
                    node={
                        "label": all_nodes,
                        "color": [node_color(n) for n in all_nodes],
                        "pad": 20,
                        "thickness": 18,
                    },
                    link={
                        "source": [node_idx[s] for s in t_agg["from"]],
                        "target": [node_idx[t] for t in t_agg["to"]],
                        "value": t_agg["count"].tolist(),
                        "color": [
                            "rgba(44,160,44,0.25)"
                            if t == CONVERSION_NODE
                            else "rgba(180,180,180,0.25)"
                            for t in t_agg["to"]
                        ],
                    },
                )
            )
            fig_sankey.update_layout(
                title_text="Channel path to Conversion (first 5 steps)",
                height=440,
                template="plotly_white",
            )
            st.plotly_chart(fig_sankey, use_container_width=True)
            st.caption(
                "Each column is one touchpoint step. Flow width = number of users. "
                "All paths terminate at **Conversion** (green)."
            )
        else:
            st.info(
                "All conversions in this window are single-touch, so there are "
                "no transitions to display."
            )

# ── Tab: Conversions ──────────────────────────────────────────────────────────

with tab_log:
    st.subheader("Conversion Log")

    # Build the log from the Linear rows: they hold every session, so the last
    # one is always present, unlike First Touch.
    conv_df = (
        df_paths[df_paths["is_conversion_session"]]
        .drop_duplicates(["user_id", "converted_at"])
        .copy()
        .sort_values("converted_at", ascending=False)
    )
    revenue_by_conversion = (
        df.groupby(["user_id", "converted_at"])["attributed_revenue"]
        .sum()
        .reset_index()
    )
    conv_df = conv_df.merge(
        revenue_by_conversion, on=["user_id", "converted_at"], how="left"
    )

    if paths_lookup is not None:
        conv_df = conv_df.merge(
            paths_lookup, on=["user_id", "converted_at"], how="left"
        )
    else:
        conv_df["path"] = conv_df["source"] + "/" + conv_df["medium"]

    display = conv_df[
        [
            "converted_at",
            "user_id",
            "attributed_revenue",
            "total_sessions_for_conversion",
            "path",
            "session_id",
        ]
    ].rename(
        columns={
            "converted_at": "Converted At",
            "user_id": "User ID",
            "attributed_revenue": "Revenue",
            "total_sessions_for_conversion": "Path Length",
            "path": "Touchpoint Path",
            "session_id": "Session ID",
        }
    )

    col_cfg: dict = {
        "Revenue": st.column_config.NumberColumn("Revenue", format="$%.0f"),
        "Converted At": st.column_config.DatetimeColumn(
            "Converted At", format="MMM DD, YYYY HH:mm"
        ),
    }

    if fs_org_id:
        display["Fullstory"] = display["Session ID"].apply(
            lambda sid: (
                f"https://app.fullstory.com/ui/{fs_org_id}/session/{sid}"
                if sid
                else None
            )
        )
        col_cfg["Fullstory"] = st.column_config.LinkColumn(
            "Fullstory", display_text="View Session"
        )
        display = display.drop(columns=["Session ID"])
    else:
        st.caption(
            "Enter your Fullstory Org ID in the sidebar to enable session-replay links."
        )

    st.dataframe(
        display,
        use_container_width=True,
        hide_index=True,
        column_config=col_cfg,
    )
