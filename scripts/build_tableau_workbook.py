#!/usr/bin/env python3
"""Build a portable Tableau workbook from the verified portfolio CSV extracts.

The generated TWB contains native Tableau worksheets and a fixed executive
dashboard. The TWBX packages the same workbook with its five local CSV data
sources so it can be opened without access to the BigQuery project.
"""

from __future__ import annotations

import csv
import shutil
import tempfile
import uuid
import zipfile
from pathlib import Path

from lxml import etree


ROOT = Path(__file__).resolve().parents[1]
TABLEAU_DIR = ROOT / "tableau"
DATA_DIR = TABLEAU_DIR / "Data"
TWB_PATH = TABLEAU_DIR / "Ecommerce_Marketing_Executive_Dashboard.twb"
TWBX_PATH = TABLEAU_DIR / "Ecommerce_Marketing_Executive_Dashboard.twbx"
WORKBOOK_VERSION = "18.1"
NS_USER = "http://www.tableausoftware.com/xml/user"

SOURCE_SPECS = {
    "scorecard": {
        "caption": "Executive Scorecard",
        "file": "portfolio_executive_scorecard.csv",
        "types": {
            "min_session_date": "date",
            "max_session_date": "date",
            "sessions": "integer",
            "users": "integer",
            "purchase_sessions": "integer",
            "governed_orders": "integer",
            "revenue_usd": "real",
        },
    },
    "trend": {
        "caption": "Weekly Trend",
        "file": "portfolio_weekly_trend.csv",
        "types": {
            "week_start": "date",
            "sessions": "integer",
            "revenue_usd": "real",
            "session_conversion_rate": "real",
            "governed_orders": "integer",
            "zero_revenue_orders": "integer",
        },
    },
    "funnel": {
        "caption": "Conversion Funnel",
        "file": "portfolio_funnel.csv",
        "types": {
            "stage_order": "integer",
            "stage": "string",
            "sessions": "integer",
            "step_conversion_rate": "real",
            "step_dropoff_rate": "real",
        },
    },
    "channel": {
        "caption": "Channel Performance",
        "file": "portfolio_channel_performance.csv",
        "types": {
            "acquisition_channel": "string",
            "sessions": "integer",
            "purchase_sessions": "integer",
            "transactions": "integer",
            "revenue_usd": "real",
            "session_conversion_rate": "real",
            "average_order_value_usd": "real",
            "revenue_per_session_usd": "real",
        },
    },
    "user_type": {
        "caption": "Customer Segment",
        "file": "portfolio_user_type.csv",
        "types": {
            "user_type": "string",
            "sessions": "integer",
            "users": "integer",
            "purchase_sessions": "integer",
            "transactions": "integer",
            "revenue_usd": "real",
            "session_conversion_rate": "real",
            "average_order_value_usd": "real",
        },
    },
}

REMOTE_TYPES = {"string": "129", "integer": "20", "real": "5", "date": "133"}
DEFAULT_FORMATS = {
    "revenue_usd": 'c"$"#,##0;("$"#,##0)',
    "average_order_value_usd": 'c"$"#,##0.00;("$"#,##0.00)',
    "revenue_per_session_usd": 'c"$"#,##0.00;("$"#,##0.00)',
    "session_conversion_rate": "p0.00%",
    "step_conversion_rate": "p0.00%",
    "step_dropoff_rate": "p0.00%",
}

FIELD_CAPTIONS = {
    "acquisition_channel": "Acquisition Channel",
    "average_order_value_usd": "Average Order Value (USD)",
    "revenue_per_session_usd": "Revenue per Session (USD)",
    "revenue_usd": "Revenue (USD)",
    "session_conversion_rate": "Session Conversion Rate",
    "user_type": "Session Type",
    "week_start": "Week",
}


def element(parent: etree._Element, tag: str, **attrs: str) -> etree._Element:
    return etree.SubElement(parent, tag, {key.replace("_", "-"): str(value) for key, value in attrs.items()})


def stable_uuid(name: str) -> str:
    return "{" + str(uuid.uuid5(uuid.NAMESPACE_URL, f"portfolio-tableau:{name}")).upper() + "}"


def field_role(datatype: str) -> tuple[str, str]:
    if datatype == "string":
        return "dimension", "nominal"
    if datatype == "date":
        return "dimension", "quantitative"
    return "measure", "quantitative"


