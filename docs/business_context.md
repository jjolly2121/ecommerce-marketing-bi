# Business Context

## Scenario

The Google Merchandise Store leadership team needs a reliable executive view of customer movement from acquisition through repeat purchase. The analysis must help marketing leaders allocate attention across acquisition channels and devices while helping merchandising leaders identify product-level funnel leaks.

## Decision owners

- Chief Marketing Officer: traffic quality, conversion, revenue trend, and channel mix
- E-commerce director: session funnel and checkout completion
- Merchandising leader: product/category demand and purchase yield
- Lifecycle marketing manager: new-versus-returning behavior and repeat purchase
- Analytics lead: KPI governance, refresh reliability, and tracking quality

## Analytical decisions

The dashboard is designed to support these decisions:

- Investigate a channel/device combination when traffic grows but purchase conversion falls.
- Prioritize checkout or cart-friction analysis at the stage with the largest relative loss.
- Rank governed purchase-item revenue for merchandising review and withhold item-level progression claims when identifier continuity is weak.
- Separate acquisition performance from repeat behavior rather than mixing both into one user label.
- Treat tracking gaps as a measurement issue when funnel ordering or transaction reconciliation fails.

## Scope boundaries

- This is descriptive and diagnostic analytics, not causal attribution.
- Channel reporting uses GA4 first-user acquisition fields because the sample does not provide a fully reliable modern session-attribution record for every event.
- A “customer” is a pseudonymous browser/app identifier, not a known person across devices.
- Repeat purchase is observable only inside the three-month sample window.
- Cart abandonment is session-based; a cart may persist into another session in a real storefront.
