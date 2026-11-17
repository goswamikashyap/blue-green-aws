# Zero-Downtime Blue-Green Deployment on AWS EC2

Production-grade Blue-Green deployment pipeline utilizing **Multi-Stage Distroless Docker containers** and an automated **Nginx reverse proxy** traffic switcher with built-in health check gating and automatic rollback.

## Key Engineering Highlights
1. **Hardened Multi-Stage Distroless Image (~13 MB):** Compiles a static Go HTTP service in Stage 1 (`golang:1.22-alpine`) and runs it in Stage 2 (`gcr.io/distroless/static-debian12:nonroot`) as a non-root user with zero Linux shell or package manager attack surface.
2. **Isolated Docker Bridge Networking (`bg-net`):** Routes internal proxy traffic directly between `nginx-proxy` and `app-blue` / `app-green` containers without exposing backend ports publicly.
3. **Automated Health Gating & Instant Rollback:** Validates `HTTP 200` on `/health` before reloading Nginx (`nginx -s reload`). Unhealthy deployments are automatically terminated while 100% of live user traffic remains safely on the active environment.

## Repository Structure
```text
├── app/
│   └── main.go             # Lightweight Go service with / and /health endpoints
├── nginx/
│   └── default.conf        # Dynamic Nginx upstream routing configuration
├── scripts/
│   ├── setup.sh            # Bootstraps Distroless image, bg-net, Blue, and Nginx
│   └── deploy.sh           # Zero-downtime Blue-Green switcher with rollback
├── Dockerfile              # Multi-stage non-root Distroless build
└── README.md
```

## Quick Start (Ubuntu / AWS EC2)
```bash
git clone https://github.com/goswamikashyap/blue-green-aws.git
cd blue-green-aws
chmod +x scripts/setup.sh scripts/deploy.sh

# 1. Bootstrap initial Blue environment (v1.0.0)
./scripts/setup.sh

# 2. Zero-downtime switch to Green (v2.0.0)
./scripts/deploy.sh blue-green-app:v1 v2.0.0

# 3. Test automatic rollback with an unhealthy image
./scripts/deploy.sh nginx:alpine v3.0.0-BROKEN
```

## Live Proof of Execution
 1. Live AWS EC2 Zero-Downtime Switch (`v1.0.0 BLUE` → `v2.0.0 GREEN`) & AWS EC2 Production Server & Running Containers

<img width="1280" height="800" alt="2" src="https://github.com/user-attachments/assets/5c170808-f291-46cc-a22c-0dd33b9a503b" />


 2. Automatic Rollback Protection on Unhealthy Deployment
    
<img width="1280" height="465" alt="3" src="https://github.com/user-attachments/assets/00ec5bb6-e0ef-49b0-849b-a8cc708009c0" />

