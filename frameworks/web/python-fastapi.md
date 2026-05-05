# FastAPI — Profile de Segurança

## Deteção
- `from fastapi import FastAPI`
- `requirements.txt` com `fastapi`

## Setup mínimo seguro

```python
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from slowapi import Limiter
from slowapi.util import get_remote_address

app = FastAPI(
    docs_url=None if os.getenv("ENV") == "production" else "/docs",
    redoc_url=None if os.getenv("ENV") == "production" else "/redoc",
)

app.add_middleware(TrustedHostMiddleware, allowed_hosts=["meusite.tld", "*.meusite.tld"])
app.add_middleware(HTTPSRedirectMiddleware)
app.add_middleware(CORSMiddleware,
    allow_origins=["https://app.meusite.tld"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
```

## Validation — Pydantic (built-in)

```python
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    age: int | None = Field(None, ge=13, le=120)

    model_config = {"extra": "forbid"}  # rejeita campos extra

@app.post("/users")
async def create_user(user: UserCreate):
    # user já validado
    pass
```

## Auth — Dependencies

```python
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

oauth2 = OAuth2PasswordBearer(tokenUrl="/auth/token")

async def get_current_user(token: str = Depends(oauth2)) -> User:
    try:
        payload = jwt.decode(token, SECRET, algorithms=["HS256"],
                             options={"verify_iss": True, "verify_aud": True},
                             issuer="meusite.tld", audience="meusite.tld")
        user_id = payload.get("sub")
        if user_id is None: raise HTTPException(401)
    except JWTError:
        raise HTTPException(401)
    user = await db.get_user(user_id)
    if not user: raise HTTPException(401)
    return user

async def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin: raise HTTPException(403)
    return user

# Uso
@app.get("/admin/users", dependencies=[Depends(require_admin)])
async def list_users(): ...
```

## ORM — SQLAlchemy / SQLModel

```python
# SQLModel (Pydantic + SQLAlchemy combinados)
from sqlmodel import Field, SQLModel, Session, select

class User(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str
    email: str = Field(unique=True, index=True)
    password_hash: str  # NÃO expor em response

# DTO separado
class UserResponse(SQLModel):
    id: int
    name: str
    email: str

@app.get("/users/{id}", response_model=UserResponse)
async def get_user(id: int, session: Session = Depends(get_session)):
    user = session.get(User, id)
    if not user: raise HTTPException(404)
    return user  # FastAPI filtra para UserResponse — exclui password_hash
```

## Rate limit (slowapi)

```python
@app.post("/login")
@limiter.limit("5/minute")
async def login(request: Request, ...): ...
```

## Common antipatterns

### `/docs` e `/openapi.json` em produção
- Expõe schema completo. Desativar ou proteger.

### Sem `response_model`
- Endpoint devolve **tudo** do model, incluindo `password_hash`.

### Pydantic sem `extra="forbid"`
- Mass assignment via campos extra.

### `Depends(get_current_user)` esquecido
- Endpoint público.

### `BackgroundTasks` com input não validado
- Tasks correm sem auth context.

### CORS `allow_origins=["*"]` com `allow_credentials=True`
- Browsers bloqueiam, mas é red flag.

### `app.mount("/static", StaticFiles(...))` com path traversal
- StaticFiles é seguro por default mas custom directories podem ter issues.

## Helpers

| Necessidade | Lib |
|---|---|
| Auth | `python-jose` (JWT), `passlib[bcrypt]` |
| OAuth2 | `authlib` |
| Rate limit | `slowapi` (FastAPI port de Flask-Limiter) |
| CORS | `fastapi.middleware.cors` (built-in) |
| Validation | `pydantic` (built-in) |
| ORM | `sqlmodel`, `sqlalchemy`, `tortoise-orm` |
| WebSocket | `fastapi.WebSocket` (built-in) |
| Background tasks | `fastapi.BackgroundTasks`, `Celery`, `arq` |

## Quick wins

- [ ] FastAPI 0.110+
- [ ] `pip-audit` sem Críticos
- [ ] `/docs`/`/redoc` desativados ou autenticados em prod
- [ ] `TrustedHostMiddleware` configurado
- [ ] `HTTPSRedirectMiddleware` em prod
- [ ] CORS com `allow_origins` específicos
- [ ] Pydantic models com `extra="forbid"`
- [ ] `response_model` em todos os endpoints (DTO sem campos sensíveis)
- [ ] `Depends(get_current_user)` em todos os endpoints privados
- [ ] JWT com `iss`, `aud`, `exp` validados
- [ ] `passlib[bcrypt]` para passwords (cost ≥ 12)
- [ ] `slowapi` rate limit em login, register, search
- [ ] Logging estruturado (structlog) com sanitização
- [ ] BackgroundTasks com auth context propagado se necessário
- [ ] WebSocket endpoints com auth no `accept`
