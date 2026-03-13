# NexusMidplane — Architecture

## Overview

NexusMidplane is a hybrid infrastructure portfolio project that simulates an enterprise middleware platform straddling on-premises infrastructure and AWS. It demonstrates the operational patterns a middleware/DevOps engineer encounters at financial services companies: dual-tier deployments, load balancing, configuration management, CI/CD pipelines, and the tradeoffs between cloud-managed and self-managed services.

**Stack summary:**

| Layer | On-Prem (Simulated) | AWS |
|---|---|---|
| Runtime | Docker containers (local) | EC2 instances |
| Java app | WildFly (JBoss) | WildFly on EC2 |
| .NET app | Kestrel / .NET 8 | .NET 8 on EC2 |
| Proxy | Apache httpd | Application Load Balancer |
| Networking | Docker bridge network | VPC + subnets + SGs |
| IaC | docker-compose | Terraform |
| Config Mgmt | Ansible (local) | Ansible (AWS dynamic inventory) |
| Certificates | Manual / self-signed | ACM (auto-renewed) |

---

## Network Topology

```mermaid
graph TB
    subgraph Internet
        USER[("👤 User / CI Runner")]
    end

    subgraph AWS["AWS (us-east-1)"]
        subgraph VPC["VPC: 10.0.0.0/16"]
            IGW[Internet Gateway]

            subgraph PublicSubnets["Public Subnets (10.0.1.0/24, 10.0.2.0/24)"]
                ALB["Application Load Balancer\n(internet-facing)"]
                NATGW["NAT Gateway"]
            end

            subgraph PrivateSubnets["Private Subnets (10.0.11.0/24, 10.0.12.0/24)"]
                EC2_JAVA["EC2: Java App\n(WildFly)\nt3.small"]
                EC2_DOTNET["EC2: .NET App\n(Kestrel)\nt3.small"]
            end

            subgraph SecurityGroups["Security Groups"]
                SG_ALB["SG: alb\n0.0.0.0/0 :80/:443"]
                SG_APP["SG: app-servers\nALB SG :8080/:5000\n0.0.0.0/0 :22 (restricted)"]
            end
        end

        S3["S3 Bucket\n(artifacts, TF state)"]
        ACM["ACM\n(TLS cert — auto)"]
        IAM["IAM\n(OIDC role for CI)"]
        CW["CloudWatch\n(logs + metrics)"]
    end

    subgraph OnPrem["On-Prem (Docker Simulation)"]
        subgraph DockerNet["Bridge Network: nexus-net"]
            APACHE["Apache httpd\n:80 / :443"]
            WILDFLY["WildFly container\n:8080"]
            DOTNET_C["Kestrel container\n:5000"]
        end
        CERTS["Self-signed certs\n(/docker/certs)"]
    end

    USER -->|HTTPS :443| ALB
    USER -->|HTTP :80| APACHE
    ALB -->|:8080| EC2_JAVA
    ALB -->|:5000| EC2_DOTNET
    APACHE -->|mod_proxy :8080| WILDFLY
    APACHE -->|mod_proxy :5000| DOTNET_C
    EC2_JAVA -->|logs| CW
    EC2_DOTNET -->|logs| CW
    IGW --- ALB
    NATGW --- EC2_JAVA
    NATGW --- EC2_DOTNET
    ACM -. "cert" .-> ALB
    CERTS -. "cert" .-> APACHE
```

---

## Data Flow — Request Path

```mermaid
sequenceDiagram
    actor User
    participant ALB as ALB / Apache
    participant App as WildFly / Kestrel
    participant Log as CloudWatch / Docker logs

    User->>ALB: HTTPS GET /java/hello
    ALB->>ALB: Listener rule: /java/* → java-tg
    ALB->>App: HTTP :8080/java/hello (SSL terminated at ALB)
    App->>App: Process request
    App-->>ALB: HTTP 200 + JSON response
    ALB-->>User: HTTPS 200 + response body

    App->>Log: Access log entry
    Note over ALB,App: On-prem: Apache mod_proxy replaces ALB<br/>TLS termination at Apache, not the app
```

---

## Deployment Pipeline Flow

