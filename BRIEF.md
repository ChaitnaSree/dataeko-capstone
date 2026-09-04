# DATAEKO Capstone — Ship the Coffee Company

**Five weeks, one system.** Everything you have been taught since day one is in
here somewhere: the shell, Git, Python, HTTP, CI, containers, SQL, monitoring,
the cloud, and infrastructure as code.

- **Time:** about 14 hours for Core, 20+ if you do the Stretch work.
- **Deadline:** see the class message.
- **Work alone.** Talk to each other all you like. Do not share code.

---

## 1. What you are building

An orders pipeline for a coffee chain. Files arrive, they get cleaned and
stored, an API serves them, monitoring watches it, CI ships it, and Terraform
builds the infrastructure it runs on.

```
   data/orders.csv
        |
        |  scripts/ingest.sh      staging + validation      (Week 1)
        v
   ingest/loader.py               csv -> dict -> Postgres   (Week 2)
        |
        v
   [ Postgres ]  <-----  api/app.py  ----->  /metrics       (Weeks 2, 4)
                              |                  |
                              |                  v
                              |            [ Prometheus ] -> [ Grafana ]
                              v
                     GitHub Actions -> GHCR image           (Week 3)
                              |
                              v
                     Terraform -> LocalStack                (Week 5)
                              |
                              v
                     GitHub Pages status site
```

**Everything runs on your laptop.** No AWS account. No credit card. No spend.
The only things that leave your machine are GitHub, GHCR and your LocalStack
token check.

---

## 2. Ground rules

1. **Keep your fork public.** Public repositories get unlimited free Actions
   minutes. Private ones get 2,000 per month, and you will run out.
2. **One branch per phase**, one pull request per phase, merged into your `main`.
   Seven PRs by the end. A phase with no PR is not marked.
3. **Commit your evidence.** Anything in `evidence/` is part of your submission.
4. **`./scripts/verify.sh` is the marking script.** Run it whenever you like. It
   is the same script your trainer runs.
5. Do not edit `tests/test_capstone.py`. It is the required check.

---

## 3. Before you start

You already have Docker, Python, Git, the AWS CLI and LocalStack from Weeks 1–5.
**Two things are new.**

### 3.1 Terraform

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Ubuntu / WSL
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

terraform version    # 1.5 or newer
```

### 3.2 Disk space

You will be running Postgres, your API, Prometheus, Grafana and LocalStack.
**Check you have at least 15 GB free before you start.**

```bash
df -h /
docker system prune -a     # frees images you are no longer using
```

This is not optional advice. While this assignment was being built, a Docker
build failed with `no space left on device` — and the cause was one of the nine
defects you are about to fix.

### 3.3 Fork and set up

```bash
# fork studio-typo-hq/dataeko-capstone on GitHub, then:
git clone https://github.com/<your-username>/dataeko-capstone.git
cd dataeko-capstone

python3 -m venv .venv
source .venv/bin/activate          # Windows/WSL: source .venv/bin/activate
pip install -r api/requirements.txt -r ingest/requirements.txt pytest
```

**Always activate the venv before running anything**, including `verify.sh`.

### 3.4 The database

```bash
docker start pg    # the container from Week 4
docker exec pg psql -U postgres -c "CREATE DATABASE capstone;"
docker exec -i pg psql -U postgres -d capstone < sql/schema.sql
docker exec -i pg psql -U postgres -d capstone < sql/seed.sql
```

The seed takes about **4 seconds** and builds:

| table | rows |
|---|---|
| stores | 6 |
| drinks | 18 |
| customers | 20,000 |
| orders | 400,000 |
| deliveries | 320,000 |

Check it:

```bash
docker exec pg psql -U postgres -d capstone -c "SELECT count(*) FROM orders;"
# 400000
```

### 3.5 Baseline

```bash
./scripts/verify.sh
```

You will score **0 of 27**. That is correct. Everything below raises it.

---

## 4. How you are marked

| Phase | Checks | Weight |
|---|---|---|
| 0 — Triage | 10 | 25% |
| 1 — Ingest | 3 | 15% |
| 2 — Serve | 4 (live) | 15% |
| 3 — Query | 5 | 15% |
| 4 — Watch | 3 | 10% |
| 5 — Ship | 4 + 2 (live) | 15% |
| 6 — Provision | 3 | 5% |

`verify.sh` writes `evidence/RECEIPT.json`. **Commit it.** Your final receipt is
your score. Stretch items are marked by hand and can raise a grade but never
lower one.

---

## PHASE 0 — Triage (Core, ~2.5 hours)

You have joined a team. This repository is what they left you. It contains
**nine defects**. Every one is something you were taught to spot.

**Branch:** `phase-0-triage`
**One commit per defect**, message format: `fix(<area>): <what you changed>`
**Deliverable:** `TRIAGE.md` with nine `## ` sections — symptom, cause, fix, and
how you proved it.

