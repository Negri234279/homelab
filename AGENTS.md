# AGENTS.md — Homelab RPi5 Scaffold Instructions

> **Para el agente de VS Code**: Este archivo contiene las instrucciones completas para generar la estructura de repositorio del homelab. Lee todo el documento antes de empezar. Genera los archivos **en el orden indicado** y respeta las rutas exactas.

---

## Contexto del proyecto

Homelab en **Raspberry Pi 5** con las siguientes capas:

| Capa | Herramienta |
|---|---|
| Provisioning OS | Ansible |
| Orquestación containers | K3s (Kubernetes ligero) |
| GitOps / Deploy | Flux CD |
| Ingress + TLS | Traefik v3 |
| DNS local | Pi-hole |
| DNS automation | Terraform (providers: Cloudflare + Pi-hole) |
| Secrets en Git | Sealed Secrets |
| Registry privado | Docker Registry local en K3s |

**Dominio base**: `*.negri.es` gestionado en Cloudflare  
**Red local**: `192.168.1.0/24`  
**RPi5 IP local**: `192.168.1.7`  
**RPi3 IP local** (futuro worker): `192.168.1.6`

---

## Instrucciones para el agente

1. Genera **todos** los archivos listados en la sección "Estructura del repo"
2. Usa los **contenidos exactos** de cada sección de spec
3. Los placeholders entre `<< >>` son valores que el usuario debe rellenar
4. Donde se indique `# TODO:`, añade un comentario en el archivo generado
5. No generes archivos fuera de la estructura definida
6. Al terminar, muestra un resumen de archivos creados

---

## Estructura del repo a generar

```
homelab/
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       ├── build-image.yml
│       └── terraform-plan.yml
├── ansible/
│   ├── inventory.yml
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── playbooks/
│   │   ├── bootstrap-rpi5.yml
│   │   ├── bootstrap-rpi3.yml
│   │   └── upgrade.yml
│   └── roles/
│       ├── common/
│       │   ├── tasks/main.yml
│       │   └── defaults/main.yml
│       ├── k3s-server/
│       │   ├── tasks/main.yml
│       │   └── defaults/main.yml
│       ├── k3s-agent/
│       │   ├── tasks/main.yml
│       │   └── defaults/main.yml
│       └── pihole/
│           ├── tasks/main.yml
│           └── defaults/main.yml
├── k8s/
│   ├── flux-system/          ← generado por flux bootstrap, no editar
│   │   └── .gitkeep
│   ├── infrastructure/
│   │   ├── kustomization.yaml
│   │   ├── traefik/
│   │   │   ├── kustomization.yaml
│   │   │   ├── helmrelease.yaml
│   │   │   ├── values.yaml
│   │   │   ├── middlewares.yaml
│   │   │   └── certificate-wildcard.yaml
│   │   ├── cert-manager/
│   │   │   ├── kustomization.yaml
│   │   │   ├── helmrelease.yaml
│   │   │   └── clusterissuer-cloudflare.yaml
│   │   ├── sealed-secrets/
│   │   │   ├── kustomization.yaml
│   │   │   └── helmrelease.yaml
│   │   └── registry/
│   │       ├── kustomization.yaml
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   └── apps/
│       ├── kustomization.yaml
│       └── _template/
│           ├── kustomization.yaml
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── pvc.yaml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── cloudflare-record/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── pihole-record/
│           ├── main.tf
│           └── variables.tf
├── scripts/
│   ├── register-app.sh
│   ├── generate-k8s-manifest.sh
│   ├── generate-tf-cloudflare.sh
│   └── generate-tf-pihole.sh
├── docs/
│   ├── architecture.md
│   ├── adding-new-app.md
│   └── secrets.md
├── homelab.schema.json          ← JSON Schema del homelab.yaml de cada app
├── README.md
└── AGENTS.md                    ← este archivo
```

---

## SPEC: Ansible

### `ansible/ansible.cfg`

```ini
[defaults]
inventory = inventory.yml
remote_user = pi
private_key_file = ~/.ssh/homelab_rsa
host_key_checking = False
stdout_callback = yaml
callbacks_enabled = timer, profile_tasks

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

### `ansible/inventory.yml`

```yaml
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3

  children:
    servers:
      hosts:
        rpi5:
          ansible_host: 192.168.1.7
          ansible_user: pi
          k3s_role: server
          node_labels:
            - "node-role.kubernetes.io/master=true"
            - "storage=local"

    workers:
      hosts:
        rpi3:                             # Descomentar cuando esté disponible
          ansible_host: 192.168.1.6
          ansible_user: pi
          k3s_role: agent
          k3s_server_url: https://192.168.1.7:6443
          node_labels:
            - "role=backup"
            - "storage=backup"
```

### `ansible/requirements.yml`

```yaml
roles:
  - name: geerlingguy.pip
    version: "2.2.0"
  - name: geerlingguy.docker
    version: "7.0.0"

collections:
  - name: community.general
    version: ">=8.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
  - name: kubernetes.core
    version: ">=3.0.0"
