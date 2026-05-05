# NestJS — Profile de Segurança

## Deteção
- `package.json` com `@nestjs/core`
- `nest-cli.json`
- `main.ts` com `NestFactory.create`

## Setup mínimo seguro

```typescript
// main.ts
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import * as cookieParser from 'cookie-parser';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(helmet());
  app.use(cookieParser(process.env.COOKIE_SECRET));
  app.enableCors({
    origin: ['https://app.meusite.tld'],
    credentials: true,
  });
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,         // remove campos não no DTO
    forbidNonWhitelisted: true,  // 400 se vier campo extra
    transform: true,
    transformOptions: { enableImplicitConversion: true },
  }));
  await app.listen(3000);
}
```

## Validation — class-validator

```typescript
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateUserDto {
  @IsString() @MinLength(1) @MaxLength(100)
  name: string;

  @IsEmail()
  email: string;

  // role NÃO incluído — anti mass assignment
}

@Controller('users')
export class UsersController {
  @Post()
  create(@Body() dto: CreateUserDto) {  // validation automática
    return this.users.create(dto);
  }
}
```

## Auth — Guards

```typescript
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(ctx: ExecutionContext) {
    const required = this.reflector.get<string[]>('roles', ctx.getHandler());
    if (!required) return true;
    const req = ctx.switchToHttp().getRequest();
    return required.some(r => req.user?.roles?.includes(r));
  }
}

// Custom decorator
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

// Uso
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Get('admin/users')
adminUsers() { ... }
```

## TypeORM / Prisma queries

Coberto em `analises/query-builders-orm.md`. Resumo NestJS:

```typescript
// TypeORM — usar QueryBuilder ou Repository
this.users.createQueryBuilder('u')
  .where('u.email = :email', { email })
  .getOne();

// Prisma
this.prisma.user.findUnique({ where: { email } });
```

## Common antipatterns

### Sem `ValidationPipe` global
- DTOs não validados.

### `whitelist: false` ou ausente
- Mass assignment via campos extra.

### `@Body()` para Entity em vez de DTO
- Expõe campos internos.

### Guards aplicados apenas localmente
- Esquecimento em rota nova → endpoint público.
- Considerar `@UseGuards(JwtAuthGuard)` global + `@Public()` decorator para opt-out.

### Microservices sem auth
- Comunicação RMQ/Kafka/gRPC entre serviços muitas vezes assumida confiável.
- Em ambientes shared, validar.

### Interceptors que vazam dados
- Interceptor que serializa respostas pode incluir campos sensíveis se DTO não filtra.

## Helpers / packages

| Necessidade | Package |
|---|---|
| Auth (Passport) | `@nestjs/passport` + `passport-*` strategies |
| JWT | `@nestjs/jwt` |
| Throttler (rate limit) | `@nestjs/throttler` |
| Schedule | `@nestjs/schedule` (jobs autenticados se necessário) |
| GraphQL | `@nestjs/graphql` |
| WebSockets | `@nestjs/websockets` |
| Validation | `class-validator` + `class-transformer` |
| Logging | `nestjs-pino` (preferida sobre default) |

## Quick wins

- [ ] NestJS 10+
- [ ] `npm audit` sem Críticos
- [ ] `ValidationPipe` global com `whitelist: true, forbidNonWhitelisted: true`
- [ ] `helmet` + `cookieParser` no main.ts
- [ ] `enableCors` com allowlist
- [ ] DTOs separados de Entities (sem `@Body() Entity`)
- [ ] Guards aplicados — preferir global + `@Public()` opt-out
- [ ] `@nestjs/throttler` em rotas sensíveis
- [ ] `@nestjs/jwt` com secret strong + expiresIn curto
- [ ] Prisma/TypeORM queries parametrizadas
- [ ] Interceptors que filtram campos sensíveis das respostas
- [ ] Logging com sanitização de PII (nestjs-pino com redact)
- [ ] Error filter global que não vaza stack
- [ ] Microservices auth (mTLS, JWT, etc.)
