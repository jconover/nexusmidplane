# NexusMidplane — Architecture Decision Records (ADRs)

Architecture Decision Records capture the *why* behind key design choices. Each ADR documents the context, options considered, the decision made, and the consequences.

---

## ADR-001: Hybrid AWS + On-Prem over Pure Cloud

**Status:** Accepted
**Date:** 2024-01

### Context

The project needed to demonstrate middleware operations skills relevant to financial services companies, which overwhelmingly run hybrid environments rather than pure cloud. A pure-AWS project would not showcase the operational complexity of managing dual-tier infrastructure, cross-boundary connectivity, or the contrast between cloud-managed and self-managed services.

### Options Considered

| Option | Pros | Cons |
|---|---|---|
| Pure AWS | Simpler, faster to build | Doesn't demonstrate on-prem ops skills |
| Pure on-prem (VMs) | Realistic, but complex setup | Poor reproducibility; heavy local resources |
| **Hybrid (Docker sim + AWS)** | **Shows both tiers; reproducible; portfolio-worthy** | **More files to manage** |

### Decision

Build a hybrid project where Docker containers simulate on-premises infrastructure (Apache, WildFly, .NET) and Terraform+EC2 represents the AWS tier. The two tiers use the same application code, deployed differently — demonstrating how a middleware engineer manages consistency across environments.

### Consequences

- Demonstrates the operational burden difference between self-managed certs (on-prem) and ACM (AWS)
- Shows Ansible managing both Docker-based and EC2-based hosts
- Vagrantfile.reference is provided for teams that prefer VM-based on-prem simulation
- Portfolio reviewer can spin up either tier independently

---

## ADR-002: WildFly over JBoss EAP

**Status:** Accepted
**Date:** 2024-01

### Context