```mermaid
flowchart LR
    GH[("GitHub\npush/PR")]
    LINT["lint\nterraform fmt\nansible-lint"]
    BJ["build-java\nmvn package WAR"]
    BN["build-dotnet\ndotnet publish"]
    TP["terraform-plan\nOIDC → AWS\nterraform plan"]
    TA["terraform-apply\n⏸ manual approval\nterraform apply"]
    ANS["ansible-configure\naws_ec2.yml\nplaybook"]
    SMOKE["smoke-tests\ncurl /health\nassert 200"]
    NOTIFY["notify\nSlack / webhook"]
    DESTROY["destroy\n⏸ manual approval\nterraform destroy"]

    GH --> LINT
    GH --> BJ
    GH --> BN
    LINT --> TP
    TP -->|action=apply| TA
    TA --> ANS
    BJ --> ANS
    BN --> ANS
    ANS --> SMOKE
    SMOKE --> NOTIFY
    GH -->|action=destroy| DESTROY

    style TA fill:#f90,color:#000
    style DESTROY fill:#f33,color:#fff
```

---

## On-Prem Docker Topology

```mermaid
graph LR
    subgraph Host["Developer Laptop / CI Runner"]
        subgraph DockerNet["Docker bridge: nexus-net (172.20.0.0/24)"]
            APACHE_C["apache\n172.20.0.2\n:80→80, :443→443"]
            WF_C["wildfly\n172.20.0.3\n:8080"]
            DN_C["dotnet\n172.20.0.4\n:5000"]
        end

        VOL_CERTS[("Volume\ncerts/")]
        VOL_CONF[("Volume\nconfigs/")]
        VOL_WAR[("Volume\ntarget/*.war")]
        VOL_PUB[("Volume\npublish/")]
    end

    CLIENT[("Browser\n/ curl")]
    CLIENT -->|:80| APACHE_C
    CLIENT -->|:443| APACHE_C
    APACHE_C -->|mod_proxy\n/java/*| WF_C
    APACHE_C -->|mod_proxy\n/dotnet/*| DN_C
    VOL_CERTS -. mount .-> APACHE_C
    VOL_CONF  -. mount .-> APACHE_C
    VOL_WAR   -. mount .-> WF_C
    VOL_PUB   -. mount .-> DN_C
```

---

## VPN / Hybrid Connectivity (Conceptual)

In a real enterprise deployment, on-prem servers connect to AWS over a Site-to-Site VPN or AWS Direct Connect. This project simulates that boundary with a split deployment:

```mermaid
graph LR
    subgraph DataCenter["On-Prem Data Center"]
        ONPREM_APP["App Servers\n(WildFly, Apache)"]
        ONPREM_DB["Database\n(Oracle / MSSQL)"]
        VPN_GW["VPN Gateway\n(Cisco / Palo Alto)"]
    end

    subgraph AWS
        VGW["Virtual Private Gateway"]
        PRIV_SUBNET["Private Subnet\n(EC2 instances)"]
        RDS["RDS\n(MySQL / Postgres)"]
    end

    VPN_GW <-->|"IPSec tunnel\n(BGP routing)"| VGW
    VGW --- PRIV_SUBNET
    ONPREM_APP -->|"Internal traffic\nvia VPN"| PRIV_SUBNET
    ONPREM_DB -. "replication\n(conceptual)" .-> RDS

    style VPN_GW fill:#f96,color:#000
    style VGW fill:#f96,color:#000
```

> **Portfolio note:** This project uses Docker locally to simulate the on-prem tier and AWS for the cloud tier. The VPN is represented architecturally; in a real engagement, Terraform's `aws_vpn_connection` and `aws_customer_gateway` resources would provision the tunnel.

---

## Key Design Properties

| Property | Decision | Rationale |
|---|---|---|
| **IaC** | Terraform | Declarative, AWS-native, state management |
| **Config mgmt** | Ansible | Agentless, SSH-based, familiar in enterprise |
| **Java app server** | WildFly | Open-source JBoss equivalent, same deployment model |
| **On-prem proxy** | Apache httpd | mod_proxy, mod_ssl, enterprise standard |
| **AWS proxy** | ALB | Managed, auto-scaled, ACM integration |
| **CI/CD** | GitHub Actions | OIDC, no stored keys, AWS-native |
| **On-prem sim** | Docker | Portable, reproducible, no VM overhead |