def add_column(parent: etree._Element, name: str, datatype: str, caption: str | None = None) -> etree._Element:
    role, field_type = field_role(datatype)
    attrs = {"datatype": datatype, "name": f"[{name}]", "role": role, "type": field_type}
    if caption:
        attrs["caption"] = caption
    if name in DEFAULT_FORMATS:
        attrs["default-format"] = DEFAULT_FORMATS[name]
    return element(parent, "column", **attrs)


def add_datasource(datasources: etree._Element, key: str, spec: dict[str, object]) -> None:
    ds_name = f"federated.portfolio_{key}"
    connection_name = f"textscan.portfolio_{key}"
    filename = str(spec["file"])
    relation_name = filename
    table_name = f"[{Path(filename).stem}#csv]"
    datasource = element(
        datasources,
        "datasource",
        caption=str(spec["caption"]),
        inline="true",
        name=ds_name,
        version=WORKBOOK_VERSION,
    )
    connection = element(datasource, "connection", **{"class": "federated"})
    named_connections = element(connection, "named-connections")
    named_connection = element(
        named_connections,
        "named-connection",
        caption=str(spec["caption"]),
        name=connection_name,
    )
    element(
        named_connection,
        "connection",
        **{
            "class": "textscan",
            "directory": "Data",
            "filename": filename,
            "password": "",
            "server": "",
        },
    )

    relation = element(
        connection,
        "relation",
        connection=connection_name,
        name=relation_name,
        table=table_name,
        type="table",
    )
    columns = element(relation, "columns", character_set="UTF-8", header="yes", locale="en_US", separator=",")
    for ordinal, (name, datatype) in enumerate(spec["types"].items()):
        element(columns, "column", datatype=datatype, name=name, ordinal=str(ordinal))

    metadata_records = element(connection, "metadata-records")
    capability = element(metadata_records, "metadata-record", **{"class": "capability"})
    element(capability, "remote-name")
    element(capability, "remote-type").text = "0"
    element(capability, "parent-name").text = f"[{relation_name}]"
    element(capability, "remote-alias")
    element(capability, "aggregation").text = "Count"
    element(capability, "contains-null").text = "true"
    attributes = element(capability, "attributes")
    for name, value in (
        ("character-set", '"UTF-8"'),
        ("field-delimiter", '","'),
        ("header-row", '"true"'),
        ("locale", '"en_US"'),
    ):
        attr = element(attributes, "attribute", datatype="string", name=name)
        attr.text = value

    object_id = f"{Path(filename).stem.upper()}_PORTFOLIO"
    for ordinal, (name, datatype) in enumerate(spec["types"].items()):
        record = element(metadata_records, "metadata-record", **{"class": "column"})
        element(record, "remote-name").text = name
        element(record, "remote-type").text = REMOTE_TYPES[datatype]
        element(record, "local-name").text = f"[{name}]"
        element(record, "parent-name").text = f"[{relation_name}]"
        element(record, "remote-alias").text = name
        element(record, "ordinal").text = str(ordinal)
        element(record, "local-type").text = datatype
        element(record, "aggregation").text = "Year" if datatype == "date" else ("Count" if datatype == "string" else "Sum")
        element(record, "contains-null").text = "true"

    element(datasource, "aliases", enabled="yes")
    for name, datatype in spec["types"].items():
        caption = FIELD_CAPTIONS.get(name, name.replace("_", " ").title())
        add_column(datasource, name, datatype, caption)

    if key == "scorecard":
        conversion = element(
            datasource,
            "column",
            caption="Session Conversion Rate",
            datatype="real",
            default_format="p0.00%",
            name="[Calculation_SessionConversion]",
            role="measure",
            type="quantitative",
        )
        element(conversion, "calculation", **{"class": "tableau", "formula": "SUM([purchase_sessions]) / SUM([sessions])"})
        aov = element(
            datasource,
            "column",
            caption="Average Order Value",
            datatype="real",
            default_format='c"$"#,##0.00;("$"#,##0.00)',
            name="[Calculation_AOV]",
            role="measure",
            type="quantitative",
        )
        element(aov, "calculation", **{"class": "tableau", "formula": "SUM([revenue_usd]) / SUM([governed_orders])"})
        note = element(
            datasource,
            "column",
            caption="Executive Recommendations",
            datatype="string",
            name="[Calculation_ExecutiveNote]",
            role="dimension",
            type="nominal",
        )
        element(
            note,
            "calculation",
            **{
                "class": "tableau",
                "formula": '"1  Validate and test product-view-to-cart friction.   2  Run a measured second-purchase lifecycle test.   3  Repair late-January purchase-value tracking before revenue or channel decisions.   Revenue completeness warning: 218 of 321 orders in the week of Jan 25 record $0 revenue."',
            },
        )

    element(
        datasource,
        "layout",
        dim_ordering="alphabetic",
        dim_percentage="0.5",
        measure_ordering="alphabetic",
        measure_percentage="0.5",
        show_structure="true",
    )


