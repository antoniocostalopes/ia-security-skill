# Exemplo de Auditoria — Django 4.2

> Few-shot para IAs auditarem apps Django.

## Input

### `settings.py`
```python
DEBUG = True
ALLOWED_HOSTS = ['*']
SECRET_KEY = 'django-insecure-abc123def456'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'mydb',
        'USER': 'postgres',
        'PASSWORD': 'postgres',
        'HOST': 'localhost',
    }
}
INSTALLED_APPS = ['django.contrib.admin', 'django.contrib.auth', 'app']
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    # 'django.middleware.csrf.CsrfViewMiddleware',  # comentado
    'django.contrib.auth.middleware.AuthenticationMiddleware',
]
```

### `app/views.py`
```python
from django.shortcuts import render
from django.http import JsonResponse
from django.db import connection
from .models import User, Post

def search(request):
    q = request.GET.get('q')
    with connection.cursor() as c:
        c.execute(f"SELECT * FROM app_post WHERE title LIKE '%{q}%'")
        return JsonResponse({'results': c.fetchall()})

def update_user(request, user_id):
    user = User.objects.get(pk=user_id)
    for field, value in request.POST.items():
        setattr(user, field, value)
    user.save()
    return JsonResponse({'ok': True})

def avatar(request):
    path = request.GET.get('file')
    with open(f'/var/uploads/{path}') as f:
        return HttpResponse(f.read(), content_type='image/png')
```

---

## Output esperado

```markdown
# Relatório de Segurança — django-app

**Data:** 2026-05-06
**Stack:** Django 4.2 · PostgreSQL · Python 3.11
**Ficheiros analisados:** 2

## 1. Score: 0/100 — **Crítico — NÃO PUBLICAR**

| Severidade | Qtd | Subtotal |
|---|---:|---:|
| Crítico | 6 | -120 |
| Alto    | 3 | -30 |
| Médio   | 2 | -8 |
| **Total** | 11 | **0 (cap)** |

## 2. Resumo Cliente
6 problemas críticos: a app permite qualquer um dump da BD, edição de qualquer user, leitura de ficheiros do servidor, e tem CSRF desativado. SECRET_KEY com `django-insecure-` indica não regenerada. **Não publicar.** Fixes ~1 dia.

## 3. Resumo Técnico
Settings em modo dev (DEBUG=True, ALLOWED_HOSTS=['*']). CsrfViewMiddleware comentado. Raw SQL com f-string. Mass assignment manual via `setattr` loop. Path traversal trivial em avatar. Falta auth em todas as views. Refactor: ativar CSRF, ModelForm strict, ORM, FileField + Storage, decorators.

## 4. Mapa de Superfícies

| # | Superfície | Localização | Auth | Risco |
|---|---|---|---|---|
| 1 | GET /search | views.py:6 | Nenhuma | Crítico |
| 2 | POST /users/<id> | views.py:12 | Nenhuma | Crítico |
| 3 | GET /avatar | views.py:18 | Nenhuma | Crítico |

## 5. Attack Chains

### Vetor 1 — Roubo total BD (Crítico, 100%)
- C1 (SQLi) + C4 (DEBUG=True): `?q=' UNION SELECT...` extrai tudo, e DEBUG mostra erros SQL para refinar payload.

### Vetor 2 — Privilege Escalation (Crítico, 95%)
- C2 (mass assignment) + ausência de auth + CSRF disabled (C5)
- POST /users/1 com `is_superuser=True` → admin Django

### Vetor 3 — Leitura de SECRET_KEY + .env (Crítico, 100%)
- C3 (path traversal): `?file=../../../app/settings.py` → SECRET_KEY → forjar sessões → admin

## 6. Achados

### Críticos

#### C1. SQL Injection em search
- **Categoria:** SQL Injection
- **Confiança:** 100%
- **Localização:** `app/views.py:8`
- **Código:**
  ```python
  c.execute(f"SELECT * FROM app_post WHERE title LIKE '%{q}%'")
  ```
- **Exploração:** `GET /search?q=' UNION SELECT password,id,1 FROM auth_user--`
- **Correção:**
  ```python
  from django.db.models import Q

  def search(request):
      q = request.GET.get('q', '').strip()[:100]
      results = Post.objects.filter(title__icontains=q).values('id', 'title', 'slug')
      return JsonResponse({'results': list(results)})
  ```

#### C2. Mass Assignment em update_user
- **Categoria:** Permissões / Mass Assignment
- **Confiança:** 100%
- **Localização:** `app/views.py:12-14`
- **Código:**
  ```python
  for field, value in request.POST.items():
      setattr(user, field, value)
  ```
- **Exploração:** `POST /users/1` com `is_superuser=True`, `is_staff=True`
- **Correção:**
  ```python
  from django.contrib.auth.decorators import login_required
  from django import forms

  class UpdateUserForm(forms.ModelForm):
      class Meta:
          model = User
          fields = ['first_name', 'last_name', 'email']  # SEM is_staff/is_superuser

  @login_required
  def update_user(request, user_id):
      if request.user.id != int(user_id) and not request.user.is_staff:
          return HttpResponseForbidden()
      user = get_object_or_404(User, pk=user_id)
      form = UpdateUserForm(request.POST, instance=user)
      if not form.is_valid():
          return JsonResponse({'errors': form.errors}, status=400)
      form.save()
      return JsonResponse({'ok': True})
  ```

