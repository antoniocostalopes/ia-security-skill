# gRPC — Profile de Segurança

## Deteção
- `.proto` files
- `package.json` com `@grpc/grpc-js`, `grpc-tools`
- `go.mod` com `google.golang.org/grpc`
- Python: `grpcio`
- `pom.xml`/`build.gradle` com `io.grpc:*`

## Princípios

gRPC é binário (Protobuf), HTTP/2, frequentemente entre serviços internos. **Não é "seguro porque é interno"** — defesa em profundidade necessária.

## Transport security — TLS

```go
// Server
creds, _ := credentials.NewServerTLSFromFile("server.crt", "server.key")
s := grpc.NewServer(grpc.Creds(creds))

// Client
creds, _ := credentials.NewClientTLSFromFile("ca.crt", "")
conn, _ := grpc.Dial("server:443", grpc.WithTransportCredentials(creds))
```

```python
# Server
with open('server.key', 'rb') as f: key = f.read()
with open('server.crt', 'rb') as f: cert = f.read()
creds = grpc.ssl_server_credentials([(key, cert)])
server.add_secure_port('[::]:50051', creds)
```

## Mutual TLS (mTLS) — para auth entre serviços

```go
// Server requires client cert
config := &tls.Config{
    ClientAuth: tls.RequireAndVerifyClientCert,
    ClientCAs:  caPool,
    Certificates: []tls.Certificate{serverCert},
}
s := grpc.NewServer(grpc.Creds(credentials.NewTLS(config)))

// Client provides cert
config := &tls.Config{
    Certificates: []tls.Certificate{clientCert},
    RootCAs:      caPool,
}
conn, _ := grpc.Dial("server:443", grpc.WithTransportCredentials(credentials.NewTLS(config)))
```

## Auth — interceptors

```go
// Unary interceptor para auth
func authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "no metadata")
    }
    tokens := md.Get("authorization")
    if len(tokens) == 0 {
        return nil, status.Error(codes.Unauthenticated, "no token")
    }
    user, err := verifyJWT(strings.TrimPrefix(tokens[0], "Bearer "))
    if err != nil {
        return nil, status.Error(codes.Unauthenticated, "invalid token")
    }
    ctx = context.WithValue(ctx, "user", user)
    return handler(ctx, req)
}

s := grpc.NewServer(
    grpc.Creds(creds),
    grpc.UnaryInterceptor(authInterceptor),
)
```

## Authorization (per method)

```go
func authzInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    user := ctx.Value("user").(*User)

    methodPermissions := map[string]string{
        "/myapp.AdminService/DeleteUser": "admin:delete_user",
        "/myapp.UserService/UpdateProfile": "user:update_profile",
    }

    if perm, ok := methodPermissions[info.FullMethod]; ok {
        if !user.HasPermission(perm) {
            return nil, status.Error(codes.PermissionDenied, "forbidden")
        }
    }
    return handler(ctx, req)
}
```

## Validation

```go
import "github.com/envoyproxy/protoc-gen-validate/validate"

// .proto
message CreateUserRequest {
    string name = 1 [(validate.rules).string = {min_len: 1, max_len: 100}];
    string email = 2 [(validate.rules).string = {email: true}];
}

// Generated code includes Validate() method
if err := req.Validate(); err != nil {
    return nil, status.Error(codes.InvalidArgument, err.Error())
}
```

## Rate limiting

```go
import "google.golang.org/grpc/tap"

// Server-level rate limit
limiter := rate.NewLimiter(100, 10)  // 100 rps, burst 10
opt := grpc.InTapHandle(func(ctx context.Context, info *tap.Info) (context.Context, error) {
    if !limiter.Allow() {
        return nil, status.Error(codes.ResourceExhausted, "rate limited")
    }
    return ctx, nil
})
s := grpc.NewServer(opt)
```

## Streaming security

```go
// Server-streaming: validar autorização para CADA mensagem se contexto muda
func (s *Server) StreamData(req *DataRequest, stream MyService_StreamDataServer) error {
    user := stream.Context().Value("user").(*User)

    for _, item := range data {
        if !user.CanAccess(item) { continue }  // filtrar
        if err := stream.Send(&DataItem{...}); err != nil {
            return err
        }
    }
    return nil
}

// Bi-directional: cada Recv pode ter contexto diferente — validar
```

## Common antipatterns

### gRPC sem TLS (insecure)
```go
// BAD
grpc.NewServer()  // sem credentials = insecure
grpc.Dial("server:443", grpc.WithInsecure())

// GOOD
grpc.NewServer(grpc.Creds(creds))
grpc.Dial("server:443", grpc.WithTransportCredentials(creds))
```

### Reflection ativa em produção
```go
// BAD em prod
import "google.golang.org/grpc/reflection"
reflection.Register(s)  // expõe schema completo

// GOOD — só em dev
if env == "dev" { reflection.Register(s) }
```

### Sem timeout / deadline
```go
// Cliente sem deadline
ctx := context.Background()  // pode ficar pendurado
client.LongMethod(ctx, req)

// GOOD
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
client.LongMethod(ctx, req)
```

### `MaxRecvMsgSize` / `MaxSendMsgSize` default
- Default 4MB. Para uploads/downloads grandes, configurar mas com limit explícito.

### Server reflection com auth check
- Mesmo se reflection ativa, considerar auth no method.

### Errors com info interna
```go
// BAD
return nil, status.Error(codes.Internal, err.Error())  // expõe stack/SQL

// GOOD
log.Error(err)
return nil, status.Error(codes.Internal, "internal error")
```

## Quick wins

- [ ] gRPC com TLS (não `WithInsecure`)
- [ ] mTLS para auth entre serviços internos
- [ ] Auth interceptor (JWT, OAuth, mTLS)
- [ ] Authorization per method
- [ ] Validation via `protoc-gen-validate` ou manual
- [ ] Rate limiting via `InTapHandle` ou middleware
- [ ] Deadlines/timeouts em todos os calls
- [ ] `MaxRecvMsgSize` / `MaxSendMsgSize` adequados
- [ ] Reflection desativada em produção
- [ ] Errors sem detalhes internos (`status.Error` com código apropriado)
- [ ] Streaming com auth check por mensagem se contexto muda
- [ ] Logging de RPCs com sanitização de PII
- [ ] grpc-health-checking implementado para LBs
- [ ] OpenTelemetry tracing (com sanitização)
- [ ] Backups de protos (.proto files versionados)
