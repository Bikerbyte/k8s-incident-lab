# Scripts

You only need to remember one command:

```bash
scripts/lab.sh help
```

PowerShell users can use the matching entry point:

```powershell
.\scripts\lab.ps1 help
```

## Main Entry Point

```bash
scripts/lab.sh deploy
scripts/lab.sh monitoring
scripts/lab.sh access
scripts/lab.sh console
scripts/lab.sh status
scripts/lab.sh scenario readiness trigger
scripts/lab.sh scenario readiness restore
```

## Internal Layout

Implementation scripts are grouped by how the lab uses them:

| Folder | Purpose |
| --- | --- |
| `lab/` | Start, inspect, expose, and clean up the lab environment. |
| `scenarios/` | Trigger and restore incident scenarios. |
| `tools/` | Validation and screenshot utilities. |

The other files directly under `scripts/` are compatibility wrappers. They keep older commands such as `scripts/deploy-app.sh` working, but `scripts/lab.sh` is the preferred interface for demos and docs.