def add_dependency_column(parent: etree._Element, field: str, datatype: str) -> None:
    caption = FIELD_CAPTIONS.get(field, field.replace("_", " ").title())
    add_column(parent, field, datatype, caption)


def add_instance(parent: etree._Element, field: str, derivation: str, kind: str) -> str:
    prefix = {"Sum": "sum", "Min": "min", "None": "none", "User": "usr"}[derivation]
    suffix = "nk" if kind == "nominal" else "qk"
    instance_name = f"[{prefix}:{field}:{suffix}]"
    element(
        parent,
        "column-instance",
        column=f"[{field}]",
        derivation=derivation,
        name=instance_name,
        pivot="key",
        type=kind,
    )
    return instance_name


def add_worksheet(
    worksheets: etree._Element,
    *,
    name: str,
    title: str,
    datasource_key: str,
    fields: list[tuple[str, str, str, str]],
    rows: list[str] | None = None,
    cols: list[str] | None = None,
    mark: str = "Automatic",
    text_field: str | None = None,
    color: str = "#2F65E5",
    sort: tuple[str, str, str] | None = None,
    font_size: str | None = None,
    show_labels: bool = True,
) -> None:
    ds_name = f"federated.portfolio_{datasource_key}"
    caption = str(SOURCE_SPECS[datasource_key]["caption"])
    worksheet = element(worksheets, "worksheet", name=name)
    layout = element(worksheet, "layout-options")
    title_node = element(layout, "title")
    formatted = element(title_node, "formatted-text")
    run = element(formatted, "run")
    run.text = title

    table = element(worksheet, "table")
    view = element(table, "view")
    refs = element(view, "datasources")
    element(refs, "datasource", caption=caption, name=ds_name)
    dependencies = element(view, "datasource-dependencies", datasource=ds_name)
    instances: dict[str, str] = {}
    for field, datatype, derivation, kind in fields:
        if field.startswith("Calculation_"):
            calc_attrs = {
                "caption": field.replace("Calculation_", "").replace("_", " "),
                "datatype": datatype,
                "name": f"[{field}]",
                "role": "dimension" if datatype == "string" else "measure",
                "type": kind,
            }
            if field == "Calculation_SessionConversion":
                calc_attrs["default-format"] = "p0.00%"
                formula = "SUM([purchase_sessions]) / SUM([sessions])"
            elif field == "Calculation_AOV":
                calc_attrs["default-format"] = 'c"$"#,##0.00;("$"#,##0.00)'
                formula = "SUM([revenue_usd]) / SUM([governed_orders])"
            else:
                formula = '"1  Validate and test product-view-to-cart friction.   2  Run a measured second-purchase lifecycle test.   3  Repair late-January purchase-value tracking before revenue or channel decisions.   Revenue completeness warning: 218 of 321 orders in the week of Jan 25 record $0 revenue."'
            calc = element(dependencies, "column", **calc_attrs)
            element(calc, "calculation", **{"class": "tableau", "formula": formula})
        else:
            add_dependency_column(dependencies, field, datatype)
        instances[field] = add_instance(dependencies, field, derivation, kind)
    if sort:
        target, direction, using = sort
        element(
            view,
            "sort",
            **{
                "class": "computed",
                "column": f"[{ds_name}].{instances[target]}",
                "direction": direction,
                "using": f"[{ds_name}].{instances[using]}",
            },
        )
    element(view, "aggregation", value="true")
    table_style = element(table, "style")
    if rows:
        axis_rule = element(table_style, "style-rule", element="axis")
        for field in rows:
            element(
                axis_rule,
                "format",
                attr="title",
                **{
                    "class": "0",
                    "field": f"[{ds_name}].{instances[field]}",
                    "scope": "rows",
                    "value": "",
                },
            )

    panes = element(table, "panes")
    pane = element(panes, "pane", selection_relaxation_option="selection-relaxation-allow")
    pane_view = element(pane, "view")
    element(pane_view, "breakdown", value="auto")
    element(pane, "mark", **{"class": "Automatic"})
    encodings = element(pane, "encodings")
    if text_field:
        element(encodings, "text", column=f"[{ds_name}].{instances[text_field]}")
    pane_style = element(pane, "style")
    mark_rule = element(pane_style, "style-rule", element="mark")
    element(mark_rule, "format", attr="color", value=color)
    element(mark_rule, "format", attr="mark-labels-show", value="true" if show_labels else "false")
    if show_labels:
        element(mark_rule, "format", attr="mark-labels-cull", value="false")
    if font_size:
        element(mark_rule, "format", attr="font-size", value=font_size)

    def shelf(values: list[str] | None) -> str:
        if not values:
            return ""
        return " / ".join(f"[{ds_name}].{instances[value]}" for value in values)

    element(table, "rows").text = shelf(rows)
    element(table, "cols").text = shelf(cols)
    element(worksheet, "simple-id", uuid=stable_uuid(name))


