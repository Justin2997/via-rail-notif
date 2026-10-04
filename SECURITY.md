# Security policy

Security fixes are maintained on the default branch. There is no promise of support for older builds; update to the latest sources.

## Private disclosure

Use [GitHub private vulnerability reporting](https://github.com/Justin2997/via-rail-notif/security/advisories/new). If it is unavailable, contact the maintainer using a contact listed on [their GitHub profile](https://github.com/Justin2997); do not publish exploit details or credentials in an issue.

Include the affected commit, impact, reproduction steps and a minimal synthetic example. Never send Apple signing keys, access tokens, or personal passenger information. No response time or bounty is guaranteed.

## Security boundaries

The app downloads public VIA sources over HTTPS, validates sizes and ZIP/CSV structure, and stores schedules and alarm state locally. No backend, authentication or analytics service is operated by this project. AlarmKit and ActivityKit behavior is controlled by iOS. Network failures, stale forecasts and physical alarm reliability are documented limitations; use a separate backup when a missed arrival would matter.

See [privacy](docs/PRIVACY.md) for local storage and network behavior.