```

### `ansible/playbooks/bootstrap-rpi5.yml`

```yaml
---
- name: Bootstrap RPi5 — Server Node
  hosts: rpi5
  become: true
  gather_facts: true

  pre_tasks:
    - name: Verify OS is Raspberry Pi OS (Debian-based)
      ansible.builtin.assert:
        that: ansible_os_family == "Debian"
        fail_msg: "Este playbook requiere Debian/Raspberry Pi OS"

  roles:
    - role: common
      tags: [common]
    - role: k3s-server
      tags: [k3s]
    - role: pihole
      tags: [pihole]

  post_tasks:
    - name: Mostrar info del cluster
      ansible.builtin.command: kubectl get nodes
      register: nodes_output
      changed_when: false

    - name: Print nodes
      ansible.builtin.debug:
        msg: "{{ nodes_output.stdout_lines }}"
```

### `ansible/playbooks/bootstrap-rpi3.yml`

```yaml
---
- name: Bootstrap RPi3 — Worker Node (Backup)
  hosts: rpi3
  become: true
  gather_facts: true

  vars_prompt:
    - name: k3s_token
      prompt: "Token K3s del servidor (cat /var/lib/rancher/k3s/server/node-token en rpi5)"
      private: true

  roles:
    - role: common
      tags: [common]
    - role: k3s-agent
      tags: [k3s]
      vars:
        k3s_server_token: "{{ k3s_token }}"
```

### `ansible/roles/common/tasks/main.yml`

```yaml
---
- name: Actualizar apt cache y paquetes base
  ansible.builtin.apt:
    update_cache: true
    upgrade: safe
    cache_valid_time: 3600

- name: Instalar paquetes esenciales
  ansible.builtin.apt:
    name:
      - curl
      - wget
      - git
      - vim
      - htop
      - jq
      - yq
      - nfs-common
      - open-iscsi
      - python3-pip
      - ca-certificates
      - gnupg
      - lsb-release
    state: present

- name: Configurar hostname
  ansible.builtin.hostname:
    name: "{{ inventory_hostname }}"

- name: Configurar timezone
  community.general.timezone:
    name: "{{ common_timezone }}"

- name: Habilitar cgroups para K3s (RPi)
  ansible.builtin.lineinfile:
    path: /boot/firmware/cmdline.txt
    backrefs: true
    regexp: '^((?!.*cgroup_enable).*)$'
    line: '\1 cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1'
  notify: Reiniciar sistema

- name: Configurar SSH hardening
  ansible.builtin.template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    mode: "0600"
  notify: Reiniciar SSH

- name: Configurar fail2ban
  ansible.builtin.apt:
    name: fail2ban
    state: present

handlers:
  - name: Reiniciar SSH
    ansible.builtin.service:
      name: ssh
      state: restarted

  - name: Reiniciar sistema
    ansible.builtin.reboot:
      reboot_timeout: 300
```

### `ansible/roles/common/defaults/main.yml`

```yaml
---
common_timezone: "Europe/Madrid"
common_locale: "es_ES.UTF-8"
common_ssh_port: 22
common_allowed_ssh_users:
  - pi
```

### `ansible/roles/k3s-server/tasks/main.yml`

```yaml
---
- name: Comprobar si K3s ya está instalado
  ansible.builtin.stat:
    path: /usr/local/bin/k3s
  register: k3s_binary

- name: Instalar K3s server
  ansible.builtin.shell: |
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="{{ k3s_version }}" sh -s - server \
      --disable traefik \
      --disable servicelb \
      --disable local-storage \
      --cluster-cidr=10.42.0.0/16 \
      --service-cidr=10.43.0.0/16 \
      --flannel-iface=eth0 \
      --write-kubeconfig-mode=644
  when: not k3s_binary.stat.exists
  args:
    creates: /usr/local/bin/k3s

- name: Esperar que K3s esté listo
  ansible.builtin.wait_for:
    path: /var/lib/rancher/k3s/server/node-token
    timeout: 120

- name: Leer node-token
  ansible.builtin.slurp:
    src: /var/lib/rancher/k3s/server/node-token
  register: k3s_node_token

- name: Guardar kubeconfig localmente
  ansible.builtin.fetch:
    src: /etc/rancher/k3s/k3s.yaml
    dest: "~/.kube/homelab-config"
    flat: true

- name: Instalar Flux CLI
  ansible.builtin.shell: |
    curl -s https://fluxcd.io/install.sh | bash
  args:
    creates: /usr/local/bin/flux

- name: Verificar prerequisitos Flux
  ansible.builtin.command: flux check --pre
  changed_when: false
  ignore_errors: true
```

### `ansible/roles/k3s-server/defaults/main.yml`

```yaml
---
k3s_version: "v1.31.0+k3s1"    # TODO: actualizar a versión estable más reciente
k3s_config_dir: /etc/rancher/k3s
flux_github_repo: "<<TU_USUARIO>>/homelab"
flux_github_branch: main
```

### `ansible/roles/pihole/tasks/main.yml`

```yaml
---
- name: Crear directorio de configuración Pi-hole
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - /etc/pihole
    - /var/log/pihole

- name: Copiar setupVars para instalación silenciosa
  ansible.builtin.template:
    src: setupVars.conf.j2
    dest: /etc/pihole/setupVars.conf
    mode: "0644"

- name: Instalar Pi-hole
  ansible.builtin.shell: |
    curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
  args:
    creates: /usr/local/bin/pihole

- name: Configurar DNS local wildcard para negri.es
  ansible.builtin.copy:
    content: |
      address=/negri.es/{{ pihole_local_ip }}
    dest: /etc/dnsmasq.d/02-negri-local.conf
    mode: "0644"
  notify: Reiniciar Pi-hole