def add_dashboard(root: etree._Element, sheet_names: list[str]) -> None:
    dashboards = element(root, "dashboards")
    dashboard = element(dashboards, "dashboard", name="Executive Dashboard")
    layout = element(dashboard, "layout-options")
    title = element(layout, "title")
    formatted = element(title, "formatted-text")
    title_run = element(formatted, "run")
    title_run.text = "Customer Journey & Marketing Performance"
    subtitle = element(formatted, "run")
    subtitle.text = "\nGA4 public e-commerce sample | Nov 1, 2020–Jan 31, 2021 | Verified BigQuery metrics"
    element(dashboard, "style")
    element(dashboard, "size", maxheight="850", maxwidth="1300", minheight="850", minwidth="1300")
    zones = element(dashboard, "zones")
    container = element(zones, "zone", type="layout-basic", h="100000", id="1", w="100000", x="0", y="0")

    header_zone = element(container, "zone", h="7000", id="12", type="text", w="100000", x="0", y="0")
    header_text = element(header_zone, "formatted-text")
    header_title = element(header_text, "run", bold="true", fontcolor="#16233F", fontsize="16")
    header_title.text = "MARKETING PERFORMANCE OVERVIEW"
    header_subtitle = element(header_text, "run", fontcolor="#65728A", fontsize="9")
    header_subtitle.text = "\nGA4 public e-commerce sample | Nov 1, 2020–Jan 31, 2021 | Verified BigQuery metrics"
    header_style = element(header_zone, "zone-style")
    element(header_style, "format", attr="color", value="#FFFFFF")
    element(header_style, "format", attr="margin", value="8")

    zone_specs = [
        ("Revenue KPI", 2, 0, 7000, 25000, 14000),
        ("Sessions KPI", 3, 25000, 7000, 25000, 14000),
        ("Conversion KPI", 4, 50000, 7000, 25000, 14000),
        ("AOV KPI", 5, 75000, 7000, 25000, 14000),
        ("Weekly Revenue", 6, 0, 21000, 60000, 21000),
        ("Weekly Conversion", 7, 0, 42000, 60000, 18000),
        ("Conversion Funnel", 8, 60000, 21000, 40000, 39000),
        ("Channel Performance", 9, 0, 60000, 56000, 29000),
        ("Customer Segment", 10, 56000, 60000, 44000, 29000),
    ]
    for name, zone_id, x, y, width, height in zone_specs:
        zone = element(
            container,
            "zone",
            h=str(height),
            id=str(zone_id),
            name=name,
            w=str(width),
            x=str(x),
            y=str(y),
        )
        zone_style = element(zone, "zone-style")
        element(zone_style, "format", attr="border-color", value="#D8E0EC")
        element(zone_style, "format", attr="border-style", value="solid")
        element(zone_style, "format", attr="border-width", value="1")
        element(zone_style, "format", attr="margin", value="6")

    recommendation_zone = element(
        container,
        "zone",
        h="11000",
        id="13",
        type="text",
        w="100000",
        x="0",
        y="89000",
    )
    recommendation_text = element(recommendation_zone, "formatted-text")
    recommendation_title = element(
        recommendation_text,
        "run",
        bold="true",
        fontcolor="#16233F",
        fontsize="11",
    )
    recommendation_title.text = "RECOMMENDED DECISIONS"
    recommendation_body = element(recommendation_text, "run", fontcolor="#33415C", fontsize="9")
    recommendation_body.text = (
        "\n1  Validate and test product-view-to-cart friction.   "
        "2  Run a measured second-purchase lifecycle test.   "
        "3  Repair late-January purchase-value tracking before revenue or channel decisions."
    )
    recommendation_warning = element(recommendation_text, "run", bold="true", fontcolor="#C85C4A", fontsize="9")
    recommendation_warning.text = (
        "\nDATA WARNING  218 of 321 governed orders in the week of Jan 25 record $0 revenue."
    )
    recommendation_style = element(recommendation_zone, "zone-style")
    element(recommendation_style, "format", attr="border-color", value="#D8E0EC")
    element(recommendation_style, "format", attr="border-style", value="solid")
    element(recommendation_style, "format", attr="border-width", value="1")
    element(recommendation_style, "format", attr="color", value="#FFFFFF")
    element(recommendation_style, "format", attr="margin", value="8")
    container_style = element(container, "zone-style")
    element(container_style, "format", attr="color", value="#F4F7FB")
    element(container_style, "format", attr="margin", value="8")
    element(dashboard, "simple-id", uuid=stable_uuid("Executive Dashboard"))

    windows = element(root, "windows", source_height="28")
    window = element(windows, "window", **{"class": "dashboard", "maximized": "true", "name": "Executive Dashboard"})
    viewpoints = element(window, "viewpoints")
    for sheet_name in sheet_names:
        viewpoint = element(viewpoints, "viewpoint", name=sheet_name)
        element(viewpoint, "zoom", type="entire-view")
    element(window, "active", id="2")
    element(window, "simple-id", uuid=stable_uuid("Executive Dashboard Window"))


