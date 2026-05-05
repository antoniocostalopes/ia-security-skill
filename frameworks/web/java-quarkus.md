# Quarkus — Profile de Segurança

## Deteção
- `pom.xml` com `io.quarkus:*`
- `application.properties` com `quarkus.*`

## Auth com Quarkus Security

```properties
# application.properties
# OIDC
quarkus.oidc.auth-server-url=https://keycloak.tld/realms/myrealm
quarkus.oidc.client-id=myapp
quarkus.oidc.credentials.secret=${OIDC_SECRET}
quarkus.oidc.application-type=web-app  # ou service para REST API

# Cookies
quarkus.http.session.cookie-secure=true
quarkus.http.session.cookie-http-only=true
quarkus.http.session.cookie-same-site=lax
```

## Annotations

```java
import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.annotation.security.PermitAll;

@Path("/api")
public class UserResource {

    @GET @Path("/me")
    @Authenticated
    public UserDto me() { ... }

    @GET @Path("/admin/users")
    @RolesAllowed("admin")
    public List<UserDto> all() { ... }

    @GET @Path("/public")
    @PermitAll
    public String publicData() { ... }
}
```

## Validation

```java
public record CreateUserDto(
    @NotBlank @Size(max = 100) String name,
    @Email String email
) {}

@POST
public Response create(@Valid CreateUserDto dto) { ... }
```

## Reactive — Mutiny

```java
@GET @Path("/users/{id}")
@Authenticated
public Uni<UserDto> get(@PathParam("id") Long id) {
    return userService.findById(id)
        .map(UserDto::from)
        .onItem().ifNull().failWith(() -> new NotFoundException());
}
```

## Common antipatterns

### `quarkus.http.cors=true` sem origins
- Permite qualquer origem.

```properties
quarkus.http.cors=true
quarkus.http.cors.origins=https://app.meusite.tld
quarkus.http.cors.methods=GET,POST,PUT,DELETE
```

### Dev mode em produção
- `quarkus:dev` expõe DevUI, hot reload — nunca em prod.

### `@PermitAll` global esquecido
- Endpoint sensível público.

### Native image sem warnings
- GraalVM native pode esconder issues runtime.

## Quick wins

- [ ] Quarkus 3.x
- [ ] Java 17+
- [ ] `mvn org.owasp:dependency-check-maven:check` sem Críticos
- [ ] OIDC integration (Keycloak ou similar)
- [ ] `@Authenticated` / `@RolesAllowed` em endpoints
- [ ] DTOs com `@Valid`
- [ ] CORS com origins explícitos
- [ ] Cookies seguros
- [ ] HTTPS forçado (`quarkus.http.insecure-requests=redirect`)
- [ ] Headers de segurança via `quarkus.http.header.*`
- [ ] DevUI off em produção
