## Acceptance Criteria
- When a webhook delivery fails, the system shall retry after a backoff interval.
- If the token is invalid, then the system shall reject the request with a 401.
- While the queue is draining, the system shall reject new enqueue requests.
