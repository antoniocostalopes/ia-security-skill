# Spring Boot — Profile de Segurança

## Deteção
- `pom.xml`/`build.gradle` com `spring-boot-starter-*`
- `@SpringBootApplication` annotation

## Spring Security — config

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity  // habilita @PreAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/", "/login", "/register").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .formLogin(form -> form
                .loginPage("/login")
                .defaultSuccessUrl("/dashboard")
            )
            .logout(logout -> logout.logoutSuccessUrl("/"))
            .csrf(Customizer.withDefaults())  // ATIVO por default
            .sessionManagement(session -> session
                .sessionFixation().migrateSession()  // regenera ID após login
                .maximumSessions(1).maxSessionsPreventsLogin(false)
            )
            .headers(headers -> headers
                .frameOptions(frame -> frame.sameOrigin())
                .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
                .httpStrictTransportSecurity(hsts -> hsts
                    .includeSubDomains(true).maxAgeInSeconds(31536000))
            );
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
```

## Method security

```java
@RestController
public class UserController {

    @GetMapping("/admin/users")
    @PreAuthorize("hasRole('ADMIN')")
    public List<UserDto> listAll() { ... }

    @PostMapping("/posts/{id}")
    @PreAuthorize("@postService.isOwner(#id, authentication.name)")
    public void update(@PathVariable Long id, @Valid @RequestBody UpdatePostDto dto) { ... }
}
```

## DTOs (anti mass assignment)

```java
// BAD
@PostMapping("/profile")
public User update(@RequestBody User user) { return repo.save(user); }
// Atacante: { "id": 1, "role": "ADMIN" }

// GOOD
public record UpdateProfileDto(
    @NotBlank @Size(max = 100) String name,
    @Size(max = 500) String bio
    // sem id, sem role, sem isActive
) {}

@PostMapping("/profile")
public UserDto update(@Valid @RequestBody UpdateProfileDto dto, Principal principal) {
    User user = repo.findByEmail(principal.getName()).orElseThrow();
    user.setName(dto.name());
    user.setBio(dto.bio());
    return UserDto.from(repo.save(user));
}
```

## JPA / Hibernate queries

Coberto em `analises/query-builders-orm.md` e `linguagens/java.md`.

```java
// BAD
em.createQuery("SELECT u FROM User u WHERE u.name = '" + name + "'");

// GOOD
em.createQuery("SELECT u FROM User u WHERE u.name = :name")
  .setParameter("name", name);

// Spring Data JPA
List<User> findByName(String name);  // safe by design

// Native query
@Query(value = "SELECT * FROM users WHERE name = :name", nativeQuery = true)
List<User> findByNameNative(@Param("name") String name);
```

## Common antipatterns

### `csrf().disable()` global
- Apenas para APIs stateless. Para web tradicional, manter ON.

### `permitAll()` esquecido em endpoint sensível
```java
.requestMatchers("/api/admin/**").permitAll()  // !!
```

### `actuator/*` exposto sem auth
- `/actuator/env`, `/actuator/configprops` revelam config.
- Configurar `management.endpoints.web.exposure.include` minimalmente.

### `@RequestBody Entity`
- Mass assignment.

### `@CrossOrigin("*")` em controllers autenticados
- Permite cookies de qualquer origem (browser bloqueia mas é red flag).

### `application.properties` com secrets
- Usar `application-prod.yml` excluído do git, ou Spring Cloud Config / Vault.

### `spring.h2.console.enabled=true` em prod
- Console SQL exposto.

### Sessions sem invalidar após mudança de password
```java
public void changePassword(String userEmail, String newPassword) {
    User u = repo.findByEmail(userEmail).orElseThrow();
    u.setPassword(encoder.encode(newPassword));
    repo.save(u);
    // INVALIDAR sessões
    sessionRegistry.getAllSessions(u, false)
        .forEach(SessionInformation::expireNow);
}
```

## Spring Boot Actuator security

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info  # mínimo
  endpoint:
    health:
      show-details: when-authorized  # nunca always
```

## Quick wins

- [ ] Spring Boot 3.x (versões 2.x EOL)
- [ ] Java 17+ LTS
- [ ] `mvn dependency-check:check` ou `gradle dependencyCheckAnalyze` sem Críticos
- [ ] Spring Security 6+
- [ ] `BCryptPasswordEncoder` (cost ≥ 12) ou Argon2
- [ ] DTOs por endpoint (não expor entities JPA)
- [ ] `@Valid` + Bean Validation em todos os DTOs
- [ ] `@PreAuthorize` em endpoints sensíveis
- [ ] CSRF ativo em web (não desativar globalmente)
- [ ] Session fixation protection (`migrateSession()`)
- [ ] HSTS, X-Frame-Options, CSP via `headers()`
- [ ] Cookies com `Secure + HttpOnly + SameSite`
- [ ] H2 console **off** em prod
- [ ] Actuator endpoints minimizados e autenticados
- [ ] Secrets via env vars / Vault, não em `application.properties`
- [ ] Logback config sem PII em logs
- [ ] Spring Data JPA queries com `@Param` ou derived methods
- [ ] Sessions invalidadas após password change