Do not fix them silently. The writing is the point.

### 0.1 The script will not run

```bash
./scripts/ingest.sh data/orders.csv
# permission denied
```

Week 1. Look at the mode. Fix it, then make Git remember:

```bash
git update-index --chmod=+x scripts/ingest.sh
```

Without that second command it works on your machine and stays broken for
everyone else. Explain in `TRIAGE.md` why.

### 0.2 A path with a space in it

```bash
cp data/orders.csv "data/march orders.csv"
bash scripts/ingest.sh "data/march orders.csv"
# scripts/ingest.sh: line 10: [: data/march: binary operator expected
```

Week 1, Session 2. One pair of quotes.

### 0.3 The Dockerfile rebuilds everything, every time

Change one line of Python and rebuild. Watch `RUN pip install` run again.

Verified on this repository:

| Dockerfile | rebuild after a one-line code edit |
|---|---|
| as shipped | **4 s** — `pip install` re-runs |
| fixed | **1 s** — `pip install` is `CACHED` |

Week 3 measured exactly this. Reorder the instructions. Put the before/after
build output in `TRIAGE.md`.

### 0.4 There is no `.dockerignore`

Run `terraform init` in `infra/`, then look at the repository:

```bash
du -sh infra/.terraform     # 778M
```

Now build the image. Everything in that folder is sent to the Docker daemon and
copied into your image. Measured here:

| | build context |
|---|---|
| no `.dockerignore` | **778 MB** — and the build failed with `no space left on device` |
| with `.dockerignore` | **1.41 kB** |

Create one. At minimum exclude `.git`, `.terraform/`, `__pycache__/`, `*.pyc`,
`.venv/`.

### 0.5 A key, in a file, in a public repository

```bash
grep -rn "dataeko-capstone-2026-secret" .
```

Two hits: `api/config.py` and `.github/workflows/ci.yml`.

Fix both. The key must come from an environment variable in the code, and from
`secrets.` in the workflow.

**Then answer this in `TRIAGE.md`:** you deleted the line and committed. Is the
key gone? Run `git log -p | grep dataeko-capstone-2026-secret` and answer
honestly. Say what you would have to do in real life. *(You are not required to
rewrite history — just to understand that deleting it is not enough.)*

### 0.6 A request with no timeout

`ingest/loader.py`, `fetch_reference()`. Week 2 told you what happens the day a
server accepts your connection and then says nothing.

Add a timeout. Say in `TRIAGE.md` what the failure looks like without one, and
why it is worse than an error.

### 0.7 A query that reads the whole table

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 4242;
```

Verified on this dataset, before any index:

```
Gather  (cost=1000.00..6657.33 rows=20 width=36)
  Workers Planned: 2
  ->  Parallel Seq Scan on orders
        Filter: (customer_id = 4242)
        Rows Removed by Filter: 133327
Planning Time: 0.107 ms
Execution Time: 5.984 ms
```

Create `sql/migrations/001_orders_customer_index.sql` containing the
`CREATE INDEX`. Apply it, re-run the plan, and put both in `TRIAGE.md`.

For reference, measured here — three runs each:

| | Execution Time |
|---|---|
| no index | 4.930 / 4.845 / 4.805 ms |
| with index | 0.080 / 0.077 / 0.075 ms |

That is **63× faster**, and the plan changes from `Parallel Seq Scan` to
`Bitmap Index Scan`. Your numbers will differ. Report yours.

### 0.8 SSH is open to the world

`infra/main.tf`:

```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

