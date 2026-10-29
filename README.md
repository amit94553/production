# atlasent-cicd-sandbox

A dummy service with a GitHub Actions deploy pipeline gated by AtlaSent. Use it to test Production Change Protection end to end: hold, human approval, a permit bound to the exact artifact, verification at the deploy step, and the refusals that should happen when something is changed or replayed.

Nothing here deploys anywhere real. `scripts/deploy.sh` copies the built site into `deployed/` on the runner and writes a record to the job summary.

## What's in it

| Path | What it does |
| --- | --- |
| `app/index.html` | The "service": a static page stamped with the commit |
| `scripts/build.sh` | Builds the site into `out/` |
| `scripts/digest.sh` | Stable `sha256:` digest of a directory, bound into the permit |
| `scripts/deploy.sh` | Dummy deploy |
| `.github/workflows/deploy.yml` | The gated pipeline and the test scenarios |
| `.github/workflows/hotfix-ungated.yml` | A deliberate ungated path for testing the exposure scan; it only echoes |

## How the pipeline works

1. **build** builds the site, computes its digest and uploads it.
2. **deploy** (GitHub Environment `production`):
   1. Downloads the site and re-checks its digest against the build.
   2. **Gate:** asks AtlaSent for `production.deploy` on `service:sandbox-web`, bound to the digest. Runs in `evaluate-only` mode with `wait-for-approval`. If policy holds, the step waits up to 30 minutes for a person to approve in the AtlaSent console, then claims the permit.
   3. **Verify:** presents the permit and consumes it. This is the execution boundary.
   4. **Deploy (dummy)** runs only if verify returned `verified == 'true'`.
   5. **Check the result** compares what happened with what the scenario expects and writes PASS or FAIL to the job summary.

## One-time setup

You need an AtlaSent account and admin rights on a GitHub repository.

1. **Create the GitHub repository** and push this folder to its `main` branch.
2. **Create a GitHub Environment** named `production` (Settings → Environments). Do not add required reviewers; AtlaSent is the approver here.
3. **Create an AtlaSent API key** in the console under API keys with these scopes:
   - `evaluate:write`
   - `verify:execute`
   - `idp_broker:mint` (an org admin grants it; needed for `production.deploy`)
   - `approvals:read` (needed to claim the permit after an approval)

   Save it as the repository secret `ATLASENT_API_KEY`.
4. **Enroll the workload binding** in the console under Integrations → GitHub:
   - repository: this repository
   - workflow file: `.github/workflows/deploy.yml`
   - branch: `main`
   - GitHub Environment: `production`

   Without this, every run is denied `ACTOR_UNVERIFIED`.
5. **Set a policy** on `production.deploy` that requires a human approval, so the gate returns `hold` rather than `allow`. Name yourself, or a second person, as an approver. A policy that denies with `INSUFFICIENT_APPROVALS` instead of holding will not wait for you.
6. **Base URL:** the Action defaults to `https://api.atlasent.io/functions/v1`. For staging or a dedicated runtime, add `ATLASENT_BASE_URL` to the `env:` of each AtlaSent step.

## Test scenarios

Run from Actions → **Deploy (AtlaSent gated)** → Run workflow, and pick a scenario. Pushing to `main` runs `normal`.

Every scenario except `rehearsal` holds first, so open the AtlaSent console and approve the request while the gate step is waiting.

| Scenario | What it does | Expected result |
| --- | --- | --- |
| `normal` | Approve, verify, deploy | Permit verified; deploy runs; PASS |
| `changed-target` | Verifies the permit for `service:sandbox-web-tampered` | Refused (`PERMIT_BINDING_MISMATCH`); no deploy; PASS |
| `tampered-plan` | Verifies with one character of the execution hash changed | Refused (`PAYLOAD_MISMATCH`); no deploy; PASS |
| `replay` | Deploys once, then presents the same permit again | First use verified; second refused (`PERMIT_ALREADY_USED`); PASS |
| `rehearsal` | AtlaSent's five-case rehearsal. Start a rehearsal in the console and paste its id into `rehearsal_request_id` | Verdict `all_expected`. Case 3 waits for you to approve in the console |

Also try these by hand:

- **Decline:** run `normal` and decline in the console. The gate step should fail closed and the deploy should be skipped.
- **Timeout:** run `normal` and do nothing. After 30 minutes the gate step should fail closed.
- **Unenrolled workflow:** copy `deploy.yml` to a new file name and run it. It should be denied `ACTOR_UNVERIFIED`.
- **Exposure scan:** from the repository root, run
  ```bash
  npx -y -p @atlasent/mcp-server@latest atlasent-exposure-scan .
  ```
  It works offline on `.github/workflows/`. It should list `hotfix-ungated.yml` as an ungated path to production and show `deploy.yml` as gated.

## What this does not test

- **Slack approvals.** Approval here happens in the AtlaSent console. Package A (approve in Slack) is not built yet.
- **Effect confirmation.** `admit-operation` and `establish-effect` need extra scopes, a Change Brief step and the AtlaSent GitHub App. See `docs/github-gate.md` in the atlasent-action repository.
- **Bypass.** The gate only protects this workflow. Anyone with direct credentials to a real target could deploy around it.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `ACTOR_UNVERIFIED` | Workload binding missing, or the repository, workflow file, branch or GitHub Environment does not match it |
| `OIDC` or identity mint error | `permissions: id-token: write` missing, or the API key lacks `idp_broker:mint` |
| Deny `INSUFFICIENT_APPROVALS` with no wait | The policy denies instead of holding; change it to require a human approval |
| Gate waits, then fails after approval | API key lacks `approvals:read`, so the permit cannot be claimed |
| Refusal scenario FAILs with "Permit issued: false" | The gate never issued a permit, so the refusal test did not run; fix the normal path first |

## Status

The scripts were run locally and the workflow YAML was parsed. The workflows have not yet run against AtlaSent. Expected refusal codes come from the atlasent-action docs and have not been observed in this repository yet.
