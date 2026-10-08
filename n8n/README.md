# n8n

Orchestration layer: external triggers, retries, and notifications. Scheduling stays in
GitHub Actions, which keeps running when the laptop is closed.

## Rebuild from nothing

One command against a fresh Ubuntu box, or against the existing one:

```sh
./provision.sh aiflow
```

It is idempotent. Running it on a working server is how you deploy a workflow change.

The script hardens the host, installs Docker, writes `compose.yaml` with the real secrets,
imports every `*.json` here, restores dedup state, activates what should be active, and
restarts so the schedules register.

For a brand new host, point it at the SSH alias and supply the secrets once:

```sh
TELEGRAM_TOKEN=... TELEGRAM_CHAT_ID=... ./provision.sh newhost
```

On an existing host the token is read from `/root/.telegram-token`, so no secret needs to be
typed or stored locally.

## Nothing irreplaceable lives on the server

| Thing | Where it really lives |
|---|---|
| Workflow definitions | this directory, in git |
| Compose file | this directory, token redacted |
| Telegram token | `/root/.telegram-token`, mode 600 |
| Dedup state | the server, but backed up and restored by `provision.sh` |
| Execution history | the server only, and disposable |

Losing the VPS costs one `provision.sh` run and the execution history.

## Access

n8n binds to `127.0.0.1:5678` and is never exposed. Docker writes its own iptables rules that
bypass ufw, so publishing the port normally would open it to the internet even though ufw
allows only 22. Reach the UI through the tunnel instead:

```sh
ssh aiflow-ui
```

then open `http://localhost:5678`.

## Workflows

| File | What it does |
|---|---|
| `alerts.json` | Every 15 minutes, read the published `status.json`, alert on newly failed repos, stay quiet about ones already reported |

Dedup is keyed on the failing run's URL. A repo that recovers is forgotten, so its next
failure alerts again.

## Three traps worth remembering

| Trap | What actually happens |
|---|---|
| `import:workflow` resets `active` to 0 | Import first, then activate, then restart. Any other order silently leaves the schedule off. |
| `n8n execute --id=` refuses a Schedule Trigger | It demands an Execute Workflow Trigger. To test, shorten the interval, let it fire, then restore it. |
| `n8n list:execution` does not exist | Read `execution_entity` from the SQLite file directly. A naive check mistakes the error message for output. |

## Adding a workflow

Drop a `*.json` here with a top-level `id` and `"active": true`, then run `provision.sh`.
Export from the UI with `docker exec n8n n8n export:workflow --id=<id> --output=/tmp/x.json`
and strip anything secret before committing.