`terraform validate` says `Success! The configuration is valid.` **Nothing warns
you.** That is why this defect is on the list.

Restrict it to `10.0.0.0/16`. In `TRIAGE.md`, explain what an attacker does with
port 22 open to `0.0.0.0/0`, and why "it is only LocalStack" is not the point.

### 0.9 `count` where `for_each` belongs

The buckets are built with `count` over a list. Remove `"staging"` from
`var.environments` and run `terraform plan`.

Verified on this exact configuration:

```
# aws_s3_bucket.env[1] must be replaced
    ~ bucket = "testuser-capstone-staging" -> "testuser-capstone-prod"  # forces replacement
# aws_s3_bucket.env[2] will be destroyed

Plan: 1 to add, 0 to change, 2 to destroy.
```

**Read that again.** Deleting *staging* destroys and rebuilds **prod**.

Convert to `for_each`. Same edit, verified:

```
# aws_s3_bucket.env["staging"] will be destroyed

Plan: 0 to add, 0 to change, 1 to destroy.
```

Put both plans in `TRIAGE.md`. This is the most important defect on the list.

### Stretch (0.S)

`data/orders-windows.csv` fails the header check with an error showing two
strings that look identical. Find out why.

```bash
head -1 data/orders-windows.csv | xxd | tail -2
```

Explain it, and make `ingest.sh` tolerate both line endings.

---

## PHASE 1 — Ingest (Core, ~2.5 hours)

**Branch:** `phase-1-ingest`

`data/orders.csv` has **200 good rows and 9 deliberately malformed ones**. The
loader must handle all 209 without crashing.

Implement three functions in `ingest/loader.py`:

- **`read_rows(path)`** — yield one dict per row. Use the `csv` module, not
  `split(",")`. Week 2 explained why.
- **`validate(row)`** — return `(ok: bool, reason: str)`. A rejection always
  carries a reason.
- **`load(path)`** — insert good rows into Postgres, write rejects to
  `evidence/rejected.csv` with their reason, print a summary.

The nine bad rows are each wrong in a different way: zero quantity, negative
quantity, a quantity that is a word, an unparseable timestamp, a status the
database will not accept, a `drink_id` with no matching drink, an empty
`customer_id`, a row that is too short, and a row that is too long.

**Required output:**

```
$ python ingest/loader.py data/orders.csv
read 209 rows
inserted 200
rejected 9 -> evidence/rejected.csv
```

**Check:** `pytest -v` must pass. Eight tests.

**Stretch:** make `load()` idempotent — run it twice, still 200 rows. And wrap
the insert in a transaction so a mid-file failure leaves nothing behind.

---

## PHASE 2 — Serve (Core, ~3 hours)

**Branch:** `phase-2-serve`

Finish `api/app.py`.

### 2.1 `GET /orders` — pagination

Query parameters `page` (default 1) and `per_page` (default 20, **capped at
100**). Response:

```json
{
  "count": 20,
  "total": 400000,
  "page": 1,
  "per_page": 20,
  "results": [ ... ]
}
```

`count` is how many you returned. `total` is how many exist. Week 2 spent a
slide on why those are different numbers. Asking for `per_page=5000` must not
return 5000 rows.

### 2.2 Authentication — 401 vs 403

| request | status |
|---|---|
| no `Authorization` header | **401** |
| `Authorization: Bearer wrong-key` | **403** |
| correct key | **200** |

401 means *I do not know who you are*. 403 means *I know exactly who you are,
and no.* Getting these the wrong way round is the single most common API bug.

The key comes from an environment variable. Not from `config.py`.

### 2.3 Rate limiting — 429

More than **10 requests in 10 seconds** from the same key returns `429` with a
`Retry-After` header. In-memory is fine.

### 2.4 A client that behaves