- name: Asegurar que Pi-hole esté habilitado
  ansible.builtin.service:
    name: pihole-FTL
    enabled: true
    state: started

handlers:
  - name: Reiniciar Pi-hole
    ansible.builtin.command: pihole restartdns
    changed_when: true
```

### `ansible/roles/pihole/defaults/main.yml`

```yaml
---
pihole_local_ip: "192.168.1.7"
pihole_web_password: "<<CAMBIAR_EN_VAULT>>"
pihole_dns_upstream_1: "1.1.1.1"
pihole_dns_upstream_2: "8.8.8.8"
pihole_domain: "lan"
pihole_rev_server: false
```

---

## SPEC: K8s — Infrastructure

### `k8s/infrastructure/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - cert-manager/
  - traefik/
  - sealed-secrets/
  - registry/
```

### `k8s/infrastructure/traefik/helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: traefik
  namespace: traefik
spec:
  interval: 1h
  chart:
    spec:
      chart: traefik
      version: ">=30.0.0 <31.0.0"
      sourceRef:
        kind: HelmRepository
        name: traefik
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: traefik-values
```

### `k8s/infrastructure/traefik/values.yaml`

```yaml
# Referenciado por traefik/helmrelease.yaml como ConfigMap
deployment:
  replicas: 1

ports:
  web:
    port: 8000
    exposedPort: 80
    redirectTo:
      port: websecure
  websecure:
    port: 8443
    exposedPort: 443
    tls:
      enabled: true

service:
  type: LoadBalancer
  spec:
    loadBalancerIP: "192.168.1.7"

additionalArguments:
  - "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
  - "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
  - "--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
  - "--certificatesresolvers.cloudflare.acme.email=<<TU_EMAIL>>"
  - "--certificatesresolvers.cloudflare.acme.storage=/data/acme.json"
  - "--log.level=INFO"
  - "--accesslog=true"
  - "--api.dashboard=true"
  - "--api.insecure=false"

env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: token

persistence:
  enabled: true
  storageClass: local-path
  size: 128Mi

ingressRoute:
  dashboard:
    enabled: true
    entryPoints: ["websecure"]
    matchRule: "Host(`traefik.negri.es`)"
    middlewares:
      - name: private-allowlist

rbac:
  enabled: true

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi
```

### `k8s/infrastructure/traefik/middlewares.yaml`

```yaml
---
# Middleware: solo acceso desde red local y VPN
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: private-allowlist
  namespace: traefik
spec:
  ipAllowList:
    sourceRange:
      - "192.168.1.0/24"          # Red local
      - "10.0.0.0/8"             # VPN (ajustar según tu configuración)
      - "127.0.0.1/32"
      - "::1/128"
---
# Middleware: headers de seguridad para apps públicas
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: secure-headers
  namespace: traefik
spec:
  headers:
    browserXssFilter: true
    contentTypeNosniff: true
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsPreload: true
    stsSeconds: 31536000
    customFrameOptionsValue: "SAMEORIGIN"
    referrerPolicy: "strict-origin-when-cross-origin"
---
# Middleware: rate limiting para apps públicas
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit-public
  namespace: traefik
spec:
  rateLimit:
    average: 100
    burst: 50
```

### `k8s/infrastructure/traefik/certificate-wildcard.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-negri-es
  namespace: traefik
spec:
  secretName: wildcard-negri-es-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "negri.es"
    - "*.negri.es"
  privateKey:
    algorithm: RSA
    size: 4096
```

### `k8s/infrastructure/cert-manager/clusterissuer-cloudflare.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <<TU_EMAIL>>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: token
        selector:
          dnsZones:
            - "negri.es"
---
# Issuer de staging para testing (evita rate limits)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: <<TU_EMAIL>>
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: token
        selector:
          dnsZones:
            - "negri.es"
```

### `k8s/infrastructure/cert-manager/helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 1h
  chart:
    spec:
      chart: cert-manager
      version: ">=1.16.0 <2.0.0"
      sourceRef:
        kind: HelmRepository
        name: jetstack
        namespace: flux-system
  install:
    crds: Create
  upgrade:
    crds: CreateReplace
  values:
    installCRDs: false    # Gestionado por install.crds
    global:
      leaderElection:
        namespace: cert-manager
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi
```

### `k8s/infrastructure/sealed-secrets/helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: sealed-secrets
  namespace: kube-system
spec:
  interval: 1h
  releaseName: sealed-secrets
  chart:
    spec:
      chart: sealed-secrets
      version: ">=2.16.0 <3.0.0"
      sourceRef:
        kind: HelmRepository
        name: sealed-secrets
        namespace: flux-system
  values:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        memory: 128Mi
```

---

## SPEC: K8s — Template de app

> **IMPORTANTE**: Este es el template que se copia para cada nueva app. No editar directamente, usar `scripts/register-app.sh`.

### `k8s/apps/_template/deployment.yaml`

```yaml
# TEMPLATE — sustituir APP_NAME, APP_IMAGE, APP_PORT, APP_NAMESPACE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME
  namespace: APP_NAMESPACE
  labels:
    app: APP_NAME
    managed-by: homelab-scripts
