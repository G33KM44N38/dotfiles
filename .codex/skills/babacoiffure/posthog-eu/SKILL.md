---
name: posthog-eu
description: Use when querying PostHog for BabaCoiffure analytics, user activity, campaign results, website/mobile events, or PostHog API access. Always use the EU PostHog host unless the user explicitly says otherwise.
---

# PostHog EU

For BabaCoiffure PostHog work:

- Default API/UI host: `https://eu.posthog.com`
- EU ingestion host may also answer: `https://eu.i.posthog.com`
- Do not use US hosts (`https://us.i.posthog.com`, `https://us.posthog.com`) for reads unless explicitly requested.
- Render `POSTHOG_API_KEY` and `NEXT_PUBLIC_POSTHOG_KEY` are capture/project keys, not read API keys. They cannot query users/events.
- A PostHog personal API key usually starts with `phx_`; use it as `Authorization: Bearer <key>`.

Quick checks:

```bash
curl -sS -H "Authorization: Bearer $POSTHOG_PERSONAL_KEY" \
  "https://eu.posthog.com/api/projects/"
```

For BabaCoiffure prod website-v2:

- Project observed: `204452` (`Default project`)
- Prod website events usually include `properties.app_surface = 'website'`
- Website pageviews use manual `$pageview` with `properties.pathname` and `$current_url`
- Mobile events usually include `properties.app_surface = 'mobile'`

Recent website query:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $POSTHOG_PERSONAL_KEY" \
  -H "Content-Type: application/json" \
  "https://eu.posthog.com/api/projects/204452/query/" \
  -d '{"query":{"kind":"HogQLQuery","query":"select event, distinct_id, timestamp, properties.$current_url, properties.pathname, properties.app_surface, properties.$host, properties.utm_campaign from events where timestamp > now() - interval 48 hour and properties.app_surface = '\''website'\'' order by timestamp desc limit 100"}}'
```