#### C3. Path Traversal em avatar
- **Categoria:** Open Redirect/SSRF (path traversal)
- **Confiança:** 100%
- **Localização:** `app/views.py:18-20`
- **Código:**
  ```python
  with open(f'/var/uploads/{path}') as f:
  ```
- **Exploração:** `?file=../../../etc/passwd` ou `?file=../../app/settings.py`
- **Correção:**
  ```python
  import os
  from pathlib import Path

  UPLOAD_BASE = Path('/var/uploads').resolve()

  @login_required
  def avatar(request, user_id):
      target = (UPLOAD_BASE / str(user_id) / 'avatar.png').resolve()
      if not str(target).startswith(str(UPLOAD_BASE)):
          return HttpResponseBadRequest()
      if not target.exists():
          return HttpResponseNotFound()
      return FileResponse(open(target, 'rb'), content_type='image/png')
  ```

#### C4. DEBUG = True em produção
- **Categoria:** Configuração / Hardening
- **Confiança:** 100%
- **Localização:** `settings.py:1`
- **Exploração:** Erros expõem stack trace + queries SQL + paths + variáveis. Atacante refina exploits rapidamente.
- **Correção:**
  ```python
  DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'  # default False
  ```

#### C5. CSRF middleware comentado
- **Categoria:** CSRF
- **Confiança:** 100%
- **Localização:** `settings.py:14`
- **Exploração:** Qualquer site malicioso pode submeter POST a /users/1.
- **Correção:** Descomentar `'django.middleware.csrf.CsrfViewMiddleware'`.

#### C6. SECRET_KEY com prefixo "django-insecure-"
- **Categoria:** Tokens / Secrets
- **Confiança:** 100%
- **Localização:** `settings.py:3`
- **Explicação:** Prefixo `django-insecure-` indica chave gerada por `startproject` — nunca foi rotacionada para produção. Se exposta (e SETTINGS leak via path traversal acima!), atacante forja sessões.
- **Correção:**
  ```python
  SECRET_KEY = os.environ['DJANGO_SECRET_KEY']  # gerar nova: python -c "import secrets; print(secrets.token_urlsafe(50))"
  ```

### Altos

#### A1. ALLOWED_HOSTS = ['*']
- **Categoria:** Configuração
- **Confiança:** 100%
- **Localização:** `settings.py:2`
- **Correção:** `ALLOWED_HOSTS = ['meusite.tld', 'www.meusite.tld']`

#### A2. DB_PASSWORD = 'postgres' (default)
- **Categoria:** Tokens / Secrets / Hardening
- **Confiança:** 100%
- **Localização:** `settings.py`
- **Correção:** Password forte via env var; nunca defaults.

#### A3. SecurityMiddleware ativo mas sem HSTS / SSL_REDIRECT
- **Categoria:** Headers HTTP
- **Confiança:** 80%
- **Correção:**
  ```python
  SECURE_SSL_REDIRECT = True
  SECURE_HSTS_SECONDS = 31536000
  SECURE_HSTS_INCLUDE_SUBDOMAINS = True
  SECURE_HSTS_PRELOAD = True
  SESSION_COOKIE_SECURE = True
  CSRF_COOKIE_SECURE = True
  X_FRAME_OPTIONS = 'DENY'
  SECURE_CONTENT_TYPE_NOSNIFF = True
  ```

### Médios

#### M1. Sem rate limit em search/login
- **Confiança:** 80%
- **Correção:** `django-ratelimit` ou `django-axes` para login.

#### M2. SECURE_PROXY_SSL_HEADER ausente (se atrás de LB)
- **Confiança:** 60%
- **Correção:** Configurar se aplicável.

## 7. Plano de Correção

### Fase 1 — 24h
- [ ] C4 — DEBUG=False
- [ ] C5 — Descomentar CSRF middleware
- [ ] C6 — SECRET_KEY nova via env
- [ ] A2 — DB password forte via env
- [ ] A1 — ALLOWED_HOSTS específico
- [ ] C1 — Substituir raw SQL por ORM
- [ ] C3 — Refazer avatar com Path validation

### Fase 2 — 1 semana
- [ ] C2 — ModelForm + login_required + ownership check
- [ ] A3 — Security headers (HSTS, secure cookies)
- [ ] M1 — Rate limiting

### Fase 3 — 2 semanas
- [ ] M2 — Proxy SSL header se atrás de LB
- [ ] django-axes para login
- [ ] Tests anti-regressão

### Fase 4 — Contínuo
- [ ] pip-audit na CI
- [ ] Bandit (SAST Python)
- [ ] Dependabot

## 8. Checklist Pré-Produção

- [ ] DEBUG = False, ALLOWED_HOSTS específico
- [ ] SECRET_KEY via env (sem `django-insecure-`)
- [ ] CSRF middleware ativo
- [ ] Auth decorators em todas as views privadas
- [ ] ORM (não raw SQL), ou raw com `[%s]` parameterized
- [ ] ModelForm com `fields` explícito
- [ ] HTTPS settings ativos
- [ ] Cookies seguros
- [ ] Password validators (min 12 chars)
- [ ] Logs sem PII
- [ ] pip-audit clean

## 9. Recomendações Adicionais

- **django-environ** para gestão de env vars
- **django-axes** para brute force protection
- **django-csp** para Content Security Policy
- **mypy + django-stubs** para type safety
- **Bandit** na CI
- **Pen-test externo** após Fase 1+2
```
