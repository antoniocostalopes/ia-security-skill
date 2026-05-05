# Django — Profile de Segurança

## Deteção
- `manage.py`
- `settings.py` com `DJANGO_SETTINGS_MODULE`
- `INSTALLED_APPS` em settings

## Settings críticos

```python
# BAD em prod
DEBUG = True
ALLOWED_HOSTS = ['*']

# GOOD
DEBUG = False
ALLOWED_HOSTS = ['meusite.tld', 'www.meusite.tld']

# Security middleware obrigatório
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',          # CSRF — não remover
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# HTTPS / HSTS
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'
SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'

# Cookies
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False  # CSRF cookie precisa de ser lido por JS
CSRF_COOKIE_SAMESITE = 'Lax'

# Password validators
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
     'OPTIONS': {'min_length': 12}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
```

## Auth & Permissions

```python
from django.contrib.auth.decorators import login_required, permission_required, user_passes_test

@login_required
@permission_required('blog.change_post', raise_exception=True)
def edit_post(request, pk):
    post = get_object_or_404(Post, pk=pk)
    if post.author != request.user:  # ownership
        raise PermissionDenied
    # ...

# Class-based
from django.contrib.auth.mixins import LoginRequiredMixin, PermissionRequiredMixin
from django.views.generic import UpdateView

class EditPost(LoginRequiredMixin, PermissionRequiredMixin, UpdateView):
    model = Post
    permission_required = 'blog.change_post'

    def get_queryset(self):
        return super().get_queryset().filter(author=self.request.user)
```

## ORM (Django ORM)

```python
# BAD
User.objects.raw(f"SELECT * FROM users WHERE name = '{name}'")
User.objects.extra(where=[f"name = '{name}'"])

# GOOD
User.objects.filter(name=name)
User.objects.raw("SELECT * FROM users WHERE name = %s", [name])

# Field-level security
class UserSerializer:
    fields = ['id', 'name', 'email']  # explícito, sem password
```

## Forms / Mass assignment

```python
# BAD — ModelForm com fields = '__all__'
class UserForm(forms.ModelForm):
    class Meta:
        model = User
        fields = '__all__'  # role passa

# GOOD — allowlist
class UserForm(forms.ModelForm):
    class Meta:
        model = User
        fields = ['name', 'email', 'bio']
```

## Templates — XSS

Django auto-escape ON por default.
```django
{# Auto-escaped #}
{{ user.name }}

{# Raw — perigoso #}
{{ user.bio|safe }}

{# Bleach para HTML controlado #}
{% load bleach_tags %}
{{ user.bio|bleach }}
```

## CSRF
- Middleware ativo. `{% csrf_token %}` em forms.
- Para AJAX: ler cookie `csrftoken`, enviar header `X-CSRFToken`.
- API com tokens (DRF): `@csrf_exempt` + auth via Token/JWT.

## Django REST Framework (DRF)

```python
from rest_framework.permissions import IsAuthenticated, DjangoModelPermissions

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated, DjangoModelPermissions]

    def get_queryset(self):
        # Anti-IDOR
        return super().get_queryset().filter(owner=self.request.user)
```

## File uploads

```python
# Storage seguro
from django.core.files.storage import default_storage

def upload(request):
    f = request.FILES['file']
    if f.size > 5 * 1024 * 1024: raise ValidationError('Too large')

    import magic
    mime = magic.from_buffer(f.read(2048), mime=True)
    f.seek(0)
    if mime not in ['image/jpeg', 'image/png']: raise ValidationError('Bad type')

    name = default_storage.save(f"uploads/{uuid.uuid4()}{os.path.splitext(f.name)[1]}", f)
```

## Common antipatterns

### `DEBUG = True` em prod
- Stack traces, settings expostos.

### `ALLOWED_HOSTS = ['*']`
- Host header injection.

### `SECRET_KEY` hardcoded ou em git
- Compromete tudo.

### `@csrf_exempt` sem alternativa de auth
- CSRF aberto.

### `User.objects.filter(...)` sem filtrar por owner
- IDOR.

### `DjangoTemplates` com `autoescape: False`
- XSS armazenado.

### `ALLOWED_REDIRECT_HOSTS` / `next` parameter sem validação
- Open redirect.

### Admin acessível em `/admin/`
- Mover para path obscuro + IP allowlist.

### `request.GET.get('x') | safe`
- XSS reflected.

## Quick wins

- [ ] Django LTS atual (4.2+)
- [ ] `pip-audit` / `safety check` sem Críticos
- [ ] `DEBUG = False`, `ALLOWED_HOSTS` específico
- [ ] `SECRET_KEY` via env var
- [ ] HTTPS forçado (`SECURE_SSL_REDIRECT`)
- [ ] HSTS, X-Frame-Options, X-Content-Type-Options ativos
- [ ] Cookies com `SECURE + HTTPONLY + SAMESITE`
- [ ] CSRF middleware ativo
- [ ] Password validators robustos (min 12 chars)
- [ ] `@login_required` / `LoginRequiredMixin` em views privadas
- [ ] Permissions a nível de view + ownership a nível de queryset
- [ ] `ModelForm.fields` allowlist (não `'__all__'`)
- [ ] Templates auto-escape ON
- [ ] DRF com `permission_classes` em todos os ViewSets
- [ ] Admin em path obscuro + IP allowlist
- [ ] `django-axes` ou similar para login rate limit/lockout