spec:
  replicas: 1
  selector:
    matchLabels:
      app: APP_NAME
  template:
    metadata:
      labels:
        app: APP_NAME
    spec:
      containers:
        - name: APP_NAME
          image: APP_IMAGE
          ports:
            - containerPort: APP_PORT
              protocol: TCP
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "APP_MEMORY_LIMIT"
          env: []          # Rellenar según homelab.yaml
          volumeMounts: [] # Rellenar si tiene volúmenes
      volumes: []          # Rellenar si tiene volúmenes
      securityContext:
        runAsNonRoot: true
```

### `k8s/apps/_template/ingress.yaml`

```yaml
# TEMPLATE — sustituir APP_NAME, APP_SUBDOMAIN, APP_PORT, APP_VISIBILITY
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: APP_NAME
  namespace: APP_NAMESPACE
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: "cloudflare"
    # Para apps PRIVADAS — descomentar:
    # traefik.ingress.kubernetes.io/router.middlewares: "traefik-private-allowlist@kubernetescrd"
    # Para apps PÚBLICAS — descomentar:
    # traefik.ingress.kubernetes.io/router.middlewares: "traefik-secure-headers@kubernetescrd,traefik-rate-limit-public@kubernetescrd"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  rules:
    - host: APP_SUBDOMAIN.negri.es
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: APP_NAME
                port:
                  number: APP_PORT
  tls:
    - hosts:
        - APP_SUBDOMAIN.negri.es
      secretName: APP_NAME-tls
```

### `k8s/apps/_template/pvc.yaml`

```yaml
# TEMPLATE — sustituir APP_NAME, VOLUME_NAME, VOLUME_SIZE
# Solo incluir si la app tiene volúmenes persistentes
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: APP_NAME-VOLUME_NAME
  namespace: APP_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: VOLUME_SIZE
```

---

## SPEC: homelab.yaml (schema por app)

> Cada repositorio de aplicación debe incluir este archivo en su raíz.

### `homelab.schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Homelab App Config",
  "type": "object",
  "required": ["app"],
  "properties": {
    "app": {
      "type": "object",
      "required": ["name", "subdomain", "visibility", "port", "image"],
      "properties": {
        "name": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$",
          "description": "Nombre único de la app (lowercase, sin espacios)"
        },
        "subdomain": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$",
          "description": "Subdominio → <subdomain>.negri.es"
        },
        "visibility": {
          "type": "string",
          "enum": ["private", "public"],
          "description": "private: solo LAN, public: internet"
        },
        "port": {
          "type": "integer",
          "minimum": 1,
          "maximum": 65535
        },
        "image": {
          "type": "object",
          "required": ["source"],
          "properties": {
            "source": {
              "type": "string",
              "enum": ["dockerfile", "registry", "ghcr"],
              "description": "dockerfile: build desde repo, registry: imagen pública, ghcr: GitHub Container Registry"
            },
            "dockerfile": {
              "type": "string",
              "default": "./Dockerfile"
            },
            "registry": {
              "type": "string",
              "description": "Imagen completa, ej: nginx:alpine"
            },
            "tag_strategy": {
              "type": "string",
              "enum": ["semver", "sha", "latest"],
              "default": "sha"
            }
          }
        },
        "namespace": {
          "type": "string",
          "default": "apps"
        },
        "resources": {
          "type": "object",
          "properties": {
            "memory": { "type": "string", "default": "256Mi" },
            "cpu": { "type": "string", "default": "250m" }
          }
        },
        "volumes": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["name", "size", "mountPath"],
            "properties": {
              "name": { "type": "string" },
              "size": { "type": "string" },
              "mountPath": { "type": "string" }
            }
          }
        },
        "env": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "value": { "type": "string" },
              "secretRef": { "type": "string" }
            }
          }
        },
        "healthcheck": {
          "type": "object",
          "properties": {
            "path": { "type": "string", "default": "/" },
            "port": { "type": "integer" }
          }
        }
      }
    }
  }
}
```

### Ejemplo `homelab.yaml` para app privada

```yaml
# homelab.yaml — colocar en la raíz del repo de la app
app:
  name: grafana
  subdomain: grafana
  visibility: private          # Solo accesible desde LAN
  port: 3000
  
  image:
    source: registry
    registry: grafana/grafana:latest
    tag_strategy: semver
  
  namespace: apps
  
  resources:
    memory: 512Mi
    cpu: 500m
  
  volumes:
    - name: data
      size: 5Gi
      mountPath: /var/lib/grafana
  
  env:
    - name: GF_SECURITY_ADMIN_USER
      value: admin
    - name: GF_SECURITY_ADMIN_PASSWORD
      secretRef: grafana-secret          # Sealed Secret con key "password"
    - name: GF_SERVER_DOMAIN
      value: grafana.negri.es
  
  healthcheck:
    path: /api/health
    port: 3000
```

### Ejemplo `homelab.yaml` para app pública

```yaml
# homelab.yaml — app con acceso público + Cloudflare
app:
  name: blog
  subdomain: blog
  visibility: public           # DNS en Cloudflare, acceso desde internet
  port: 80
  
  image:
    source: dockerfile
    dockerfile: ./Dockerfile
    tag_strategy: sha
  
  namespace: apps
  
  resources:
    memory: 128Mi
    cpu: 100m
  
  healthcheck:
    path: /
    port: 80
