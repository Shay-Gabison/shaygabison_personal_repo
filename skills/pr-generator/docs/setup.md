# Configuration: pr-generator

The install script copied these files to your project root. Follow the steps below.

## 1. Configure

Open [templates/pr-generator-config.md](../templates/pr-generator-config.md) — each placeholder has inline comments explaining what it is and how to find the value.

Fill in all `{{PLACEHOLDER}}` values in your copied `pr-generator-config.md`.

## 2. Place PR Template

Copy `pull_request_template.md` to its standard Azure DevOps location:

```bash
mkdir -p .azuredevops
cp pull_request_template.md .azuredevops/pull_request_template.md
```

If `.azuredevops/pull_request_template.md` already exists, compare the two files and merge any differences before overwriting:

```bash
diff pull_request_template.md .azuredevops/pull_request_template.md
```

Then customize `.azuredevops/pull_request_template.md` for your team's PR standards.