The project targets middleware roles at financial services companies, many of which run JBoss EAP (Red Hat's enterprise-supported version of WildFly). The question was whether to use the paid enterprise product or its open-source upstream.

### Options Considered

| Option | License | Subscription | Parity |
|---|---|---|---|
| JBoss EAP | Commercial | Requires Red Hat subscription | Production-used in enterprise |
| **WildFly** | **Apache 2.0** | **Free** | **Upstream of EAP; same deployment model** |
| Tomcat | Apache 2.0 | Free | Lighter; fewer enterprise features |
| Payara (GlassFish) | CDDL | Free/paid | Less common in finance |

### Decision

Use WildFly. It is the upstream project for JBoss EAP and uses identical deployment mechanisms (WAR hot-deploy, `standalone.xml` configuration, management CLI). Skills demonstrated on WildFly transfer directly to JBoss EAP. Using WildFly avoids a Red Hat subscription requirement for a portfolio project.

### Consequences

- WAR deployment, JVM tuning, and datasource configuration patterns are identical to EAP
- WildFly Docker image is official and actively maintained
- Some EAP-specific features (Hibernate Validator enterprise extensions, patching tooling) are absent — noted in documentation
- **Enterprise reference:** In a production context, JBoss EAP would be used with Red Hat support, and IBM WebSphere or Oracle WebLogic are common alternatives at large banks

---

## ADR-003: Docker over Vagrant for On-Prem Simulation

**Status:** Accepted
**Date:** 2024-01

### Context

The on-premises simulation needed to be reproducible across developer laptops (macOS, Linux, WSL2 on Windows) without requiring a hypervisor or significant disk space. The choice was between Docker containers and Vagrant-managed VMs.

### Options Considered

| Option | Startup time | Resource usage | Reproducibility | OS realism |
|---|---|---|---|---|
| **Docker Compose** | **Seconds** | **Low (~200 MB RAM)** | **Excellent (OCI images)** | **Process-level isolation** |
| Vagrant + VirtualBox | Minutes | High (~1-2 GB RAM/VM) | Good (Vagrantfile) | Full VM (closest to bare metal) |
| Vagrant + VMware | Minutes | High | Good | Full VM |
| Manual localhost | N/A | Varies | Poor | None |

### Decision

Use Docker Compose for the primary on-prem simulation. A `Vagrantfile.reference` is included as a documented alternative for teams or reviewers who prefer VM-based simulation or need to demonstrate bare-metal provisioning skills.

### Consequences

- Setup takes seconds, not minutes — better developer experience
- Containers share the host kernel — not identical to bare-metal VMs, but sufficient for demonstrating app deployment, proxy config, and cert management
- `Vagrantfile.reference` demonstrates awareness of VM-based approaches used in some enterprise environments
- Docker is widely available on all target platforms (macOS Docker Desktop, Linux native, WSL2)

---

## ADR-004: GitHub Actions over Azure DevOps

**Status:** Accepted
**Date:** 2024-01

### Context

The project needed a CI/CD pipeline that could demonstrate AWS deployment automation. The two primary candidates were GitHub Actions (native to where the code is hosted) and Azure DevOps (common in Microsoft-stack enterprises).

### Options Considered

| Option | AWS integration | OIDC support | Cost | Familiarity |
|---|---|---|---|---|
| **GitHub Actions** | **Native (aws-actions/)** | **Native** | **Free for public repos** | **Widely known** |
| Azure DevOps | Requires AWS plugin | Workload identity (preview) | Licensed or limited free | Common in .NET shops |
| Jenkins | Plugin-based | Via OIDC plugin | Self-hosted | Legacy enterprise |
| CircleCI | AWS orbs | OIDC context | Paid above free tier | Growing |

### Decision

GitHub Actions with OIDC authentication. The `aws-actions/configure-aws-credentials` action natively supports OIDC role assumption, eliminating the need for stored AWS access keys. The `hashicorp/setup-terraform` and `actions/setup-java` actions are well-maintained and widely used.

### Consequences

- No long-lived AWS credentials in GitHub Secrets — only the OIDC role ARN
- Pipeline is self-documenting via YAML
- Manual approval gates use GitHub Environments (no additional tooling)
- **Enterprise reference:** In regulated financial services, this pattern maps to Azure DevOps workload identity or Jenkins OIDC plugins. The OIDC principle (short-lived tokens, no stored secrets) is the same across platforms
- **UCD reference:** IBM UrbanCode Deploy (UCD) is common in large banks for application deployment. UCD provides similar features (approval gates, environment promotion, rollback) as this pipeline but with a GUI-driven workflow and tighter mainframe/WebSphere integration. GitHub Actions is the modern open-source equivalent for teams not on IBM tooling.

---

## ADR-005: Apache httpd over Nginx for On-Prem Proxy

**Status:** Accepted
**Date:** 2024-01

### Context

The on-premises reverse proxy needed to terminate TLS, route `/java/*` to WildFly and `/dotnet/*` to Kestrel, and demonstrate enterprise proxy configuration patterns.

### Options Considered

| Option | Module ecosystem | Enterprise use | Config style | TLS handling |
|---|---|---|---|---|
| **Apache httpd** | **Rich (mod_proxy, mod_ssl, mod_rewrite)** | **Very common in finance** | **Directive-based** | **mod_ssl** |
| Nginx | Lean, performant | Growing, especially cloud-native | Block-based | TLS termination |
| HAProxy | Load balancing focus | Common for TCP/L4 | ACL-based | Passthrough or termination |

### Decision

Apache httpd with `mod_proxy` and `mod_ssl`. Apache is more prevalent in the financial services companies targeted by this portfolio, particularly those running older JBoss/WebSphere stacks where Apache was the standard front-end proxy. `mod_proxy_balancer` demonstrates load-balancing awareness.

### Consequences

- `mod_proxy_ajp` (AJP connector) could be demonstrated as an alternative to HTTP proxying for WildFly
- Apache configuration is more verbose than Nginx but is representative of what a middleware engineer maintains at an enterprise bank
- **AWS contrast:** ALB replaces Apache entirely in the AWS tier — demonstrating the operational burden reduction when moving to managed load balancing

---

## ADR-006: Ansible Roles over Monolithic Playbooks

**Status:** Accepted
**Date:** 2024-01

### Context

The configuration management layer needed to deploy the Java app, .NET app, and configure the proxy on both Docker-simulated and EC2-based hosts. The question was how to structure the Ansible code.

### Options Considered

| Option | Reusability | Testability | Complexity |
|---|---|---|---|
| Monolithic playbook | Low | Hard to unit test | Low initial, grows |
| **Ansible roles** | **High (role per service)** | **Molecule-testable** | **Moderate** |
| Ansible collections | Very high | Yes | High (overkill for single project) |

### Decision

Ansible roles, one per service (`wildfly`, `dotnet`, `apache`, `common`). Roles are the standard unit of reusability in Ansible and the pattern expected at enterprises using Red Hat Ansible Automation Platform.

### Consequences

- `ansible/roles/wildfly/` handles all WildFly concerns: install, configure, deploy WAR, service management
- `ansible/roles/dotnet/` mirrors the pattern for .NET
- Roles can be tested independently with Molecule (not implemented here but structure supports it)
- `ansible/aws.yml` and `ansible/onprem.yml` are thin playbooks that import roles
- **Enterprise reference:** Red Hat Ansible Automation Platform (AAP) organizes content as collections of roles; this project's role structure maps directly to that model

---

## ADR-007: Terraform Remote State in S3

**Status:** Accepted
**Date:** 2024-01

### Context

Terraform state needs to be stored somewhere accessible to both local developers and the GitHub Actions CI pipeline.

### Decision

S3 backend with DynamoDB state locking. S3 provides versioning (rollback to previous state), DynamoDB prevents concurrent apply conflicts, and the bucket is created separately (bootstrap step) to avoid chicken-and-egg problems.

### Consequences

- State file contains sensitive data — bucket has versioning, encryption, and public access blocked
- CI pipeline needs S3 read/write permissions (included in OIDC role policy)
- Local developers need the same OIDC role or explicit AWS credentials
- `terraform/backend.tf` uses partial configuration — secrets passed at `init` time via `-backend-config`