```

---

## SPEC: Terraform

### `terraform/providers.tf`

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # TODO: Configurar backend remoto (Terraform Cloud o S3)
  # backend "s3" {
  #   bucket = "homelab-tfstate"
  #   key    = "homelab/terraform.tfstate"
  #   region = "eu-west-1"
  # }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

### `terraform/variables.tf`

```hcl
variable "cloudflare_api_token" {
  description = "Cloudflare API Token con permisos Zone:Edit y DNS:Edit"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID de negri.es en Cloudflare"
  type        = string
}

variable "rpi5_public_ip" {
  description = "IP pública del router (para apps públicas)"
  type        = string
}

variable "rpi5_local_ip" {
  description = "IP local del RPi5 (192.168.1.7)"
  type        = string
  default     = "192.168.1.7"
}

variable "pihole_host" {
  description = "Host SSH del RPi5 para gestionar Pi-hole"
  type        = string
  default     = "pi@192.168.1.7"
}

variable "pihole_ssh_key" {
  description = "Ruta a la clave SSH privada para conectar al RPi5"
  type        = string
  default     = "~/.ssh/homelab_rsa"
}
```

### `terraform/main.tf`

```hcl
# Apps desplegadas — este archivo es gestionado por register-app.sh
# No editar manualmente, usar: ./scripts/register-app.sh

# Ejemplo de app privada (DNS en Pi-hole):
# module "grafana_dns" {
#   source    = "./modules/pihole-record"
#   name      = "grafana"
#   local_ip  = var.rpi5_local_ip
#   pihole_host   = var.pihole_host
#   pihole_ssh_key = var.pihole_ssh_key
# }

# Ejemplo de app pública (DNS en Cloudflare):
# module "blog_dns" {
#   source       = "./modules/cloudflare-record"
#   name         = "blog"
#   zone_id      = var.cloudflare_zone_id
#   public_ip    = var.rpi5_public_ip
#   proxied      = true
# }
```

### `terraform/modules/cloudflare-record/main.tf`

```hcl
resource "cloudflare_record" "app" {
  zone_id = var.zone_id
  name    = var.name          # subdomain
  content = var.public_ip
  type    = "A"
  ttl     = 1                 # Auto cuando proxied=true
  proxied = var.proxied
}

# Registrar subdominio www si es necesario
resource "cloudflare_record" "app_www" {
  count   = var.create_www ? 1 : 0
  zone_id = var.zone_id
  name    = "www.${var.name}"
  content = var.public_ip
  type    = "A"
  ttl     = 1
  proxied = var.proxied
}
```

### `terraform/modules/cloudflare-record/variables.tf`

```hcl
variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "name" {
  description = "Nombre del subdominio (sin .negri.es)"
  type        = string
}

variable "public_ip" {
  description = "IP pública para el registro A"
  type        = string
}

variable "proxied" {
  description = "Si Cloudflare actúa como proxy (CDN + protección)"
  type        = bool
  default     = true
}

variable "create_www" {
  description = "Crear también registro www.subdominio"
  type        = bool
  default     = false
}
```

### `terraform/modules/pihole-record/main.tf`

```hcl
resource "null_resource" "pihole_dns_record" {
  triggers = {
    name     = var.name
    local_ip = var.local_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ${var.pihole_ssh_key} -o StrictHostKeyChecking=no ${var.pihole_host} \
        "echo 'address=/${var.name}.negri.es/${var.local_ip}' | \
         sudo tee /etc/dnsmasq.d/02-${var.name}.conf && \
         sudo pihole restartdns"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -i ${self.triggers.pihole_ssh_key} -o StrictHostKeyChecking=no ${var.pihole_host} \
        "sudo rm -f /etc/dnsmasq.d/02-${self.triggers.name}.conf && \
         sudo pihole restartdns"
    EOT
  }
}
```

### `terraform/modules/pihole-record/variables.tf`

```hcl
variable "name" {
  description = "Nombre del subdominio"
  type        = string
}

variable "local_ip" {
  description = "IP local a la que apunta el dominio"
  type        = string
}

variable "pihole_host" {
  description = "SSH user@host del RPi5"
  type        = string
}

variable "pihole_ssh_key" {
  description = "Ruta a la clave SSH privada"
  type        = string
}
```

### `terraform/terraform.tfvars.example`

```hcl
# Copiar a terraform.tfvars y rellenar valores reales
# NUNCA commitear terraform.tfvars al repo

cloudflare_api_token = "<<TU_CF_API_TOKEN>>"
cloudflare_zone_id   = "<<TU_ZONE_ID>>"
rpi5_public_ip       = "<<TU_IP_PUBLICA>>"
rpi5_local_ip        = "192.168.1.7"
pihole_host          = "pi@192.168.1.7"
pihole_ssh_key       = "~/.ssh/homelab_rsa"
```

---

## SPEC: Scripts

### `scripts/register-app.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# register-app.sh — Registra una app en el homelab
# Uso: ./scripts/register-app.sh /ruta/al/repo-de-la-app
# =============================================================================

APP_REPO="${1:?Error: proporciona la ruta al repo de la app}"
CONFIG="$APP_REPO/homelab.yaml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Verificar dependencias
for cmd in yq kubectl terraform git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Dependencia no encontrada: $cmd"
    exit 1
  fi
done

# Verificar que existe homelab.yaml
if [[ ! -f "$CONFIG" ]]; then
  echo "❌ No se encontró homelab.yaml en $APP_REPO"
  exit 1
fi

