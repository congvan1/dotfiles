# 2026-01-20 High response time in GraphQL components

- Page ID: `969736193`
- Space ID: `92340225`
- Version: `12`
- URL: https://vtvcab.atlassian.net/wiki/spaces/SD/pages/969736193/2026-01-20+High+response+time+in+GraphQL+components

## Content

## Summary

| **Reporter** |  |
| --- | --- |
| **Incident** | High response time in GraphQL components |
| **Behavior** | When the football event took place and the number of participating users increased suddenly, this issue began to occur. At that time, the event had approximately **7,000–8,000 concurrent viewers**. |
| **Priority** | CRITICALRed |
| **Affected services** | * Subscription * Homepage |

## Incident report

| **Instructions** | **Report** |
| --- | --- |
| Leadup | * These two trigger multiple requests to the subscription GraphQL server:    + Livechat session (resolving `UserProfile`)   + Querying the channel list (resolving `Channel` entities in `subscription-graphql`) * When resolving the channel and user list, each entity requires a separate database connection to fetch data, leading to a large number of connections being created in a short period of time. |
| Fault | * The database connection acquire time is too high. * N+1 query pattern. * PgBouncer in **session mode**, which is not well-suited for handling a large number of concurrent connections. |
| Impact | * Users got stuck on the homepage and channel screens due to high loading times, and in some cases, requests timed out and returned errors. |
| Detection | * Dashboard NLB Websocket:  * Apollo router dashboard: [Apollo Dashboard](https://grafana.vtvprime.vn/goto/7eI_7xIDR?orgId=1)  * Tracing:  * Prometheus metrics:   Timeout operations:  Internal server error operations:  Internal server error subgraph  Bad Gateway error subgraph |
| Follow-up tasks | * :    + Apply `dataloader` for `user tier`   + Optimize Subscription Service queries used by GraphQL, adding indexes where necessary.   + Go benchmark, timebox optimization effort * + K6 loadtest |

#### Timeout GraphQL operations

| **Subgraph** | **Operation** | **Investigator** | **Can Hardcode (subscription subgraph)** |
| --- | --- | --- | --- |
| **channel** | Channel |  | `requiredSubscriptions` |
| Channels |  | `requiredSubscriptions` |
| Event |  | `requiredSubscriptions` |
| ProgrammesSchedule |  | `requiredSubscriptions` |
| SimilarEvents |  | `requiredSubscriptions` |
| **comment** | CommentsAndReviews | Trace id: 04e4c9686d59f5679dd870f627df5949 | `activeSubscriptions` |
| **homepage** | HomepageBlockContents |  | `requiredSubscriptions` |
| HomepageBlockContentsByBlockID |  | `requiredSubscriptions` |
| HomepageBlocks |  | `requiredSubscriptions` |
| SmartTVSideNavSlots | Số lượng ít, ko có trace → có thể giống các query homepage ở trên |  |
| **identity** | Me | TraceID: `174c97fc601e2d68ca28e1a020f4276e` | `activeSubscriptions`    `suggestedSubscriptionPlans` |
| Users | TraceID: `087663a227d74c9d5b8ba9f3fb96c97e` | Yes, only tier field. |
| **search** | Search | Trace id: 12477af519da3b338de535d9311084e3 | `requiredSubscriptions` |
| **subscription** | SubscriptionPlanGroups | None |  |
| SubscriptionPlans | TraceID: `100c4d2c7447e7fb45afe6a23db909f4` |  |
| TransactionHistory | TraceID: `059967fc1d3fccea26f787302a86273f` |  |

#### Internal Server Error GraphQL operations

| **Subgraph** | **Operation** | **Investigator** |
| --- | --- | --- |
| channel  channel | Channel |  |
| SendChannelHeartbeat |  |