def build_workbook() -> etree._ElementTree:
    root = etree.Element(
        "workbook",
        {
            "original-version": WORKBOOK_VERSION,
            "source-build": "2021.1.2 (20211.21.0511.0935)",
            "source-platform": "mac",
            "version": WORKBOOK_VERSION,
        },
        nsmap={"user": NS_USER},
    )
    manifest = element(root, "document-format-change-manifest")
    element(manifest, "SheetIdentifierTracking")
    element(manifest, "WindowsPersistSimpleIdentifiers")
    preferences = element(root, "preferences")
    element(preferences, "preference", name="ui.encoding.shelf.height", value="24")
    element(preferences, "preference", name="ui.shelf.height", value="26")
    element(root, "style")

    datasources = element(root, "datasources")
    for key, spec in SOURCE_SPECS.items():
        add_datasource(datasources, key, spec)

    worksheets = element(root, "worksheets")
    add_worksheet(
        worksheets,
        name="Revenue KPI",
        title="REVENUE",
        datasource_key="scorecard",
        fields=[("revenue_usd", "real", "Sum", "quantitative")],
        mark="Text",
        text_field="revenue_usd",
        font_size="24",
    )
    add_worksheet(
        worksheets,
        name="Sessions KPI",
        title="SESSIONS",
        datasource_key="scorecard",
        fields=[("sessions", "integer", "Sum", "quantitative")],
        mark="Text",
        text_field="sessions",
        font_size="24",
    )
    add_worksheet(
        worksheets,
        name="Conversion KPI",
        title="CVR",
        datasource_key="scorecard",
        fields=[
            ("sessions", "integer", "Sum", "quantitative"),
            ("purchase_sessions", "integer", "Sum", "quantitative"),
            ("Calculation_SessionConversion", "real", "User", "quantitative"),
        ],
        mark="Text",
        text_field="Calculation_SessionConversion",
        color="#149C8A",
        font_size="24",
    )
    add_worksheet(
        worksheets,
        name="AOV KPI",
        title="AOV",
        datasource_key="scorecard",
        fields=[
            ("revenue_usd", "real", "Sum", "quantitative"),
            ("governed_orders", "integer", "Sum", "quantitative"),
            ("Calculation_AOV", "real", "User", "quantitative"),
        ],
        mark="Text",
        text_field="Calculation_AOV",
        font_size="24",
    )
    add_worksheet(
        worksheets,
        name="Weekly Revenue",
        title="Holiday peak followed by softer January revenue",
        datasource_key="trend",
        fields=[("week_start", "date", "None", "quantitative"), ("revenue_usd", "real", "Sum", "quantitative")],
        cols=["week_start"],
        rows=["revenue_usd"],
        mark="Line",
        show_labels=False,
    )
    add_worksheet(
        worksheets,
        name="Weekly Conversion",
        title="Weekly session conversion rate",
        datasource_key="trend",
        fields=[
            ("week_start", "date", "None", "quantitative"),
            ("session_conversion_rate", "real", "Min", "quantitative"),
        ],
        cols=["week_start"],
        rows=["session_conversion_rate"],
        mark="Line",
        color="#149C8A",
        show_labels=False,
    )
    add_worksheet(
        worksheets,
        name="Conversion Funnel",
        title="The largest step loss occurs before cart",
        datasource_key="funnel",
        fields=[
            ("stage", "string", "None", "nominal"),
            ("sessions", "integer", "Sum", "quantitative"),
            ("stage_order", "integer", "Sum", "quantitative"),
        ],
        rows=["stage"],
        cols=["sessions"],
        mark="Bar",
        text_field="sessions",
        sort=("stage", "ASC", "stage_order"),
    )
    add_worksheet(
        worksheets,
        name="Channel Performance",
        title="Organic leads revenue; Referral leads efficiency",
        datasource_key="channel",
        fields=[
            ("acquisition_channel", "string", "None", "nominal"),
            ("revenue_usd", "real", "Sum", "quantitative"),
        ],
        rows=["acquisition_channel"],
        cols=["revenue_usd"],
        mark="Bar",
        text_field="revenue_usd",
        sort=("acquisition_channel", "DESC", "revenue_usd"),
    )
    add_worksheet(
        worksheets,
        name="Customer Segment",
        title="Returning sessions concentrate value",
        datasource_key="user_type",
        fields=[("user_type", "string", "None", "nominal"), ("revenue_usd", "real", "Sum", "quantitative")],
        rows=["user_type"],
        cols=["revenue_usd"],
        mark="Bar",
        text_field="revenue_usd",
        color="#149C8A",
        sort=("user_type", "DESC", "revenue_usd"),
    )
    add_worksheet(
        worksheets,
        name="Executive Recommendations",
        title="RECOMMENDED DECISIONS",
        datasource_key="scorecard",
        fields=[("Calculation_ExecutiveNote", "string", "User", "nominal")],
        mark="Text",
        text_field="Calculation_ExecutiveNote",
        color="#16233F",
        font_size="9",
    )
    sheet_names = [sheet.get("name") for sheet in worksheets]
    add_dashboard(root, sheet_names)
    return etree.ElementTree(root)