# Parsear configuración
NAME=$(yq '.app.name' "$CONFIG")
SUBDOMAIN=$(yq '.app.subdomain' "$CONFIG")
VISIBILITY=$(yq '.app.visibility' "$CONFIG")
PORT=$(yq '.app.port' "$CONFIG")
NAMESPACE=$(yq '.app.namespace // "apps"' "$CONFIG")
IMAGE_SOURCE=$(yq '.app.image.source' "$CONFIG")
MEMORY=$(yq '.app.resources.memory // "256Mi"' "$CONFIG")

echo "🚀 Registrando app: $NAME"
echo "   Subdominio: $SUBDOMAIN.negri.es"
echo "   Visibilidad: $VISIBILITY"
echo "   Puerto: $PORT"
echo "   Namespace: $NAMESPACE"

# 1. Generar manifests K8s
K8S_DIR="$REPO_ROOT/k8s/apps/$NAME"
echo ""
echo "📦 Generando manifests K8s en $K8S_DIR..."
"$SCRIPT_DIR/generate-k8s-manifest.sh" "$CONFIG" "$K8S_DIR"

# 2. Generar Terraform DNS
echo ""
echo "🌐 Configurando DNS ($VISIBILITY)..."
TF_FILE="$REPO_ROOT/terraform/apps/${NAME}.tf"
mkdir -p "$REPO_ROOT/terraform/apps"

if [[ "$VISIBILITY" == "public" ]]; then
  "$SCRIPT_DIR/generate-tf-cloudflare.sh" "$NAME" "$SUBDOMAIN" > "$TF_FILE"
  echo "   → Registro A en Cloudflare para $SUBDOMAIN.negri.es"
else
  "$SCRIPT_DIR/generate-tf-pihole.sh" "$NAME" "$SUBDOMAIN" > "$TF_FILE"
  echo "   → Registro dnsmasq en Pi-hole para $SUBDOMAIN.negri.es"
fi

# 3. Aplicar Terraform
echo ""
echo "⚙️  Aplicando Terraform DNS..."
cd "$REPO_ROOT/terraform"
terraform init -upgrade -input=false
terraform apply -target="module.${NAME}_dns" -auto-approve -input=false

# 4. Git commit y push
echo ""
echo "📤 Haciendo commit y push..."
cd "$REPO_ROOT"
git add "k8s/apps/$NAME/" "terraform/apps/${NAME}.tf"
git commit -m "feat: add app $NAME ($SUBDOMAIN.negri.es, $VISIBILITY)"
git push

echo ""
echo "✅ App '$NAME' registrada exitosamente."
echo "   Flux desplegará la app en ~2 minutos."
echo "   URL: https://$SUBDOMAIN.negri.es"
```

### `scripts/generate-k8s-manifest.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIG="$1"
OUTPUT_DIR="$2"

NAME=$(yq '.app.name' "$CONFIG")
SUBDOMAIN=$(yq '.app.subdomain' "$CONFIG")
VISIBILITY=$(yq '.app.visibility' "$CONFIG")
PORT=$(yq '.app.port' "$CONFIG")
NAMESPACE=$(yq '.app.namespace // "apps"' "$CONFIG")
IMAGE_SOURCE=$(yq '.app.image.source' "$CONFIG")
MEMORY=$(yq '.app.resources.memory // "256Mi"' "$CONFIG")
CPU=$(yq '.app.resources.cpu // "250m"' "$CONFIG")

# Determinar imagen
if [[ "$IMAGE_SOURCE" == "registry" ]]; then
  IMAGE=$(yq '.app.image.registry' "$CONFIG")
elif [[ "$IMAGE_SOURCE" == "dockerfile" ]]; then
  IMAGE="registry.local/$NAME:latest"    # Registry local en K3s
elif [[ "$IMAGE_SOURCE" == "ghcr" ]]; then
  IMAGE="ghcr.io/<<TU_USUARIO>>/$NAME:latest"
fi

# Determinar middleware de Traefik según visibilidad
if [[ "$VISIBILITY" == "private" ]]; then
  MIDDLEWARE="traefik-private-allowlist@kubernetescrd"
else
  MIDDLEWARE="traefik-secure-headers@kubernetescrd,traefik-rate-limit-public@kubernetescrd"
fi

mkdir -p "$OUTPUT_DIR"

# kustomization.yaml
cat > "$OUTPUT_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
EOF

# Añadir PVC si hay volúmenes
if yq -e '.app.volumes | length > 0' "$CONFIG" &>/dev/null; then
  echo "  - pvc.yaml" >> "$OUTPUT_DIR/kustomization.yaml"
fi

# deployment.yaml
cat > "$OUTPUT_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
  namespace: $NAMESPACE
  labels:
    app: $NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
        - name: $NAME
          image: $IMAGE
          ports:
            - containerPort: $PORT
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "$MEMORY"
              cpu: "$CPU"
EOF

# service.yaml
cat > "$OUTPUT_DIR/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  selector:
    app: $NAME
  ports:
    - port: $PORT
      targetPort: $PORT
      protocol: TCP
EOF

# ingress.yaml
cat > "$OUTPUT_DIR/ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $NAME
  namespace: $NAMESPACE
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: "cloudflare"
    traefik.ingress.kubernetes.io/router.middlewares: "$MIDDLEWARE"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  rules:
    - host: $SUBDOMAIN.negri.es
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $NAME
                port:
                  number: $PORT
  tls:
    - hosts:
        - $SUBDOMAIN.negri.es
      secretName: $NAME-tls
