# PROMPT para agente VS Code — Generar repo homelab

> Pega este prompt en el chat del agente de VS Code (GitHub Copilot Chat, Continue, Cursor, etc.)

---

## Prompt a usar en el agente

```
Lee el archivo AGENTS.md en la raíz del repositorio y genera todos los archivos 
que describe. Sigue exactamente este orden:

1. Crea el `.gitignore` con el contenido del spec
2. Crea la estructura de directorios vacíos necesaria
3. Genera todos los archivos de `ansible/` siguiendo las specs de AGENTS.md
4. Genera todos los archivos de `k8s/infrastructure/` siguiendo las specs
5. Genera todos los archivos de `k8s/apps/_template/` siguiendo las specs
6. Genera todos los archivos de `terraform/` y sus módulos
7. Genera todos los scripts en `scripts/` y dales permisos de ejecución
8. Genera los archivos de `.github/` (workflows y copilot-instructions)
9. Genera los archivos de `docs/`
10. Genera el `README.md` y el `homelab.schema.json` raíz

Para cada archivo:
- Usa el contenido EXACTO del bloque de código en AGENTS.md
- Respeta las rutas exactas indicadas
- Los placeholders << >> déjalos como están para que el usuario los complete

Al terminar, muestra un árbol de todos los archivos creados y el checklist 
de la sección "Checklist post-generación".
```

---

## Alternativa: por fases (si el agente tiene límite de contexto)

### Fase 1 — Ansible
```
Lee AGENTS.md. Genera solo los archivos de la sección "SPEC: Ansible" 
y el .gitignore. Respeta las rutas exactas.
```

### Fase 2 — K8s Infrastructure
```
Lee AGENTS.md. Genera los archivos de "SPEC: K8s — Infrastructure" 
en k8s/infrastructure/ con sus kustomizations y helmreleases.
```

### Fase 3 — K8s App Template
```
Lee AGENTS.md. Genera los archivos de "SPEC: K8s — Template de app" 
en k8s/apps/_template/ y el homelab.schema.json en la raíz.
```

### Fase 4 — Terraform
```
Lee AGENTS.md. Genera todos los archivos de terraform/ incluyendo 
módulos cloudflare-record y pihole-record.
```

### Fase 5 — Scripts y CI/CD
```
Lee AGENTS.md. Genera los scripts en scripts/, dales chmod +x, 
y genera los workflows de .github/workflows/.
```

### Fase 6 — Docs y README
```
Lee AGENTS.md. Genera los archivos de docs/, el README.md raíz 
y el .github/copilot-instructions.md.
```

---

## Comandos útiles post-generación

```bash
# Verificar permisos de scripts
chmod +x scripts/*.sh

# Instalar dependencias Ansible
cd ansible && ansible-galaxy install -r requirements.yml

# Validar Terraform
cd terraform && terraform init && terraform validate

# Copiar tfvars de ejemplo
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Editar terraform.tfvars con tus valores reales

# Verificar estructura generada
find . -type f | grep -v '.git/' | sort
```