`ingest/client.py` — calls `/orders`, pages through **all** results, and when it
gets a 429 it reads `Retry-After`, waits, and retries. Every request has a
timeout. Print the total number of orders it collected.

**Stretch:** `ETag` + `304 Not Modified` on `/orders`.

---

## PHASE 3 — Query (Core, ~2 hours)

**Branch:** `phase-3-query`

One file per question in `sql/queries/`, and the answer in a comment at the top.

**Q1 — `01_revenue_by_city.sql`.** Total revenue per city, highest first. Needs
`orders`, `drinks` and `stores` joined, `qty × price_inr`, and only `collected`
orders.

**Q2 — `02_never_ordered.sql`.** Which drinks has nobody ever ordered? This is an
anti-join. Verified answer: **3 drinks** — `turmeric latte`, `rose cardamom`,
`affogato`. If you get 0, you wrote an inner join.

**Q3 — `03_undelivered.sql`.** How many orders have no delivery row at all?
Verified answer: **80,000**.

**Q4 — `04_loyal_customers.sql`.** Customers with more than 25 orders, with their
order count and total spend. `GROUP BY` and `HAVING`, not `WHERE`.

### 3.5 The index, properly

Capture `EXPLAIN ANALYZE` for a query of your choice **before** and **after**
adding an index, into `evidence/explain-before.txt` and
`evidence/explain-after.txt`.

The before-plan must contain `Seq Scan`. The after-plan must contain
`Index Scan`. `verify.sh` checks for both strings.

Write two sentences in the file: which index, and why the planner changed
its mind.

**Stretch:** find a query where adding an index makes things *worse*, and prove
it with timings. They exist. Week 4 measured one.

---

## PHASE 4 — Watch (Core, ~2.5 hours)

**Branch:** `phase-4-watch`

### 4.1 Instrument the API

Already present: a `Counter` and a `Histogram`. **Add a `Gauge`** called
`capstone_orders_in_flight` that goes up when a request starts and down when it
finishes.

Three metric types, three jobs. In `evidence/promql.txt`, write one sentence on
why a counter would be wrong for in-flight requests.

### 4.2 Start the stack

```bash
cd observability && docker compose up -d
```

- Prometheus — http://localhost:9090
- Grafana — http://localhost:3000 (`admin` / `admin`)

Confirm your API is being scraped: Prometheus → Status → Targets → `UP`.

### 4.3 Generate load and query it

Drive some traffic, including failures. Then in `evidence/promql.txt`, commit
these three queries **and their output**:

1. Request rate over 5 minutes, by endpoint
2. Error rate as a percentage of all requests
3. 95th percentile latency

You will need `rate()`, and `histogram_quantile()` for the third.

### 4.4 Grafana

Build a dashboard with those three panels. Export it to
`evidence/dashboard.json` (Dashboard → Share → Export → Save to file).

### 4.5 Kill it

Stop your API. Wait a minute. Screenshot Prometheus showing `up == 0` into
`evidence/`. In `promql.txt`, write what `rate()` does to a counter that stops
existing, and why an alert on "error rate" would not have fired here.

**Stretch:** an alerting rule that fires when the API is down for 1 minute.
Commit the rule and a screenshot of it firing.

---

## PHASE 5 — Ship (Core, ~3 hours)

**Branch:** `phase-5-ship`

### 5.1 Fix the CI workflow

`.github/workflows/ci.yml` must:

- run `pytest` on a **matrix** of Python 3.11, 3.12 and 3.13
- upload `report.xml` with `actions/upload-artifact@v4`
- take the API key from `secrets.`, never from the file

Add the secret in your fork: Settings → Secrets and variables → Actions.

### 5.2 Multi-stage image

Rewrite the `Dockerfile` as a multi-stage build. Dependencies before source
(you fixed that in Phase 0). Record the final image size in your PR.

### 5.3 Publish to GHCR

Add a `build` job that pushes to:

```
ghcr.io/<your-lowercase-username>/dataeko-capstone:latest
```