EOF

echo "✅ Manifests K8s generados en $OUTPUT_DIR"
```

### `scripts/generate-tf-cloudflare.sh`

```bash
#!/usr/bin/env bash
# Genera módulo Terraform para DNS público en Cloudflare
NAME="$1"
SUBDOMAIN="$2"

cat <<EOF
# Auto-generado por register-app.sh — no editar
module "${NAME}_dns" {
  source     = "./modules/cloudflare-record"
  name       = "$SUBDOMAIN"
  zone_id    = var.cloudflare_zone_id
  public_ip  = var.rpi5_public_ip
  proxied    = true
}
EOF
```

### `scripts/generate-tf-pihole.sh`

```bash
#!/usr/bin/env bash
# Genera módulo Terraform para DNS local en Pi-hole
NAME="$1"
SUBDOMAIN="$2"

cat <<EOF
# Auto-generado por register-app.sh — no editar
module "${NAME}_dns" {
  source         = "./modules/pihole-record"
  name           = "$SUBDOMAIN"
  local_ip       = var.rpi5_local_ip
  pihole_host    = var.pihole_host
  pihole_ssh_key = var.pihole_ssh_key
}
EOF
```

---

## SPEC: GitHub Actions

### `.github/workflows/build-image.yml`

```yaml
name: Build & Push Docker Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Leer homelab.yaml
        id: config
        run: |
          echo "name=$(yq '.app.name' homelab.yaml)" >> $GITHUB_OUTPUT
          echo "source=$(yq '.app.image.source' homelab.yaml)" >> $GITHUB_OUTPUT

      - name: Saltar si no es dockerfile
        if: steps.config.outputs.source != 'dockerfile'
        run: |
          echo "Imagen externa, nada que construir"
          exit 0

      - name: Setup Docker Buildx (multi-arch para ARM64)
        uses: docker/setup-buildx-action@v3
        with:
          platforms: linux/arm64

      - name: Login a GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build y Push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/arm64
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### `.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - "terraform/**"

jobs:
  plan:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.7"

      - name: Terraform Init
        run: terraform init -input=false
        env:
          TF_TOKEN_app_terraform_io: ${{ secrets.TF_API_TOKEN }}

      - name: Terraform Plan
        run: |
          terraform plan -input=false -no-color 2>&1 | tee plan.txt
        env:
          TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
          TF_VAR_cloudflare_zone_id: ${{ secrets.CF_ZONE_ID }}
          TF_VAR_rpi5_public_ip: ${{ secrets.RPI5_PUBLIC_IP }}

      - name: Comentar plan en PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/plan.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan\n\`\`\`\n${plan}\n\`\`\``
            });
```

### `.github/copilot-instructions.md`

```markdown
# Copilot Instructions — Homelab RPi5

## Contexto del proyecto
Homelab sobre Kubernetes (K3s) en Raspberry Pi 5. Stack: Ansible + K3s + Flux CD + Traefik + cert-manager + Terraform + Pi-hole.

## Convenciones importantes

### Nuevas apps
Siempre crear un `homelab.yaml` siguiendo el esquema en `/homelab.schema.json`.
Usar `./scripts/register-app.sh` para registrar la app, nunca crear manifests manualmente.

### Visibilidad
- `visibility: private` → Middleware Traefik `private-allowlist` → DNS en Pi-hole vía Terraform
- `visibility: public` → Middleware Traefik `secure-headers + rate-limit-public` → DNS en Cloudflare vía Terraform

### Namespaces K8s
- `traefik` → Traefik y middlewares
- `cert-manager` → cert-manager
- `kube-system` → Sealed Secrets
- `apps` → Todas las apps de usuario

### Secrets
NUNCA commitear secrets en texto plano. Usar siempre Sealed Secrets:
```bash
kubectl create secret generic <nombre> --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/apps/<app>/sealed-secret.yaml
```

### Traefik middlewares (namespaced)
Al referenciar middlewares en anotaciones, usar el formato:
`<namespace>-<nombre>@kubernetescrd`
Ejemplo: `traefik-private-allowlist@kubernetescrd`

### Imágenes Docker
- Build local (ARM64): `docker buildx build --platform linux/arm64`
- Siempre publicar en GHCR: `ghcr.io/<usuario>/<app>:<sha>`

## Archivos que NO editar manualmente
- `terraform/apps/*.tf` → generados por `register-app.sh`
- `k8s/apps/*/` → generados por `register-app.sh`
- `k8s/flux-system/` → gestionado por Flux
```

---

## SPEC: Documentación

### `docs/adding-new-app.md`

```markdown
# Cómo añadir una nueva app al homelab

## 1. Crear el repositorio de la app en GitHub

El repo puede tener cualquier nombre. Debe incluir:
- El código fuente
- Un `Dockerfile` (si `image.source: dockerfile`)
- Un `homelab.yaml` en la raíz

## 2. Crear el homelab.yaml

Copia y adapta uno de estos ejemplos según el tipo de app:

### App privada (solo LAN)
```yaml
app:
  name: mi-app
  subdomain: mi-app
  visibility: private
  port: 8080
  image:
    source: dockerfile
  resources:
    memory: 256Mi
```

### App pública (internet)
```yaml
app:
  name: mi-blog
  subdomain: blog
  visibility: public
  port: 80
  image:
    source: registry
    registry: nginx:alpine
```

