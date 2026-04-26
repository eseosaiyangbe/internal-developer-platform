# Local Development Documentation

This directory contains all documentation for local development, testing, and learning with Docker Compose and local Kubernetes.

## 📚 Documentation Index

### 🎯 Learning Path (Follow in Order)

| Step | Guide | Description |
|------|-------|-------------|
| **0** | [Learning Path Overview](./00-overview.md) | Complete tutorial roadmap and architecture |
| **1** | [Prerequisites Setup](./01-prereqs.md) | Install Docker, Kubernetes tools, and dev environment |
| **2** | [Docker Multi-Container App](./02-compose.md) | Build your first containerized application |
| **3** | [Kubernetes Production Deployment](./03-k8s-basics.md) | Deploy apps on Kubernetes with databases |
| **4** | [Internet Access & Networking](./04-ingress.md) | Make your app accessible from the internet |
| **5** | [Performance Monitoring](./05-observability.md) | Track app health with Prometheus & Grafana |
| **6** | [Automated Deployments](./06-gitops.md) | Deploy with GitOps automation |

### 📖 Reference Guides

- **[Troubleshooting](./08-troubleshooting.md)** - Common issues and solutions
- **[FAQ](./09-faq.md)** - Frequently asked questions
- **[Glossary](./10-glossary.md)** - Terms and definitions explained
- **[Decision Notes](./11-decision-notes.md)** - Architecture decisions and rationale
- **[Customization Guide](./customization-guide.md)** - Customize configuration and settings
- **[User Guide](./user-guide.md)** - How to access and use the application
- **[Maintenance Guide](./maintenance-guide.md)** - Maintain and update your local environment

## 🚀 Quick Start

### Docker Compose (Simplest)
```bash
cp .env.example .env
docker-compose up -d
# Access at http://localhost:8080
```

### Local Kubernetes (k3s)
```bash
# Provision the local k3s runtime
../../scripts/ensure-k3s-runtime.sh

# Deploy application
kubectl apply -k ../../k8s/overlays/dev

# Access via Traefik on the k3s node IP
curl -H 'Host: memflip.devops.local' http://192.168.64.2/
```

The authoritative Kubernetes path is:

- [12-phase7-k8s-dev.md](./12-phase7-k8s-dev.md)

The older tutorial-era manifests now live in:

- [../../k8s-legacy-lab/README.md](/Users/raymond/Documents/DevOps-Easy-Learning/MemFlip/k8s-legacy-lab/README.md)

## 🎯 Learning Objectives

By following these guides, you will learn:
- ✅ Container orchestration with Docker and Kubernetes
- ✅ Multi-container application architecture
- ✅ Kubernetes deployments, services, and ingress
- ✅ Monitoring and observability with Prometheus/Grafana
- ✅ GitOps workflows with ArgoCD
- ✅ Production-ready security practices

## ⏱️ Time Investment

- **Fast Track**: 2-3 hours (experienced users)
- **Guided Learning**: 5-8 hours (recommended for beginners)
- **Deep Dive**: 10+ hours (with all exercises and experiments)

## 🔗 Related Documentation

- **[AWS Deployment](../aws/README.md)** - Production AWS infrastructure
- **[Main Documentation](../README.md)** - Complete documentation hub