**Your username must be lowercase.** GHCR rejects capitals, and this broke
several of you in Week 3.

Use `secrets.GITHUB_TOKEN` — no new secret needed — and set:

```yaml
permissions:
  contents: read
  packages: write
```

**Then make the package public.** Your trainer must be able to run
`docker pull ghcr.io/<you>/dataeko-capstone:latest` without logging in. This is
a manual click in the package settings.

### 5.4 The status page

`.github/workflows/pages.yml` — build and deploy a **static status page** to
GitHub Pages showing:

- your name and GitHub username
- the row counts in your database
- your four Phase 3 answers
- a link to your GHCR package
- the date it was built

It must be generated by the workflow, not hand-written. Enable Pages in
Settings → Pages → Source: GitHub Actions.

Your site must be live at:

```
https://<your-username>.github.io/dataeko-capstone/
```

This is the one thing from this assignment you can show someone outside the
programme. Make it look decent.

**Stretch:** make the CI fail the build if the image is larger than 200 MB.

---

## PHASE 6 — Provision (Core, ~2 hours)

**Branch:** `phase-6-provision`

### 6.1 Start LocalStack

```bash
docker run -d --name localstack -p 4566:4566 \
  -e LOCALSTACK_AUTH_TOKEN=<your-token> \
  localstack/localstack:latest

curl -s http://localhost:4566/_localstack/health
```

LocalStack needs internet to check its token, even though it runs locally.

### 6.2 Apply

```bash
cd infra
terraform init
terraform plan  -var student=<your-lowercase-username>
terraform apply -var student=<your-lowercase-username>
```

Save the plan output to `evidence/plan.txt`.

> **Note the `s3_use_path_style = true` line in the provider.** Without it,
> Terraform addresses buckets as `http://<bucket>.localhost:4566`, which never
> resolves, and `apply` **hangs** rather than failing. It cost an hour to find.

### 6.3 Extend it

Add to `infra/main.tf`:

- an **IAM role** a Lambda can assume
- a **Lambda function** using `infra/handler.py`
- an **S3 notification** so uploading to the `dev` bucket invokes it

Prove it works:

```bash
aws --endpoint-url=http://localhost:4566 s3 cp data/orders.csv \
  s3://<you>-capstone-dev/
aws --endpoint-url=http://localhost:4566 logs tail /aws/lambda/<function-name>
```

Put the log line showing `INGEST TRIGGERED` in `evidence/`.

You will need `depends_on` between the notification and the permission. Work out
why for yourself — the error message tells you.

### 6.4 Drift

Change something with the CLI, then run `terraform plan` and save it to
`evidence/drift-plan.txt`. The plan must show Terraform detecting the change.

In your PR, answer: **who is right, the file or the account?**

**Stretch:** move the state to an S3 backend inside LocalStack.

---

## 7. Submitting

By the deadline your fork must have:

- [ ] seven branches merged into `main` via pull requests
- [ ] `TRIAGE.md` with nine sections
- [ ] `evidence/` — `rejected.csv`, `explain-before.txt`, `explain-after.txt`,
      `promql.txt`, `dashboard.json`, `plan.txt`, `drift-plan.txt`, `RECEIPT.json`
- [ ] a green CI badge in your `README.md`
- [ ] a **public** GHCR package
- [ ] a live Pages site

Then run the full check and commit the receipt:

```bash
source .venv/bin/activate
API_KEY=<your-key> ./scripts/verify.sh --live
git add evidence/RECEIPT.json && git commit -m "chore: final receipt" && git push
```

Open one final pull request titled **`CAPSTONE: <your name>`** into
`studio-typo-hq/dataeko-capstone`. In the description, put your Pages URL, your
GHCR package URL, and your score.

---

## 8. If you get stuck

Two rules.

**Read the error.** All of it, including the line number. Week 2's whole
traceback slide was about this.

**Ask after thirty minutes, not after three hours.** When you ask, send: what
you ran, what you expected, what happened, and what you tried. A screenshot of
the whole terminal window, not a crop.

Getting stuck is normal. Staying stuck quietly is the only real mistake.