## 3. Registrar la app

```bash
git clone https://github.com/<usuario>/mi-app /tmp/mi-app
./scripts/register-app.sh /tmp/mi-app
```

El script:
1. Genera los manifests K8s en `k8s/apps/mi-app/`
2. Genera el módulo Terraform DNS en `terraform/apps/mi-app.tf`
3. Aplica el DNS (Pi-hole o Cloudflare según visibilidad)
4. Hace commit y push
5. Flux detecta el cambio y despliega en ~2 minutos

## 4. Verificar el despliegue

```bash
# Ver pods
kubectl get pods -n apps

# Ver el Ingress
kubectl get ingress -n apps

# Ver el certificado TLS
kubectl get certificate -n apps

# Ver logs de Traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# Ver logs de la app
kubectl logs -n apps -l app=mi-app
```

## 5. Secrets

Si tu app necesita secrets:

```bash
# Crear el secret (sin commitear)
kubectl create secret generic mi-app-secret \
  --from-literal=password='mi_contraseña' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/apps/mi-app/sealed-secret.yaml

# Añadir al kustomization.yaml de la app
echo "  - sealed-secret.yaml" >> k8s/apps/mi-app/kustomization.yaml

# Commitear el SealedSecret (es seguro, está cifrado)
git add k8s/apps/mi-app/sealed-secret.yaml
git commit -m "feat: add sealed secret for mi-app"
git push
```
```

### `docs/secrets.md`

```markdown
# Gestión de Secrets

## Principios
- **NUNCA** commitear secrets en texto plano
- Usar **Sealed Secrets** para todo lo que va a Git
- Las variables de entorno sensibles van como `secretRef` en `homelab.yaml`

## Flujo de trabajo

### 1. Obtener la clave pública del cluster
```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  > pub-sealed-secrets.pem
```

### 2. Crear y sellar un secret
```bash
kubectl create secret generic nombre-secret \
  --namespace=apps \
  --from-literal=clave=valor \
  --dry-run=client -o yaml | \
  kubeseal --format yaml \
    --cert pub-sealed-secrets.pem \
  > k8s/apps/mi-app/sealed-secret.yaml
```

### 3. Referenciar en el Deployment
```yaml
env:
  - name: MI_VARIABLE
    valueFrom:
      secretKeyRef:
        name: nombre-secret
        key: clave
```

## Secrets de infraestructura

### Cloudflare API Token (para cert-manager y Traefik)
```bash
kubectl create secret generic cloudflare-api-token \
  --namespace=traefik \
  --from-literal=token=TU_CF_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/infrastructure/traefik/sealed-cloudflare-token.yaml
```

El token de Cloudflare necesita permisos:
- Zone → Zone → Read
- Zone → DNS → Edit
```

---

## README.md

```markdown
# 🏠 Homelab RPi5

Infraestructura como código para Raspberry Pi 5 con Kubernetes (K3s), Flux CD, Traefik y automatización DNS completa.

## Stack

| Capa | Herramienta |
|---|---|
| OS Provisioning | Ansible |
| Orquestación | K3s (Kubernetes) |
| GitOps | Flux CD |
| Ingress + TLS | Traefik v3 + cert-manager |
| DNS local | Pi-hole |
| DNS remoto | Terraform + Cloudflare |
| Secrets en Git | Sealed Secrets |

## Inicio rápido

### 1. Clonar y configurar

```bash
git clone https://github.com/<<TU_USUARIO>>/homelab
cd homelab
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Editar terraform.tfvars con tus valores
```

### 2. Provisionar el RPi5

```bash
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/bootstrap-rpi5.yml
```

### 3. Inicializar Flux

```bash
export GITHUB_TOKEN=<<TU_GITHUB_TOKEN>>
flux bootstrap github \
  --owner=<<TU_USUARIO>> \
  --repository=homelab \
  --branch=main \
  --path=k8s/flux-system \
  --personal
```

### 4. Añadir una app

Ver [docs/adding-new-app.md](docs/adding-new-app.md)

## Estructura

```
homelab/
├── ansible/        # Provisioning del SO y K3s
├── k8s/            # Manifests Kubernetes (gestionado por Flux)
├── terraform/      # Automatización DNS
├── scripts/        # Herramientas de gestión
└── docs/           # Documentación
```

## Apps

<!-- Lista auto-generada por register-app.sh -->

| App | Subdominio | Visibilidad |
|-----|-----------|-------------|
| _vacío_ | | |
```

---

## Checklist post-generación para el agente

Al terminar de generar los archivos, el agente debe:

- [ ] Verificar que todos los archivos `*.sh` tienen permisos de ejecución (`chmod +x scripts/*.sh`)
- [ ] Confirmar que `terraform/terraform.tfvars` **NO** está en el repo (debe estar en `.gitignore`)
- [ ] Crear `.gitignore` con: `terraform/.terraform/`, `terraform/*.tfvars`, `*.tfstate`, `*.tfstate.backup`, `.env`, `pub-sealed-secrets.pem`
- [ ] Crear `terraform/apps/.gitkeep` para que el directorio exista pero vacío
- [ ] Verificar que todos los `kustomization.yaml` de infrastructure referencian correctamente sus subdirectorios
- [ ] Mostrar el listado final de archivos creados con `tree` o equivalente
