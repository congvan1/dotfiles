# 2026-01-07 High response time in GraphQL components

- Page ID: `945782785`
- Space ID: `92340225`
- Version: `6`
- URL: https://vtvcab.atlassian.net/wiki/spaces/SD/pages/945782785/2026-01-07+High+response+time+in+GraphQL+components

## Content

Summary Reporter Incident High response time in GraphQL components Behavior When the football event took place and the number of participating users increased suddenly, this issue began to occur. At that time, the event had approximately 3,000–4,000 concurrent viewers . Priority CRITICAL Red Affected services Subscription Homepage Incident report Instructions Report Leadup These two trigger multiple requests to the subscription GraphQL server: Livechat session (resolving UserProfile ) Querying the channel list (resolving Channel entities in subscription-graphql ) When resolving the channel and user list, each entity requires a separate database connection to fetch data, leading to a large number of connections being created in a short period of time. Fault The database connection acquire time is too high. Currently, we are using PgBouncer in session mode , which is not well-suited for handling a large number of concurrent connections. We have not set up any caching mechanisms in PRD. Impact Users got stuck on the homepage and channel screens due to high loading times, and in some cases, requests timed out and returned errors. Detection Apollo router dashboard: https://shorturl.at/YAVub Tracing: subscription-graphql: Trace homepage-graphql: Trace Follow-up tasks Anh propose tuning database. entity-cache cho subscription subgraph. release userlabel-service. apply dataloader cho subscription graphql (case resolve Channel entity).
