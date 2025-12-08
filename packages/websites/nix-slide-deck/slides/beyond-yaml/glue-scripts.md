---
layout: top-title-two-cols
color: dark
class: text-sm
columns: is-6
---

:: title ::

# The Problem with Glue Scripts

:: right ::

```yaml
# .gitlab-ci.yml (excerpt)
build_image:
  script:
    - docker build -t "org/app:$CI_COMMIT_REF_NAME" .
```

\:: left ::

<div style="margin-top: 0rem; font-size: 0.9rem;">
Glue scripts are fragile, inconsistent, and hard to manage:

- 💥 Breaks on different OS versions
- 🐛 Dev ≠ CI ≠ Prod: hard to replicate bugs
- 🔁 No rollback, no guarantees
- 🔓 Unverified installs = security risk
- 📉 Slows onboarding and time-to-prod

</div>

---
layout: top-title-two-cols
color: dark
class: text-sm
columns: is-6
---

:: title ::

# Glue Scripts Are Everywhere

:: right ::

```bash
# setup.sh
sudo yum install -y zsh git curl
git clone https://github.com/zsh-users/zsh-autosuggestions ...
```

```dockerfile
# Dockerfile
FROM centos:8
COPY setup.sh .
RUN ./setup.sh
```

\:: left ::

<div style="margin-top: 0rem; font-size: 0.9rem;">

Developers create ad hoc setup scripts:

- ❓ Unclear what installs what
- ⛓️ CI scripts depend on manual steps
- 🧩 Setup logic duplicated across repos
- ⏳ Hours lost debugging environment drift

</div>

---
layout: top-title-two-cols
color: dark
class: text-sm
columns: is-6
---

:: title ::

# Business Impact

:: right ::

<div style="margin-top: 0rem; font-size: 0.9rem;">

- 📉 Fragility over velocity
- 🔐 Security risks multiply
- 🧑‍💻 Developer time wasted
- 🚧 No path to standardization
- 😬 Leadership sees instability, not innovation

</div>

:: left ::

<div style="margin-top: 0rem; font-size: 0.9rem;">

Glue scripts are hidden tech debt.  
They slow delivery, increase risk, and make scaling harder.  
<b>The fix?</b> Deterministic, declarative builds.

</div>
