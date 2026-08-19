# KPI Definitions

All funnel KPIs use a **session** denominator unless explicitly labeled user- or order-based. Session-level funnel flags are deduplicated before aggregation, preventing repeated events from inflating conversion.

| KPI | Business definition | SQL definition | Primary grain | Caveat |
|---|---|---|---|---|
| Users | Distinct pseudonymous visitors | `COUNT(DISTINCT user_pseudo_id)` | Filter context | Not cross-device people |
| Sessions | Distinct GA4 user-session keys | `COUNT(DISTINCT CONCAT(user_pseudo_id, ga_session_id))` | Session | Events without `ga_session_id` are excluded from session marts |
| Product-view sessions | Sessions with at least one `view_item` | `SUM(has_product_view)` | Session | Product list views are excluded |
| Add-to-cart sessions | Sessions with at least one `add_to_cart` | `SUM(has_add_to_cart)` | Session | Quantity does not multiply the session flag |
| Add-to-cart stage ratio | Sessions with add-to-cart activity divided by sessions with product-view activity | `add_to_cart_sessions / product_view_sessions` | Aggregate | Independent stage-volume ratio, not proof that the same sessions progressed |
| Ordered view-to-cart rate | Product-view sessions with a later add-to-cart event in the same session | `ordered_cart_sessions / ordered_view_sessions` | Session path | Event timestamps enforce stage order; still descriptive, not causal |
| Checkout sessions | Sessions with `begin_checkout` | `SUM(has_begin_checkout)` | Session | Does not require cart in the same session |
| Purchase sessions | Sessions with at least one valid purchase event | `SUM(has_purchase)` | Session | Deduplicated at session grain |
| Session conversion rate | Sessions that purchased | `purchase_sessions / sessions` | Aggregate | Not a user conversion rate |
| Cart abandonment rate | Cart sessions without a purchase | `(add_to_cart_sessions - cart_and_purchase_sessions) / add_to_cart_sessions` | Aggregate | Session-based proxy; carts can persist |
| Checkout completion rate | Checkout sessions that also purchased | `checkout_and_purchase_sessions / checkout_sessions` | Aggregate | Same-session co-occurrence; does not require the full preceding ordered path |
| Governed orders / transactions | Distinct governed order keys | `COUNT(DISTINCT order_key)` | Order | Uses customer + valid transaction ID; missing IDs fall back to one order per purchase session |
| Revenue | Purchase revenue in USD | `SUM(purchase_revenue_usd)` | Order | Uses GA4-reported revenue; refunds analyzed separately if present |
| Average order value | Revenue per governed order | `revenue / transactions` | Aggregate | Includes disclosed purchase-session fallback orders; zero-revenue orders lower AOV |
| New session | First observed GA session number | `ga_session_number = 1` | Session | GA4 session number is browser-scoped |
| Returning session | GA session number greater than one | `ga_session_number > 1` | Session | “Returning” does not necessarily mean prior purchaser |
| Repeat purchaser | Pseudonymous user with 2+ distinct transactions | `transaction_count >= 2` | User | Limited to observed window |
| Repeat-purchase rate | Purchasers with 2+ transactions | `repeat_purchasers / purchasers` | User | Right- and left-censored by sample dates |
| Product view-to-cart rate | Item viewers who later generate cart activity for that item within reporting aggregation | `add_to_cart_users / product_view_users` | Product/filter | Aggregate association, not ordered-path attribution |
| Product purchase rate | Product viewers who purchase the item within reporting aggregation | `purchasing_users / product_view_users` | Product/filter | Do not use as a headline KPI in this obfuscated sample because item identifiers are inconsistent across event types |

## Channel grouping

The project reports **first-user acquisition channel**, derived from `traffic_source.source`, `traffic_source.medium`, and `traffic_source.name`. It is deliberately not called session channel or last-click attribution.

Precedence: Direct, Email, Paid Search, Organic Search, Paid Social, Organic Social, Display, Referral, Affiliates, Other. The exact `CASE` expression is centralized in `sql/20_core/20_fct_sessions.sql`.
