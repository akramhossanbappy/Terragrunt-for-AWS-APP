# Running this repo against the real AWS account

Target: **tfdemo / FIFA**, account `487542879553`, region `ap-southeast-1`
(`waf-cloudfront` deploys to `us-east-1`). This is the production
environment — `plan` is safe/read-only, `apply` changes real infrastructure.

This repo uses a Terragrunt layout pinned under `projects/live/<environment>/<region>/<service>/`.
The current production configuration lives in `projects/live/production/`.

## 1. Install Terraform and Terragrunt

The buildspecs (`plan-buildspec.yaml`, `apply-buildspec.yaml`) pin the exact
Terragrunt version used in CI:

```bash
export TERRAGRUNT_VERSION=0.83.2
```

Install that same version locally so `terragrunt plan`/`apply` behaves
identically to CI. Newer Terragrunt majors (0.90+) ship a redesigned CLI
(`run --all` instead of `run-all`, different flag names, different
`dependency`/mock_outputs resolution behavior) — don't use one of those for
this repo, or local runs won't match CI.

**macOS** (Homebrew installs latest, not 0.83.2 — download the pinned binary
directly):

```bash
mkdir -p ~/.local/bin
curl -sL -o ~/.local/bin/terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_darwin_arm64"
chmod +x ~/.local/bin/terragrunt
xattr -d com.apple.quarantine ~/.local/bin/terragrunt 2>/dev/null
```

Use `terragrunt_darwin_amd64` instead of `terragrunt_darwin_arm64` on Intel
Macs. Make sure `~/.local/bin` comes before any other `terragrunt` on your
`PATH` (e.g. Homebrew's `/opt/homebrew/bin`), then confirm:

```bash
terragrunt --version   # should print: terragrunt version v0.83.2
```

**Linux** (matches the buildspecs exactly):

```bash
curl -s -qL -o terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
chmod +x terragrunt
sudo mv terragrunt /usr/bin/
```

You'll also need **Terraform >= 1.12.0** on `PATH` (the version floor set in
`projects/live/production/terragrunt.hcl`'s `generate "provider"` block):

```bash
terraform --version
```

## 2. Configure AWS credentials

Every unit's S3 backend, provider, and `dependency` block resolution needs
real API access — `mock_outputs` only cover the case where a dependency
hasn't been applied yet, not missing/invalid credentials.

Use whatever credential source your team normally uses for this account
(SSO, an IAM user profile, an assumed role) — as long as it resolves to
account `487542879553`:

```bash
# e.g. via a named profile
export AWS_PROFILE=<your-profile-for-487542879553>

# or via SSO
aws sso login --profile <your-profile>
export AWS_PROFILE=<your-profile>

# or via static/temporary credentials
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # only if using temporary/STS credentials
```

Verify before doing anything else — this must return account
`487542879553`, not an error:

```bash
aws sts get-caller-identity
```

The credentials need permission to read/write the state bucket
(`tfdemo-fifa-terraform-state-bucket-production`) and to manage every
resource type the modules under `projects/modules/` touch (VPC, EKS, ECR,
CodePipeline/CodeBuild, ElastiCache, EFS, OpenSearch, S3, CloudFront, WAFv2,
CloudWatch, Lambda, IAM, etc.).

## 3. Set required secrets (not to be added to tfvars/inputs)

`docker_password` (`delivery` unit) and `os_db_user` / `os_db_password`
(`data` unit) are deliberately absent from every unit's `terragrunt.hcl`
`inputs` block — see `projects/CLAUDE.md`. In CI these are injected as
`TF_VAR_*` env vars by CodeBuild, pulled from a single JSON secret at
Secrets Manager path `/prod/terraform/key` (see
`cicd-terraform (apply-from-local)/main.tf`). Do the same locally before
`apply`/`plan` on `delivery` or `data`:

```bash
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id /prod/terraform/key \
  --query SecretString --output text)

export TF_VAR_docker_password=$(echo "$SECRET_JSON" | jq -r .TF_VAR_docker_password)
export TF_VAR_os_db_user=$(echo "$SECRET_JSON" | jq -r .TF_VAR_os_db_user)
export TF_VAR_os_db_password=$(echo "$SECRET_JSON" | jq -r .TF_VAR_os_db_password)
```

`plan`/`apply` on other units (`networking`, `cluster`, `waf-regional`,
`waf-cloudfront`, `static-sites`, `monitoring`) don't need these.

## 4. init / validate / plan / apply

Run from `projects/live/production/` — see `projects/CLAUDE.md` for the full
per-unit architecture and `projects/MIGRATION.md` if the state cutover from
the old root module isn't finished yet in this account.

```bash
cd projects/live/production
terragrunt run-all init
terragrunt run-all validate
terragrunt run-all plan
terragrunt run-all apply
```

Terragrunt resolves the `dependency` blocks (`cluster`/`data` ← `networking`,
`static-sites` ← `waf-cloudfront`, `monitoring` ← `data`) and orders the run
automatically — you don't need to apply units in a specific order yourself
when using `run-all`.

To work on a single unit instead of all 8 (`networking`, `cluster`,
`delivery`, `data`, `static-sites`, `waf-regional`, `waf-cloudfront`,
`monitoring`):

```bash
cd projects/live/production/<region>/<unit>
terragrunt init
terragrunt plan
terragrunt apply
```

If a unit's dependency (e.g. `networking` for `cluster`) hasn't been applied
yet, add `--terragrunt-non-interactive` so Terragrunt falls back to that
dependency's configured `mock_outputs` instead of prompting.

Non-interactive form (as used by the buildspecs, for CI or scripted runs —
note the forced `--terragrunt-parallelism 1` on apply, and the WAF units
currently running `waf_count_mode_only = true`, observe-only, not enforcing):

```bash
terragrunt run-all init --terragrunt-non-interactive
terragrunt run-all plan --terragrunt-non-interactive
terragrunt run-all apply --terragrunt-non-interactive --terragrunt-parallelism 1 -- -auto-approve
```

`terragrunt run-all apply` with `-auto-approve` applies without a
confirmation prompt — make sure `plan` output has been reviewed first.