def verify_inputs() -> None:
    for spec in SOURCE_SPECS.values():
        source = ROOT / "exports" / str(spec["file"])
        if not source.exists():
            raise FileNotFoundError(source)
        with source.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            missing = set(spec["types"]) - set(reader.fieldnames or [])
            if missing:
                raise ValueError(f"{source.name} is missing required fields: {sorted(missing)}")
            if not next(reader, None):
                raise ValueError(f"{source.name} has no data rows")


def write_outputs(tree: etree._ElementTree) -> None:
    TABLEAU_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    for spec in SOURCE_SPECS.values():
        shutil.copy2(ROOT / "exports" / str(spec["file"]), DATA_DIR / str(spec["file"]))
    tree.write(TWB_PATH, encoding="utf-8", xml_declaration=True, pretty_print=True)

    with tempfile.TemporaryDirectory(prefix="portfolio-tableau-") as temp_dir:
        package_root = Path(temp_dir)
        shutil.copy2(TWB_PATH, package_root / TWB_PATH.name)
        package_data = package_root / "Data"
        package_data.mkdir()
        for spec in SOURCE_SPECS.values():
            shutil.copy2(DATA_DIR / str(spec["file"]), package_data / str(spec["file"]))
        with zipfile.ZipFile(TWBX_PATH, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(package_root / TWB_PATH.name, TWB_PATH.name)
            for source in sorted(package_data.iterdir()):
                archive.write(source, f"Data/{source.name}")


def main() -> None:
    verify_inputs()
    workbook = build_workbook()
    write_outputs(workbook)
    print(TWB_PATH)
    print(TWBX_PATH)


if __name__ == "__main__":
    main()
